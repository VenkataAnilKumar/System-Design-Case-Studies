# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 1M users (~10K orders/sec)**
- Single matching engine per symbol
- PostgreSQL for positions (master-replica)
- Redis for market data cache (1 sec TTL)
- 3-5 app servers (Order Gateway, Position Service)

**1M → 5M users (~50K orders/sec)**
- Shard positions DB by user_id range (4 shards)
- Add read replicas for historical queries (order history, trade reports)
- Horizontally scale matching engines (one per popular symbol; others share)
- Move audit log to distributed Kafka (6 partitions)

**5M → 10M users (~100K orders/sec)**
- Use message brokers (Kafka) between Gateway → Matching Engine
- Pre-provision matching engines for top 1000 symbols (dedicated instances)
- Add market data multicast for pro tier (UDP)
- Co-locate exchange connectors in NYSE/NASDAQ data centers (sub-ms latency)
- Cache user risk limits (buying_power) in Redis; sync with DB every 100ms

**Beyond 10M (HFT scale)**
- Custom kernel-bypass networking (DPDK)
- FPGA-based matching engines (sub-microsecond)
- Direct market access (FIX protocol to exchanges)
- Global: Route US users → US region, EU users → London region (regulatory requirement: GDPR, MiFID II)

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| Matching Engine Crash | Orders not processed; book lost | Health check timeout (1s) | Hot standby; replay Kafka event log to rebuild book (5-10s recovery) |
| Exchange Disconnect | No market data; cannot route orders | FIX heartbeat timeout (30s) | Failover to backup feed; halt trading if all feeds down (circuit breaker) |
| Position DB Outage | Orders rejected (cannot verify balance) | DB connection pool exhausted | Read from replica (stale by 1s); reject writes; queue orders for retry |
| Risk Check Service Down | Orders bypass risk checks (dangerous) | Health endpoint fails | Fail-closed: Reject all orders until service recovers; alert oncall immediately |
| Kafka Lag | Order acks delayed; fills not reflected in positions | Consumer lag metric > 1000 msgs | Scale Kafka partitions; add consumers; backpressure at Gateway (rate-limit) |
| User DDoS (spam orders) | Legitimate orders starved | Single user > 1000 orders/sec | Per-user rate limit (100 orders/sec); temp ban on violation |
| Accounting Error (position mismatch) | User has wrong share count | Daily reconciliation job (compare DB vs. clearinghouse) | Manual review queue; compensate user if our fault; investigate bug |

---

## SLOs (Service Level Objectives)

- **Order Ack Latency**: p99 < 10ms (Gateway → user response)
- **Matching Latency**: p95 < 1ms (order arrives at engine → fill event)
- **Market Data Lag**: p99 < 10ms (exchange timestamp → WebSocket push)
- **Availability**: 99.99% during market hours (9:30 AM - 4 PM ET, Mon-Fri); downtime budget = 52 sec/year
- **Fill Rate**: >99% for market orders (filled within 1 sec)
- **Data Accuracy**: Zero accounting errors per month (positions match clearinghouse)

---

## Common Pitfalls

1. **Ignoring time synchronization**: Matching engines must use NTP; clock drift causes wrong FIFO order; symptom: users report "later order filled first"
2. **No idempotency on fills**: Network retry can double-fill; use unique fill_id; check "already processed" before updating positions
3. **Unbounded order book**: DoS via spam limit orders far from market; limit: max 1000 orders per user per symbol; or price collar (orders >10% from last trade rejected)
4. **Stale risk checks**: User deposits $1000; cache not updated; order rejected incorrectly; solution: invalidate cache on balance change, or TTL <100ms
5. **No circuit breakers**: Market crashes; users panic-sell; system overloaded; solution: Halt trading if >10% move in 5 min; manual resume after review

---

## Interview Talking Points

- **Latency budget breakdown**: Where does each millisecond go? (network 2ms, gateway validation 1ms, matching 0.5ms, position update 2ms, ack back 2ms = ~8ms total)
- **Why event sourcing?**: Audit trail for SEC; replay for debugging; rebuild state after crash
- **FIFO fairness**: How to prevent "queue jumping"? Colocate matching engine with exchange; all users route through same gateway (no shortcuts)
- **HFT arms race**: Is sub-ms matching enough? No—pros want microseconds; requires custom hardware (FPGAs, kernel bypass); expensive trade-off vs. cloud simplicity
- **Regulatory compliance**: What logs are required? Every order (timestamp, user, symbol, price, qty, status); every fill (counterparty, price, qty, timestamp); retained 7 years (SEC Rule 17a-4)
- **Disaster recovery**: How fast can you recover? Matching engines: 5-10 sec (replay events); Positions DB: <1 min (failover to replica); Market data: <30 sec (reconnect to exchange feeds)

---

## Follow-Up Questions to Explore

- How would you add options trading? (Multi-leg orders; Greeks calculation; expiration handling)
- How to prevent insider trading detection? (Pattern analysis; flag suspicious activity before trade; real-time alerts)
- How to support after-hours trading? (Extended hours 4 AM - 9:30 AM, 4 PM - 8 PM; lower liquidity; wider spreads)
- How to handle stock splits? (Adjust all open orders; update positions; notify users)
- How would you add margin trading (borrow to buy)? (Margin requirements; collateral checks; forced liquidation on margin call)
- How to scale internationally? (Regulatory differences: T+2 in US, T+3 in India; currency conversion; cross-border settlement)
