# Web Crawler

## Problem Statement

Design a **Googlebot-like web crawler** that discovers, fetches, and indexes billions of web pages while respecting robots.txt and politeness policies.

**Core Challenge**: Crawl 10B pages on a 30-day cycle (3.8K pages/sec sustained, 1M pages/sec peak) while respecting 1 req/sec per domain politeness and deduplicating content.

**Key Requirements**:
- URL discovery and frontier management
- Fetch and parse HTML (extract text and links)
- Robots.txt compliance (respect disallowed paths, crawl-delay)
- Politeness (1 req/sec per domain)
- Deduplication (exact and near-duplicate detection)
- Recrawl scheduling (prioritize frequently-changing pages)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10B pages, 3.8K/sec sustained, 1M/sec peak, politeness) |
| [02-architecture.md](./02-architecture.md) | Components (Crawler Workers, URL Frontier, Dedup Service, Storage) |
| [03-key-decisions.md](./03-key-decisions.md) | BFS vs DFS, deduplication (MD5, Simhash), robots.txt caching |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to web-scale, failure scenarios, spider traps |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Crawl Rate** | 3.8K pages/sec sustained, 1M peak |
| **Politeness** | 1 req/sec per domain (100% compliance) |
| **Deduplication** | 95% accuracy (exact + near-duplicate) |
| **Availability** | 99.9% (batch system, downtime acceptable) |

## Technology Stack

- **URL Frontier**: Distributed priority queue (Kafka), sharded by domain
- **Crawler Workers**: 1000 nodes, parallel fetching
- **Robots.txt Cache**: Redis (24h TTL per domain)
- **Deduplication**: MD5 hash (exact), Simhash (near-duplicate)
- **Storage**: S3/HDFS for raw HTML (1PB)

## Interview Focus Areas

1. **Politeness**: Shard frontier by domain, enforce 1 req/sec per shard
2. **BFS vs DFS**: BFS discovers important pages early (home → categories)
3. **Deduplication**: MD5 for exact (70%), Simhash for near-duplicate (20%)
4. **Robots.txt**: Cache with 24h TTL, fetch once per domain
5. **Spider Traps**: Infinite URL generation (dynamic pages with pagination)
