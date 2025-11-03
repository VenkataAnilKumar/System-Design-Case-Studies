# Key Technical Decisions

## 1. Pull-Based (Prometheus) vs. Push-Based (StatsD) Metrics Collection

**Decision**: **Pull-based Prometheus scraping** as default with push gateway for batch jobs.

**Rationale**:
- **Service Discovery**: Prometheus auto-discovers services via Kubernetes/Consul (no manual agent config)
- **Health Checks**: Scrape failures indicate service issues (implicit monitoring)
- **Target Control**: Centralized scrape config prevents metrics spam (vs. any service can push anything)

**Trade-offs**:
- **Ephemeral Workloads**: Short-lived jobs (AWS Lambda) can't be scraped → push gateway needed
- **Network Overhead**: Scraping 1000 services × 15s = 66 requests/sec (vs. push batching)
- **Firewall Issues**: Pull requires inbound connectivity to services (vs. push only needs outbound)

**When to Reconsider**:
- If >50% of workloads are ephemeral (Lambda, batch jobs), switch to push-based (Telegraf/Vector)
- For multi-region deployments, push to regional collectors to avoid cross-region scraping

---

## 2. Elasticsearch vs. Loki for Log Storage

**Decision**: **Loki** for cost efficiency, **Elasticsearch** for rich search use cases.

**Rationale**:
- **Loki**: 10× cheaper storage (no content indexing), optimized for label-based queries
  - Use case: Tailing logs by service/pod, aggregating error counts
- **Elasticsearch**: Full-text search with regex, fuzzy matching
  - Use case: Security logs (search for "failed login attempt from IP 1.2.3.4")

**Trade-offs**:
- **Loki**: Can't search arbitrary text unless it's a label (e.g., can't search "timeout" in message)
- **Elasticsearch**: Index size = 50% of raw logs (vs. Loki 5%), slow writes at high cardinality

**Architecture**: Hybrid approach
- **Loki** for application logs (service, level, pod labels)
- **Elasticsearch** for security/audit logs (need full-text search)

**When to Reconsider**:
- If users demand arbitrary full-text search on all logs, accept 10× cost and use Elasticsearch everywhere
- If log volume <100GB/day, cost difference is negligible—simplify with Elasticsearch only

---

## 3. Head-Based vs. Tail-Based Trace Sampling

**Decision**: **Tail-based sampling** with 30s buffering for error retention.

**Rationale**:
- **Head-Based**: Sample 1% at span creation (fast, low overhead)
  - Problem: Misses rare errors (0.01% error rate × 1% sampling = 0.0001% of errors captured)
- **Tail-Based**: Buffer spans 30s, decide after seeing full trace
  - Benefit: Keep 100% of error traces, sample 1% of success traces

**Trade-offs**:
- **Latency**: 30s delay before traces visible in UI (vs. <5s with head-based)
- **Memory**: Buffer 30s × 100K traces/s = 3M traces in memory (~6GB)
- **Complexity**: Collector must correlate spans from distributed services (require trace_id)

**When to Reconsider**:
- For real-time debugging (need traces <5s after request), use head-based sampling with higher rate (10%)
- If memory cost is prohibitive, use adaptive sampling (sample errors at 100%, reduce success rate dynamically)

---

## 4. Single Cluster vs. Federated Multi-Cluster TSDB

**Decision**: **Single global TSDB cluster** (VictoriaMetrics) with regional Prometheus scrapers.

**Rationale**:
- **Simplicity**: One query endpoint for all metrics (no federation complexity)
- **Cost**: Centralized storage allows global deduplication (same metric from 3 regions → store once)
- **Query Speed**: Single cluster avoids cross-region queries (no federation latency)

**Trade-offs**:
- **Cross-Region Ingestion**: Regional scrapers push to global cluster (higher network cost)
- **Single Point of Failure**: Cluster outage loses all metrics (mitigated with multi-AZ + S3 backup)
- **Data Residency**: GDPR/CCPA may require metrics to stay in-region (not globally centralized)

**When to Reconsider**:
- If data residency laws require regional isolation, use Thanos with per-region clusters + global query layer
- For >10 regions, federation prevents excessive cross-region traffic (push to regional, query globally)

---

## 5. Real-Time vs. Batched Alert Evaluation

**Decision**: **1-minute evaluation interval** with batched notifications.

**Rationale**:
- **Balance**: 1min is fast enough for most incidents (5min threshold = alert fires at 6min)
- **Cost**: 1min interval reduces TSDB query load vs. 10s evaluation (6× fewer queries)
- **Noise Reduction**: Batch alerts (10 pods crash → 1 alert "deployment X failing")

**Trade-offs**:
- **Detection Delay**: 1min eval + 5min threshold = 6min MTTD (vs. 10s eval = 5.17min)
- **Flapping**: 1min interval may miss transient spikes (e.g., 30s error spike that self-heals)

**When to Reconsider**:
- For critical SLOs (payments, authentication), use 10s evaluation with 30s threshold (alert at 40s)
- If TSDB can handle load, reduce to 30s evaluation for faster detection

---

## 6. Downsample Metrics vs. Keep Full Resolution

**Decision**: **Automatic downsampling** after 7 days (1s → 1min), after 30 days (1min → 1h).

**Rationale**:
- **Storage Savings**: 1h resolution = 3600× fewer samples vs. 1s (TB → GB)
- **Query Speed**: Aggregating 1h chunks vs. 3600s samples = 100× faster
- **Use Case**: Long-term trends (capacity planning) don't need 1s resolution

**Trade-offs**:
- **Lost Granularity**: Can't debug 2-week-old spike at 1s resolution (only 1min resolution available)
- **Irreversible**: Downsampling deletes original samples (can't reconstruct 1s data later)

**Retention Policy**:
- **0-7 days**: Full resolution (1s for 1s metrics, 15s for Prometheus default)
- **7-30 days**: 1min resolution (delete 1s samples)
- **30-90 days**: 1h resolution (delete 1min samples)
- **90+ days**: Archive to S3 (cold storage, slow queries)

**When to Reconsider**:
- If debugging often requires historical 1s resolution, extend full-resolution retention to 14 days
- For compliance (audit logs), keep full resolution for 1 year (accept 10× storage cost)

---

## 7. Local Aggregation (Agent-Side) vs. Centralized Aggregation

**Decision**: **Centralized aggregation** in TSDB for flexibility.

**Rationale**:
- **Query Flexibility**: Users can aggregate metrics any way (by service, by pod, by region) without re-configuring agents
- **Raw Data**: Store raw samples, compute aggregates at query time (e.g., p99 latency requires histogram buckets)
- **No Agent Complexity**: Agents just forward metrics, no local computation

**Trade-offs**:
- **Network Cost**: Sending raw metrics (10M/s) vs. pre-aggregated (1M/s) = 10× bandwidth
- **Query Load**: Aggregating at query time adds latency (vs. pre-computed aggregates)

**Agent-Side Aggregation** (alternative):
- Use case: Mobile/IoT devices with limited bandwidth
- Agents compute p50/p99/p999 locally, send only summary stats
- Cost: Lose ability to aggregate across different dimensions (can't recalculate after ingestion)

**When to Reconsider**:
- If network costs >$100K/mo, enable agent-side aggregation for high-volume metrics (e.g., per-request latency → per-minute summary)
- For edge deployments (IoT), local aggregation is mandatory (bandwidth constraint)

---

## 8. Cardinality Limits: Enforce vs. Educate

**Decision**: **Enforce hard limits** (100M active time series) with automated alerts.

**Rationale**:
- **TSDB Protection**: Unbounded cardinality (e.g., user_id in labels) crashes TSDB (OOM)
- **Cost Control**: 100M series × 10 bytes/sample = 1GB/sample → 86TB/day (unacceptable)
- **Immediate Feedback**: Reject metrics with high-cardinality labels at ingestion time

**Enforcement**:
- **Scrape-Time Validation**: Prometheus agents drop metrics with labels matching `user_id`, `request_id` (blacklist)
- **Global Limit**: TSDB rejects writes if active series >100M (return HTTP 429)
- **Per-Tenant Quotas**: Each team gets 10M series quota (prevent one team from consuming all capacity)

**Trade-offs**:
- **Legitimate Use Cases**: Sometimes high cardinality is needed (e.g., per-customer billing metrics)
- **Operational Overhead**: Teams get paged when hitting limits (requires education on cardinality best practices)

**When to Reconsider**:
- If teams need high-cardinality metrics (e.g., per-user latency), use separate TSDB for high-cardinality data (accept 10× cost)
- For billing/analytics use cases, send high-cardinality data to OLAP (ClickHouse) instead of TSDB

---

**Summary Table**:

| Decision | Chosen Approach | Main Benefit | Main Cost | Reconsider If... |
|----------|----------------|--------------|-----------|------------------|
| Metrics Collection | Pull (Prometheus) | Auto-discovery | Can't scrape ephemeral jobs | >50% workloads are ephemeral |
| Log Storage | Loki (labels only) | 10× cheaper | No full-text search | Need arbitrary text search |
| Trace Sampling | Tail-based (30s buffer) | 100% error retention | 30s latency + memory | Need real-time traces <5s |
| TSDB Topology | Single global cluster | Simplicity | Cross-region network cost | Data residency laws |
| Alert Evaluation | 1min interval | Cost/noise balance | 6min MTTD | Critical APIs need <1min |
| Downsampling | Auto (7d→1min, 30d→1h) | Storage savings | Lost granularity | Debug needs historical 1s data |
| Aggregation | Centralized (query-time) | Flexibility | Network/query cost | Bandwidth >$100K/mo |
| Cardinality | Hard limits (100M series) | TSDB protection | Rejects legitimate high-cardinality | Separate high-cardinality TSDB |
