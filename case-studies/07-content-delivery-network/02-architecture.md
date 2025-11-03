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
