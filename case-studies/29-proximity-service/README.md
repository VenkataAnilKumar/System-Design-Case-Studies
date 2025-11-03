# Proximity Service

## Problem Statement

Design a **Yelp/Foursquare-like proximity service** that finds nearby places (restaurants, stores) based on user location with low latency.

**Core Challenge**: Handle 1M queries/sec for radius searches (find all places within 5km) with <100ms p99 latency while indexing 100M places and tracking 10M moving objects (delivery drivers).

**Key Requirements**:
- Radius search (find places within N km)
- Real-time location updates (drivers, bikes)
- Polygon search (find places within custom boundary)
- Filtering (category, rating, open now)
- Ranking (sort by distance, rating, popularity)
- Geofencing (trigger alerts when entering/exiting region)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M queries/sec, 100M places, <100ms latency) |
| [02-architecture.md](./02-architecture.md) | Components (Geospatial Index, Location Service, Query API, Geofencing) |
| [03-key-decisions.md](./03-key-decisions.md) | Geohash vs H3, Redis Geo vs PostGIS, sharding strategies |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global coverage, failure scenarios, hot spot mitigation |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Query Latency** | p99 <100ms (5km radius) |
| **Location Update Rate** | 10M objects × 1 update/5s = 2M updates/sec |
| **Accuracy** | <10m error for GPS coordinates |
| **Availability** | 99.9% |

## Technology Stack

- **Geospatial Index**: Redis Geo (GEORADIUS) or PostGIS
- **Geohash/H3**: Encode lat/lon into cell IDs for prefix search
- **Location Streaming**: Kafka for real-time driver location updates
- **Sharding**: Partition by Geohash prefix (co-locate nearby places)
- **Caching**: Per-cell caching (all places in Geohash cell)

## Interview Focus Areas

1. **Geohash**: Encode (lat, lon) → string ("9q8yy") for prefix-based search
2. **Redis Geo**: GEORADIUS command for <10ms radius queries
3. **H3 vs Geohash**: H3 hexagons (uniform) vs Geohash squares (edge distortion)
4. **Sharding**: Shard by Geohash prefix to co-locate nearby places
5. **Geofencing**: Check if (lat, lon) is inside polygon (point-in-polygon algorithm)
