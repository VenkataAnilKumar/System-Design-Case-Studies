# Distributed Message Broker

## Problem Statement

Design a **Kafka/RabbitMQ-like distributed message broker** that provides high-throughput, durable messaging with exactly-once delivery semantics.

**Core Challenge**: Handle 1M messages/sec with <10ms p99 latency while ensuring durability (no message loss), ordering guarantees, and horizontal scalability.

**Key Requirements**:
- Pub/sub messaging with topic partitioning
- At-least-once, at-most-once, exactly-once delivery
- Message ordering per partition
- Message retention and replay
- Consumer groups with load balancing
- Replication for durability (3 replicas)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M msgs/sec, <10ms latency, exactly-once, durability) |
| [02-architecture.md](./02-architecture.md) | Components (Broker Cluster, Zookeeper/Raft, Consumer Groups) |
| [03-key-decisions.md](./03-key-decisions.md) | Partitioning, replication, delivery semantics |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to petabytes, failure scenarios, ordering guarantees |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Publish Latency** | p99 <10ms |
| **Throughput** | 1M msgs/sec per cluster |
| **Durability** | Zero message loss (3× replication) |
| **Availability** | 99.99% |

## Technology Stack

- **Log Storage**: Append-only commit log (segment files)
- **Partitioning**: Hash-based partitioning for parallelism
- **Replication**: Leader-follower with ISR (in-sync replicas)
- **Coordination**: ZooKeeper or Raft for cluster coordination
- **Consumer**: Pull-based consumption with offset tracking

## Interview Focus Areas

1. **Partitioning**: Hash key for ordered message delivery per partition
2. **Replication**: Leader writes, followers replicate asynchronously
3. **Exactly-Once**: Idempotent producer + transactional consumer
4. **Zero Copy**: Sendfile() for efficient disk-to-network transfer
5. **Consumer Groups**: Load balancing across consumers
