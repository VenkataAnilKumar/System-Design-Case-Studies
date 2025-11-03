# 27-distributed-file-storage - Distributed File Storage
Generated: 2025-11-02 20:38:45 -05:00

---

<!-- Source: 01-requirements.md -->
# Requirements & Scale

## Functional Requirements
1. **Object Storage**: PUT/GET/DELETE objects (files) via REST API, identified by unique keys
2. **Versioning**: Store multiple versions of same object, list/retrieve/delete specific versions
3. **Replication**: Cross-region replication for DR, async within 15min
4. **Erasure Coding**: Reduce storage cost (Reed-Solomon k+m encoding: 10+4 = 1.4× overhead vs. 3× replication)
5. **Metadata Search**: List objects by prefix, filter by tags, sort by modified_date
6. **Access Control**: Bucket policies (public/private), signed URLs (temporary access), IAM integration
7. **Lifecycle Management**: Auto-delete after 90 days, transition to cold storage (Glacier) after 30 days

## Non-Functional Requirements
**Durability**: 99.999999999% (11 9's) → lose 1 object per 10 billion per year
**Availability**: 99.99% for standard storage, 99.9% for cold storage
**Latency**: p99 <100ms for hot data (<100MB), <1s for cold data
**Throughput**: 100K requests/sec, 10GB/s aggregate bandwidth
**Cost Efficiency**: $0.023/GB/month standard, $0.004/GB cold (75% cheaper)

## Scale Estimates
**Objects**: 10B objects, 1KB avg size = 10PB total
**Traffic**: 100K req/s (70% GET, 20% PUT, 10% DELETE)
**Storage Growth**: 1PB/month new data
**Hot/Cold Ratio**: 20% hot (accessed weekly), 80% cold (accessed monthly)

**Infrastructure**:
- Storage Nodes: 1000 nodes × 12TB SSD (hot) + 5000 nodes × 12TB HDD (cold) = 72PB capacity
- Metadata DB: 10B objects × 1KB metadata = 10TB (sharded across 100 nodes)
- API Gateway: 50 nodes handling 100K req/s

**Cost**: $1.5M/mo (storage) + $500K (compute) + $200K (network) = **$2.2M/mo**




---

<!-- Source: 02-architecture.md -->
# 2) High-Level Architecture (Most Detailed)

```mermaid
flowchart TB
  subgraph Clients
    App[Client Apps]
  end

  subgraph Edge
    APIGW[API Gateway]
  end

  subgraph Control
    Meta[Metadata Service\n(Cassandra/Dynamo)]
    Chunk[Chunk Manager]
    Repl[Replication Manager]
    Life[Lifecycle Manager]
  end

  subgraph Storage[Storage Tiers]
    Hot[Hot Tier\nSSD]
    Warm[Warm Tier\nHDD]
    Cold[Cold Tier\nArchive]
  end

  App --> APIGW
  APIGW --> Meta
  APIGW --> Chunk
  Chunk --> Hot
  Chunk --> Warm
  Repl --> Warm
  Repl --> Cold
  Life --> Warm
  Life --> Cold
  Meta --- Hot
  Meta --- Warm
  Meta --- Cold
```

## Components

### 1. API Gateway
REST API (PUT /bucket/key, GET /bucket/key) with auth (AWS Signature V4), rate limiting, request routing.

### 2. Metadata Service
Distributed database (Cassandra/DynamoDB) storing object metadata:
```
{object_key, bucket, size, version_id, storage_class, created_at, tags, owner_id}
```
Sharded by hash(bucket+key) for horizontal scaling.

### 3. Data Nodes (Storage Cluster)
- **Hot Tier**: SSDs for frequently accessed objects (<100ms latency)
- **Warm Tier**: HDDs for infrequently accessed (<1s latency)
- **Cold Tier**: Tape/glacier for archival (<5min restore time)

Each object stored with replication (3× copies) or erasure coding (10+4 chunks, 1.4× overhead).

### 4. Chunk Management
Large files (>5MB) split into chunks (5MB each) and distributed across nodes.
**Benefits**: Parallel uploads/downloads, fault tolerance (missing chunk recovered from erasure code).

### 5. Replication Manager
Async replication to secondary regions (cross-region DR).
**Process**: Object written → replicated to 3 nodes in primary region → async copied to secondary region (15min RPO).

### 6. Erasure Coding Engine
Reed-Solomon (10+4): Split object into 10 data chunks + 4 parity chunks → any 10 of 14 chunks can reconstruct original.
**Storage Savings**: 1.4× overhead (10+4=14 chunks, 14/10 = 1.4×) vs. 3× for replication.

### 7. Lifecycle Manager
Background job that:
- Transitions objects to cold storage after 30 days (policy-based)
- Deletes expired objects (90-day retention policy)
- Compacts small objects (combine 1000 × 1KB files into 1MB blob)

## Data Flows

### Flow A: PUT Object
1. Client → API Gateway: `PUT /my-bucket/photo.jpg` (5MB file)
2. API Gateway:
   - Authenticate (check IAM policy)
   - Generate object_id (UUID)
   - Split file into chunks (1MB each × 5 chunks)
3. Chunk Manager:
   - Hash-based placement: chunk_1 → Node A, chunk_2 → Node B, ...
   - Write 3 replicas per chunk (nodes A, B, C)
4. Metadata Service: Insert metadata (object_key, size, version_id, node_locations)
5. API Gateway → Client: `200 OK {version_id: "v123"}`

**Latency**: 5MB / 100MB/s = 50ms upload + 20ms metadata = **70ms total**.

### Flow B: GET Object (Hot Data)
1. Client → API Gateway: `GET /my-bucket/photo.jpg`
2. API Gateway → Metadata Service: Lookup object (get node_locations)
3. Chunk Manager: Read chunks from nodes A, B, C, D, E (parallel)
4. Reassemble chunks → return file
5. API Gateway → Client: `200 OK` + file bytes

**Latency**: 20ms metadata + 50ms read (parallel chunks) = **70ms total**.

### Flow C: Lifecycle Transition (Hot → Cold)
1. Lifecycle Manager (cron job daily): Query metadata for objects >30 days old in hot tier
2. For each object:
   - Copy chunks from SSD nodes → HDD nodes
   - Update metadata (storage_class: "cold")
   - Delete SSD chunks (free space)

## API Design

**Upload Object**:
```http
PUT /bucket/key HTTP/1.1
Host: storage.example.com
Authorization: AWS4-HMAC-SHA256 ...
Content-Type: image/jpeg
Body: <binary data>

Response 200 OK:
{
  "version_id": "v123",
  "etag": "md5hash"
}
```

**Download Object**:
```http
GET /bucket/key HTTP/1.1

Response 200 OK:
Content-Length: 5242880
Body: <binary data>
```

**List Objects**:
```http
GET /bucket?prefix=photos/&max_keys=1000

Response 200 OK:
{
  "objects": [
    {"key": "photos/1.jpg", "size": 5MB, "modified": "2024-01-01"},
    ...
  ],
  "is_truncated": true,
  "next_marker": "photos/1001.jpg"
}
```

## Monitoring
- **Durability**: Track lost chunks (target 0 per year for 11 9's)
- **Availability**: Uptime per region (target 99.99%)
- **Latency**: p50/p95/p99 for GET/PUT operations
- **Storage Cost**: Cost per GB (optimize with erasure coding + lifecycle policies)
- **Replication Lag**: Time to replicate to secondary region (target <15min)




---

<!-- Source: 03-key-decisions.md -->
# Key Technical Decisions

## 1. Replication vs. Erasure Coding
**Decision**: **Replication** for hot data (3×), **erasure coding** for cold data (10+4).
**Rationale**: Replication = faster reads (no reconstruction), erasure coding = cheaper storage (1.4× vs. 3×).
**Reconsider**: If storage cost dominates, use erasure coding everywhere (accept reconstruction latency).

## 2. Metadata: Centralized DB vs. Embedded in Objects
**Decision**: **Centralized metadata DB** (Cassandra).
**Rationale**: Fast prefix listing (SELECT WHERE key LIKE 'photos/%'), consistent views.
**Reconsider**: For small-scale (<1M objects), embed metadata in object headers (simpler).

## 3. Chunk Size: 1MB vs. 5MB vs. 64MB
**Decision**: **5MB chunks** (balance parallelism and overhead).
**Rationale**: 1MB = too many chunks (overhead), 64MB = poor parallelism (single chunk blocks download).
**Reconsider**: For large files (>1GB), use 64MB chunks (fewer metadata entries).

## 4. Consistency: Strong vs. Eventual
**Decision**: **Eventual consistency** for reads (replicas may lag 100ms).
**Rationale**: Availability over consistency (CAP theorem). Most use cases tolerate stale reads.
**Reconsider**: For critical metadata (billing), use strong consistency (quorum reads).

## 5. Cross-Region Replication: Sync vs. Async
**Decision**: **Async replication** (15min RPO).
**Rationale**: Sync replication adds 100ms+ latency (cross-region network RTT). Async is cost-efficient.
**Reconsider**: For disaster recovery SLA <1min RPO, use sync replication (accept latency hit).

## 6. Object Versioning: Enabled by Default vs. Opt-In
**Decision**: **Opt-in versioning** (disabled by default).
**Rationale**: Versioning 2× storage cost (every PUT creates new version). Most users don't need it.
**Reconsider**: For compliance (audit trails), enable versioning by default.

## 7. Garbage Collection: Immediate Delete vs. Soft Delete
**Decision**: **Soft delete** (mark deleted, cleanup after 30 days).
**Rationale**: Allows undelete (user mistakes), reduces metadata churn.
**Reconsider**: For privacy laws (GDPR right to deletion), use immediate hard delete.

## 8. Multi-Part Upload: Client-Managed vs. Server-Managed
**Decision**: **Client-managed** (client splits file, uploads parts, completes).
**Rationale**: Resilient to network failures (resume from last part), supports parallelism.
**Reconsider**: For simple use cases, server-managed (single PUT) is easier.




---

<!-- Source: 04-wrap-up.md -->
# Wrap-Up & Deep Dives

## Scaling Playbook
**Stage 1 (MVP)**: Single-node storage, 1M objects, replication 2×, no versioning.
**Stage 2 (Production)**: 100 nodes, 1B objects, replication 3×, erasure coding for cold data, metadata sharding.
**Stage 3 (Scale)**: 5000 nodes, 10B objects, lifecycle policies (hot→cold→glacier), cross-region replication, intelligent tiering.

## Failure Scenarios
- **Node Failure**: Chunk lost → reconstruct from replicas or erasure-coded chunks.
- **Datacenter Failure**: Cross-region replication ensures data survives regional outage (RPO 15min).
- **Bit Rot**: Periodic scrubbing (checksum validation) detects corruption → reconstruct from parity.

## SLO Commitments
- **Durability**: 99.999999999% (lose <1 object per 10B per year)
- **Availability**: 99.99% standard, 99.9% cold storage
- **Latency**: p99 <100ms hot data, <1s cold data
- **Replication Lag**: <15min for cross-region

## Common Pitfalls
1. **No Erasure Coding**: Replication 3× = 3× cost. Use erasure coding for cold data (1.4× overhead).
2. **Large Chunks**: 100MB chunks = poor parallelism (slow downloads). Use 5MB chunks.
3. **Ignoring Bit Rot**: SSDs/HDDs decay over time. Run monthly scrubbing (checksum validation).
4. **No Lifecycle Policies**: Hot data sits on expensive SSDs forever. Auto-transition to cold after 30 days.
5. **Metadata Hotspots**: Sharding by bucket_name causes hotspots (popular buckets). Use hash(bucket+key).

## Interview Talking Points
- **Erasure Coding**: "Reed-Solomon 10+4 = 1.4× overhead (vs. 3× replication) → 50% cost savings for cold data."
- **11 9's Durability**: "3× replication across AZs + cross-region async replication + periodic scrubbing → lose <1 object per 10B per year."
- **Chunk Placement**: "Consistent hashing assigns chunks to nodes → add node, only 1/N chunks relocate (vs. rehashing all)."
- **Metadata Sharding**: "10B objects × 1KB = 10TB metadata → shard across 100 Cassandra nodes by hash(bucket+key)."

## Follow-Up Questions
1. **Deduplication**: How do you detect and eliminate duplicate files (content-addressable storage, SHA256 hashing)?
2. **Small File Optimization**: Store 1M tiny files (1KB each) efficiently (combine into 1GB blobs)?
3. **Intelligent Tiering**: Automatically move rarely-accessed objects to cold storage (ML-based access prediction)?
4. **Multi-Tenancy**: Isolate buckets per tenant (quotas, rate limits, cost attribution)?
5. **Global Namespace**: Support same bucket name across regions (geo-routing, consistency challenges)?

**Final Thought**: Distributed file storage trades **consistency** for **availability** and **durability**. Erasure coding is the key to achieving 11 9's durability at 1.4× storage overhead (vs. 3× for replication)—but requires complex reconstruction logic. The challenge is balancing cost (storage tiers) with performance (latency SLAs).



