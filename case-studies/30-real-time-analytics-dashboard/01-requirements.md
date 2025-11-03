# Requirements & Scale

## Functional Requirements
1. **Event Ingestion**: Collect events (page views, clicks, purchases) via SDK/API
2. **Pre-Aggregation**: Compute rollups (page views per minute, revenue per hour) in real-time
3. **Dashboards**: Visualize time-series (line graphs), breakdowns (pie charts), tables
4. **Drill-Down**: Click metric → filter by dimensions (country, device, campaign)
5. **Custom Queries**: Ad-hoc SQL-like queries (GROUP BY, WHERE, ORDER BY)
6. **Alerts**: Notify when metric exceeds threshold (traffic drop >20%)
7. **Historical Analysis**: Query data from last 90 days (hot), 1 year (warm), 7 years (cold)

## Non-Functional Requirements
**Ingestion**: 100K events/sec sustained, 1M peak
**Freshness**: <1min lag (event ingestion → queryable)
**Query Latency**: p99 <3s for 7-day dashboard, <10s for 90-day historical
**Concurrency**: 10K concurrent dashboard users
**Cost**: <$0.001/event ingestion + storage + query

## Scale Estimates
**Events**: 10B events/day = 115K events/sec avg, 1M/sec peak
**Event Size**: 1KB avg (timestamp, user_id, page_url, country, device, ...)
**Raw Storage**: 10B × 1KB = 10TB/day raw events
**Pre-Aggregated**: 1000 metrics × 1440 min/day = 1.4M data points/day (100× compression)
**Query Load**: 10K users × 10 dashboard refreshes/min = 100K queries/min = 1.6K queries/sec

**Infrastructure**:
- Streaming: Kafka (100 brokers) + Flink (500 workers)
- OLAP DB: ClickHouse (200 nodes) for pre-aggregated data
- Cache: Redis for frequently accessed dashboards
- Raw Storage: S3 for archival (10TB/day × 90 days = 900TB)

**Cost**: $500K/mo (compute) + $100K (storage) + $50K (Kafka/Flink) = **$650K/mo**
