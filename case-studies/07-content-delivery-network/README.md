# Content Delivery Network (CDN)

## Problem Statement

Design a **Cloudflare/Akamai-like global CDN** that caches and delivers static content from edge locations closest to end users.

**Core Challenge**: Serve 10 Tbps of traffic from 200+ edge locations with <50ms p95 latency to 95% of global users while maintaining >90% cache hit rate.

**Key Requirements**:
- Global edge PoPs (Points of Presence) in 200+ cities
- Origin shielding to protect backend servers
- Cache warming and purge propagation
- DDoS protection and rate limiting
- TLS termination at edge
- Real-time analytics (cache hit rate, bandwidth, errors)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10 Tbps, 200+ edge PoPs, 90% cache hit rate) |
| [02-architecture.md](./02-architecture.md) | Components (Edge Servers, Origin Shield, Control Plane, Routing) |
| [03-key-decisions.md](./03-key-decisions.md) | Cache eviction policies, origin shielding, Anycast routing |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to exabytes, failure scenarios, DDoS mitigation |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Edge Latency** | p95 <50ms (user to edge PoP) |
| **Cache Hit Rate** | >90% (minimize origin requests) |
| **Availability** | 99.99% (per PoP degradation acceptable) |
| **DDoS Protection** | Handle 10M RPS attack without service degradation |

## Technology Stack

- **Edge Servers**: Nginx/Varnish for caching, LRU eviction
- **Routing**: Anycast IP for geo-routing to nearest PoP
- **Origin Shield**: Regional cache layer between edge and origin
- **Control Plane**: Distributed config management (etcd/Consul)
- **Analytics**: Real-time log streaming (Kafka → ClickHouse)

## Interview Focus Areas

1. **Anycast Routing**: Route requests to nearest PoP based on BGP
2. **Cache Eviction**: LRU, TTL, cache key design (query params, headers)
3. **Origin Shielding**: Reduce origin load by 10×
4. **Purge Propagation**: Invalidate cache across 200 PoPs in <30s
5. **DDoS Mitigation**: Rate limiting, challenge pages (CAPTCHA), IP reputation
