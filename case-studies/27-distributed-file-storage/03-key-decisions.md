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
