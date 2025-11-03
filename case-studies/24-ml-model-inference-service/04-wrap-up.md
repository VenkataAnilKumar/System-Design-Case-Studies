# Wrap-Up & Deep Dives

## Scaling Playbook

### Stage 1: MVP (10 Models, 1K Predictions/sec)
**Infrastructure**:
- 3 CPU servers (t3.xlarge) for simple models (logistic regression, XGBoost)
- TensorFlow Serving for 2 deep learning models
- S3 for model storage (manual upload)
- Redis for prediction caching (single-node)

**Key Additions**:
- REST API with input validation
- Basic monitoring (latency, throughput, errors)
- Manual model deployment (SCP model to server, restart service)

**Limitations**:
- No A/B testing (deploy overwrites old model)
- No feature store (features passed in request)
- No GPU optimization (CPU inference only)

---

### Stage 2: Production (100 Models, 10K Predictions/sec)
**Infrastructure**:
- 20 GPU servers (g4dn.xlarge with NVIDIA T4)
- NVIDIA Triton for multi-framework support (TensorFlow, PyTorch, ONNX)
- MLflow Model Registry for versioning
- Feature Store (Feast): Redis for online, S3 for offline
- Kubernetes for orchestration (auto-scaling, health checks)

**Key Additions**:
- **A/B Testing**: Route 80/20 split between v1/v2, track metrics in Datadog
- **Dynamic Batching**: 10ms timeout, batch size up to 32 for GPU efficiency
- **CI/CD Pipeline**: GitLab → model validation → Docker image → Kubernetes deploy
- **Model Monitoring**: Drift detection (feature distribution shifts), accuracy tracking

**Optimizations**:
- Preload models on server startup (avoid cold start)
- Cache predictions for duplicate inputs (30% hit rate)
- Multi-model serving for low-QPS models (10 models per GPU)

---

### Stage 3: Scale (1000 Models, 100K Predictions/sec)
**Infrastructure**:
- 100 GPU servers for real-time (T4/A10)
- 500 spot GPU instances for batch inference (V100/A100)
- Model Registry with approval workflows (Airflow DAGs)
- Advanced Feature Store (Tecton): Streaming + batch features, point-in-time correctness
- Service Mesh (Istio) for traffic splitting and observability

**Key Additions**:
- **Canary Deployments**: Automatic rollback if error rate >2× baseline
- **Explainability**: SHAP values for fraud detection (optional, adds 50ms latency)
- **Model Ensembles**: Combine 3 models (voting, stacking) for higher accuracy
- **Cost Optimization**: Spot instances for batch, auto-scale down GPU servers during off-peak

**Optimizations**:
- **TensorRT Conversion**: 2-5× faster inference vs. native TensorFlow
- **Model Compression**: Quantization (FP32 → INT8) reduces model size 4×, latency 2×
- **Adaptive Batching**: Increase batch size to 64 during high traffic (80% util → 95% util)
- **Edge Inference**: Deploy lightweight models to edge (mobile, IoT) for <10ms latency

**Operational Maturity**:
- **Self-Service**: Data scientists deploy models via CLI (`mlflow deploy fraud_detection_v3 --replicas 3`)
- **Cost Attribution**: Track inference costs per team/model (chargeback)
- **Chaos Engineering**: Kill GPU servers, introduce 500ms latency, test fallback to cached predictions

---

## Failure Scenarios

| Failure | Detection | Impact | Mitigation | Recovery Time |
|---------|-----------|--------|------------|---------------|
| **GPU Server Crash** | Health check failure (3 consecutive) | 10% capacity loss (1 of 10 servers) | Kubernetes restarts pod, traffic shifts to healthy servers | <2min (pod restart + model load) |
| **Model Load OOM** | CUDA out-of-memory error on startup | Model unavailable | Reduce batch size or deploy to larger GPU (T4 16GB → A10 24GB) | <10min (reconfigure + redeploy) |
| **Batch Job Spot Interruption** | Spot instance termination notice (2min warning) | Batch job paused mid-execution | Checkpoint progress to S3 every 10min, resume on new instance | <5min (new instance + reload checkpoint) |
| **Feature Store Down** | Redis timeout (1s) | Predictions fail (missing features) | Fallback to default features (user_age=30, location="US") or cached features | <1min (Redis failover to replica) |
| **Model Registry Unavailable** | S3 connection timeout | Can't deploy new models (existing models unaffected) | Keep last-deployed model cached on servers, retry S3 with exponential backoff | <5min (S3 recovery) |
| **A/B Test Failure** | Variant B error rate >2× variant A | 20% users see errors | Auto-rollback to 100% variant A, alert ML team | <30s (instant traffic shift) |
| **Model Drift** | Prediction distribution shifts >10% | Accuracy degrades over days/weeks | Retrain model with recent data, deploy v3 | Days (retrain + validate + deploy) |
| **Cache Stampede** | Popular input, cache TTL expires, 1000 simultaneous requests | Redis overload, increased latency | Request coalescing (dedupe in-flight requests), probabilistic early expiration | <5min (cache repopulated) |

---

## SLO Commitments

### Latency
- **Target**: p99 <100ms for real-time models, p99 <500ms for non-critical
- **Measurement**: `histogram_quantile(0.99, rate(inference_latency_seconds_bucket[5m]))`
- **Error Budget**: 1% of requests can exceed 100ms

### Availability
- **Target**: 99.95% uptime (22min downtime/month)
- **Measurement**: `(successful_predictions + cached_predictions) / total_requests`
- **Error Budget**: 43 minutes/month

### Throughput
- **Target**: Handle 100K predictions/sec globally
- **Measurement**: Auto-scale should maintain <80% GPU utilization
- **Error Budget**: QPS can drop to 90K for up to 5min during scaling events

### Model Deployment Speed
- **Target**: Deploy new model in <10min (code commit → production)
- **Measurement**: CI/CD pipeline duration
- **Error Budget**: 5% of deploys can take up to 30min (if manual approval required)

---

## Common Pitfalls

### 1. **Ignoring Cold Start Latency**
**Problem**: Loading 5GB transformer from S3 takes 30s → first request times out.

**Solution**:
- Preload models on server startup (liveness probe waits for model load)
- Keep models in memory 24/7 (don't unload after idle time)
- Use readiness probe: Only route traffic after test prediction succeeds

---

### 2. **Not Using Dynamic Batching**
**Problem**: Single requests → 5% GPU utilization → 20× more GPUs needed.

**Solution**:
- Enable dynamic batching (TensorFlow Serving: `--batching_parameters_file`, Triton: `max_batch_size`)
- Tune timeout (10ms for <100ms SLA, 50ms for <500ms SLA)
- Monitor batch size: Alert if avg <8 (underutilized GPU)

---

### 3. **High-Cardinality Metrics Explode**
**Problem**: Logging `prediction` value as metric label → 1M unique values → Prometheus crashes.

**Solution**:
- Use histograms for continuous values (latency, prediction confidence)
- Limit labels to low-cardinality dimensions (model_version, instance_id, status)
- Log full prediction details to S3 (not metrics system)

---

### 4. **No Feature Store → Train/Serve Skew**
**Problem**: Training uses SQL aggregation (user's 30-day avg), serving recomputes in Python → different results.

**Solution**:
- Use Feature Store (Feast/Tecton) for both training and serving
- Store feature computation logic (SQL/Spark) in version control
- Validate feature consistency: Compare training vs. serving features for same user

---

### 5. **A/B Test Without Statistical Significance**
**Problem**: Deploy v2 after 1 day with 1000 predictions → insufficient data → false positive.

**Solution**:
- Calculate required sample size: `n = (Z * σ / margin_of_error)^2` (e.g., 10K predictions for 95% confidence)
- Use sequential testing (Bayesian A/B test) for faster decisions
- Don't stop test early even if results look good (wait for planned duration)

---

### 6. **Model Drift Goes Undetected**
**Problem**: Production data changes (COVID shifts shopping patterns) → model accuracy drops from 95% → 70% over months.

**Solution**:
- Track prediction distribution: Alert if P(fraud=1) shifts >10% from baseline (2% → 2.2%)
- Sample 1% predictions, collect ground truth labels (delayed), measure accuracy weekly
- Set up champion/challenger: Run old model in shadow mode, compare with new model

---

### 7. **GPU OOM During Peak Traffic**
**Problem**: Traffic spikes → batch size increases → GPU out of memory → crash.

**Solution**:
- Set hard `max_batch_size` limit (32 for T4, 64 for A10)
- Monitor GPU memory: Alert if >90% utilized
- Use gradient checkpointing (training) or model quantization (inference) to reduce memory

---

### 8. **No Fallback for Model Failures**
**Problem**: Primary model crashes → all predictions fail → revenue loss.

**Solution**:
- **Cached Predictions**: Return last-known prediction for same input (stale but better than error)
- **Simpler Model Fallback**: If deep learning model fails, fall back to XGBoost (faster, lower accuracy)
- **Default Prediction**: For non-critical models (recommendations), return popular items

---

## Interview Talking Points

When discussing ML inference in interviews, emphasize:

### 1. **Latency vs. Throughput Trade-offs**
- "Dynamic batching increases throughput 10× but adds 10ms latency—acceptable for 100ms SLA, not for 20ms SLA."
- "TensorRT optimizations give 2-5× speedup on GPU but require NVIDIA lock-in and complex conversion pipeline."

### 2. **Feature Store Importance**
- "Feature store prevents train/serve skew—same feature computation code for training and serving."
- "Precompute batch features (daily) for low latency, use real-time features (Kafka/Flink) for critical signals."

### 3. **A/B Testing Mechanics**
- "User-level hashing (hash(user_id) % 100 < 20 → variant B) ensures consistent experience per user."
- "Shadow mode tests latency/errors with zero user impact, then traffic-based canary tests business metrics."

### 4. **GPU Optimization**
- "Single request = 5% GPU utilization → batch 32 requests = 80% utilization → 16× cost savings."
- "Multi-model serving amortizes GPU cost: 10 low-QPS models per GPU vs. 10 GPUs for 10 models."

### 5. **Model Monitoring**
- "Track prediction distribution (P(fraud=1) should match historical baseline), alert on >10% drift."
- "Sample 1% of predictions, get ground truth labels (delayed), measure accuracy weekly."

### 6. **Failure Handling**
- "GPU server crash → Kubernetes restarts pod, preloads model from S3 (30s), health check passes, traffic resumes."
- "A/B test failure (variant B error rate >2×) → auto-rollback to 100% variant A within 30s."

---

## Follow-Up Questions to Explore

1. **Model Compression**: Compare quantization (FP32→INT8), pruning, distillation for 4× smaller models.
2. **Edge Inference**: Design offline inference for mobile devices (Core ML, TensorFlow Lite, ONNX Runtime).
3. **Multi-Armed Bandits**: Use contextual bandits for dynamic A/B testing (vs. static 80/20 split).
4. **Explainability**: Add SHAP values to predictions—how to keep latency <100ms?
5. **Model Serving on Kubernetes**: Compare Seldon, KServe, BentoML for model deployment.
6. **Cost Optimization**: When to use spot instances, reserved instances, savings plans for GPU workloads?
7. **Real-Time Retraining**: Design online learning system that updates model every hour (streaming data).
8. **Fraud Detection**: Handle imbalanced classes (99% legit, 1% fraud) in model training and serving.
9. **Recommendation Systems**: Design two-tower model serving with candidate generation + ranking.
10. **Privacy-Preserving ML**: Use federated learning or differential privacy for sensitive data (healthcare, finance).

---

**Final Thought**: ML inference is about **latency** (batching, GPU optimization), **cost** (multi-model serving, spot instances), and **reliability** (A/B testing, monitoring). The key challenge is **train/serve skew**—models perform well offline but fail in production due to feature inconsistencies or data drift. Feature stores and rigorous A/B testing are critical to closing this gap.
