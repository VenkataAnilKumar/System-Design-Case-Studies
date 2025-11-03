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
