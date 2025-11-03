# Key Technical Decisions

## 1. Geohash vs. H3 (Hexagonal Grid)
**Decision**: **Geohash** for simplicity, **H3** for accuracy.
**Rationale**: Geohash is simpler (string-based, Redis native). H3 has uniform cell sizes (hexagons, no edge distortion).
**Reconsider**: For Uber-like use cases (driver matching), use H3 (Uber's open-source library).

## 2. Redis Geo vs. PostGIS (PostgreSQL)
**Decision**: **Redis Geo** for real-time queries, **PostGIS** for complex polygons.
**Rationale**: Redis is in-memory (<10ms queries). PostGIS supports advanced spatial queries (intersects, contains).
**Reconsider**: For complex queries (find places inside city limits + exclude parks), use PostGIS.

## 3. Precision: Geohash 6 (±1km) vs. Geohash 7 (±100m)
**Decision**: **Geohash 6** for city-scale search.
**Rationale**: 5km radius = ~5 Geohash 6 cells (manageable). Geohash 7 = ~50 cells (overhead).
**Reconsider**: For high-precision (delivery routing), use Geohash 7 or 8.

## 4. Sharding: By Geohash Prefix vs. Random
**Decision**: **By Geohash prefix** (first 2 chars).
**Rationale**: Co-locates nearby places on same shard → single-shard queries (no cross-shard joins).
**Reconsider**: For global load balancing (avoid hotspots), use random sharding.

## 5. Real-Time Updates: Push vs. Pull
**Decision**: **Push** (location update stream).
**Rationale**: Drivers push location every 5s → index always current. Pull (query on-demand) adds latency.
**Reconsider**: For battery-sensitive devices (low power), use pull (query when needed).

## 6. Caching: Per-Query vs. Per-Cell
**Decision**: **Per-cell caching** (Geohash prefix).
**Rationale**: Cache all places in "9q8yy" cell → reuse for nearby queries. Per-query cache has low hit rate.
**Reconsider**: For personalized queries (rating filters), use per-query cache.

## 7. Distance Calculation: Haversine vs. Euclidean
**Decision**: **Haversine** for accuracy.
**Rationale**: Haversine accounts for Earth curvature (accurate to 1m). Euclidean is 10% error at 100km distances.
**Reconsider**: For small distances (<1km), Euclidean is faster (accept 1% error).

## 8. Polygon Search: Pre-Filter vs. Post-Filter
**Decision**: **Pre-filter** with bounding box, **post-filter** with exact polygon.
**Rationale**: Bounding box is fast (Redis query). Exact polygon is slow (PostGIS). Pre-filter reduces candidates 10×.
**Reconsider**: For simple rectangles, bounding box only is sufficient (no post-filter).
