# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 10M pages (~1K queries/sec)**
- Single crawler instance; SQLite frontier
- Single Elasticsearch node (1TB index)
- PostgreSQL for doc metadata
- No PageRank (simple TF-IDF ranking)
- In-memory autocomplete (10K queries)

**10M → 1B pages (~10K queries/sec)**
- Distributed crawlers (10 instances); Kafka frontier (6 partitions)
- Elasticsearch cluster (10 nodes; 10TB index; 3 replicas)
- Cassandra for doc metadata (3 nodes)
- PageRank: Weekly batch job (Spark on 100 workers)
- Redis cache (10GB; top 100K queries)

**1B → 10B pages (~100K queries/sec)**
- 100 crawler instances; Kafka (20 brokers, 100 partitions)
- Elasticsearch: 100 nodes; 100TB index; shard by term
- PageRank: Daily batch job (1000 workers; 4 hours runtime)
- ML ranking: LambdaMART model; TensorFlow Serving (50 instances)
- Autocomplete: Pre-built trie; updated hourly from logs
- Multi-region: US, EU, Asia (route by GeoDNS; replicate index)

**Beyond 10B (Google scale)**
- Custom inverted index (Bigtable-like; columnar; compression)
- Distributed PageRank: Incremental updates (Pregel/Giraph)
- Neural ranking: BERT embeddings; vector similarity search (FAISS)
- Real-time indexing: Streaming pipeline (Kafka → Flink → index in <1 min)
- Mobile-first: Separate index for mobile pages (prioritize AMP, fast-loading sites)

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Crawler Crash | Some pages not crawled; frontier stalled | Health check timeout (30s) | Kafka retains frontier; other crawlers continue; crashed crawler restarts and resumes |
| Elasticsearch Node Down | Search queries slow; some shards unavailable | Cluster status yellow/red | Replicas serve queries; promote replica to primary; rebalance shards |
| PageRank Job Fails | Ranking uses stale scores (1 day old) | Job completion timeout (6 hr) | Retry job; if persistent, use previous day's PageRank; manual investigation |
| Cache (Redis) Outage | All queries hit backend; latency spikes | Redis connection timeout | Serve from Elasticsearch (slower); scale up query workers; rebuild cache from logs |
| Indexing Lag (>1 hr) | New pages not searchable; users complain | Kafka consumer lag > 10K msgs | Scale indexing workers (add 50 instances); temporarily skip less critical tasks (e.g., language detection) |
| Spam Attack (SEO spam flood) | Low-quality results in top 10 | Manual audits; user feedback (spam reports) | Penalize spammy domains (blacklist); retrain ML model with new spam examples |

---

## SLOs (Service Level Objectives)

- **Query Latency**: p95 < 500ms; p50 < 200ms
- **Availability**: 99.9% uptime (43 min downtime/month)
- **Relevance**: Top-10 CTR >80%; top-1 CTR >40%
- **Index Freshness**: News indexed <1 min; regular pages <24 hr
- **Crawl Coverage**: >90% of Alexa top 1M sites indexed
- **Spam Rate**: <1% spam in top 10 results

---

## Common Pitfalls

1. **Ignoring robots.txt**: Legal issues; IP banned by sites; symptom: 403 errors; solution: Fetch and parse robots.txt before every domain crawl
2. **No politeness delay**: DDoS accusations; IP blacklisted; symptom: Crawler blocked; solution: Rate-limit 1 req/sec per domain (distributed limiter in Redis)
3. **Crawl traps (infinite URLs)**: Crawler stuck in calendar links (`/2025/01/01`, `/2025/01/02`, ...); symptom: Frontier grows unbounded; solution: URL pattern detection (skip URLs with >5 date components)
4. **Stale cache**: User sees old results; symptom: New pages not appearing; solution: Short TTL (5 min) or invalidate cache on index updates (complex)
5. **No deduplication**: Index bloated with mirrors; symptom: 3x storage cost; solution: SimHash near-duplicate detection (95% threshold)

---

## Interview Talking Points

- **Crawling politeness**: Why rate-limit? Respect server resources; avoid legal issues (terms of service violations); build good reputation (sites more likely to allow crawling)
- **Inverted index structure**: What's stored? `{term: [{doc_id, positions[], tf_idf}]}`; why positions? Phrase queries ("machine learning" must be adjacent)
- **PageRank intuition**: Random surfer model (follow links with 85% probability, jump to random page 15%); iterative algorithm (converges in ~10 rounds); popularity metric (linked by many pages = higher rank)
- **TF-IDF formula**: `TF = term_count / total_terms`; `IDF = log(total_docs / docs_with_term)`; intuition: Frequent in doc but rare across corpus = high relevance
- **ML ranking features**: TF-IDF, PageRank, domain authority, freshness, URL depth, click-through rate (CTR), dwell time, bounce rate; label: human raters score query-doc relevance (0-4)
- **Scaling challenge**: Inverted index grows linearly with corpus size; query latency grows logarithmically (with sharding); bottleneck: popular terms (e.g., "the"); solution: Remove stop words, replicate hot shards

---

## Follow-Up Questions to Explore

- How would you add image search? (OCR for text in images; alt text; visual embeddings (ResNet); reverse image search via feature matching)
- How to detect SEO spam? (Keyword stuffing: term frequency too high; cloaking: show different content to crawler vs. user; link farms: many low-quality inbound links; solution: Penalize in ranking)
- How to handle multiple languages? (Detect language (langdetect); separate index per language; translate query if mismatch (Google Translate API))
- How would you add personalized search? (User profile: location, past clicks, search history; boost results matching profile; privacy concern: store profile encrypted)
- How to implement "I'm Feeling Lucky" (return top result directly)? (Cache top result per popular query; higher risk if ranking is wrong; requires very high precision)
- How to scale crawling to 1 trillion pages? (Prioritize: Crawl high-PageRank pages first; recrawl schedule: News hourly, blogs daily, archives yearly; distributed: 10K crawlers; each handles 100M pages/day)
