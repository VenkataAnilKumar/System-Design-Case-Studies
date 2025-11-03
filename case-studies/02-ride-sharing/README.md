# Ride Sharing Platform

## Problem Statement

Design an **Uber/Lyft-like ride-sharing system** that matches riders with nearby drivers in real-time with minimal latency.

**Core Challenge**: Handle 10M daily active users with 1M concurrent drivers sending GPS updates at 1 Hz (60M location updates/minute) while matching ride requests to drivers within 2-5 seconds (p99).

**Key Requirements**:
- Real-time driver location tracking (1 Hz GPS streaming)
- Sub-5-second rider-to-driver matching (geospatial search)
- Dynamic pricing with surge by micro-area
- Trip lifecycle management (request → assignment → pickup → completion)
- ETA/ETD calculations with traffic awareness
- Real-time notifications to rider and driver apps

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M drivers, 60M GPS updates/min, 50K-200K RPS matching) |
| [02-architecture.md](./02-architecture.md) | Components (Dispatch Service, Location Service, Matching Engine, Surge Pricing) |
| [03-key-decisions.md](./03-key-decisions.md) | Geospatial indexing (S2/H3), matching algorithms, surge calculation |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling from MVP to global deployment, failure scenarios, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Matching Latency** | p99 <5s (request → driver assigned) |
| **Location Update Latency** | p99 <100ms (GPS write) |
| **Availability** | 99.95% |
| **GPS Update Rate** | 1 Hz per active driver (60M/min for 1M drivers) |

## Technology Stack

- **Geospatial Index**: S2/H3 cells, Redis for hot driver locations
- **Matching**: K-nearest neighbor search (20-100 drivers within 1-3km)
- **Location Streaming**: WebSocket/gRPC for persistent connections
- **Surge Pricing**: Real-time supply/demand calculation per micro-area
- **Trip Store**: PostgreSQL for trip records, Kafka for event streaming

## Interview Focus Areas

1. **Geospatial Indexing**: S2/H3 cells for efficient radius queries
2. **Matching Algorithm**: Balance driver proximity, ETA, acceptance rate
3. **Surge Pricing**: Dynamic pricing based on supply/demand per cell
4. **GPS Update Optimization**: 1 Hz streaming at scale (60M updates/min)
5. **Failure Modes**: Driver location staleness, matching service downtime
