# 3) Key Decisions (Trade-offs)

## 1) ABR Protocol: HLS vs DASH
- HLS (Apple): Dominant on mobile/iOS; simple .m3u8 + .ts; supported everywhere
- DASH (MPEG): Open standard; better for live low-latency; more complex
- Choice: HLS primary; DASH optional for advanced live or Android-heavy markets

## 2) Transcode Strategy: Just-in-Time vs Pre-Transcode
- JIT: Transcode on first view → save cost for unpopular videos
- Pre-transcode: All resolutions upfront → predictable latency; better UX
- Choice: Pre-transcode top tiers (360p, 720p, 1080p); JIT for 4K if source allows and demand exists

## 3) Storage Tiers
- Hot (CDN edge): Recent/popular; milliseconds latency
- Warm (origin object storage): Older but accessible; seconds latency
- Cold (Glacier): Rarely watched; minutes restore; 10× cheaper
- Policy: Auto-tier after 90 days no views; restore on demand with acceptable delay

## 4) CDN vs Self-Host Edge
- CDN (Akamai/Cloudflare): Pay per GB; global PoPs; elastic
- Self-host: CapEx heavy; complex operations; saves long-term cost at massive scale
- Choice: CDN for <1PB/month; consider hybrid/self-host at Netflix/YouTube scale (100+ PB/month)

## 5) Live Streaming Latency
- Traditional HLS: 10–30s glass-to-glass
- Low-latency HLS/DASH: 3–5s (chunked transfer encoding, smaller segments)
- WebRTC: Sub-second but complex; not CDN-friendly
- Choice: LL-HLS for live events; accept 3–5s for cost/scale balance

## 6) DRM and Content Protection
- Widevine (Android/Chrome), FairPlay (Apple), PlayReady (Microsoft)
- Adds complexity (license servers, key rotation)
- Choice: Optional per video; enable for premium/paid content only

## 7) Recommendation Engine
- Collaborative filtering: User-item matrix; similar users/videos
- Content-based: Video metadata (tags, category, creator)
- Hybrid: Combine both; use deep learning (embeddings) at scale
- Choice: Start simple (CF + content); evolve to neural models with scale

## 8) Analytics Real-Time vs Batch
- Real-time: Kafka → stream processing (Flink) → dashboards (live view counts)
- Batch: Daily ETL (Spark) → data warehouse (Snowflake/BigQuery) → creator analytics
- Choice: Hybrid; real-time for operational metrics; batch for deep insights
