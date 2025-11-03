# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
	subgraph Clients
		App1[App Service]
		App2[Batch Job]
	end

	subgraph Access
		ClientLib[Smart Client Library]
		Proxy[Cache Proxy (Twemproxy/Envoy)]
	end

	subgraph Cache Cluster
		CHRing[Consistent Hash Ring]
		NodeA[Cache Node A]
		NodeB[Cache Node B]
		NodeC[Cache Node C]
		ReplicaA[Replica A]
		ReplicaB[Replica B]
	end

	subgraph Persistence
		AOF[(AOF Log)]
		RDB[(RDB Snapshots)]
	end

	subgraph Control
		Sentinel[Sentinel/Raft\nFailover]
		Metrics[Monitoring]
	end

	App1 --> ClientLib
	App2 --> Proxy
	ClientLib --> CHRing
	Proxy --> CHRing
	CHRing --> NodeA
	CHRing --> NodeB
	CHRing --> NodeC
	NodeA --> ReplicaA
	NodeB --> ReplicaB
  
	NodeA --> AOF
	NodeA --> RDB
	NodeB --> AOF
	NodeB --> RDB
  
	Sentinel -.-> NodeA
	Sentinel -.-> NodeB
	Metrics -.-> NodeA
	Metrics -.-> NodeB
```

## Components

- Cache Nodes: In-memory storage (Redis/Memcached); single-threaded or multi-threaded
- Consistent Hashing Ring: Virtual nodes (1000/physical node); rebalance on add/remove
- Replication: Master-replica per shard; async replication; sentinel/raft for failover
- Client Library: Smart client; maintains hash ring; routes requests; connection pooling
- Proxy Layer (Optional): Twemproxy/Envoy for legacy clients; routing + load balancing
- Persistence: RDB snapshots (forked process); AOF (append-only log); hybrid
- Monitoring: Metrics (hit rate, evictions, latency); slow log; memory usage

## Data Flows

### A) GET (Cache Hit)

1) Client hashes key → node ID via consistent hashing
2) Send GET to node; node looks up key in hash table (O(1))
3) If exists → return value; update LRU metadata
4) If TTL expired → return null; evict key

### B) SET (Write)

1) Client hashes key → node ID
2) Send SET to master node; master writes to memory
3) If persistence enabled → append to AOF; async flush to disk
4) Async replicate to replica nodes (eventually consistent)
5) Return success to client

### C) Node Failure & Failover

1) Sentinel detects master down (3 heartbeats missed)
2) Sentinel quorum votes; promote replica to master
3) Update hash ring; notify clients (via pub/sub or health check)
4) Clients reroute traffic to new master

### D) Rebalancing (Add Node)

1) New node joins; hash ring recalculated with virtual nodes
2) Some keys migrate from existing nodes to new node (consistent hashing minimizes moves)
3) Clients update hash ring; start routing new keys to new node
4) Background migration of existing keys (lazy or proactive)

## Data Model

- keys(key, value, ttl, created_at, accessed_at)
- metadata(node_id, memory_used, evictions, hit_rate)
- replication(master_node_id, replica_node_ids[], lag)

## APIs

- GET key
- SET key value [TTL seconds]
- DELETE key
- INCR key
- LPUSH key value (list)
- ZADD key score value (sorted set)
- PUBLISH channel message

Auth: Optional password; TLS for encryption; client cert auth for mTLS.

## Why These Choices

- Consistent hashing: Minimal key movement on node add/remove (only ~1/N keys move)
- Single-threaded per key: Simplifies concurrency; high throughput via multiplexing (epoll)
- Async replication: Lower latency for writes; acceptable for cache (eventual consistency OK)
- Smart client: Avoids proxy hop; lower latency; clients have latest hash ring

## Monitoring

- Hit rate; miss rate; eviction rate
- p50/p95/p99 latency per operation
- Memory usage; fragmentation; swap
- Replication lag; failover events