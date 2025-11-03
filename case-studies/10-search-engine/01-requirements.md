# 1) Functional & Non-Functional Requirements

## Functional Requirements

### Core Search
- Web crawling: Discover pages via seed URLs; follow links; respect robots.txt; politeness delay (1 req/sec per domain)
- Indexing: Parse HTML; extract text, title, meta tags, links; build inverted index (term → doc IDs)
- Query processing: Parse query; tokenize; spell-check; autocomplete; expand (synonyms)
- Ranking: TF-IDF, PageRank, freshness, domain authority; machine-learned ranking (LambdaMART)
- Results: Top 10 results per page; snippet (highlight query terms); title, URL, cached link

### Advanced Features
- Autocomplete: Suggest queries as user types (based on popularity, personalization)
- Spell correction: "pythom" → "Did you mean: python?"
- Image/video search: Separate index; metadata (alt text, caption); visual similarity (embeddings)
- Safe search: Filter adult content; toggle on/off
- Personalization: Boost results based on user history (location, past clicks)
- Freshness: Prioritize recent pages for news queries; recrawl frequently

### Admin/Operations
- Index sharding: Partition by term or document; horizontal scale
- Cache: Popular queries cached (Redis); TTL 5 min
- Monitoring: Query latency, index size, crawl rate, relevance metrics (CTR, dwell time)

## Non-Functional Requirements

- **Latency**: p95 < 500ms (user types query → results displayed); p50 < 200ms
- **Throughput**: 100K queries/sec peak; 50K avg
- **Index Size**: 10B web pages × 1KB avg = 10TB compressed (100TB uncompressed)
- **Crawl Rate**: 1B pages/day (~11K pages/sec); refresh popular pages daily, others weekly
- **Availability**: 99.9% uptime (43 min downtime/month)
- **Relevance**: Top-10 CTR >80% (users click at least one result); top-1 CTR >40%
- **Freshness**: News articles indexed within 1 min; regular pages within 1 day

## Scale Estimate

- **Indexed Pages**: 10B pages (subset of 50B+ total web pages)
- **Index Storage**: 10B pages × 1KB avg metadata + 10KB inverted index entry = 110TB (compressed to ~10TB)
- **Queries**: 100K/sec peak × 86400 sec/day = 8.6B queries/day
- **Crawl**: 1B pages/day; avg page size 100KB = 100PB/day raw (dedupe + compress to 10TB/day stored)
- **Cache**: 1M unique queries/day (Zipf distribution; top 10K account for 50% of traffic); 1M × 10KB = 10GB cache

## Constraints

- **Robots.txt**: Must respect (crawl delay, disallow paths); penalty: legal action, IP ban
- **Politeness**: Max 1 req/sec per domain; avoid DDoS accusations
- **Copyright**: Cannot store full page text (fair use); only snippets + link
- **GDPR**: Right to be forgotten (remove URLs from index upon request)
- **Spam**: Detect SEO spam (keyword stuffing, cloaking, link farms); penalize in ranking

## Success Measures

- **Relevance**: Top-10 CTR >80%; dwell time >30 sec (user reads result page)
- **Latency**: p95 query latency <500ms
- **Index Coverage**: >90% of popular sites indexed (Alexa top 1M)
- **Freshness**: News indexed <1 min; regular pages <24 hr
- **Spam Detection**: <1% spam in top 10 results
