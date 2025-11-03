# 3) Key Design Decisions & Trade-Offs

## 1. Breadth-First vs. Depth-First Crawling

**Decision**: Breadth-first (BFS).

**Rationale**:
- Discover important pages early (linked from home pages)
- Avoids getting stuck in deep directory structures (e.g., /archive/2005/...)

**Trade-off**: Higher memory usage (frontier queue stores all level-N URLs before moving to N+1).

**When to reconsider**: If targeting deep web (academic papers, archived content); use priority queue (rank by estimated importance, not just breadth).

---

## 2. Term-Based vs. Document-Based Index Sharding

**Decision**: Term-based (shard by term hash).

**Rationale**:
- Query "python tutorial" → Only 2 shards queried (python shard + tutorial shard)
- Lower latency (parallel queries to 2 shards vs. fanning out to 100 doc shards)

**Trade-off**: Load imbalance (popular terms like "the" hit one shard heavily); mitigated by removing stop words, replicating hot shards.

**When to reconsider**: If queries are mostly multi-term (5+ words); doc-based sharding reduces per-query fan-out.

---

## 3. Synchronous vs. Async Indexing

**Decision**: Async (eventual consistency).

**Rationale**:
- Crawling and indexing decoupled; can replay indexing if algo changes
- Latency OK: 1-min delay for news, 1-day for regular pages

**Trade-off**: Search results lag behind real-time web (breaking news takes 1 min to appear).

**When to reconsider**: If real-time search required (e.g., Twitter search); use streaming indexing (Kafka → Flink → Elasticsearch).

---

## 4. ML Ranking vs. Hand-Tuned Scoring

**Decision**: Hybrid—ML model (LambdaMART) + hand-tuned signals (TF-IDF, PageRank).

**Rationale**:
- ML learns complex patterns (user behavior, seasonal trends)
- Hand-tuned signals are interpretable (explain why result ranked high)

**Trade-off**: ML model adds 50ms inference latency; training requires 1M+ labeled queries.

**When to reconsider**: If launching MVP; start with TF-IDF + PageRank only; add ML after collecting query logs.

---

## 5. Per-Query vs. Pre-Aggregated Autocomplete

**Decision**: Pre-aggregated (trie built from query logs daily).

**Rationale**:
- Low latency (trie lookup <1ms); no real-time computation
- Popular queries dominate (Zipf distribution); trie size <1GB

**Trade-off**: Autocomplete lags by 1 day (new trending queries not suggested immediately).

**When to reconsider**: If real-time trends critical (e.g., news events); rebuild trie every 5 min from recent logs.

---

## 6. Exact Deduplication vs. Near-Duplicate (SimHash)

**Decision**: Near-duplicate (SimHash with 95% threshold).

**Rationale**:
- Catches plagiarism, mirrors (same content, different URLs)
- Reduces index size by 30% (many pages are copies)

**Trade-off**: False positives (5% different content treated as duplicates); users may miss slightly different versions.

**When to reconsider**: If false positives are a problem (e.g., legal documents where every word matters); use exact deduplication (SHA-256 hash).

---

## 7. Centralized vs. Distributed PageRank

**Decision**: Distributed (MapReduce batch job, daily).

**Rationale**:
- Web graph too large for single machine (10B nodes, 100B edges)
- PageRank iterative (10 rounds); parallelize across 1000 workers

**Trade-off**: Slow update (daily batch); new pages have no PageRank for 24 hrs.

**When to reconsider**: If incremental PageRank needed (e.g., real-time news ranking); use approximate algorithms (local PageRank, vertex-centric updates).

---

## 8. Cache All Queries vs. Only Popular Queries

**Decision**: Only popular queries (top 10K = 50% traffic).

**Rationale**:
- Long-tail queries (millions of unique queries) have low hit rate (<1%)
- Caching 10K queries requires 100MB RAM; caching all queries = 10GB (expensive at scale)

**Trade-off**: Cache miss for 50% of queries (tail); they pay full latency cost.

**When to reconsider**: If latency SLA is strict; cache aggressively (top 1M queries); or pre-compute results (offline batch).
