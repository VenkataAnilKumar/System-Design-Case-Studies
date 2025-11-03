# Observability & Monitoring Platform

## Problem Statement

Design a **Datadog/New Relic-like observability platform** that collects, stores, and visualizes metrics, logs, and traces from distributed systems at scale.

**Core Challenge**: Ingest 10M metrics/sec, 1M log lines/sec, and 100K traces/sec with <1s query latency for dashboards while storing 90 days of hot data and 1 year of cold data.

**Key Requirements**:
- Metrics collection (time-series, 10s granularity)
- Log aggregation and search (full-text, structured)
- Distributed tracing (trace ID propagation)
- Alerting with anomaly detection
- Dashboards with real-time updates
- Retention policies (hot/warm/cold storage)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10M metrics/sec, 1M logs/sec, <1s query latency) |
| [02-architecture.md](./02-architecture.md) | Components (Agents, Ingestion, Time-Series DB, Log Store, Query API) |
| [03-key-decisions.md](./03-key-decisions.md) | Time-series DB selection, log indexing, trace sampling |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to enterprise, failure scenarios, cost optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Ingestion Rate** | 10M metrics/sec, 1M logs/sec |
| **Query Latency** | p95 <1s for dashboards |
| **Retention** | 90 days hot, 1 year cold |
| **Availability** | 99.95% |

## Technology Stack

- **Metrics**: Prometheus/InfluxDB for time-series storage
- **Logs**: Elasticsearch for full-text search, S3 for cold storage
- **Traces**: Jaeger/Zipkin for distributed tracing
- **Ingestion**: Kafka for buffering, Fluentd/Vector for agents
- **Alerting**: PromQL queries + alertmanager

## Interview Focus Areas

1. **Time-Series Compression**: Gorilla compression (Facebook)
2. **Log Indexing**: Inverted index (Elasticsearch) vs columnar (ClickHouse)
3. **Trace Sampling**: Head-based vs tail-based sampling
4. **Cardinality Explosion**: High-cardinality labels (user_id) cause issues
5. **Retention Policies**: Hot (SSD), Warm (HDD), Cold (S3) tiering
