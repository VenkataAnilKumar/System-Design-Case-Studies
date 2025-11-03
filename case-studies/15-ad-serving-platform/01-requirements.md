# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Ad Request Handling: Parse page/app context; geo; device; user ID (if consented)
- Targeting: Contextual (page keywords), behavioral (segments), geo, time, frequency caps
- Auction: First-price or second-price with floors; brand safety filters
- Pacing & Budgets: Spend evenly, dayparting, throttling, delivery goals
- Frequency Capping: User-level caps (e.g., 3/day per campaign)
- Creative Delivery: Select creative variant; track impressions/clicks; CDN delivery
- Reporting: Near-real-time dashboards; breakdowns by campaign/geo/device/placement
- Fraud Prevention: IVT detection (bots, datacenter IPs), viewability, click spam detection
- Privacy: Consent management (TCF/CPRA), contextual fallback when no consent

## Non-Functional Requirements

- Latency: p95 < 100ms (end-to-end); ad decisioning < 50ms budget
- Scale: 2M QPS peak ad requests; 10M QPS KV lookups (caps, segments)
- Availability: 99.99% for ad serving; graceful degradation (contextual only)
- Accuracy: Pacing error < ±5%; frequency cap accuracy > 99.9%
- Cost: Optimize memory per user key; cache hit rate > 95%

## Scale Estimate

- Users: 500M unique/month; 100M/day
- Keys: Frequency cap KV ~ 2B keys (campaign×user); TTL 7–30 days
- Events: 50B impressions/day; 2B clicks/day; streaming to analytics

## Constraints

- Privacy regulations: GDPR/CCPA; consent strings; data minimization
- Supply chain: Header bidding, ads.txt/app-ads.txt; SSP/DSP integrations
- Brand safety: Blocklists; viewability standards (MRC)

## Success Measures

- Revenue (eCPM, fill rate, win rate)
- Pacing adherence; under/over-delivery
- Viewability rate and IVT rate
- p95 latency and timeouts avoided