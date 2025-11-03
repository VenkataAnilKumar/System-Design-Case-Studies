# Payment Gateway Processor

## Problem Statement

Design a **Stripe/PayPal-like payment gateway** that processes credit card transactions with PCI compliance, fraud detection, and multi-PSP routing.

**Core Challenge**: Process 10K transactions/sec with <500ms p99 latency while maintaining PCI DSS compliance, <0.1% fraud rate, and 99.99% payment success rate.

**Key Requirements**:
- Payment authorization and capture (two-step)
- Multi-PSP routing (Stripe, Adyen, Braintree)
- Fraud detection (real-time ML scoring <100ms)
- Tokenization for PCI compliance (vault card data)
- Idempotency (prevent double-charging)
- Reconciliation with bank statements

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10K TPS, <500ms latency, <0.1% fraud, PCI DSS) |
| [02-architecture.md](./02-architecture.md) | Components (Gateway, PSP Router, Fraud Engine, Vault, Ledger) |
| [03-key-decisions.md](./03-key-decisions.md) | Tokenization, PSP routing, fraud detection, idempotency |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global payments, failure scenarios, compliance |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Authorization Latency** | p99 <500ms (includes fraud check + PSP) |
| **Fraud Rate** | <0.1% of transaction volume |
| **Payment Success Rate** | >99.99% |
| **Availability** | 99.99% |

## Technology Stack

- **Tokenization**: HSM (hardware security module) for card vault
- **Fraud Detection**: ML models (XGBoost, neural nets) + rules engine
- **PSP Router**: Intelligent routing (cost, success rate, region)
- **Ledger**: Double-entry accounting (PostgreSQL)
- **Idempotency**: Request deduplication (idempotency keys)

## Interview Focus Areas

1. **Tokenization**: Replace card numbers with tokens (PCI DSS Level 1)
2. **Fraud Detection**: Real-time ML scoring (<100ms) before PSP call
3. **PSP Routing**: Route to lowest-cost PSP with highest success rate
4. **Idempotency**: Dedupe duplicate requests (network retries)
5. **Reconciliation**: Match gateway records with PSP/bank statements daily
