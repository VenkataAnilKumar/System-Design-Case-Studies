# Food Delivery Platform

## Problem Statement

Design a **DoorDash/Uber Eats-like food delivery platform** that matches customers, restaurants, and delivery drivers in real-time with optimal routing.

**Core Challenge**: Handle 10M orders/day with <5-minute order-to-driver assignment, optimize multi-stop delivery routes, and maintain 99.9% on-time delivery rate.

**Key Requirements**:
- Restaurant catalog with real-time menu updates
- Order placement with cart management
- Driver matching and assignment (<5 min)
- Route optimization (multi-stop pickup/delivery)
- Real-time order tracking (GPS updates)
- Payment processing (customer, restaurant, driver payouts)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10M orders/day, <5min assignment, 99.9% on-time) |
| [02-architecture.md](./02-architecture.md) | Components (Order Service, Matching Engine, Routing, Tracking) |
| [03-key-decisions.md](./03-key-decisions.md) | Driver matching algorithms, route optimization, surge pricing |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global markets, failure scenarios, driver incentives |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Order Assignment** | <5 min (order → driver assigned) |
| **On-Time Delivery** | >99.9% (within promised ETA) |
| **Driver Utilization** | >80% (minimize idle time) |
| **Availability** | 99.95% |

## Technology Stack

- **Geospatial Index**: S2/H3 cells for driver location
- **Matching**: Greedy algorithm (nearest driver with capacity)
- **Routing**: Google Maps API + in-house optimization (traveling salesman)
- **Tracking**: WebSocket for real-time driver GPS updates
- **Payments**: Multi-party split (customer, restaurant, driver, platform)

## Interview Focus Areas

1. **Driver Matching**: Balance proximity, ETA, driver acceptance rate
2. **Route Optimization**: Traveling salesman for multi-stop deliveries
3. **Demand Forecasting**: Predict order volume for driver supply
4. **Surge Pricing**: Dynamic pricing based on demand/supply ratio
5. **Cold Start Problem**: New restaurant/driver with no ratings
