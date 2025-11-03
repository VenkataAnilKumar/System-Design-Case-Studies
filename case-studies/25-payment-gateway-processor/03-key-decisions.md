# Key Technical Decisions

## 1. Tokenization: Vault-Based vs. Format-Preserving Encryption (FPE)

**Decision**: **Vault-based tokenization** with HSM for PCI DSS compliance.

**Rationale**:
- **Security**: Card numbers never stored in application DB (only tokens), HSM is FIPS 140-2 certified
- **Detokenization**: Vault API returns original card for PSP calls (encrypted channel)
- **Compliance**: Reduces PCI scope (app is not in scope if no card data stored)

**Format-Preserving Encryption** (alternative):
- Encrypts card maintaining format (1234567890123456 → 6789012345678901, both 16 digits)
- Benefit: Can use encrypted card in legacy systems expecting card format
- Trade-off: Weaker security (deterministic encryption), not recommended for PCI

**When to Reconsider**: For non-PCI use cases (gift cards), FPE is simpler than vault.

---

## 2. Fraud Detection: Synchronous vs. Asynchronous Scoring

**Decision**: **Synchronous fraud check** (<100ms) before PSP authorization.

**Rationale**:
- **Block Before PSP**: Save $0.10 PSP fee per blocked transaction (5% of traffic)
- **Real-Time Decision**: Can't approve payment if fraud score unknown
- **Latency Budget**: 100ms fraud + 200ms PSP = 300ms total (within 500ms SLA)

**Asynchronous** (alternative):
- Approve first, check fraud after → faster (no fraud latency) but higher chargeback risk

**When to Reconsider**: If fraud model >200ms, make it async and refund fraudulent transactions later.

---

## 3. PSP Routing: Static vs. Dynamic (Smart Routing)

**Decision**: **Dynamic routing** based on card type, region, PSP performance.

**Rationale**:
- **Cost Optimization**: Route VISA to lowest-fee PSP (Stripe 2.9% vs. Adyen 3.1%)
- **Success Rate**: Route EU Mastercard to Adyen (95% auth rate vs. Stripe 92%)
- **Failover**: If PSP A timeout, retry with PSP B (improve success rate 95% → 98%)

**Static Routing** (alternative):
- Simplicity: All transactions → Stripe (no routing logic)
- Trade-off: Higher costs, single point of failure

**When to Reconsider**: For small volume (<1M tx/mo), single PSP is simpler (multi-PSP overhead not worth it).

---

## 4. Idempotency: Client-Side Keys vs. Server-Side Deduplication

**Decision**: **Client-side idempotency keys** (UUID in header).

**Rationale**:
- **Prevent Duplicate Charges**: Network timeout → client retries → idempotency key prevents double charge
- **Stateless**: Server checks DB for existing payment with same key (no in-memory state needed)
- **Standard**: Industry best practice (Stripe, Adyen all use idempotency keys)

**Server-Side Deduplication** (alternative):
- Dedupe based on (merchant_id, amount, timestamp) → risky (legitimate duplicate amounts)

**When to Reconsider**: For internal APIs (not client-facing), server-side dedupe is acceptable.

---

## 5. Settlement: Real-Time vs. Batch (Daily)

**Decision**: **Batch settlement** (daily at 2am) for cost efficiency.

**Rationale**:
- **Cost**: Single bank transfer (10K transactions) vs. 10K individual transfers (10K × $0.25 wire fee)
- **Standard Practice**: Banks settle ACH/wire in batches (not real-time)
- **Merchant Expectation**: Merchants expect T+1 or T+2 settlement (not instant)

**Real-Time Settlement** (alternative):
- Instant payouts (Stripe Instant Payouts) for premium merchants
- Trade-off: 1.5% fee for instant vs. 0% for batch

**When to Reconsider**: For gig economy (Uber drivers), offer real-time settlement as premium feature.

---

## 6. Ledger: RDBMS vs. Blockchain

**Decision**: **RDBMS (PostgreSQL)** with append-only ledger table.

**Rationale**:
- **ACID Transactions**: Double-entry ledger requires atomic debits/credits (RDBMS strength)
- **Query Performance**: SQL queries for reconciliation reports (vs. blockchain's slow queries)
- **Cost**: PostgreSQL is free/cheap vs. blockchain infrastructure costs

**Blockchain** (alternative):
- Immutable audit trail, no single point of trust
- Trade-off: Complex, slow (10 TPS vs. 10K TPS for Postgres), overkill for centralized payment gateway

**When to Reconsider**: For decentralized payments (crypto), blockchain is required.

---

## 7. Retry Logic: Immediate vs. Delayed (Exponential Backoff)

**Decision**: **Exponential backoff** (1min, 5min, 1h, 24h) with PSP rotation.

**Rationale**:
- **Transient Failures**: 5% of declines are temporary (insufficient funds → user adds funds → retry succeeds)
- **PSP Rotation**: Retry with different PSP (PSP B may approve what PSP A declined)
- **User Experience**: Async retry (via webhook) doesn't block checkout

**Immediate Retry** (alternative):
- Retry within same request (3 attempts × 500ms = 1.5s total latency)
- Trade-off: Increases checkout latency, PSP may rate-limit

**When to Reconsider**: For high-value transactions ($10K+), immediate retry with multiple PSPs is worth latency hit.

---

## 8. 3D Secure: Always-On vs. Adaptive (Risk-Based)

**Decision**: **Adaptive 3D Secure** (enable only for high-risk transactions).

**Rationale**:
- **Conversion Rate**: 3DS adds 2-5s latency + extra step → 10-20% abandoned checkouts
- **SCA Exemptions**: EU PSD2 allows exemptions (low-value <€30, trusted merchants, low fraud rate)
- **Risk-Based**: Enable 3DS only if fraud_score >50 (balance security vs. UX)

**Always-On 3DS** (alternative):
- Maximum security, shift fraud liability to bank
- Trade-off: Lower conversion, user friction

**When to Reconsider**: For high-fraud merchants (digital goods), always-on 3DS is mandatory.

---

**Summary Table**:

| Decision | Chosen Approach | Main Benefit | Main Cost | Reconsider If... |
|----------|----------------|--------------|-----------|------------------|
| Tokenization | Vault-based HSM | PCI compliance | HSM cost ($10K/mo) | Non-PCI use case |
| Fraud Detection | Synchronous (<100ms) | Block before PSP | Added latency | Model >200ms |
| PSP Routing | Dynamic smart routing | Cost + success rate | Complexity | Volume <1M tx/mo |
| Idempotency | Client-side keys | Prevent duplicates | Client must send key | Internal APIs only |
| Settlement | Daily batch | Cost efficiency | T+1 delay | Gig economy (instant needed) |
| Ledger | PostgreSQL RDBMS | ACID + query speed | Centralized trust | Decentralized crypto |
| Retry Logic | Exponential backoff | Recover transient failures | Delayed resolution | High-value tx need instant retry |
| 3D Secure | Adaptive (risk-based) | Conversion vs. security | Complex rules | High-fraud merchants |
