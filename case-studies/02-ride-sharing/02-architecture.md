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
