# Video Conferencing Platform

## Problem Statement

Design a **Zoom/Google Meet-like video conferencing platform** that supports real-time audio/video communication for large meetings with low latency.

**Core Challenge**: Handle 1M concurrent meetings with up to 1000 participants per meeting while maintaining <150ms end-to-end latency and 99.95% availability.

**Key Requirements**:
- Real-time audio/video streaming (WebRTC)
- Screen sharing and recording
- Chat and reactions during meetings
- Meeting scheduling and invitations
- Breakout rooms for sub-groups
- Scalability for large webinars (10K+ participants)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M meetings, 1000 participants/meeting, <150ms latency) |
| [02-architecture.md](./02-architecture.md) | Components (Signaling Server, SFU, Recording Service, Chat) |
| [03-key-decisions.md](./03-key-decisions.md) | Mesh vs SFU vs MCU, codec selection, bandwidth optimization |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to enterprise, failure scenarios, quality optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **End-to-End Latency** | <150ms (speaker to listeners) |
| **Packet Loss** | <1% (with jitter buffer compensation) |
| **Concurrent Meetings** | 1M meetings, 50M participants |
| **Availability** | 99.95% |

## Technology Stack

- **WebRTC**: Peer-to-peer for small groups, SFU for large meetings
- **SFU**: Selective Forwarding Unit (Janus, mediasoup)
- **Signaling**: WebSocket for room join/leave, offer/answer exchange
- **Recording**: FFmpeg for server-side recording
- **CDN**: Distribute recorded videos

## Interview Focus Areas

1. **Mesh vs SFU**: Mesh for <5 participants, SFU for scalability
2. **Bandwidth Optimization**: Simulcast (multiple quality streams)
3. **Jitter Buffer**: Compensate for packet loss and reordering
4. **Codec Selection**: VP8/VP9 vs H.264 (compatibility vs compression)
5. **Large Meetings**: Gallery view vs active speaker detection
