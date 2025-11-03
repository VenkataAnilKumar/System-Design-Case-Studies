# 3) Key Design Decisions & Trade-Offs

## 1. In-Memory Order Book vs. Persistent DB

**Decision**: In-memory order book per symbol; durability via event sourcing (Kafka).

**Rationale**:
- Matching latency must be <1ms; disk I/O adds 5-10ms
- Order book is small (top 1000 price levels × 100 orders each = ~100K orders per symbol)
- Event log (Kafka) provides durability; can rebuild book on crash

**Trade-off**: Slower recovery on matching engine restart (replay events); mitigated by periodic snapshots.

**When to reconsider**: If symbols have millions of open orders (rare); consider hybrid (top-of-book in memory, rest in DB).

---

## 2. FIFO vs. Pro-Rata Matching

**Decision**: FIFO (price-time priority).

**Rationale**:
- Fair to retail investors; order time matters
- Simpler logic; deterministic; regulatory standard for equities

**Trade-off**: High-frequency traders can "cut in line" with faster links; some futures markets use pro-rata (allocate by order size).

**When to reconsider**: If targeting options/futures (pro-rata common); or if regulations change.

---

## 3. Synchronous vs. Async Position Updates

**Decision**: Synchronous update (strong consistency).

**Rationale**:
- Position must reflect fills immediately; prevent overselling shares
- Risk checks on next order require accurate real-time balance

**Trade-off**: Adds ~2-5ms latency to fill path; could bottleneck at 100K orders/sec.

**When to reconsider**: If latency budget is tighter; use optimistic locking with retry; or pre-allocate "position slots" for pending orders.

---

## 4. Multicast vs. Unicast Market Data

**Decision**: Hybrid—unicast WebSocket for retail; multicast UDP for pros/HFTs.

**Rationale**:
- Retail needs backpressure (slow clients); WebSocket handles gracefully
- Pros require lowest latency (~microseconds); UDP multicast avoids per-client overhead

**Trade-off**: Multicast has no delivery guarantee; clients must handle gaps (sequence numbers).

**When to reconsider**: If user base is 100% retail; skip multicast complexity.

---

## 5. Strong vs. Eventual Consistency for Positions

**Decision**: Strong consistency (ACID transactions).

**Rationale**:
- Financial correctness > latency; no phantom shares or negative cash
- Regulations require audit trail; cannot have "eventually correct" balances

**Trade-off**: Limits horizontal scaling of position service; single DB shard per user.

**When to reconsider**: Never for regulatory compliance; could relax for non-trading features (e.g., portfolio charts can lag by seconds).

---

## 6. Single-Threaded vs. Multi-Threaded Matching

**Decision**: Single-threaded matching per symbol.

**Rationale**:
- FIFO requires deterministic order processing; multi-threading complicates locking
- One symbol's orders are independent of others; parallelize across symbols

**Trade-off**: If one symbol gets 50% of traffic (e.g., AAPL during earnings), that engine becomes bottleneck.

**When to reconsider**: Vertical scaling limit (~500K orders/sec per thread); at that point, partition symbol into sub-symbols (AAPL-A, AAPL-B) and merge at end of day (complex; avoid unless truly needed).

---

## 7. Co-Location vs. Cloud Hosting

**Decision**: Cloud (AWS) for retail platform; co-located for HFT connectors.

**Rationale**:
- Cloud: elastic scaling; 99.99% SLA; lower ops cost
- Co-location: Sub-ms latency to exchanges (NYSE, NASDAQ data centers); required for competitive market-making

**Trade-off**: Co-location is expensive ($10K+/month per rack); only justifiable for pro/HFT tier.

**When to reconsider**: If targeting only retail; stay pure cloud. If adding institutional clients, invest in co-lo.

---

## 8. Pre-Trade vs. Post-Trade Risk Checks

**Decision**: Pre-trade (synchronous).

**Rationale**:
- Regulatory requirement (RegT); cannot allow margin violations
- Prevents bad orders from reaching matching engine (reduces load)

**Trade-off**: Adds 1-2ms to order path; false positives can anger users (e.g., stale buying_power cache).

**When to reconsider**: If latency budget is extremely tight; could do async post-trade checks for certain order types (e.g., small market orders), but risky for compliance.
