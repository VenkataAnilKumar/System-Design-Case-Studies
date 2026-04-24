# Chapter 1 — Requirements & Scale

> Goal: Define what we are building, how large it needs to be, and the first-order constraints that shape every architecture decision.

---

## What We Are Building

A ride-sharing platform (Uber/Lyft-like) that connects riders with nearby drivers in real time:

- Riders request rides by sharing their pickup location and product type (standard, XL, premium).
- Drivers stream GPS location at 1 Hz and accept or decline offers from the dispatch system.
- The platform matches a rider to a driver within 2–5 seconds (p99) using geospatial search.
- Dynamic pricing (surge) adjusts fares per micro-area based on real-time supply/demand.
- Both rider and driver receive live trip updates throughout the full lifecycle.

Scope (Phase 1): Design only (no code), production-credible, single primary region with city-level isolation.

---

## Core Requirements

### Functional

- **Request ride:** Rider provides pickup (lat/lng), optional destination, and product type.
- **Driver app:** Go online/offline; stream GPS at 1 Hz; accept/decline offers.
- **Matching:** Assign a nearby eligible driver within 2–5 seconds p99.
- **ETA calculation:** Show pickup ETA and estimated trip duration.
- **Dynamic pricing:** Upfront fare quote; surge multiplier recalculated every 30–120s per micro-area.
- **Trip lifecycle:** Requested → Assigned → Driver Arrived → In Progress → Completed / Cancelled.
- **Real-time notifications:** Push updates to rider and driver apps at each state change.
- **Payments:** Pre-authorize a hold at request time; capture final fare at trip completion.
- **Safety:** Phone number masking, SOS emergency button, in-trip share-your-ride link, fraud detection.

### Non-Functional

- **Matching latency:** request→assign p99 < 5s; p50 < 1.5s.
- **Location pipeline:** GPS write p99 < 100ms; read (dispatch query) p99 < 50ms.
- **Availability:** 99.95%+ (≤ 4.38 hours/year downtime).
- **Durability:** No trip state transitions or payment events must be lost.
- **City-level isolation:** An outage in one city must not cascade to others.
- **Cost-aware:** Optimize compute for bursty evening peaks; cache geo reads aggressively.

---

## Scale Targets

| Metric | Value |
|---|---|
| Daily active riders | 10M |
| Peak concurrent riders searching | 1M |
| Active drivers online (peak) | 1M |
| GPS location updates | 1 Hz/driver → **1M updates/s** (60M/min) at peak |
| Trip requests (avg) | ~200K trips/day (~2.3/s avg) |
| Trip requests (peak burst) | ~1,500/s (3× evening spike, promotions) |
| Avg trip duration | ~15 minutes |
| Concurrent active trips (peak) | ~500K |
| Matching search radius | K = 20–100 candidates within 1–3 km |

---

## Back-of-Envelope

### Storage

| Data | Size per Record | Volume | Total |
|---|---|---|---|
| Hot driver location (Redis) | ~500 B | 1M drivers | ~500 MB |
| Trip record (PostgreSQL) | ~2 KB | ~200M trips/year | ~400 GB/year |
| Location telemetry (Kafka → S3) | ~150 B/event | 1M/s × 86,400s | ~13 TB/day raw |
| Compressed Parquet on S3 | ~15 B/event (10× compression) | — | ~1.3 TB/day stored |
| Payment records | ~1 KB | 200M/year | ~200 GB/year |

### Bandwidth

| Flow | Rate | Bandwidth |
|---|---|---|
| Driver GPS inbound (location updates) | 1M/s × 150 B | **~150 MB/s** inbound |
| Rider location tracking (active trips) | 500K × 1 Hz × 150 B | ~75 MB/s outbound |
| Trip event stream (Kafka internal) | 1M events/min × 500 B | ~8 MB/s |
| **Total peak network** | | **~250 MB/s (~2 Gbps)** |

### Compute Sizing (Rule of Thumb)

| Component | Throughput per Instance | Instances Needed |
|---|---|---|
| WebSocket Gateway | 10K connections | 150 (1.5M peak connections) |
| Location Service | 10K writes/s | 100 (for 1M/s GPS peak) |
| Dispatch Workers | 20 matching ops/s | 75 (for 1,500 trips/s peak) |
| API Servers | 5K RPS | 10–20 (general REST traffic) |
| Redis (location index) | 50K ops/s | 20 nodes |
| PostgreSQL (trip store) | 2K writes/s per shard | 10 primary shards |
| Kafka | 100K msg/s per broker | 6 brokers (3× replication) |

---

## Constraints and Guardrails

- **GPS is noisy:** Apply Kalman filtering and snap-to-road; reject teleport jumps (> 100 m/s speed).
- **Network is flaky:** Mobile clients buffer and reconnect; state syncs on reconnect via trip ID.
- **City granularity:** Surge pools, dispatch queues, and DB shards are all city-aware.
- **Privacy:** Driver exact location is hidden from the rider until a driver is assigned.
- **Availability over consistency:** Prefer a slightly stale ETA over a failed request.
- **Idempotent payments:** Payment events are immutable; charge only on final confirmed trip state.
- **Backpressure:** Surge and promotions can spike dispatch load 5–10×; rate-limit offers per driver.

---

## Success Measures

| Metric | Target |
|---|---|
| Request → assign latency | p50 < 1.5s, p95 < 3s, p99 < 5s |
| Offer acceptance rate | > 70% (top cities) |
| GPS freshness | 95% of active drivers updated within 3s |
| ETA accuracy | Mean absolute error < 2 minutes |
| Match rate | > 90% of requests matched within 10s |
| Trip FSM error rate | < 0.01% |

---

## Out of Scope (Phase 1)

- Carpooling / multi-stop trip routing
- In-app turn-by-turn navigation (delegated to maps SDK)
- Driver earnings dashboard and weekly payouts
- Advanced ML demand forecasting and driver positioning nudges
- Full multi-region active-active (start with city pinned to home region + DR standby)
