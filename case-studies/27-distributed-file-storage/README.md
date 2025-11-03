# Distributed File Storage

## Problem Statement

Design an **S3/Google Cloud Storage-like distributed file storage** system that provides durable, highly available object storage at scale.

**Core Challenge**: Store 10B objects (10PB total) with 11 9's durability (99.999999999%), serve 100K requests/sec with <100ms p99 latency, and support cross-region replication.

**Key Requirements**:
- PUT/GET/DELETE objects via REST API
- Versioning (store multiple versions of same object)
- Cross-region replication for disaster recovery
- Erasure coding (reduce storage cost vs replication)
- Metadata search (list by prefix, tags)
- Lifecycle policies (auto-delete after 90 days, transition to cold storage)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10B objects, 11 9's durability, <100ms latency) |
| [02-architecture.md](./02-architecture.md) | Components (API Gateway, Metadata Service, Data Nodes, Replication) |
| [03-key-decisions.md](./03-key-decisions.md) | Erasure coding, metadata sharding, lifecycle management |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to exabytes, failure scenarios, durability guarantees |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Durability** | 11 9's (lose <1 object per 10B per year) |
| **Availability** | 99.99% for standard, 99.9% for cold storage |
| **Latency** | p99 <100ms for hot data, <1s for cold |
| **Throughput** | 100K requests/sec |

## Technology Stack

- **Metadata**: Cassandra/DynamoDB for object metadata (sharded by key)
- **Data Storage**: Erasure coding (Reed-Solomon 10+4) for cost efficiency
- **Replication**: 3× replication for hot data, erasure coding for cold
- **Lifecycle**: Background jobs for auto-transition and deletion
- **Object Lock**: Immutability for compliance (WORM storage)

## Interview Focus Areas

1. **11 9's Durability**: 3× replication + cross-region + erasure coding
2. **Erasure Coding**: Reed-Solomon (10+4) = 1.4× overhead vs 3× replication
3. **Metadata Sharding**: Partition by hash(bucket+key) for scalability
4. **Lifecycle Policies**: Auto-transition to cold storage after 30 days
5. **Versioning**: Store multiple versions with soft delete
