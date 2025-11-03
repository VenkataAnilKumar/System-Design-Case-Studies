# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 100K QPS**
- Single-region ad servers; Redis for caps; ClickHouse for reporting
- Basic targeting; contextual fallback; single CDN

**100K → 1M QPS**
- Global edges; campaign sharding; bitmap indices for eligibility
- Multi-tenant KV cluster; Flink streaming to OLAP; near-real-time dashboards
- Fraud detection models; viewability measurement

**1M → 2M+ QPS**
- Anycast routing; per-campaign leaders for pacing; cross-region replication
- Hot key mitigation (user hashing, sharded caps)
- Stricter SLA monitors; automatic traffic shedding on overload

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| KV node loss | Caps inaccurate | Error rates; replication lag | Replicate; fallback to approximate caps; rebuild from snapshots |
| Edge region outage | Latency spikes | RUM latency | Route to nearest healthy edge; adjust budgets |
| Analytics lag | Reporting delayed | Consumer lag | Backpressure; prioritize impression logs; degrade click enrichers |
| Policy service down | Unsafe placements | Health checks | Fail-safe: block unknown categories; conservative policies |

---

## SLOs

- p95 ad decision latency < 100ms; timeouts < 0.1%
- Pacing error < ±5%
- Frequency cap miss < 0.1%
- Reporting freshness p95 < 5 min

---

## Common Pitfalls

1. Hot user keys causing skew; shard keys and apply TTL
2. Overly complex targeting causing slow eligibility; precompute bitmaps
3. Logging synchronously on hot path; always async with disk buffer
4. Ignoring consent → regulatory risk; strict gating with contextual fallback
5. Single-region budget counters → overspend; elect per-campaign leaders

---

## Interview Talking Points

- Latency budgeting and edge footprint strategies
- Pacing algorithms under strong consistency constraints
- Frequency capping data structures at massive scale
- Real-time analytics pipeline architecture and backpressure
- Privacy-first design and contextual fallback quality

---

## Follow-Up Questions

- How to support video ads with viewability events (quartiles)?
- How to run multi-armed bandits for creative optimization?
- How to guarantee SLOs under header bidding traffic bursts?
- How to design anti-fraud features without adding hot path latency?
