# 3) Key Design Decisions & Trade-Offs

## 1. Push vs. Pull Scheduling

**Decision**: Pull-based workers consuming from queues.

**Rationale**: Backpressure built-in; workers scale independently; network-friendly across regions.

**Trade-off**: Slightly higher dispatch latency vs. push; needs visibility timeouts/leases to handle duplicates.

**When to reconsider**: Ultra-low latency (<50ms) tasks; push can be considered with careful flow control.

---

## 2. At-Least-Once vs. Exactly-Once

**Decision**: At-least-once with idempotent tasks + dedupe keys.

**Rationale**: Exactly-once in distributed systems is expensive/fragile; idempotency is robust.

**Trade-off**: Requires developer discipline (idempotent side-effects); more metadata to track.

**When to reconsider**: Tasks that are pure computation (no side-effects) can be deduped more aggressively.

---

## 3. Centralized vs. Sharded Scheduler

**Decision**: Sharded by time bucket and tenant.

**Rationale**: Avoids single bottleneck; aligns with multi-tenant isolation.

**Trade-off**: Cross-shard coordination for DAGs spanning tenants (rare).

**When to reconsider**: If single-tenant deployment; centralized scheduler is simpler.

---

## 4. Queue Choice: Kafka vs. RabbitMQ

**Decision**: Kafka for scale and durability.

**Rationale**: High throughput; partitioning; replay; stronger ordering guarantees per partition.

**Trade-off**: Higher operational complexity; exactly-once semantics are nuanced.

**When to reconsider**: For small installations or strict per-message routing semantics, RabbitMQ/SQS is simpler.

---

## 5. Time Model: Timing Wheel vs. Cron Scan

**Decision**: Hierarchical timing wheel for timers; cron parser for schedule generation.

**Rationale**: Millions of timers with O(1) tick; cron-only scans get expensive at scale.

**Trade-off**: Implementation complexity; careful persistence of wheel state.

**When to reconsider**: If scale is <100K timers; a cron table scan may suffice.

---

## 6. Lease Backend: etcd/Consul vs. Redis

**Decision**: etcd/Consul for control-plane leases; Redis for rate limiting.

**Rationale**: Strong consistency and reliable watch semantics for leases; Redis excels at counters and buckets.

**Trade-off**: Operating both systems adds complexity.

**When to reconsider**: Managed control-plane (e.g., Cloud Spanner + Pub/Sub) may reduce ops burden.

---

## 7. Logs Storage: Object Store + Index vs. Full-Text in DB

**Decision**: Logs to object storage (S3) with searchable index (Loki/ELK).

**Rationale**: Cheap, scalable storage; efficient queries over metadata; streaming supported.

**Trade-off**: Searching full text requires index maintenance; eventual consistency in indexes.

**When to reconsider**: Low scale; storing logs in DB is simpler.
