# Online Banking System

## Problem Statement

Design a **Chase/Wells Fargo-like online banking system** that handles financial transactions with ACID guarantees, fraud detection, and regulatory compliance.

**Core Challenge**: Process 100K transactions/sec with <100ms latency while maintaining strong consistency (no money lost/duplicated) and detecting fraud in real-time (<1s).

**Key Requirements**:
- Account management (checking, savings, credit cards)
- Money transfers (internal, ACH, wire, international)
- Transaction history with search and filtering
- Fraud detection (ML-based real-time scoring)
- Bill payments and recurring transfers
- Regulatory compliance (KYC, AML, audit trails)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100K TPS, <100ms latency, ACID, real-time fraud detection) |
| [02-architecture.md](./02-architecture.md) | Components (Core Banking, Transaction Service, Fraud Engine, Compliance) |
| [03-key-decisions.md](./03-key-decisions.md) | ACID transactions, fraud detection, double-entry ledger |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to global banks, failure scenarios, disaster recovery |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Transaction Latency** | p99 <100ms |
| **Consistency** | 100% (ACID, no money lost) |
| **Fraud Detection** | <1s (real-time scoring before approval) |
| **Availability** | 99.99% |

## Technology Stack

- **Core Banking**: PostgreSQL with ACID transactions
- **Ledger**: Double-entry accounting (debits = credits)
- **Fraud Detection**: ML models (random forest, neural nets) + rules
- **Audit Logs**: Immutable append-only log (blockchain-inspired)
- **Compliance**: KYC/AML checks, transaction monitoring

## Interview Focus Areas

1. **ACID Transactions**: Two-phase commit for fund transfers
2. **Double-Entry Ledger**: Every transaction has debit and credit entries
3. **Fraud Detection**: Real-time ML scoring (<1s) with rule-based fallback
4. **Idempotency**: Prevent duplicate transactions on retry
5. **Disaster Recovery**: Multi-region replication, RPO <1 minute
