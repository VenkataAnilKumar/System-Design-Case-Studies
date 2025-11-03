# 3) Key Design Decisions & Trade-Offs

## 1. Ledger Storage: RDBMS vs. Event Store

**Decision**: RDBMS (PostgreSQL) with strict ACID + append-only entries.

**Rationale**: Mature transactions; strong consistency; easy auditing.

**Trade-off**: Horizontal write scaling requires partitioning by account or batch.

**When to reconsider**: If throughput > 50K TPS writes; consider sharding or specialized ledger engines.

---

## 2. Idempotency Boundaries

**Decision**: Idempotency at API (client-provided key) and at Posting Batch level.

**Rationale**: Network retries common; ensures exactly-once effect.

**Trade-off**: Key management and dedupe windows; risk of key reuse mistakes.

**When to reconsider**: Never for money-moving APIs; keep strict.

---

## 3. Strong vs. Eventual Consistency

**Decision**: Strong for ledger/balances; eventual for analytics and notifications.

**Rationale**: Financial correctness > availability; analytics can lag.

**Trade-off**: May reduce availability during partitions.

**When to reconsider**: For read-only features during incidents, use stale reads from replicas.

---

## 4. Fraud: Rules vs. ML

**Decision**: Hybrid — rules for explainability; ML for recall.

**Rationale**: Compliance requires explainability; ML catches complex patterns.

**Trade-off**: Model governance and drift; false positives hurt UX.

**When to reconsider**: Start rules-only; add ML when data maturity allows.

---

## 5. Card Processing: Build vs. Buy

**Decision**: Buy (processor) initially; build abstraction for future.

**Rationale**: Compliance and network certifications are heavy; time-to-market.

**Trade-off**: Less control; fees.

**When to reconsider**: Scale and margin justify partial insourcing.

---

## 6. Reconciliation: Real-Time vs. Batch

**Decision**: Batch end-of-day with near-real-time sanity checks.

**Rationale**: Networks provide files on cadence; batch aligns with them.

**Trade-off**: Intraday drift must be tolerated; need alerts for anomalies.

**When to reconsider**: Real-time feeds (e.g., RTP) can support continuous reconciliation.
