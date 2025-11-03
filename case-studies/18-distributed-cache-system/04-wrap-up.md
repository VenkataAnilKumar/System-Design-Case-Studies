# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M QPS**
- Single Redis instance (16GB RAM); master-replica; sentinel
- Client-side hashing (mod N)

**1M → 10M QPS**
- Cluster with 10 shards (100GB total); consistent hashing
- Read replicas per shard; smart client library
- Persistence: RDB snapshots every 5 min

**10M → 50M QPS**
- Multi-region clusters; regional replicas for read locality
- Twemproxy for legacy clients; direct smart clients for performance
- Monitoring: Prometheus + Grafana; slow log analysis

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Master node crash | Writes fail; reads from replica | Sentinel misses 3 heartbeats | Auto-failover to replica (<30s); clients reroute |
| Replica lag spike | Stale reads | Replication offset gap | Add replicas; optimize network; alerts |
| Memory full | Evictions spike; hit rate drops | Memory usage > 90% | Scale horizontally; increase TTL; optimize data |
| Hot key | Single node overloaded | High CPU on one node | Shard hot key; use local cache; rate-limit |
| Network partition | Split-brain risk | Sentinel quorum loss | Quorum-based failover; fencing old master |

---

## SLOs

- p99 latency < 10ms (reads); < 20ms (writes)
- Hit rate > 95%
- Availability 99.99%; failover < 30s
- Replication lag < 1s

---

## Common Pitfalls

1. No TTL on keys → memory leak; set default TTL or max memory with eviction
2. Single hot key → CPU spike on one node; shard or replicate hot keys locally
3. Large values (>1MB) → network saturation; compress or split into smaller keys
4. Synchronous persistence → write latency spikes; use async AOF with fsync every second
5. No monitoring → blind to cache misses; instrument hit/miss rates per key pattern

---

## Interview Talking Points

- Consistent hashing mechanics and virtual nodes
- Master-replica replication and failover (sentinel vs. raft)
- Eviction policies: LRU vs. LFU vs. TTL-based
- Persistence tradeoffs: RDB vs. AOF vs. no persistence
- Hot key mitigation: local caching, sharding, rate-limiting

---

## Follow-Up Questions

- How to handle cache stampede (thundering herd)?
- How to implement cache warming strategies?
- How to support multi-region caching with geo-replication?
- How to optimize for read-heavy vs. write-heavy workloads?
- How to implement distributed locks (Redlock algorithm)?