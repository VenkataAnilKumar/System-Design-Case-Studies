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