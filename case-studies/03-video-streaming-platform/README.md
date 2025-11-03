# Video Streaming Platform

## Problem Statement

Design a **YouTube/Netflix-like video streaming platform** that delivers high-quality adaptive video to millions of concurrent viewers globally.

**Core Challenge**: Handle 500M monthly active users watching 100M hours/day (70K concurrent avg, 10M peak) with low latency (video start <2s, seek <1s) and minimal buffering (<0.5% rebuffer ratio).

**Key Requirements**:
- Video upload with chunked/resumable transfers (up to 10GB)
- Multi-format transcoding (360p→4K, H.264/H.265/AV1)
- Adaptive bitrate streaming (HLS/DASH)
- Global CDN delivery (<100ms from 95% of users)
- Search, recommendations, engagement (like/comment/subscribe)
- Live streaming with low latency (<5s glass-to-glass)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100M DAU, 10M peak concurrent, 50Tbps bandwidth) |
| [02-architecture.md](./02-architecture.md) | Components (Upload Service, Transcoding Pipeline, CDN, Playback API) |
| [03-key-decisions.md](./03-key-decisions.md) | ABR algorithms, CDN strategy, transcoding optimization, storage tiers |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to 1B videos, cost optimization, failure scenarios, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Time to First Frame** | p95 <2s |
| **Seek Latency** | <1s |
| **Rebuffer Ratio** | <0.5% of playback time |
| **CDN Cache Hit Rate** | >90% |
| **Transcoding Speed** | Real-time (10 min video → <10 min transcode) |

## Technology Stack

- **Upload**: Chunked upload with resumability (S3 multipart)
- **Transcoding**: FFmpeg on spot instances, parallel job queue
- **ABR Packaging**: HLS/DASH manifest generation
- **CDN**: Multi-tier (edge, regional, origin), 95% cache hit
- **Storage**: Hot (SSD), Warm (HDD), Cold (Glacier) tiering
- **Metadata**: PostgreSQL/DynamoDB for video catalog

## Interview Focus Areas

1. **Adaptive Bitrate**: Client-side bandwidth detection, quality switching
2. **Transcoding Pipeline**: Parallel job execution, spot instance optimization
3. **CDN Strategy**: Cache warming, purge propagation, origin shielding
4. **Cost Optimization**: Bandwidth is 70% of OpEx (CDN offload, compression)
5. **Live Streaming**: Low-latency HLS (LL-HLS), sub-5s glass-to-glass
