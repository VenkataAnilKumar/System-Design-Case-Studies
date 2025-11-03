# 3) Key Decisions (Trade-offs)

## 1) Fanout: Write vs Read vs Hybrid
- Write fanout (push): Precompute home timelines → fast reads; costly for high-follower authors
- Read fanout (pull): Compute on demand → consistent cost per reader; higher read latency
- Choice: Hybrid (push for normal authors; pull for celebrities)

## 2) Storage for Timelines
- Redis lists for hot pages; NoSQL (Cassandra/Scylla) for durable, large, append-only sequences
- Why: High write throughput, wide rows by user_id + time buckets, predictable scans

## 3) Ranking vs Pure Recency
- Ranking improves engagement but adds latency and complexity
- Choice: Rank top K (e.g., 50) with cached features; degrade to recency on failures/timeouts

## 4) Counters Consistency
- Eventual: cache increments, batch flush; exact on demand with read-through
- When to use strong: financial/critical metrics only; feed counters can be eventual

## 5) Graph & Privacy Checks
- Cache follows/blocks (Bloom filters + key sets); enforce visibility both at write and read
- Safety: content moderation pipeline on publish; quarantine bad items

## 6) Multi-Region Strategy
- Pin user to home region for writes; replicate timelines asynchronously
- Cross-region reads allowed with increased latency; warm caches by region

## 7) Backfill & Rebuild
- Rebuild home timelines after ranking model changes: background jobs with throttling
- Keep last N days in Redis; older pages read-through from NoSQL
