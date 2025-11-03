# 4) Wrap-Up: Scaling, Failures, Interview Tips

## Scaling Playbook

**0 → 10M users (~100K emails/day)**
- Single SMTP server; single PostgreSQL instance
- Local spam filter (SpamAssassin); ClamAV for virus scan
- Store attachments on local disk
- Simple full-text search (PostgreSQL GIN index)

**10M → 100M users (~1B emails/day)**
- Shard mailbox DB by user_id (4 shards)
- Add Kafka for mail queue (3 brokers; 6 partitions)
- Deploy Elasticsearch (3 nodes; 1B docs indexed)
- Move attachments to S3; enable deduplication
- Horizontal scale SMTP receivers (10 instances; load-balanced)

**100M → 500M users (~10B emails/day)**
- 64 mailbox shards (PostgreSQL); read replicas for analytics
- Kafka: 12 brokers; 48 partitions
- Elasticsearch: 50 nodes; 10TB index; 10B docs
- Spam filter: GPU-accelerated ML inference (100 instances)
- Multi-region: US-East, US-West, EU (data residency for GDPR)
- CDN for attachments (CloudFront); cache popular files (e.g., company logos)

**Beyond 500M (Gmail scale)**
- Custom storage engine (Bigtable-like; columnar; compression)
- Distribute spam model inference to edge (TensorFlow Lite on SMTP receivers)
- Proactive caching: Pre-fetch inbox for likely-to-login users (ML prediction)
- Global Anycast SMTP (route to nearest data center)
- Quantum-safe encryption (post-quantum cryptography for future-proofing)

---

## Failure Scenarios

| Failure | Impact | Detection | Mitigation |
|---|---|---|---|
| SMTP Receiver Crash | Incoming mail rejected | Health check fails | Load balancer routes to healthy instances; MX failover to backup (DNS TTL 5 min) |
| Spam Filter Overloaded | Emails delayed; queue backs up | Kafka consumer lag > 10K msgs | Scale consumers (add 10 instances); temporarily skip ML model (rule-based only) |
| Elasticsearch Down | Search broken; inbox still works | Cluster status red | Read-only mode; show cached results; rebuild index from DB (takes 2 days for 10B emails) |
| Mailbox Shard Outage | 1/64 of users cannot read/send | DB connection timeout | Failover to read replica (promote to master); users see read-only mode for 5 min |
| Attachment S3 Outage | Cannot download attachments | S3 API errors | Serve from cache (CloudFront); if cache miss, show "Temporarily unavailable" |
| Virus Scanner API Down | Emails with attachments stuck | Scanner timeout (10s) | Bypass scanner (risky); quarantine for manual review; or reject with 4xx (temp fail) |
| Sender Reputation Drop | Emails bouncing; blacklisted | Bounce rate > 10% | Throttle outbound; investigate spam complaints; request de-listing from blacklists |

---

## SLOs (Service Level Objectives)

- **Uptime**: 99.9% availability (43 min downtime/month); measured by synthetic test emails every 1 min
- **Send Latency**: p95 < 500ms (user clicks Send → SMTP ack)
- **Inbox Load**: p95 < 200ms (fetch 50 latest emails)
- **Search Latency**: p95 < 1s (full-text search over 10K emails)
- **Deliverability**: >99% of sent emails reach inbox (not spam, not bounced)
- **Spam Accuracy**: <1% false negatives (spam in inbox); <0.1% false positives (real mail in spam)

---

## Common Pitfalls

1. **Ignoring SPF/DKIM/DMARC**: Outbound emails marked spam by recipients; symptom: low deliverability (50%); solution: Configure DNS records correctly; monitor alignment
2. **No rate-limiting on SMTP**: Attackers flood server; symptom: SMTP receiver CPU 100%; solution: Per-IP rate limit (100 emails/min); per-user rate limit (1000 emails/day)
3. **Storing raw MIME in DB**: Wastes space (2x overhead); symptom: Storage explodes; solution: Store parsed body_text + body_html separately; compress; dedupe attachments
4. **Synchronous virus scan on send**: Adds 3s latency for large attachments; symptom: User timeout; solution: Async scan; return "Email queued" immediately; notify if virus found
5. **No backpressure in mail queue**: Kafka lag grows indefinitely during spike; symptom: Emails delayed 1+ hour; solution: Reject new emails with 4xx (temp fail) when lag > 100K msgs

---

## Interview Talking Points

- **SMTP protocol basics**: How does `MAIL FROM`, `RCPT TO`, `DATA` work? What's the difference between `250 OK` (success) and `4xx` (temp fail, retry)?
- **Spam detection evolution**: Start with blacklists → Add regex rules → Train ML model on user feedback → Use embeddings (BERT) for semantic spam (e.g., "You won a prize" phrased differently)
- **Why Kafka for mail queue?**: Durability (replicated); replay (reprocess if spam model updated); decoupling (SMTP ingestion independent of processing)
- **Search relevance**: How to rank search results? BM25 (term frequency); recency (newer emails higher); user interaction (clicked results boost future ranking)
- **Attachment deduplication trade-offs**: Privacy (can infer if two users received same file); storage savings (30%); virus scan efficiency (scan once, protect all users)
- **Global scaling**: Data residency (GDPR: EU users in EU data centers); MX routing (GeoDNS: route to nearest SMTP receiver); attachment CDN (CloudFront: serve from edge)

---

## Follow-Up Questions to Explore

- How would you add end-to-end encryption (E2EE)? (PGP or S/MIME; key exchange challenges; cannot search encrypted body)
- How to prevent account takeover? (2FA mandatory; CAPTCHA on login; rate-limit password attempts; alert on login from new device)
- How to handle large attachments (>25MB)? (Upload to cloud storage; send link instead of inline attachment; expire link after 30 days)
- How would you support calendar invites (iCal)? (Parse .ics attachment; extract event details; sync with calendar service; RSVP buttons in email)
- How to scale spam model training? (Distributed training on GPU cluster; sample 1B emails; weekly retraining; A/B test new model before rollout)
- How to migrate users from legacy system? (IMAP sync: fetch all emails from old server; preserve folder structure, read status; dedup by Message-ID; cutover DNS MX records)
