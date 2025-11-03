# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 50K orders/day**
- Single region; PostgreSQL; Redis cache; basic dispatch
- SMS notifications; manual support tooling

**50K → 1M orders/day**
- Regional shards for dispatch; Kafka for events; Elasticsearch for search
- ML ETA service; dynamic pricing; proactive delay notifications
- POS integrations for top restaurants; fraud scoring

**1M → 5M orders/day**
- Multi-region active-active; regional catalogs; CDN for images
- Advanced batching/heatmaps; surge incentives; A/B tests on dispatch scoring
- Real-time telemetry pipeline (Flink) for ETA calibration; experimentation platform

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| POS integration outage | Orders not acknowledged | Webhook failures | Fallback to phone/SMS confirmation; pause store temporarily |
| Dispatch overload | Slow assignments, cold food | Time-to-assign > SLO | Prioritize ready orders; pause low-rated restaurants; incentives to near couriers |
| Payment capture failure | Revenue loss | PSP errors | Retry with backoff; partial capture; manual follow-up |
| Telemetry gaps | ETA inaccurate | Missing pings | Extrapolate using last speed; prompt courier; map matching |
| Weather spike | Widespread delays | Weather alerts | Auto-extend ETAs; surge couriers; notify customers proactively |

---

## SLOs

- Search p95 < 300ms; checkout p95 < 800ms
- Dispatch time-to-assign p95 < 60s; on-time delivery > 95%
- ETA MAE < 5 min
- Payment auth success > 98%; capture retries resolved < 24h

---

## Common Pitfalls

1. Over-aggressive batching causing cold food; cap batch size/time windows
2. Ignoring prep variability per restaurant; learn per-venue prep times
3. No idempotency on order state transitions; double charges/refunds
4. Poor surge controls → customer backlash; transparency on fees and ETAs
5. Telemetry bandwidth drains courier batteries; adaptive rates needed

---

## Interview Talking Points

- Dispatch scoring features and trade-offs (utilization vs. SLA)
- ETA modeling and online calibration with telemetry
- Multi-tenant POS integration patterns and fallbacks
- Payments lifecycle: auth, capture, refunds, tip adjustments
- Operating during city-wide events and adverse weather

---

## Follow-Up Questions

- How to support groceries with substitutions and multi-stop routes?
- How to reduce cancellations with better readiness predictions?
- How to optimize courier incentives for balanced supply geography?
- How to integrate dark kitchens/virtual brands with different prep behaviors?
