# Real-Time Analytics Dashboard

## Problem Statement

Design a **Google Analytics/Mixpanel-like real-time analytics dashboard** that ingests events, pre-aggregates metrics, and visualizes data with <1-minute freshness.

**Core Challenge**: Ingest 10B events/day (115K events/sec average, 1M peak) with <1min lag (event → queryable) and serve dashboards with <3s p99 query latency for 7-day time ranges.

**Key Requirements**:
- Event ingestion via SDK/API (page views, clicks, purchases)
- Pre-aggregation (rollups by minute, hour, day)
- Dashboard visualization (time-series, breakdowns, tables)
- Drill-down and filtering (by country, device, campaign)
- Custom queries (ad-hoc GROUP BY, WHERE, ORDER BY)
- Alerts (notify when metric exceeds threshold)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10B events/day, <1min lag, <3s query latency) |
| [02-architecture.md](./02-architecture.md) | Components (Ingestion API, Stream Processor, OLAP DB, Query Service) |
| [03-key-decisions.md](./03-key-decisions.md) | Pre-aggregation, ClickHouse vs Druid, caching strategies |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to trillions of events, failure scenarios, cost optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Freshness** | <1min lag (event → queryable) |
| **Query Latency** | p99 <3s for 7-day dashboard |
| **Ingestion Rate** | 1M events/sec peak |
| **Concurrency** | 10K concurrent dashboard users |

## Technology Stack

- **Ingestion**: Kafka for event buffering
- **Stream Processing**: Apache Flink for 1-min pre-aggregation
- **OLAP Database**: ClickHouse (columnar, fast aggregations)
- **Caching**: Redis for frequently accessed dashboards (1-min TTL)
- **Query API**: GraphQL or REST for dashboard queries

## Interview Focus Areas

1. **Pre-Aggregation**: Aggregate events every 1 min → 100× data reduction
2. **ClickHouse**: Columnar storage for fast aggregations (GROUP BY, SUM)
3. **Freshness**: <1min lag via Flink tumbling windows
4. **Caching**: Cache dashboard results with 1-min TTL (90% hit rate)
5. **Hot/Cold Tiering**: Last 7 days on SSD (hot), 90 days on HDD (warm)
