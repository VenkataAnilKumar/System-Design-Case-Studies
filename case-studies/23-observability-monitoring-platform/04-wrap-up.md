# Wrap-Up & Deep Dives

## Scaling Playbook

### Stage 1: MVP (10 Services, 1K Metrics/sec)
**Infrastructure**:
- Single Prometheus server (local storage, 15-day retention)
- Loki with 100GB local disk (7-day retention)
- Jaeger all-in-one (in-memory storage, 1-day retention)
- Grafana with pre-built dashboards (USE/RED method)

**Key Additions**:
- Basic alerting: CPU >90%, memory >90%, service down
- Log shipping via Fluentd daemonset
- OpenTelemetry auto-instrumentation for Java/Go services

**Limitations**:
- No long-term retention (all data lost after 15 days)
- Single point of failure (Prometheus crash = no monitoring)
- Manual dashboard creation (no service catalog)

---

### Stage 2: Production (100 Services, 100K Metrics/sec)
**Infrastructure**:
- VictoriaMetrics cluster (3 nodes, 30-day hot + 90-day warm on S3)
- Loki cluster (3 ingesters, 3 queriers, S3 backend)
- Tempo distributed tracing (S3-backed, 7-day retention)
- Grafana with LDAP auth + RBAC

**Key Additions**:
- **Thanos** (optional): Multi-cluster federation, global query layer
- **SLO Tracking**: Define SLOs (99.9% availability), error budget burn-rate alerts
- **Service Mesh**: Istio auto-generates RED metrics (no code instrumentation)
- **Cost Attribution**: Track storage/query costs per team (chargeback)

**Optimizations**:
- Tail-based trace sampling (30s buffer, 100% error retention)
- Downsample metrics after 7 days (1s → 1min)
- Cardinality enforcement (reject metrics with user_id labels)
- Alert grouping (10 pods crash → 1 alert)

---

### Stage 3: Scale (1K Services, 10M Metrics/sec)
**Infrastructure**:
- VictoriaMetrics cluster (50 nodes, sharded by metric hash)
- Elasticsearch + Loki hybrid (Elasticsearch for security logs, Loki for app logs)
- Tempo with 100TB S3 storage (14-day retention with 1% sampling)
- Grafana with SSO, org-based multi-tenancy

**Key Additions**:
- **Anomaly Detection**: ML-based anomaly detection (Prometheus + Grafana ML)
- **Adaptive Sampling**: Sample 0.1% of success traces, 100% of errors, 10% of slow requests (p99 >1s)
- **Capacity Planning**: Trend analysis dashboards (predict when to scale based on 90-day growth rate)
- **Service Catalog**: Auto-generate dashboards per service (template-based)

**Optimizations**:
- **Regional Scrapers**: Prometheus agents in each region push to global VictoriaMetrics (reduce cross-region traffic)
- **Query Caching**: Cache dashboard queries (1min TTL) to reduce TSDB load
- **Pre-Aggregation**: Store pre-computed rollups (e.g., per-service p99 latency) for faster queries
- **Compression Tuning**: Gorilla encoding for metrics, zstd level 9 for logs (maximize compression)

**Operational Maturity**:
- **Self-Service**: Teams create dashboards/alerts via Terraform (GitOps)
- **Chaos Engineering**: Simulate TSDB node failure, network partition, scrape timeout
- **Cost Optimization**: Auto-delete low-value metrics (e.g., unused metrics for 30 days)

---

## Failure Scenarios

| Failure | Detection | Impact | Mitigation | Recovery Time |
|---------|-----------|--------|------------|---------------|
| **Prometheus Scraper Down** | No metrics for 2 scrape intervals (30s) | Gaps in metrics for affected services | Multiple scrapers in HA mode (same targets, dedupe at TSDB) | <1min (failover to backup scraper) |
| **TSDB Node Crash** | Health check failure, cluster monitoring | Queries fail for sharded metrics | Replication (3× RF), query across replicas | <5min (automatic failover) |
| **S3 Outage** (long-term storage) | TSDB write errors to S3 | Can't query >30-day data | Multi-region S3 replication, local cache for recent queries | Hours (S3 recovery) |
| **Log Ingestion Overload** | Agent buffer full (10GB disk) | Logs dropped (data loss) | Back-pressure: Slow down log emission, alert on buffer usage >80% | 10min (scale Loki ingesters) |
| **Trace Collector Crash** | No spans received for 1min | Traces missing for affected services | Multiple collectors (load-balanced), retry on failure | <2min (container restart) |
| **Cardinality Explosion** | Active time series >100M, memory pressure | TSDB OOM crash, query failures | Hard limits (reject writes), auto-cleanup of stale series (24h TTL) | <30min (enforce limits, cleanup) |
| **Alert Fatigue** | >100 alerts/hour | On-call ignores critical alerts | Alert grouping, silence low-priority alerts, escalation policies | Days (tune alert rules) |
| **Dashboard Query Timeout** | Query exceeds 30s | Dashboard fails to load | Query optimization (reduce time range, add filters), pre-aggregated metrics | <5min (kill expensive queries) |

---

## SLO Commitments

### Ingestion Availability
- **Target**: 99.9% of metrics/logs/traces ingested successfully
- **Measurement**: `(total_samples - dropped_samples) / total_samples`
- **Error Budget**: 86K samples/day can be dropped (out of 86M samples/day)

### Query Latency
- **Target**: p95 dashboard queries <3s for 7-day range
- **Measurement**: `histogram_quantile(0.95, rate(tsdb_query_duration_seconds_bucket[5m]))`
- **Error Budget**: 5% of queries can exceed 3s

### Alert Latency (MTTD)
- **Target**: 95% of incidents detected within 5min
- **Measurement**: Time from incident start to alert fired
- **Error Budget**: 5% of incidents can take >5min to detect

### Data Retention
- **Target**: 100% of data retained for committed period (30 days hot, 90 days warm)
- **Measurement**: Audit S3 backups monthly, verify no data loss
- **Error Budget**: Zero tolerance for data loss (11 9's durability via S3)

---

## Common Pitfalls

### 1. **Cardinality Explosion from User IDs in Labels**
**Problem**: Adding `user_id` label creates 1M time series per metric (vs. 10 without).

**Solution**:
- **Blacklist High-Cardinality Labels**: Reject metrics with `user_id`, `request_id`, `session_id` at scrape time
- **Use Exemplars**: Store sparse examples (1 per 1000 samples) instead of full-resolution labels
- **Educate Teams**: Publish cardinality best practices (labels should have <100 unique values)

---

### 2. **Ignoring Downsampling → Storage Costs Explode**
**Problem**: Keeping 1s resolution for 90 days = 100TB storage (vs. 1TB with downsampling).

**Solution**:
- **Automatic Downsampling**: 7 days → 1min, 30 days → 1h (configured in VictoriaMetrics)
- **Retention Policies**: Delete raw data after downsampling (no duplication)
- **Cost Alerts**: Alert when storage growth >10% per week

---

### 3. **Alert Fatigue from Noisy Rules**
**Problem**: 100+ alerts/day → on-call ignores critical alerts → incidents escalate.

**Solution**:
- **Alert Grouping**: Batch related alerts (e.g., "10 pods down in deployment X" → 1 alert)
- **Silence Maintenance Windows**: Auto-silence alerts during known deployments
- **Escalation Policies**: Low-priority alerts to Slack, high-priority to PagerDuty

---

### 4. **No Query Timeout → Expensive Queries Kill TSDB**
**Problem**: User runs `rate(http_requests_total[365d])` → scans 13TB, crashes TSDB.

**Solution**:
- **Hard Timeout**: Kill queries after 30s (configurable per user)
- **Query Validation**: Require time range <7 days for ad-hoc queries, >7 days requires approval
- **Pre-Aggregated Metrics**: Store pre-computed rollups for long-term queries (e.g., daily p99 latency)

---

### 5. **Trace Sampling Misses Rare Errors**
**Problem**: 1% head-based sampling + 0.01% error rate = 1 in 10,000 errors captured.

**Solution**:
- **Tail-Based Sampling**: Buffer 30s, keep 100% of error traces
- **Adaptive Sampling**: Dynamically increase sampling rate for low-traffic services (e.g., 10% for <100 RPS services)
- **Always Sample Errors**: Override sampling for any span with `error=true` tag

---

### 6. **Log Indexing Costs Exceed Budget**
**Problem**: Elasticsearch indexes 1TB/day logs → $50K/mo (indexing = 50% of raw log size).

**Solution**:
- **Loki for App Logs**: Index only labels (service, level), not log content (10× cheaper)
- **Elasticsearch for Security Logs**: Use for critical logs that need full-text search (10% of volume)
- **Retention Tiers**: 7 days hot, 30 days warm (S3), 90 days cold (S3 Glacier)

---

### 7. **No Service Discovery → Manual Scrape Config**
**Problem**: Adding new service requires manual Prometheus config update (error-prone).

**Solution**:
- **Kubernetes Service Discovery**: Prometheus auto-discovers pods via Kubernetes API (labels: `prometheus.io/scrape: "true"`)
- **Consul Service Discovery**: Services register with Consul, Prometheus scrapes all registered services
- **Dynamic Config Reload**: Prometheus reloads config every 30s (no restart needed)

---

### 8. **Not Correlating Metrics/Logs/Traces**
**Problem**: User sees high latency in metrics, but can't find corresponding logs/traces.

**Solution**:
- **Trace ID in Logs**: Include `trace_id` in every log line (structured logging)
- **Exemplars**: Store sparse trace IDs in metric samples (1 per 1000 samples)
- **Grafana Correlation**: Click metric spike → auto-query logs with same time range + trace ID

---

## Interview Talking Points

When discussing observability in interviews, emphasize:

### 1. **Three Pillars: Metrics, Logs, Traces**
- "Metrics tell you **what** is broken (high error rate), logs tell you **why** (database timeout), traces tell you **where** (which service in the chain)."
- "Metrics are aggregated (avg/p99), logs are raw events, traces are correlated spans."

### 2. **Cardinality Trade-offs**
- "Adding user_id to metric labels creates 1M time series → TSDB crashes. Use exemplars (sparse samples) instead."
- "Labels should have <100 unique values; use tags for high-cardinality fields (indexed differently)."

### 3. **Sampling Strategies**
- "Head-based sampling (1%) is fast but misses rare errors. Tail-based sampling (30s buffer) keeps 100% of errors but adds latency."
- "Adaptive sampling: 0.1% for success, 100% for errors, 10% for slow requests (p99 >1s)."

### 4. **Pull vs. Push**
- "Pull (Prometheus) enables service discovery and health checks but can't scrape ephemeral jobs (Lambda). Push gateway solves this."
- "Push (StatsD) works for any workload but requires firewall outbound rules and loses implicit health monitoring."

### 5. **Query Optimization**
- "Downsample metrics after 7 days (1s → 1min) → 60× storage savings. Long-term queries use pre-aggregated rollups."
- "Query timeout (30s) prevents expensive queries from crashing TSDB. Require time range filters (<7 days for ad-hoc)."

### 6. **SLO-Based Alerting**
- "Alert on error budget burn rate, not absolute values. E.g., if 5% error budget consumed in 1h → critical alert."
- "Group related alerts (10 pods crash → 1 alert). Silence during maintenance windows."

---

## Follow-Up Questions to Explore

1. **Distributed Tracing at Scale**: How do you correlate spans from 10K microservices with out-of-order arrival?
2. **Real-Time Anomaly Detection**: Design ML pipeline for detecting metric anomalies (unsupervised learning on time series).
3. **Cost Optimization**: How do you identify and delete unused metrics (no queries in 30 days)?
4. **Multi-Tenancy**: Design RBAC for observability platform (1000 teams, isolated metrics/logs/traces per team).
5. **Compliance (GDPR)**: How do you anonymize logs (PII redaction) while retaining debugging utility?
6. **High-Cardinality Metrics**: When would you use OLAP (ClickHouse) instead of TSDB for per-user metrics?
7. **Service Mesh Integration**: Compare Istio (sidecar) vs. eBPF (kernel-level) for metrics collection.
8. **Log Aggregation at Edge**: Design log pipeline for IoT devices with limited bandwidth (local aggregation, compression).
9. **Alert Routing**: Design complex alert routing (severity + team + region + time-of-day).
10. **Capacity Planning**: Predict when to scale based on 90-day metric trends (linear regression, seasonality detection).

---

**Final Thought**: Observability is about **reducing MTTR** (mean time to resolve) via fast correlation of metrics/logs/traces. The key trade-offs are **cost** (cardinality/retention/sampling) vs. **fidelity** (granularity/completeness). Most teams over-collect initially (waste $$$) and under-query (miss insights)—the goal is to ruthlessly prioritize high-signal data and delete the rest.
