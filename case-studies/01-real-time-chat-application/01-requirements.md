# 1) Requirements & Scale

> Goal: Define what we are building, how big it needs to be, and the first-order constraints. Keep it brief and practical.

---

## What we are building (at a glance)

A real-time chat system (WhatsApp/Slack-like) that supports:

- One-on-one and group messaging (text + media)
- Delivery/read receipts and presence (online/typing)
- Message history with pagination
- Push notifications for offline users

Scope (Phase 1): Design only (no code), production-credible, cloud-friendly.

---

## Core requirements

### Functional

- Send/receive messages instantly (Web, iOS, Android)
- Create groups, add/remove members
- Show delivery states: sent ✓, delivered ✓✓, read ✓✓ blue
- Presence: online/offline, last seen, typing
- Upload/download images/videos/files (links in messages)
- Search by user/conversation (basic)

### Non-functional

- Real-time UX: p99 message delivery under 100 ms for online users
- Availability ≥ 99.95% (≈ 4.38 hours/year downtime)
- Data durability: messages must not be lost
- Privacy: minimal exposure in push notifications
- Cost-aware: prefer simple, proven building blocks

---

## Scale targets (order-of-magnitude)

- 100M daily active users (DAU)
- 10M concurrent WebSocket connections
- Average 50 messages/day/user → 5B messages/day
- Average write rate: ~58K messages/sec (×3 at peak ≈ 174K/sec)
- Read-heavy: roughly 10 reads per write (history fetch, delivery state)

---

## Quick capacity math (back-of-envelope)

- Message size (text avg): ~1 KB (body + metadata)
- Daily text storage: 5B × 1 KB ≈ 5 TB/day
- Media (10% messages, 50 KB avg via CDN/S3): ≈ 25 TB/day (served mostly via CDN)
- One-year storage (text only, before compression): ≈ 1.8 PB
- With compression and realistic retention: plan for multi-PB over years

Networking (messages only):
- Peak bandwidth: 174K msg/s × 1.1 KB ≈ 190 MB/s ≈ 1.5 Gbps (media served via CDN separately)

Compute sizing (rule-of-thumb):
- WebSocket: ~10K connections/server → ~1,000–1,200 WS servers for 10M conns
- API: ~5K RPS/server → 40–60 API servers for core traffic
- Cache: 0.5–3 TB Redis cluster for presence + hot history
- DB: Shard PostgreSQL by conversation_id; start with 10 shards × 4 replicas

---

## Constraints and guardrails

- Ordering matters: conversations must render in correct order → favor strong consistency for writes
- Real-time first: bidirectional transport (WebSocket) for online delivery
- Async everything else: notifications, analytics, fan-out workers via a queue
- Keep it simple: proven tech (PostgreSQL + Redis + Kafka + S3/CDN)
- Mobile clients can buffer offline; sync on reconnect
- WebSocket preferred; HTTP fallback for restrictive networks
- End-to-end encryption (E2EE) optional; server-side moderation when needed
- Multi-region deployment; eventual consistency across regions acceptable (CRDT for sync)
- PII/GDPR: User can delete messages; 30-day hard retention; compliance audit logs

---

## Success measures

- Delivery latency p99 < 100 ms for online users
- Success rate ≥ 99.9% per message
- Stable connections: < 1% drop per hour
- 90%+ CDN hit ratio for media

---

## Out of scope (Phase 1)

- End-to-end encryption protocol details (use Signal in Phase 2)
- Advanced search/ranking and ML-based spam detection
- Full multi-region active-active (start with single primary region + DR)
