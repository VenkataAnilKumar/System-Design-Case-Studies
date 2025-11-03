# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Add PoPs in new regions; BGP anycast automatically routes
- Horizontal scale within PoP: Add cache servers; load balance with ECMP
- Storage: SSD/NVMe for hot cache; HDD for warm; evict cold
- Control plane: Shard customers; per-customer config in distributed KV store
- Analytics: Stream to Kafka; aggregate in data warehouse; cache dashboards

## Failure Scenarios
1) PoP outage
- Impact: Traffic reroutes to next-nearest PoP via BGP/DNS
- Mitigation: Multi-PoP redundancy; health checks; automatic failover

2) Origin down
- Impact: Cache hits still work; cache misses fail
- Mitigation: Serve stale content (stale-while-revalidate); queue purge requests

3) Cache stampede (thundering herd)
- Impact: Many edge servers miss simultaneously; hammer origin
- Mitigation: Origin shield collapses requests; request coalescing at edge

4) DDoS overwhelms PoP
- Impact: Legitimate traffic affected
- Mitigation: Blackhole attack IPs; rate-limit aggressively; failover to other PoPs

## SLOs & Metrics
- Cache hit rate > 90%; origin offload > 80%
- p95 latency < 50ms (edge); <150ms (including origin pull)
- Availability 99.99% per PoP; 99.999% global (multi-PoP)
- DDoS mitigation: Block > 99% of attack traffic

## Pitfalls and Gotchas
- Negative caching: Cache 404s; avoid repeated origin hits for missing content
- Vary header: Cache separately per Vary (e.g., Accept-Encoding); can fragment cache
- Long TTLs: Hard to update; balance freshness vs hit rate
- Purge propagation delay: Eventual consistency; some edges serve stale briefly

## Interview Talking Points
- Anycast vs GeoDNS; BGP routing basics
- Origin shield and request collapsing
- Cache eviction policies; LRU vs TTL
- Multi-layer DDoS protection

## Follow-up Q&A
- Q: Handle live video streaming?
  - A: HLS/DASH segments cached at edge; manifest dynamically generated; low TTL for live
- Q: Dynamic content (personalized APIs)?
  - A: Proxy through CDN but don't cache; SSL termination and DDoS still apply
- Q: Cert management at scale?
  - A: Let's Encrypt automation; centralized cert store; SNI at edge
- Q: Cost optimization?
  - A: Increase cache hit rate (longer TTLs, better eviction); compress responses; tiered pricing by region

---

This CDN design uses global anycast routing, multi-tier caching (edge + shield), TTL-based LRU eviction, and layered DDoS protection to deliver content with low latency and high availability while minimizing origin load.
