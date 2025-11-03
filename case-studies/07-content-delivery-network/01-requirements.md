# 1) Requirements & Scale

## Functional Requirements

- Content caching: Cache static assets (images, videos, CSS/JS, HTML) at edge
- Origin pull: Fetch from origin on cache miss; populate edge cache
- Cache invalidation: Purge/invalidate by URL, tag, or wildcard
- Geo-routing: Route users to nearest PoP; DNS-based or anycast
- SSL/TLS termination: Handle HTTPS at edge; certificate management
- DDoS protection: Rate limiting, bot detection, L3/L4/L7 filtering
- Analytics: Cache hit rate, bandwidth, request counts, error rates per customer

## Non-Functional Requirements

- Low latency: p95 < 50ms from edge to user; <100ms including origin pull
- High availability: 99.99%+ per PoP; multi-PoP redundancy
- Scalability: 100+ Tbps aggregate; elastic per-customer burst
- Cost efficiency: Maximize cache hit rate to minimize origin load
- Observability: Real-time dashboards; per-customer metrics

## Scale & Back-of-the-Envelope

- PoPs: 100+ globally; 1000+ edge servers total
- Traffic: 10–100 Tbps aggregate; 10M+ RPS per major PoP
- Cache size: 100TB–1PB per PoP (SSD/NVMe)
- Customers: 1M+ domains; multi-tenant

## Constraints & Assumptions

- Most content is cacheable (images, videos, static assets)
- Dynamic content (APIs) can be proxied but not cached
- Origin must handle cache misses; CDN shields with mid-tier cache
- TTL controlled by origin headers (Cache-Control, Expires)

## Success Measures

- Cache hit rate > 90%
- Origin offload (% of traffic served from edge)
- p95 latency from user to edge
- DDoS mitigation success (blocked vs passed)
