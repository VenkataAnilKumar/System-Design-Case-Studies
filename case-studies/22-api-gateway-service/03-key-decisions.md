# Key Technical Decisions

## 1. Stateless Gateway Nodes vs. Sticky Sessions

**Decision**: **Stateless gateway nodes** with all auth/rate-limit state in external stores (Redis, auth service).

**Rationale**:
- **Horizontal Scalability**: Add/remove nodes without state migration or connection draining complexity
- **Zero Downtime Deploys**: Rolling updates don't lose in-flight state (auth tokens cached in Redis, not locally)
- **Load Balancer Simplicity**: No session affinity needed, pure round-robin works

**Trade-offs**:
- **Latency**: Every request hits Redis for rate limit check (~1ms overhead vs. local memory)
- **Redis Dependency**: Rate limiting degrades if Redis is unavailable (fallback to local in-memory counters)
- **Cache Stampede**: JWT public key cache misses trigger auth service calls (mitigated with 5-min TTL)

**When to Reconsider**:
- If Redis latency >5ms p99, consider local rate limit caches with eventual consistency
- For extreme low-latency requirements (<1ms overhead), explore in-process state with gossip protocols

---

## 2. Token Bucket vs. Leaky Bucket Rate Limiting

**Decision**: **Token Bucket** as default with configurable Leaky Bucket per route.

**Rationale**:
- **Burst Tolerance**: Token bucket allows short bursts (e.g., 100 req/s sustained, burst to 200 for 1s)
- **User Experience**: Bursty clients (mobile apps reconnecting) don't hit rate limits unnecessarily
- **Simple Implementation**: Redis INCR + EXPIRE commands handle token refill atomically

**Leaky Bucket** (alternative for strict pacing):
- Used for abuse-prone APIs (e.g., SMS sending) where burst is undesirable
- Guarantees fixed rate (no bursts), better for backend protection

**Trade-offs**:
- **Token Bucket**: Bursts can overwhelm backends if too many users burst simultaneously
- **Leaky Bucket**: Rejects legitimate burst traffic during reconnection storms

**When to Reconsider**:
- If backend services can't handle bursts, switch to Leaky Bucket for those routes
- For DDoS-prone endpoints, use sliding window counters (more accurate but higher Redis load)

---

## 3. Local Circuit Breaker State vs. Distributed Coordination

**Decision**: **Local per-node circuit breaker** state with no cross-node coordination.

**Rationale**:
- **Zero Latency Overhead**: No remote calls to check circuit state (decision in <1μs)
- **Independent Failure Detection**: Each gateway independently detects backend issues (no coordination delay)
- **Simpler Implementation**: Avoids distributed consensus complexity

**Trade-offs**:
- **Inconsistent State**: Node A might have circuit open while Node B is closed (delayed convergence)
- **Redundant Health Checks**: All nodes probe backend during half-open state (extra load)
- **Slower Global Response**: Takes N×(detection_window) for all nodes to open circuit (N=node count)

**When to Reconsider**:
- If backend protection requires instant cluster-wide circuit opening, add Redis-based shared state
- For canary deployments, centralized circuit breaker prevents mixed states across gateway versions

---

## 4. In-Memory Route Config vs. Database Lookup

**Decision**: **In-memory route trie** with etcd-based updates (no per-request DB lookup).

**Rationale**:
- **Sub-Millisecond Latency**: O(1) route lookup from prefix trie in <100μs
- **High Throughput**: 100K RPS/node without external dependencies on hot path
- **Eventual Consistency**: Config updates propagate via etcd watch (1-5s delay acceptable)

**Trade-offs**:
- **Memory Footprint**: 5K routes × 10KB = 50MB per node (negligible on modern servers)
- **Propagation Delay**: New routes take 1-5s to reach all nodes (not instant)
- **Cold Start**: New gateway nodes must load full config from etcd on startup (~1s delay)

**When to Reconsider**:
- If route count exceeds 100K (50MB+ memory), consider tiered caching or database lookup for rarely-used routes
- For real-time routing changes (e.g., emergency rate limit adjustments), add Redis-based override layer

---

## 5. JWT Validation: Remote vs. Cached Public Keys

**Decision**: **Cache JWT public keys locally** with 5-min TTL, fallback to auth service on miss.

**Rationale**:
- **Latency**: Avoid auth service call on every request (20ms → 500μs validation time)
- **Availability**: Gateway can validate tokens even if auth service is degraded
- **Key Rotation**: 5-min TTL ensures rotated keys propagate within acceptable window

**Trade-offs**:
- **Revocation Delay**: Revoked tokens remain valid until cache expires (5min max)
- **Cache Stampede**: Key rotation triggers all nodes to call auth service simultaneously (mitigated with staggered refresh)
- **Memory**: Each key ~2KB, 10 keys = 20KB per node (negligible)

**When to Reconsider**:
- For high-security APIs (banking, healthcare), use OAuth introspection endpoint on every request (accept 20ms latency)
- If immediate revocation is required, add Redis-based token blacklist check

---

## 6. HTTP/2 vs. HTTP/1.1 for Backend Connections

**Decision**: **HTTP/2 with multiplexing** to backends by default.

**Rationale**:
- **Connection Efficiency**: Single TCP connection per backend (vs. 100s with HTTP/1.1 keep-alive)
- **Lower Latency**: No head-of-line blocking with request multiplexing
- **Cost Savings**: Fewer open sockets reduces TCP state overhead (memory, file descriptors)

**Trade-offs**:
- **Backend Compatibility**: Not all legacy backends support HTTP/2 (fallback to HTTP/1.1)
- **Debugging Complexity**: Single connection makes request tracing harder (need stream IDs)
- **Failure Impact**: Connection failure drops all in-flight requests (vs. isolated failures in HTTP/1.1)

**When to Reconsider**:
- If backend uses HTTP/1.1-only features (chunked encoding edge cases), disable HTTP/2 per route
- For low-QPS backends (<10 RPS), HTTP/1.1 keep-alive is simpler and sufficient

---

## 7. Centralized vs. Embedded Gateway (Sidecar Pattern)

**Decision**: **Centralized gateway cluster** at edge (not sidecar per service).

**Rationale**:
- **Cost Efficiency**: 9 gateway nodes vs. 500 sidecars (one per backend service)
- **Simplified Operations**: Single control plane for all routing/auth/rate-limiting policies
- **East-West Traffic**: Backend services communicate directly (no sidecar overhead for internal calls)

**Sidecar Pattern** (alternative for service mesh):
- Each backend has co-located Envoy proxy (Istio/Linkerd pattern)
- Benefits: mTLS per service, fine-grained observability, circuit breaking at service level
- Cost: 500 sidecars × 0.5 vCPU = 250 vCPU overhead

**Trade-offs**:
- **Centralized**: Single point of failure (mitigated with multi-AZ), no per-service circuit breaking
- **Sidecar**: Higher cost/complexity, but better security isolation and observability

**When to Reconsider**:
- If adopting service mesh for mTLS everywhere, migrate to sidecar pattern (Envoy as both gateway + sidecar)
- For microservices with heterogeneous rate limits per service, sidecar pattern simplifies policy management

---

## 8. Synchronous vs. Asynchronous Request Logging

**Decision**: **Asynchronous logging** with buffered writes to avoid blocking request path.

**Rationale**:
- **Latency**: Logging to disk/network is slow (10ms+); async ensures <100μs impact on request
- **Throughput**: Batch log writes (1000 logs/batch) reduces I/O overhead
- **Resilience**: If log sink is down, buffer logs in memory (100K logs = ~50MB) and retry

**Trade-offs**:
- **Log Loss**: Gateway crash loses buffered logs not yet flushed (trade-off for performance)
- **Debugging**: Async logs may arrive out-of-order in centralized logging (use request_id for correlation)
- **Memory**: Buffer size must be tuned (too small = frequent flushes, too large = memory pressure)

**When to Reconsider**:
- For compliance-critical APIs (payments, healthcare), use synchronous logging with WAL (write-ahead log)
- If log loss is unacceptable, add local disk buffer with fsync before returning response (accept latency hit)

---

**Summary Table**:

| Decision | Chosen Approach | Main Benefit | Main Cost | Reconsider If... |
|----------|----------------|--------------|-----------|------------------|
| Gateway State | Stateless | Horizontal scale | Redis dependency | Redis latency >5ms |
| Rate Limiting | Token Bucket | Burst tolerance | Can overwhelm backend | Backends can't handle bursts |
| Circuit Breaker | Local per-node | Zero latency | Inconsistent state | Need instant cluster-wide action |
| Route Lookup | In-memory trie | <100μs latency | 1-5s propagation delay | >100K routes |
| JWT Validation | Cached keys (5min) | 500μs vs 20ms | 5min revocation delay | High-security API |
| Backend Protocol | HTTP/2 multiplex | Connection efficiency | Backend compatibility | Backend is HTTP/1.1-only |
| Gateway Topology | Centralized edge | Cost/simplicity | No per-service policies | Adopting service mesh |
| Request Logging | Async buffered | <100μs overhead | Potential log loss | Compliance requires durability |
