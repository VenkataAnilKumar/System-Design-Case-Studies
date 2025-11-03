# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M devices**
- Single MQTT broker; Kafka (3 brokers, 6 partitions); InfluxDB single node
- Basic rules for alerts; no ML; 30-day retention

**1M → 10M devices**
- Clustered MQTT brokers; Kafka (6 brokers, 24 partitions); sharded InfluxDB
- Flink for stream processing; anomaly detection ML models
- S3 cold storage; retention policies (hot 7d, warm 90d, cold 7y)

**10M → 100M devices**
- Regional MQTT gateways; Kafka multi-region; TimescaleDB with compression
- Auto-scaling Flink; dedicated alerting infrastructure; OTA with canary rollouts
- Cost optimization: sampling (non-critical metrics at 1/10 rate), downsampling for old data

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| MQTT broker crash | Devices cannot send data | Broker health checks | Load balancer failover; devices reconnect with exponential backoff |
| Kafka partition leader failure | Ingestion paused | Kafka cluster alerts | Auto-elect new leader; ISR ensures no data loss |
| Flink checkpoint failure | State loss; duplicate processing | Checkpoint timeout | Retry from last successful checkpoint; idempotency prevents double-alerts |
| Time-Series DB overload | Write failures; query slow | Write latency spikes | Shard horizontally; reject non-critical writes; backpressure to Kafka |
| Alert storm (1000s/sec) | Notification saturation | Alert rate spike | Deduplication; rate-limit per user; batch digest emails |

---

## SLOs

- Ingestion success rate > 99.9%; message loss < 0.01%
- Alert latency p95 < 2s; false positive rate < 1%
- Query p95 < 3s (hot data); < 30s (warm data)
- OTA success rate > 98%; rollback within 5 min on failures

---

## Common Pitfalls

1. No server-side timestamping → device clock skew breaks windowed aggregations
2. Single Kafka partition per device → hot partition; shard by device_id range
3. No schema versioning → breaking changes brick old devices; use forward/backward compatibility
4. Unbounded state in stream processor → OOM; use TTL on state, evict old keys
5. Alert fatigue → too many false positives; tune thresholds; add deduplication

---

## Interview Talking Points

- MQTT vs. HTTP tradeoffs for IoT; persistent connections vs. stateless
- Stream processing state management (checkpoints, windows, TTL)
- Time-series DB sharding strategies (time, device, metric)
- Alerting deduplication and fan-out patterns
- OTA rollout strategies (canary, blue/green, rollback triggers)

---

## Follow-Up Questions

- How to support bidirectional communication (commands to devices)?
- How to handle devices with intermittent connectivity (offline buffering)?
- How to implement end-to-end encryption for device telemetry?
- How to scale anomaly detection models (per-device vs. fleet-wide)?
- How to support multi-tenancy (isolate customers' devices)?