# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Shard inventory by SKU_id; shard orders by user_id or region
- Redis for hot inventory reads; SQL for durable ledger
- Horizontal checkout workers; queue for backpressure
- Multi-PSP strategy (primary + fallback); circuit breakers

## Failure Scenarios
1) PSP Timeout
- Impact: Checkouts fail; cart abandonment
- Mitigation: Fallback PSP; retry with exponential backoff; manual reconciliation queue

2) Inventory Reservation Leak
- Impact: Stock locked but no order; under-utilization
- Mitigation: TTL cleanup worker; monitoring for high reservation-to-order gap

3) Flash Sale Overload
- Impact: Checkout latency spikes; timeouts
- Mitigation: Pre-warm caches; rate-limit; queue system; failover to "notify me"

4) Double-Charge on Retry
- Impact: Customer charged twice
- Mitigation: Idempotency keys; PSP deduplication; refund automation

## SLOs & Metrics
- Checkout p95 < 200ms; payment auth success > 98%; oversell rate < 0.01%
- Reservation→capture conversion > 70%; TTL expiry < 20%
- Order FSM errors < 0.1%

## Pitfalls
- Race conditions on inventory decrement; use atomic SQL (WHERE stock >= qty)
- Stale pricing in cart; validate at checkout
- Tax/shipping calc failures block checkout; fallback to estimates
- Refund complexity; saga rollback must be idempotent

## Interview Talking Points
- Inventory reservation flow; TTL and cleanup
- Saga pattern for distributed transactions
- Idempotency in payments
- Flash sale throttling strategies

## Follow-up Q&A
- Q: How prevent bots buying all stock?
  - A: CAPTCHA; rate limits; device fingerprinting; waitlist/lottery
- Q: Multi-currency support?
  - A: Store prices in base currency; convert at checkout with cached FX rates
- Q: Fraud detection?
  - A: ML models (velocity checks, device signals); manual review for high-risk
- Q: Refund automation?
  - A: Reverse payment capture; release inventory; update order state; notify user

---

This e-commerce design prioritizes consistency (no oversell) and idempotency (no double-charge) via pessimistic inventory locking, saga-based orchestration, and PSP integration with fallback strategies.
