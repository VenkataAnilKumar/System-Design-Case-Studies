# Stock Trading Platform

## Problem Statement

Design a **Robinhood/E*TRADE-like stock trading platform** that executes trades in real-time with low latency and strict financial compliance.

**Core Challenge**: Handle 100K orders/sec during market open with <10ms p99 order placement latency while maintaining ACID guarantees and regulatory compliance (audit trails, settlement).

**Key Requirements**:
- Real-time market data streaming (quotes, order book updates)
- Order placement with validation (buying power, margin checks)
- Order matching engine (FIFO, price-time priority)
- Portfolio management (positions, P&L calculation)
- Settlement and clearing (T+2 for stocks)
- Regulatory compliance (audit logs, transaction reporting)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100K orders/sec, <10ms latency, ACID requirements) |
| [02-architecture.md](./02-architecture.md) | Components (Order Service, Matching Engine, Risk Management, Settlement) |
| [03-key-decisions.md](./03-key-decisions.md) | Order matching algorithms, ACID transactions, hot spot handling |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to millions of users, failure scenarios, compliance |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Order Latency** | p99 <10ms (placement to matching engine) |
| **Throughput** | 100K orders/sec sustained |
| **Availability** | 99.99% during market hours |
| **Data Consistency** | ACID for all financial transactions |

## Technology Stack

- **Matching Engine**: In-memory order book (C++/Java low-latency)
- **Order Store**: PostgreSQL with ACID guarantees
- **Market Data**: WebSocket streaming, Kafka for fan-out
- **Risk Management**: Pre-trade checks (buying power, margin)
- **Settlement**: Batch processing (T+2), reconciliation with clearinghouses

## Interview Focus Areas

1. **Order Matching**: FIFO queue with price-time priority
2. **ACID Transactions**: Two-phase commit for order placement + balance deduction
3. **Hot Spot Prevention**: Popular stocks (e.g., Tesla) causing contention
4. **Market Data**: Real-time streaming to millions of clients
5. **Regulatory Compliance**: Audit trails, immutable transaction logs
