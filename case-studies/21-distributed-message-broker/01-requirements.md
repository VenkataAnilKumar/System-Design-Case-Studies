# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Publish/Subscribe: Producers send messages to topics; consumers subscribe
- Ordering: Per-partition ordering (within partition); global ordering optional
- Durability: Persist messages to disk; replicated; configurable retention (time/size)
- Delivery Semantics: At-least-once, at-most-once, exactly-once (idempotent producer + transactional consumer)
- Consumer Groups: Multiple consumers share partition load; offset management
- Backpressure: Consumers pull at own pace; no message loss if consumer slow
- Dead Letter Queue: Unprocessable messages routed to DLQ after retries
- Compaction: Keep only latest value per key (for change-data-capture)

## Non-Functional Requirements

- Throughput: 10M messages/sec; 100MB/sec per partition
- Latency: p99 < 10ms producer; < 50ms end-to-end (producer → consumer)
- Availability: 99.99% with replication; leader election < 5s
- Durability: Zero message loss with replication factor 3 and acks=all
- Scalability: 100K topics; 1M partitions; horizontal scaling

## Scale Estimate

- Messages: 10M/sec × 1KB avg = 10GB/sec = 864TB/day
- Retention: 7 days × 864TB = 6PB total (compressed to ~2PB)
- Partitions: 1M partitions × 3 replicas = 3M partition replicas
- Consumers: 100K consumer groups; avg 10 consumers/group = 1M consumers

## Constraints

- Ordering within partition only (not across partitions)
- Replication lag: Typically <100ms; can spike to seconds under load
- Compaction not real-time: Runs periodically (minutes)

## Success Measures

- Zero message loss (validated via end-to-end counters)
- p99 latency < 10ms producer; < 50ms consumer
- Replication lag p99 < 200ms
- Leader election < 5s; no data loss on failover