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
