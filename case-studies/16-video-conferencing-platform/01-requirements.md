# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Meeting Lifecycle: Create, join, leave; link/code entry; waiting room; lock/unlock
- Media: Audio/video (VP8/VP9/H.264/AV1); screenshare; simulcast/SVC; mute/unmute
- Signaling: ICE/STUN/TURN; SDP negotiation; renegotiation for layout changes
- Layouts: Speaker view, gallery, pin, spotlight; dynamic switching
- Recording: Cloud recording to S3; playback; transcription; highlights
- Chat: In-meeting text; file sharing; reactions; polls
- Breakout Rooms: Sub-rooms; host assign/shuffle; auto-return
- Controls: Host mute all, remove participant, disable screenshare, end for all
- Quality: Network probing, BWE (bandwidth estimation), adaptive bitrate, FEC/retransmit

## Non-Functional Requirements

- Latency: p95 E2E (mic → speaker) < 300ms; signaling < 500ms
- Availability: 99.9% meeting join success; graceful degradation (audio-only)
- Scale: 500K concurrent meetings; rooms up to 1000 participants; 10M DAU
- Quality: Packet loss < 1%; jitter < 30ms; MOS > 4.0
- Security: E2EE optional; signaling TLS; DTLS-SRTP for media; auth per meeting

## Scale Estimate

- Meetings/day: 5M; avg duration 30 min; peak 500K concurrent
- Participants: 5M online peak; avg 5/meeting → 2.5M active streams
- Bandwidth: 5M streams × 1.5 Mbps avg → 7.5 Tbps peak egress
- Recording: 100K meetings/day recorded × 500MB avg → 50TB/day storage

## Constraints

- NAT traversal: ~20% behind symmetric NAT; need TURN relays
- Mobile bandwidth: Variable; must degrade gracefully (audio-only fallback)
- Browser/device diversity: WebRTC quirks per browser; codec support varies
- Clock skew and jitter buffers complicate synchronization

## Success Measures

- Join success rate > 99.9%; time-to-join p95 < 3s
- Audio/video quality MOS > 4.0; packet loss < 1%
- E2E latency p95 < 300ms; jitter < 30ms
- Recording success rate > 99%; transcription accuracy > 90%