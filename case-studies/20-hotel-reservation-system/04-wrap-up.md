# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 100K bookings/day**
- Single PostgreSQL; Elasticsearch single node; basic search/book
- Payment via Stripe; email notifications

**100K → 1M bookings/day**
- Shard inventory DB by property_id; read replicas for search
- Elasticsearch cluster (10 nodes); regional deployments
- Redis for inventory cache (1-min TTL); lock manager (Redlock)
- Payment orchestration with retry logic; fraud scoring

**1M → 10M bookings/day**
- Multi-region active-active (geo-routed); eventual consistency for reviews/ratings
- Distributed inventory locks (etcd/Consul); partition by region
- Advanced fraud detection (ML models); chargebacks handling
- A/B testing on checkout flow; conversion optimization

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Inventory DB outage | Cannot book | Write errors; timeout | Read-only mode; queue bookings; process when DB recovers |
| Search index stale | Wrong availability shown | Cache age > 5 min | Reindex; reduce TTL; fallback to DB for booking |
| Payment PSP down | Bookings fail | PSP API errors | Failover to secondary PSP; queue for retry |
| Lock timeout (user slow) | Inventory held unnecessarily | Booking TTL expired | Auto-release; notify user; allow restart |
| Double booking (race) | Customer dispute | Two confirmed bookings same room/date | Refund + upgrade; compensate; investigate lock failure |

---

## SLOs

- Search p95 < 500ms; booking p95 < 2s
- Zero double bookings (validated daily via reconciliation)
- Payment auth success > 98%; capture within 24h of check-in
- Booking confirmation delivery < 10s

---

## Common Pitfalls

1. No idempotency on bookings → duplicate charges on network retry
2. Weak locks → double booking; use strong consistency (SELECT FOR UPDATE or CAS with version)
3. Ignoring time zones → wrong check-in/out times; normalize to UTC, display local
4. No TTL on locks → inventory starved; enforce automatic release
5. Stale search results → user frustration; balance cache TTL with consistency needs

---

## Interview Talking Points

- Pessimistic vs. optimistic locking for inventory (last room problem)
- Idempotency strategies for payment and booking APIs
- Search vs. booking consistency models (eventual vs. strong)
- Payment auth/capture workflows and PSP failover
- Time zone handling and inventory calendar representation

---

## Follow-Up Questions

- How to support dynamic pricing (surge during high demand)?
- How to handle overbooking (common in airlines/hotels)?
- How to implement loyalty programs and points redemption?
- How to support multi-room bookings (group reservations)?
- How to integrate with channel managers (Expedia, Booking.com)?