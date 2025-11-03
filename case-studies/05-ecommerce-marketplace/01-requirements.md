# 1) Requirements & Scale

## Functional Requirements

- Catalog: Browse products, filter/sort, view details, images, reviews
- Search: Full-text + faceted (brand, price range, rating)
- Cart: Add/remove/update items; save for later; view subtotal/taxes/shipping
- Checkout: Validate items, calculate shipping/taxes, apply discounts/coupons
- Inventory: Reserve stock on checkout start; release on timeout/cancel; decrement on payment capture
- Payments: Authorize at checkout; capture on shipment (or immediate for digital)
- Orders: State machine (created → confirmed → shipped → delivered → canceled/refunded)
- Idempotency: Retries must not double-charge or double-reserve

## Non-Functional Requirements

- Low latency: Checkout API p95 < 200ms (excluding external PSP round-trips)
- High availability: 99.95%+, degraded modes during PSP or tax provider incidents
- Consistency: Prevent oversell under contention; exactly-once-ish payments
- Observability: Per-merchant SLIs; payment auth success rate; reserve→capture conversion

## Scale & Back-of-the-Envelope

- Checkouts: 200–500K/min during peak (flash sale); ~3–8K RPS sustained
- Inventory SKUs: 10^5–10^7 per marketplace; hot SKUs during launches
- Payment providers: Multiple PSPs; average 300–800ms external latency

## Constraints & Assumptions

- Tokenized cards via PSP; no PAN storage
- Inventory reservations TTL ~10–15 min
- Mixed carts (multiple warehouses) split into shipments
- Strong write path for decrement/oversell prevention; reads can be cached

## Success Measures

- Authorization success rate; capture success rate
- Oversell rate (target ≈ 0)
- Checkout p95 latency; external dependency contribution
- Reserve→capture conversion (% of reservations that complete)
