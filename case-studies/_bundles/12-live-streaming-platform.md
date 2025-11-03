# 12-live-streaming-platform - Live Streaming Platform
Generated: 2025-11-02 20:38:44 -05:00

---

<!-- Source: 01-requirements.md -->
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



---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
	subgraph Creators
		Encoder[Encoder (OBS)]
	end

	subgraph Viewers
		Browser[Browser/Mobile App]
	end

	subgraph Ingest
		IngestEdge[Ingest Edge\nRTMP/SRT/WebRTC]
		StreamAuth[Stream Auth]
	end

	subgraph Processing
		Transcode[Transcode Cluster\nGPU/ASIC]
		Packager[Packager\nHLS/DASH/LL-HLS]
		SFU[WebRTC SFU\nSub-500ms]
	end

	subgraph Delivery
		Origin[(Origin Storage\nHot/Warm)]
		CDN[CDN\nMulti-tier edge]
		ChatGW[Chat Gateway\nWebSocket]
	end

	subgraph Data
		SessionSvc[Session Service]
		Redis[(Redis\nChat/State)]
		S3[(Object Storage\nDVR/VOD)]
		Kafka[Kafka\nEvents]
	end

	Encoder --> IngestEdge
	IngestEdge --> StreamAuth
	StreamAuth --> Transcode
	Transcode --> Packager
	Transcode --> SFU
  
	Packager --> Origin
	Origin --> CDN
	CDN --> Browser
	SFU --> Browser
  
	Browser --> ChatGW
	ChatGW --> Redis
	ChatGW --> Kafka
  
	IngestEdge --> SessionSvc
	Packager --> S3
```

## Components

- Ingest Edge: Globally distributed RTMP/SRT/WebRTC ingress; TLS; anycast/GeoDNS routing
- Stream Auth: Validate stream keys, enforce bitrate/codec profile, attach metadata (channel ID)
- Transcode Cluster: GPU-accelerated (NVENC) or ASIC; per-title ladder, keyframe-aligned renditions
- Packager: HLS/DASH; LL-HLS with CMAF chunked transfer; segmenter; origin push
- Origin Storage: Hot origin (SSD, HTTP origin), Warm object store for DVR/VOD (S3/GCS)
- CDN: Multi-CDN, real-time traffic steering; tokenized URLs; prefetch hints
- WebRTC SFU: Selective Forwarding Unit for sub-500ms paths; ICE/STUN/TURN; bandwidth estimation (TWCC)
- Chat Service: Pub/sub over WebSocket; sharded rooms; moderation pipeline
- Control Plane: Session service (stream state), channel registry, entitlement & geo-policy
- Anti-Abuse: Watermarking, fingerprinting, leak detection, link-takedown automation
- Observability: QoE beacons, ingest/packager health, transcode metrics, CDN real-user monitoring

## Data Flows

### A) Stream Ingest → Transcode → Package → Deliver (LL-HLS)

1) Encoder (OBS) pushes RTMP/SRT → Ingest Edge (nearest POP)
2) Stream Auth validates key/profile; assigns session ID; emits session start
3) Ingest forwards elementary streams (H.264/HEVC + AAC/Opus) to Transcode Cluster
4) Transcode produces aligned renditions (e.g., 1080p@6Mbps, 720p@3Mbps, 480p@1.5Mbps)
5) Packager segments into CMAF chunks (e.g., 1s) and partial segments; updates HLS manifest with preload hints
6) Origin stores recent chunks for DVR window; CDN pulls and caches; client plays near live edge

### B) Interactive Mode (WebRTC)

1) Browser/mobile uses WHIP (WebRTC-HTTP Ingestion Protocol) to publish; viewers join via WHEP
2) SFU receives RTP streams; forwards selected layers (SVC/Simulcast) to each viewer
3) ICE/STUN/TURN negotiate paths; congestion control adjusts bitrate (Google Congestion Control/TWCC)
4) For large audiences, hybrid: Presenter via WebRTC to SFU; SFU also publishes to LL-HLS pipeline for mass distribution

### C) Chat & Moderation

1) Viewer connects to Chat Gateway (WebSocket); joins channel room (sharded by channel_id)
2) Messages → Moderation filters (rate limit, banned words, spam, links); ML classifier flags
3) Accepted messages fanout via pub/sub; store in short-term backlog (Redis) and long-term store (Cassandra)
4) Moderator actions (timeout/ban/delete) propagate to gateway and are enforced at edge

### D) VOD Archival & Clipping

1) Rolling DVR chunks consolidated into HLS VOD; index chapters
2) Users mark highlights; clipping service splices segments (frame-accurate using keyframe maps)
3) Transcode on demand for VOD renditions; store to warm/cold tiers

## Data Model

- streams(id, channel_id, state[starting|live|ended], protocol[rtmp|srt|webrtc], started_at, ended_at)
- renditions(stream_id, profile, bitrate, resolution, keyframe_interval)
- chat_messages(id, channel_id, user_id, text, ts, flags{spam,toxic,link})
- dvr_segments(stream_id, seq, s3_key, duration, timestamp)
- entitlements(channel_id, policy{geo,subscriber_only,age_restriction})

## APIs

- POST /v1/streams/start {stream_key}
- POST /v1/streams/stop {stream_id}
- GET /v1/streams/:id/manifest.m3u8 (signed)
- WS /v1/chat/:channel_id
- POST /v1/moderation/:channel_id/actions {ban|timeout|delete}

Auth: JWT for viewer APIs; HMAC-signed stream keys for ingest; signed URL tokens for CDN.

## Why These Choices

- LL-HLS for mass scale with 2–5s latency; WebRTC for sub-500ms interactivity
- SRT for more resilient ingest over the public Internet (ARQ/FEC)
- Per-title encoding reduces bitrate at same quality; cuts CDN cost
- CMAF chunks enable chunked transfer and unified storage for HLS/DASH
- Multi-CDN + steering improves global QoE; avoids vendor lock-in

## Monitoring

- Glass-to-glass latency; live-edge distance; rebuffer ratio; startup time

- Ingest errors (validation, disconnects), transcode queue depth, packager segment gaps
- CDN cache hit ratio; regional QoE (bitrate, failures); chat delivery latency



---

<!-- Source: 03-key-decisions.md -->
# 3) Key Design Decisions & Trade-Offs

## 1. LL-HLS vs. WebRTC for Delivery

**Decision**: Hybrid — LL-HLS for large audiences (2–5s latency), WebRTC for interactive sessions (<500ms).

**Rationale**: LL-HLS scales well over CDNs; WebRTC gives ultra-low latency but is costly at scale.

**Trade-off**: Two pipelines to maintain; complexity in hybrid events.

**When to reconsider**: If interactivity is core for all streams, invest in large SFU clusters and TURN capacity (higher cost).

---

## 2. RTMP vs. SRT vs. WHIP Ingest

**Decision**: Support RTMP (ubiquity), SRT (resilience), and WHIP (WebRTC native).

**Rationale**: Broad encoder support and better performance over lossy networks.

**Trade-off**: More protocols to operate; edge gateways more complex.

**When to reconsider**: If creator base is homogeneous (e.g., OBS only), narrow support to reduce cost.

---

## 3. Centralized vs. Edge Transcoding

**Decision**: Regional centralized transcode clusters.

**Rationale**: Higher utilization on GPUs; easier to manage orchestration and per-title encoding.

**Trade-off**: Higher backbone bandwidth from ingest POPs to regions.

**When to reconsider**: If POP count grows and backbone becomes bottleneck; add edge transcode for hot regions.

---

## 4. Chunk Duration and Keyframe Interval

**Decision**: 1s CMAF chunks, keyframe every 2s; partial segments enabled.

**Rationale**: Reduces live edge distance; enables fast ABR switching.

**Trade-off**: Higher overhead (more requests); encoder stress.

**When to reconsider**: For ultra-low bandwidth users, longer segments (2–4s) may reduce overhead.

---

## 5. DRM vs. Signed URLs + Watermarking

**Decision**: Signed URLs + forensic watermarking for most; DRM for premium.

**Rationale**: DRM adds device constraints; signed URLs + watermarking deter casual piracy.

**Trade-off**: Hardcore piracy still possible; takedown workflows required.

**When to reconsider**: If premium rights demand DRM (studios, sports leagues), enforce DRM on supported devices.

---

## 6. Chat Architecture: Fanout via Pub/Sub vs. SFU Data Channels

**Decision**: Pub/Sub (WebSocket) separate from media pipeline.

**Rationale**: Chat scales independently; avoids tying reliability to WebRTC path.

**Trade-off**: Two connections to manage on clients.

**When to reconsider**: Small-room interactive calls can use WebRTC data channels for simplicity.

---

## 7. Multi-CDN vs. Single CDN

**Decision**: Multi-CDN with real-time steering.

**Rationale**: Regional performance variance; failover across providers improves QoE.

**Trade-off**: Vendor complexity; cost negotiations.

**When to reconsider**: Early stage or regional-only service can use single CDN initially.




---

<!-- Source: 04-wrap-up.md -->
# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 100K viewers**
- Single region ingest/transcode; one CDN; 3 renditions; HLS (6s segments)
- Basic chat (Redis pub/sub); minimal moderation

**100K → 1M viewers**
- Add LL-HLS (CMAF 1s chunks); multi-region ingest; GPU transcoders
- Multi-CDN; origin shield; signed URLs; watermarking
- Per-title encoding; start DVR (30–60 min)

**1M → 5M+ viewers**
- Global ingest POPs; regional transcode clusters; packager autoscale
- Real-time CDN steering; prefetch/push to edges for marquee events
- WebRTC SFU for interactive shows; TURN autoscaling
- Full moderation pipeline (ML + human); chat sharding with hotspots isolation

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Transcoder crash | Renditions missing, playback stalls | Health probe fails, missing variants | Restart; failover to backup encoder; show fallback slate |
| Packager gap | Player stalls at live edge | Segment continuity check | Regenerate manifests; client backoff; increase buffer temporarily |
| CDN provider outage | Regional playback failures | RUM QoE drop; CDN errors | Shift traffic to alternate CDN; invalidate tokens selectively |
| Ingest POP down | Creators can't connect | POP health down | Anycast/GeoDNS failover to nearest POP |
| Chat spike (spam) | Chat unusable | Rate of messages > baseline | Per-user/IP rate limit, slow-mode; ML spam filter tightened |
| Piracy leak | Revenue loss | Fingerprint match on pirate sites | Automated takedowns; rotate keys; watermark tracing |

---

## SLOs

- LL-HLS live edge distance p95 < 3s; startup p95 < 2s
- WebRTC end-to-end p95 < 500ms
- Rebuffer ratio < 0.5%
- Ingest/origin availability 99.99%
- Chat delivery latency p95 < 200ms

---

## Common Pitfalls

1. Keyframe misalignment across renditions → ABR stalls; enforce encoder keyframe interval
2. Long segments (6s) in live → high latency; move to 1–2s CMAF chunks for LL-HLS
3. Single CDN dependence → regional QoE drops; adopt multi-CDN early for events
4. No signed URLs → link sharing; enforce tokenization and geo/entitlement policies
5. Under-provisioned TURN → WebRTC fails behind NAT; autoscale TURN with usage

---

## Interview Talking Points

- LL-HLS vs. WebRTC trade-offs at scale (cost, latency, reliability)
- Per-title encoding and why it saves egress while improving QoE
- Multi-CDN steering strategies (real-user monitoring, RTT-based routing)
- Chat scalability patterns (room sharding, rate limiting, moderation feedback loop)
- Watermarking/fingerprinting workflows and automated takedowns

---

## Follow-Up Questions

- How to support multi-audio (commentary tracks) and multi-camera switching?
- How to implement live ad insertion (SCTE-35) with server-side ad insertion (SSAI)?
- How to scale real-time subtitles and translations?
- How to guarantee frame-accurate clipping for highlights?
- How to offer Creator Studio analytics with minute-by-minute QoE insights?



