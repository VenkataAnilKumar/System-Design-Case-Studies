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
