# Chapter 4 — Scale, Failures & Wrap-Up

> Practical production notes for the real-time chat system. Covers the scaling playbook from MVP to 100M users, how each component fails and recovers, monitoring, runbooks, cost, and key takeaways.

---

## Contents

1. [Scaling Playbook (0 → 100M Users)](#1-scaling-playbook-0--100m-users)
2. [Failure Modes & Mitigation](#2-failure-modes--mitigation)
3. [Monitoring & Alerts](#3-monitoring--alerts)
4. [Operational Runbooks](#4-operational-runbooks)
5. [Cost Breakdown](#5-cost-breakdown)
6. [Trade-Offs Summary](#6-trade-offs-summary)
7. [Key Takeaways](#7-key-takeaways)
8. [Interview Quick Reference](#8-interview-quick-reference)

---

## 1. Scaling Playbook (0 → 100M Users)

### Phase 1 — MVP (0–100K users)

- Single-region, single AZ
- 5 WebSocket servers (2K connections each)
- 1 PostgreSQL primary + 2 read replicas (unsharded)
- 1 Redis instance (16 GB)
- Monolithic message service

**Bottleneck:** PostgreSQL write throughput (~10K writes/s single node)

---

### Phase 2 — Growth (100K–10M users)

- Multi-AZ deployment
- 50 WebSocket servers (consistent-hash load balancing)
- PostgreSQL sharded: 4 shards, keyed by `conversation_id`
- Redis Cluster (6 nodes, 96 GB total)
- Services split into Message, Presence, Group, and Notification

**Bottleneck:** Cross-server routing via Redis Pub/Sub under peak fan-out load

---

### Phase 3 — Scale (10M–100M users)

- Multi-region (US, EU, Asia-Pacific)
- 1,000+ WebSocket servers (auto-scaling)
- PostgreSQL: 20+ shards per region, 4 replicas each
- Redis Cluster: 50+ nodes
- Kafka for cross-region sync (MirrorMaker 2)
- CDN for media (99%+ cache hit ratio)

**Bottleneck:** Hot shards from viral conversations

---

### Capacity Numbers @ 100M DAU

| Component | Per-Instance Capacity | Instances Needed |
|---|---|---|
| WebSocket servers | 10K connections | 1,000 (10M concurrent) |
| Message service | 5K RPS | 70 (345K peak) |
| PostgreSQL shards | 10K writes/s | 40 (with headroom) |
| Redis cluster | 50K ops/s | 10 nodes |
| Kafka brokers | 100K msg/s | 6 (3× replication) |

**Scaling triggers:**
- WebSocket: add a server when avg connections >8K
- API: add when p95 latency >100ms or CPU >70%
- Redis: add nodes when memory >80%; enable cluster mode above 100 GB
- PostgreSQL: add shards when writes >8K/s or storage >1 TB per shard
- Kafka: add partitions when sustained throughput >100K msg/s

---

## 2. Failure Modes & Mitigation

### 1. WebSocket Server Crash

**Impact:** 10K users disconnected

**Detection:** Load balancer health check fails (2 consecutive missed pings)

**Recovery:**
1. Clients receive connection-close event.
2. Exponential backoff reconnect: 1s, 2s, 4s, max 30s.
3. LB routes new connections to healthy servers.
4. Client fetches missed messages: `GET /messages?since={last_seen_ts}`.

**Mitigation:**
- Rolling deploys with 30s connection-draining grace period
- Pre-warm replacement servers before they enter the LB pool
- Circuit breaker: if >50% of servers are unhealthy → fall back to HTTP polling

**SLA impact:** ~2–5s downtime per user (reconnect time)

---

### 2. PostgreSQL Primary Failure (Single Shard)

**Impact:** Writes fail for conversations on that shard (~5% of traffic per shard)

**Detection:**
- Health check: failed write operations
- Replication lag alert: replica not receiving updates within 30s

**Recovery:**
1. Automatic failover: promote read replica to primary (30–60s).
2. Update connection pool to point to the new primary.
3. Replay queued writes from the Kafka buffer.

**Mitigation:**
- Per-shard isolation: all other shards remain unaffected
- Exponential backoff + retry (3 attempts) in the Message Service
- Kafka acts as a write-ahead log; no messages are lost during failover
- Alert on replication lag >30s

**SLA impact:** 30–60s write unavailability for 5–10% of users; reads unaffected (replicas remain healthy)

---

### 3. Redis Cluster Partial Failure

**Impact:**
- Presence data stale — users may show online incorrectly
- Cache misses → increased DB load (up to 10× read amplification)
- Pub/Sub delivery delays for online routing

**Detection:**
- Cache hit ratio drops below 85%
- Redis command latency p99 >10ms

**Recovery:**
1. Redis Cluster automatically promotes replicas to primary (5–10s).
2. Cache rebuilds via cache-aside on subsequent reads.

**Mitigation:**
- Cache-aside pattern: always fall through to DB on a miss
- Presence degrades gracefully: show "last seen X minutes ago" instead of live status
- Pub/Sub fallback: Kafka-based delivery kicks in (slower but reliable)
- Circuit breaker on Redis: bypass cache entirely if the cluster is unavailable

**SLA impact:** Minimal; system degrades gracefully with higher latency but no data loss

---

### 4. Kafka Consumer Lag

**Impact:**
- Delayed push notifications for offline users
- Search index becomes stale
- Analytics pipeline delayed

**Detection:**
- Consumer lag >50K messages in the `offline_messages` topic
- Lag growing faster than consumption rate

**Recovery:**
1. Scale consumers horizontally (add instances).
2. Increase partition count for higher parallelism.
3. Prioritize draining `offline_messages` before `analytics`.

**Mitigation:**
- Idempotent consumers (safe to replay)
- Dead-letter queue (DLQ) for poison messages
- Alert on lag growth rate, not just absolute lag size

**SLA impact:** Non-critical path; online delivery is unaffected

---

### 5. Network Partition (Multi-Region Split Brain)

**Impact:** US region cannot reach EU region; cross-region Kafka replication stalls

**Detection:**
- Cross-region health checks fail
- Kafka MirrorMaker replication lag spikes

**Recovery:**
- Each region operates independently in Active-Active mode.
- CRDT conflict resolution runs when the partition heals.
- Messages converge via the append-only log (ULID ordering).

**Mitigation:**
- Region-local reads/writes; no cross-region dependencies in the hot path
- Conflict-free data model: append-only messages, last-write-wins for presence
- Manual intervention only if CRDT divergence is detected

**SLA impact:** No user-visible impact; each region continues serving its local users independently

---

## 3. Monitoring & Alerts

### Dashboards

**1. Real-Time Overview**
- Messages/s (sent, delivered, read)
- Active WebSocket connections per server
- p50/p95/p99 send latency

**2. Health**
- Service error rates per endpoint
- Database connection pool saturation
- Kafka consumer lag per topic
- Circuit breaker states

**3. Business Metrics**
- DAU/MAU ratio
- Messages per user per day
- Group vs 1-on-1 message ratio
- Media upload success rate

---

### Alerts

**Critical — page on-call immediately:**
- Message send latency p99 >150ms sustained for 5 minutes
- WebSocket reconnect rate >10% over 2 minutes
- PostgreSQL write errors >1% over 1 minute
- Kafka consumer lag >100K messages

**Warning — ticket for next business day:**
- Cache hit ratio <85% for 10 minutes
- Redis memory >80%
- Disk usage per shard >70%
- Dead-letter queue size >1,000 messages

---

## 4. Operational Runbooks

### Runbook 1 — Graceful WebSocket Drain (Deployment)

1. Mark the server instance as "draining" in the load balancer (stop accepting new connections).
2. Broadcast a `server_maintenance` event to all currently connected clients.
3. Clients receive the event and reconnect to other servers.
4. Wait up to 60s for graceful disconnects (or until fewer than 50 active connections remain).
5. Force-close any remaining connections with a `Retry-After` header.
6. Deploy the new version.
7. Re-add the instance to the LB pool.

---

### Runbook 2 — Hot Shard Mitigation (PostgreSQL)

1. Identify the hot shard: write latency >100ms p99 or storage >1 TB.
2. Analyze root cause: query top 10 conversations by message count on that shard.
3. Apply a per-conversation rate limit: `conversation_id`-based throttle (max 100 msg/min).
4. Plan the split: create a new shard targeting 50% of the hot shard's conversations.
5. Update the routing table: `HASH(conversation_id) % new_shard_count` mapping.
6. Dual-write period: write to both old and new shards for 1 hour.
7. Cutover: redirect reads to the new shard; stop dual-write; monitor for errors.

---

### Runbook 3 — Kafka DLQ Replay

1. Investigate poison messages: review DLQ error patterns and stack traces.
2. Deploy a patched consumer that handles the offending message format.
3. Pause live consumption on the affected topic.
4. Replay DLQ messages to the original topic:

```bash
kafka-console-consumer --topic offline_messages_dlq --from-beginning \
  | kafka-console-producer --topic offline_messages
```

5. Monitor: confirm consumer lag decreases and no new DLQ entries appear.
6. Resume live consumption.

---

## 5. Cost Breakdown (100M DAU — AWS Reference Pricing)

| Component | Configuration | Monthly Cost |
|---|---|---|
| WebSocket servers | 1,000 × c5.2xlarge | $250K |
| PostgreSQL | 40 shards × db.r5.4xlarge | $400K |
| Redis cluster | 50 nodes × r5.xlarge | $80K |
| Kafka | 6 brokers × m5.2xlarge | $25K |
| S3 storage | 4.5 PB media (growing) | $100K |
| CloudFront CDN | 10 PB/month egress | $100K |
| Data transfer | Cross-AZ + egress | $100K |
| **Total** | | **~$1.05M/month** |

**Cost per DAU:** ~$0.0105 ($10.50 per 1,000 users)

**Optimization levers:**
- Reserved instances: −40% on compute
- S3 Intelligent-Tiering: −30% on storage costs
- Spot instances for Kafka consumers: −70% on worker compute

---

## 6. Trade-Offs Summary

| Decision | What We Gain | What We Give Up |
|---|---|---|
| WebSocket over HTTP | Real-time latency, lower bandwidth | Connection state management complexity |
| PostgreSQL over Cassandra | Strong ordering, ACID | Manual sharding; vertical scaling ceiling |
| Redis Pub/Sub + Kafka hybrid | Fast online + reliable offline | Two messaging systems to operate |
| ULID message IDs | Time-sortable, no coordinator | 128-bit size (vs 64-bit Snowflake) |
| 60s presence TTL | 99% cost reduction | Up to 60s staleness |
| Multi-region Active-Active | Low global latency, high availability | Eventual consistency across regions |

---

## 7. Key Takeaways

1. **Ordering over throughput**: Chat requires strict message ordering per conversation; PostgreSQL + ACID was chosen over Cassandra's higher write TPS.
2. **Hybrid sync/async**: Redis Pub/Sub for the fast online path; Kafka for the durable offline path.
3. **Shard by conversation**: Keeps all messages for a conversation on one shard; avoids distributed transactions.
4. **Graceful degradation**: Redis down → fall through to DB; WebSocket unavailable → fall back to HTTP polling.
5. **Idempotency everywhere**: Client-generated `client_msg_id` prevents duplicates on retries.
6. **ML as enhancement**: Moderation, notification ranking, and search improve UX without altering core delivery guarantees.
7. **Tail latency matters**: Monitor p99, not p50. Per-shard and per-server metrics catch hot spots before they cascade.

---

## 8. Interview Quick Reference

**Common pitfalls to call out:**
- Polling instead of WebSocket (10M RPS just for keep-alive at 10M users)
- Missing sticky sessions for WS servers (breaks cross-server routing)
- Over-caching without TTL discipline (stale group membership)
- Under-sharding early (re-shard is painful) or over-sharding early (ops overhead)
- Leaking message content in push notification payloads

**Key talking points:**
- Message ordering: single-shard per conversation + ACID write
- WebSocket + sticky LB; Redis Pub/Sub for cross-server routing
- Group fan-out via Kafka; pull-dominant for celebrity groups (>1K members)
- Read-after-write consistency: read from the primary briefly after a write
- Presence with 30s heartbeat + 60s TTL: 99% cost savings vs exact tracking

**Follow-up Q&A:**

| Question | Answer |
|---|---|
| Hot shard handling? | Increase shard count; migrate hot conversations; rate-limit per conversation |
| Redis goes down — messages lost? | No. Redis is cache + routing bus only; PostgreSQL is the source of truth |
| Why Redis Pub/Sub instead of per-user Kafka queue? | Pub/Sub is sub-ms; per-user durable queues explode cardinality and ops cost |
| Read-your-own-writes guarantee? | Read from primary (or replica with lag check) after a write |
| When to choose long polling over WebSocket? | Small scale, intermittent updates, or WebSocket-blocked environments |

---

## References

- **WebSocket at Scale**: Slack Engineering — Job Queue and Connection Management
- **Discord Architecture**: How Discord Stores Billions of Messages (Cassandra → ScyllaDB migration)
- **WhatsApp Scale**: 1M connections per server using Erlang (Rick Reed, SIGMOD 2012)
- **Message Ordering**: DDIA Ch. 5 (Replication) and Ch. 7 (Transactions) — Kleppmann
- **ULID Spec**: https://github.com/ulid/spec
- **Signal Protocol**: Double Ratchet Algorithm — Marlinspike & Perrin
- **CRDT for Multi-Region**: Conflict-Free Replicated Data Types — Shapiro et al.
