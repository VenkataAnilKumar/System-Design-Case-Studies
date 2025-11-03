# Hotel Reservation System

## Problem Statement

Design a **Booking.com/Airbnb-like hotel reservation system** that handles room inventory, booking, and prevents double-booking under high concurrency.

**Core Challenge**: Process 10K bookings/sec during peak (flash sales) with <200ms latency while preventing overbooking through distributed locking and inventory management.

**Key Requirements**:
- Hotel/room search with filters (location, price, amenities)
- Real-time availability checking
- Booking with payment hold (authorize, not capture)
- Inventory management (prevent double-booking)
- Cancellation with refund policies
- Dynamic pricing (surge during high demand)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10K bookings/sec, <200ms latency, zero overbooking) |
| [02-architecture.md](./02-architecture.md) | Components (Search, Booking Service, Inventory, Payment, Pricing) |
| [03-key-decisions.md](./03-key-decisions.md) | Pessimistic locking, optimistic locking, inventory reservation |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global hotels, failure scenarios, overbooking prevention |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Booking Latency** | p95 <200ms |
| **Overbooking Rate** | ~0% (strong consistency) |
| **Search Latency** | p99 <500ms |
| **Availability** | 99.95% |

## Technology Stack

- **Search**: Elasticsearch for hotel/room filtering
- **Inventory**: PostgreSQL with row-level locks (pessimistic locking)
- **Booking**: Saga pattern for distributed transactions
- **Payments**: Multi-PSP integration (authorize on booking, capture on check-in)
- **Pricing**: Dynamic pricing engine (supply/demand, events)

## Interview Focus Areas

1. **Overbooking Prevention**: Pessimistic locking (SELECT FOR UPDATE)
2. **Inventory Reservation**: Hold inventory for 10 min during payment
3. **Distributed Transactions**: Saga pattern (compensating transactions)
4. **Dynamic Pricing**: Adjust prices based on demand, competitor rates
5. **Cancellation Policies**: Refund rules (free cancellation window, partial refunds)
