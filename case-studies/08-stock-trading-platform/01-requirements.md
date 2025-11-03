# 1) Requirements & Scale

## Functional Requirements

- Order placement: Market, limit, stop orders; buy/sell stocks
- Order matching: Match buy/sell orders; FIFO price-time priority
- Market data: Real-time quotes (bid/ask); trade feed; order book depth
- Portfolio: View positions, balances, P&L; transaction history
- Risk checks: Buying power validation; day-trade limits; reject invalid orders
- Settlement: T+2 clearing; broker-dealer integration
- Compliance: Audit trail; trade reporting; regulatory (SEC, FINRA)

## Non-Functional Requirements

- Ultra-low latency: Order ack < 10ms; matching < 1ms; market data < 10ms
- High availability: 99.99%+ during market hours
- Consistency: Strong consistency for orders/positions; no double-execution
- Fairness: FIFO order matching; no front-running
- Observability: Trade latency, fill rates, system health per symbol

## Scale & Back-of-the-Envelope

- Users: 10M accounts; 1M concurrent during market open
- Orders: 100K orders/sec peak (market open); 1M+ per day
- Market data: 10K symbols; 1M quotes/sec; multicast feed
- Positions: 10M users × 10 positions avg = 100M position records

## Constraints & Assumptions

- Market hours: 9:30 AM – 4 PM ET weekdays
- Order book per symbol in-memory; durability via event log
- Latency critical (microseconds matter for HFT); most retail users tolerate <100ms
- Regulatory requirements: Audit logs, trade reporting, best execution

## Success Measures

- Order-to-ack latency p50/p95/p99
- Fill rate (% of orders executed)
- Market data lag (exchange → platform → user)
- Zero accounting errors (positions/balances)
