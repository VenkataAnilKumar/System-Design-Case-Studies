# 3) Key Design Decisions & Trade-Offs

## 1. Push vs. Pull for Email Delivery

**Decision**: Hybrid—push via WebSocket for active users; pull (IMAP IDLE) for legacy clients.

**Rationale**:
- Push: Lower latency (instant notification); reduces polling load
- IMAP IDLE: Standard protocol; works with Outlook, Thunderbird

**Trade-off**: Push requires persistent connections (100K connections = ~5GB RAM); expensive at scale.

**When to reconsider**: If >1M concurrent users online; use mobile push notifications (APNs/FCM) instead of WebSocket; cheaper.

---

## 2. Synchronous vs. Async Spam Filtering

**Decision**: Synchronous (inline during SMTP ingestion).

**Rationale**:
- Reject spam before storing; saves storage costs
- Sender gets immediate 5xx error (discourages spammers)

**Trade-off**: Adds 200-250ms to SMTP ack latency; could time out slow clients.

**When to reconsider**: If spam filter latency > 500ms; move to async (accept all mail; filter post-ingestion); trade storage for latency.

---

## 3. Single-Tenant vs. Multi-Tenant Mailbox DB

**Decision**: Multi-tenant (shard by user_id).

**Rationale**:
- Cheaper ops: 64 shards vs. 500M single-tenant DBs
- Easier backups, schema migrations

**Trade-off**: Noisy neighbor (one user's heavy queries slow others on same shard); harder to isolate security breach.

**When to reconsider**: If targeting enterprises; offer single-tenant DB for compliance (HIPAA, finance).

---

## 4. Full-Text Search: Elasticsearch vs. PostgreSQL

**Decision**: Elasticsearch.

**Rationale**:
- Better relevance scoring (BM25, phrase matching)
- Scales horizontally (add nodes); PostgreSQL full-text is single-node bound
- Supports fuzzy search, synonyms (e.g., "receipt" matches "invoice")

**Trade-off**: Eventual consistency (emails indexed after 10-60s); extra ops complexity (cluster tuning).

**When to reconsider**: If budget-constrained; PostgreSQL GIN index + tsvector is "good enough" for <1M emails/user.

---

## 5. Attachment Deduplication: Hash vs. Content-Based

**Decision**: SHA-256 hash deduplication.

**Rationale**:
- Same attachment sent to 1000 users → store once; saves 30% storage
- Fast: Hash computed during upload; O(1) lookup

**Trade-off**: False positives if hash collision (extremely rare); privacy concern (can infer if two users received same file by comparing hashes).

**When to reconsider**: If strict privacy required (e.g., healthcare); disable deduplication; encrypt attachments per-user.

---

## 6. Virus Scanning: On-Upload vs. On-Download

**Decision**: On-upload (synchronous).

**Rationale**:
- Prevent storing malware; protects all users
- Sender notified immediately (email rejected if virus found)

**Trade-off**: Adds 100-200ms to send path; could time out for large attachments (25MB scan takes 2-3s).

**When to reconsider**: If latency critical; scan async (store encrypted; scan in background; quarantine if malware detected later).

---

## 7. SMTP Retry: Exponential Backoff vs. Fixed Interval

**Decision**: Exponential backoff (1 min, 5 min, 30 min, 2 hr, 6 hr, 24 hr; max 3 days).

**Rationale**:
- Reduces load on recipient server (avoids thundering herd)
- RFC 5321 compliant

**Trade-off**: Slow delivery for transient failures; user may complain "email not sent yet."

**When to reconsider**: If SLA requires <1 min delivery; reduce backoff; risk being blacklisted by recipient.

---

## 8. Threading: Message-ID vs. Subject Matching

**Decision**: Message-ID (In-Reply-To, References headers).

**Rationale**:
- Deterministic; RFC 5322 standard
- Handles subject changes (e.g., "Re: Meeting" → "Re: Meeting - Updated Agenda")

**Trade-off**: If sender client doesn't set In-Reply-To (broken clients), threading fails; fallback to subject+participants matching (fuzzy).

**When to reconsider**: Never—Message-ID is correct approach; but need fallback heuristics for legacy clients.
