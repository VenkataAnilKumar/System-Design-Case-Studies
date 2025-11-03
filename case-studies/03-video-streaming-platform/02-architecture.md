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
