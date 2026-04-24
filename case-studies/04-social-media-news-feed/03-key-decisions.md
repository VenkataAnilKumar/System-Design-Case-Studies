# Chapter 3 — Key Design Decisions

> Each decision records the options considered, the trade-offs, the final choice, and the conditions under which you would revisit it.

---

## Decision 1: Fan-Out Strategy — Push vs Pull vs Hybrid

### Options Considered

| Option | Description |
|---|---|
| **Push (fan-out on write)** | On every post, write post_id into each follower's timeline immediately |
| **Pull (fan-out on read)** | At feed fetch time, query each followee's post table and merge |
| **Hybrid** | Push for regular users; pull-at-read for celebrities (> threshold followers) |

### Trade-Offs

**Push**
- Pro: O(1) feed reads; Redis ZREVRANGEBYSCORE is microseconds; zero latency to assemble feed candidates.
- Pro: Simplest read path — single Redis key per user.
- Con: Write amplification — 1 post × 1 M followers = 1 M Redis writes. Celebrities make this catastrophic.
- Con: Wasted work — ~40% of followers are inactive; you write timelines nobody reads.
- Con: Fan-out lag grows with follower count; freshness SLO harder to meet at the tail.

**Pull**
- Pro: No write amplification; posting is O(1).
- Pro: Feed is always perfectly fresh at read time.
- Con: Feed fetch requires N DB reads (one per followee). At 2000 followees: 2000 parallel Cassandra reads → high latency, high DB load.
- Con: Ranking requires all candidates to be pulled before scoring; increases read path complexity.

**Hybrid**
- Pro: Combines benefits — normal users get low-latency push; celebrities don't blow up fan-out workers.
- Con: Two code paths to maintain; merge complexity at read time (merge sorted lists from Redis + celebrity sets).
- Con: Threshold choice is arbitrary; users near threshold need careful handling (hysteresis zone).

### Final Choice: Hybrid with threshold at 10 K followers

**Rationale:** The read path is the hot path (100:1 read/write ratio). Push for normal users keeps feed reads at O(1) Redis lookups. The celebrity tail (< 0.1% of users) is handled by pull-at-read without impacting the 99.9% case. Kafka decouples fan-out from post creation latency.

### When to Reconsider
- If > 5% of users exceed the threshold → revisit threshold or add tiered fan-out.
- If Redis cluster cost becomes dominant → evaluate Cassandra-based timeline with materialized views.
- If fan-out lag consistently exceeds 30 s → add more fan-out worker capacity or raise threshold.

---

## Decision 2: Timeline Storage — Redis Sorted Sets vs Cassandra vs DynamoDB

### Options Considered

| Option | Read Latency | Write Latency | Cost | Notes |
|---|---|---|---|---|
| **Redis Sorted Set** | < 2 ms | < 2 ms | High ($$/GB) | In-memory; fast; expensive at scale |
| **Cassandra wide rows** | 5–20 ms | 5–10 ms | Low ($/GB) | Durable; append-only; cheap |
| **DynamoDB** | 5–15 ms | 5–15 ms | Medium | Managed; limited query flexibility |
| **Hybrid: Redis + Cassandra** | < 2 ms (hot) | Both paths | Medium | Hot last 200 in Redis; full history in Cassandra |

### Trade-Offs

**Redis Sorted Sets**
- Pro: Single-digit millisecond reads; ZADD + ZREVRANGEBYSCORE is atomic and fast.
- Con: Memory-resident = expensive. 2.56 TB of timeline data at $5–10/GB/month = $12–25 K/month just for timelines.

**Cassandra Wide Rows**
- Pro: Cheap durable storage; naturally partitioned by user_id, clustered by timestamp.
- Con: 5–20 ms read latency busts the 200 ms feed SLO when combined with other steps.

**DynamoDB**
- Pro: Fully managed; auto-scaling.
- Con: Hot partition problem if user_id distribution is skewed; vendor lock-in.

**Hybrid Redis + Cassandra**
- Hot tier: last 200 timeline entries in Redis (covers > 95% of feed loads).
- Warm tier: full timeline history in Cassandra for pagination and cache misses.
- Pro: Keeps Redis footprint ~75% smaller vs pure Redis; low latency for the common case.

### Final Choice: Redis Sorted Sets (hot tier, last 200 entries) + Cassandra (warm tier, full history)

**Rationale:** Feed reads are the highest-frequency operation (5 M/sec). The 2 ms Redis latency is essential to meet the 200 ms end-to-end SLO. Redis footprint is reduced by storing only the last 200 entries per user, with Cassandra backing for deep pagination. Inactive user timelines expire from Redis after 7 days (EXPIRE), freeing memory automatically.

### When to Reconsider
- Redis memory cost > 30% of total infra budget → migrate hot tier to Dragonfly DB or evaluate Cassandra with row cache and SSD tiering.

---

## Decision 3: Counter Architecture — Write-Through vs Write-Back vs CRDT

### Options Considered

| Option | Description |
|---|---|
| **Write-through to DB** | Every like/unlike immediately writes to Cassandra COUNTER table |
| **Write-back (Redis + async flush)** | Increment Redis counter immediately; flush to Cassandra in batches every 60 s |
| **CRDT counters** | Distributed CRDT G-Counter replicated across nodes; merge on read |
| **HyperLogLog** | Approximate unique-viewer counts using Redis PFADD/PFCOUNT |

### Trade-Offs

**Write-through**
- Con: Cassandra COUNTER writes at 500 K events/sec requires a very large cluster.
- Con: COUNTER type is not idempotent — retry storms double-count.

**Write-back (Redis + async flush)**
- Pro: Redis INCR is atomic, sub-millisecond, handles 500 K ops/sec on a small cluster.
- Pro: Batch flush amortizes DB writes; 60 s flush window = 30 M events batched per minute.
- Con: Up to 60 s of counter data lives in Redis only — crash loses that window (mitigated by AOF + replica).

**CRDT G-Counter**
- Pro: Naturally conflict-free in multi-region active-active.
- Con: No native Redis CRDT in open-source Redis; requires Redis Enterprise or custom implementation.
- Con: Overkill for single-region deployment.

**HyperLogLog**
- Appropriate for unique-viewer counts (cardinality estimation), not total like counts.

### Final Choice: Write-back (Redis INCR + async Kafka flush to Cassandra)

**Rationale:** 500 K events/sec at sub-millisecond Redis latency is the only viable option at this scale. A 60 s staleness window is acceptable per requirements. Exact counts on demand: post detail view bypasses Redis and reads from Cassandra. Idempotency: Redis `SET NX` prevents double-counting on retries.

### When to Reconsider
- Multi-region active-active → CRDT counters eliminate cross-region synchronization overhead.
- Exact-count SLA required (e.g., creator monetization payouts) → synchronous write-through to Spanner for those specific counters.

---

## Decision 4: Feed Pagination — Cursor-Based vs Offset-Based

### Options Considered

| Option | Stability | Performance | Complexity |
|---|---|---|---|
| **Offset-based** | Unstable on live feed | O(offset) scan | Minimal |
| **Time-cursor** | Stable | O(log N) | Low |
| **Keyset (composite cursor)** | Deterministic | O(log N) | Medium |
| **Server-side opaque cursor** | Deterministic | Varies | High (stateful) |

### Trade-Offs

**Offset-based** — Simple but unstable: items inserted between pages cause duplicates or skips. Deep pagination requires scanning all preceding rows.

**Time-cursor** — Stable pagination; posts with identical timestamps create non-deterministic page boundaries (need tiebreaker).

**Keyset (composite cursor)** — Deterministic: (score, post_id) is globally unique. O(log N) in sorted structures. Handles clock skew: sort by ingestion timestamp; break ties by post_id.

### Final Choice: Keyset cursor with (score, post_id) composite, encoded as opaque base64

**Rationale:** Encoded as base64 JSON `{score: float, post_id: uuid}`, treated as opaque by clients. Server-side maps to `ZREVRANGEBYSCORE timeline:{uid} (score -inf LIMIT 0 21` (fetch 21, return 20, use the 21st as next cursor). Deterministic, O(log N), no server state.

---

## Decision 5: Post Deduplication Across Feed Sources

### The Problem

In the hybrid fan-out model, the same post_id can appear in multiple sources:
1. `timeline:{user_id}` — pushed fan-out for non-celebrity authors.
2. `celebrity_posts:{author_id}` — pulled at read time for celebrity authors.
3. `posts_by_author:{author_id}` — Cassandra fallback during Redis outage.

### Options Considered

| Option | Cost | Accuracy |
|---|---|---|
| **In-memory hash set** | O(N) memory, bounded at 200 | Exact |
| **Sorted set merge** | O(N log N) | Exact (set semantics) |
| **Bloom filter** | O(1) per check | ~1% false-positive |
| **Original post_id dedup post-hydration** | Requires hydration first | Exact for reposts |

### Final Choice: In-memory hash set dedup + original_post_id dedup post-hydration

**Rationale:** Candidate set is bounded at 200 posts — a 200-element hash set lookup is O(1) and uses < 10 KB of memory per request; no persistent state required. After hydration, a second dedup pass on `original_post_id` collapses reposts of the same source post, keeping the highest-ranked variant.

---

## Decision 6: Ranking Feature Engineering — Online vs Offline vs Hybrid

### Options Considered

| Approach | Latency | Freshness | Notes |
|---|---|---|---|
| **Pure online features** | High | Real-time | 200 candidates × 5 M req/sec = massive read fan-out |
| **Pure offline features** | Low | Hours-stale | Misses engagement velocity signals |
| **Hybrid (online + offline)** | Low | Mixed | Offline affinity + online velocity |
| **Two-tower model** | Very low | Embedding staleness | Cold start problem for new posts |

### Final Choice: Hybrid feature engineering with ONNX gradient-boosted tree model

**Features**: Offline (user-author affinity, author historical engagement rate — hourly Spark job → Redis Feature Store) + Online (engagement velocity — INCR counter reads, < 1 ms; freshness decay — computed inline from timestamp).

**Rationale:** GBDT with hybrid features is interpretable, fast at inference (< 0.1 ms per candidate with ONNX Runtime), and well-suited for mixed feature types. Two-tower embeddings deferred to Phase 2 (content discovery outside the follow graph).

---

## Decision 7: Multi-Region Strategy

### Options Considered

| Strategy | Availability | Write Latency | Operational Complexity |
|---|---|---|---|
| **Single region** | Low | Low | Minimal |
| **Active-passive** | Medium | Low (primary) | Medium |
| **Active-active with local reads** | High | Low (local) | High |
| **Active-active with global write routing** | High | High (cross-region commit) | Very high |

### Final Choice: Active-active with local reads, async cross-region CDC replication

**Rationale:** Feed latency is dominated by the read path. Serving reads from the local region is non-negotiable for the p95 < 200 ms SLO globally. Write conflicts (concurrent follow/unfollow, counter updates) are resolved by last-write-wins with timestamp — acceptable for social data. Kafka CDC replication between regions with 15–30 s average lag sits within the freshness SLO.

---

## Decision 8: Graph Storage — Relational vs Key-Value vs Graph DB

### Options Considered

| Option | Transaction Support | Fan-out Read | Complexity |
|---|---|---|---|
| **MySQL + Redis cache** | Full ACID | Batch follower lookup via cache | Medium |
| **Neo4j / graph DB** | Limited | Traversal-optimized (overkill for bulk) | High |
| **Cassandra wide-row** | None (LWT) | Efficient bulk reads | Medium |
| **Redis only** | None | Microsecond | Memory-constrained |

### Final Choice: MySQL (source of truth) + Redis (hot cache) + Cassandra (large follower sets for celebrities)

**Rationale:** Follow relationships require ACID guarantees (follow-request acceptance must be atomic). MySQL provides this. Redis caches hot following/follower sets for the 99% case. Cassandra stores the full follower list for celebrity accounts where MySQL index size becomes a concern. Three-tier approach matches data temperature to storage cost.

---

## Decision 9: Timeline Backfill & Rebuild Strategy

### Scenarios Requiring Rebuild
1. User follows a new account → need to inject that account's recent posts retroactively.
2. Redis cluster failure → all timelines lost; must rebuild from Cassandra.
3. Fan-out worker bug → subset of timelines corrupted or missing entries.
4. Account unblock → previously filtered posts may now be visible.

### Options Considered

| Option | User Experience | System Impact |
|---|---|---|
| **On-demand backfill (sync)** | Immediate but first load > 1 s | Cascade risk on Redis recovery |
| **Async backfill job** | Short stale window (< 5 s) | Rate-limited; safe |
| **Full rebuild from Cassandra** | Correct but expensive | High Cassandra read load |
| **Incremental backfill (7-day window)** | Covers 99% of practical use | Cost-effective |

### Final Choice: Async incremental backfill (7-day window) with on-demand trigger

**Rationale:** On new follow: async job queued; injects posts from last 7 days from `posts_by_author` for the new followee into the user's Redis timeline. On Redis recovery: bulk backfill job reads last 200 posts per active user from Cassandra, writes back to Redis — rate-limited at 100 K writes/sec. Estimated full rebuild time for 50 M active users: ~2 h.
