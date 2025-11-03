# 3) Key Design Decisions & Trade-Offs

## 1. Latency Budget Allocation

**Decision**: 10ms edge → 20ms targeting → 10ms caps/pacing → 10ms auction → 10ms response.

**Rationale**: Fits p95 < 100ms including network.

**Trade-off**: Tight budgets require careful caching and precomputation.

**When to reconsider**: Mobile networks with high RTT; expand edge footprint.

---

## 2. Frequency Caps Storage

**Decision**: In-memory distributed KV with periodic snapshot to disk.

**Rationale**: 10M QPS counters require memory speed; TTL cleanup.

**Trade-off**: Memory cost; replication needed for durability.

**When to reconsider**: Use count-min sketch for approximate caps at extreme scale.

---

## 3. Auction Type: First vs. Second Price

**Decision**: First-price with bid shading; enforce floors.

**Rationale**: Market trend; simpler settlements.

**Trade-off**: Requires bidder trust and transparency.

**When to reconsider**: Partner ecosystems demanding second-price.

---

## 4. Pacing Consistency

**Decision**: Strong consistency per campaign counter (atomic increments), regional mirrors eventually consistent.

**Rationale**: Prevent overspend while enabling geo-scale.

**Trade-off**: Cross-region writes increase latency; mitigate with leader per campaign.

**When to reconsider**: Small budgets; allow slight drift with periodic reconciliation.

---

## 5. Privacy & Consent Handling

**Decision**: Consent-gated user data; contextual fallback.

**Rationale**: Regulatory compliance; user trust.

**Trade-off**: Lower CPM without personalization.

**When to reconsider**: Markets with explicit opt-in only; stricter gating.

---

## 6. Brand Safety

**Decision**: Multi-layer — publisher allowlists, NLP classifiers, 3rd-party verification.

**Rationale**: Reduce unsafe placements.

**Trade-off**: False positives reduce reach.

**When to reconsider**: High false positive rates → tune thresholds per vertical.
