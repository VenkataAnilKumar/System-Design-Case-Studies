# Requirements & Scale

## Functional Requirements

### Core Capabilities
1. **Metrics Collection**: Scrape Prometheus exporters from services (pull model) or accept push via remote_write API
2. **Logs Aggregation**: Ingest structured logs (JSON) and unstructured logs (syslog) via agents (Fluentd, Vector)
3. **Distributed Tracing**: Collect spans (OpenTelemetry) with parent-child relationships, visualize request flows
4. **Alerting**: Evaluate alert rules (PromQL/LogQL) every 1min, send notifications via PagerDuty/Slack/email
5. **Dashboards**: Pre-built dashboards (CPU, memory, latency) and custom ad-hoc queries with Grafana
6. **Service Maps**: Auto-generate dependency graphs from trace data (service A → service B → database C)
7. **Log Search**: Full-text search with filters (timestamp, log level, service name, trace ID)

### Advanced Features
- **Anomaly Detection**: ML-based detection of metric/log anomalies (unsupervised learning)
- **SLO Tracking**: Define SLOs (99.9% availability), track error budgets, burn-rate alerts
- **Capacity Planning**: Trend analysis for resource utilization (predict when to scale)
- **Cost Attribution**: Break down observability costs per team/service (storage, query volume)
- **Multi-Tenancy**: Isolate metrics/logs/traces per tenant with RBAC
- **Long-Term Storage**: Archive old data to S3/GCS (90-day hot, 1-year warm, 7-year cold)

## Non-Functional Requirements

### Performance
- **Ingestion Throughput**: 10M metrics/sec, 1TB logs/day, 100K traces/sec
- **Query Latency**: p95 <3s for dashboard queries (7-day range), <10s for 90-day historical queries
- **Real-Time Alerting**: Alert rule evaluation within 1min of metric/log arrival

### Availability
- **Uptime**: 99.9% SLA (43min downtime/month)
- **Data Durability**: 99.999999999% (11 9's) via S3/GCS replication
- **Redundancy**: Multi-AZ deployment, no single point of failure

### Scalability
- **Services Monitored**: 5K services, 100K hosts/containers
- **Cardinality**: 100M unique metric time series (service × metric × labels)
- **Retention**: 30 days hot (queryable), 90 days warm (slower queries), 1 year cold (archived)
- **Users**: 1K concurrent dashboard users, 10K alert rules

### Cost Efficiency
- **Compression**: 10:1 compression for metrics (Gorilla encoding), 5:1 for logs (zstd)
- **Downsampling**: Aggregate 1s metrics to 1min after 7 days, 1h after 30 days
- **Smart Sampling**: Sample 1% of traces (high-volume services) vs. 100% (critical services)

## Scale Estimates

### Metrics (Prometheus-Compatible)
- **Ingestion Rate**: 10M metrics/sec = 600M metrics/min
- **Storage Per Metric**: 1 sample = 16 bytes (timestamp + float64 value)
- **Raw Storage**: 10M × 60s × 16 bytes = 9.6GB/min = 13.8TB/day (before compression)
- **Compressed Storage**: 13.8TB ÷ 10 = **1.4TB/day** (Gorilla encoding)
- **30-Day Retention**: 1.4TB × 30 = **42TB** hot storage

### Logs (Structured JSON)
- **Ingestion Rate**: 1TB/day = 11.6MB/s
- **Log Size**: 500 bytes/log avg (timestamp, level, service, message, trace_id)
- **Log Count**: 1TB ÷ 500 bytes = **2 billion logs/day**
- **Compressed Storage**: 1TB ÷ 5 = **200GB/day** (zstd compression)
- **30-Day Retention**: 200GB × 30 = **6TB** hot storage

### Traces (OpenTelemetry)
- **Ingestion Rate**: 100K traces/sec = 6M traces/min
- **Spans Per Trace**: 10 spans avg (frontend → backend → database → cache)
- **Span Size**: 2KB avg (service name, operation, duration, tags, logs)
- **Storage**: 100K × 10 × 2KB = 2GB/s = **172.8TB/day** (before sampling/compression)
- **Sampled Storage**: 172.8TB × 1% sampling = **1.7TB/day**
- **7-Day Retention**: 1.7TB × 7 = **12TB** (traces are short-lived, deleted faster than metrics/logs)

### Infrastructure
- **Time-Series DB** (VictoriaMetrics/Thanos): 42TB hot + 100TB warm (S3-backed)
- **Log Storage** (Elasticsearch/Loki): 6TB hot + 50TB warm
- **Trace Storage** (Jaeger/Tempo): 12TB hot
- **Query Nodes**: 50 nodes for metrics, 20 for logs, 10 for traces
- **Total Storage**: ~210TB hot/warm + 1PB cold (S3)

### Cost Estimation (Monthly)
- **Compute**: 80 nodes × $300/mo = $24K (c5.2xlarge equivalent)
- **Storage**: 210TB hot (SSD) × $0.10/GB = $21K, 1PB cold (S3) × $0.02/GB = $20K
- **Network**: 200TB/mo ingestion × $0.08/GB = $16K
- **Total**: **~$80K/mo** for entire observability platform

## Constraints
- **Cardinality Explosion**: Unbounded label values (e.g., user IDs in metrics) can create billions of time series → enforce label limits
- **Query Cost**: Ad-hoc queries on 90-day data can scan 100TB+ → enforce query timeouts (30s) and require time range filters
- **Data Sovereignty**: GDPR requires logs to stay in-region (EU data in EU, US data in US)
- **Sampling Trade-offs**: Aggressive trace sampling (0.1%) can miss rare errors → use adaptive sampling (sample 100% of errors)

## Success Measures
- **Detection Speed**: 95% of incidents detected within 2min of occurrence
- **MTTD (Mean Time To Detect)**: <5min via automated alerts
- **MTTR (Mean Time To Resolve)**: <30min with trace-based root cause analysis
- **Query Performance**: 95% of dashboard queries return in <3s
- **Cost Per Service**: <$50/mo per monitored service (all observability costs)
