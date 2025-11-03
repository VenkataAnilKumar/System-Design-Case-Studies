# ML Model Inference Service

## Problem Statement

Design a **TensorFlow Serving-like ML inference service** that serves predictions from trained models with low latency and high throughput.

**Core Challenge**: Serve 100K predictions/sec with <100ms p99 latency while supporting model versioning, A/B testing, and GPU optimization.

**Key Requirements**:
- Real-time inference API (REST/gRPC)
- Batch inference for offline workloads
- Model versioning and rollback
- A/B testing (route 20% to model v2)
- Dynamic batching for GPU efficiency
- Autoscaling based on load

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100K pred/sec, <100ms latency, GPU optimization) |
| [02-architecture.md](./02-architecture.md) | Components (Model Server, Registry, Feature Store, A/B Router) |
| [03-key-decisions.md](./03-key-decisions.md) | Dynamic batching, model caching, GPU vs CPU |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to 1000 models, failure scenarios, cost optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Inference Latency** | p99 <100ms |
| **Throughput** | 100K predictions/sec |
| **GPU Utilization** | >80% (maximize throughput) |
| **Model Load Time** | <10s (model swap/rollout) |

## Technology Stack

- **Model Serving**: TensorFlow Serving, TorchServe, Triton
- **Dynamic Batching**: Batch requests within 10ms window
- **Model Registry**: MLflow, SageMaker Model Registry
- **Feature Store**: Feast for feature lookup
- **Autoscaling**: Kubernetes HPA based on GPU utilization

## Interview Focus Areas

1. **Dynamic Batching**: Batch 32 requests within 10ms for GPU efficiency
2. **Model Versioning**: Canary deployments (5% traffic to v2)
3. **GPU Optimization**: TensorRT, model quantization (FP32 → INT8)
4. **Feature Store**: Precomputed features for low-latency lookup
5. **A/B Testing**: Traffic splitting with statistical significance
