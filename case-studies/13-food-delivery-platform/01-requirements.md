# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Discovery: Restaurants, cuisines, filters (rating, price, diet), search, promos
- Menu & Availability: Real-time item availability, options (size, spice), prep times
- Cart & Checkout: Add items, fees/taxes, tips, coupons, payment methods
- Order Lifecycle: Place, confirm, prep start/ready, pickup, en-route, delivered; cancel/modify
- Courier Dispatch: Match orders to couriers; batching; hot bag constraints; pickup/delivery SLAs
- Live Tracking: Courier location, ETA updates, map view, chat (customer-courier-restaurant)
- Notifications: SMS/push for order status; driver app alerts
- Support: Refunds/adjustments; partial items; substitutions; issue resolution

## Non-Functional Requirements

- Latency: Search/list p95 < 300ms; checkout p95 < 800ms; ETA recompute < 2s
- Availability: 99.95% during meal peaks; degraded mode (read-only menus) on partial outages
- Scale: 500K concurrent orders; 200K couriers; 20K restaurants per metro
- Accuracy: ETA MAE < 5 min; inventory accuracy > 99%; payment capture 100% idempotent
- Reliability: Dispatch within 60s p95; order drop rate < 0.1%
- Safety: Fraud detection for payments; courier background checks; PII privacy

## Scale Estimate

- Orders/day: 5M; peak 25K/min (meal spikes)
- Courier telemetry: 200K × 1Hz → 200K location updates/sec (bursting)
- Menu data: 1M restaurants × avg 80 items → 80M SKUs; updates 1–2/day; hot items change hourly
- Chat: 5M orders/day × 10 msgs avg → 50M msgs/day (~600 msgs/sec)

## Constraints

- Geography-dependent constraints (traffic, weather, zones, regulations)
- Restaurants with legacy POS/phones; integrations vary
- Payments: PCI DSS; chargebacks; tips adjustments post-delivery

## Success Measures

- Delivery SLA met % (>95%) and ETA accuracy (MAE < 5 min)
- Order conversion rate; cart abandonment
- Courier utilization (>60%) and idle time
- Customer support contact rate (<2%) and refund cost (<2% GMV)
- Fraud loss rate (<0.1% of GMV)