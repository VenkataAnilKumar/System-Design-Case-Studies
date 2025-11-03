# 18-distributed-cache-system - Distributed Cache System
Generated: 2025-11-02 20:38:45 -05:00

---

<!-- Source: 01-requirements.md -->
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



---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
	subgraph Clients
		App1[App Service]
		App2[Batch Job]
	end

	subgraph Access
		ClientLib[Smart Client Library]
		Proxy[Cache Proxy (Twemproxy/Envoy)]
	end

	subgraph Cache Cluster
		CHRing[Consistent Hash Ring]
		NodeA[Cache Node A]
		NodeB[Cache Node B]
		NodeC[Cache Node C]
		ReplicaA[Replica A]
		ReplicaB[Replica B]
	end

	subgraph Persistence
		AOF[(AOF Log)]
		RDB[(RDB Snapshots)]
	end

	subgraph Control
		Sentinel[Sentinel/Raft\nFailover]
		Metrics[Monitoring]
	end

	App1 --> ClientLib
	App2 --> Proxy
	ClientLib --> CHRing
	Proxy --> CHRing
	CHRing --> NodeA
	CHRing --> NodeB
	CHRing --> NodeC
	NodeA --> ReplicaA
	NodeB --> ReplicaB
  
	NodeA --> AOF
	NodeA --> RDB
	NodeB --> AOF
	NodeB --> RDB
  
	Sentinel -.-> NodeA
	Sentinel -.-> NodeB
	Metrics -.-> NodeA
	Metrics -.-> NodeB
```

## Components

- Cache Nodes: In-memory storage (Redis/Memcached); single-threaded or multi-threaded
- Consistent Hashing Ring: Virtual nodes (1000/physical node); rebalance on add/remove
- Replication: Master-replica per shard; async replication; sentinel/raft for failover
- Client Library: Smart client; maintains hash ring; routes requests; connection pooling
- Proxy Layer (Optional): Twemproxy/Envoy for legacy clients; routing + load balancing
- Persistence: RDB snapshots (forked process); AOF (append-only log); hybrid
- Monitoring: Metrics (hit rate, evictions, latency); slow log; memory usage

## Data Flows

### A) GET (Cache Hit)

1) Client hashes key → node ID via consistent hashing
2) Send GET to node; node looks up key in hash table (O(1))
3) If exists → return value; update LRU metadata
4) If TTL expired → return null; evict key

### B) SET (Write)

1) Client hashes key → node ID
2) Send SET to master node; master writes to memory
3) If persistence enabled → append to AOF; async flush to disk
4) Async replicate to replica nodes (eventually consistent)
5) Return success to client

### C) Node Failure & Failover

1) Sentinel detects master down (3 heartbeats missed)
2) Sentinel quorum votes; promote replica to master
3) Update hash ring; notify clients (via pub/sub or health check)
4) Clients reroute traffic to new master

### D) Rebalancing (Add Node)

1) New node joins; hash ring recalculated with virtual nodes
2) Some keys migrate from existing nodes to new node (consistent hashing minimizes moves)
3) Clients update hash ring; start routing new keys to new node
4) Background migration of existing keys (lazy or proactive)

## Data Model

- keys(key, value, ttl, created_at, accessed_at)
- metadata(node_id, memory_used, evictions, hit_rate)
- replication(master_node_id, replica_node_ids[], lag)

## APIs

- GET key
- SET key value [TTL seconds]
- DELETE key
- INCR key
- LPUSH key value (list)
- ZADD key score value (sorted set)
- PUBLISH channel message

Auth: Optional password; TLS for encryption; client cert auth for mTLS.

## Why These Choices

- Consistent hashing: Minimal key movement on node add/remove (only ~1/N keys move)
- Single-threaded per key: Simplifies concurrency; high throughput via multiplexing (epoll)
- Async replication: Lower latency for writes; acceptable for cache (eventual consistency OK)
- Smart client: Avoids proxy hop; lower latency; clients have latest hash ring

## Monitoring

- Hit rate; miss rate; eviction rate
- p50/p95/p99 latency per operation
- Memory usage; fragmentation; swap
- Replication lag; failover events



---

<!-- Source: 03-key-decisions.md -->
# 3) Key Design Decisions & Trade-Offs

## 1. Consistent Hashing vs. Hash Slot

**Decision**: Consistent hashing with virtual nodes.

**Rationale**: Minimal key movement on rebalancing; even load distribution.

**Trade-off**: More complex implementation; clients need hash ring updates.

**When to reconsider**: If Redis Cluster (hash slot) is acceptable; simpler protocol.

---

## 2. Master-Replica vs. Peer-to-Peer

**Decision**: Master-replica with sentinel failover.

**Rationale**: Simpler consistency model; single write path per shard.

**Trade-off**: Write bottleneck at master; read scaling via replicas only.

**When to reconsider**: If write-heavy; consider sharding or multi-master (conflict resolution needed).

---

## 3. Persistence: RDB vs. AOF vs. Hybrid

**Decision**: Hybrid (RDB snapshots + AOF for recent changes).

**Rationale**: Fast recovery (load RDB); durability (replay AOF for delta).

**Trade-off**: Disk I/O overhead; slower writes if fsync every write.

**When to reconsider**: Pure cache (no persistence); turn off for max performance.

---

## 4. Eviction: LRU vs. LFU

**Decision**: LRU (Least Recently Used) default; LFU optional.

**Rationale**: LRU simple and effective for temporal locality; LFU better for skewed access.

**Trade-off**: LRU can evict popular but old keys; LFU needs frequency counters (more memory).

**When to reconsider**: Analyze access patterns; if Zipf-heavy, LFU may improve hit rate.

---

## 5. Smart Client vs. Proxy

**Decision**: Smart client for performance; proxy for legacy clients.

**Rationale**: Smart client saves proxy hop (~2-5ms); proxy simplifies clients.

**Trade-off**: Smart client complexity; all clients need hash ring logic.

**When to reconsider**: If many languages/platforms; centralize routing in proxy.

---

## 6. Replication: Sync vs. Async

**Decision**: Async replication.

**Rationale**: Lower write latency; cache data is non-critical (eventual consistency OK).

**Trade-off**: Data loss if master crashes before replication completes.

**When to reconsider**: If durability critical; use sync replication (higher latency).

---

## 7. Data Structures: Simple KV vs. Rich Types

**Decision**: Support rich types (lists, sets, sorted sets, hashes).

**Rationale**: Enables complex use cases (leaderboards, session stores, queues).

**Trade-off**: More memory overhead; complex eviction (evict whole structure vs. elements).

**When to reconsider**: Pure cache; stick to simple KV for lower footprint.




---

<!-- Source: 04-wrap-up.md -->
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


