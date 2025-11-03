# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 10M tasks/day**
- Single scheduler + orchestrator; PostgreSQL; RabbitMQ; 100 workers
- Logs to local disk; rotate daily; simple UI

**10M → 100M tasks/day**
- Shard scheduler by tenant/time bucket; Kafka (6 brokers, 24 partitions)
- K8s for worker autoscaling; logs to S3 + Loki
- Partition metadata DB (Citus/CockroachDB); read replicas
- Rate limiting per tenant; backpressure policies

**100M → 1B tasks/day**
- Kafka 12 brokers, 96 partitions; dedicated clusters per region
- Timing wheel distributed across shards; checkpoint state to DB
- Global control plane with regional failover; mTLS everywhere
- Preemption + fair scheduling (DRF) across tenants

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Scheduler leader crash | Schedules not emitted | Leader heartbeat lost | Leader election; warm standby; replay due windows from DB |
| Orchestrator backlog | Ready tasks not dispatched | Queue depth rising | Scale orchestrator; shed load (pause low-priority tenants) |
| Worker partition | Tasks time out | Missed heartbeats | Revoke leases; re-enqueue; idempotency prevents double effects |
| Kafka outage | Dispatch halted | Producer/consumer errors | Retry with backoff; regional failover; buffer in DB |
| Hot partition (top-of-hour) | Burst overwhelms queue | Spikes in due tasks | Jittered schedules; spread-out cron; token bucket rate limits |
| Metadata DB hotspot | Slow API/UI | High p95 queries | Add read replicas; partition hot tables; cache DAG definitions |

---

## SLOs

- Schedule-to-dispatch p95 < 500ms
- Orchestrator availability 99.99%
- Task success rate > 99%
- Duplicate execution rate < 0.01% (idempotency failures)
- Log ingestion lag p95 < 5s

---

## Common Pitfalls

1. Non-idempotent tasks cause duplicate side-effects on retries
2. Cron spikes at top-of-hour overwhelm queues; add jitter
3. Long-running tasks without heartbeats leak capacity; enforce TTL + checkpointing
4. Using DB as a queue leads to lock contention; use proper brokers
5. Unbounded retries create feedback loops; cap attempts and dead-letter

---

## Interview Talking Points

- Why at-least-once with idempotency beats exactly-once in practice
- How a hierarchical timing wheel works and why it's efficient
- Handling mass retries/backfills without melting the control plane
- Designing leases/visibility timeouts to avoid duplicate work
- Multi-tenant fairness: quotas, DRF, preemption

---

## Follow-Up Questions

- How to support SLAs per DAG with preemption?
- How to integrate with GitOps for DAG versioning and rollbacks?
- How to run tasks across on-prem and cloud workers (hybrid)?
- How to support human approvals and manual steps in DAGs?
- How to support step-caching and incremental recomputation?
