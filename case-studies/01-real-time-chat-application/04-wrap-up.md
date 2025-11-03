# 4) Scale, Failures & Wrap-Up# Chapter 4 · Scale, Failures, and Wrap-Up (Concise)



## Scaling Plan (0 → 100M Users)> Goal: Practical production notes you can recall in an interview. Short and useful.



### Phase 1: MVP (0-100K users)---

- Single-region deployment (1 AZ)

- 5 WebSocket servers (2K connections each)## How we scale (simple playbook)

- 1 PostgreSQL primary + 2 read replicas

- Single Redis instance (16GB)- **Connections**: add WebSocket instances (sticky by user)

- Monolithic Message Service- **Reads**: add Redis capacity; increase cache coverage; raise TTLs for hot sets

- **Writes**: add DB shards (by conversation_id); add replicas for read scaling

Bottleneck: PostgreSQL writes (~10K/sec)- **Fan-out**: add Kafka partitions and workers; keep synchronous path slim

- **Media**: push more via CDN; tune image/video compression & variants

### Phase 2: Growth (100K - 10M users)

- Multi-AZ deployment---

- 50 WebSocket servers (load balanced)

- Shard PostgreSQL: 4 shards (conversation_id hashing)## What can fail (and how we recover)

- Redis Cluster (6 nodes, 96GB total)

- Split services: Message, Presence, Group, Notification1) **WebSocket server crash**

- Impact: a slice of users disconnect

Bottleneck: Cross-server routing (Redis Pub/Sub)- Auto-recovery: clients reconnect with backoff; new WS instance takes over

- Mitigation: health checks, rolling deploys, circuit breakers

### Phase 3: Scale (10M - 100M users)

- Multi-region (US, EU, Asia)2) **Redis node down**

- 1000+ WebSocket servers (auto-scaling)- Impact: cache misses → higher DB load

- PostgreSQL: 10+ shards per region- Recovery: Redis cluster failover; warm critical keys (presence, hot convos)

- Redis Cluster: 50+ nodes- Mitigation: graceful cache-miss path; alert on hit ratio drop

- Kafka for cross-region sync

- CDN for media (99% cache hit)3) **DB primary down (one shard)**

- Impact: writes fail for that shard

Bottleneck: Hot shards (viral conversations)- Recovery: promote replica to primary; resume in ~30–60s

- Mitigation: per-shard isolation; backpressure + retries in WS/API

### Capacity Numbers

4) **Kafka backlog**

| Component | Capacity per Instance | Instances Needed @ 100M DAU |- Impact: delayed notifications/fan-out (messages still stored)

|-----------|----------------------|----------------------------|- Recovery: scale consumers, add partitions, purge DLQ if needed

| WebSocket Servers | 10K connections | 1,000 (10M concurrent) |- Mitigation: alerts on consumer lag; idempotent consumers

| Message Service | 5K RPS | 35 (174K peak) |

| PostgreSQL Shards | 10K writes/sec | 20 (with headroom) |---

| Redis Cluster | 50K ops/sec | 10 nodes |

| Kafka Brokers | 100K msg/sec | 6 (3x replication) |## Monitoring cheat-sheet (Golden Signals)



## Failure Modes & Mitigation- Latency: WS send/receive; API p50/p95; DB query times

- Traffic: messages/sec; active connections; cache ops/sec

### 1. WebSocket Server Crash- Errors: send failures; 5xx rate; consumer retries/DLQ size

- Saturation: CPU/mem per pod; Redis memory; DB connections; Kafka lag

**Impact:** 10K users disconnected

Business KPIs

**Detection:** Load balancer health check fails (2 consecutive missed pings)- Delivered/sent ratio; delivery time p95

- DAU/MAU; messages per DAU; notification open rate

**Auto-recovery:**

- Clients receive connection close event---

- Exponential backoff reconnect: 1s, 2s, 4s, max 30s

- LB routes to healthy servers## Common pitfalls (avoid these)

- Client fetches missed messages: `GET /messages?since={last_seen_ts}`

- Using polling where WebSocket is clearly needed

**Mitigation:**- No sticky sessions for WS (cross-server routing pain)

- Rolling deploys with connection draining (30s grace period)- Over-caching without sensible TTLs/invalidation paths

- Pre-warm replacement servers- Under-sharding early (painful re-shards) or over-sharding early (ops overhead)

- Circuit breaker if >50% servers unhealthy → fallback to HTTP polling- Leaking content in push notifications



**SLA Impact:** ~2-5s downtime per user (reconnect time)---



### 2. PostgreSQL Primary Failure (Single Shard)## Trade-offs summary



**Impact:** Writes fail for conversations on that shard (~10% of traffic)| Decision | Benefit | Cost | Alternative |

|---|---|---|---|

**Detection:** | WebSocket over polling | Real-time, efficient | Sticky LB | Long polling/SSE |

- Health check: Failed write operation| PostgreSQL over Cassandra | Strong ordering | Sharding work | Cassandra (eventual) |

- Replication lag alert: Replica not receiving updates| Redis caching | 10× faster reads | Invalidation | DB-only (slower) |

| Kafka async fan-out | Snappy UX, decoupled | Added infra | Sync fan-out (slow) |

**Recovery:**| CDN for media | Cheap, fast, global | Cache control | Direct-from-DB (costly) |

1. Automatic failover: Promote read replica to primary (30-60s)

2. Update connection pool to point to new primary---

3. Retry queued writes (Kafka buffer holds messages)

## Interview talking points

**Mitigation:**

- Per-shard isolation: Other shards unaffected- How you keep message ordering (single-shard per conversation; ACID)

- Retry logic with exponential backoff (3 attempts)- Why WS + sticky LB; what Redis Pub/Sub is used for

- Kafka as write-ahead log (replay on recovery)- Fan-out via Kafka; when to switch to pull for huge groups

- Alert on replication lag >30s- Read-after-write consistency and presence with TTLs



**SLA Impact:** 30-60s write unavailability for 10% of users; reads unaffected (replicas healthy)---



### 3. Redis Cluster Partial Failure## Follow-up interview Q&A (quick)



**Impact:** - Q: How do you scale writes when one shard gets hot?

- Presence data stale (users show offline incorrectly)	- A: Rebalance by increasing shard count and migrating hot conversations; temporarily raise cache TTLs and enable backpressure.

- Cache misses → increased DB load- Q: What if Redis goes down—do we lose messages?

- Pub/Sub delivery delays	- A: No. Redis is a cache/bus. The source of truth is PostgreSQL; delivery can fall back to polling/sync until Redis recovers.

- Q: Why not use a single queue per user instead of Redis Pub/Sub?

**Detection:**	- A: Pub/Sub keeps routing simple and fast across WS servers; per-user durable queues explode cardinality and ops cost.

- Cache hit ratio drops below 85%- Q: How do you ensure users read their own writes immediately?

- Redis command latency >10ms	- A: Read-after-write policy: briefly read from primary after a write or until replica catches up.

- Q: When would you choose long polling over WebSocket?

**Auto-recovery:**	- A: Very small scale, intermittent updates, or restricted environments where persistent connections are unreliable.

- Redis Cluster rebalances: Slaves promoted, data redistributed

- Recovery time: 5-10s---



**Mitigation:**## Wrap-up

- Cache-aside pattern: Always fetch from DB on miss

- Presence degradation: Show "last seen X minutes ago" instead of live statusThis design favors correctness and simplicity: WebSocket + PostgreSQL + Redis + Kafka + S3/CDN. It scales horizontally, keeps the sync path tight, and moves heavy work to async. It’s a practical template you can adapt to most chat-like systems.

- Pub/Sub fallback: Kafka-based delivery (slower but reliable)
- Circuit breaker on Redis: Bypass cache if unavailable

**SLA Impact:** Minimal; system degrades gracefully (higher latency, no data loss)

### 4. Kafka Consumer Lag

**Impact:** 
- Delayed push notifications (offline users don't get alerts)
- Search index stale
- Analytics delayed

**Detection:**
- Consumer lag >50K messages
- Lag time >5 minutes

**Recovery:**
1. Scale consumers horizontally (add more instances)
2. Increase parallelism (more partitions)
3. Prioritize topics: Drain `offline_messages` before `analytics`

**Mitigation:**
- Idempotent consumers (replay safe)
- Dead Letter Queue (DLQ) for poison pills
- Alert on lag growth rate (not absolute lag)

**SLA Impact:** Non-critical path; online delivery unaffected

### 5. Network Partition (Split Brain)

**Impact:** Multi-region: US can't reach EU region

**Detection:**
- Cross-region health checks fail
- Kafka replication lag spikes

**Recovery:**
- Each region operates independently (Active-Active)
- Conflict resolution via CRDT when partition heals
- Messages converge eventually (append-only log)

**Mitigation:**
- Region-local reads/writes (no cross-region dependencies)
- Conflict-free data model (timestamps for ordering)
- Manual intervention only if CRDT divergence detected

**SLA Impact:** No user-visible impact; regions isolated

## Monitoring & Alerts (SLO-Based)

### Critical (Page On-Call)

- Message send latency p99 >150ms for 5 minutes
- WebSocket reconnect rate >10% for 2 minutes
- PostgreSQL write errors >1% for 1 minute
- Kafka consumer lag >100K messages

### Warning (Ticket Next Day)

- Cache hit ratio <85% for 10 minutes
- Redis memory >80%
- Disk usage per shard >70%
- Dead Letter Queue size >1000

### Dashboards

1. **Real-time Overview**
   - Messages/sec (sent, delivered, read)
   - Active connections per server
   - P50/P95/P99 send latency

2. **Health**
   - Service error rates (per endpoint)
   - Database connection pool usage
   - Kafka consumer lag per topic
   - Circuit breaker states

3. **Business Metrics**
   - DAU/MAU
   - Messages per user per day
   - Group vs 1-on-1 ratio
   - Media upload success rate

## Operational Runbooks

### Runbook 1: Graceful WebSocket Drain (Deployment)

```
1. Mark server as "draining" in LB (stop accepting new connections)
2. Send "server_maintenance" event to all connected clients
3. Clients initiate reconnect to other servers
4. Wait 60s for graceful disconnect (or until <50 connections)
5. Force-close remaining connections
6. Deploy new version
7. Re-add to LB pool
```

### Runbook 2: Hot Shard Mitigation

```
1. Identify hot shard: Write latency >100ms p99 or storage >1TB
2. Analyze: Single conversation causing spike? (Query top 10 by message count)
3. Apply rate limit: conversation_id-based throttle (max 100 msg/min)
4. Plan split: Create new shard; migrate 50% of conversations
5. Update routing table: conversation_id hash → new shard mapping
6. Dual-write period: Write to both old and new shards (1 hour)
7. Cutover: Redirect reads to new shard; stop dual-write
```

### Runbook 3: Kafka DLQ Replay

```
1. Investigate poison pill: Check DLQ for error patterns
2. Fix consumer bug; deploy patched version
3. Pause live consumption: Stop consumers from main topic
4. Replay DLQ:
   kafka-console-consumer --topic offline_messages_dlq \
     --from-beginning | kafka-console-producer --topic offline_messages
5. Verify: Check consumer lag decreases; no new DLQ entries
6. Resume live consumption
```

## Cost Breakdown (100M DAU)

| Component | Cost/Month |
|-----------|-----------|
| WebSocket Servers (1000 × c5.2xlarge) | $250K |
| PostgreSQL (20 shards × db.r5.4xlarge) | $200K |
| Redis Cluster (50 nodes × r5.xlarge) | $80K |
| Kafka (6 brokers × m5.2xlarge) | $25K |
| S3 Storage (2.25PB media) | $50K |
| CloudFront (CDN, 10PB/month) | $100K |
| Data Transfer (egress) | $150K |
| **Total Infrastructure** | **$855K/month** |

**Cost per DAU:** $0.00855 ($8.55 per 1000 users)

Optimization opportunities:
- Reserved instances: -40% compute cost
- S3 Intelligent-Tiering: -30% storage cost
- Spot instances for Kafka consumers: -70% worker cost

## Trade-Offs Summary

| Decision | What We Gain | What We Lose |
|----------|-------------|--------------|
| WebSocket over HTTP | Real-time latency, lower bandwidth | Connection management complexity |
| PostgreSQL over Cassandra | Strong consistency, ACID | Manual sharding, vertical scaling limit |
| Redis Pub/Sub + Kafka hybrid | Fast online + reliable offline | Two messaging systems to maintain |
| ULID message IDs | Time-sortable, no coordination | 128-bit size (vs 64-bit Snowflake) |
| 60s presence TTL | 99% cost reduction | Up to 60s staleness |
| Multi-region Active-Active | Low latency globally, HA | Eventual consistency across regions |

## Key Takeaways

1. **Consistency over availability:** Chat requires strict message ordering; chose PostgreSQL + ACID over eventual consistency
2. **Hybrid sync/async:** Online delivery via Redis Pub/Sub (fast); offline via Kafka (reliable)
3. **Shard by conversation:** Keeps related data together; avoids distributed transactions
4. **Graceful degradation:** Redis down → fetch from DB; WebSocket down → HTTP fallback
5. **Idempotency everywhere:** Client-generated IDs prevent duplicates on retries
6. **ML as enhancement:** Moderation, ranking, search improve UX without breaking core guarantees
7. **Observe the tails:** p99 latency matters more than avg; monitor per-shard/per-server metrics

## References

- **WebSocket at Scale:** Slack Engineering - Job Queue and Connection Management
- **Discord Architecture:** How Discord Stores Billions of Messages (Cassandra → ScyllaDB migration)
- **WhatsApp Scale:** 1M connections per server using Erlang (Rick Reed talk)
- **Message Ordering:** DDIA Chapter 5 (Replication) and Chapter 7 (Transactions)
- **ULID Spec:** https://github.com/ulid/spec
- **Signal Protocol:** Double Ratchet Algorithm (E2EE)
- **CRDT for Multi-Region:** Conflict-Free Replicated Data Types (Shapiro et al.)

