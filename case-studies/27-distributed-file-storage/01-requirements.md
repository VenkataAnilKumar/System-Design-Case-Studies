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
