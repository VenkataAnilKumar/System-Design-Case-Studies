# Social Media News Feed

## Problem Statement

Design a **Facebook/Twitter-like news feed** that delivers personalized content to millions of users with low latency and real-time updates.

**Core Challenge**: Generate personalized feeds for 1B users with 100M posts/day while maintaining p99 <300ms feed generation and handling 10M concurrent users.

**Key Requirements**:
- Personalized feed ranking (friends, pages, relevance score)
- Real-time post creation and propagation
- Engagement actions (like, comment, share)
- Fan-out to followers (1-10M followers per celebrity)
- Media-rich posts (images, videos, links)
- Infinite scroll with pagination

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1B users, 100M posts/day, 10M concurrent) |
| [02-architecture.md](./02-architecture.md) | Components (Feed Service, Ranking Engine, Fan-out Service, Timeline Cache) |
| [03-key-decisions.md](./03-key-decisions.md) | Push vs pull feed, ranking algorithms, fan-out strategies |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling patterns, failure scenarios, cache strategies, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Feed Latency** | p99 <300ms |
| **Post Fan-out** | <1s for 10K followers, async for >100K |
| **Cache Hit Rate** | >90% for hot feeds |
| **Availability** | 99.95% |

## Technology Stack

- **Feed Generation**: Redis cache + PostgreSQL/Cassandra for timeline
- **Ranking**: ML models (EdgeRank-like) for personalized sorting
- **Fan-out**: Kafka for async propagation to followers
- **Storage**: Cassandra for posts, Redis for hot timelines
- **CDN**: Media delivery (images, videos)

## Interview Focus Areas

1. **Push vs Pull**: Hybrid approach (push for small followers, pull for celebrities)
2. **Ranking Algorithm**: Recency, engagement score, friendship strength
3. **Fan-out Strategies**: Async queue for celebrities (1M+ followers)
4. **Cache Invalidation**: TTL vs event-driven invalidation
5. **Hot Spot Mitigation**: Celebrity posts causing thundering herd
