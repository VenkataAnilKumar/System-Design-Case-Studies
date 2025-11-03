# Requirements & Scale

## Functional Requirements

### Core Capabilities
1. **Payment Authorization**: Validate card details, check balance/limits, get auth code from issuing bank (<500ms)
2. **PSP Routing**: Route transactions to optimal PSP (Stripe, Adyen, Braintree) based on card type, region, cost
3. **Fraud Detection**: Real-time scoring with rules engine + ML model, block high-risk transactions before auth
4. **Capture & Settlement**: Capture funds after auth (e.g., at shipping), batch settle with banks daily
5. **Reconciliation**: Match payment gateway records with PSP/bank statements, detect discrepancies
6. **Multi-Currency**: Support 150+ currencies with real-time FX rates, handle cross-border fees
7. **3D Secure**: Implement Strong Customer Authentication (SCA) for EU transactions (PSD2 compliance)
8. **Tokenization**: Replace card numbers with tokens (PCI DSS compliance), store tokens in vault

### Advanced Features
- Payment methods: Credit card, debit, ACH, wire transfer, digital wallets (Apple Pay, Google Pay)
- Recurring billing (subscriptions) with retry logic for failed payments
- Partial captures (authorize $100, capture $80 if item out of stock)
- Refunds and chargebacks (dispute handling, representment to banks)
- Smart retry (retry declined transactions after 24h with different PSP)
- Multi-PSP failover (if PSP A is down, failover to PSP B within 1s)

## Non-Functional Requirements

### Performance
- **Authorization Latency**: p99 <500ms (includes fraud check + PSP call)
- **Throughput**: 10K TPS peak (Black Friday), 2K TPS sustained
- **Fraud Check**: <100ms p99 for ML scoring (not blocking critical path)

### Availability
- **Uptime**: 99.99% (43 min/year downtime, $1M penalty per hour downtime)
- **Redundancy**: Multi-region active-active, min 3 replicas per component
- **Graceful Degradation**: If fraud ML model down, fall back to rules engine

### Security & Compliance
- **PCI DSS Level 1**: No card data stored (tokenization), encrypted in transit (TLS 1.3)
- **PII Protection**: Mask card numbers in logs (show only last 4 digits)
- **Audit Trails**: Immutable logs for all transactions (7-year retention for compliance)
- **Key Rotation**: Rotate encryption keys every 90 days without downtime

### Financial Accuracy
- **Zero Data Loss**: Every transaction must be recorded (dual writes to DB + ledger)
- **Idempotency**: Duplicate API calls must not create duplicate charges
- **Reconciliation**: 100% of transactions reconciled within 24 hours

## Scale Estimates

### Traffic Profile
- **Peak TPS**: 10K TPS (Black Friday) = 36M transactions/hour
- **Sustained TPS**: 2K TPS avg = 172M transactions/day
- **Geographic Distribution**: 40% US, 30% EU, 20% APAC, 10% rest
- **Payment Methods**: 70% credit card, 20% debit, 5% digital wallet, 5% ACH/wire

### Transaction Sizes
- **Authorization**: 2KB request (card details, billing address), 500 bytes response (status, auth code)
- **Fraud Check**: 5KB (100+ features: IP, device fingerprint, transaction history)
- **Ledger Entry**: 1KB (transaction_id, amount, currency, timestamp, status)

### Infrastructure
- **API Servers**: 100 nodes (8 vCPU each) = 800 vCPU for 10K TPS
- **Fraud ML Service**: 20 GPU nodes (NVIDIA T4) for real-time scoring
- **Database**: PostgreSQL with 50TB storage (7 years × 172M tx/day × 1KB)
- **Token Vault**: HSM (Hardware Security Module) cluster for encryption

### Cost Estimation (Monthly)
- **Compute**: 120 nodes × $300/mo = $36K
- **Database**: 50TB × $0.10/GB = $5K
- **PSP Fees**: 172M tx/day × 30 days × $0.10/tx = $516K (2.9% + $0.30 typical)
- **HSM**: $10K/mo (dedicated hardware)
- **Total**: **~$567K/mo** (dominated by PSP fees)

## Constraints
- **PCI DSS**: Cannot store CVV (even encrypted), must use tokenization
- **3D Secure Latency**: SCA adds 2-5s latency (user redirected to bank for auth)
- **PSP Lock-In**: Each PSP has custom API (Stripe ≠ Adyen) → multi-PSP routing is complex
- **Chargeback Risk**: Merchant liable for fraudulent transactions → must minimize fraud rate <0.1%

## Success Measures
- **Authorization Success Rate**: >98% (2% legitimate declines acceptable)
- **Fraud Rate**: <0.1% of transaction volume (balance fraud prevention vs. false positives)
- **Reconciliation**: 100% match rate within 24 hours (zero missing transactions)
- **Latency SLA**: 99% of authorizations in <500ms (including fraud check)
- **Uptime**: 99.99% (measured monthly, penalties for violations)
