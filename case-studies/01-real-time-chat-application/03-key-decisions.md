# 3) Key Decisions# Chapter 3 · Key Decisions (Concise)



## WebSocket vs HTTP Polling> Goal: Capture the 3–4 decisions that define the architecture. Short, practical, interview-ready.



**Decision: WebSocket for real-time; HTTP as fallback**---



Why not HTTP polling?## 1) Real-time transport: WebSocket vs SSE vs Long Polling

- Polling at 1s intervals → 1000 wasted requests/min per user when idle

- 10M users × 1 req/s = 10M RPS just checking for new messages- **Problem**: Need instant, two-way communication (typing, delivery, presence, messages)

- Cost: ~$500K/month vs $50K for persistent connections- **Options**:

  - Long polling: simple, but chatty and inefficient at scale

Why not Long Polling?  - Server-Sent Events (SSE): server→client only, no client→server push

- Still requires 1 request per message  - WebSocket: full-duplex, single persistent connection

- Complex timeout handling (30-60s holds)- **Decision**: WebSocket

- Head-of-line blocking  - Why: lowest latency, best battery/network efficiency, supports bidirectional flows

  - Trade-off: connection state + sticky load balancing required

WebSocket benefits:  - Note: keep REST for non-realtime (history, settings, CRUD)

- Bidirectional: Server can push instantly

- Single TCP connection: Lower overhead---

- Sub-100ms delivery latency

- 10K connections/server achievable with Go/Erlang## 2) Data store for messages: PostgreSQL vs Cassandra



Trade-off: More complex connection management (heartbeats, reconnects, load balancing)- **Problem**: Messages must appear in strict order within each conversation

- **Options**:

## PostgreSQL vs NoSQL (Cassandra)  - Cassandra: great write throughput, but eventual consistency → ordering gaps

  - PostgreSQL: strong consistency (ACID), simpler queries, easy pagination

**Decision: PostgreSQL with sharding**- **Decision**: PostgreSQL (sharded by conversation_id)

  - Why: ordering and correctness trump raw write TPS

Why consistency matters:  - How we scale: 10 shards × 4 replicas, add shards as we grow

1. Message ordering must be strict per conversation  - Trade-off: sharding complexity, careful capacity planning

2. User deletes message → must disappear immediately (not eventual)  - When to reconsider: if ordering can be relaxed and write volume dominates reads, evaluate Cassandra/ScyllaDB

3. Group admin removes member → no more messages visible (ACID transaction)

---

PostgreSQL advantages:

- ACID transactions: INSERT message + UPDATE conversation.last_message atomically## 3) Fan-out strategy for group messages: Push vs Pull (Hybrid)

- Strong consistency: What you write, you immediately read

- Foreign keys: Can't orphan messages- **Problem**: Send one message to 10–1000 members without blocking sender

- Complex queries: JOIN conversations + participants + messages natively- **Options**:

  - Push to everyone immediately (fast UX, heavy workload)

Cassandra disadvantages for chat:  - Pull on demand when opening chat (lightweight, delayed UX)

- Eventual consistency → deleted messages may reappear briefly- **Decision**: Hybrid

- No cross-partition transactions → can't atomically update message + conversation  - Default: push to online members via WebSocket

- Lightweight Transactions (LWT) too slow for chat latency requirements  - Offline: enqueue to Kafka → push notification only; sync on return

  - Very large/celebrity groups: pull-dominant (push only @mentions)

Numbers:

- PostgreSQL: ~10K writes/sec per shard---

- With 10 shards: 100K writes/sec → covers 174K peak with headroom

- Read replicas: 3 replicas × 50K reads/sec = 150K reads/sec## 4) Caching strategy: What to cache and how



We accept manual sharding complexity for correctness.- **Problem**: Reads dominate (10:1). DB is too slow/expensive for every read.

- **Plan**:

## Redis Pub/Sub vs Kafka for Online Delivery  - Presence: Redis keys with short TTL (auto-expire)

  - Recent messages: cache hot conversations (cache-aside on read)

**Decision: Hybrid - Redis Pub/Sub for online, Kafka for offline**  - Profiles/group metadata: cache with longer TTL; invalidate on write

  - Cross-server routing: Redis Pub/Sub channels (user:{id}, group:{id})

Redis Pub/Sub:- **Trade-offs**:

- Sub-millisecond latency for cross-server routing  - Cache invalidation is hard → prefer immutability where possible

- Ephemeral: No persistence needed for online users  - Keep TTLs reasonable; tolerate brief staleness for non-critical data

- Simple: PUBLISH to channel, all subscribers get it instantly

- Limitation: No replay if subscriber is down---



Kafka:## 5) Asynchrony: What goes to Kafka

- Persistent log: Guaranteed delivery for offline users

- Replay: Can re-consume on failure- **Problem**: Keep p95 under 100 ms for sending a message

- Limitation: ~10-50ms latency (too slow for real-time feel)- **Plan**:

  - Synchronous path: validate → write to DB → ACK to sender

Hybrid approach:  - Async path (Kafka): fan-out to group, notifications, analytics, indexing

1. Message Service writes to DB → publishes to Redis Pub/Sub- **Benefits**:

2. Online users: Get instant delivery via Pub/Sub  - Snappy UX; independent scaling of workers; retry semantics built-in

3. Simultaneously: Write to Kafka `offline_messages` topic

4. Kafka consumers check Redis for online status---

5. If offline: Send push notification via FCM/APNS

## 6) Privacy in notifications

Best of both: Real-time for online + reliable delivery for offline.

- **Problem**: Push notifications can leak content (E2EE later)

## Sharding Strategy (Conversation ID)- **Decision**: Use generic payloads ("New message from Alice")

  - Full content shown only after app fetches and decrypts locally (future E2EE)

**Decision: Shard by conversation_id (consistent hashing)**

---

Why not user_id?

- Group messages span multiple users → requires cross-shard queries## TL;DR

- Hot users (celebrities) create skewed shards

- WebSocket for real-time; REST for everything else

Why conversation_id?- PostgreSQL (sharded) for ordered messages; Redis for hot reads/presence

- All messages in a conversation live on one shard → no distributed transactions- Kafka for fan-out/notifications/analytics (async)

- Queries are per-conversation (fetch history) → single shard lookup- Hybrid push/pull for groups; generic push notifications for privacy

- Load distributes evenly (millions of conversations)

---

Shard key: `HASH(conversation_id) % num_shards`

- Start with 10 shards; add more when single shard >8K writes/sec or >1TB storage 

- Re-sharding: Expand to 20 shards → migrate even-numbered conversations → dual-write period → cutover

Hot shard mitigation:
- If one conversation goes viral (10M members): Separate "broadcast" service
- Rate limit per conversation: Max 100 msg/sec

## ULID vs Snowflake for Message IDs

**Decision: ULID (Universally Unique Lexicographically Sortable Identifier)**

Why not auto-increment?
- Requires coordination across shards → bottleneck
- Exposes message count (privacy/competitive intel)

Why not UUID v4?
- Random → can't sort by time without additional column
- Larger index (16 bytes)

ULID benefits:
- Time-sortable: First 48 bits = timestamp (ms precision)
- No coordination: Generated locally
- Lexicographic ordering: `ORDER BY id DESC` = newest first
- 128-bit: Collision-free
- URL-safe: Base32 encoded

Example: `01ARYZ6S41TSV4RRFFQ69G5FAV`
- First 10 chars: Timestamp
- Remaining: Randomness

## Multi-Region Strategy

**Decision: Active-Active with CRDT for sync**

Single region risks:
- US-East outage → entire system down
- High latency for EU/Asia users (300ms+)

Active-Active approach:
- Each region has full stack (WS, API, DB, Redis, Kafka)
- Users routed to nearest region (latency-based DNS)
- Cross-region sync via Kafka replication (MirrorMaker 2)

Conflict resolution (CRDT):
- Messages: Append-only → no conflicts (ULID timestamp for ordering)
- Presence: Last-write-wins (timestamp-based)
- Group membership: Operational Transform (add/remove commute)

Trade-off: Eventual consistency across regions (acceptable; users rarely change regions mid-conversation).

## Message Retention & Archival

**Decision: Tiered storage by age**

Hot (Redis cache): Last 50 messages per conversation, 1h TTL
- Covers 90% of reads (recent history)
- ~5TB total (compressed)

Warm (PostgreSQL): 30 days, partitioned monthly
- SSD-backed; indexed for fast queries
- ~150TB (sharded)

Cold (S3): 30 days - 5 years, compressed Parquet
- For compliance/legal hold
- Queries via Athena/Presto (acceptable latency)

Deleted messages:
- Soft delete (deleted_at column) for 7 days (undo grace period)
- Hard delete after 7 days (GDPR compliance)
- Media: Mark for deletion in S3 (lifecycle policy purges after 30 days)

## End-to-End Encryption (E2EE)

**Decision: Optional E2EE (Signal Protocol) for private chats**

Why optional?
- E2EE prevents server-side moderation/search
- Enterprise customers need compliance (audit logs, e-discovery)

Signal Protocol (Double Ratchet):
- Each device has identity key + signed pre-keys
- Key exchange via server (relay only; no access to keys)
- Forward secrecy: New key per message
- Server stores encrypted payloads; can't read content

Implementation:
- Client-side encryption before sending to WebSocket
- Server forwards encrypted blob
- Recipient decrypts locally
- Media: Encrypt before S3 upload; share key via encrypted message

Trade-off: Increased client complexity; ~20% battery/CPU overhead.

## Rate Limiting Strategy

**Decision: Multi-layer rate limits**

Per-user limits:
- 100 messages/minute (burst protection)
- 50 group creates/hour (spam prevention)
- 1000 API calls/minute (DoS protection)

Per-IP limits (at LB):
- 10K requests/sec (protects backend from DDoS)

Per-conversation limits:
- 1000 messages/minute (prevents spam in large groups)

Implementation:
- Redis Token Bucket algorithm
- Distributed counters with sliding window
- Return 429 Too Many Requests with Retry-After header

Bypass for VIPs:
- Separate rate limit tier for paid/enterprise accounts

## Presence Accuracy vs Cost

**Decision: 60-second TTL with optimistic updates**

Fully accurate presence:
- Requires heartbeat every second → 10M users × 1Hz = 10M writes/sec to Redis
- Cost: ~$100K/month in Redis cluster

Our approach:
- Client sends heartbeat every 30s
- Server sets Redis key: `user:{id}:presence` with 60s TTL
- If no heartbeat in 60s → key expires → user marked offline
- Optimistic: Show "online" even during 30-60s window without heartbeat

Edge case: User closes app → appears online for up to 60s
- Acceptable: "last seen" timestamp shown after 60s
- Critical scenarios (video call) use explicit presence ping

Trade-off: 60s staleness for 99% cost reduction.

