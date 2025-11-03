# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M users**
- Single model; batch training weekly; simple CF (ALS)
- Feature Store in PostgreSQL; no real-time signals

**1M → 10M users**
- Two-tower model; daily retraining; Kafka for real-time events
- Feature Store: Redis for hot embeddings; S3 for cold
- FAISS for ANN candidate generation; ranking service (10 instances)

**10M → 100M users**
- Multi-stage ranking: Candidate gen (kNN) → coarse ranker (100 candidates) → fine ranker (top 10)
- Distributed training (Horovod); model sharding by user cohort
- Experimentation platform; multi-armed bandits for exploration

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Feature Store cache miss | Slow recommendations | p95 latency spike | Fallback to batch embeddings in S3; populate cache asynchronously |
| Kafka lag | Stale features | Consumer lag > 10K msgs | Scale consumers; prioritize high-value users; backpressure |
| Model serving crash | No recommendations | Health check fails | Load balancer routes to healthy instances; fallback to popularity-based |
| Training pipeline failure | Outdated model | Daily job timeout | Use yesterday's model; alert ML eng; investigate ETL issues |
| Cold start (new user) | Poor recommendations | No interaction history | Content-based + trending items; prompt for preferences |

---

## SLOs

- p95 latency < 200ms; p50 < 100ms
- CTR > 5%; conversion rate > 2%
- Feature freshness < 10s for real-time signals
- Model update cadence: daily (weekly for large models)

---

## Common Pitfalls

1. Ignoring diversity → filter bubble; enforce category/creator diversity in top 10
2. Overfitting to clicks → optimize for downstream metrics (watch time, purchases)
3. No exploration → popular items dominate; use epsilon-greedy or Thompson sampling
4. Stale embeddings → poor recommendations; monitor feature freshness
5. No A/B testing → cannot measure impact; always test before full rollout

---

## Interview Talking Points

- Candidate generation vs. ranking two-stage pipeline
- Embedding learning (two-tower, contrastive loss, triplet loss)
- Real-time feature updates vs. batch precomputation tradeoffs
- Cold start strategies (content-based, trending, onboarding surveys)
- A/B testing mechanics and statistical significance

---

## Follow-Up Questions

- How to handle popularity bias and fairness in recommendations?
- How to support multi-objective optimization (CTR + revenue + diversity)?
- How to scale to 1B users with real-time personalization?
- How to implement explainability ("Recommended because...")?
- How to handle adversarial behavior (fake clicks, review bombing)?