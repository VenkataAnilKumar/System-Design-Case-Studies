# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 10K DAU**
- Single-region SFU; basic signaling; STUN only (no TURN)
- Simple layouts; no recording; basic chat

**10K → 100K DAU**
- Add TURN relays; regional SFUs; signaling clusters
- Cloud recording; transcription; analytics pipeline
- Simulcast; BWE with TWCC

**100K → 10M DAU**
- Global edge SFUs; anycast signaling; TURN autoscaling
- E2EE optional; breakout rooms; advanced layouts; noise suppression
- Large meetings (1000+) use dedicated SFU clusters

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| SFU crash | Participants disconnect | Health checks fail | Reconnect to standby SFU; client auto-rejoin |
| TURN relay overload | Increased packet loss | TURN CPU/bandwidth saturation | Autoscale TURN; ICE failover to next candidate |
| Signaling partition | Cannot join/leave | WebSocket errors | Retry with exponential backoff; route to healthy signaling node |
| Recording service lag | Recordings incomplete | Muxing errors; S3 failures | Buffer locally; retry upload; alert ops |
| Network congestion | Packet loss, jitter | TWCC reports; RTC stats | BWE downgrades bitrate; drop to audio-only if severe |

---

## SLOs

- Join success rate > 99.9%; time-to-join p95 < 3s
- E2E latency p95 < 300ms; jitter < 30ms
- Packet loss < 1%; MOS > 4.0
- Recording success > 99%; transcription latency < 5 min

---

## Common Pitfalls

1. Under-provisioned TURN → participants behind NAT cannot connect; autoscale TURN with usage
2. Fixed bitrate → network congestion causes packet loss; implement BWE (TWCC/REMB)
3. No simulcast → high-bandwidth participants force everyone to high bitrate; enable simulcast
4. Synchronous recording muxing → SFU CPU spikes; offload to dedicated recording workers
5. Ignoring ICE failures → silent join failures; monitor ICE state and surface errors

---

## Interview Talking Points

- SFU vs. MCU tradeoffs: latency, scale, bandwidth, CPU
- ICE/STUN/TURN and NAT traversal; candidate gathering and prioritization
- BWE algorithms (GCC, TWCC) and how they adapt to congestion
- Simulcast layer selection and switching; SVC emerging benefits
- Recording architecture and E2EE tradeoffs (features vs. privacy)

---

## Follow-Up Questions

- How to support 10K+ participant webinars (MCU with audience view)?
- How to implement noise suppression and background blur at scale?
- How to optimize for mobile networks (high latency, packet loss)?
- How to handle international calls with high RTT (200ms+)?
- How to design E2EE with cloud features like transcription?