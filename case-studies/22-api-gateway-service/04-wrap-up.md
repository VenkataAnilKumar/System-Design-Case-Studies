# Wrap-Up & Deep Dives

## Scaling Playbook

### Stage 1: MVP (0 → 10K RPS)
**Infrastructure**:
- 3 gateway nodes (single region), 1 Redis instance
- Basic route config in JSON file (manual reload)
- JWT validation with hardcoded public key

**Key Additions**:
- Basic rate limiting (fixed window per user)
- Circuit breaker with manual reset
- Access logs to stdout (Elasticsearch aggregation)

**Limitations**:
- Manual config deploys (SSH + reload)
- No multi-region support
- Rate limiting only per user (not per API)

---

### Stage 2: Production (10K → 100K RPS)
**Infrastructure**:
- 9 gateway nodes (3 per region × 3 regions)
- Redis cluster with 3 master + 3 replica shards
- etcd cluster for config storage

**Key Additions**:
- Distributed config updates via etcd watch (30s propagation)
- Per-route rate limiting with Redis token buckets
- Automatic circuit breaker recovery (half-open state)
- Prometheus metrics + Grafana dashboards
- TLS termination at edge LB with mTLS to backends (optional)

**Optimizations**:
- HTTP/2 connection pooling to backends
- JWT public key caching (5min TTL)
- Async logging with 1000-log batches
- Health checks every 10s with 3-failure threshold

---

### Stage 3: Scale (100K → 1M+ RPS)
**Infrastructure**:
- 30+ gateway nodes with auto-scaling (CPU >80%)
- Redis cluster with 12 shards (geographic distribution)
- Multi-region etcd clusters with cross-region replication

**Key Additions**:
- GraphQL gateway with schema stitching (federated backends)
- Canary routing with weighted traffic splits (10% → 50% → 100%)
- Advanced rate limiting: sliding window counters, hierarchical quotas (tenant > user > API)
- DDoS mitigation: IP reputation scoring, geo-blocking, CAPTCHA integration
- Distributed tracing with 1% sampling (OpenTelemetry → Jaeger)

**Optimizations**:
- L7 load balancing with least-connection algorithm (vs. round-robin)
- Cached responses with Varnish/Nginx (CDN-like caching for GET requests)
- Request coalescing: Dedupe identical in-flight requests to backends
- WASM-based custom plugins for per-customer logic (vs. hardcoded Lua)

**Operational Maturity**:
- Chaos engineering: Kill gateway nodes, partition Redis, throttle backends
- SLO-based alerting: Burn-rate alerts (5% error budget consumed in 1h)
- Cost optimization: Spot instances for gateway nodes (stateless = interruptible)

---

## Failure Scenarios

| Failure | Detection | Impact | Mitigation | Recovery Time |
|---------|-----------|--------|------------|---------------|
| **Gateway Node Crash** | Health check failure (3 consecutive) | Traffic shifts to healthy nodes | Edge LB removes node from rotation | <30s (health check interval) |
| **Redis Cluster Down** | Connection timeout (1s) | Rate limiting degrades to local in-memory | Fallback to per-node token buckets (eventual consistency) | <10s (automatic failover to replica) |
| **Backend Service Overload** | p99 latency >5s for 10 requests | Circuit breaker opens, fail fast with 503 | Stop sending traffic, retry after 30s | 30s-2min (backend scales/recovers) |
| **etcd Partition** | Watch connection lost | Config updates stop propagating | Gateway uses last-known-good config | <5min (etcd leader election) |
| **Auth Service Down** | JWT validation cache miss timeout (2s) | New users can't authenticate (cached users OK) | Extend JWT cache TTL to 15min during incident | <5min (auth service failover) |
| **DDoS Attack** | Rate limit violations spike (>100/s) | Legitimate users hit rate limits | IP blacklisting, geo-blocking, global throttling | Minutes to hours (depends on attack sophistication) |
| **Config Rollout Bug** | Error rate spikes after deploy | All traffic affected if validation missed | Automatic rollback to previous config version | <2min (control plane detects + reverts) |
| **TLS Cert Expiry** | Edge LB health check fails (TLS handshake error) | All traffic blocked | Automated cert rotation with Let's Encrypt (7-day renewal) | <1min (control plane pushes new cert) |

---

## SLO Commitments

### Latency
- **Target**: p99 gateway overhead <5ms, p50 <2ms
- **Measurement**: `gateway_request_duration_seconds` histogram (excludes backend time)
- **Error Budget**: 0.1% of requests can exceed 5ms → ~86K/1M requests/day

### Availability
- **Target**: 99.99% uptime (4min downtime/month)
- **Measurement**: `(total_requests - 5xx_errors) / total_requests`
- **Error Budget**: 43 minutes/month

### Throughput
- **Target**: Handle 1M RPS globally without degradation
- **Measurement**: QPS per gateway node <100K (headroom for spikes)
- **Error Budget**: Auto-scale should trigger before 80% CPU utilization

### Configuration Propagation
- **Target**: 95% of config updates propagate within 30s
- **Measurement**: `gateway_config_version` metric lag across nodes
- **Error Budget**: 5% of updates can take up to 60s

---

## Common Pitfalls

### 1. **Underestimating Gateway Latency Overhead**
**Problem**: Adding auth, rate limiting, logging adds 10ms+ per request (unacceptable for low-latency APIs).

**Solution**:
- Profile hot path: Route lookup, JWT validation, rate limit check should each be <1ms
- Use in-memory caches aggressively (JWT keys, rate limit counters)
- Benchmark: `wrk -t12 -c400 -d30s --latency http://gateway/health` (expect <2ms p99)

---

### 2. **Rate Limiting Without Backpressure**
**Problem**: Gateway enforces rate limits, but backends still overload (gateway itself generates too much traffic).

**Solution**:
- Implement global rate limits (cluster-wide, not just per-user)
- Circuit breakers should trigger before backend CPU >80%
- Use token bucket with burst limits sized to backend capacity

---

### 3. **Circuit Breaker Flapping**
**Problem**: Circuit breaker oscillates between open/closed (half-open probes succeed, then fail again).

**Solution**:
- Increase half-open probe count (test 10 requests, not 1)
- Add hysteresis: Require 5 consecutive successes to close circuit (not just 1)
- Set higher error threshold (75% instead of 50%) if backend has transient errors

---

### 4. **Config Propagation Race Conditions**
**Problem**: Admin deploys new route, but some gateway nodes still use old config (requests fail with 404).

**Solution**:
- Use config version numbers in etcd (gateway nodes log version on reload)
- Monitor `gateway_config_version` metric across nodes (alert if drift >1 version)
- Implement config validation in control plane (reject invalid configs before deploy)

---

### 5. **JWT Cache Stampede**
**Problem**: Auth service crashes briefly → all gateway nodes simultaneously fetch JWT keys → auth service overloaded.

**Solution**:
- Stagger JWT key refresh (jitter: random 0-60s delay per node)
- Extend cache TTL during degradation (5min → 15min if auth service is slow)
- Implement exponential backoff for key fetch retries

---

### 6. **Ignoring Backend Connection Pooling**
**Problem**: Gateway opens 100 new TCP connections per request → backend runs out of file descriptors.

**Solution**:
- HTTP/2 connection pooling (1 connection per backend, multiplexed)
- Set `MaxIdleConnsPerHost` to 100+ (Go http.Transport config)
- Monitor `gateway_backend_connections{state}` gauge (alert if >1000 per backend)

---

### 7. **No Timeout Enforcement**
**Problem**: Backend hangs → gateway waits indefinitely → all gateway connections exhausted.

**Solution**:
- Set aggressive timeouts per route (default 5s, critical APIs 1s)
- Use context deadlines in Go: `ctx, cancel := context.WithTimeout(ctx, 5*time.Second)`
- Circuit breaker should count timeouts as errors (trigger open state)

---

### 8. **Logging PII in Access Logs**
**Problem**: Access logs contain full JWT tokens, user emails → GDPR violation.

**Solution**:
- Redact sensitive headers: `Authorization: Bearer ***`, `Cookie: ***`
- Hash user IDs in logs: `user_id: sha256(user_id)` (still correlatable, but not PII)
- Implement log retention policies (delete after 30 days)

---

## Interview Talking Points

When discussing API Gateway design in interviews, emphasize:

### 1. **Latency-Driven Tradeoffs**
- "We cache JWT public keys locally to avoid 20ms auth service calls on every request—trade-off is 5min revocation delay."
- "In-memory route lookup with O(1) trie gives <100μs vs. 10ms database lookup."

### 2. **Distributed Systems Challenges**
- "Circuit breaker state is per-node (no coordination) → eventual consistency across gateway cluster."
- "etcd watch mechanism propagates config updates within 1-5s → eventual consistency is acceptable for routes, not for emergency rate limits."

### 3. **Rate Limiting Deep Dive**
- "Token bucket allows bursts (better UX) vs. leaky bucket strict pacing (better backend protection)."
- "Redis sorted sets for sliding window counters are more accurate but 3× slower than fixed window."

### 4. **Failure Handling**
- "Circuit breaker half-open state sends probe requests to test backend recovery—need 5 consecutive successes to avoid flapping."
- "If Redis is down, we fall back to local in-memory rate limiting with eventual consistency."

### 5. **Observability**
- "We emit per-route latency histograms (not just averages) to catch p99 issues."
- "Distributed tracing with 1% sampling (100% sampling would overwhelm Jaeger at 1M RPS)."

### 6. **Security**
- "TLS termination at edge LB with optional mTLS to backends for sensitive services."
- "JWT validation caches public keys but checks signature + expiry on every request."

---

## Follow-Up Questions to Explore

1. **GraphQL Gateway**: How would you add schema stitching to federate multiple GraphQL backends?
2. **Multi-Tenancy**: How do you enforce per-tenant rate limits and circuit breakers without cross-tenant interference?
3. **Request Coalescing**: How would you deduplicate identical in-flight requests to backends (cache stampede protection)?
4. **Global Rate Limiting**: How would you implement cluster-wide rate limits (not just per-node) with Redis?
5. **Canary Routing**: Design weighted traffic splitting (10% new version, 90% old) with automatic rollback on error rate spike.
6. **WebSocket Support**: How does the gateway handle WebSocket upgrades and long-lived connections?
7. **gRPC Transcoding**: Design REST→gRPC translation layer (map HTTP path/body to Protobuf fields).
8. **Cost Optimization**: When would you use serverless gateway (AWS API Gateway, GCP Cloud Endpoints) vs. self-managed?
9. **Zero Trust Architecture**: How do you add mTLS per-request authentication when gateway is inside VPC?
10. **Compliance**: Design PCI-DSS compliant gateway for payment APIs (no card data logging, TLS 1.3 only, audit trails).

---

**Final Thought**: API Gateway is the "front door" to your microservices—optimize for latency (caching, in-memory state), resilience (circuit breakers, retries), and observability (metrics, traces). The key trade-off is **centralized simplicity** (one gateway for all services) vs. **decentralized control** (sidecar per service). Most teams start centralized and migrate to service mesh (sidecar) as they scale to hundreds of services.
