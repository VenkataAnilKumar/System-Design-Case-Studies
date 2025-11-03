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
