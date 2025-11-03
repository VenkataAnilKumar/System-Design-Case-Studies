# 02-ride-sharing - Ride Sharing
Generated: 2025-11-02 20:38:43 -05:00

---

<!-- Source: 01-requirements.md -->
# 1) Requirements & Scale

## Functional Requirements

- Request ride: Rider provides pickup, optional destination, product (standard, XL, etc.)
- Driver app: Go-online/offline; stream GPS at 1 Hz; accept/decline requests
- Matching: Assign a nearby eligible driver within 2–5 seconds p99
- ETA/ETD: Show pickup ETA and trip time estimates
- Pricing & Surge: Quote upfront fare; dynamic surge by micro-area/time
- Trip lifecycle: Created → Driver-assigned → Driver-arrived → In-progress → Completed/Cancelled
- Notifications: Realtime updates to both rider and driver apps
- Payments: Hold and charge at trip completion; receipts
- Safety & Compliance: Phone masking, SOS, trip sharing, fraud checks

## Non-Functional Requirements

- Low latency: Request→assignment < 2–5s p99; location read/write < 100ms p99
- High availability: 99.95%+; degraded modes must keep core flows alive
- Global distribution: Multi-region; city-level isolation where possible
- Cost efficiency: Optimize compute for bursty evening peaks; cache geo reads
- Observability: Per-city SLOs; tail-latency budgets for dispatch critical path

## Scale & Back-of-the-Envelope

- DAU: ~10M (varies by region); monthly ~50–100M
- Concurrency: ~1M riders searching + ~1M drivers online at peaks
- Location updates: 1 Hz/driver → ~60M/minute (1M drivers); payload ~150B → ~9GB/min
- Ride requests: ~50K–200K RPS burst (promos, weather spikes)
- Matching searches: K-nearest drivers per request; K=20–100 within 1–3km

Storage rough cut:
- Hot location state (in-memory/Redis): driver_id → lat/lng/cell/last_seen (TTL 2–3 min)
- Trip store (SQL): ~100M trips/month; ~1–2KB/trip core + metadata/receipts separate
- Analytics lake (cold): events (request, offer, accept, start, end) via Kafka → object storage

## Constraints & Assumptions

- Assume mobile clients can reconnect and buffer small bursts (sub-10s)
- Network is flaky; GPS noisy. We smooth locations and tolerate drops
- City granularity: Everything (surge pools, dispatch queues) is city+hour aware
- Privacy: Never reveal exact driver location before assignment; mask PII during trip

## Success Measures

- Time to match (p50/p95/p99)
- Match rate (offers accepted / offers sent)
- Cancellation rate (pre-assign, post-assign)
- ETA accuracy (abs error and bias)
- Supply utilization (driver online time that’s engaged)




---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
  subgraph Clients
    Rider[Ride App (Rider)]
    Driver[Driver App]
  end

  subgraph Edge
    LB[Global LB / CDN]
    GW[API Gateway]
    WS[Realtime Gateway (WS/SSE)]
  end

  subgraph Core Services
    RiderSvc[Rider Service]
    DriverSvc[Driver Service]
    LocSvc[Location Service\n(H3/GeoIndex + Cache)]
    Dispatch[Matching / Dispatch Service]
    Pricing[Pricing / Surge Service]
    Trip[Trip Service\n(State Machine)]
    Notify[Notification Service]
  end

  subgraph Data
    Redis[(Redis Cluster\nHot location / caches)]
    PG[(PostgreSQL / OLTP)]
    ES[(Elastic/OLAP optional)]
    MQ[Kafka / Event Bus]
    OBJ[(Object Storage\nLogs/Receipts/Telem)]
  end

  Rider --> LB --> GW --> RiderSvc
  Driver --> LB --> GW --> DriverSvc
  Rider & Driver --> WS

  LocSvc <--> Redis
  Dispatch --> LocSvc
  Dispatch <--> Pricing
  Dispatch <--> Trip
  RiderSvc <--> Trip
  DriverSvc <--> Trip
  Trip <--> PG
  Pricing <--> PG

  RiderSvc --> MQ
  DriverSvc --> MQ
  Dispatch --> MQ
  MQ --> Notify
  Notify --> WS
  MQ --> OBJ
```

## Data Flow (Request → Assign) in 8 steps

1) Rider requests: app sends pickup (lat/lng), product, city → API Gateway → Rider Service
2) Rider Service validates, persists request stub (Trip=Requested) → PG; emits event request.created
3) Dispatch consumes event, queries Location Service for nearest eligible drivers in pickup cell + neighbors (H3 rings)
4) Pricing provides estimated fare and ETA; Dispatch ranks candidates (distance, ETA, acceptance likelihood, driver constraints)
5) Dispatch sends offer to top N drivers (push) via WS; also posts to per-cell queue for pull fallback
6) First accept wins: Driver accepts → WS → Dispatch; others get auto-expire
7) Dispatch updates Trip: Assigned(driver_id, ETA_pickup), notifies rider+driver via WS/Push
8) Background: Pricing locks fare; anti-fraud checks; navigation prefetch

## Location Updates

- Driver app streams GPS at 1 Hz → WS → Driver Service → Location Service
- Location Service maps lat/lng → H3 cell (resolution ~8–10), writes to Redis as:
  - loc:drv:{driver_id} → {lat,lng,cell,heading,ts}
  - idx:cell:{cell_id} → set(driver_id) with TTL/bloom filter to prune stale
- Smoothing: Kalman filter/simple averaging to denoise; outlier detection

## Core Data Model (minimal)

- trips(id PK, rider_id, driver_id, product, city, state, pickup_point, dropoff_point,
        quote_fare, final_fare, created_at, updated_at)
- offers(id PK, trip_id FK, driver_id, state[pending|accepted|declined|expired], ttl, created_at)
- drivers(id PK, status[online|offline|busy], city, rating, vehicle_class, updated_at)
- riders(id PK, rating, banned, created_at)

Indexes: trips(city,state,created_at), offers(trip_id,state), drivers(city,status,vehicle_class)

## APIs (sample)

- POST /v1/trips: create request {pickup, dest?, product}
- GET /v1/trips/:id: status/eta
- WS events: driver.offer, driver.offer_expired, trip.assigned, trip.arriving, trip.started, trip.completed
- Driver WS: driver.location_update, driver.accept_offer, driver.decline_offer

Auth: JWT per request/WS connect. Rate limit location updates; validate city affinity.

## Why These Components

- Location Service: optimized for k-NN by geo-cells (H3/Geohash) → fast ring scans; Redis for hot sets
- Dispatch: encapsulates matching policy; supports push (offer to candidates) and pull (drivers poll) hybrid
- Pricing: read-heavy with periodic recompute; cache surge factors per cell; protect from thundering herds
- Trip Service: source of truth for state transitions with ACID in PG; idempotent updates
- Event Bus: decouple analytics, receipts, fraud, and notifications from critical path

## Monitoring Cheat-Sheet

- Dispatch: request→assign latency p50/p95/p99; offer acceptance rate; retries; timeouts
- Location: update lag (age of last update), per-city cache hit, cell density skew
- Pricing: surge recompute latency; cache hit; quote vs final fare error
- Trip: FSM transition errors; idempotency conflicts; DB contention (locks)
- WS: connection churn; event delivery latency; drop/retry counts




---

<!-- Source: 03-key-decisions.md -->
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




---

<!-- Source: 04-wrap-up.md -->
# 4) Scale, Failures & Wrap-Up

## Scaling Playbook

- Partition by city → isolate failures, scale independently
- Location tier: Redis Cluster sharded by H3 prefix; MGET for neighbor cells
- Dispatch: Horizontal workers per city with rate limits; backpressure on offers
- Pricing: Precompute surge per cell every 30–120s; cache and serve from memory
- Trip DB: PG primary per city or per-region with logical sharding by city_id

## Failure Scenarios

1) Location Cache Outage
- Impact: Matching blind spots; rising assignment latency
- Mitigation: Fallback to last-known locations from driver device; shrink search radius; degrade features

2) Dispatch Backlog (Offer Timeouts)
- Impact: Low acceptance; long waits
- Mitigation: Expand search radius; lower N and T intelligently; temporarily increase surge factor; scale workers

3) Pricing Lag/Spike
- Impact: Bad quotes; cancellations
- Mitigation: Clamp surge delta; circuit-breaker to base pricing; recompute priority cells first

4) Regional Partition
- Impact: City isolated; cross-region services unreachable
- Mitigation: City-local dependencies; queue cross-region events; operate in island mode until heal

## Monitoring & SLOs

- Request→Assign latency: p50 < 1.5s, p95 < 3s, p99 < 5s
- Offer accept rate: > 70% in top cities (adjust per market)
- Location staleness: 95% of drivers < 3s old
- Surge recompute latency: p95 < 2s per cell batch
- Trip FSM errors: < 0.01%

## Pitfalls and Gotchas

- GPS noise: Snap-to-road and sanity checks; avoid teleporting vehicles
- Thundering herds: Surge/promos can flood dispatch; apply backpressure and fast reject
- Starvation: Same drivers getting all jobs; implement fairness constraints
- Clock skew: Server timestamps authoritative; avoid client-sourced ordering

## Interview Talking Points

- Why H3 grid and ring search? Explain locality, sharding, and cache efficiency
- Hybrid dispatch rationale with timeouts and radius expansion policy
- Trip FSM idempotency and exactly-once-ish semantics for payments
- Multi-region strategy: city pinning, failover, Island Mode operations

## Follow-up Q&A

- Q: How do you prevent offer spamming drivers?
  - A: Rate-limit per driver; exponential cooldown on declines; rotate candidates
- Q: ETA accuracy improvements?
  - A: Historical speed profiles per road segment; weather/events signals
- Q: Surge fairness?
  - A: Clamp changes; public rules; per-product caps; audit trail of adjustments
- Q: Handling mega events (concerts/stadium)?
  - A: Pre-warm cells, boost capacity, temporary pickup geofences and staging lots

---

This design prioritizes low-latency matching and operational isolation at city granularity, using H3-backed geo indexing, a hybrid dispatch model, and a strict trip FSM over a reliable SQL store, while decoupling analytics/pricing via an event bus.



