# 3) Key Design Decisions & Trade-Offs

## 1. Centralized vs. Regional Dispatch

**Decision**: Regional dispatch services per metro.

**Rationale**: Local traffic patterns and regulations; lower latency; resilience to region failures.

**Trade-off**: Harder cross-region load sharing; configuration drift.

**When to reconsider**: Small countries/cities; centralized is simpler initially.

---

## 2. Greedy vs. Global Optimization for Assignment

**Decision**: Greedy scoring with periodic re-optimization.

**Rationale**: Fast decisions under load; near-optimal with rebalancing.

**Trade-off**: Occasional suboptimal batching or assignments.

**When to reconsider**: For mega-events (Super Bowl), run global optimizer for hot zones.

---

## 3. ETA Modeling: Rule-Based vs. ML

**Decision**: ML (gradient boosting) for travel+prep; online calibration with telemetry.

**Rationale**: Captures nonlinear effects (weather, time-of-day, restaurant behavior).

**Trade-off**: Model drift; requires feature pipelines and monitoring.

**When to reconsider**: Early stage: rule-based baseline while gathering data.

---

## 4. Inventory Consistency: Push vs. Pull with Restaurants

**Decision**: Pull via periodic sync + push webhooks for live outages.

**Rationale**: POS systems unreliable; combine for better freshness.

**Trade-off**: Occasional stale items; require substitution flow.

**When to reconsider**: Deep POS integration with SLAs → push dominant.

---

## 5. Courier Telemetry Rate

**Decision**: 1Hz default; adapt down to 0.2Hz when idle, up to 2Hz near pickup/drop.

**Rationale**: Balance battery, bandwidth, and ETA accuracy.

**Trade-off**: Server complexity for adaptive rates.

**When to reconsider**: If network cost spikes or battery issues; adjust heuristics.

---

## 6. Payments: Auth-Then-Capture vs. Immediate Capture

**Decision**: Auth on place, capture on delivery (post-tip adjust window).

**Rationale**: Handle item changes/cancellations; better CX for tips.

**Trade-off**: Auth holds expire; capture failures need retries.

**When to reconsider**: Markets where immediate capture required by regulation.
