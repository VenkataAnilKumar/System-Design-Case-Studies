# 3) Key Design Decisions & Trade-Offs

## 1. SFU vs. MCU

**Decision**: SFU (Selective Forwarding Unit).

**Rationale**: Lower latency; horizontal scale; client-side layout flexibility.

**Trade-off**: Higher egress bandwidth (each stream sent N-1 times); clients must decode multiple streams.

**When to reconsider**: If target is low-end devices (IoT, feature phones); MCU composites into single stream.

---

## 2. Simulcast vs. SVC

**Decision**: Simulcast (multiple independent layers) with SVC fallback for AV1.

**Rationale**: Broader codec support (VP8/H.264); simpler switching.

**Trade-off**: Higher bandwidth vs. SVC (which reuses base layer); AV1 SVC emerging.

**When to reconsider**: Once AV1 SVC is widely supported, prefer it for bandwidth savings.

---

## 3. TURN Placement: Centralized vs. Edge

**Decision**: Edge TURN relays in each region.

**Rationale**: Minimize latency for relayed media; reduce backbone load.

**Trade-off**: Operational complexity; need per-region capacity planning.

**When to reconsider**: Small-scale deployment; centralized TURN is simpler initially.

---

## 4. Recording: Server-Side vs. Client-Side

**Decision**: Server-side (SFU subscribes to all feeds).

**Rationale**: Reliability (client may crash); host can record without participants knowing.

**Trade-off**: SFU load increases; egress bandwidth for recordings.

**When to reconsider**: If privacy requires client-side; or if SFU capacity is constrained.

---

## 5. E2EE: Optional vs. Mandatory

**Decision**: Optional (default off; opt-in for sensitive meetings).

**Rationale**: Recording, transcription, and cloud features require plaintext; E2EE breaks them.

**Trade-off**: Privacy vs. features; need clear UX about tradeoffs.

**When to reconsider**: If targeting enterprise/healthcare; make E2EE default with feature limitations.

---

## 6. Jitter Buffer: Fixed vs. Adaptive

**Decision**: Adaptive (adjust based on network conditions).

**Rationale**: Lower latency in stable networks; resilient in lossy ones.

**Trade-off**: Complexity; can cause audio glitches if poorly tuned.

**When to reconsider**: Fixed buffer is simpler for controlled networks (corporate VPN).

---

## 7. Breakout Rooms: Separate SFUs vs. Same SFU

**Decision**: Same SFU with logical sub-rooms; WebRTC renegotiation.

**Rationale**: Fast room switches; no media reconnection.

**Trade-off**: SFU state complexity; if main room has 1000 and breakout 5, resource imbalance.

**When to reconsider**: Large meetings; spawn dedicated SFUs per breakout for isolation.
