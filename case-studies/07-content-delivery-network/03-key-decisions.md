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
