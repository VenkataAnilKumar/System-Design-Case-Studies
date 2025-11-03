# System Design Case Studies 🚀

**30 production-grade system design case studies** for mastering distributed systems, preparing for FAANG interviews, and building real-world architectures. From Netflix-scale video streaming to Uber's geospatial matching, learn how industry giants handle billions of requests per day.

[![Case Studies](https://img.shields.io/badge/Case%20Studies-30%20Complete-brightgreen.svg)](./case-studies)
[![Files](https://img.shields.io/badge/Files-150%20Markdown-blue.svg)](./case-studies)
[![Style](https://img.shields.io/badge/Style-ByteByteGo%20%2B%20Educative-purple.svg)](./case-studies)

---

## 🎯 What's Inside

Each case study follows a **5-chapter structure**:
1. **Requirements & Scale** - Functional/non-functional requirements, traffic estimates, cost analysis
2. **Architecture Design** - Components (what & why), data flows, data models, APIs, monitoring
3. **Key Technical Decisions** - Trade-offs with "when to reconsider" triggers (e.g., SQL vs NoSQL)
4. **Wrap-Up & Deep Dives** - Scaling playbook (MVP→Production→Scale), failure scenarios, SLOs, pitfalls, interview tips

**Writing Philosophy**: Concise & practical (ByteByteGo/Educative style), real-world trade-offs over theory, domain-specific depth (not templated copy-paste).

---

## 📚 All 30 Case Studies

### 🔴 Real-Time & Messaging (1-2)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **01** | [**Real-Time Chat**](./case-studies/01-real-time-chat-application) | WebSocket, message queue, presence, E2EE | 100M users, 1M concurrent |
| **02** | [**Ride-Sharing**](./case-studies/02-ride-sharing-platform) | Geospatial matching (Geohash), ETA prediction, surge pricing | 10M rides/day, real-time tracking |

### 🔵 Media & Content (3, 6, 8, 12)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **03** | [**Video Streaming**](./case-studies/03-video-streaming-platform) | Adaptive bitrate (HLS), CDN, multi-region, transcoding | 100M hours/day, Netflix-scale |
| **06** | [**Collaborative Docs**](./case-studies/06-collaborative-document-editor) | Operational Transform/CRDT, WebSocket, conflict resolution | 1M concurrent editors, Google Docs |
| **08** | [**CDN**](./case-studies/08-content-delivery-network) | Edge caching, origin shielding, cache invalidation, geo-routing | 10TB/day bandwidth, Cloudflare-scale |
| **12** | [**Live Streaming**](./case-studies/12-live-streaming-platform) | LL-HLS/WebRTC, RTMP ingest, chat moderation, DVR | 1M concurrent viewers, Twitch-scale |

### 🟢 Social & E-Commerce (4-5, 9, 20)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **04** | [**Social Media Feed**](./case-studies/04-social-media-news-feed) | Fanout (push/pull hybrid), timeline ranking, newsfeed generation | 500M users, Twitter/Instagram |
| **05** | [**E-Commerce**](./case-studies/05-ecommerce-marketplace) | Inventory management, shopping cart, checkout, order fulfillment | 10M products, Amazon-scale |
| **09** | [**Search Engine**](./case-studies/09-search-engine) | Inverted index, PageRank, query processing, autocomplete | 10B documents, Google-scale |
| **20** | [**Hotel Reservation**](./case-studies/20-hotel-reservation-system) | Pessimistic locking, overbooking prevention, payment auth/capture | 1M bookings/day, Booking.com |

### 🟡 Infrastructure & Data (7, 10-11, 17-19, 23, 27-28, 30)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **07** | [**Email Service**](./case-studies/07-email-delivery-service) | SMTP/IMAP, spam filtering, attachment storage, rate limiting | 10B emails/day, Gmail-scale |
| **10** | [**Stock Trading**](./case-studies/10-stock-trading-platform) | Order matching engine, order book, market data, low-latency | <10ms p99 latency, NASDAQ-scale |
| **11** | [**Task Scheduler**](./case-studies/11-distributed-task-scheduler) | Cron-like scheduling, DAG execution, retry logic, priority queues | 1M tasks/day, Airflow/Temporal |
| **17** | [**IoT Pipeline**](./case-studies/17-iot-data-processing-pipeline) | MQTT ingestion, stream processing (Flink), time-series DB, OTA updates | 10M devices, 1B events/day |
| **18** | [**Distributed Cache**](./case-studies/18-distributed-cache-system) | Consistent hashing, LRU/LFU eviction, master-replica, pub/sub | 100K RPS, Redis/Memcached |
| **19** | [**Recommendation Engine**](./case-studies/19-recommendation-engine) | Collaborative filtering, two-tower embeddings, candidate generation, real-time signals | 100M users, Netflix/YouTube |
| **23** | [**Observability Platform**](./case-studies/23-observability-monitoring-platform) | Metrics (Prometheus), logs (Loki), traces (Jaeger), alerting, cardinality limits | 10M metrics/sec, Datadog-scale |
| **27** | [**Distributed File Storage**](./case-studies/27-distributed-file-storage) | Erasure coding (Reed-Solomon), replication, metadata sharding, 11 9's durability | 10B objects, 10PB, S3-scale |
| **28** | [**Web Crawler**](./case-studies/28-web-crawler) | URL frontier, robots.txt, politeness, deduplication (MD5/Simhash), BFS | 10B pages, Googlebot-scale |
| **30** | [**Real-Time Analytics**](./case-studies/30-real-time-analytics-dashboard) | Stream processing (Flink), OLAP (ClickHouse), pre-aggregation, caching | 10B events/day, Google Analytics |

### 🟠 Food & Delivery (13-15)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **13** | [**Food Delivery**](./case-studies/13-food-delivery-platform) | Regional dispatch, ML ETA, adaptive telemetry, surge pricing | 10M orders/day, DoorDash/UberEats |
| **14** | [**Online Banking**](./case-studies/14-online-banking-system) | Double-entry ledger, ACID transactions, fraud detection, reconciliation | 100M accounts, Chase/Wells Fargo |
| **15** | [**Ad Serving**](./case-studies/15-ad-serving-platform) | <100ms decisioning, frequency caps, first-price auction, pacing, privacy-first | 1M RPS, Google Ads |

### 🟣 Video & Communication (16, 21)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **16** | [**Video Conferencing**](./case-studies/16-video-conferencing-system) | SFU architecture, WebRTC, simulcast, adaptive jitter buffer, server-side recording | 10K concurrent rooms, Zoom/Meet |
| **21** | [**Message Broker**](./case-studies/21-distributed-message-broker) | Topics/partitions, ISR replication, consumer groups, leader election, exactly-once | 1M msg/sec, Kafka-scale |

### 🔵 API & Gateway (22, 24-26, 29)
| # | System | Key Concepts | Scale Targets |
|---|--------|--------------|---------------|
| **22** | [**API Gateway**](./case-studies/22-api-gateway-service) | Rate limiting (token bucket), JWT auth, circuit breakers, PSP routing | 100K RPS, Kong/AWS Gateway |
| **24** | [**ML Model Inference**](./case-studies/24-ml-model-inference-service) | Dynamic batching, GPU optimization, A/B testing, feature store, canary deployment | 100K predictions/sec, TensorFlow Serving |
| **25** | [**Payment Gateway**](./case-studies/25-payment-gateway-processor) | PSP routing, fraud detection, PCI DSS (HSM tokenization), settlement | 10K TPS, Stripe/Adyen |
| **26** | [**Content Moderation**](./case-studies/26-content-moderation-system) | AI classifiers (BERT/ResNet), confidence routing, human review, CSAM detection | 100M items/day, Meta/YouTube |
| **29** | [**Proximity Service**](./case-studies/29-proximity-service) | Geohash/H3, Redis Geo, radius search, geofencing, real-time location updates | 100M places, 10M updates/sec, Yelp/Uber
- **#29** [Proximity Service](./case-studies/29-proximity-service) - Yelp/Foursquare
- **#30** [Real-Time Analytics](./case-studies/30-real-time-analytics-dashboard) - Mixpanel/Amplitude

### 🔴 Advanced
- **#2** [Ride-Sharing](./case-studies/02-ride-sharing-service) - Uber/Lyft
- **#3** [Video Streaming](./case-studies/03-video-streaming-platform) - Netflix/YouTube
- **#6** [Collaborative Editor](./case-studies/06-collaborative-document-editor) - Google Docs
- **#7** [CDN](./case-studies/07-content-delivery-network) - Cloudflare
- **#8** [Stock Trading](./case-studies/08-stock-trading-platform) - Robinhood/E*TRADE
- **#9** [Email Service](./case-studies/09-email-service-provider) - Gmail/Outlook
- **#12** [Live Streaming](./case-studies/12-live-streaming-platform) - Twitch/YouTube Live
- **#15** [Ad Serving Platform](./case-studies/15-ad-serving-platform) - Google Ads
- **#14** [Online Banking](./case-studies/14-online-banking-system) - Chase/Revolut
- **#16** [Video Conferencing](./case-studies/16-video-conferencing-platform) - Zoom
- **#15** [Multiplayer Gaming](./case-studies/15-multiplayer-game-backend) - Fortnite
- **#16** [Video Conferencing](./case-studies/16-video-conferencing-platform) - Zoom
- **#18** [Distributed Cache](./case-studies/18-distributed-cache-system) - Redis
- **#19** [Recommendation Engine](./case-studies/19-recommendation-engine) - Netflix
- **#21** [Message Broker](./case-studies/21-distributed-message-broker) - Kafka
- **#23** [Observability](./case-studies/23-observability-monitoring-platform) - Prometheus
- **#23** [Observability](./case-studies/23-observability-monitoring-platform) - Prometheus
- **#24** [ML Inference](./case-studies/24-ml-model-inference-service) - SageMaker
- **#27** [Distributed File Storage](./case-studies/27-distributed-file-storage) - Dropbox/Drive
- **#28** [Web Crawler](./case-studies/28-web-crawler) - Google Bot/Scrapy
**[📖 View Complete List with Details →](./case-studies/README.md)**

---

## 🚀 Quick Start

### For Interviews (No Beginner Cases - All Intermediate to Advanced)
1. Start with **3 intermediate** systems (Chat, Social Feed, Hotel Reservation, Content Moderation)
2. Master **3 advanced core** systems (Stock Trading, Email Service, Video Streaming)
3. Deep dive into **2 advanced specialized** (Ride-Sharing, Ad Serving Platform)

### For Portfolio
Pick **3-5 systems** to showcase:
- **Full-Stack**: Email Service (#9) + Social Feed (#4) + Content Moderation (#26)
- **Backend/Infrastructure**: Message Broker (#21) + API Gateway (#22) + Cache (#18)
- **Fintech**: Stock Trading (#8) + Payment Gateway (#25) + Banking (#14)
- **Media/Ads**: Live Streaming (#12) + Ad Serving (#15) + CDN (#7)

---

## 🛠️ How to Use

1. **Study**: Browse `case-studies/` folder, read README.md files
2. **Generate**: Use `PROMPT.md` template with AI (Claude/GPT-4) to create new case studies
3. **Customize**: Fork and adapt for your own projects

---

## 🎓 Tech Stack Covered

**Backend**: Python, Node.js, Go, Java | **Databases**: PostgreSQL, MongoDB, Redis, Cassandra  
**Queues**: Kafka, RabbitMQ | **Real-Time**: WebSocket, WebRTC, gRPC  
**Infrastructure**: Docker, Kubernetes, Terraform | **Cloud**: AWS, GCP, Azure  
**Monitoring**: Prometheus, Grafana, ELK | **AI/ML**: TensorFlow Serving, PyTorch

---

## 💡 Why Use This?

✅ **Job Interviews**: Covers common FAANG system design questions  
✅ **Portfolio**: Showcase architectural thinking to employers  
✅ **Learning**: Structured path from beginner to advanced  
✅ **Reference**: Real-world patterns for your own projects

---

## 🤝 Contributing

Found an issue or want to add a case study? Pull requests welcome!

---

## 📄 License

MIT License - Free to use for personal and commercial projects.

---

## ⭐ Show Your Support

If this helped you land an interview or learn something new, give it a star!

---

**Happy Learning! 🚀**
