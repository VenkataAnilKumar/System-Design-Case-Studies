# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Separate write path (publish) and read path (fetch) with Kafka in the middle
- Shard timelines by user_id; bound hot keys with per-bucket rows
- Use Redis for hot home pages; TTL + LFU; prefetch next page on read
- Celebrity handling: force pull path; CDN for media; rate-limit fanout tasks
- Ranking: feature cache; circuit-breakers and timeouts; fallback to recency

## Failure Scenarios
1) Fanout backlog spike
- Impact: Freshness degrades
- Mitigation: Prioritize active users first; drop tail for inactive; expand pull coverage

2) Redis outage
- Impact: Read latency up; hit durable store more
- Mitigation: Read-through to NoSQL; enable recency-only mode; tighten page size

3) Ranking service timeout
- Impact: Latency spikes
- Mitigation: Enforce 50–80ms budget; fallback to recency; log model fallback rate

4) Counter drift
- Impact: Incorrect like counts
- Mitigation: Periodic reconciliation job; switch to exact on demand

## SLOs & Metrics
- Freshness lag p95 < 3s; feed p95 < 200ms; cache hit > 90%
- Fanout success > 99.9%; backlog drains within 5 minutes at 2× peak
- Ranking p95 < 80ms; fallbacks < 5%

## Pitfalls and Gotchas
- Hot keys: Popular posts/users; shard by post_id or use consistent hashing
- Privacy leaks: Double-check visibility at both write and read
- Ranking bias: Feedback loops (popular gets more popular); inject diversity
- Abuse/spam: Rate limits; shadow bans; ML-based detection

## Interview Talking Points
- Hybrid fanout rationale; celebrity handling
- Timeline storage design; pagination and hotset management
- Ranking latency budgets and graceful degradation
- Counters consistency and reconciliation strategy

## Follow-up Q&A
- Q: How handle viral posts?
  - A: Pre-warm cache; throttle fanout; prioritize pull for author if followers spike
- Q: Real-time vs batch ranking?
  - A: Hybrid; online for top K with cached features; offline for model training
- Q: Multi-language feed?
  - A: Translate on demand (cache translations); or serve in author's language + auto-translate button
- Q: Content moderation at scale?
  - A: ML classifiers on publish; human review queue; user reports; takedown workflow

---

This feed design balances read latency and write cost via hybrid fanout, keeps hot timelines in Redis with durable NoSQL backing, and uses ranking with strict time budgets and fallbacks to maintain usability during incidents.
