# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Candidate Generation: Retrieve relevant items from 10M catalog; collaborative filtering, content-based
- Ranking: Score and re-rank candidates; personalization; business rules (diversity, freshness)
- Real-Time Signals: Incorporate clicks, views, purchases within seconds
- A/B Testing: Multiple model versions; traffic splitting; metrics tracking
- Exploration vs. Exploitation: Balance popular items with discovery
- Offline Training: Batch feature engineering; model training (daily/weekly)
- Feature Store: Precompute user/item features; low-latency lookup
- Explainability: "Because you watched X" reasoning

## Non-Functional Requirements

- Latency: p95 < 200ms end-to-end (candidate generation + ranking)
- Throughput: 50K recs/sec
- Freshness: Real-time signals reflected within 10s
- Coverage: >90% of items recommended at least once per week
- Diversity: No more than 30% from single category in top 10
- Cost: Optimize inference; cache popular user embeddings

## Scale Estimate

- Users: 100M; 10M DAU
- Items: 10M; new items 10K/day
- Interactions: 1B clicks/day; 100M purchases/day
- Features: 1K dimensions per user/item; 100M × 1K × 4B = 400GB embeddings

## Constraints

- Cold start: New users/items lack interaction history
- Data skew: Power users generate 80% of interactions
- Privacy: GDPR requires explainability and opt-out

## Success Measures

- CTR (click-through rate) > 5%; conversion rate > 2%
- Engagement: Session duration +10%; repeat visits +15%
- Offline metrics: Precision@10, Recall@10, NDCG > 0.7