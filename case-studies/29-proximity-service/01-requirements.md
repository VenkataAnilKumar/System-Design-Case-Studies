# Requirements & Scale

## Functional Requirements
1. **Radius Search**: Find places within N km of (lat, lon) → return list sorted by distance
2. **Real-Time Updates**: Track moving objects (Uber drivers) with location updates every 5s
3. **Polygon Search**: Find places within custom boundary (city limits, delivery zone)
4. **Filtering**: Filter by category (restaurants, gas stations), rating (>4 stars), open now
5. **Ranking**: Sort by distance, rating, popularity (click-through rate)
6. **Geofencing**: Trigger alerts when object enters/exits region (driver enters pickup zone)

## Non-Functional Requirements
**Latency**: p99 <100ms for radius queries (5km search)
**Throughput**: 1M queries/sec, 10M location updates/sec
**Accuracy**: <10m error for GPS coordinates
**Scalability**: 100M places, support global coverage (worldwide queries)

## Scale Estimates
**Places**: 100M static places (restaurants, stores)
**Moving Objects**: 10M active (Uber drivers, delivery bikes)
**Location Updates**: 10M objects × 1 update/5s = 2M updates/sec sustained, 10M peak
**Queries**: 1M queries/sec, 5km radius avg

**Infrastructure**:
- Geo Index (Redis with Geo commands): 100M places × 100 bytes = 10GB in-memory
- Location Update Service: 1000 nodes handling 10K updates/sec each
- Query Service: 500 nodes handling 2K queries/sec each

**Cost**: $300K/mo (compute) + $50K (Redis clusters) = **$350K/mo**
