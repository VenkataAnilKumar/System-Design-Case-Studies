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
