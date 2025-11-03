# Collaborative Document Editor

## Problem Statement

Design a **Google Docs-like collaborative editor** where multiple users can edit the same document simultaneously with real-time synchronization.

**Core Challenge**: Support 1M concurrent editing sessions with <100ms keystroke latency while maintaining document consistency through Operational Transformation (OT) or CRDTs.

**Key Requirements**:
- Real-time collaborative editing (multiple cursors visible)
- Conflict-free merge of concurrent edits (OT/CRDT)
- Version history and rollback
- Presence indicators (who's editing, cursor positions)
- Offline editing with sync on reconnect
- Rich text formatting and comments

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (1M concurrent sessions, <100ms keystroke sync) |
| [02-architecture.md](./02-architecture.md) | Components (WebSocket Gateway, OT Engine, Document Store, Presence Service) |
| [03-key-decisions.md](./03-key-decisions.md) | OT vs CRDT, conflict resolution, operational transformation algorithms |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to millions of documents, offline sync, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Keystroke Latency** | p99 <100ms (client → server → all clients) |
| **Conflict Resolution** | 100% (no data loss on concurrent edits) |
| **Availability** | 99.95% |
| **Max Concurrent Editors** | 50 per document (soft limit) |

## Technology Stack

- **Real-Time Sync**: WebSocket for bidirectional communication
- **Conflict Resolution**: Operational Transformation (OT) or CRDTs (Yjs)
- **Document Store**: MongoDB/PostgreSQL for document versions
- **Presence**: Redis for active user tracking
- **History**: Append-only log for version history

## Interview Focus Areas

1. **Operational Transformation**: Transform concurrent operations to maintain consistency
2. **CRDT vs OT**: Trade-offs (CRDTs simpler, OT better for rich text)
3. **Offline Sync**: Queue operations locally, replay on reconnect
4. **Presence**: Cursor position broadcasting with throttling
5. **Version History**: Snapshot + delta storage for efficient rollback
