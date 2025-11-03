# 07-content-delivery-network - Content Delivery Network
Generated: 2025-11-02 20:38:44 -05:00

---

<!-- Source: 01-requirements.md -->
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




---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
	subgraph Users
		User[End Users]
	end

	subgraph DNS
		GeoDNS[GeoDNS/Anycast]
	end

	subgraph Edge
		PoP1[Edge PoP US-East\nNginx/Varnish]
		PoP2[Edge PoP EU-West]
		PoP3[Edge PoP APAC]
	end

	subgraph Mid-Tier
		Shield[Origin Shield\nCollapse requests]
	end

	subgraph Origin
		Origin[Customer Origin]
	end

	subgraph Control
		Portal[Customer Portal]
		PurgeAPI[Purge API]
		Metrics[Monitoring\nPrometheus/Grafana]
	end

	User --> GeoDNS
	GeoDNS -.->|Route nearest| PoP1
	GeoDNS -.->|Route nearest| PoP2
	GeoDNS -.->|Route nearest| PoP3
  
	PoP1 -->|Cache miss| Shield
	PoP2 -->|Cache miss| Shield
	PoP3 -->|Cache miss| Shield
	Shield -->|Cache miss| Origin
  
	Portal --> PurgeAPI
	PurgeAPI --> PoP1
	PurgeAPI --> PoP2
	PurgeAPI --> PoP3
  
	PoP1 --> Metrics
	PoP2 --> Metrics
	PoP3 --> Metrics
```

## Components

- Edge PoPs: 100+ locations globally; Nginx/Varnish cache servers; SSD/NVMe storage
- DNS/Anycast: GeoDNS or anycast IP routing to nearest PoP
- Origin Shield: Mid-tier cache between edge and origin; collapses requests
- Control Plane: Customer portal; cache config; purge API; analytics aggregation
- Monitoring: Real-time metrics (Prometheus/Grafana); alerting; log aggregation

## Data Flows

### A) User Request (Cache Hit)

1) User → DNS: Resolve cdn.example.com → nearest PoP IP (GeoDNS or anycast)
2) User → Edge PoP: GET /image.jpg
3) Edge checks local cache (LRU + TTL)
4) Cache hit → Serve from edge (sub-ms disk read); update LRU
5) Response with headers (X-Cache: HIT, Age: 3600)

### B) User Request (Cache Miss)

1) User → Edge PoP: GET /video.mp4
2) Cache miss → Edge → Origin Shield (mid-tier)
3) Shield checks cache; if miss → Shield → Origin
4) Origin responds with content + Cache-Control: max-age=86400
5) Shield caches; returns to edge
6) Edge caches; serves to user
7) Subsequent requests hit edge cache

### C) Cache Invalidation (Purge)

1) Customer → Control Plane API: POST /purge {url: "/style.css"}
2) Control Plane → All edge PoPs: Invalidate /style.css
3) Edge servers mark entry stale or delete
4) Next request: Cache miss → fetch fresh from origin

### D) DDoS Attack

1) Massive traffic spike detected (rate anomaly)
2) Edge applies rate limits per IP; challenge suspicious requests (CAPTCHA)
3) L3/L4 filters (SYN flood, UDP amp) at network edge
4) L7 analysis (bot detection, fingerprinting)
5) Legitimate traffic passes; attack traffic dropped; origin protected

## Data Model

- cache_entries(key=URL, value=content_blob, ttl, headers, lru_score) — per PoP
- customer_configs(domain, origin_url, cache_rules, purge_keys, ssl_cert)
- analytics_events(timestamp, customer_id, pop_id, url, cache_status, bytes, latency) — stream to data warehouse

## APIs

- GET /cdn/:customer/:path (end-user facing)
- POST /v1/purge {urls, tags} (customer API)
- GET /v1/analytics?start=...&end=... (customer dashboard)

Auth: Customer API keys; SSL cert pinning for origin

## Why These Choices

- Anycast: Same IP advertised from multiple PoPs; BGP routes to nearest; simplifies DNS
- Origin Shield: Reduces origin load; collapses concurrent misses into one origin request
- TTL-based caching: Honor origin headers; configurable overrides per customer
- LRU eviction: Keep hot content; evict cold to make room
- Multi-tier (edge + shield + origin): Balance latency, hit rate, origin protection

## Monitoring

- Cache hit rate per PoP; per customer
- Origin response time; error rate
- Bandwidth (Gbps in/out per PoP)
- DDoS events; blocked request rate
- SSL cert expiry; auto-renewal status




---

<!-- Source: 03-key-decisions.md -->
# 3) Key Decisions (Trade-offs)

## 1) Pull vs Push CDN
- Pull: Edge fetches from origin on miss; simpler for customers; origin-driven TTL
- Push: Customer uploads to CDN; no origin fetches; better for static sites
- Choice: Pull primary (most flexible); push optional for static-only customers

## 2) Anycast vs GeoDNS
- Anycast: Same IP from all PoPs; BGP routing; simpler client config; can cause suboptimal routing
- GeoDNS: Different IPs per region; precise control; requires DNS lookups
- Choice: Anycast for simplicity; GeoDNS fallback for fine-tuned routing

## 3) Origin Shield: Single vs Multi-Tier
- Single tier (edge → origin): Simpler but higher origin load
- Multi-tier (edge → shield → origin): Adds latency but protects origin
- Choice: Multi-tier with regional shields; collapses requests

## 4) Cache Eviction Policy
- LRU: Evict least recently used; good for general workloads
- LFU: Evict least frequently used; better for stable hot content
- TTL-first: Respect origin TTL strictly; simpler
- Choice: LRU with TTL enforcement; configurable per customer

## 5) Purge Mechanism
- Tag-based: Group URLs by tag; purge all with one API call
- URL-based: Purge individual URLs; precise but manual
- Wildcard: Purge /path/* patterns
- Choice: Support all three; tag-based most scalable

## 6) DDoS Mitigation Layers
- Network (L3/L4): SYN flood, UDP amp; BGP blackhole
- Transport (L7): Rate limiting, CAPTCHA, JS challenge
- Choice: Layered defense; escalate from rate-limit to challenge to block

## 7) SSL/TLS Handling
- Shared cert (*.cdn-provider.com): Simple but exposes CDN domain
- Custom cert per customer: Better branding; requires cert management
- Let's Encrypt auto-renewal: Free but 90-day expiry
- Choice: Support both; auto-renewal for custom domains

## 8) Metrics Aggregation
- Real-time (stream): Kafka → Flink → dashboards; low latency
- Batch (hourly): Reduce granularity; cheaper storage
- Choice: Hybrid; real-time for ops; batch for billing/analytics




---

<!-- Source: 04-wrap-up.md -->
# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Add PoPs in new regions; BGP anycast automatically routes
- Horizontal scale within PoP: Add cache servers; load balance with ECMP
- Storage: SSD/NVMe for hot cache; HDD for warm; evict cold
- Control plane: Shard customers; per-customer config in distributed KV store
- Analytics: Stream to Kafka; aggregate in data warehouse; cache dashboards

## Failure Scenarios
1) PoP outage
- Impact: Traffic reroutes to next-nearest PoP via BGP/DNS
- Mitigation: Multi-PoP redundancy; health checks; automatic failover

2) Origin down
- Impact: Cache hits still work; cache misses fail
- Mitigation: Serve stale content (stale-while-revalidate); queue purge requests

3) Cache stampede (thundering herd)
- Impact: Many edge servers miss simultaneously; hammer origin
- Mitigation: Origin shield collapses requests; request coalescing at edge

4) DDoS overwhelms PoP
- Impact: Legitimate traffic affected
- Mitigation: Blackhole attack IPs; rate-limit aggressively; failover to other PoPs

## SLOs & Metrics
- Cache hit rate > 90%; origin offload > 80%
- p95 latency < 50ms (edge); <150ms (including origin pull)
- Availability 99.99% per PoP; 99.999% global (multi-PoP)
- DDoS mitigation: Block > 99% of attack traffic

## Pitfalls and Gotchas
- Negative caching: Cache 404s; avoid repeated origin hits for missing content
- Vary header: Cache separately per Vary (e.g., Accept-Encoding); can fragment cache
- Long TTLs: Hard to update; balance freshness vs hit rate
- Purge propagation delay: Eventual consistency; some edges serve stale briefly

## Interview Talking Points
- Anycast vs GeoDNS; BGP routing basics
- Origin shield and request collapsing
- Cache eviction policies; LRU vs TTL
- Multi-layer DDoS protection

## Follow-up Q&A
- Q: Handle live video streaming?
  - A: HLS/DASH segments cached at edge; manifest dynamically generated; low TTL for live
- Q: Dynamic content (personalized APIs)?
  - A: Proxy through CDN but don't cache; SSL termination and DDoS still apply
- Q: Cert management at scale?
  - A: Let's Encrypt automation; centralized cert store; SNI at edge
- Q: Cost optimization?
  - A: Increase cache hit rate (longer TTLs, better eviction); compress responses; tiered pricing by region

---

This CDN design uses global anycast routing, multi-tier caching (edge + shield), TTL-based LRU eviction, and layered DDoS protection to deliver content with low latency and high availability while minimizing origin load.



