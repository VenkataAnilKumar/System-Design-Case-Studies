# Distributed Cache System

## Problem Statement

Design a **Redis/Memcached-like distributed cache** that provides low-latency key-value storage with high availability and fault tolerance.

**Core Challenge**: Serve 1M requests/sec with <1ms p99 latency while maintaining 99.99% availability and handling node failures gracefully.

**Key Requirements**:
- Low-latency GET/SET operations (<1ms p99)
- Data partitioning (consistent hashing)
- Replication for fault tolerance (3 replicas)
- Eviction policies (LRU, LFU, TTL)
- Hot-key detection and mitigation
- Client-side intelligent routing

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M req/sec, <1ms latency, 99.99% availability) |
| [02-architecture.md](./02-architecture.md) | Components (Cache Nodes, Cluster Manager, Client Library) |
| [03-key-decisions.md](./03-key-decisions.md) | Consistent hashing, replication, eviction policies |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to petabytes, failure scenarios, hot-key mitigation |

## Key Metrics

| Metric | Target |
|--------|--------|
| **GET Latency** | p99 <1ms |
| **Throughput** | 1M req/sec per cluster |
| **Availability** | 99.99% (node failures tolerated) |
| **Cache Hit Rate** | >90% |

## Technology Stack

- **In-Memory Store**: Hash table with linked list (LRU)
- **Partitioning**: Consistent hashing (virtual nodes)
- **Replication**: Async replication to 2 replicas
- **Client**: Smart client with local routing table
- **Cluster Manager**: Gossip protocol for membership

## Interview Focus Areas

1. **Consistent Hashing**: Virtual nodes for uniform distribution
2. **Replication**: Async replication for low latency
3. **Eviction Policies**: LRU (least recently used) vs LFU (least frequently used)
4. **Hot-Key Mitigation**: Local caching, read replicas
5. **Split-Brain Prevention**: Quorum reads/writes
