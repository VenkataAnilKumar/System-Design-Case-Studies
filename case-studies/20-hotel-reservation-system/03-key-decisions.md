# 3) Key Design Decisions & Trade-Offs

## 1. Pessimistic vs. Optimistic Locking

**Decision**: Pessimistic (SELECT FOR UPDATE) for last room inventory.

**Rationale**: Strong consistency; prevents double booking; acceptable contention at scale.

**Trade-off**: Locks held during checkout (~2 min); can block other users.

**When to reconsider**: If contention is high (>10% lock failures); use optimistic (CAS with retries).

---

## 2. Payment Auth vs. Capture Timing

**Decision**: Auth on booking; capture at check-in or post-stay.

**Rationale**: Aligns with hotel policy; reduces fraud (cancel if no-show); better CX.

**Trade-off**: Auth holds expire after 7 days; need to extend or re-auth.

**When to reconsider**: If cancellation rate is low; capture immediately to reduce auth management.

---

## 3. Search Index: Real-Time vs. Cached Availability

**Decision**: Cache availability in Elasticsearch (1-min TTL); fetch real-time on booking.

**Rationale**: Fast search without hitting Inventory DB; eventual consistency OK for browsing.

**Trade-off**: User may see unavailable room in search; corrected on booking attempt.

**When to reconsider**: If false positives hurt conversion; reduce cache TTL to 10s.

---

## 4. Inventory Storage: SQL vs. NoSQL

**Decision**: PostgreSQL with row-level locks.

**Rationale**: ACID transactions; strong consistency; well-understood locking semantics.

**Trade-off**: Vertical scaling limits; need partitioning by property_id for large scale.

**When to reconsider**: If >10M properties; shard by geography or use distributed DB (CockroachDB).

---

## 5. Booking TTL: Fixed vs. Adaptive

**Decision**: Fixed 10-min TTL for inventory hold.

**Rationale**: Simple; industry standard; balances user UX with inventory churn.

**Trade-off**: Power users may need more time; short TTL can frustrate.

**When to reconsider**: If checkout abandonment is high; offer extension option (click to extend 5 min).

---

## 6. Cancellation: Sync vs. Async Refund

**Decision**: Async refund processing (5-7 days).

**Rationale**: PSP constraint; immediate UX (confirmation); backend handles delay.

**Trade-off**: User waits for refund; need clear communication.

**When to reconsider**: If offering instant refunds as credits (Wallet balance); use for loyalty.

---

## 7. Reviews: Immediately Visible vs. Moderated

**Decision**: Moderated (approve within 24h).

**Rationale**: Prevents spam, fake reviews; maintains quality.

**Trade-off**: Delayed visibility; moderation cost.

**When to reconsider**: If trust is high; allow immediate with retroactive takedown.
