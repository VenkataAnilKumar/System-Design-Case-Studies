# Chapter 3 — Key Technical Decisions

> **TL;DR:** WebSocket for transport · PostgreSQL (sharded by conversation) for ordered messages · Redis Pub/Sub for online routing + Kafka for offline delivery · ULID for sortable message IDs · 30s heartbeat + 60s TTL for presence · Signal Protocol for optional E2EE

---

## Contents

1. [Real-Time Transport — WebSocket vs SSE vs Long Polling](#1-real-time-transport)
2. [Message Store — PostgreSQL vs Cassandra](#2-message-store)
3. [Cross-Server Delivery — Redis Pub/Sub + Kafka Hybrid](#3-cross-server-delivery)
4. [Group Fan-Out — Push vs Pull vs Hybrid](#4-group-fan-out)
5. [Sharding Key — Conversation ID](#5-sharding-key)
6. [Message IDs — ULID vs Snowflake vs UUID](#6-message-ids)
7. [Caching Strategy](#7-caching-strategy)
8. [Presence — Accuracy vs Cost](#8-presence--accuracy-vs-cost)
9. [Multi-Region — Active-Active + CRDT](#9-multi-region)
10. [Message Retention — Tiered Storage](#10-message-retention)
11. [End-to-End Encryption — Signal Protocol](#11-end-to-end-encryption)
12. [Rate Limiting — Multi-Layer Strategy](#12-rate-limiting)

---

## 1. Real-Time Transport

**Problem:** Need instant, bidirectional communication for messages, typing indicators, delivery receipts, and presence updates — across Web, iOS, and Android.

**Options:**

| Option | Latency | Bidirectional | Cost @ 10M users/month |
|---|---|---|---|
| HTTP Polling (1s interval) | ~1s | No | ~$500K |
| Long Polling | ~200ms | No | ~$200K |
| Server-Sent Events (SSE) | ~50ms | Server → Client only | ~$100K |
| **WebSocket** | **<50ms** | **Yes** | **~$50K** |

**Decision:** WebSocket for all real-time flows; REST for non-real-time (history fetch, settings, CRUD).

**Why:**
- Single persistent TCP connection per client — bidirectional frames, sub-100ms latency achievable
- 10K concurrent connections per server using Go or Erlang
- HTTP polling at 1-second intervals = 10M RPS just for keep-alive at scale — not viable

**Trade-off:** WebSocket requires sticky load balancing (consistent hashing by `user_id`) and stateful connection management (heartbeats, reconnects, drain on deploy).

**When to reconsider:** SSE if clients only need server-push with no client events. Long polling at small scale or in environments where WebSocket is blocked by corporate firewalls.

---

## 2. Message Store

**Problem:** Messages must be retrieved in strict send order within each conversation. Deletes must be immediate. Group membership changes must be atomic with message visibility.

**Options:**

| Criterion | PostgreSQL (chosen) | Cassandra |
|---|---|---|
| Ordering | Strong (ACID, single shard) | Eventual (race conditions) |
| Transactions | Full ACID per shard | Limited (LWT is slow) |
| Write throughput | ~10K/s per shard | ~100K/s+ |
| Sharding model | Manual re-shard | Auto-distribute |
| Ops maturity | High | Steeper learning curve |

**Decision:** PostgreSQL, sharded by `conversation_id` (10 shards initially, 4 replicas each).

**Why:**
- Ordering is a hard requirement — Cassandra's eventual consistency can produce ordering gaps unacceptable in chat UX
- A deleted message must disappear immediately, not eventually
- 10 shards × 10K writes/s = 100K/s capacity; well above 345K/s peak with further sharding

**Trade-off:** Manual re-sharding when a shard exceeds 8K writes/s or 1 TB storage. More ops work than managed Cassandra.

**When to reconsider:** If global write volume routinely exceeds 1M/s and strict per-conversation ordering can be relaxed, evaluate Cassandra or ScyllaDB.

---

## 3. Cross-Server Delivery

**Problem:** User A is connected to WS-Server-1; User B is connected to WS-Server-3. WS-Server-1 must route the message to WS-Server-3 for immediate delivery.

**Options considered:**
- **Full mesh** (each WS server talks to every other): O(N²) connections; operational nightmare at 1,000 servers
- **Redis Pub/Sub**: sub-millisecond, ephemeral, no persistence
- **Kafka direct**: durable but 10–50ms latency — too slow for real-time feel

**Decision:** Hybrid — Redis Pub/Sub for online routing, Kafka for offline delivery.

| Concern | Redis Pub/Sub | Kafka |
|---|---|---|
| Latency | Sub-millisecond | 10–50ms |
| Persistence | None (ephemeral) | 7-day log |
| Replay on failure | No | Yes |
| Best fit | Online routing | Offline notifications, analytics |

**Why:**
- Redis handles the hot path: publish to `user:{recipient_id}:messages`; all WS servers subscribed for that user deliver instantly
- Kafka handles the cold path: offline users, notification workers, analytics consumers, search indexing
- End-to-end: ~50–80ms (DB write + Pub/Sub + delivery)

**Trade-off:** Two messaging systems to maintain. Must ensure a message written to Redis Pub/Sub is also durably written to Kafka before the ACK to the sender.

**When to reconsider:** If multi-region active-active is required, Redis Pub/Sub alone won't span regions — Kafka becomes the primary bus with per-region consumers.

---

## 4. Group Fan-Out

**Problem:** Send one message to N members (2–1,000+) without blocking the sender or making N synchronous DB writes.

**Options:**
- **Push all immediately:** Fast UX; N synchronous writes per message; blocks sender for large groups
- **Pull on open:** Lightweight; members fetch when they open the chat; stale until then
- **Hybrid:** Push to online members; pull for offline; special case celebrity groups

**Decision:** Hybrid.

- **Online members (group ≤ 1,000):** Kafka consumer fans out per member via Redis Pub/Sub
- **Offline members:** `offline_messages` Kafka topic → Notification Service → FCM/APNs
- **Celebrity groups (>1,000 online members):** Push only to @mentioned users; others pull on open

**Why:** The sender is blocked only for a single DB write + Kafka publish (~40ms). All fan-out is async and independently scalable.

**Trade-off:** Offline members may miss notifications if the Kafka consumer is lagging. Hybrid routing rules add complexity (must check presence for each recipient).

---

## 5. Sharding Key

**Problem:** Partition messages across DB shards without cross-shard joins or distributed transactions.

**Options:**
- **Shard by `user_id`:** Simple for per-user queries; bad for group messages (one message spans N users → cross-shard writes)
- **Shard by `conversation_id`:** All messages for a conversation land on one shard; ordering is local

**Decision:** Shard by `conversation_id` using consistent hashing (`HASH(conversation_id) % num_shards`).

**Why:**
- Conversation history pagination is a single-shard query — no scatter-gather
- Message ordering is enforced locally — no distributed coordination needed
- A group message requires only one write, not N writes across shards
- Millions of conversations distribute load evenly

**Trade-off:** A single viral conversation (millions of members, high message volume) can hot-shard. Mitigate with a per-conversation rate limit (100 msg/min) and a dedicated "broadcast shard" for outliers.

**Re-shard trigger:** Write throughput >8K/s per shard or storage >1 TB. Expand to 2× shards, migrate even-numbered conversation hashes, dual-write during cutover.

---

## 6. Message IDs

**Problem:** Message IDs must be globally unique across shards, time-sortable for pagination, and generated locally without coordination between nodes.

**Options:**

| Option | Sortable | No Coordinator | Size | Notes |
|---|---|---|---|---|
| Auto-increment | Yes | No | 64-bit | Bottleneck at shard boundaries |
| UUID v4 | No | Yes | 128-bit | Random; can't sort by time |
| Snowflake | Yes | Yes (clock) | 64-bit | Clock skew risk; Twitter-origin |
| **ULID** | **Yes** | **Yes** | **128-bit** | Base32; lexicographic; no clock risk |

**Decision:** ULID (Universally Unique Lexicographically Sortable Identifier).

**Structure:** `01ARYZ6S41TSV4RRFFQ69G5FAV`
- First 10 chars: millisecond timestamp (makes IDs time-sortable)
- Last 16 chars: random component (collision-free within the same millisecond)

**Why:** Time-sortable without a central sequencer; URL-safe Base32 encoding; `ORDER BY message_id DESC` gives newest-first without a separate `created_at` sort column.

**Trade-off:** 128-bit vs Snowflake's 64-bit (larger indexes). Within the same millisecond, ordering is random — at 345K/s peak this affects ~0.3% of messages. If strict sub-millisecond ordering is required, add a per-conversation sequence number as a secondary sort key.

---

## 7. Caching Strategy

**Problem:** Read:write ratio is ~10:1. Without caching, peak DB read load would be 3.45M reads/s — unsustainable for PostgreSQL.

**Decision:** Cache-aside (read-through on miss; write-invalidate on change).

| Cache | Key Pattern | TTL | Purpose |
|---|---|---|---|
| Recent messages | `conv:{id}:messages` | 1h | Covers ~90% of reads (recent history) |
| Presence | `user:{id}:presence` | 60s | Auto-expires on disconnect |
| WS routing | `user:{id}:conn` | 60s | Routes message to correct WS server |
| Group metadata | `group:{id}:members` | 5min | Reduces membership DB lookups |
| User profile | `user:{id}:profile` | 15min | Reduces user lookup joins |

**Trade-offs:**
- Message content is immutable after send — safe to cache aggressively
- Mutable data (group membership, presence) — use short TTLs; brief staleness is acceptable
- Negative caching for recently-missed empty results prevents thundering herd on cold conversations

---

## 8. Presence — Accuracy vs Cost

**Problem:** Tracking 10M online users requires frequent writes. Exact presence (1s heartbeat) = 10M Redis writes/s.

**Options:**

| Approach | Writes/s | Monthly Cost | Staleness |
|---|---|---|---|
| 1s heartbeat (exact) | 10M | ~$100K | None |
| 10s heartbeat | 1M | ~$10K | 10s |
| **30s heartbeat + 60s TTL** | **333K** | **~$3K** | **Up to 60s** |

**Decision:** 30-second client heartbeat; 60-second Redis TTL.

**Why:** 99% cost reduction. 60-second staleness is acceptable — users see "last seen 1 minute ago" rather than live status. The 30s heartbeat means the key is refreshed twice per TTL window, so a clean disconnect causes the key to expire within 60s.

**Trade-off:** A user who force-quits the app appears online for up to 60 seconds. For time-critical flows (video call initiation), send an explicit `presence.offline` event on app background rather than waiting for TTL expiry.

---

## 9. Multi-Region

**Problem:** Single-region risks: full outage on region failure; 200–300ms latency for EU/Asia users.

**Decision:** Active-Active across 3 regions (US, EU, Asia-Pacific) with CRDT-based conflict resolution.

**Architecture:**
- Each region has a full independent stack: WS cluster, API cluster, PostgreSQL shards, Redis, Kafka
- Users are geo-routed to the nearest region via latency-based DNS
- Cross-region sync via Kafka MirrorMaker 2

**Conflict resolution (CRDT):**
- Messages: append-only log → no write conflicts; ULID timestamp for ordering
- Presence: last-write-wins (timestamp-based)
- Group membership: add/remove operations commute → CRDT set

**Trade-off:** Eventual consistency across regions (acceptable — users rarely change regions mid-conversation). Operational complexity of maintaining 3× the infrastructure.

**When to start multi-region:** Remain single-region until DAU >10M or p99 latency >200ms for a significant user segment.

---

## 10. Message Retention

**Decision:** Tiered storage by message age.

| Tier | Store | Retention | Access Pattern | Notes |
|---|---|---|---|---|
| Hot | Redis cache | Last 50 msgs / 1h TTL | In-memory, instant | Covers ~90% of reads |
| Warm | PostgreSQL (SSD) | 30 days | Indexed queries | Partitioned monthly |
| Cold | S3 (compressed Parquet) | 30 days – 5 years | Athena/Presto queries | Compliance / legal hold |

**Deletion:**
- Soft delete: `deleted_at` column; content hidden for 7 days (undo window for accidental deletes)
- Hard delete: purge row after 7 days (GDPR compliance)
- Media: S3 lifecycle policy deletes originals after CDN 30-day cache expires

---

## 11. End-to-End Encryption

**Decision:** Optional E2EE using Signal Protocol (Double Ratchet) for 1-on-1 chats; off by default.

**Why optional:**
- E2EE prevents server-side content moderation and compliance search (both required by enterprise customers)
- Group E2EE adds significant key management complexity on member join/leave (requires re-keying all members)

**How it works:**
1. Each device registers an identity key and signed pre-keys with the server
2. Key exchange is server-relayed; server never holds private keys
3. Client encrypts the message before sending to WebSocket
4. Server forwards the encrypted blob; recipient decrypts locally
5. Media: encrypted before S3 upload; decryption key shared via an encrypted message payload

**Trade-off:** ~20% increase in client CPU/battery. Server-side content moderation is disabled for E2EE conversations.

---

## 12. Rate Limiting

**Decision:** Multi-layer token bucket limits enforced in Redis.

| Layer | Limit | Purpose |
|---|---|---|
| Per-user messages | 100 msgs/min | Burst spam protection |
| Per-conversation | 1,000 msgs/min | Viral group spam |
| Per-user API calls | 1,000 calls/min | Abuse prevention |
| Per-IP (at LB) | 10K req/s | DDoS mitigation |
| Group creation | 50 groups/hour | Account spam |

**Implementation:** Redis sliding-window counters with token bucket refill. Returns `429 Too Many Requests` with `Retry-After` header. Paid/enterprise accounts get a separate higher-tier limit bucket.

---

## Interview TL;DR

| Decision | Chosen | Key Reason | Main Alternative |
|---|---|---|---|
| Transport | WebSocket | <100ms, bidirectional | Long polling (simpler, less efficient) |
| Message store | PostgreSQL (sharded) | ACID ordering | Cassandra (higher write TPS, eventual) |
| Online routing | Redis Pub/Sub | Sub-ms fan-out | Kafka direct (too slow) |
| Offline delivery | Kafka | Durable replay | RabbitMQ (simpler, less durable) |
| Shard key | `conversation_id` | Single-shard queries | `user_id` (cross-shard for groups) |
| Message IDs | ULID | Sortable, no coordinator | Snowflake (64-bit, clock skew risk) |
| Presence | 30s heartbeat + 60s TTL | 99% cost savings | 1s heartbeat (exact, costly) |
| E2EE | Signal Protocol (optional) | Forward secrecy | No E2EE (simpler, no privacy) |
