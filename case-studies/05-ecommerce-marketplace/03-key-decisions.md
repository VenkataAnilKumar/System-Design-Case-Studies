# 3) Key Decisions (Trade-offs)

## 1) Inventory Model: Pessimistic vs Optimistic Locking
- Pessimistic: Reserve upfront; prevent oversell but locks stock for non-converting users
- Optimistic: Oversell risk; notify user "out of stock" at payment
- Choice: Pessimistic with short TTL (10–15 min); balance conversion vs availability

## 2) Payment: Auth vs Capture Timing
- Auth+Capture immediate: Simpler; funds held longer; higher refund rate
- Auth at checkout, capture on shipment: Better UX; reduces refunds for cancellations
- Choice: Auth+hold; capture on shipment (standard for physical goods)

## 3) Saga vs 2PC for Distributed Transactions
- 2PC: Strong consistency; blocking; coordinator SPOF
- Saga: Eventual consistency; compensating transactions; more complex
- Choice: Saga (reserve→auth→order→capture with rollback steps)

## 4) Search: SQL vs Elasticsearch
- SQL: Structured queries; slow full-text; limited faceting
- Elasticsearch: Fast full-text; rich facets; eventual consistency
- Choice: Elasticsearch for search; SQL for transactional catalog updates

## 5) Flash Sale Handling
- Queue users; throttle checkout; pre-warm inventory cache
- Lottery/waitlist for high-demand SKUs
- Choice: Rate-limit + queue; fallback to "notify when available"

## 6) Multi-Region Strategy
- Inventory per region; cross-region fallback on stockouts
- Orders pinned to user's region; replicate async
- Choice: Regional isolation; global catalog with regional stock

## 7) Tax Calculation
- Real-time (Avalara/TaxJar API): Accurate but adds latency
- Pre-cached by zip: Fast but stale; periodic refresh
- Choice: Hybrid; cache common zips; real-time for edge cases
