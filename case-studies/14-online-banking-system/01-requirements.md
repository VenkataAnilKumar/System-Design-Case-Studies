# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Accounts: Open/close; KYC onboarding; account types (checking, savings); statements
- Balances: Real-time available and ledger balances; holds; overdraft rules
- Transfers: Internal (A→B), ACH, wires, card transactions; scheduled and recurring
- Cards: Issuance, authorization, clearing, chargebacks; 3DS
- Payments: Bill pay, Zelle/SEPA equivalents; standing orders
- Limits & Controls: Per-transaction and daily limits; freezes; travel notices
- Fraud & AML: Real-time risk scoring; sanctions screening; SAR filing; case management
- Audit & Reporting: GL posting, reconciliations, regulatory reports
- Support: Disputes, chargebacks, refunds; account recovery

## Non-Functional Requirements

- Consistency: Strong for ledger and balances; idempotent operations
- Availability: 99.99% for payments auth; 99.9% for non-critical features
- Security: PCI DSS for cards, SOC2; encryption at rest/in transit; HSM for key mgmt
- Throughput: 200K TPS reads (balance checks), 20K TPS writes (transactions)
- Latency: Card auth p95 < 300ms; internal transfer p95 < 800ms
- Durability: Financial records 7+ years retention; WORM storage for audit

## Scale Estimate

- Accounts: 100M; avg 3 accounts per user
- Transactions/day: 200M; avg size 200B → 40GB/day (hot), 1TB/day with indexing
- Ledger size: 1–5TB hot; 100TB cold over years
- Fraud events: 50K/sec scoring; 1% escalations

## Constraints

- Regulatory: KYC/AML, OFAC, PCI DSS, GLBA; privacy (GDPR/CCPA)
- Settlement networks: Cutoff times (ACH batches), wire windows, card network SLAs
- Reconciliation with external systems (core banking, networks)

## Success Measures

- Zero double-spend; reconciliation diffs < 1 ppm
- Auth approval rate > 98% (good traffic); fraud loss < 5 bps of volume
- Incident rate for critical flows < 1/mo; MTTR < 30 min
- SLA adherence: Card auth p95 < 300ms; ACH file processing on-time % > 99.99%