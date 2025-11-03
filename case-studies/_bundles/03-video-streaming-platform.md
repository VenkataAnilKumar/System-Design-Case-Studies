# 03-video-streaming-platform - Video Streaming Platform
Generated: 2025-11-02 20:38:43 -05:00

---

<!-- Source: 01-requirements.md -->
# 1) Requirements & Scale

## Functional Requirements

- Upload: Users upload videos (MP4/MOV/etc., up to 10GB); chunked/resumable
- Transcode: Convert to multiple formats/resolutions (360p→4K); H.264/H.265/AV1; ABR packaging (HLS/DASH)
- Stream: Adaptive bitrate playback; seek; quality selector; autoplay next
- Search & Browse: Title/tag/channel search; trending, categories, recommendations
- Engagement: Like/comment/subscribe; view counts; watch history; playlists
- Monetization: Pre/mid/post-roll ads; subscriptions; creator revenue share
- Live streaming: Real-time ingest, low-latency playback (sub-5s glass-to-glass)

## Non-Functional Requirements

- Low latency: Video start < 2s; seek < 1s; ABR switch < 500ms
- High availability: 99.95%+
- Global reach: CDN edge delivery; <100ms from 95% of users
- Cost efficiency: Bandwidth is largest OpEx; optimize transcode/storage tiers
- Observability: Buffer ratio, start time, quality distribution, CDN hit rates

## Scale & Back-of-the-Envelope

- Users: 500M MAU; 100M DAU
- Videos: 1B+ catalog; 10M uploads/day
- Viewing: 100M hours/day → 6B minutes/day → 70K concurrent avg; 10M peak
- Storage: 10M uploads/day × 500MB raw + 4× for ABR tiers → ~20PB/day ingested; cold archive after 90 days
- Bandwidth: 10M concurrent × 5Mbps (1080p) = 50Tbps peak; 95% offloaded to CDN

## Constraints & Assumptions

- Transcode time target: ~real-time (10 min video → transcode in <10 min)
- DRM optional (Widevine/FairPlay) for premium content
- Copyright/ContentID detection on upload
- Mobile-first (70% traffic); auto quality based on network

## Success Measures

- Time to first frame (p50/p95/p99)
- Rebuffer ratio (% of playback time buffering; target <0.5%)
- CDN cache hit rate (target >90%)
- Upload success rate (target >99%)
- Viewer engagement (watch time per session)




---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
  subgraph Clients
    Creator[Creator App]
    Viewer[Viewer App/Browser]
  end

  subgraph Edge
    CDN[CDN (Akamai/Cloudflare)\n90%+ cache hit]
    LB[Load Balancer]
  end

  subgraph Core Services
    UploadSvc[Upload Service\nChunked multipart]
    VideoSvc[Video Service API\nMetadata CRUD]
    TranscodeSvc[Transcode Workers\nFFmpeg + GPU]
    SearchSvc[Search Service\nElasticsearch]
    RecoSvc[Recommendation Engine\nML models]
    AdSvc[Ad Service\nVAST/VMAP]
    AnalyticsSvc[Analytics Service]
  end

  subgraph Data & Messaging
    Redis[(Redis/Memcache\nMetadata/Thumbnails)]
    PG[(PostgreSQL\nVideo metadata)]
    S3Raw[(Object Storage\nRaw uploads)]
    S3ABR[(Object Storage\nABR segments)]
    Kafka[Kafka\nEvent Stream]
    ES[(Elasticsearch\nSearch index)]
  end

  Creator --> LB --> UploadSvc
  Viewer --> CDN
  Viewer --> LB --> VideoSvc
  
  UploadSvc --> S3Raw
  UploadSvc --> Kafka
  Kafka --> TranscodeSvc
  TranscodeSvc --> S3Raw
  TranscodeSvc --> S3ABR
  TranscodeSvc --> PG
  
  CDN --> S3ABR
  VideoSvc --> Redis
  VideoSvc --> PG
  VideoSvc --> ES
  SearchSvc --> ES
  RecoSvc --> PG
  
  Viewer -.->|heartbeat| AnalyticsSvc
  AnalyticsSvc --> Kafka
```

## Components (What/Why)

- Upload Service: Chunked multipart upload (S3/GCS); resumable; MD5 checksum; metadata capture
- Transcode Service: Distributed workers (FFmpeg + GPU); parallel jobs per resolution; output ABR segments (HLS .m3u8 + .ts chunks or DASH .mpd + .mp4 segments)
- Storage:
  - Hot (Redis/Memcache): Metadata, thumbnails, manifests for popular videos
  - Warm (Object storage + CDN): Recent/popular ABR segments
  - Cold (Glacier/archive): Old or low-view content; restore on demand
- CDN: Multi-tier edge (Akamai/Cloudflare/Fastly); 90%+ cache hit; origin-shield to protect backend
- Video Service (API): Metadata CRUD; watch history; playlists; like/comment aggregation
- Search/Recommendation: Elasticsearch for text search; ML models for personalized feed (collaborative filtering + content features)
- Ad Service: VAST/VMAP decisioning; server-side ad insertion (SSAI) for live; client-side for VOD
- Analytics: Real-time dashboards (view counts, concurrent); batch aggregation (Spark/Flink) for creator dashboards

## Data Flows

### A) Upload → Transcode → Publish

1) User → Upload Service: chunked POST; stores raw video in object storage (bucket: raw-uploads)
2) Emit upload.completed event (Kafka)
3) Transcode workers consume event:
   - Fetch raw video
   - Parallel transcode jobs: 360p, 720p, 1080p, 4K (if source quality allows)
   - Package ABR: HLS (m3u8 master + per-resolution playlists + .ts segments) or DASH (mpd + .mp4 segments)
   - Write segments to object storage (bucket: vod-abr)
   - Generate thumbnails (sprite sheet for timeline hover)
4) Update video metadata: status=ready, abr_manifest_url, duration, thumbnail_url
5) Optional: ContentID scan; ad markers insertion; DRM key wrapping

### B) Playback (VOD)

1) Client → Video Service: GET /videos/:id → metadata + ABR manifest URL (CDN URL)
2) Client fetches manifest (e.g., master.m3u8) from CDN
3) CDN cache hit (90%+ case) → serve from edge
4) CDN cache miss → origin pull from object storage; cache at edge with TTL
5) Client selects initial bitrate (based on bandwidth estimate); fetches segments (.ts or .mp4)
6) Adaptive logic: measure throughput; switch up/down bitrates seamlessly
7) Periodically: client sends heartbeat (watch progress, buffer events) → Analytics Service

### C) Live Streaming

1) Creator → Ingest endpoint (RTMP/SRT/WebRTC): real-time video chunks
2) Live Transcoder: segment on-the-fly into ABR tiers; publish sliding window manifest (last N segments)
3) CDN pulls manifest + segments; viewers watch with 3–10s latency (HLS) or sub-3s (LL-HLS/DASH low-latency)
4) Archive stream to VOD after broadcast ends

## Minimal Data Model

- videos(id PK, uploader_id, title, description, duration, status[uploading|transcoding|ready|failed], abr_manifest_url, thumbnail_url, view_count, created_at)
- watch_history(user_id, video_id, timestamp, progress_sec)
- engagement(video_id, likes, comments_count, shares; denormalized counters updated async)
- transcode_jobs(job_id PK, video_id FK, resolution, status[queued|processing|done|failed], worker_id, created_at)

Indexes: videos(uploader_id, status, created_at desc), watch_history(user_id, timestamp desc)

## APIs (Examples)

- POST /v1/videos/upload {title, file_chunks, …}
- GET /v1/videos/:id {metadata + manifest_url}
- GET /v1/videos/:id/manifest.m3u8 (CDN URL, not API; serves HLS manifest)
- POST /v1/videos/:id/heartbeat {progress_sec, buffer_events}
- GET /v1/search?q=…
- GET /v1/recommendations?user_id=…

Auth: JWT; rate-limit uploads per user; validate video ownership for edits

## Why These Choices

- ABR (HLS/DASH): Industry standard; client adapts to network; smooth quality transitions
- Object storage + CDN: Cost-effective for massive scale; pay per GB served; CDN absorbs spikes
- Transcode parallelism: One raw video → N independent jobs (by resolution); scales horizontally
- Cold storage: Rarely-watched videos archived; restore latency acceptable (minutes) vs. cost savings
- Async analytics: Decouple playback hotpath from view-count updates; eventual consistency fine for counters

## Monitoring Cheat-Sheet

- Playback: time-to-first-frame p50/p95/p99; rebuffer ratio; quality distribution
- Transcode: job backlog; processing time per resolution; failure rate
- CDN: cache hit rate; origin bandwidth; edge error rate
- Upload: success rate; resume/retry count; average upload time
- Storage: hot/warm/cold tier usage; cost per GB-month




---

<!-- Source: 03-key-decisions.md -->
# 3) Key Decisions (Trade-offs)

## 1) ABR Protocol: HLS vs DASH
- HLS (Apple): Dominant on mobile/iOS; simple .m3u8 + .ts; supported everywhere
- DASH (MPEG): Open standard; better for live low-latency; more complex
- Choice: HLS primary; DASH optional for advanced live or Android-heavy markets

## 2) Transcode Strategy: Just-in-Time vs Pre-Transcode
- JIT: Transcode on first view → save cost for unpopular videos
- Pre-transcode: All resolutions upfront → predictable latency; better UX
- Choice: Pre-transcode top tiers (360p, 720p, 1080p); JIT for 4K if source allows and demand exists

## 3) Storage Tiers
- Hot (CDN edge): Recent/popular; milliseconds latency
- Warm (origin object storage): Older but accessible; seconds latency
- Cold (Glacier): Rarely watched; minutes restore; 10× cheaper
- Policy: Auto-tier after 90 days no views; restore on demand with acceptable delay

## 4) CDN vs Self-Host Edge
- CDN (Akamai/Cloudflare): Pay per GB; global PoPs; elastic
- Self-host: CapEx heavy; complex operations; saves long-term cost at massive scale
- Choice: CDN for <1PB/month; consider hybrid/self-host at Netflix/YouTube scale (100+ PB/month)

## 5) Live Streaming Latency
- Traditional HLS: 10–30s glass-to-glass
- Low-latency HLS/DASH: 3–5s (chunked transfer encoding, smaller segments)
- WebRTC: Sub-second but complex; not CDN-friendly
- Choice: LL-HLS for live events; accept 3–5s for cost/scale balance

## 6) DRM and Content Protection
- Widevine (Android/Chrome), FairPlay (Apple), PlayReady (Microsoft)
- Adds complexity (license servers, key rotation)
- Choice: Optional per video; enable for premium/paid content only

## 7) Recommendation Engine
- Collaborative filtering: User-item matrix; similar users/videos
- Content-based: Video metadata (tags, category, creator)
- Hybrid: Combine both; use deep learning (embeddings) at scale
- Choice: Start simple (CF + content); evolve to neural models with scale

## 8) Analytics Real-Time vs Batch
- Real-time: Kafka → stream processing (Flink) → dashboards (live view counts)
- Batch: Daily ETL (Spark) → data warehouse (Snowflake/BigQuery) → creator analytics
- Choice: Hybrid; real-time for operational metrics; batch for deep insights




---

<!-- Source: 04-wrap-up.md -->
# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Transcode: Horizontal GPU workers; priority queue for popular creators/channels
- CDN: Multi-CDN strategy (primary + fallback); auto-scale edge capacity during events
- Storage: Shard object storage by video_id prefix; use lifecycle policies for cold tiering
- Database: Shard videos table by uploader_id or region; read replicas for metadata reads
- Search: Elasticsearch cluster with sharding; cache popular queries in Redis

## Failure Scenarios
1) Transcode Backlog Spike
- Impact: New uploads stuck in "processing" for hours
- Mitigation: Auto-scale workers; prioritize by creator tier; show estimated wait time; fallback to raw video playback (480p passthrough)

2) CDN Origin Overload
- Impact: Cache misses hammer origin; slow playback start
- Mitigation: Origin shield (mid-tier cache); rate-limit origin requests; pre-warm cache for viral videos

3) Live Stream Ingest Failure
- Impact: Broadcast drops; viewers see error
- Mitigation: Multi-region ingest endpoints; auto-failover; buffering at ingest layer; alert creator immediately

4) Storage Tier Migration Bug
- Impact: Videos moved to cold tier too early; restore latency spikes
- Mitigation: Dry-run tier policies; manual override for popular channels; monitor restore request rates

## SLOs & Metrics
- Playback: p95 time-to-first-frame < 2s; rebuffer ratio < 0.5%; ABR quality p50 > 720p
- Upload: success rate > 99%; transcode completion < 10 min for p95
- CDN: cache hit > 90%; origin bandwidth < 5% of total
- Availability: 99.95% for playback; 99.9% for upload (more tolerance for async path)

## Pitfalls and Gotchas
- Codec compatibility: Not all devices support H.265/AV1; fallback to H.264
- Seek performance: Keyframe alignment matters; too few keyframes → slow seeks
- Viral spikes: Pre-warm CDN for scheduled events (sports, premieres); auto-throttle otherwise
- Copyright strikes: False positives; provide appeal flow; don't auto-delete without review

## Interview Talking Points
- ABR explained: how client measures bandwidth and switches bitrates seamlessly
- Transcode pipeline: parallel jobs, priority queues, GPU vs CPU trade-offs
- CDN economics: why bandwidth is the largest cost; cache hit optimization strategies
- Live vs VOD: latency vs scale trade-offs; HLS vs WebRTC

## Follow-up Q&A
- Q: How do you handle 4K at scale?
  - A: JIT transcode; only for high-demand videos; use AV1 for better compression; expensive but growing
- Q: Content moderation for uploads?
  - A: ML models (NSFW detection, violence); human review queue for borderline; copyright fingerprinting (ContentID)
- Q: Multi-region strategy?
  - A: Upload to nearest region; replicate to others async; CDN pulls from closest origin; metadata global (multi-region DB)
- Q: Cost optimization tips?
  - A: Aggressive caching; cold tiering; codec efficiency (AV1 saves 30% bandwidth); negotiate CDN contracts at scale

---

This video streaming design balances cost (storage tiers, CDN, compression) with UX (ABR, low latency, high availability), using distributed transcode workers, global CDN delivery, and tiered storage to serve billions of videos to hundreds of millions of concurrent viewers.



