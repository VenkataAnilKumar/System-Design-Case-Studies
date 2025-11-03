# E-commerce Marketplace

## Problem Statement

Design an **Amazon/eBay-like e-commerce platform** that handles product catalog, inventory management, checkout, and order processing at scale.

**Core Challenge**: Process 200-500K checkouts/minute during peak (flash sales) with <200ms p95 latency while preventing overselling through distributed inventory management.

**Key Requirements**:
- Product catalog with search and filtering (10M+ SKUs)
- Shopping cart with real-time pricing and inventory checks
- Checkout with inventory reservation (10-15 min TTL)
- Payment processing with multiple PSPs (idempotent)
- Order lifecycle management (created → confirmed → shipped → delivered)
- Prevent overselling under high contention

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (500K checkouts/min peak, 10M SKUs, multi-PSP) |
| [02-architecture.md](./02-architecture.md) | Components (Catalog Service, Cart, Checkout, Inventory, Order Service) |
| [03-key-decisions.md](./03-key-decisions.md) | Inventory reservation, payment idempotency, oversell prevention |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to Black Friday volumes, failure scenarios, consistency patterns |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Checkout Latency** | p95 <200ms (excluding PSP calls) |
| **Oversell Rate** | ~0% (strong consistency for inventory) |
| **Payment Success Rate** | >98% |
| **Availability** | 99.95% |

## Technology Stack

- **Catalog**: Elasticsearch for search, PostgreSQL for product details
- **Inventory**: Redis for hot SKU counts, PostgreSQL with row-level locks
- **Checkout**: Distributed transactions (Saga pattern or 2PC)
- **Payments**: Multiple PSP integrations (Stripe, Adyen, PayPal)
- **Orders**: Event-driven state machine (Kafka + PostgreSQL)

## Interview Focus Areas

1. **Oversell Prevention**: Optimistic locking, distributed locks, reservation TTL
2. **Idempotency**: Prevent double-charge on retry (idempotency keys)
3. **Inventory Reservation**: TTL expiry, background cleanup jobs
4. **Payment Flows**: Authorize vs capture, PSP failover strategies
5. **Flash Sale Handling**: Rate limiting, queue-based checkout, virtual waiting rooms
