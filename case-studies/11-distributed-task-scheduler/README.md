# Distributed Task Scheduler

## Problem Statement

Design a **cron/Airflow-like distributed task scheduler** that reliably executes millions of scheduled jobs with exactly-once semantics.

**Core Challenge**: Schedule and execute 10M tasks/day with <1s scheduling latency, exactly-once guarantee, and handle worker failures gracefully.

**Key Requirements**:
- Schedule recurring tasks (cron expressions)
- Task dependencies (DAG execution)
- Retry with exponential backoff
- Distributed execution across worker pool
- Exactly-once execution (idempotency)
- Task monitoring and alerting

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10M tasks/day, exactly-once, <1s scheduling) |
| [02-architecture.md](./02-architecture.md) | Components (Scheduler, Task Queue, Worker Pool, State Store) |
| [03-key-decisions.md](./03-key-decisions.md) | Task distribution, exactly-once semantics, failure handling |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to enterprise, failure scenarios, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Scheduling Latency** | <1s (scheduled time to execution start) |
| **Exactly-Once** | 100% (no duplicate executions) |
| **Availability** | 99.95% |
| **Max Concurrent Tasks** | 100K workers |

## Technology Stack

- **Scheduler**: Time-wheel algorithm for efficient cron scheduling
- **Task Queue**: Kafka/RabbitMQ for task distribution
- **State Store**: PostgreSQL for task metadata, Redis for locks
- **Worker Pool**: Auto-scaling based on queue depth
- **Orchestration**: Kubernetes for worker management

## Interview Focus Areas

1. **Exactly-Once**: Distributed locks, idempotency keys
2. **DAG Execution**: Topological sort for task dependencies
3. **Retry Policies**: Exponential backoff, max retries
4. **Worker Failure**: Heartbeat monitoring, task reassignment
5. **Hot Partitions**: Popular tasks causing queue imbalance
