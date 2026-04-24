# Chapter 4 — Scale, Failures & Wrap-Up

> Practical production notes for the ride-sharing platform. Covers the scaling playbook from single city to global, how each component fails and recovers, runbooks, cost breakdown, and key takeaways.

---

## Contents

1. [Scaling Playbook (Single City → Global)](#1-scaling-playbook-single-city--global)
2. [Failure Modes & Mitigation](#2-failure-modes--mitigation)
3. [Monitoring & Alerts](#3-monitoring--alerts)
4. [Operational Runbooks](#4-operational-runbooks)
5. [Cost Breakdown](#5-cost-breakdown)
6. [Trade-Offs Summary](#6-trade-offs-summary)
7. [Key Takeaways](#7-key-takeaways)
8. [Interview Quick Reference](#8-interview-quick-reference)

---

## 1. Scaling Playbook (Single City → Global)

### Phase 1 — Single City MVP (0–100K DAU)

- Single city, single AZ
- 5 WebSocket servers (2K connections each)
- 1 Redis instance (8 GB) — location index + surge cache
- 1 PostgreSQL primary + 2 read replicas (unsharded)
- 3 Dispatch workers
- Monolithic Dispatch + Pricing service

**Bottleneck:** Redis write throughput as driver count approaches 100K (~100K/s GPS writes)

---

### Phase 2 — Multi-City (100K–1M DAU, 5–10 cities)

- City-level isolation introduced: separate DB shard, Redis namespace, and Dispatch worker pool per city
- 50 WebSocket servers (10K connections each)
- Redis Cluster: 5 nodes per city (dedicated to location index)
- PostgreSQL: 1 primary shard per city + 3 replicas
- Services split: Location Service, Dispatch Service, Pricing Service, Notification Service
- Kafka introduced for async fan-out (notifications, analytics, receipts)

**Bottleneck:** Dispatch worker CPU during evening peaks (single-threaded matching loops); surge recompute lag

---

### Phase 3 — Global Scale (1M–10M DAU, 50+ cities)

- Multi-region (US, EU, Asia-Pacific); each city pinned to its home region
- 150 WebSocket servers (auto-scaling)
- Redis Cluster: 20 nodes (location index sharded by H3 cell prefix)
- PostgreSQL: 10+ city shards per region, 3 replicas each
- Kafka: 6 brokers per region, MirrorMaker 2 for cross-region analytics sync
- Surge Worker: dedicated per-city process with hourly demand forecasts
- Island Mode: each city can operate fully independently during regional partitions

**Bottleneck:** Hot H3 cells near airports/stadiums; GPS smoothing CPU at 1M+ concurrent drivers

---

### Capacity Numbers @ 10M DAU

| Component | Per-Instance Capacity | Instances Needed |
|---|---|---|
| WebSocket servers | 10K connections | 150 (1.5M peak connections) |
| Location Service workers | 10K GPS writes/s | 100 (1M/s peak) |
| Dispatch workers | 20 matching ops/s | 75 (1,500 trips/s peak) |
| Redis (location index) | 50K ops/s | 20 nodes |
| PostgreSQL shards | 2K writes/s | 10 (with headroom) |
| Kafka brokers | 100K msg/s | 6 (3× replication) |

**Scaling triggers:**
- WebSocket: add server when avg connections > 8K
- Location Service: add worker when GPS write p99 > 80ms
- Dispatch: add workers when request→assign p99 > 3s
- Redis: add nodes when memory > 80%
- PostgreSQL: add shard when writes > 1.5K/s or storage > 500 GB

---

## 2. Failure Modes & Mitigation

### 1. Redis Location Cache Outage

**Impact:** Dispatch cannot find nearby drivers; matching halts; request→assign latency spikes to timeout

**Detection:**
- Redis command latency p99 > 10ms
- Dispatch `getNearbyDrivers` error rate > 1%
- Cache hit ratio drops to 0%

**Recovery:**
1. Redis Cluster automatically promotes a replica to primary (5–10s).
2. Cache rebuilds organically as drivers send their next GPS update (within 1–3s for active drivers).
3. In-flight requests retry via Dispatch worker backoff (3 attempts, 500ms spacing).

**Mitigation:**
- Fall back to last-known driver positions stored in driver device memory (reported in the reconnect payload).
- Shrink H3 search radius from ring-2 to ring-1 to reduce Redis read fan-out.
- Circuit breaker: if Redis unavailable > 10s → Dispatch switches to degraded mode (offer nearest known drivers from last cache snapshot).

**SLA impact:** 5–30s matching degradation per city during Redis failover; no data loss (PostgreSQL is source of truth)

---

### 2. Dispatch Service Overload (Offer Timeout Storm)

**Impact:** Low offer acceptance; rising request→assign latency; rider-facing "no cars available" errors

**Detection:**
- Request→assign p99 > 5s sustained for 3 minutes
- Offer acceptance rate < 50% for 5 minutes
- Dispatch worker CPU > 85%

**Recovery:**
1. Automatically expand H3 search to ring-3 (doubles search area).
2. Increase offer TTL from 15s to 20s (gives drivers more time to respond).
3. Horizontally scale Dispatch workers (auto-scaling triggers at CPU > 70%).
4. Temporarily increase surge multiplier by 0.5× to attract more drivers online.

**Mitigation:**
- Pre-warm dispatch worker pool before known demand spikes (stadium events, weather alerts).
- Rate-limit offer pushes per driver to 5 offers/minute to prevent driver app overload.
- Backpressure: shed non-critical enrichments (ETA accuracy boost, fraud pre-check) under high load.

**SLA impact:** Matching latency degrades from p99 5s to p99 8–12s during peak; recovers within 5–10 minutes of scaling

---

### 3. Pricing Service Lag / Surge Spike

**Impact:** Stale surge multipliers; fare quotes diverge from actual charges; rider cancellation spike

**Detection:**
- Surge recompute lag > 120s per cell batch
- Quote vs. final fare error > 20% for 5 minutes
- Pricing Service response time p99 > 200ms

**Recovery:**
1. Circuit breaker on Pricing Service → serve base fare (surge = 1.0×) from Redis fallback key.
2. Cap the live surge multiplier change to ±20% per recompute cycle (prevents oscillation).
3. Send rider a fare-revision notification if final fare exceeds quote by > 15%.

**Mitigation:**
- Cold-start fallback: if cell surge key is missing in Redis, serve city-level baseline surge.
- Cap maximum surge multiplier at 5× to prevent extreme fare shock.
- Precompute surge for the next 15 minutes using demand forecast during major events.

**SLA impact:** Minimal ride disruption; fare accuracy degrades temporarily; no trip data loss

---

### 4. Regional Network Partition (City Island Mode)

**Impact:** City's home region becomes unreachable; cross-region analytics and payment settlement stall

**Detection:**
- Cross-region health checks fail
- Kafka MirrorMaker replication lag > 5 minutes
- Payment settlement API unreachable

**Recovery:**
1. Each city operates in Island Mode — local dispatch, matching, and trip state are unaffected.
2. Payment pre-auth is preserved locally; settlement retried when connectivity restores.
3. Kafka events queue locally (7-day retention); MirrorMaker replays on reconnect.
4. Manual failover for cross-city analytics; no rider or driver impact during partition.

**Mitigation:**
- City-local dependencies: every in-trip action (GPS, offer, FSM transitions) uses city-local infrastructure only.
- Payment events idempotent — replaying queued events post-partition produces no double-charges.
- Operations runbook for declaring Island Mode and signaling all city services.

**SLA impact:** No rider/driver impact during partition; analytics and settlement delayed until reconnect

---

### 5. Mass GPS Reconnect (Driver App Update / Server Restart)

**Impact:** 1M drivers reconnect within a short window; WebSocket and Location Service overwhelmed; Redis cell sets temporarily empty

**Detection:**
- WebSocket connection rate > 50K/s (normal: ~1K/s)
- Redis SET ops spike to 5× baseline
- Location Service CPU > 90%

**Recovery:**
1. Load balancer distributes reconnects across all WebSocket servers (consistent hashing means some imbalance — handled by overflow routing).
2. Location Service applies request jitter: 100ms random delay per driver reconnect to spread the spike.
3. Redis cell sets repopulate within 3–5s as drivers send their first GPS update post-reconnect.

**Mitigation:**
- Exponential backoff on reconnect: 1s, 2s, 4s, max 30s — prevents simultaneous reconnect wave.
- Rolling driver app deployments: force-update only 5% of the driver fleet per hour.
- Pre-warm Redis cell sets from the last snapshot before a planned server restart.

**SLA impact:** 3–10s matching degradation during mass reconnect; no trip loss (in-progress trips resume from FSM state in PostgreSQL)

---

## 3. Monitoring & Alerts

### Dashboards

**1. Real-Time Operations**
- Request→assign latency p50/p95/p99 by city
- Offer acceptance rate by city
- Active drivers online and GPS freshness percentile

**2. System Health**
- WebSocket connection count per server
- Redis memory usage and eviction rate per node
- Kafka consumer lag per topic
- Dispatch worker CPU and queue depth

**3. Business Metrics**
- Trips completed per hour by city
- Cancellation rate (pre-assign vs post-assign)
- ETA accuracy (mean absolute error by city)
- Surge multiplier distribution

---

### Alerts

**Critical — page on-call immediately:**
- Request→assign p99 > 5s sustained for 3 minutes (any major city)
- Offer acceptance rate < 50% for 5 minutes
- Redis cluster node failure (automatic cluster promote + alert)
- Trip FSM error rate > 0.01%
- Payment pre-auth failure rate > 1%

**Warning — ticket for next business day:**
- GPS freshness: > 5% of active drivers last updated > 10s ago
- Kafka consumer lag > 50K messages
- Dispatch worker CPU > 70% sustained for 10 minutes
- Surge recompute lag > 120s for any cell batch

---

## 4. Operational Runbooks

### Runbook 1 — Expand Dispatch Search Radius (Low Acceptance Rate)

1. Confirm trigger: offer acceptance rate < 60% for 5 continuous minutes in target city.
2. Check supply: query `SELECT COUNT(*) FROM redis idx:cell:{pickup_cell}` for the affected area.
3. If supply is low (< 5 drivers in ring-1 + ring-2), expand search to ring-3 automatically via Dispatch config flag.
4. If supply is adequate but acceptance is low, check driver app connectivity (WebSocket error rate) — may be a push delivery issue, not a supply issue.
5. If neither resolves in 10 minutes, increment city surge multiplier by +0.5× to attract more drivers online.
6. Monitor acceptance rate for 5 minutes; revert radius expansion once rate recovers above 70%.

---

### Runbook 2 — Hot H3 Cell Mitigation (Airport / Stadium Event)

1. Detect trigger: single H3 cell with > 500 active drivers (extreme density) or > 200 concurrent ride requests.
2. Apply per-driver offer rate limit for drivers in the cell: max 2 offers/minute (prevents app overload).
3. Deploy a temporary "staging lot" virtual geofence: route overflow drivers to a designated waiting area 300–500 m from the hotspot.
4. Increase surge for the hot cell to 2× to redistribute rider demand to adjacent cells.
5. Dedicate 2 Dispatch workers exclusively to the hot cell during the event window.
6. After the event, drain the hot cell by gradually lowering surge back to city baseline over 30 minutes.

---

### Runbook 3 — City Failover to DR Region

1. Confirm partition: cross-region health check failures for > 5 minutes; Kafka MirrorMaker lag > 5 minutes.
2. Declare Island Mode for the affected city: notify all city services to operate locally only.
3. Redirect city DNS to DR region (TTL 60s — propagates within 1–2 minutes).
4. Verify DR region has a recent PostgreSQL replica (replication lag < 1 minute before failover).
5. Promote DR replica to primary; update connection pool in all city services.
6. Resume Kafka event replay: MirrorMaker processes queued events in order (idempotent consumers).
7. After primary region recovers: validate data consistency; replay any missed events; reverse DNS to home region.

---

## 5. Cost Breakdown (10M DAU — AWS Reference Pricing)

| Component | Configuration | Monthly Cost |
|---|---|---|
| WebSocket servers | 150 × c5.2xlarge | $37K |
| Location Service workers | 100 × c5.xlarge | $17K |
| Dispatch workers | 75 × c5.2xlarge | $19K |
| PostgreSQL | 10 shards × db.r5.2xlarge + replicas | $80K |
| Redis Cluster (location index) | 20 nodes × r5.xlarge | $35K |
| Kafka | 6 brokers × m5.2xlarge | $25K |
| S3 (location telemetry) | 1.3 TB/day × 30 = 39 TB | $1K |
| CloudFront / Data transfer | Cross-AZ + egress | $20K |
| **Total** | | **~$234K/month** |

**Cost per DAU:** ~$0.023 ($23 per 1,000 users/month)

**Optimization levers:**
- Reserved instances on PostgreSQL and Redis: −40% on compute
- Spot instances for Dispatch workers: −70% on matching compute (fault-tolerant, stateless)
- S3 Intelligent-Tiering for telemetry data older than 30 days: −30% on storage

---

## 6. Trade-Offs Summary

| Decision | What We Gain | What We Give Up |
|---|---|---|
| H3 over PostGIS | Sub-ms Redis scan; horizontal sharding | Approximate boundaries (not exact circle) |
| Hybrid push/pull dispatch | Speed + fallback durability | Two code paths to maintain; double-assign guard needed |
| PostgreSQL over Cassandra | ACID FSM; idempotent `ON CONFLICT` | Manual re-sharding; vertical ceiling |
| City-level shard isolation | Failure blast radius limited to one city | Cross-city queries require aggregation layer |
| Kalman filter for GPS | Smooth map display; correct H3 cell mapping | 1–2s smoothing lag for rapid position changes |
| Pre-auth hold at request | Zero non-payment risk post-trip | Rider's credit temporarily reduced; hold fees |
| Historical ETA profiles | Accurate without per-call traffic API cost | 24h lag for new road changes |

---

## 7. Key Takeaways

1. **Geospatial locality is everything:** Hexagonal H3 cells with Redis-backed set membership makes k-NN driver search O(rings) — the most critical operation in the system runs in < 10ms.
2. **Hybrid dispatch beats pure push:** Offering to N drivers first, then falling back to a pull queue, gives both speed and resilience. Never depend on a single driver accepting.
3. **City-level isolation over global monolith:** Sharding by city contains failures and allows independent scaling. An outage in São Paulo must never affect London.
4. **Trip FSM idempotency protects everything:** Every state transition is an `ON CONFLICT DO NOTHING` or `DO UPDATE`. Retries, network failures, and duplicate events are safe to replay.
5. **Location freshness over precision:** 1–3s stale driver positions are acceptable for dispatch. Design the TTL and heartbeat to automatically prune offline drivers — never rely on explicit deregistration.
6. **ETA accuracy is a trust metric:** Riders cancel when the ETA is consistently wrong. Invest in per-road-segment historical speed profiles early — they pay off in cancellation rate reduction.
7. **Pre-auth holds prevent post-trip fraud:** Authorizing payment before dispatching a driver removes the most common non-payment vector. The 1.5× buffer handles legitimate fare increases.

---

## 8. Interview Quick Reference

**Common pitfalls to call out:**
- Global driver table with no city partitioning (H3 scan becomes a full-table scan under load)
- Exact driver location shared with rider before assignment (privacy violation)
- Synchronous pricing recompute in the dispatch critical path (blocks matching under load)
- No idempotency on `acceptOffer` (two concurrent accepts both succeed → double-assign)
- GPS raw passthrough without outlier rejection (teleporting vehicles break H3 cell index)

**Key talking points:**
- H3 ring search: why hexagonal cells, how ring expansion works, how Redis set membership maps to cells
- Hybrid dispatch: push offer TTL, pull fallback queue, idempotent accept guard
- Trip FSM: state transitions, idempotency, how PostgreSQL `ON CONFLICT` enforces single-accept
- Surge pricing: precompute vs. real-time, clamping, cache invalidation
- City-level shard isolation: failure containment, Island Mode, DR failover steps

**Follow-up Q&A:**

| Question | Answer |
|---|---|
| Hot H3 cell handling? | Per-driver offer rate limits; staging lot geofences; increased surge to redistribute demand |
| Redis goes down — trips lost? | No. Redis holds hot location state only; PostgreSQL is the source of truth for all trip data |
| How do you prevent double-assignment? | Trip Service uses `SELECT FOR UPDATE` / `ON CONFLICT` on `acceptOffer`; only one driver can flip to Assigned |
| ETA accuracy improvements? | Per-road-segment historical speed profiles updated nightly; real-time scaling factor from live trip telemetry |
| How do you handle driver GPS spoofing? | Speed anomaly detection (> 100 m/s jump); Kalman outlier rejection; device integrity attestation; post-trip fraud model |
| When to go multi-region? | When a single city exceeds 500K concurrent drivers or p99 GPS latency > 100ms due to distance from the primary region |

---

## References

- **Uber Engineering:** Engineering Surge Pricing — H3 and Demand Forecasting
- **Lyft Engineering:** Cartographer — Real-Time Location at Lyft
- **Uber Engineering:** How Uber Computes ETA at the Lowest Latency
- **H3 Spec:** https://h3geo.org/docs/
- **Kalman Filter:** Welch & Bishop — An Introduction to the Kalman Filter (UNC TR 95-041)
- **Geospatial Indexing:** Postgres + PostGIS vs. Redis Geo vs. H3 — trade-off analysis
- **DDIA:** Kleppmann Ch. 9 (Consistency and Consensus) — CP vs. AP trade-offs
