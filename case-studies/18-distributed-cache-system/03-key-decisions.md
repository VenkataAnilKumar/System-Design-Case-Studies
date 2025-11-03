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
