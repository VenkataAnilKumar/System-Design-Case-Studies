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
