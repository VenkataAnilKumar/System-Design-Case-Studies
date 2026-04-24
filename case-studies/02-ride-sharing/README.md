# Ride-Sharing Platform

## Problem Statement

Design an **Uber/Lyft-like ride-sharing system** that matches riders with nearby drivers in real-time with minimal latency.

**Core Challenge:** Handle 10M daily active users with 1M concurrent drivers streaming GPS at 1 Hz (1M updates/s at peak) while matching ride requests to drivers within 2–5 seconds (p99).

**Key Requirements:**
- Real-time driver location tracking (1 Hz GPS streaming, H3 geospatial indexing)
- Sub-5-second rider-to-driver matching (k-NN ring search on Redis-backed H3 cells)
- Dynamic surge pricing by micro-area (H3 cell-level, recomputed every 30–120s)
- Trip lifecycle management (Requested → Assigned → Driver Arrived → In Progress → Completed)
- ETA calculation using historical road-segment speed profiles
- Real-time push notifications to rider and driver apps at each state change

## Design Documents

| Document | Description |
|---|---|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M drivers, 1M GPS writes/s, 1,500 trips/s peak), bandwidth calc, compute sizing |
| [02-architecture.md](./02-architecture.md) | Components, GPS update sequence, request-to-assign sequence, trip FSM, ER diagram, API design |
| [03-key-decisions.md](./03-key-decisions.md) | 10 trade-off decisions: H3 vs Geohash, hybrid dispatch, Kalman filter, ETA models, pre-auth payment |
| [04-wrap-up.md](./04-wrap-up.md) | Phase 1/2/3 scaling playbook, 5 failure modes, 3 runbooks, cost breakdown (~$234K/month) |

## Key Metrics

| Metric | Target |
|---|---|
| **Matching Latency** | p50 < 1.5s, p99 < 5s (request → driver assigned) |
| **Location Write Latency** | p99 < 100ms (GPS → Redis) |
| **GPS Freshness** | 95% of active drivers updated within 3s |
| **ETA Accuracy** | Mean absolute error < 2 minutes |
| **Availability** | 99.95% |

## Technology Stack

- **Geospatial Index:** H3 hexagonal grid (res 9, ~200 m cells); driver sets stored in Redis
- **Dispatch:** Hybrid push (top-N offer) + pull (cell queue fallback)
- **Location Streaming:** WebSocket persistent connection; 1 Hz GPS frames
- **Surge Pricing:** Per-H3-cell recompute every 30–120s; cached in Redis; clamped ±20%/cycle
- **Trip Store:** PostgreSQL sharded by city; ACID FSM with idempotent `ON CONFLICT`
- **Async Fan-out:** Kafka for notifications, analytics, payment events, telemetry

## Quick Start (Interview Prep)

1. Start with the **matching critical path**: GPS → H3 cell → Redis set → k-NN ring scan → ranked offer → accept.
2. Walk through the **Trip FSM**: what states exist, which transitions are valid, why idempotency matters.
3. Explain **surge pricing**: how the multiplier is computed, why clamping is critical, how it's cached.
4. Cover **failure modes**: Redis down (fall back to device positions), Dispatch overload (expand radius + scale).
5. Discuss **city-level isolation**: why every component is city-sharded and what Island Mode means.

## Interview Focus Areas

1. **H3 Geospatial Indexing:** Hex cells vs. Geohash rectangles; why ring search is O(rings); Redis set membership
2. **Hybrid Dispatch:** Push offer to top-N; fall back to pull queue; idempotent double-assign guard
3. **Surge Pricing:** Cell-level demand signal; change clamping; Redis cache with TTL fallback
4. **GPS at Scale:** 1M updates/s inbound; Kalman smoothing; TTL-based stale driver prune
5. **Payment Pre-Auth:** Why authorize before dispatch; 1.5× buffer; idempotent capture at completion

## Related Case Studies

- **[01 — Real-Time Chat](../01-real-time-chat-application):** WebSocket at scale, Redis Pub/Sub routing, presence TTL patterns
- **[13 — Food Delivery](../13-food-delivery-platform):** Similar dispatch architecture with restaurant readiness signals
- **[29 — Proximity Service](../29-proximity-service):** Deep dive into Geohash/H3 radius search and geofencing
