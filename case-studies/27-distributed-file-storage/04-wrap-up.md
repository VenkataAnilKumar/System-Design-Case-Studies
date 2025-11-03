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
