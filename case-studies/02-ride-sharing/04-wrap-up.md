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
