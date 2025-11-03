# Ad Serving Platform

## Problem Statement

Design a **Google AdWords-like ad serving platform** that selects and delivers relevant ads in real-time with sub-100ms latency and high click-through rates.

**Core Challenge**: Handle 1M ad requests/sec, run real-time auction (Vickrey), and serve ads with <100ms p99 latency while maximizing revenue (CTR × bid price).

**Key Requirements**:
- Real-time ad auction (second-price/Vickrey)
- Targeting (user demographics, interests, context)
- Frequency capping (max 3 impressions per user per day)
- Click/impression tracking and attribution
- Budget pacing (spend $1000/day evenly)
- Fraud detection (bot traffic, click fraud)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M req/sec, <100ms latency, real-time auction) |
| [02-architecture.md](./02-architecture.md) | Components (Ad Server, Auction Engine, Targeting, Budget Service) |
| [03-key-decisions.md](./03-key-decisions.md) | Auction algorithms, targeting optimization, budget pacing |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to billions of impressions, failure scenarios, fraud detection |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Ad Serving Latency** | p99 <100ms (request → ad rendered) |
| **Auction Throughput** | 1M auctions/sec |
| **CTR** | >2% (click-through rate) |
| **Availability** | 99.95% |

## Technology Stack

- **Ad Server**: In-memory ad cache, low-latency serving
- **Auction Engine**: Vickrey (second-price) auction algorithm
- **Targeting**: ML models for CTR prediction (logistic regression, neural nets)
- **Budget Service**: Redis for real-time budget tracking
- **Analytics**: Kafka → ClickHouse for impression/click tracking

## Interview Focus Areas

1. **Auction Algorithm**: Second-price (Vickrey) vs first-price
2. **Targeting**: User profiling (demographics, interests, browsing history)
3. **Budget Pacing**: Smooth spending over 24 hours (avoid spending all in 1 hour)
4. **Frequency Capping**: Track impression counts per user (bloom filter)
5. **Fraud Detection**: Bot detection (IP patterns, click timing)
