# Live Streaming Platform

## Problem Statement

Design a **Twitch/YouTube Live-like streaming platform** that broadcasts live video to millions of concurrent viewers with sub-5-second latency.

**Core Challenge**: Handle 1M concurrent streamers with 100M concurrent viewers (100:1 viewer-to-streamer ratio) while maintaining <5s glass-to-glass latency and 99.95% availability.

**Key Requirements**:
- Low-latency video ingest (RTMP/WebRTC from streamers)
- Real-time transcoding (multiple bitrates for ABR)
- Sub-5-second delivery to viewers (HLS/DASH)
- Chat with millions of concurrent messages
- DVR (rewind/pause live stream)
- Monetization (ads, subscriptions, donations)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M streamers, 100M viewers, <5s latency) |
| [02-architecture.md](./02-architecture.md) | Components (Ingest, Transcoding, CDN, Chat Service) |
| [03-key-decisions.md](./03-key-decisions.md) | Low-latency protocols (LL-HLS, WebRTC), transcoding optimization |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global events, failure scenarios, cost optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Glass-to-Glass Latency** | <5s (streamer camera → viewer screen) |
| **Concurrent Viewers** | 100M peak (1M per popular stream) |
| **Availability** | 99.95% |
| **Rebuffer Ratio** | <1% |

## Technology Stack

- **Ingest**: RTMP/SRT for streamer upload, WebRTC for ultra-low-latency
- **Transcoding**: Live transcoding (H.264/H.265), GPU acceleration
- **Delivery**: LL-HLS (Low-Latency HLS) or WebRTC for viewers
- **Chat**: WebSocket servers, Kafka for message fan-out
- **CDN**: Multi-tier caching for popular streams

## Interview Focus Areas

1. **Low-Latency Protocols**: LL-HLS vs WebRTC trade-offs
2. **Live Transcoding**: Real-time encoding with <1s delay
3. **Chat Scaling**: Handle 1M concurrent chat messages per stream
4. **DVR**: Sliding window buffer (last 4 hours) for rewind
5. **Viral Streams**: Sudden 10× traffic spike (e.g., breaking news)
