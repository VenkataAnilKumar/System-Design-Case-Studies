# Chapter 3 — Key Technical Decisions

> **TL;DR:** H3 geospatial grid for location indexing · Hybrid push/pull dispatch · PostgreSQL (city-sharded) for ACID trip state · Redis for sub-ms hot location reads · Kafka for durable async fan-out · 30s GPS + 180s TTL for location freshness · Pre-auth hold at request, capture at completion

---

## Contents

1. [Real-Time Transport — WebSocket vs gRPC vs SSE](#1-real-time-transport)
2. [Geospatial Index — H3 vs Geohash vs R-Tree vs PostGIS](#2-geospatial-index)
3. [Dispatch Strategy — Push vs Pull vs Hybrid](#3-dispatch-strategy)
4. [Matching Scoring — ETA vs Distance vs Acceptance Rate](#4-matching-scoring)
5. [Surge Pricing Model — Cell Granularity and Recompute Cadence](#5-surge-pricing-model)
6. [Trip Store — PostgreSQL vs Cassandra](#6-trip-store)
7. [GPS Location Smoothing — Raw vs Kalman Filter](#7-gps-location-smoothing)
8. [ETA Calculation — Static Speed vs ML Model vs Live Traffic](#8-eta-calculation)
9. [Payment Authorization — Pre-Auth Hold vs Charge at End](#9-payment-authorization)
10. [Consistency Model — Strong for Trip State, Eventual for Everything Else](#10-consistency-model)

---

## 1. Real-Time Transport

**Problem:** Drivers stream GPS at 1 Hz and must receive offer pushes instantly. Riders need continuous location updates during a trip. Both require low-latency bidirectional communication on mobile networks.

**Options:**

| Option | Latency | Direction | Cost @ 1M drivers |
|---|---|---|---|
| HTTP Polling (1s) | ~1s | Client → Server only | ~$200K/month |
| Long Polling | ~200ms | Client → Server pull | ~$100K/month |
| Server-Sent Events (SSE) | ~50ms | Server → Client only | ~$60K/month |
| gRPC streaming | ~20ms | Bidirectional | ~$50K/month |
| **WebSocket** | **<50ms** | **Bidirectional** | **~$50K/month** |

**Decision:** WebSocket for all real-time flows (GPS stream, offer push, trip updates); REST for non-real-time (trip creation, history, settings).

**Why:**
- A single persistent TCP connection handles both inbound GPS frames and outbound offer pushes — no need to maintain two separate channels.
- 1 Hz GPS polling via HTTP would require 1M RPS just for location updates at peak — clearly not viable.
- gRPC streaming is a viable alternative but adds complexity (HTTP/2 multiplexing, protobuf tooling) for mobile clients that already support WebSocket natively.

**Trade-off:** WebSocket requires sticky load balancing (consistent hashing by `driver_id`) and stateful connection management (heartbeats, reconnects, drain on deploy).

**When to reconsider:** gRPC if binary efficiency and schema enforcement are priorities; SSE if drivers only need to receive offers (no inbound GPS stream).

---

## 2. Geospatial Index

**Problem:** For each ride request, find K nearest available drivers within a 1–3 km radius in under 50ms, across 1M active drivers distributed across hundreds of cities.

**Options:**

| Option | Neighbor Query | Sharding | Cache Locality | Ops Complexity |
|---|---|---|---|---|
| PostGIS (R-Tree) | Exact radius query | Hard to distribute | Low | Medium |
| Geohash | String prefix neighbors | Easy (prefix shard) | Good | Low |
| **H3 Hexagonal Grid** | **Ring expansion (O(rings))** | **Cell-prefix shard** | **Excellent** | **Low** |
| Redis GEODIST | O(N) scan per radius | Redis cluster | Good | Low |

**Decision:** H3 hexagonal grid at resolution 9 (~200 m cell edge), with ring expansion for neighbor search; cell sets stored in Redis.

**Why:**
- H3 cells are hexagonal — all 6 neighbors are equidistant, unlike Geohash rectangles where corner cells are farther away. This gives more uniform coverage in ring searches.
- A ring-1 search (7 cells) covers ~1 km radius at res 9; ring-2 (19 cells) covers ~2 km. Each ring is a `SMEMBERS` call on Redis — fast and predictable.
- Cell IDs can be used as shard keys, enabling horizontal scaling of the location index by cell prefix.

**Trade-off:** H3 cells have fixed boundaries — a driver 201 m away may be in ring-2 while a driver 199 m away is in ring-1. For dispatch this is acceptable; for exact geofencing, PostGIS remains better.

**When to reconsider:** PostGIS if centimeter-level precision is required (e.g., parking lot assignment). Redis GEOADD if the driver count per cell is always small and simplicity is preferred.

---

## 3. Dispatch Strategy

**Problem:** How to assign a driver to a ride request — send offers to the best candidates immediately (push), let drivers claim from a queue (pull), or combine both.

**Options:**

| Option | Assignment Speed | Driver Fairness | Resilience | Complexity |
|---|---|---|---|---|
| Pure Push (offer N drivers) | Fast | Low (best drivers always picked) | Low (no driver accepts = wait) | Medium |
| Pure Pull (drivers claim from queue) | Slower | High (driver chooses) | High (queue persists) | Low |
| **Hybrid (Push first; Pull fallback)** | **Fast** | **Medium** | **High** | **Medium** |

**Decision:** Hybrid — push offers to top-N drivers first; if no acceptance within TTL (15s), expose the trip to a per-cell pull queue for wider pickup.

**Why:**
- Push gives the fastest assignment: the first driver to accept wins, typically within 2–5s.
- Pure push fails when top-N drivers all decline or are unresponsive. The pull queue acts as a durable fallback — the trip isn't lost.
- The per-cell pull queue also handles cold starts (new cities, thin supply) where ranked candidates are scarce.

**Trade-off:** Hybrid adds complexity — the system must expire push offers, transition to pull, and prevent double-assignment (idempotent `acceptOffer` on the Trip Service prevents this).

**When to reconsider:** Pure pull if regulatory or marketplace rules require driver autonomy (e.g., drivers should always choose their own trips).

---

## 4. Matching Scoring

**Problem:** When multiple eligible drivers are available for an offer, how do we rank them to maximize rider experience, driver satisfaction, and overall system efficiency?

**Scoring factors (weighted sum):**

| Factor | Weight | Why |
|---|---|---|
| Estimated pickup ETA | 50% | Directly impacts rider wait time — the primary UX metric |
| Offer acceptance likelihood | 25% | Low-acceptance drivers waste offer slots and extend assignment time |
| Driver freshness (time since last trip) | 15% | Fairness: idle drivers should be preferred to reduce starvation |
| Vehicle class match | Hard constraint | Never send an economy offer to an XL-only driver |
| Driver rating | 10% | Protect rider experience on high-rating filter requests |

**Decision:** Weighted ETA-first scoring with hard constraints (vehicle class, driver status, rider rating requirements). Fairness adjustments applied when multiple candidates share similar ETA scores.

**Why:** ETA is the single metric riders care most about. Acceptance likelihood reduces round-trip latency — a driver who will decline is worse than a slightly farther driver who will accept.

**Trade-off:** Acceptance likelihood requires per-driver historical acceptance-rate tracking (updated async from offer outcomes). Cold-start problem for new drivers: default to 70% until 50+ offer observations.

---

## 5. Surge Pricing Model

**Problem:** Balance supply and demand dynamically per micro-area to reduce wait times during peaks while keeping fare increases predictable and fair to riders.

**Options:**

| Approach | Responsiveness | Stability | Rider Transparency |
|---|---|---|---|
| City-level surge | Low | High | Easy to explain |
| Hex-cell surge (H3 res 8–9) | High | Medium | Harder to explain |
| Real-time auction pricing | Very high | Low (oscillates) | Confusing |
| **Hex-cell surge + change clamping** | **High** | **High** | **Medium** |

**Decision:** H3 cell-level surge recomputed every 30–120s; multiplier changes clamped to ±20% per cycle; cached in Redis with 120s TTL.

**Why:**
- Cell-level granularity captures micro-supply-demand imbalances (e.g., stadium exit vs. quiet residential street 500 m away).
- Clamping prevents oscillation — rapid rider cancellations during a spike could otherwise trigger a surge→drop→surge cycle within minutes.
- Caching in Redis means the dispatch critical path never waits on a recompute.

**Trade-off:** 30–120s recompute lag means surge lags real-time demand by up to 2 minutes. For most scenarios this is acceptable; for sudden events (accidents, flash floods), manual override capability is required.

---

## 6. Trip Store

**Problem:** Trip state transitions (Requested → Assigned → InProgress → Completed) must be atomic and strictly ordered. A payment event must not be applied twice.

**Options:**

| Criterion | PostgreSQL (chosen) | Cassandra | MongoDB |
|---|---|---|---|
| ACID transactions | Yes (per shard) | No (LWT only) | Yes (limited) |
| FSM idempotency | Easy (ON CONFLICT) | Harder | Medium |
| Query flexibility | High (SQL) | Low (partition key only) | Medium |
| Ops maturity | High | Steeper | Medium |
| Sharding model | Manual (by city) | Auto-distribute | Manual/auto |

**Decision:** PostgreSQL, sharded by `city_id` (1 primary shard per major city, 3 replicas).

**Why:**
- Trip state transitions require serializable isolation — two concurrent `acceptOffer` calls must not both succeed. PostgreSQL `SELECT FOR UPDATE` or `ON CONFLICT` handles this cleanly.
- SQL gives flexibility for ops queries (trips by state per city, offer acceptance rates, fraud patterns) without a separate analytics layer.
- City-level sharding keeps the data model simple — no distributed transactions are needed.

**Trade-off:** Manual re-sharding when a single city grows beyond 2K writes/s or 500 GB. Cassandra would auto-distribute but at the cost of ACID guarantees.

**When to reconsider:** If global write volume exceeds 50K trips/s or strict per-conversation ordering can be relaxed, evaluate Cassandra or DynamoDB.

---

## 7. GPS Location Smoothing

**Problem:** Mobile GPS readings are noisy — ±10–50 m positional error, occasional multi-hundred-meter jumps from signal acquisition. Using raw GPS coordinates leads to erratic driver positions on maps and incorrect ETA estimates.

**Options:**

| Option | Noise Reduction | Latency Overhead | Complexity |
|---|---|---|---|
| Raw GPS passthrough | None | None | None |
| Simple moving average (last 3 readings) | Medium | ~1ms | Low |
| Snap-to-road only | High | ~5ms (road graph lookup) | Medium |
| **Kalman filter + outlier rejection** | **High** | **<1ms** | **Medium** |

**Decision:** Kalman filter for smoothing consecutive readings; outlier rejection for teleport jumps (speed > 100 m/s); snap-to-road applied for ETA display only (not for dispatch queries).

**Why:**
- Kalman filter is a one-pass O(1) algorithm per update — negligible overhead in the 1 Hz GPS stream.
- Outlier rejection prevents a single bad GPS reading from placing a driver in the wrong H3 cell, which would cause matching failures.
- Snap-to-road is deferred to the ETA/map display layer to avoid the latency of a graph lookup on every GPS update.

**Trade-off:** Kalman filter introduces 1–2s of smoothing lag for rapidly changing positions (tight turns, abrupt acceleration). Acceptable for dispatch; display layer compensates with dead-reckoning interpolation.

---

## 8. ETA Calculation

**Problem:** Accurate pickup ETA is the single most important number shown to riders. A poor ETA estimate (off by > 3 minutes) directly correlates with cancellations.

**Options:**

| Option | Accuracy | Latency | Infra Cost |
|---|---|---|---|
| Straight-line / haversine only | Low | <1ms | Minimal |
| Static road-speed profiles (historical avg) | Medium | ~5ms | Low (precomputed) |
| Real-time traffic API (Google Maps) | High | ~100ms | High (per-call cost) |
| **Historical speed + real-time correction** | **High** | **<20ms** | **Medium** |

**Decision:** Historical per-road-segment speed profiles (computed from 30 days of trip data, updated nightly), with a real-time speed scaling factor per city zone refreshed every 60s from live trip telemetry.

**Why:**
- Pure haversine ignores road topology entirely — unacceptable in grid cities and impossible in cities with bridges/tunnels.
- Live traffic API costs $5–10 per 1,000 calls; at 1,500 dispatch calls/s, this would be ~$650K/month on traffic queries alone.
- Historical profiles cover 95% of accuracy with a small fraction of the cost; the real-time correction factor handles current incidents and weather without per-call API costs.

**Trade-off:** Nightly batch updates miss new road openings or closures for up to 24 hours. Supplement with an ops feed from map providers for known infrastructure changes.

---

## 9. Payment Authorization

**Problem:** How to ensure the rider is charged correctly at trip end without holding funds for too long and without risk of non-payment.

**Options:**

| Option | Rider Trust | Non-Payment Risk | Complexity |
|---|---|---|---|
| Charge at trip end (no hold) | High | High (card declined post-trip) | Low |
| Full charge at request | Low (over-charge on cancel) | None | Low |
| **Pre-auth hold at request; capture at end** | **High** | **Low** | **Medium** |
| Escrow / wallet pre-load | Medium | None | High |

**Decision:** Pre-authorize a hold equal to 1.5× the estimated fare at request time; capture the exact final fare at trip completion; release the hold delta automatically.

**Why:**
- Pre-auth ensures the rider has sufficient funds before a driver is dispatched — prevents fraud and protects drivers.
- 1.5× buffer covers surge increases or longer-than-estimated trips without requiring re-authorization.
- PCI-DSS compliant: no raw card data stored; tokenized via payment gateway.

**Trade-off:** Pre-auth holds reduce rider's available credit for the trip duration (~15–30 minutes). Some card networks charge for holds not converted to captures within 7 days — enforce trip timeout and hold release for long-pending trips.

---

## 10. Consistency Model

**Problem:** Different parts of the system have different consistency requirements — some require ACID guarantees, others can tolerate eventual consistency for higher availability and lower cost.

**Decision:** Strong consistency for trip state transitions (CP); eventual consistency for surge pricing, location display, and analytics.

| Component | Consistency Level | Rationale |
|---|---|---|
| Trip FSM (PostgreSQL) | **Strong (Serializable)** | Two concurrent `acceptOffer` calls must not both succeed |
| Payment events | **Strong (ACID)** | Double-charge is unacceptable |
| Driver location (Redis) | **Eventual (TTL-based)** | 1–3s staleness acceptable for dispatch |
| Surge multiplier (Redis cache) | **Eventual (30–120s lag)** | Brief lag is acceptable; quote is only an estimate |
| Offer acceptance | **Strong (idempotent write)** | Only one driver may accept a given offer |
| Analytics / ML features | **Eventual** | Training data can be hours old |
| Multi-region (city failover) | **Eventual (island mode)** | City operates independently during partition; reconciles on heal |

**Trade-off:** Strong consistency for trip state limits horizontal scaling of the Trip Service — all writes for a city must go to the same primary shard. This is acceptable because trip write throughput per city is low (~100–500/s) even at peak.

---

## Interview TL;DR

| Decision | Chosen | Key Reason | Main Alternative |
|---|---|---|---|
| Real-time transport | WebSocket | <50ms bidirectional; 1M connections feasible | gRPC streaming |
| Geospatial index | H3 hexagonal grid | O(rings) scan; cache locality; even neighbor distance | Geohash (rectangular cells) |
| Dispatch strategy | Hybrid push/pull | Push speed + pull durability | Pure push (no fallback) |
| Matching scoring | ETA-first weighted sum | Rider wait time is the primary UX metric | Distance-first |
| Surge pricing | Cell-level + change clamping | Micro-area accuracy; no oscillation | City-level surge |
| Trip store | PostgreSQL (city-sharded) | ACID FSM; idempotent `ON CONFLICT` | Cassandra (no ACID) |
| GPS smoothing | Kalman filter + outlier reject | Sub-ms overhead; eliminates teleport jumps | Raw passthrough |
| ETA calculation | Historical speed + real-time factor | Accurate without per-call traffic API cost | Google Maps API (expensive) |
| Payment | Pre-auth hold at request | Prevents non-payment after driver dispatch | Charge at end (fraud risk) |
| Consistency | Strong for trip/payment; eventual for location | Safety for money; speed for location | Full strong consistency (too slow) |
