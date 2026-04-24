# Chapter 3 — Key Design Decisions

> Each decision records the options considered, the trade-offs, the final choice, and the conditions under which you would revisit it.

---

## Decision 1: ABR Protocol — HLS vs DASH

### Options Considered

| Option | Standard Body | Segment Format | Native iOS | Native Android | CDN Support |
|---|---|---|---|---|---|
| **HLS** | Apple | .ts / fragmented MP4 | Native (AVFoundation) | Via ExoPlayer | Universal |
| **DASH** | MPEG | fragmented MP4 | Via Shaka Player | Native (ExoPlayer) | Universal |
| **CMAF** | MPEG | fMP4 (shared segments) | Via player SDK | Via player SDK | Growing |

### Trade-Offs

**HLS**
- Pro: Native support on iOS/macOS (AVFoundation) — no custom player required; lowest integration complexity for the dominant mobile platform.
- Pro: LL-HLS (Low-Latency HLS) brings glass-to-glass latency to 2–4 s using partial segments and preload hints.
- Con: Historically used `.ts` containers (MPEG-2 TS), which are larger than fMP4; HLS v7+ moves to fragmented MP4 (aligned with DASH).
- Con: Apple controls the specification; DASH evolves via open committee.

**DASH**
- Pro: Open standard; richer feature set (multi-period ads, content protection profiles, roles).
- Pro: Better specified for low-latency live (chunk transfer encoding; server push).
- Con: No native iOS support; requires Shaka Player or similar, adding a JavaScript dependency.
- Con: More manifest complexity (XML MPD vs plain-text M3U8); harder to debug manually.

**CMAF**
- Pro: Single segment file shared by both HLS and DASH playlists — halves storage for dual-format output.
- Con: Requires modern CDN support for byte-range delivery; older CDN configs need adjustment.

### Final Choice: HLS as primary; CMAF fMP4 segments for both HLS v7 and DASH playlists

**Rationale:** iOS is 40%+ of traffic; HLS native support is non-negotiable. CMAF unifies the segment format, eliminating double-storage. Shaka Packager writes both HLS and DASH manifests pointing to the same fMP4 segments. LL-HLS enabled for live streams.

### When to Reconsider
- If DASH client adoption on iOS grows (Apple supports DASH in WebKit) → shift to DASH-primary with HLS compatibility manifest.
- If multi-period ad insertion becomes critical → DASH's multi-period support is superior to HLS's discontinuity tags.

---

## Decision 2: Codec Selection — H.264 vs H.265 vs AV1

### Options Considered

| Codec | Compression Efficiency | Hardware Decode Coverage | Encode Cost | Royalties |
|---|---|---|---|---|
| **H.264** | Baseline | 99.9% of devices | Low (1× reference) | MPEG-LA (bundled) |
| **H.265 (HEVC)** | ~40% better than H.264 | ~80% (iOS, modern Android, smart TVs) | Medium (3–5×) | Complex multi-pool (risk) |
| **AV1** | ~30% better than H.265 | ~50% hardware; growing fast | High (10–20×) | Royalty-free |
| **VP9** | ~30% better than H.264 | ~90% (Chrome/Android dominant) | Medium (4–8×) | Royalty-free |

### Trade-Offs

**H.264** — Universal compatibility, lowest encode cost. At 5 Mbps for 1080p it is increasingly inefficient vs alternatives. Appropriate as the guaranteed baseline.

**H.265** — Reduces bandwidth 40% vs H.264 at equivalent quality. Royalty situation is complex (HEVC Advance, MPEG-LA, Velos Media pools overlap); creates legal uncertainty. Hardware decode coverage is good but not universal.

**AV1** — Best compression; royalty-free. Encode cost 10–20× H.264 means GPU acceleration is mandatory. Hardware decode in 2024+ devices (Apple M1+, Snapdragon 8 Gen 2+) is expanding rapidly.

**VP9** — Good compression; royalty-free; widely supported in Chrome/Android. Encode cost moderate. Being superseded by AV1 within the same ecosystem.

### Final Choice: H.264 (universal baseline) + AV1 (premium tier for 1080p+)

**Rationale:** H.264 ensures every device can play every video. AV1 at 1080p saves ~30% of CDN bandwidth vs H.264 for modern clients that declare AV1 hardware decode in their User-Agent. The HLS master manifest lists both renditions; players that support AV1 select it automatically. Encode AV1 on GPU workers; H.264 on CPU workers (cost models differ).

### When to Reconsider
- AV1 hardware decode coverage exceeds 80% globally → drop H.264 as the required baseline, encode only H.264 for legacy devices.
- H.265 royalty pool consolidates (unlikely near-term) → H.265 offers better device coverage than AV1 today with lower encode cost.

---

## Decision 3: Transcode Strategy — Pre-Encode All Tiers vs Just-in-Time 4K

### Options Considered

| Strategy | Description | Cost | UX |
|---|---|---|---|
| **Pre-encode all tiers on upload** | 360p, 720p, 1080p, 4K all encoded immediately | High (4K encode is expensive) | Instant 4K availability |
| **JIT 4K (lazy encode)** | 360p/720p/1080p on upload; 4K only when first 4K viewer requests it | Lower | 4K delayed ~10 min on first request |
| **Progressive quality release** | 360p published first; 720p/1080p added as they complete | Lowest TTFP (time to first play) | Video available in 360p within 2 min of upload |

### Trade-Offs

**Pre-encode all tiers**
- Pro: All quality levels available the moment the video is published.
- Con: 4K encodes are 10–20× more expensive than 720p and are wasted if the video never receives a 4K view (true for > 95% of videos).

**JIT 4K**
- Pro: 60–70% transcode cost reduction (4K represents ~60% of total encode compute).
- Con: First 4K viewer triggers a ~10-min encode; that viewer sees 1080p until 4K is ready.
- Con: Requires a JIT trigger mechanism (player signals 4K capability; Video API queues 4K job if not already available).

**Progressive quality release**
- Pro: Video playable within 2 minutes of upload completion (360p encodes in < 1 min for a 10-min video).
- Con: Requires the player to gracefully handle a manifest that grows over time (ABR re-fetch reveals new renditions).

### Final Choice: Progressive release (360p first) + JIT 4K; 720p and 1080p pre-encoded

**Rationale:** Progressive release minimizes time-to-first-play, which is the creator-facing SLO. 720p and 1080p cover 95%+ of viewer demand and are pre-encoded to avoid JIT latency for common renditions. 4K is JIT to avoid the massive cost of encoding 4K for videos that will never be viewed at that resolution.

### When to Reconsider
- 4K viewer percentage exceeds 20% of total views → pre-encode 4K for videos above a view count threshold (e.g., > 10 K views).
- Creator SLA requires 4K at publish → pre-encode for creator-tier accounts (premium feature, passed as a priority flag to the transcode queue).

---

## Decision 4: Upload Chunking Strategy — Chunk Size and Resumability Protocol

### Options Considered

| Approach | Chunk Size | Resume Support | Protocol Complexity |
|---|---|---|---|
| **Single-shot upload** | Full file | None | Minimal |
| **Custom multipart** | 10 MB fixed | Byte-range based | Medium |
| **TUS protocol** | Configurable | Native (offset-based) | Standard (open spec) |
| **S3 multipart native** | 5 MB–5 GB | S3 UploadId + ETags | Medium |

### Trade-Offs

**Single-shot upload**
- Fails for large files on unreliable mobile networks. A 5 GB upload that fails at 95% requires a full restart.

**TUS protocol**
- Open standard; client libraries for iOS, Android, Web, Python, etc.
- Server stores upload offset in Redis (TTL 24 h); client resumes from last confirmed byte.
- Pro: Transparent to the underlying storage layer; works with S3, GCS, or local disk.
- Con: One additional protocol layer; minor overhead vs direct S3 multipart.

**S3 multipart native**
- Presigned part URLs expire independently; client can upload parts in parallel (up to 10 K parts, max 5 GB/part).
- Con: Client must implement ETag tracking and call CompleteMultipartUpload explicitly.
- Con: No standardized offset resume — client must track which parts succeeded.

### Final Choice: TUS over HTTPS with 10 MB chunks; each chunk maps to one S3 multipart part

**Rationale:** TUS provides a standard resume protocol with broad client library support. Mapping each TUS chunk to one S3 multipart part is a simple backend implementation. Upload Service stores the S3 UploadId and per-part ETags in Redis. On TUS HEAD (resume query), service returns the last confirmed offset. Client uploads only remaining chunks, then calls TUS PATCH to complete. Server calls `CompleteMultipartUpload` on the final PATCH.

### When to Reconsider
- If upload reliability is not a concern (desktop app with stable connectivity) → simplify to direct S3 multipart with presigned URLs (fewer server round-trips).
- File sizes consistently < 100 MB → single-shot upload with client-side retry is sufficient and simpler.

---

## Decision 5: Video Metadata Database — PostgreSQL vs Cassandra vs DynamoDB

### Options Considered

| Option | Write TPS (sustained) | Read latency | Transactions | Operational complexity |
|---|---|---|---|---|
| **PostgreSQL** | 10–15 K | 1–5 ms (indexed) | Full ACID | Medium |
| **Cassandra** | 100 K+ | 5–20 ms | None (LWT for lightweight) | High |
| **DynamoDB** | Unlimited (managed) | 5–15 ms | Limited (TransactWriteItems) | Low (managed) |

### Trade-Offs

**PostgreSQL**
- Required for the video publish transaction: update `videos.status`, insert rendition records, update `channel.video_count` — all atomically.
- At 115 uploads/sec (10 M/day), write TPS for the `videos` table is trivial for a single primary.
- Engagement writes (view increments, like counts) are buffered in Redis — only the periodic batch flush hits PostgreSQL.

**Cassandra**
- Appropriate if write TPS exceeds 10 K sustained to the primary table.
- No multi-table transactions — publish atomicity requires application-level compensation logic.
- Wide-column schema works for `watch_history` (partitioned by `user_id`, clustered by `video_id`).

**DynamoDB**
- Fully managed; no operational overhead for scaling, replication, or backups.
- `TransactWriteItems` limited to 25 items — sufficient for the publish transaction.
- Con: Limited query flexibility; secondary indexes are eventually consistent (GSI) or expensive (LSI).
- Con: At high scan volumes (search, analytics), DynamoDB becomes expensive vs PostgreSQL + Elasticsearch.

### Final Choice: PostgreSQL (primary metadata) + Cassandra (watch history, large engagement tables)

**Rationale:** PostgreSQL for `videos` and `transcode_jobs` — ACID guarantees are non-negotiable for the publish transaction. Cassandra for `watch_history` (high write throughput; partitioned by `user_id`; no transactional requirement) and engagement history. Sharding trigger for PostgreSQL: when `videos` table exceeds 500 M rows or write TPS exceeds 10 K → introduce Citus partitioning by `video_id` hash.

### When to Reconsider
- Multiple geographic write regions required → DynamoDB Global Tables or CockroachDB eliminates cross-region replication complexity.
- Video catalog exceeds 10 B rows → Cassandra with time-partitioned wide rows is more cost-effective than PostgreSQL at that scale.

---

## Decision 6: Thumbnail Generation Strategy

### Options Considered

| Approach | Generation Time | Cost | Quality |
|---|---|---|---|
| **Static frame extract** | < 5 s | Lowest | Unpredictable (may catch a bad frame) |
| **ML-based quality scoring** | 30–60 s | Medium | High (selects visually appealing frames) |
| **Sprite sheet + poster** | < 10 s | Low | Deterministic (every N seconds + first appealing frame) |
| **Creator-uploaded thumbnail** | N/A | Zero compute | Creator-controlled (often highest CTR) |

### Trade-Offs

**Static frame extract** — Simple, fast, but a random frame at a fixed timestamp (e.g., 5 s) often produces a poor thumbnail (blurred motion, black frame during scene cut).

**ML-based quality scoring** — Compute a frame quality score (sharpness, face detection, aesthetics) across N candidate frames; select the highest scorer. Adds 30–60 s to time-to-publish. Increases CTR by ~8% vs random frame in A/B tests.

**Sprite sheet** — Generate one low-res frame per 5 s as a sprite sheet (for timeline scrubbing preview). Simultaneously extract a poster image (highest quality frame in the first 30 s). Two separate outputs from one pass.

**Creator thumbnail** — Creators who upload their own thumbnail consistently outperform auto-generated thumbnails in CTR. Must be offered as an explicit option.

### Final Choice: ML frame quality scoring (async, post-publish) + sprite sheet (sync, pre-publish) + creator upload option

**Rationale:** Sprite sheet is generated synchronously during transcode (blocks publish only if missing). ML-scored poster frame is generated asynchronously after publish — the auto-selected frame is shown until ML scoring completes (~60 s later), then the CDN-cached thumbnail URL is updated. Creator thumbnail upload replaces both if provided. The three-tier system maximizes CTR without adding latency to the publish path.

### When to Reconsider
- ML scoring latency exceeds 5 min → drop ML scoring; use sprite-sheet poster only.
- A/B test shows creator thumbnails perform < 5% better than ML thumbnails → drop creator upload feature (simplify UX).

---

## Decision 7: Storage Tier Policy — When to Transition to Cold/Archive

### Options Considered

| Policy | Trigger | Simplicity | Cost Savings |
|---|---|---|---|
| **Age-based** | > 90 days since upload | Simple | Good for typical content |
| **View-count based** | < 100 views in last 30 days | Moderate | Better for content with tail views |
| **Hybrid (age + views)** | > 90 days AND < 10 views/day | Complex | Best |
| **Manual tagging** | Admin marks content as cold | Manual | Precise but operational burden |

### Final Choice: Hybrid policy — age > 90 days AND average daily views < 10 → cold; > 365 days AND < 1 view/day → archive

**Rationale:** Age-only policies prematurely archive content that is still actively watched (evergreen tutorials, viral videos). View-count-only policies keep all historical content warm unnecessarily. Hybrid correctly keeps popular content warm regardless of age and archives truly abandoned content.

**Implementation**: A daily Spark job reads `videos` + `analytics.daily_view_counts`, identifies candidates, and writes lifecycle tag updates to S3. S3 Intelligent-Tiering is an alternative but incurs per-object monitoring fees at 10 B+ object scale.

---

## Decision 8: CDN Pre-Warming vs Reactive Cache Fill

### Options Considered

| Approach | On Publish Spike | CDN Cost | Implementation |
|---|---|---|---|
| **Reactive (no pre-warm)** | Origin flood on first views | Low (no extra requests) | Zero complexity |
| **Pre-warm top PoPs** | Warm for first viewers | Small (50 HEAD requests) | Low |
| **Pre-warm all PoPs** | Near-zero origin on publish | Higher (200+ requests) | Medium |
| **Predictive pre-warm** | Scheduled events (sports, premieres) pre-warmed hours ahead | Variable | High |

### Final Choice: Pre-warm top 50 PoPs by traffic weight on publish; predictive pre-warm for scheduled high-traffic events

**Rationale:** Pre-warming 50 PoPs costs 50 GET requests at manifest size (~5 KB) = 250 KB of origin traffic — negligible. For a viral video with 2 M first-minute views from 200 PoPs, pre-warming reduces origin requests from 200 (cache-miss storm) to near zero. Predictive pre-warm for scheduled events (sports finals, movie premieres) is triggered via an admin API call specifying a video_id and a warm-at timestamp.

---

## Decision 9: Live Latency Target — Standard HLS vs LL-HLS vs WebRTC

### Options Considered

| Protocol | Latency | CDN Compatible | Scale | Complexity |
|---|---|---|---|---|
| **Standard HLS** | 10–30 s | Universal | Unlimited | Low |
| **LL-HLS** | 2–4 s | Yes (partial segment + preload hints) | Unlimited | Medium |
| **DASH-LL** | 2–4 s | Growing | Unlimited | Medium |
| **WebRTC** | < 500 ms | No (needs SFU) | Thousands per SFU | Very high |

### Final Choice: LL-HLS for all live streams; WebRTC reserved for Phase 2 interactive events (< 100 participants)

**Rationale:** LL-HLS achieves 2–4 s glass-to-glass without requiring a new CDN topology. WebRTC at millions of viewers requires an SFU relay that re-streams to CDN, recovering to 3–5 s latency anyway — nearly matching LL-HLS at massively higher operational cost and complexity. The only valid WebRTC use case is interactive two-way video (live auctions, Q&A sessions with real-time host response to audience) — a Phase 2 feature.

---

## Decision 10: Analytics — Real-Time vs Batch vs Lambda Architecture

### Options Considered

| Approach | Freshness | Query flexibility | Operational cost |
|---|---|---|---|
| **Batch only** (Spark daily) | 24 h stale | High (SQL on data lake) | Low |
| **Real-time only** (Flink) | Seconds | Medium (stream aggregations) | High |
| **Lambda** (batch + real-time) | Seconds for speed layer; hours for batch layer | High | Very high (two systems) |
| **Kappa** (Kafka + Flink + data lake) | Seconds | High (replay from Kafka) | Medium |

### Final Choice: Kappa architecture — Flink consumes Kafka `player-events`; writes to real-time dashboard store (Druid) and data lake (S3 Parquet) simultaneously

**Rationale:** Lambda's dual-codebase complexity is not justified. Kappa uses a single Flink job for both real-time aggregates (view counts, concurrent viewers, rebuffer ratio) and batch output (Parquet files for creator analytics). Kafka retention of 7 days allows historical reprocessing if the Flink job has a bug. Druid provides sub-second ad-hoc queries on real-time metrics; Athena/Spark queries the S3 data lake for deep analytics.
