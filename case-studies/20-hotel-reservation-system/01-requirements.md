# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Search & Discovery: Location, dates, guests, filters (price, amenities, rating); map view
- Availability: Real-time room inventory; calendar view; rate plans (refundable, non-refundable)
- Booking: Select room; guest details; payment; confirmation; email/SMS
- Inventory Locking: Hold room during checkout (TTL 10 min); prevent double booking
- Cancellation: Policies (free, penalty); refunds; waitlist for sold-out dates
- Reviews & Ratings: Post-stay reviews; moderation; ranking impact
- Property Management: Hotel dashboard; rate/inventory updates; block dates
- Payments: Auth on book; capture post-stay or at check-in; refunds; fraud detection

## Non-Functional Requirements

- Availability: 99.9% for search/booking; graceful degradation (cache stale data)
- Latency: Search p95 < 500ms; booking p95 < 2s
- Consistency: Strong for inventory (no double booking); eventual for reviews
- Throughput: 10K bookings/min peak; 500K concurrent users searching
- Fraud Prevention: Stolen cards; fake bookings; rate-limiting

## Scale Estimate

- Properties: 1M hotels × 100 rooms avg = 100M room-night inventory
- Searches: 50M/day; peak 2K/sec
- Bookings: 1M/day; peak 10K/min
- Inventory updates: 10K/sec (rate/availability changes by hotels)

## Constraints

- Time zones: Check-in/out times vary; local time vs. UTC handling
- Concurrent bookings: Last room race condition; need locking or optimistic concurrency
- Payment holds: Auth expires after 7 days; extend or re-auth

## Success Measures

- Booking conversion rate > 10%
- Zero double bookings (strong consistency validated)
- Payment success rate > 98%
- Search-to-book latency p95 < 3s