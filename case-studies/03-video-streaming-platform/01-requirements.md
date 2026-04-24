# 1) Requirements & Scale

> Goal: Define what we are building, how big it needs to be, and the first-order constraints. Keep it brief and practical.

---

## What we are building (at a glance)

A large-scale video streaming platform (YouTube/Netflix-style) that lets creators upload, transcode, and publish videos — and lets viewers watch them on-demand or live with adaptive quality across any device and network.

Scope (Phase 1): Design only (no code), production-credible, cloud-friendly.

---

## Core requirements

### Functional

- **Upload**: Creators upload video files (MP4/MOV/MKV, up to 10 GB); chunked and resumable
- **Transcode**: Convert raw uploads to multiple formats and resolutions (360p → 4K) using H.264/H.265/AV1; package as ABR streams (HLS/DASH)
- **Stream (VOD)**: Adaptive bitrate playback; seek to any position; manual quality selector; autoplay next video
- **Live streaming**: Real-time ingest via RTMP/SRT; low-latency ABR delivery (target < 5 s glass-to-glass)
- **Search & Discovery**: Full-text search by title, tags, channel; trending feed; category browsing; personalized recommendations
- **Engagement**: Likes, comments, subscribe; view count; watch history; playlists; video sharing
- **Monetization**: Pre-roll, mid-roll, post-roll ads (VAST/VMAP); channel subscriptions; creator revenue share dashboard

### Non-functional

- **Playback latency**: Time to first frame p99 < 4 s; seek latency p95 < 1 s; ABR rendition switch < 500 ms
- **Availability**: 99.95%+ for playback; 99.9% for upload (async path tolerates brief interruptions)
- **Global reach**: CDN edge delivery; < 100 ms from 95% of users worldwide
- **Rebuffer ratio**: < 0.5% of total playback time (industry benchmark)
- **Cost efficiency**: Bandwidth is the largest OpEx — CDN offload and storage tiering are first-class concerns
- **Observability**: Per-region SLOs on TTFF, rebuffer ratio, CDN cache hit rate, transcode queue depth

---

## Scale targets (order-of-magnitude)

- **Users**: 500 M MAU; 100 M DAU
- **Uploads**: 10 M videos/day (roughly 115 uploads/s average; 500+ at peak)
- **Catalog**: 1 B+ videos at rest
- **Concurrent viewers**: 70 K average; 10 M peak (live events, viral moments)
- **Daily watch time**: 100 M hours/day (6 B minutes/day)
- **Bandwidth**: 10 M concurrent viewers × 5 Mbps (1080p avg) = 50 Tbps peak; 95%+ served by CDN

---

## Quick capacity math (back-of-envelope)

**Storage — raw uploads**
- 10 M uploads/day × 500 MB avg raw = 5 PB/day raw ingestion
- ABR transcoding produces ~4× the raw size across all renditions: 5 × 4 = 20 PB/day written to object storage
- After 90-day retention window, cold-archive to Glacier-class storage (~10× cheaper)

**Storage — long-term**
- Keep 30 days hot/warm: 20 PB/day × 30 = 600 PB active object storage
- Archive tier for older/low-view content: petabyte-scale Glacier buckets

**Bandwidth — CDN**
- 10 M peak concurrent × 5 Mbps = 50 Tbps total egress
- 95% CDN cache hit → ~2.5 Tbps origin egress at peak

**Compute sizing (transcode)**
- Target: transcode in ≤ 1× real-time (10-min video → done in < 10 min)
- Each rendition (360p/720p/1080p/4K) runs as an independent job
- Encode time per rendition per minute of source: ~0.5 CPU-min for 720p with FFmpeg
- 10 M uploads/day × 10 min avg duration × 3 renditions × 0.5 CPU-min = 250 M CPU-min/day → ~4 K vCPUs sustained; 20 K at peak

**Metadata DB**
- Upload events: 115 writes/s (easily single PostgreSQL primary)
- Engagement events: 100 M DAU × 10 actions = 1 B/day = 11 K writes/s → buffer in Redis; batch flush

---

## Constraints and guardrails

- Transcode must complete within 1× video duration (10-min video published in < 10 min)
- CDN is mandatory — never design for self-serving raw bandwidth at this scale
- ABR (HLS/DASH) is required; progressive download not acceptable
- GOP alignment must be enforced across all renditions for seamless ABR switching
- DRM (Widevine/FairPlay) optional per video; required for premium/paid content
- Copyright fingerprinting (ContentID-style) must run before video is published
- Mobile-first: 70% of traffic is mobile; auto-quality selection based on network conditions
- Storage lifecycle policies: auto-tier to cold after 90 days with no views
- E2E encryption not required (server-side is sufficient for Phase 1)
- Multi-region active-active out of scope; primary region + CDN global delivery for Phase 1

---

## Success measures

| Metric | Target |
|---|---|
| Time to first frame (p50 / p95 / p99) | < 800 ms / < 2 s / < 4 s |
| Seek latency (p95) | < 1 s |
| Rebuffer ratio | < 0.5% of playback time |
| CDN cache hit rate | > 90% |
| Upload success rate | > 99% |
| Transcode completion (p95) | < 2× video duration |
| Playback availability | > 99.95% |

---

## Out of scope (Phase 1)

- End-to-end encryption for video content at rest
- Full multi-region active-active write replication
- Advanced ML recommendation model (collaborative filtering only; deep learning models in Phase 2)
- Real-time comment moderation (async ML pipeline sufficient)
- Interactive live features (polls, live shopping, real-time Q&A)
- Detailed creator analytics beyond view counts and watch time aggregates
