# Wrap-Up & Deep Dives

## Scaling Playbook
**Stage 1 (MVP)**: PostgreSQL with PostGIS, 1M places, radius search with bounding box.
**Stage 2 (Production)**: Redis Geo, 10M places, Geohash indexing, real-time location updates (Kafka stream).
**Stage 3 (Scale)**: H3 hexagonal grid, 100M places, sharded by geohash prefix, geofencing with polygon queries, multi-region (geo-routing).

## Failure Scenarios
- **Redis Down**: Fall back to PostGIS (slower, 50ms vs. 10ms).
- **Location Update Lag**: Kafka backlog → stale driver locations (show last-known position).
- **Hotspot Shards**: Popular city (NYC) overloads shard → further partition (NYC = 10 sub-shards).

## SLO Commitments
- **Query Latency**: p99 <100ms for 5km radius search
- **Update Latency**: Location updates indexed within 100ms
- **Accuracy**: Distance error <10m (Haversine calculation)
- **Availability**: 99.9% uptime

## Common Pitfalls
1. **Euclidean Distance**: Use Haversine for Earth curvature (10% error at 100km).
2. **Single Shard Hotspot**: NYC queries overload one shard → partition by finer Geohash (6 → 7).
3. **No Geohash Neighbors**: Query only center cell → miss results on cell boundary (include 9 neighbors).
4. **Stale Locations**: Don't update driver location → show out-of-date position (confuses riders).
5. **No Geofencing**: Miss driver entering pickup zone → delayed notifications.

## Interview Talking Points
- **Geohash**: "Encode (37.77, -122.41) → '9q8yy' (precision 5 = ~1km square). Query prefix '9q8yy*' returns all nearby places."
- **Redis Geo**: "GEORADIUS places 37.77 -122.41 5 km WITHDIST → returns places sorted by distance in <10ms (in-memory)."
- **H3 vs. Geohash**: "H3 uses hexagons (uniform distances), Geohash uses squares (edge distortion). Uber uses H3 for driver matching."
- **Sharding**: "Shard by Geohash prefix (first 2 chars '9q') → co-locates nearby places on same shard (avoid cross-shard queries)."

## Follow-Up Questions
1. **Geofencing at Scale**: 1M active geofences × 10M drivers = 10T checks/sec. How to optimize?
2. **Moving Objects**: Track 10M drivers with 1 update/5s → 2M updates/sec. How to scale location update stream?
3. **Polygon Queries**: Complex delivery zones (exclude parks, lakes). How to optimize PostGIS queries?
4. **Multi-Region**: Global service (US, EU, Asia). How to partition data (geo-based vs. random)?
5. **Uber Driver Matching**: Match rider to nearest driver in <1s. How to prioritize by ETA, not just distance?

**Final Thought**: Proximity service trades **query latency** (use in-memory Redis) for **index update complexity** (real-time location streams). The key challenge is **sharding**—partition by geohash to co-locate nearby places, but avoid hotspots in dense cities (NYC, SF). Geofencing (polygon queries) requires PostGIS for accuracy, but pre-filter with bounding box to reduce load 10×.
