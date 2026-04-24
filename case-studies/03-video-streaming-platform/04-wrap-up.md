# Chapter 4 — Wrap-Up

> Operational readiness, failure playbook, SLOs, and interview prep.

---

## Scaling Playbook

| Dimension | Trigger | Primary Action | Secondary Action |
|---|---|---|---|
| Upload throughput | Chunk error rate > 1% or multipart abort rate rising | Scale Upload Service pods; verify S3 health | Increase chunk retry backoff; shed non-critical API traffic |
| Transcode backlog | Kafka consumer lag > 5 K messages on any rendition topic | Auto-scale worker fleet (spot VMs, per-tier queues) | Increase Kafka partition count; prioritize 360p/720p to unblock earliest video availability |
| Metadata DB reads | p95 read latency > 100 ms or read replica CPU > 70% | Add Redis cache for hot video rows (30 s TTL) | Add read replica; partition `watch_history` to a separate cluster |
| Metadata DB writes | Replication lag > 5 s or primary write TPS > 12 K | Batch engagement writes via Redis flush; reduce view count flush frequency | Introduce Citus sharding by `video_id` hash |
| CDN origin overload | Origin request rate > 10% of total CDN requests | Increase manifest CDN TTL; add origin shield region | Pre-warm CDN proactively on publish; shift traffic weight to under-loaded CDN vendor |
| Search degradation | Elasticsearch query p95 > 200 ms | Add replica shards; tune shard allocation | Enable query result cache for top-1000 search terms |
| Analytics pipeline lag | Flink processing delay > 60 s | Increase Flink task manager count and parallelism | Increase Kafka partition count for `player-events` topic |
| Live ingest capacity | Active stream count > 80% of ingest node capacity | Auto-scale live ingest fleet | Add a PoP in the overloaded region; rebalance stream assignments |

**Scaling philosophy**: The delivery plane (CDN to client) scales horizontally without bound — CDN vendors handle it. All constraints land on the write side: transcode workers, the metadata DB, and the analytics pipeline. Design for independent scaling of each write component; avoid coupling transcode throughput to metadata write throughput — they have very different load profiles.

---

## Failure Scenarios

### Scenario 1: Transcode Worker Crash Mid-Rendition

**Scenario**: A spot VM running a 1080p encode is preempted. FFmpeg is killed after producing 60% of the rendition segments.

**Impact**: The 1080p rendition is incomplete. Other renditions on separate VMs are unaffected. Video is not published because the orchestrator requires all required renditions before flipping status to `published`.

**Detection**: Kafka consumer heartbeat stops. After 30 s, the broker marks the consumer dead and re-queues the message. The coordinator detects the missing rendition checkpoint in Redis.

**Mitigation**: Before encoding, the new worker checks whether the rendition already exists in S3. If complete, mark done without re-encoding. If not, re-encode from scratch — simpler and safer than partial segment resume for most codec configurations.

**Recovery**: New worker picks up the message within 30–90 s of preemption. Maximum publish delay equals one full rendition encode time. AWS Spot interruption notices provide a 2-minute warning; use this window to checkpoint and gracefully exit.

---

### Scenario 2: Thundering Herd on Viral Video Publish

**Scenario**: A video goes live and is shared widely. Two million users click the link within 60 seconds. CDN edge has a cold cache.

**Impact**: Two million manifest requests hit CDN PoPs with no cached copy. Without origin shield, each of 200 PoPs makes an independent origin request, flooding the Manifest Service.

**Detection**: CDN cache hit rate for the video drops to near zero. Origin request rate spikes 100×. API Gateway error rate alarm fires if origin becomes saturated.

**Mitigation**: Publish Service issues synthetic HEAD requests to the top 50 CDN PoPs immediately after `status = published`. Manifest Service caches the signed manifest URL in Redis for 30 s — only the first origin fetch is a true miss. S3 handles tens of thousands of requests/sec per prefix without rate limiting.

**Recovery**: After 2–3 CDN request cycles (~15 s), the edge is warm and origin traffic returns to baseline. At worst, the first wave of viewers sees 100–500 ms additional TTFF. No availability impact.

---

### Scenario 3: CDN Vendor Partial Outage

**Scenario**: Primary CDN vendor experiences degraded performance in a region. Segment fetch times increase from 30 ms to 2–5 s; some requests return 504.

**Impact**: Viewers in the affected region see rebuffering and elevated TTFF. Regional rebuffer ratio rises above the 1% alert threshold.

**Detection**: Synthetic probes (HTTP HEAD to a known segment URL, every 30 s per vendor per region) detect p95 TTFB exceeding 500 ms. Player telemetry shows rebuffer ratio spike localized to the affected region.

**Mitigation**: Multi-CDN traffic manager shifts DNS weight away from the degraded vendor. DNS TTL is 60 s; the shift propagates to new clients within one TTL. In-flight sessions continue on the current CDN until their DNS cache expires (60–120 s).

**Recovery**: Traffic weights restored gradually after vendor resolves: 10% → 30% → 50% → 100%, with synthetic probe verification at each step. Total viewer impact: 1–3 minutes of degraded quality.

---

### Scenario 4: PostgreSQL Primary Failure

**Scenario**: PostgreSQL primary instance becomes unresponsive due to a hardware fault. All write operations fail immediately.

**Impact**: Upload initiation returns 500 errors. Transcode status updates fail. Redis view count flushes queue up. Read replicas remain available — video page loads and search continue working.

**Detection**: PgBouncer reports connection failures to primary. APM write-path error rate spikes. Patroni health check fails for the primary node.

**Mitigation**: Patroni promotes the synchronous standby to primary within 15 s. Synchronous replication guarantees zero data loss. PgBouncer reconnects to the new primary automatically.

**Recovery**: Full write availability restored within 30 s. Former primary replaced with a new standby within 5–10 minutes. Redis flush backlog drains within the next 60 s cycle with no data loss (all events were already in Kafka).

---

### Scenario 5: S3 Regional Outage

**Scenario**: Primary AWS region hosting the ABR object store experiences broad S3 degradation. Segment fetches from origin fail or time out.

**Impact**: CDN cache misses that would normally hit S3 origin now fail. Popular content already in CDN cache (the majority) is unaffected. Long-tail content not in CDN cache returns errors.

**Detection**: S3 `5xxErrors` metric spikes. CDN origin error rate exceeds 5%. Synthetic playback probes for cache-miss test URLs fail.

**Mitigation**: Cross-region replication is enabled on the `vod-abr/` prefix. CDN origin failover configuration points to the secondary region bucket. DNS weight update shifts CDN origin CNAME from the primary region to the secondary. Replication lag is typically < 15 min for new objects.

**Recovery**: Full playback availability restores once origin failover DNS change propagates (60–120 s). Transcode pipeline is paused or redirected to write to the secondary region during the outage. After primary region recovers, a reconciliation job verifies replication consistency.

---

### Scenario 6: Kafka Broker Failure

**Scenario**: One Kafka broker in the `transcode-jobs` cluster fails. Partitions on that broker become temporarily unavailable.

**Impact**: Transcode jobs for affected partitions pause until partition leadership is re-elected. Upload completions queued or returning errors. No data lost with RF=3.

**Detection**: Kafka under-replicated partition count rises above zero. Consumer lag begins growing. Kafka producer errors rise in Upload Service metrics.

**Mitigation**: With RF=3, Kafka elects a new leader for affected partitions within 30 s. Producers reconnect and resume publishing. Consumer groups automatically rebalance assignments to surviving brokers.

**Recovery**: Full throughput restored within 60 s of broker failure. The brief pause in transcode job delivery adds at most 1–2 minutes to affected video transcode times. Failed broker replaced; partitions sync in background.

---

### Scenario 7: Live Stream Ingest Node Failure

**Scenario**: A live ingest node crashes while actively receiving 200 live streams.

**Impact**: All 200 streams lose their RTMP connection. Viewers see the live stream freeze and eventually receive a "stream offline" error after 10–15 s of silence.

**Detection**: Ingest node health check fails. Stream health dashboard shows 200 streams simultaneously dropping to zero bitrate. Alert fires within 30 s.

**Mitigation**: Broadcaster software is configured with automatic reconnect (OBS default: retry every 5 s, up to 10 retries). Anycast DNS for the ingest endpoint routes reconnecting broadcasters to the next-nearest healthy node.

**Recovery**: Broadcasters reconnect; streams resume within 10–20 s. Viewers experience a gap in the live timeline. If DVR is enabled, viewers can scrub back to the last segment before the gap. Post-incident: implement stream state handoff protocol (primary/secondary ingest node per stream) to enable sub-5 s failover without broadcaster reconnect.

---

## SLOs and Metrics

| Metric | p50 | p95 | p99 | Source |
|---|---|---|---|---|
| Time to first frame (TTFF) | < 800 ms | < 2 s | < 4 s | Client player SDK telemetry |
| Seek latency | < 400 ms | < 900 ms | < 2 s | Client player SDK telemetry |
| ABR rendition switch time | < 200 ms | < 500 ms | < 1 s | Client player SDK telemetry |
| Rebuffer ratio | — | < 0.5% of playback time | < 1% | Client player SDK telemetry |
| Upload success rate | — | — | > 99% | Server-side upload completion event |
| Transcode completion time | < 1× duration | < 2× duration | < 5× duration | Job timestamps in Metadata DB |
| API latency (read) | < 30 ms | < 100 ms | < 300 ms | APM traces per endpoint |
| API error rate (5xx) | — | — | < 0.1% | API Gateway access logs |
| CDN cache hit rate | — | — | > 90% | CDN vendor analytics API |
| Live glass-to-glass latency (LL-HLS) | < 2 s | < 4 s | < 8 s | Reference clock comparison |
| Search result latency | < 50 ms | < 150 ms | < 300 ms | Elasticsearch slow log + APM |

**Error budget**: At 99.95% playback availability, monthly error budget = 22 minutes. Major incidents should consume < 15 minutes/month; remaining 7 minutes covers planned maintenance. Track error budget burn rate weekly; freeze risky deploys when burn rate exceeds 2×.

---

## Pitfalls and Gotchas

**1. Assuming CDN cache hit rate starts high.** A newly published video has a cold CDN cache. The first N requests all hit origin. Without pre-warming and origin shields, a viral publish creates an origin flood. CDN cache hit rate is a trailing metric — pre-warming is the only way to get ahead of it.

**2. Signing individual segment URLs at application scale.** At 10 M concurrent viewers × 1 segment request per 4 s = 2.5 M signing operations/sec — CPU-prohibitive. Use CDN-level signed tokens scoped to a path prefix (`/vod-abr/{video_id}/*`). One token covers all segments for a video.

**3. Using the same Kafka topic for all rendition tiers.** A flood of 4K encode requests (slow, expensive) can starve 360p encodes (fast, cheap). A 5-minute 360p encode should not wait behind a 90-minute 4K encode. Use separate topics per rendition tier; tune consumer group sizes independently.

**4. Storing view counts as direct DB writes.** At 10 M concurrent viewers, naive view_count increments collapse a standard RDBMS. Buffer view counts in Redis INCR; flush periodically to DB. 60-second eventual consistency is acceptable for display.

**5. Forgetting GOP alignment across renditions.** HLS/DASH ABR switching requires identical keyframe timestamps across all renditions. If 360p has a keyframe at t=4.02 s and 1080p at t=4.15 s, switching renditions at that boundary causes a visible stutter. Scene-change detection must run before encoding, and all renditions must use the same GOP boundaries.

**6. Underestimating live chat scale.** A live stream with 500 K concurrent viewers and chat enabled generates ~10 K chat messages/min (2% of viewers send one message per 3 minutes). Naive broadcast: 500 K × 10 K/min = 5 B deliveries/min. Fan-out must be rate-limited (show 30 messages/s max in the UI regardless of actual rate). Backend must use tiered fan-out: Redis Pub/Sub for < 10 K viewers; Kafka topic per stream for > 10 K.

**7. DRM license server as a single point of failure.** If the DRM license server is unavailable, no new playback sessions can start for protected content. DRM licenses should be cached on the client for the session duration (not re-fetched per segment). Treat DRM provider availability as a dependency in SLO calculations.

**8. Deleting raw files before transcode is confirmed complete.** If S3 lifecycle rules delete the raw file before all renditions are confirmed written, a worker crash means the video cannot be re-processed. Keep raw files for at least 7 days after `status = published`. Only then move to Glacier or delete.

---

## Interview Talking Points

**Q: Where do you start when asked to design a video streaming platform?**

Start by separating the two fundamentally different pipelines: the ingest pipeline (upload → transcode → publish, write-heavy, async, compute-bound) and the delivery pipeline (manifest → segments → client, read-heavy, latency-critical, CDN-dominated). Candidates who conflate these two paths reveal a gap in understanding. Establish scale numbers: 10 M uploads/day drives transcode sizing; 10 M concurrent viewers at 5 Mbps drives CDN sizing. These are very different workloads with very different bottlenecks.

**Q: Why is CDN so important here?**

CDN absorbs 95%+ of all video egress. The origin stack is sized for only 5% of traffic. Without CDN, you would need to operate 50 Tbps of egress from your own servers — physically and economically impossible for most organizations. The CDN hit rate is the most important cost metric in the entire system. Every percentage point of cache hit rate improvement directly reduces origin cost and improves latency for cache-miss traffic.

**Q: Why not just use WebRTC for live streaming?**

WebRTC is designed for small-group communication (< 10 participants without a relay). Scaling to millions of concurrent viewers requires an SFU that re-streams WebRTC to a CDN — at which point latency increases to 3–5 s anyway, nearly matching LL-HLS. LL-HLS achieves 1–3 s latency, works with existing CDN infrastructure, and requires no new client-side protocol. WebRTC is correct for interactive two-way video (video calls, live auctions), not one-to-many broadcast.

**Q: How does seek work without downloading the entire file?**

HLS and DASH manifests map wall-clock timestamps to segment sequence numbers. Each segment is 4–6 seconds of video stored as a separate S3 object. A seek to position T requires fetching the segment at `floor(T / segment_duration)`. The player flushes its buffer and requests that segment plus the subsequent N segments for its lookahead buffer. There is no need to download or buffer the content between the current position and the seek target — this is why segment-based streaming fundamentally outperforms progressive download for seeking.

---

## Follow-Up Q&A

**Q: How do you handle a 10 GB upload from a mobile client on a flaky LTE connection?**

TUS protocol with 10 MB chunks. Client splits the file locally, uploads each chunk as a separate S3 multipart part using a presigned URL, and records the ETag for each successfully uploaded part. If the connection drops, the client queries the server for the last confirmed offset on next open and resumes from that chunk. The server stores the offset in Redis with a 24-hour TTL. Incomplete uploads are cleaned up from S3 after 24 hours via a lifecycle expiry rule. Five concurrent chunk uploads saturate available LTE bandwidth without overloading any single TCP connection.

**Q: How do you prevent a creator from uploading copyrighted content?**

Two-phase approach: (1) At upload time, an audio fingerprint (chromaprint) and a video perceptual hash are computed against the assembled raw file before it enters the transcode queue. Fingerprints are matched against a rights database. A match triggers a hold, block, or revenue-claim action per the rights holder's policy. (2) The transcode pipeline is blocked or proceeds with a monetization flag depending on the policy result. ContentID-style systems do not prevent upload — they detect after upload and respond per policy.

**Q: How would you redesign this for a short-form video platform (TikTok-style) with 60-second max duration?**

Several constraints change: (1) Files < 50 MB, so chunked upload is unnecessary — single-shot multipart upload is sufficient. (2) Transcode time is trivially fast (< 30 s for all renditions of a 60-second video); the real-time transcode SLO is not challenging. (3) The recommendation feed is the product — the engineering investment shifts to the recommendation and ranking pipeline. (4) CDN strategy stays the same. (5) Video-to-video swipe transition requires pre-fetching the next 2–3 videos' first segments into the player buffer before the user completes the current video — drives up CDN traffic per session but dramatically reduces perceived TTFF on navigation.

**Q: At what scale does PostgreSQL stop being sufficient for video metadata?**

A single PostgreSQL primary handles ~10–15 K write TPS with connection pooling. With 5 read replicas and Redis caching (80%+ hit rate), the read path handles 500 K+ read TPS effectively. Upload events (115 writes/sec) are well within single-primary capacity. The problem is engagement tables: 100 M DAU × 10 interactions/session = 1 B events/day = ~11 K writes/sec. Redis batching keeps this off the primary for view counts. For comments and likes at full scale: partition by `video_id` hash using Citus, or move engagement to a separate Cassandra cluster.

**Q: How does the recommendation system handle a completely new user with no watch history?**

Cold-start uses a three-stage fallback: (1) Onboarding signal: during registration, show the user topic cards (Sports, Music, Gaming) and ask them to select interests. These topic tags seed content-based recommendation. (2) Session context: within the first session, each video the user watches updates a session embedding. After 3–5 watches, the two-tower model has enough signal to produce personalized recommendations within that session. (3) Geographic and demographic trending: for users who skip onboarding, serve the trending feed for their region and device type as the default. The system never shows an empty feed; it progressively personalizes as signal accumulates.

**Q: How would you add support for multiple audio tracks (dubbed content)?**

HLS and DASH both support multiple audio renditions in a single manifest. In HLS, `#EXT-X-MEDIA` tags declare alternate audio tracks. Each audio track is a separate AAC encode stored as a separate rendition in S3. The transcode pipeline accepts multiple audio input files and produces one encoded audio rendition per language. Shaka Packager generates the manifest with all audio group references. At playback, the player downloads video segments from the selected quality rendition and audio segments from the selected language track independently, muxing them in the player. This enables language switching without rebuffering the video track.

---

## Closing Summary

A video streaming platform at YouTube/Netflix scale is two distinct engineering problems: a write-heavy async pipeline (upload → transcode → publish) and a read-heavy latency-critical delivery system (CDN → manifest → segments → player). The transcode pipeline is the cost center; the CDN is the scale multiplier. Get the CDN cache hit rate above 90% and the origin stack becomes nearly irrelevant for delivery. Get the transcode pipeline working on spot VMs with per-rendition parallelism and the compute cost is manageable.

The decisions that matter most are not which database or which queue — they are: how do you structure segment URLs for maximum CDN caching (content-addressed, immutable); how do you decouple the transcode pipeline from the delivery path so a transcode backlog never affects playback; and how do you design ABR manifests so the client can always find the right quality level without the server needing to know the viewer's bandwidth. Everything else is implementation detail.
