# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M messages/sec**
- 3-broker cluster; 100 partitions; replication factor 3
- Single ZooKeeper ensemble; basic monitoring

**1M → 10M messages/sec**
- 20-broker cluster; 1000 partitions; rack-aware placement
- KRaft for leader election; tiered storage (S3 for old segments)
- Producer tuning (batching, compression, idempotence)

**10M → 100M messages/sec**
- Multi-cluster per region; 100+ brokers per cluster
- Federation or mirroring for cross-region replication
- Advanced monitoring (Prometheus, Grafana); quotas per client

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Leader broker crash | Partition unavailable briefly | Heartbeat timeout | Controller elects new leader from ISR (<5s); no data loss |
| ISR shrink (replica lag) | Durability risk | ISR count < min.insync.replicas | Alert; investigate slow replica; reject writes if ISR too small |
| Consumer lag spike | Delayed processing | Lag > threshold | Scale consumers; optimize processing; backpressure upstream |
| Disk full | Writes rejected | Disk usage > 90% | Retention cleanup; add brokers; alert |
| Network partition | Split-brain risk | ZooKeeper/KRaft quorum loss | Fencing via epoch; reject stale leaders; manual intervention |

---

## SLOs

- p99 producer latency < 10ms; end-to-end < 50ms
- Zero message loss with acks=all and replication factor 3
- Leader election < 5s; replication lag p99 < 200ms
- Consumer lag < 1M messages (or 10s lag for real-time)

---

## Common Pitfalls

1. Under-partitioned topics → throughput bottleneck; over-partition early (but not >1K/broker)
2. No idempotent producer → duplicates on retry; enable idempotence
3. Auto-commit offsets → message loss if consumer crashes before processing; use manual commit
4. Hot partitions (single key sends all traffic) → partition skew; use composite keys or sub-partition
5. Ignoring consumer lag → messages pile up; alert and autoscale consumers

---

## Interview Talking Points

- Append-only log mechanics and why it's fast (sequential I/O)
- ISR replication and acks tradeoffs (durability vs. latency)
- Consumer group rebalancing and offset management
- Leader election via ZooKeeper/KRaft and split-brain prevention
- Exactly-once semantics (idempotent producer + transactional consumer)

---

## Follow-Up Questions

- How to handle poison pill messages (consumer crashes on one message)?
- How to implement schema evolution (Avro, Protobuf) with registry?
- How to support multi-tenancy with quotas and isolation?
- How to mirror topics across data centers (active-passive vs. active-active)?
- How to implement tiered storage (hot on SSD, cold on S3)?