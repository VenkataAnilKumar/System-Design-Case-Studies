# Chapter 4 — Wrap-Up

> Operational readiness, failure playbook, SLOs, and interview prep.

---

## Scaling Playbook

Scale each dimension independently. The system is designed so no single bottleneck controls all traffic paths.

### Dimension 1: Post Write Throughput
- **Scale trigger**: Post API CPU > 70% or p99 write latency > 100 ms.
- **Action**: Add Post API pods (Kubernetes HPA on RPS). Kafka auto-scales partition consumers. Cassandra write throughput scales linearly with nodes.

### Dimension 2: Fan-Out Throughput
- **Scale trigger**: Kafka consumer group lag > 60 s (HPA) or > 5 min (PagerDuty page).
- **Action**: Add fan-out workers (HPA on consumer lag metric). If Redis write throughput is the bottleneck: add Redis Cluster shards.
- **Ceiling**: Redis Cluster scales to ~1 M writes/sec per shard × N shards. At 10 M writes/sec: 10+ shards.

### Dimension 3: Feed Read Throughput
- **Scale trigger**: Feed API RPS > 80% of cluster capacity or p95 > 250 ms.
- **Action**: Scale Feed API pods (HPA). Add Redis read replicas for timeline reads. Add Memcached nodes for post hydration.

### Dimension 4: Counter Throughput
- **Scale trigger**: Redis CPU > 60% or INCR latency > 2 ms.
- **Action**: Shard counter Redis by `post_id % N`. Each shard handles its partition of post counters independently.

### Dimension 5: Graph Service
- **Scale trigger**: Graph service p95 > 5 ms or error rate > 0.1%.
- **Action**: Add Redis read replicas for follower set cache. MySQL read replicas for the durable graph store. Scale Graph Service API pods horizontally.

### Dimension 6: Ranking Service
- **Scale trigger**: Ranking p95 > 25 ms or ranking error rate > 0.5%.
- **Action**: Scale Ranking Service pods (model is in-process ONNX; fully stateless). Add Redis read replicas for feature store reads.

### Dimension 7: Storage Growth
- **Action**: Tiered archival — posts > 30 days: Parquet on S3; posts > 1 year: S3 Glacier. Cassandra cluster holds only the hot tier (< 30 days). Table-level TTLs enforce hot tier automatically.

### Dimension 8: Notification Throughput
- **Scale trigger**: Push gateway queue depth > 100 K or APNs/FCM error rate > 1%.
- **Action**: Scale Notification Worker pods. Tune per-user notification rate limits (currently 5/hr) to shed load during viral events.

---

## Failure Scenarios

### Scenario 1: Redis Cluster Failure (Timeline Store Down)

**Impact**: Feed reads cannot retrieve timeline data from cache. All 5 M reads/sec hit the fallback path simultaneously. Feed latency degrades from 45 ms to ~500 ms p95.

**Detection**: Prometheus alert — Redis `up == 0` for > 30 s; Feed API cache-miss-rate > 50%; feed latency p95 > 400 ms.

**Mitigation**: Feed API circuit breaker activates fallback: read `posts_by_author` from Cassandra for the user's top 20 followees by interaction recency. Feed remains functional; quality unchanged.

**Recovery**: Redis Sentinel / Cluster auto-failover to replica within 30 s for single-node failure. Full cluster restart triggers async timeline rebuild job (7-day window, rate-limited at 100 K writes/sec). Estimated full rebuild: ~2 h for 50 M active users.

---

### Scenario 2: Fan-Out Worker Lag

**Impact**: Posts published but not yet appearing in followers' feeds. Freshness SLO violated.

**Detection**: Kafka consumer group `fanout-workers` lag > 60 s → PagerDuty. Freshness probe (automated test account posts; measures time until visible in test-follower's feed) exceeds 30 s.

**Mitigation**: Scale fan-out workers immediately via HPA. If lag is caused by a celebrity thundering herd: dynamically promote the author above the fan-out threshold, switching them to pull-at-read.

**Recovery**: Workers consume Kafka backlog (7-day retention). No data is lost. Posts appear in feeds retroactively as workers process.

---

### Scenario 3: Cassandra Post Store Degradation

**Impact**: Post hydration cache misses fall through to a slow or unavailable Cassandra. Feed assembly stalls on the hydration step.

**Detection**: Cassandra `read_latency_p99` > 20 ms; Memcached miss-to-Cassandra error rate rising; Feed API hydration step p95 > 30 ms.

**Mitigation**: Post hydration cache (Memcached, 24 h TTL) serves recently accessed posts without touching Cassandra. Feed API reduces candidate set from 200 to 50 during degradation. Posts absent from Memcached are omitted rather than blocking — partial feed returned with `X-Feed-Degraded: true` header.

**Recovery**: RF=3 + LOCAL_QUORUM: tolerates 1-node failure per rack transparently. For 2-node failure: demote reads to LOCAL_ONE. Full Cassandra outage: serve feed from Memcached only.

---

### Scenario 4: Privacy Filter Bug — Posts Visible to Wrong Users

**Impact**: Posts marked `followers_only` or from private accounts appear in unauthorized feeds. P0 trust/safety incident.

**Detection**: Privacy audit log (samples 1% of feed responses, checks each returned post's visibility against requesting user's graph). Any audit violation triggers immediate PagerDuty page. Automated red-team test accounts run every 5 minutes.

**Mitigation**: Kill switch: disable feed endpoint; serve empty feed with "temporarily unavailable" message. Do not serve stale cached feeds — they may contain violating posts.

**Recovery**: Replay privacy audit log to identify affected users and posts. Proactive user notification if required by regulation. Post-incident: tighten audit coverage from 1% to 10% sampling.

---

### Scenario 5: Ranking Service Failure

**Impact**: Feed posts returned in reverse-chronological order. Estimated 20–30% engagement drop vs ranked feed. No data loss; no privacy incident. Service fully functional.

**Detection**: Ranking service health check fails; Feed API fallback mode activated (`ranking_fallback_rate` > 1%). PagerDuty warn at 1%, page at 5%.

**Mitigation**: Feed API wraps ranking call with 25 ms hard timeout. On timeout or error: fallback to reverse-chronological sort. Feeds remain functional immediately.

**Recovery**: Ranking service is fully stateless (ONNX model loaded in-process). Pod restart recovers in < 30 s. No persistent state to rebuild.

---

### Scenario 6: Counter Hot Key (Viral Post)

**Impact**: A post goes viral — 1 M likes/sec hitting a single Redis key. Single shard CPU saturated; counter increment latency spikes for all keys on that shard.

**Detection**: Redis per-key ops/sec metric > 100 K/sec on a single key (hot-key monitor daemon). Shard CPU > 80%.

**Mitigation**: Automatic counter sharding: Engagement API routes increments to `counter:{post_id}:likes:{shard_id % N}` where shard_id is selected randomly. Read path sums shards: `SUM(counter:{post_id}:likes:*)`.

**Recovery**: Per-shard load reduced by N×. Counters remain eventually consistent. No data loss (Redis AOF + replica).

---

### Scenario 7: Graph Service Unavailable

**Impact**: Fan-out workers cannot resolve follower lists. New posts written to Cassandra but not pushed to any timelines. Feed reads pass privacy checks against stale cached data.

**Detection**: Graph service error rate > 5% → page. Fan-out worker logged errors: `graph_lookup_failed` counter spiking.

**Mitigation**: Fan-out workers use a cached follower-list snapshot (Redis, TTL 5 min) as a fallback. Privacy filter falls back to MySQL direct reads (slower but correct).

**Recovery**: Graph service is stateless; pod restart recovers in < 30 s. Fan-out workers that used stale cached snapshots produce correct (if slightly delayed) timelines.

---

## SLOs

| Service / Metric | p50 | p95 | p99 | Error Budget (monthly) |
|---|---|---|---|---|
| Feed API latency (warm cache) | 50 ms | 200 ms | 400 ms | 0.05% (21.6 min) |
| Feed API latency (cold / cache miss) | 150 ms | 500 ms | 800 ms | — |
| Post creation (write, sync steps) | 30 ms | 100 ms | 200 ms | 0.1% (43.2 min) |
| Fan-out freshness (post → feed) | 2 s | 15 s | 30 s | best-effort |
| Ranking service latency | 5 ms | 20 ms | 40 ms | 0.1% (fallback OK) |
| Graph/privacy service latency | 1 ms | 3 ms | 8 ms | 0.01% (critical) |
| Engagement API (like/unlike) | 10 ms | 30 ms | 60 ms | 0.1% |
| Feed endpoint availability | — | — | — | 99.95% (4.38 hr/yr) |
| Privacy error rate | — | — | — | < 0.001% |
| Counter staleness (feed display) | — | — | — | < 60 s |

---

## Pitfalls and Gotchas

**1. Celebrity threshold is not dynamic.** A static 10 K follower threshold creates an oscillation problem. Accounts near the boundary can cross it during a viral moment, switching between push and pull mid-session. Fix: add a hysteresis dead zone (switch to pull at 10 K; do not switch back to push until < 8 K). Evaluate threshold dynamically based on recent fan-out queue depth, not just follower count.

**2. Clock skew in timeline cursors.** Unix timestamps as cursor scores break when servers have > 1 s clock skew. Server A writes a post with score T+1; server B writes with score T. User paginates from T — they miss server B's post. Fix: use hybrid logical clocks (HLCs) for timeline ordering, or use Cassandra-assigned write timestamps as the canonical sort key rather than client-submitted values.

**3. Thundering herd on Redis recovery.** When Redis recovers after a full outage, the first wave of feed reads all miss cache and simultaneously fan out to Cassandra. At 5 M req/sec × 20 followees = 100 M Cassandra reads/sec — catastrophic. Fix: probabilistic early expiration (PER) to proactively refresh cache entries before expiry. Alternatively, stagger cache rebuilds by user cohort, rate-limiting Cassandra rebuild reads.

**4. Privacy check race condition.** If a user blocks another during an active feed session, the privacy filter may still hold a cached "not blocked" relationship for up to the cache TTL (5 min). Fix: on block event, immediately invalidate the privacy cache for the affected user pair by publishing to `privacy.updated` Kafka topic consumed by all privacy filter pod instances.

**5. Engagement idempotency key space explosion.** Redis `SET NX user:{uid}:liked:{post_id}` with 30-day TTL — at 500 K engagements/sec × 30 days = 1.3 T keys. At ~60 bytes/key = 78 TB Redis memory for idempotency alone — infeasible. Fix: use a Bloom filter for fast "already liked" checks (< 1% false-positive). Back Bloom filter positives with a Cassandra `user_engagements` table for exact verification.

**6. Ranking cold start for new posts.** A brand-new post has zero engagement velocity. The GBDT model was trained on posts with engagement features populated. New posts receive low predicted scores — a self-fulfilling prophecy. Fix: inject a freshness boost for posts < 5 min old (additive score term that decays exponentially). Reserve a "new post" slot: always include the single most-recent unranked post from each followee regardless of model score.

**7. Backfill cascade on mass follow.** A user imports 500 contacts and follows them all at once. 500 concurrent Cassandra range scans × N simultaneous mass-follow users = significant read amplification. Fix: rate-limit backfill jobs per user (max 10 concurrent). Show "Loading your feed..." UX indicator. Cap total cluster-wide backfill Cassandra read rate to protect other workloads.

**8. Stale feature vectors after rapid engagement.** Offline affinity features updated hourly. If a user rapidly engages with a new author (10 likes in 5 minutes), the feed won't prioritize the new author for up to 1 hour. Fix: maintain a short-term online affinity cache in Redis (`affinity:{user_id}:{author_id}`, 2 h TTL, incremented on each engagement event). Blend online and offline affinity at scoring time (0.3 × online + 0.7 × offline).

---

## Interview Talking Points

**Q: Why not pull on every feed read instead of pre-computing timelines?**

Pull eliminates write amplification but shifts the problem to the read path catastrophically. A user following 2000 accounts triggers 2000 parallel queries on every feed load. At 5 M feed reads/sec: 10 B DB reads/sec — three orders of magnitude more than with cached timelines. Push: storing post IDs in Redis costs pennies per user; avoiding 10 B reads/sec saves the entire DB cluster. Pull is only viable for users following < 50 accounts, and even then it hurts latency. Hybrid gives you the best of both.

**Q: How do you handle a celebrity with 100 M followers posting at the same time as 50 K other posts?**

Celebrity posts bypass fan-out entirely — they land in `celebrity_posts:{author_id}` only. Fan-out cost is O(1) regardless of follower count. At read time, the Feed API queries this table for celebrities the user follows (typically < 10). The merge of celebrity posts with the personal Redis timeline happens in the Feed API, sorted by score. This decouples "everyone sees this" (a broadcast problem) from "personalized timeline" (a per-user cache problem).

**Q: What happens if ranking fails?**

Ranking is a soft dependency with a 25 ms hard timeout. On failure: reverse-chronological fallback. Feeds are functional; quality degrades ~20–30% by engagement metrics. Never block a feed render waiting for ranking. The key interview insight: design every non-critical dependency as a soft dependency with a defined fallback. Identify your hard dependencies (Redis for timeline, Cassandra for post writes) and protect them — everything else should degrade gracefully.

**Q: How do you guarantee a blocked user's posts never appear in a feed?**

Defence in depth at two layers. Layer 1 (write time): fan-out workers check block lists before writing to a follower's timeline — the post never enters the timeline. Layer 2 (read time): privacy filter checks block/mute relationships after hydration, before response. Layer 1 prevents wasted timeline entries; Layer 2 is the safety net for race conditions (user blocks author after the post is already in cache). On a block event, immediately invalidate the privacy cache entry for that user pair via the `privacy.updated` Kafka topic.

---

## Follow-Up Q&A

**Q: How would you add real-time feed updates (WebSocket push)?**

Add a Feed Push Service maintaining persistent WebSocket connections per client. When a fan-out worker writes a new post_id to a user's timeline, it also publishes to a per-user pub/sub topic (Redis Pub/Sub or Kafka `timeline.updated:{user_id}`). The Push Service subscribes per user and sends a lightweight signal to the client: `{"type": "new_posts_available", "count": 3}`. The client then calls `GET /v1/feed` normally to retrieve the posts. This avoids pushing full post payloads over WebSocket while giving users real-time awareness.

**Q: How would you design the Explore/Trending feed?**

Trending is architecturally separate from the home feed. (1) Trend detection: sliding-window counters on hashtag/keyword frequency using Apache Flink. A topic trends when its 15-min velocity exceeds N × its 24-hour baseline velocity. (2) Trend index: Elasticsearch or a purpose-built inverted index populated by a batch job. (3) Explore feed: collaborative filtering (users similar to you engaged with these posts) rather than follow-graph-based ranking. The home feed architecture needs no changes — Explore is an additive read path with different ranking signals.

**Q: How do you avoid showing duplicate reposts in the feed?**

After post hydration, each hydrated post object includes `original_post_id`. In Feed API, after hydration, run a dedup pass: keep only the highest-ranked repost per original; drop duplicates. This is O(N) over the 200-candidate set — trivial. The feed shows "Alice and Bob both reposted this" as a single entry, which is also better UX.

**Q: How do you handle account deletion and the right to be forgotten?**

Account deletion triggers a multi-stage async pipeline: (1) Immediately: account deactivated, auth tokens revoked, profile hidden. (2) Within 24 h: all posts soft-deleted; privacy filters begin returning empty for those posts. (3) Within 30 days: hard delete from Cassandra post store; Kafka compaction tombstones remove events. (4) Follower/following graph edges removed via Graph Service job. (5) Timeline entries pointing to deleted posts cleaned by a background sweeper (ZREM from Redis sorted sets). Audit logs retained separately under legal hold exemption.

**Q: How would you extend this design to support ephemeral Stories (24-hour content)?**

Stories require a separate timeline because they expire. Add a `stories_timeline:{user_id}` sorted set with 24 h item-level TTL enforced via a background sweeper. Stories stored in a `stories` Cassandra table with a 25 h TTL (1 h grace). Feed API reads both timelines independently; renders them in separate UI sections. No changes to the post fan-out path.

**Q: How do you prevent the system from amplifying misinformation through ranking?**

The ranking model uses engagement velocity as a strong signal — misinformation often receives high engagement velocity before fact-checking occurs. Mitigations at multiple layers: (1) Content policy ML classifier runs async on every post before fan-out completes — high-confidence violations are held. (2) Ranking model includes a "misinformation risk" feature (output from a separate classifier) as a hard downrank signal. (3) Verified fact-check labels from trusted partners suppress ranking score. (4) Viral threshold circuit breaker: posts reaching > 1 M engagements/hour are paused for human review before further amplification.

**Q: What does graceful degradation look like end-to-end?**

Four tiers, each worse than the previous but still functional. Tier 1 (normal): ranked, fresh, personalized feed from Redis + Ranking Service, p95 45 ms. Tier 2 (ranking down): reverse-chronological feed from Redis, p95 25 ms, engagement drops ~25%. Tier 3 (Redis down): Cassandra fallback, unranked, p95 500 ms, no data loss. Tier 4 (Cassandra down): Memcached-only feed, stale but functional, shows cached posts from last 24 h. The system never returns an empty feed if any tier is available — an empty feed is worse than a stale feed for user trust.

---

## Closing Summary

This design separates the write-heavy fan-out path from the read-heavy feed assembly path, using Kafka as the decoupling boundary. The fundamental insight is that a social feed is a pre-computation problem: the expensive work — resolving followers, filtering, ordering — must happen at write time for normal users, not at read time. The celebrity exception inverts this: their massive follower counts make write-time fan-out impractical, so their posts are injected at read time with a simple table scan.

The system tolerates failures gracefully at every layer. Ranking fails: reverse-chronological fallback. Redis fails: Cassandra fallback. Fan-out lags: eventual consistency within SLO. No single component failure produces an outage — degraded quality is acceptable; an empty feed is not.

Three non-obvious insights worth carrying into any interview: (1) Timeline storage is the most cost-sensitive component — the Redis/Cassandra tiering decisions drive infrastructure cost more than any other choice. (2) Counter consistency is a trap — exact counts require a separate read path and most products do not need them in the feed. (3) Privacy correctness requires defence in depth — single-layer privacy checks are insufficient given the race conditions between block events, cached timeline contents, and high write concurrency.
