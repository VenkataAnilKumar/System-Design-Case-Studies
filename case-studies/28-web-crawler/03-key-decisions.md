# Key Technical Decisions

## 1. BFS vs. DFS Crawling
**Decision**: **BFS** (breadth-first search) for balanced coverage.
**Rationale**: BFS discovers important pages early (home page → category pages → product pages). DFS risks getting trapped in deep subsections.
**Reconsider**: For focused crawling (specific topic), use DFS with topical scoring.

## 2. URL Frontier: Centralized Queue vs. Sharded by Domain
**Decision**: **Sharded by domain** for politeness enforcement.
**Rationale**: Each shard handles one domain → easy to rate-limit (1 req/sec). Centralized queue can't enforce per-domain limits.
**Reconsider**: For small-scale (<1K domains), centralized queue is simpler.

## 3. Deduplication: Exact Hash vs. Near-Duplicate Detection
**Decision**: **Exact hash** (MD5) + **Simhash** for near-duplicates.
**Rationale**: Exact hash catches 70% duplicates (mirrors, reprints). Simhash catches 20% near-duplicates (minor edits).
**Reconsider**: For strict deduplication (news aggregators), exact hash only is faster.

## 4. Robots.txt: Cache vs. Fetch Every Time
**Decision**: **Cache with 24h TTL** (Redis).
**Rationale**: Avoid fetching robots.txt on every request (overhead). 24h is standard refresh interval.
**Reconsider**: For aggressive crawlers, fetch every time to ensure compliance (accept latency).

## 5. Politeness: Per-Domain vs. Per-IP
**Decision**: **Per-domain** rate limiting.
**Rationale**: Multiple domains on same IP (shared hosting) shouldn't block each other. Per-domain is fairer.
**Reconsider**: For IP-based rate limiting (prevent DDoS), use per-IP limits.

## 6. Recrawl Strategy: Fixed Interval vs. Adaptive
**Decision**: **Adaptive** based on change frequency.
**Rationale**: News sites change hourly (recrawl daily), static sites change yearly (recrawl monthly). Adaptive saves bandwidth.
**Reconsider**: For simple implementation, use fixed 30-day interval for all pages.

## 7. Content Storage: Raw HTML vs. Parsed Text
**Decision**: **Raw HTML** for flexibility.
**Rationale**: Store original HTML → can re-parse later with improved extractors. Parsed text loses structure.
**Reconsider**: For storage cost reduction, store parsed text only (lose re-parsing ability).

## 8. Distributed Crawling: Centralized Coordinator vs. Peer-to-Peer
**Decision**: **Centralized coordinator** (frontier service).
**Rationale**: Easier to enforce global policies (politeness, deduplication). P2P is complex (coordination overhead).
**Reconsider**: For massive scale (10M workers), use P2P (no single bottleneck).
