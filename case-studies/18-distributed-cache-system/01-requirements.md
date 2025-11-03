# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Basic Operations: GET, SET, DELETE; TTL per key; atomic operations (INCR, DECR)
- Data Structures: Strings, hashes, lists, sets, sorted sets
- Eviction: LRU, LFU, TTL-based; configurable per namespace
- Replication: Master-replica; async replication; failover
- Partitioning: Consistent hashing; virtual nodes; rebalancing
- Persistence: Optional snapshots + AOF (append-only file) for durability
- Pub/Sub: Channels for real-time notifications
- Transactions: Multi-key ops with WATCH/EXEC (optimistic locking)

## Non-Functional Requirements

- Latency: p99 < 10ms for reads; p99 < 20ms for writes
- Throughput: 10M QPS reads; 1M QPS writes per cluster
- Availability: 99.99% with automatic failover (< 30s downtime)
- Consistency: Eventual for replicas; strong for single master
- Durability: Configurable (in-memory only vs. persist to disk)

## Scale Estimate

- Keys: 1B keys × 1KB avg = 1TB per cluster (10TB total across clusters)
- Traffic: 10M reads/sec; 1M writes/sec; 11M total ops/sec
- Memory: 10TB RAM across 1000 nodes (10GB/node)

## Constraints

- Memory-bound: Hot data only; cold data evicted or in disk (Redis + RocksDB)
- Network saturation: High QPS → need local replicas per region

## Success Measures

- Cache hit rate > 95%
- p99 latency < 10ms
- Failover time < 30s; zero data loss for persisted keys
- CPU utilization < 70% per node