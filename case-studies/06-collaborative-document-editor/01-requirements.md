# 1) Requirements & Scale

## Functional Requirements

- Real-time editing: Multiple users edit same document simultaneously; see changes <1s
- Conflict resolution: Concurrent edits merge automatically (no manual conflicts)
- Cursor presence: Show other users' cursors, selections, names
- Version history: Time-travel to any past version; restore; compare diffs
- Comments/suggestions: Inline comments; threaded replies; suggest mode (track changes)
- Permissions: Owner/editor/viewer/commenter roles; share links with expiry
- Offline mode: Edit offline; sync on reconnect; handle conflicts

## Non-Functional Requirements

- Low latency: Edit propagation p95 < 500ms; cursor updates < 100ms
- High availability: 99.9%+
- Consistency: Eventual consistency with convergence guarantees (CRDT/OT)
- Observability: Edit lag, sync errors, conflict resolution success rate

## Scale & Back-of-the-Envelope

- Users: 50M MAU; 5M DAU
- Documents: 100M+ active docs; 1B+ total
- Concurrent editing: 1M concurrent sessions; avg 2–5 users/doc
- Operations: 10K ops/sec (insert, delete, format); burst to 100K during peak

## Constraints & Assumptions

- Document size limit ~10MB text; larger docs split or paginated
- WebSocket for real-time; fallback to polling
- Conflicts rare with OT/CRDT; no user-facing "conflict" errors
- Rich text (bold, links, lists); not full layout engine

## Success Measures

- Edit-to-visible latency p50/p95/p99
- Conflict resolution success rate (no divergence)
- Concurrent editing sessions; user retention
- Sync error rate; data loss incidents (target: 0)
