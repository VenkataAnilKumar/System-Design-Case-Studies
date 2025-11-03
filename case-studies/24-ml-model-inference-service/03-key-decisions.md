# Key Technical Decisions

## 1. Dynamic Batching vs. Fixed-Size Batching

**Decision**: **Dynamic batching** with 10ms timeout and max batch size 32.

**Rationale**:
- **Variable Traffic**: Traffic varies 10× between peak/off-peak → fixed batching wastes GPU cycles during low traffic
- **Latency Control**: 10ms timeout ensures p99 <100ms (10ms wait + 50ms inference + 30ms overhead)
- **Throughput**: Batch size 32 achieves 80% GPU utilization (sweet spot for NVIDIA T4)

**Trade-offs**:
- **Complexity**: Dynamic batching requires queue management (vs. simple fixed-size batches)
- **Latency Variability**: First request in batch waits 10ms, last request waits 0ms (p99 >p50)
- **Underutilization**: Low traffic (<3 req/10ms) means small batches (batch=1 → 5% GPU utilization)

**When to Reconsider**:
- If traffic is perfectly predictable (e.g., batch jobs), use fixed batching with optimal batch size
- For ultra-low latency (<20ms p99), disable batching and accept lower GPU utilization

---

## 2. Multi-Model Serving vs. Single-Model-Per-Server

**Decision**: **Single-model-per-server** for real-time, **multi-model** for batch/low-QPS models.

**Rationale**:
- **Resource Isolation**: Critical models (fraud detection) get dedicated GPUs (no interference from other models)
- **Cost Optimization**: 900 low-QPS models share 10 GPUs (90 models/GPU) via multi-model serving
- **Operational Simplicity**: Single model = predictable memory/latency, easier to debug

**Multi-Model Serving** (for low-QPS models):
- **Benefits**: Amortize GPU cost across 10-100 models, reduce infrastructure by 10×
- **Challenges**: Models compete for GPU memory (OOM risk), one slow model blocks others

**When to Reconsider**:
- If GPU costs >$100K/mo, aggressively co-locate models (accept complexity for cost savings)
- For heterogeneous models (TensorFlow + PyTorch), use NVIDIA Triton (supports mixed frameworks on one server)

---

## 3. Model Caching: Predictions vs. Models

**Decision**: **Cache predictions** (Redis) for duplicate inputs, NOT model artifacts.

**Rationale**:
- **Prediction Caching**: 30% cache hit rate for ad ranking (same ad+user seen multiple times) → 30% cost savings
- **Model Caching**: Models are loaded once at server startup (preloaded in GPU memory), no need to re-cache
- **Cold Start Avoidance**: Keep models in memory 24/7 (dedicated servers), avoid S3 load latency (30s for 5GB model)

**Trade-offs**:
- **Stale Predictions**: Cached prediction may be outdated if model retrained (mitigated with 1h TTL)
- **Cache Overhead**: Redis lookup adds 1ms latency (negligible vs. 50ms inference)

**When to Reconsider**:
- For low-QPS models (<10 RPS), unload model from memory after 1h idle → cache model in S3, reload on demand
- If cache hit rate <5%, disable caching to avoid Redis cost/complexity

---

## 4. A/B Testing: User-Level vs. Request-Level Hashing

**Decision**: **User-level hashing** for consistent experience.

**Rationale**:
- **User Consistency**: Same user always sees same model version (no confusing experience)
- **Statistical Validity**: User-level randomization ensures unbiased comparison (vs. request-level may favor one variant if user makes multiple requests)
- **Reproducibility**: User 123 always in variant B → can debug by replaying user's requests

**Request-Level** (alternative):
- **Faster Convergence**: Each request is independent → reach statistical significance faster
- **Use Case**: Non-user-facing APIs (internal batch jobs) where consistency doesn't matter

**When to Reconsider**:
- For non-logged-in users (anonymous traffic), use request-level hashing (no user_id available)
- If A/B test must conclude in 1 day (urgency), use request-level for faster data collection

---

## 5. Feature Store: Precompute vs. Real-Time Computation

**Decision**: **Precompute batch features** (daily), **real-time features** for critical signals.

**Rationale**:
- **Batch Features** (precomputed): User's 30-day transaction average, purchase history → computed once daily, cached in Redis
  - Benefit: Low latency (<5ms Redis lookup vs. 500ms SQL aggregation)
  - Trade-off: Features are 0-24h stale
- **Real-Time Features**: Last 5 clicks, current cart items → computed on-the-fly from Kafka stream
  - Benefit: Always fresh
  - Trade-off: Higher latency (20ms Flink query)

**Hybrid Approach**: 80% features precomputed, 20% real-time

**When to Reconsider**:
- If all features must be real-time (e.g., fraud detection needs instant signal), compute everything on-the-fly (accept 100ms latency)
- For batch inference (offline recommendations), use 100% precomputed features (no real-time needed)

---

## 6. Model Format: Native vs. ONNX vs. TensorRT

**Decision**: **ONNX** for portability, **TensorRT** for GPU optimization.

**Rationale**:
- **ONNX**: Framework-agnostic (TensorFlow → ONNX → PyTorch) enables vendor flexibility
  - Trade-off: 10-20% slower than native format
- **TensorRT**: NVIDIA's optimized runtime (2-5× faster than native TensorFlow)
  - Trade-off: Vendor lock-in (NVIDIA GPUs only), conversion complexity

**Strategy**: Use ONNX for development/staging, TensorRT for production GPU inference

**When to Reconsider**:
- For CPU-only inference, use native formats (TensorFlow SavedModel, PyTorch TorchScript) for simplicity
- If training framework changes frequently, stick with ONNX (avoid repeated TensorRT conversions)

---

## 7. Auto-Scaling: Request-Based vs. GPU-Utilization-Based

**Decision**: **GPU utilization-based** with 80% target.

**Rationale**:
- **Resource Efficiency**: Scale when GPU >80% busy (vs. request count which may not correlate with GPU load)
- **Cost Control**: Avoid over-provisioning (request count can spike but GPU still idle if requests are cached)
- **Predictive Scaling**: Use 5-min moving average to smooth spikes (avoid flapping)

**Request-Based** (alternative):
- **Simpler**: Scale based on QPS threshold (e.g., >10K RPS → add node)
- **Problem**: Doesn't account for cache hits (10K RPS with 90% cache hit = 1K actual inferences)

**When to Reconsider**:
- For CPU-based models (no GPU), use request-based scaling (CPU utilization is noisier metric)
- If GPU utilization data is unavailable (cloud provider limitation), fall back to request-based

---

## 8. Canary Deployment: Traffic-Based vs. Shadow Mode

**Decision**: **Traffic-based canary** (5% live traffic) with shadow mode for validation.

**Rationale**:
- **Traffic-Based Canary**: Route 5% real traffic to v2, compare metrics with v1
  - Benefit: Real-world testing with actual users
  - Risk: 5% users see potential bugs
- **Shadow Mode**: Send 100% traffic to both v1 and v2, but only return v1 results
  - Benefit: Test v2 with zero user impact
  - Limitation: Can't measure business metrics (revenue, conversions) since v2 results are discarded

**Strategy**: Shadow mode for 1 day (validate latency, errors) → traffic-based canary for 7 days (validate business metrics)

**When to Reconsider**:
- For critical models (fraud detection), use extended shadow mode (7 days) before any real traffic
- If shadow mode shows identical results, skip canary and go straight to full rollout (blue-green deployment)

---

**Summary Table**:

| Decision | Chosen Approach | Main Benefit | Main Cost | Reconsider If... |
|----------|----------------|--------------|-----------|------------------|
| Batching | Dynamic (10ms timeout) | Adapts to traffic | Latency variability | Ultra-low latency <20ms |
| Model Serving | Single-model per server (real-time) | Resource isolation | Higher cost | GPU costs >$100K/mo |
| Caching | Predictions (Redis) | 30% cost savings | 1ms latency overhead | Cache hit <5% |
| A/B Testing | User-level hashing | Consistent UX | Slower convergence | Anonymous traffic |
| Features | Precompute batch, real-time critical | Low latency | 0-24h staleness | All features must be fresh |
| Model Format | ONNX (dev), TensorRT (prod) | Portability + speed | Conversion complexity | CPU-only inference |
| Auto-Scaling | GPU utilization (80%) | Cost efficiency | Metric lag (1min) | CPU-based models |
| Canary | Traffic-based (5%) + shadow | Real-world testing | 5% user risk | Critical models |
