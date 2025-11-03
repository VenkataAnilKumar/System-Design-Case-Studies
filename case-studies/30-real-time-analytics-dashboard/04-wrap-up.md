# Wrap-Up & Deep Dives

## Scaling Playbook
**Stage 1 (MVP)**: PostgreSQL, 1M events/day, hourly batch aggregation (Spark), 10s query latency.
**Stage 2 (Production)**: ClickHouse, 100M events/day, 1-min Flink streaming, 3s query latency, Redis cache.
**Stage 3 (Scale)**: 10B events/day, 500-node ClickHouse cluster, hot/warm/cold tiering, 90% cache hit rate, ML anomaly detection, multi-region.

## Failure Scenarios
- **Kafka Lag**: Flink falls behind → dashboard data is stale (5min lag instead of 1min). Auto-scale Flink workers.
- **ClickHouse Overload**: Too many concurrent queries → query timeout. Rate-limit queries, increase cache TTL.
- **Cache Stampede**: Dashboard cache expires, 1000 users query simultaneously → ClickHouse overload. Stagger cache expiration (jitter).

## SLO Commitments
- **Data Freshness**: <1min lag (p95) from event → queryable
- **Query Latency**: p99 <3s for 7-day dashboard, <10s for 90-day
- **Availability**: 99.9% uptime for dashboard service
- **Accuracy**: 99.9% of events ingested (0.1% acceptable loss for non-critical events)

## Common Pitfalls
1. **No Pre-Aggregation**: Querying raw events (10B rows) = 10s+ latency. Pre-aggregate to 1.4M rows (100× reduction).
2. **Hot Partitions**: Partition Kafka by user_id → popular users overload partition. Use round-robin or hash(user_id % 1000).
3. **Cache Stampede**: Dashboard cache expires → 1000 queries hit ClickHouse. Stagger expiration (TTL 60s ± 10s).
4. **No Query Timeout**: Expensive query scans 90 days × 10B events → crashes ClickHouse. Enforce 30s timeout.
5. **Ignoring Out-of-Order Events**: Mobile events arrive late (offline mode) → wrong aggregates. Use Flink event-time processing.

## Interview Talking Points
- **Pre-Aggregation**: "10B raw events → 1.4M pre-aggregated rows (1-min rollups) → 100× data reduction → <3s query latency."
- **ClickHouse**: "Columnar DB optimized for OLAP (aggregations) → 10× faster than PostgreSQL for analytics queries."
- **Flink Streaming**: "Tumbling windows (60s) → aggregate page views per country per device → <1min lag (event → queryable)."
- **Caching**: "Redis caches dashboards (1-min TTL) → 90% cache hit rate → reduces ClickHouse load 10×."

## Follow-Up Questions
1. **Cardinality Explosion**: User_id in dimensions (1B users) → 1B rows per metric. How to handle?
2. **Real-Time Joins**: Enrich events with user profile (user_id → country). How to minimize latency?
3. **Data Freshness vs. Cost**: <1min lag requires expensive streaming. When to use 5-min or hourly batches?
4. **Multi-Tenancy**: Isolate dashboards per customer (SaaS). How to prevent cross-tenant queries?
5. **Approximate Queries**: Use HyperLogLog for distinct counts (1% error, 10× memory savings). When to use?

**Final Thought**: Real-time analytics balances **freshness** (<1min lag via streaming) with **cost** (pre-aggregation reduces storage/query cost 100×). The key trade-off is **granularity**—store 1-min rollups for dashboards (cheap, fast), keep raw events for drill-downs (expensive, slow). ClickHouse's columnar storage + Flink's event-time processing + Redis caching = <3s dashboards at $0.001/event.
