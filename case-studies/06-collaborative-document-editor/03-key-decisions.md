# 3) Key Decisions (Trade-offs)

## 1) OT vs CRDT
- OT: Transform concurrent ops; deterministic ordering; lower overhead; complex to implement correctly
- CRDT: Math guarantees convergence; no central transform; higher metadata (tombstones, version vectors)
- Choice: OT for text editing (Google Docs model); CRDT for decentralized/offline-first (e.g., rich JSON docs)

## 2) Central Server vs P2P
- Central server: Simpler ordering; single source of truth; scales with sharding
- P2P: No server; full decentralization; complex NAT traversal
- Choice: Central server for simplicity and reliability; sticky WebSocket per doc

## 3) Operation Granularity
- Character-level: Every keystroke an op; high op count; fine-grained undo
- Block-level: Group edits (e.g., word, sentence); fewer ops; coarser undo
- Choice: Character-level for real-time feel; batch on network layer for efficiency

## 4) Snapshot Strategy
- Frequency: Every N ops (e.g., 1000) or time interval (e.g., 5 min)
- Storage: Full doc vs incremental delta
- Choice: Full snapshots every 1K ops or 5 min; trade storage for fast load

## 5) Offline Sync
- Queue all ops; replay on reconnect with vector clocks for causal ordering
- Risk: Long offline → large queue; potential divergence
- Mitigation: Cap offline edit duration; force full resync if too stale

## 6) Presence Updates
- Broadcast every cursor move: High bandwidth
- Throttle: Send updates every 100–200ms; interpolate client-side
- Choice: Throttled presence with client-side smoothing

## 7) Permissions Enforcement
- Client-side check (fast) + server-side validate (authoritative)
- Risk: Client bypass; must validate all ops server-side
- Choice: Dual-check; reject unauthorized ops at server

## 8) Version History Storage
- Full snapshots per version: Easy but storage-heavy
- Op log replay: Compact but slow for old versions
- Choice: Hybrid; snapshots at intervals; ops between snapshots
