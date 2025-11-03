# Key Technical Decisions

## 1. Pre-Aggregation vs. Raw Event Queries
**Decision**: **Pre-aggregation** (1-min rollups) for dashboards.
**Rationale**: Querying 10B raw events = 10s+ latency. Pre-aggregated = 1.4M rows = <3s latency. 100× data reduction.
**Reconsider**: For drill-down queries (rare dimensions), query raw events (accept 10s latency).

## 2. ClickHouse vs. Druid vs. Elasticsearch
**Decision**: **ClickHouse** for cost/performance.
**Rationale**: ClickHouse is fastest (columnar, vectorized queries), cheapest (open-source). Druid is complex. Elasticsearch is slow for aggregations.
**Reconsider**: For full-text search (logs), use Elasticsearch. For real-time ingestion (<1s lag), use Druid.

## 3. Stream Processing: Flink vs. Spark Streaming
**Decision**: **Flink** for true real-time (<1min lag).
**Rationale**: Flink has event-time processing (correct results with out-of-order events). Spark Streaming is micro-batches (2-5min lag).
**Reconsider**: For batch processing (hourly jobs), use Spark (simpler).

## 4. Caching: Per-Dashboard vs. Per-Query
**Decision**: **Per-dashboard caching** (1-min TTL).
**Rationale**: Dashboards are frequently accessed (90% cache hit). Per-query cache has low hit rate (infinite combinations).
**Reconsider**: For personalized dashboards (user-specific filters), use per-query cache.

## 5. Data Retention: Hot/Warm/Cold Tiering
**Decision**: **Hot (7d SSD), Warm (90d HDD), Cold (1y S3)**.
**Rationale**: 80% queries are last 7 days (hot). Warm/cold are rarely accessed (accept 10s latency).
**Reconsider**: For compliance (7-year retention), keep all data in cold storage (S3 Glacier).

## 6. Alerting: Threshold-Based vs. Anomaly Detection
**Decision**: **Threshold-based** (traffic drop >20%) with optional ML anomaly detection.
**Rationale**: Thresholds are simple, predictable. ML detects novel anomalies but has false positives.
**Reconsider**: For complex metrics (seasonality, trends), use ML anomaly detection.

## 7. Sampling: None vs. 1% for High-Volume Events
**Decision**: **Sampling for debug events** (1%), no sampling for business metrics (page views).
**Rationale**: Debug events (mouse moves) = 10× volume, low value. Business metrics must be accurate.
**Reconsider**: For cost reduction, sample all events (accept accuracy loss).

## 8. Query Timeout: 30s vs. No Limit
**Decision**: **30s timeout** for dashboard queries.
**Rationale**: Prevents expensive queries from consuming resources. Users expect <3s (30s is fallback).
**Reconsider**: For data science queries (complex ad-hoc), allow longer timeouts (5min).
