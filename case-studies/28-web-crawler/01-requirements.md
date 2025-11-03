# Requirements & Scale

## Functional Requirements
1. **URL Discovery**: Start with seed URLs, extract links from crawled pages, prioritize frontier
2. **Fetch & Parse**: Download HTML, extract text/links, detect content type (HTML/PDF/image)
3. **Robots.txt Compliance**: Respect /robots.txt (disallowed paths, crawl-delay directive)
4. **Politeness**: Limit requests per domain (default 1 req/sec, configurable per robots.txt)
5. **Deduplication**: Detect duplicate content (exact, near-duplicate) via content hashing
6. **Recrawl Scheduling**: Prioritize frequently-changing pages (news: daily, blogs: weekly, static: monthly)
7. **Distributed Crawling**: Partition URLs across workers by domain (avoid parallel requests to same domain)

## Non-Functional Requirements
**Throughput**: 1M pages/sec globally (100K domains × 10 req/sec avg)
**Storage**: 10B pages × 100KB avg = 1PB raw HTML + metadata
**Latency**: Process each page within 10s (fetch + parse + store)
**Availability**: 99.9% uptime (crawlers can tolerate downtime, batch system)

## Scale Estimates
**Pages**: 10B pages, 30-day recrawl → 10B / 30 / 86400 = 3.8K pages/sec sustained, 1M pages/sec peak
**Domains**: 100K domains, politeness 1 req/sec → max 100K req/sec (1 per domain)
**HTML Size**: 100KB avg page → 10B pages = 1PB storage
**Links**: 50 outbound links/page avg → 500B links total (graph structure)

**Infrastructure**:
- Crawlers: 1000 worker nodes (1K pages/sec each)
- URL Frontier: Distributed queue (Kafka/RabbitMQ) with 1B URLs queued
- Deduplication DB: Bloom filter + content hash (MD5/SHA256) for 10B pages
- Storage: S3/HDFS for raw HTML (1PB)

**Cost**: $500K/mo (compute) + $50K (storage) + $100K (network bandwidth) = **$650K/mo**
