# Search Engine

## Problem Statement

Design a **Google-like search engine** that indexes billions of web pages and returns relevant results in milliseconds.

**Core Challenge**: Index 10B web pages (1PB raw HTML) and serve 100K queries/sec with <200ms p99 query latency while maintaining high relevance (click-through rate >60%).

**Key Requirements**:
- Web crawling (respect robots.txt, politeness)
- Document indexing (inverted index, term frequency)
- Query processing (ranking, relevance scoring)
- Autocomplete and spell correction
- Personalized results (user history, location)
- Paid search ads integration

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10B pages, 100K QPS, <200ms latency, 60% CTR) |
| [02-architecture.md](./02-architecture.md) | Components (Crawler, Indexer, Query Service, Ranking Engine) |
| [03-key-decisions.md](./03-key-decisions.md) | Inverted index design, PageRank, query optimization |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to web-scale, failure scenarios, ranking improvements |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Query Latency** | p99 <200ms |
| **Crawl Rate** | 1M pages/sec |
| **Index Size** | 10B pages, 500TB compressed |
| **Relevance** | >60% click-through rate on top result |

## Technology Stack

- **Crawler**: Distributed crawler (1000 nodes), politeness (1 req/sec per domain)
- **Indexer**: MapReduce for inverted index generation
- **Storage**: Distributed file system (HDFS/GFS) for index shards
- **Query Service**: Query fanout to 100s of index servers
- **Ranking**: PageRank + ML models (relevance, personalization)

## Interview Focus Areas

1. **Inverted Index**: Term → list of doc IDs with positions
2. **PageRank**: Graph algorithm for page authority
3. **Query Optimization**: Query rewrite, synonym expansion
4. **Index Sharding**: Partition index by term or document
5. **Ranking**: Relevance scoring (TF-IDF, BM25), personalization
