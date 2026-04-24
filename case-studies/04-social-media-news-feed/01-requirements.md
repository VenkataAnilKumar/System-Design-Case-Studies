# 1) Requirements & Scale

> Goal: Define what we are building, how big it needs to be, and the first-order constraints. Keep it brief and practical.

---

## What we are building (at a glance)

A personalized social media news feed (Twitter/Instagram-style) where users follow each other, publish posts (text + media), and see a ranked timeline of their followees' content in near real-time.

Scope (Phase 1): Design only (no code), production-credible, cloud-friendly.

---

## Core requirements

### Functional

- **Post creation**: Users create posts containing text (≤ 280 chars for tweets; ≤ 2200 chars for captions), images, or video thumbnails pointing to media in object storage. Visibility: public / followers-only / mentioned-only.
- **Home feed**: Personalized timeline of posts from accounts the user follows. Default ranking: ML-ranked by engagement affinity; fallback: reverse-chronological.
- **Engagement**: Like, comment, share/repost, save; counters visible on each post. Idempotent (double-like is a no-op).
- **User graph**: Follow / unfollow / block / mute. Private accounts: follow requests must be accepted before feed access.
- **Notifications**: Push and in-app alerts for new posts from close accounts, mentions, engagement on own posts.
- **Search & Explore**: Trending topics, hashtag pages, user search. Optional for Phase 1 — separate service.
- **Creator analytics**: View counts, engagement rates, follower growth — batch-updated daily.

### Non-functional

- **Feed latency**: p95 < 200 ms (warm cache); cold miss < 500 ms
- **Write latency**: Post creation p99 < 200 ms (sync steps only; fan-out is async)
- **Availability**: 99.95%+ for feed reads; 99.9% for post writes
- **Freshness**: Post visible in followers' feeds within 30 s (p95) of creation
- **Privacy correctness**: Blocked/muted/private-account posts must never appear in unauthorized feeds
- **Cost**: Prefer precomputed timelines to minimize read-time computation; tier storage aggressively

---

## Scale targets (order-of-magnitude)

- **Users**: 200 M MAU; 50 M DAU
- **Posts created**: 10–50 K posts/sec peak; median 1 K/sec
- **Engagements**: 10× posts = 100–500 K events/sec peak
- **Feed reads**: 1–5 M/sec globally (50 M DAU × 100 feed loads/day ÷ 86 400 s ≈ 58 K baseline; 5 M at peak)
- **Follower graph**: Median ~200 followers; 99th percentile 10 K; celebrity accounts: up to 100 M followers
- **Notifications**: ~5 M push deliveries/sec at peak engagement windows

---

## Quick capacity math (back-of-envelope)

**Storage — posts**
- 200 B post metadata × 1 B posts/year (10 K posts/sec × 86 400 s × 365) = ~200 TB/year of post metadata
- Hot tier (Cassandra, last 30 days): 200 B × 26 B posts = ~5 TB
- Media (images, videos): stored in object storage, CDN-fronted — out of scope for feed architecture

**Storage — timelines**
- 50 M DAU × last 200 posts × 16 bytes (UUID) per entry = 160 GB of timeline data
- With Redis: 160 GB well within a medium Redis cluster (32–64 GB usable per node × 5 nodes)

**Write throughput — fan-out**
- Normal user post: author has 200 followers → 200 Redis ZADD operations per post
- At 1 K posts/sec × 200 followers avg = 200 K Redis writes/sec for fan-out
- Celebrity post (100 M followers): fan-out is skipped entirely (pull-at-read)

**Read throughput — feed**
- 5 M feed reads/sec × 1 Redis ZREVRANGEBYSCORE = 5 M Redis reads/sec
- Redis cluster with 5 nodes handles 1 M reads/sec per node → 5 nodes for baseline; 15 nodes for peak

**Engagement counters**
- 500 K events/sec → Redis INCR per event; 60 s flush batch to Cassandra
- Cassandra flush rate: 500 K/sec ÷ (500 K events/flush) = 1 flush/sec → trivially manageable

---

## Constraints and guardrails

- **Follower graph is power-law distributed**: top 0.1% of accounts (celebrities) have follower counts 5000× the median. Design must handle them specially — not as edge cases.
- **Fan-out must be decoupled from post write latency**: post creation must ACK within 200 ms; fan-out can take seconds asynchronously via Kafka.
- **Eventual consistency is acceptable for counters and timelines**: exact like counts and real-time feed updates are not required. Freshness SLO (30 s) is achievable without strong consistency.
- **Privacy must be enforced at both write time and read time**: single-layer check is insufficient given cache staleness and race conditions on block/follow events.
- **Ranking must be a soft dependency**: if the ranking service is unavailable, feed falls back to reverse-chronological — never an empty feed.
- **Media (images/video) is CDN-fronted**: the feed API returns metadata and media URLs only; media delivery is a separate system.
- **Multi-region active-active**: each region runs a full stack; writes go to the local region; cross-region replication is async (15–30 s lag); conflict resolution is last-write-wins.

---

## Success measures

| Metric | Target |
|---|---|
| Feed load latency (p50 / p95 / p99) | < 50 ms / < 200 ms / < 400 ms |
| Post publish → feed visible (p95) | < 30 s |
| Fan-out success rate | > 99.9% |
| Cache hit rate (feed timelines) | > 90% |
| Ranking latency (p95) | < 25 ms |
| Privacy error rate | < 0.001% |
| Feed availability | > 99.95% |

---

## Out of scope (Phase 1)

- End-to-end message encryption (DMs are a separate service)
- Full-text search and trending topics (separate Search Service)
- Creator monetization and ad serving (separate Ad Platform)
- Stories / ephemeral content (separate Stories Service)
- Full multi-region active-active with zero-latency conflict resolution (Spanner-based coordination)
- ML model training infrastructure (use pre-trained GBDT model served via ONNX Runtime)
- Real-time collaborative content editing
