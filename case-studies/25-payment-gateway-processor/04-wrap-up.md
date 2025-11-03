# Wrap-Up & Deep Dives

## Scaling Playbook

### Stage 1: MVP (1K TPS, Single PSP)
**Infrastructure**: 10 API servers, PostgreSQL primary + replica, Stripe integration, basic fraud rules (velocity checks).

**Limitations**: No multi-PSP, no ML fraud detection, manual reconciliation.

---

### Stage 2: Production (5K TPS, Multi-PSP)
**Infrastructure**: 50 API servers, PostgreSQL with read replicas, Stripe + Adyen, fraud ML model (XGBoost), HSM tokenization vault, automated reconciliation.

**Key Additions**: PSP failover, smart routing (cost + success rate), async retry service, 3D Secure for EU.

---

### Stage 3: Scale (10K TPS, Global)
**Infrastructure**: 100+ API servers across 3 regions, PostgreSQL sharded by merchant_id, 3+ PSPs, ensemble fraud models (XGBoost + neural net), multi-region HSMs.

**Optimizations**: Local PSP routing (US transactions → US PSP), currency-aware routing (EUR → EU PSP), predictive retry (ML predicts optimal retry time), real-time settlement for premium merchants.

---

## Failure Scenarios

| Failure | Detection | Impact | Mitigation | Recovery Time |
|---------|-----------|--------|------------|---------------|
| **PSP Timeout** | 500ms timeout | Failed authorizations | Auto-failover to backup PSP | <1s |
| **Fraud Model Down** | Health check failure | Fall back to rules engine | Rules block obvious fraud (velocity, geolocation) | <5min (model restart) |
| **HSM Unavailable** | Tokenization API error | Cannot process new payments | Use cached tokens (existing customers), queue new tokens | <10min (HSM failover) |
| **Database Overload** | Query latency >1s | Slow authorizations | Read replicas, cache frequently accessed data | <2min (add replicas) |
| **Reconciliation Mismatch** | Daily batch job alert | Missing transactions | Manual investigation, contact PSP | Hours to days |

---

## SLO Commitments

**Authorization Latency**: p99 <500ms (includes fraud + PSP)
**Success Rate**: >98% of legitimate transactions approved
**Fraud Rate**: <0.1% of transaction volume
**Reconciliation**: 100% match within 24 hours
**Uptime**: 99.99% (43 min/year downtime)

---

## Common Pitfalls

1. **No Idempotency → Duplicate Charges**: Always require idempotency keys, dedupe in DB.
2. **Storing CVV**: PCI violation (never store CVV, even encrypted). Use tokenization.
3. **Synchronous Settlement**: Don't wire transfer per transaction (use daily batches).
4. **Ignoring 3DS**: EU merchants must support SCA (PSD2 law) or face declines.
5. **No PSP Failover**: Single PSP = single point of failure (timeout → lost sales).
6. **Weak Fraud Detection**: High fraud rate → chargebacks → PSP termination.
7. **Manual Reconciliation**: Automate daily reconciliation or miss discrepancies.
8. **Hardcoded PSP Logic**: Use adapter pattern for multi-PSP (easy to add new PSP).

---

## Interview Talking Points

1. **Idempotency**: "Client sends UUID in header → server checks DB → if exists, return original response (no double charge)."
2. **Tokenization**: "HSM encrypts card → returns token → app stores token (PCI compliant, card never in DB)."
3. **Smart Routing**: "Route VISA to Stripe (2.9% fee), Mastercard EU to Adyen (95% auth rate)."
4. **Fraud Detection**: "Rules (velocity, geo) + ML (XGBoost) → score 0-100 → block if >80, <100ms latency."
5. **Reconciliation**: "Daily batch: Compare gateway ledger (10K tx, $1M) vs. PSP statement → alert if mismatch."
6. **Failover**: "If Stripe timeout (500ms) → retry with Adyen → total latency 700ms (acceptable for failover)."

---

## Follow-Up Questions

1. **Multi-Currency**: How do you handle FX rate updates (real-time vs. daily batch)?
2. **Chargebacks**: Design dispute resolution flow (merchant evidence submission, representment to bank).
3. **PCI Compliance**: What are PCI DSS SAQ (Self-Assessment Questionnaire) levels (A vs. D)?
4. **Subscription Billing**: Handle recurring payments with retry logic (failed → retry after 3 days).
5. **Split Payments**: Design marketplace payment routing (platform fee + merchant payout).
6. **Cross-Border Fees**: Calculate international transaction fees (1.5% + FX spread).
7. **Strong Customer Authentication (SCA)**: Implement 3D Secure 2.0 (biometric auth).
8. **Payment Method Orchestration**: Support ACH, wire, SEPA, local payment methods (Alipay, iDEAL).
9. **Real-Time Fraud Feedback**: Chargeback data → retrain ML model (close feedback loop).
10. **Cost Optimization**: When to use PSP cascading (retry multiple PSPs) vs. single PSP?

---

**Final Thought**: Payment gateway design is about **reliability** (idempotency, failover), **compliance** (PCI DSS, tokenization), and **cost optimization** (smart PSP routing). The critical trade-off is **fraud prevention vs. false positives**—block too much, lose legitimate sales; block too little, lose to chargebacks.
