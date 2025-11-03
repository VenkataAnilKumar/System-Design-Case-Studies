# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Ingest: RTMP (OBS, encoders), SRT (loss-resilient), WHIP/WHEP for WebRTC ingest
- Auth: Stream keys, OAuth for creators; per-stream ACL (subscribers-only, geo-block)
- Transcoding: Per-title encoding ladder; audio transcode; subtitles/closed captions
- Packaging: HLS/DASH; LL-HLS with CMAF; DVR (rolling window, e.g., 2 hours)
- Delivery: Global CDN; tokenized URLs; DRM (FairPlay/Widevine) optional
- Interactive: WebRTC SFU rooms for <500ms latency; live chat; reactions; polls
- Stream Lifecycle: Start/stop; preview; health metrics; auto-reconnect; fallback slates
- VOD: Auto-archive streams to VOD; clipping/highlights generation
- Moderation: Chat filters, rate limits, block/ban users; content flags; takedown
- Observability: Real-time QoE (startup time, rebuffer %, bitrate); creator dashboards

## Non-Functional Requirements

- Latency Targets: WebRTC E2E p95 < 500ms; LL-HLS p95 2–5s; VOD startup p95 < 2s
- Availability: 99.99% ingest/origin; 99.95% playback
- Throughput: 100K ingest streams; 5M concurrent viewers; peak egress 20–40 Tbps
- Cost Control: Optimize transcode and egress with per-title ladders and cache efficiency
- Security: Signed URLs; DRM for premium; watermarking and fingerprinting; DDoS protection
- Compliance: Regional content policies; GDPR data retention; DMCA takedown workflows

## Scale Estimate

- Ingest: 100K RTMP/SRT; avg 6 Mbps (1080p) → 600 Gbps inbound
- Transcode Outputs: 6 renditions × 2.5 Mbps avg → ~1.5 Tbps from transcoders to packagers
- Viewers: 5M × 3 Mbps avg → 15 Tbps egress (peaks higher for big events)
- Storage: DVR 2h for top 10K channels × 3 Mbps ≈ 27 TB rolling; VOD archiving 10 PB/year
- Chat: 5M viewers → 200K msgs/sec peak; moderation 1–5% flagged

## Constraints

- Glass-to-glass latency depends on keyframe alignment, chunk size, and network RTT
- Mobile networks: Variable bandwidth and high packet loss; ABR must adapt quickly
- Creator hardware: Unreliable encoders; need server-side enforcement on codecs/bitrates
- Rights management: Geo/IP restrictions; device-based DRM availability differs by platform

## Success Measures

- Playback QoE: Startup p95 < 2s (VOD), rebuffer < 0.5% time, average bitrate > 2.5 Mbps
- Latency: WebRTC p95 < 500ms; LL-HLS live edge distance < 3 segments
- Reliability: <0.01% ingest disconnects due to server; failover < 5s
- Cost Efficiency: $/hour streamed within budget; cache hit ratio > 90% for hot events
- Safety: Moderation SLA < 60s review for flagged content; <0.1% false takedowns