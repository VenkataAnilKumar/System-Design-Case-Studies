# 4) Scale, Failures & Wrap-Up

## Scaling Playbook
- Shard docs by doc_id; sticky WS routing to same shard for ordering
- Collab servers: Horizontal scale per doc shard; Redis for session state
- Op log: Time-series DB (InfluxDB) or append-only table; partition by doc_id + timestamp
- Snapshots: Object storage (S3); CDN for popular docs
- Presence: Redis with TTL; pub/sub for cursor broadcasts

## Failure Scenarios
1) Collab server crash
- Impact: Active sessions disconnect; ops in-flight lost
- Mitigation: Clients auto-reconnect; request catchup ops from last ack'd version; server replays from log

2) OT transform bug (divergence)
- Impact: Clients see different doc states
- Mitigation: Versioned OT library; extensive testing; fallback to full resync if hash mismatch detected

3) Network partition (client isolated)
- Impact: User edits offline; long queue
- Mitigation: Cap offline duration; force full reload if >1K pending ops; warn user

4) Snapshot lag
- Impact: Slow doc load (must replay many ops)
- Mitigation: Auto-snapshot on inactivity; background workers generate snapshots for hot docs

## SLOs & Metrics
- Op latency p95 < 500ms; p99 < 1s
- Presence update < 200ms p95
- Divergence incidents: 0 per month (critical)
- Doc load time p95 < 2s (including snapshot + ops)

## Pitfalls and Gotchas
- OT correctness: TP1/TP2 properties; test exhaustively with fuzzing
- Cursor position after transform: Adjust correctly or jumps occur
- Large docs (>10MB): Paginate or split; full-doc sync becomes slow
- Undo/redo with OT: Must invert ops correctly; complex with concurrent edits

## Interview Talking Points
- OT vs CRDT comparison; when to use each
- How OT transforms concurrent insert at same position
- Snapshot + op log hybrid for version history
- Sticky WebSocket routing for operation ordering

## Follow-up Q&A
- Q: How handle paste of large text?
  - A: Chunk into smaller ops; batch send; show progress bar; server validates size limits
- Q: Undo in collaborative context?
  - A: Per-user undo stack; invert ops; broadcast as new op; others see reversal
- Q: Rich media (images, embeds)?
  - A: Store refs in doc (URLs); upload to object storage; inline rendering; ops reference by ID
- Q: Comment threads?
  - A: Separate data model; anchor to doc position range; adjust range on edits via OT

---

This collaborative editor design uses OT for conflict-free real-time editing, sticky WebSocket sessions for operation ordering, periodic snapshots for fast load, and an append-only operation log for version history and time-travel.
