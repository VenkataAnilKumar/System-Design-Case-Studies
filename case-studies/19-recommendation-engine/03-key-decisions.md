# 3) Key Design Decisions & Trade-Offs

## 1. Collaborative Filtering vs. Content-Based

**Decision**: Hybrid (CF for users with history; content-based for cold start).

**Rationale**: CF captures user behavior; content-based handles new items.

**Trade-off**: Complexity in blending; need both pipelines.

**When to reconsider**: If catalog is static; pure CF may suffice.

---

## 2. Matrix Factorization vs. Deep Learning

**Decision**: Two-tower deep learning for embeddings; MF as fallback.

**Rationale**: DL captures nonlinear patterns; scales better with features.

**Trade-off**: Higher training cost; need GPUs; interpretability harder.

**When to reconsider**: Small catalog (<100K items); MF (ALS) is simpler and faster.

---

## 3. Real-Time vs. Batch Feature Updates

**Decision**: Real-time for short-term history; batch for embeddings.

**Rationale**: Balance freshness with cost; embeddings stable over hours.

**Trade-off**: Eventually consistent features; requires stream processing infra.

**When to reconsider**: If latency budget allows; batch every 5 min may suffice.

---

## 4. kNN vs. Learned Index for Candidate Gen

**Decision**: kNN on embeddings (FAISS/Annoy).

**Rationale**: Fast ANN search (<50ms for 10M items); easy to update index.

**Trade-off**: Approximate (not exact top-K); index rebuild on embedding updates.

**When to reconsider**: If exact top-K needed; use learned index (slower but precise).

---

## 5. Centralized vs. Distributed Ranking

**Decision**: Centralized ranking service; shard by user cohort if needed.

**Rationale**: Simplifies model serving; most users fit in single instance.

**Trade-off**: Potential bottleneck; need horizontal scaling for high QPS.

**When to reconsider**: If >100K QPS; partition by user_id and route via proxy.

---

## 6. Precompute vs. On-Demand Embeddings

**Decision**: Precompute and cache in Feature Store.

**Rationale**: Sub-10ms lookup; batch updates sufficient for most users.

**Trade-off**: Stale embeddings (lag ~1 hour); storage cost.

**When to reconsider**: For power users; compute embeddings on-demand with real-time signals.

---

## 7. A/B Test Assignment: User-Level vs. Session-Level

**Decision**: User-level (consistent experience).

**Rationale**: Avoids confusion; metrics stable per user.

**Trade-off**: Cannot test within-session effects; longer ramp-up time.

**When to reconsider**: Short sessions (anonymous users); session-level is faster.
