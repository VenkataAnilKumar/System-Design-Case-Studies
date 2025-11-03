# 3) Key Design Decisions & Trade-Offs

## 1. Push vs. Pull for Consumers

**Decision**: Pull-based (consumers poll brokers).

**Rationale**: Natural backpressure; consumers control pace; no broker overload.

**Trade-off**: Consumers must loop; empty polls waste CPU (mitigated by long-poll).

**When to reconsider**: Real-time notifications; push via WebSocket may be better.

---

## 2. Replication: Sync vs. Async

**Decision**: Configurable (acks=all for sync ISR; acks=1 for async leader-only).

**Rationale**: Balance durability with latency; let producers choose.

**Trade-off**: acks=all adds 10-50ms latency; acks=1 risks message loss on leader crash.

**When to reconsider**: If all traffic is critical; enforce acks=all via broker config.

---

## 3. Partitioning: By Key vs. Round-Robin

**Decision**: Hash(key) % partitions if key provided; else round-robin.

**Rationale**: Ordering per key; load balancing when no key.

**Trade-off**: Hot keys cause partition skew; need re-partitioning or sub-partitioning.

**When to reconsider**: If keys are evenly distributed; hash partitioning works well.

---

## 4. Offset Storage: Broker vs. External

**Decision**: Store in broker (__consumer_offsets topic).

**Rationale**: Simplifies architecture; leverages broker durability; atomic commit with message processing (transactions).

**Trade-off**: Broker dependency; if broker down, cannot commit offsets.

**When to reconsider**: If external coordination needed (e.g., Flink checkpoints in S3).

---

## 5. Leader Election: ZooKeeper vs. KRaft

**Decision**: KRaft (Kafka-native Raft) for new clusters.

**Rationale**: Removes ZooKeeper dependency; faster recovery; simpler ops.

**Trade-off**: KRaft is newer (since Kafka 2.8); ZooKeeper more battle-tested.

**When to reconsider**: Legacy clusters; stick with ZooKeeper until KRaft is proven.

---

## 6. Retention: Time-Based vs. Size-Based

**Decision**: Both (whichever limit reached first).

**Rationale**: Flexibility; prevent disk full while honoring time requirements.

**Trade-off**: Complexity in cleanup logic; need monitoring for both.

**When to reconsider**: Pure streaming (no replay); short retention (hours) simplifies.

---

## 7. Compaction: Always vs. On-Demand

**Decision**: On-demand (enable per topic for CDC use cases).

**Rationale**: Most topics don't need compaction; adds overhead.

**Trade-off**: Compacted topics have higher read amplification; lag during compaction.

**When to reconsider**: If all topics are key-value stores (rare); enable by default.
