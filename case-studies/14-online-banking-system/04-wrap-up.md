# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M accounts**
- Single-region PostgreSQL; read replicas; Kafka for events; basic fraud rules
- ACH/wires via partner bank; card processor integration

**1M → 20M accounts**
- Partition ledger by account range; hot/cold storage; snapshot balances
- Feature store + ML for fraud; case management tooling
- Active-active read paths; disaster recovery runbooks

**20M → 100M+ accounts**
- Multi-region active-active with strongly consistent ledger shards (per-region); global routing by account hash
- Reconciliation automation; GL at scale; regulatory reporting pipelines

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Ledger partition failure | Cannot post transactions | Write errors; latency spikes | Fail closed; read-only mode; promote standby shard; backlog replay |
| PSP outage | Card auth declines | Error rates spike | Failover to secondary PSP; risk-based soft declines |
| ACH file rejection | Settlement delays | NACHA return codes | Rebuild file; manual review; customer comms |
| Fraud model drift | False positives/negatives | Precision/recall drop | Retrain; rollback model; adjust thresholds |
| Reconciliation diffs | Financial risk | Diff > threshold | Auto-resolve; escalate to ops; freeze impacted accounts if necessary |

---

## SLOs

- Card auth p95 < 300ms; approval rate > 98% good traffic
- Internal transfer p95 < 800ms; zero double-spend
- Reconciliation diffs < 1 ppm; GL posting completion < 2h after close
- Fraud review backlog SLA < 24h

---

## Common Pitfalls

1. Missing idempotency on retries → duplicate postings
2. Blending available and ledger balance → confusion and overdrafts
3. Weak audit trails → compliance issues; use immutable logs (WORM)
4. Over-reliance on single PSP or bank partner → add redundancy
5. Skipping backtests on fraud model changes → revenue loss or user lockouts

---

## Interview Talking Points

- Double-entry ledger mechanics and ACID guarantees
- Holds vs. postings and available vs. ledger balance
- Idempotency strategy across APIs and ledger
- Reconciliation flow and why it's essential
- Hybrid fraud detection and model governance

---

## Follow-Up Questions

- How to support multi-currency and FX fees?
- How to implement real-time payments (RTP) with 24/7 availability?
- How to onboard business accounts with multi-user approvals?
- How to meet regional regulations (PSD2 SCA, GDPR data residency)?
