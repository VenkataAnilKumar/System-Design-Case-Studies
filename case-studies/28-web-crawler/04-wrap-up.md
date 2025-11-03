# Wrap-Up & Deep Dives

## Scaling Playbook
**Stage 1 (MVP)**: Single worker, 10K pages, BFS crawling, no deduplication.
**Stage 2 (Production)**: 100 workers, 100M pages, robots.txt cache, exact deduplication (MD5), politeness 1 req/sec.
**Stage 3 (Scale)**: 1000 workers, 10B pages, near-duplicate detection (Simhash), adaptive recrawl, distributed frontier (Kafka), geo-distributed (multi-region).

## Failure Scenarios
- **Worker Crash**: URL requeued after timeout (idempotent crawling).
- **Frontier Overload**: Rate-limit URL submissions, prioritize high-value domains.
- **Robots.txt Unavailable**: Assume conservative policy (crawl-delay 10s).

## SLO Commitments
- **Crawl Rate**: 1M pages/sec peak, 3.8K sustained (30-day recrawl cycle)
- **Politeness**: 100% compliance with robots.txt (0 violations)
- **Duplicate Detection**: 95% accuracy (exact + near-duplicate)
- **Freshness**: News sites recrawled within 24h, static sites within 30 days

## Common Pitfalls
1. **No Politeness**: Crawling too fast overwhelms servers → IP banned.
2. **Ignoring Robots.txt**: Legal risk (CFAA violations in some jurisdictions).
3. **Infinite Loops**: Dynamic URLs (example.com?page=1&page=2&...) → infinite crawl. Use URL normalization.
4. **Spider Traps**: Malicious sites with infinite links → set max depth (10 hops).
5. **No Deduplication**: Crawl same page 100× → wasted bandwidth.

## Interview Talking Points
- **Politeness**: "Shard frontier by domain → each shard enforces 1 req/sec rate limit → 100K domains = 100K req/sec max."
- **Robots.txt**: "Cache robots.txt rules (Redis, 24h TTL) → avoid fetching on every request (overhead)."
- **Deduplication**: "MD5 hash for exact duplicates (70%), Simhash for near-duplicates (20%) → 90% total duplicate detection."
- **BFS vs. DFS**: "BFS discovers important pages early (home → categories → products). DFS risks deep traps (page1 → page2 → page3 → ...)."

## Follow-Up Questions
1. **JavaScript Rendering**: Crawl single-page apps (React/Vue) that require JS execution (headless Chrome, Puppeteer)?
2. **Incremental Crawling**: Detect changed pages (ETag, Last-Modified headers) → skip unchanged pages?
3. **Focused Crawling**: Crawl only pages related to specific topic (ML classifier scores pages, prioritize high-scoring)?
4. **Deep Web**: Crawl pages behind login forms, CAPTCHA (human-in-the-loop)?
5. **Crawl Budget**: Allocate crawl budget per domain (Google crawls 100 pages/day for small sites, 10K for large)?

**Final Thought**: Web crawling balances **throughput** (crawl fast) with **politeness** (don't overwhelm servers). The key challenge is **frontier management**—prioritizing important pages (PageRank, freshness) while respecting rate limits (1 req/sec per domain). Deduplication (exact + near-duplicate) saves 30% bandwidth by avoiding redundant crawls.
