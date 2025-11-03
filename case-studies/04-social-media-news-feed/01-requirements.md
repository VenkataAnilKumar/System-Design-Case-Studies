# 1) Requirements & Scale

## Functional Requirements

- Post: Users create posts (text, image/video pointers), visibility (public/friends/followers)
- Feed: Personalized home feed (friends/followees + ranking); reverse-chron backup
- Actions: Like, comment, share/retweet, save; counters eventually consistent
- Privacy: Respect blocks, private accounts, circles/lists
- Notifications: New posts from close friends; mentions; engagement alerts
- Search/Explore: Optional—trending, topics, hashtag discovery

## Non-Functional Requirements

- Low latency: Feed fetch p95 < 200ms from cache; cold miss < 500ms
- High availability: 99.95%+
- Freshness: New post appears in followers' feeds within seconds
- Cost: Optimize storage (cold/archive) and cache hit ratios
- Observability: Per-tenant (region) feed SLOs; ranking latency budgets

## Scale & Back-of-the-Envelope

- Users: 200M MAU; 50M DAU
- Writes: 10–50K posts/sec peak; engagements 10× posts
- Reads: 1–5M feed reads/sec global
- Fanout: Median followers/user ~200; heavy-tailed (celebrities 1M+)

Rough storage:
- Post metadata (SQL/NoSQL): 10^11 posts over years; 200–500B each core
- Media in object storage (CDN fronted)
- Feed timelines: precomputed lists (Redis/Memcache + persistent store)

## Constraints & Assumptions

- Follower graph is sparse and skewed (power-law)
- Celebrity fanout handled differently ("live fanout"/pull-based)
- Counters (likes) are eventually consistent; exact counts on demand via read-through
- Ranking model can run online with cached features; heavy features offline

## Success Measures

- Feed p95 latency; freshness lag (publication→visible)
- Cache hit rate; backend read QPS reductions
- Engagement uplift (CTR, dwell time) with ranking on vs baseline
- Error rate and stale/incorrect visibility incidents
