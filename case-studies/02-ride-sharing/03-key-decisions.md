# 3) Key Decisions (Trade-offs)

## 1) Push vs Pull Dispatch

- Push: System offers to top-N drivers; fastest; enables policy control
- Pull: Drivers poll/claim jobs from nearby queue; simpler infra, more driver choice
- Choice: Hybrid. Push first to N; if no accept in T seconds, expose to pull queue
- When to reconsider: If driver autonomy or marketplace rules require bidding

## 2) Geo Index: H3/Geohash vs R-Tree

- H3/Geohash: Fixed grid cells; O(rings) neighbor scans; excellent cache locality
- R-Tree: True spatial index; better for sparse regions but harder to shard
- Choice: H3 grid at res 8–10, ring search up to radius; per-city sharding by cell prefix

## 3) Matching Objective and Constraints

- Objective: Minimize pickup ETA while preserving fairness and acceptance probability
- Constraints: Vehicle class fit, driver status, driver/rider ratings, city policies
- Ties: Use driver recency/fatigue, load balancing across zones

## 4) Pricing & Surge Model

- Surge inputs: supply/demand per cell, queue length, forecast
- Recompute cadence: 30–120s per cell; clamp changes to avoid oscillation
- Choice: Cache surge factors; cold-start fallbacks; guardrails on max surge

## 5) Source of Truth Stores

- Hot location: Redis (TTL, sets per cell) + periodic snapshot to object storage
- Trips/Offers/Accounts: PostgreSQL with strict FSM and idempotency keys
- Analytics/ML: Kafka to lakehouse (S3/ADLS) with batch/stream processing

## 6) Consistency Model

- Strong consistency for trip state transitions (CP) in single region per city
- Eventual consistency for surge, analytics, and secondary views
- Multi-region: City pinned to a home region; failover playbook per city

## 7) Mobile Realtime Transport

- Choice: WebSocket for bi-directional; fallback to SSE/long-polling for constrained networks
- Sticky routing for drivers to keep cell locality; JWT on connect + refresh

## 8) Anti-Fraud & Safety Hooks

- Device integrity signals; location jump detection; duplicate device checks
- Masked calling; SOS event priority path; anomaly alerts to safety team
