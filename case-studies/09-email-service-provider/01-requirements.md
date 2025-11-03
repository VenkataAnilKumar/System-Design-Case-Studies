# 1) Functional & Non-Functional Requirements

## Functional Requirements

### Core Email Operations
- Send email: Compose, attach files (up to 25MB), send to multiple recipients
- Receive email: SMTP ingestion; spam filtering; virus scanning; deliver to inbox
- Read email: Fetch mailbox; threading/conversation view; mark read/unread
- Search: Full-text search over subject, body, attachments; filters (from, date range, has:attachment)
- Organize: Folders, labels, archive, delete, undo delete (trash retention 30 days)
- Attachments: Upload/download; preview (images, PDFs); virus scan on receive

### Advanced Features
- Spam detection: ML-based + rule-based (SPF/DKIM/DMARC); user feedback (mark as spam)
- Deliverability: Sender reputation; bounce handling (hard/soft); unsubscribe links for bulk mail
- Threading: Group replies into conversations; sort by latest message
- Contacts: Auto-complete; import from CSV; sync with address book
- Push notifications: Mobile/desktop alerts for new mail (IMAP IDLE or WebSocket)

### Compliance & Security
- Encryption: TLS for SMTP; at-rest encryption (AES-256)
- Audit: Retention for legal (eDiscovery); export user data (GDPR)
- 2FA: Require for login; app-specific passwords for IMAP/SMTP clients

## Non-Functional Requirements

- **Availability**: 99.9% uptime (43 min downtime/month); graceful degradation (read-only mode if write DB is down)
- **Latency**: Send email <500ms (p95); search <1s for 10K emails; inbox load <200ms
- **Throughput**: 10B emails/day (~115K emails/sec average, 300K/sec peak); 100K SMTP connections/sec
- **Deliverability**: >99% for legitimate emails; <0.1% false positives (real mail marked spam)
- **Storage**: 15GB free per user; 1PB total (500M users × 2GB avg); compressed + deduplicated attachments
- **Spam Accuracy**: <1% false negatives (spam in inbox); <0.1% false positives (real mail in spam)
- **Search**: Index all emails; full-text search in <1s; support 10-year history per user

## Scale Estimate

- **Users**: 500M active; 50M DAU (daily active)
- **Emails**: 10B/day sent/received (~5B inbound SMTP, 5B outbound)
- **Storage**: 500M users × 2GB avg = 1PB (compressed); attachments 50% of total
- **Search Index**: 10B emails × 10KB avg metadata = 100TB index (Elasticsearch)
- **SMTP Connections**: Peak 100K/sec (morning rush hour); avg 50K/sec
- **Attachments**: 5B emails/day × 30% have attachments × 2MB avg = 3PB/day raw (dedupe to ~500TB/day)

## Constraints

- SMTP protocol (RFC 5321): Must support standard clients (Outlook, Thunderbird, mobile)
- IMAP/POP3 for retrieval: Legacy protocol support
- SPF/DKIM/DMARC: Required for sender authentication; prevent spoofing
- CAN-SPAM Act: Unsubscribe link for bulk mail; honor opt-outs
- GDPR: Right to export/delete user data; data residency (EU users in EU data centers)

## Success Measures

- **Deliverability rate**: % of sent emails that reach inbox (target >99%)
- **Spam accuracy**: Precision (spam in spam folder) >99%; Recall (spam not in inbox) >99%
- **Search relevance**: Click-through rate on top search result >80%
- **Uptime**: 99.9% availability (measured by synthetic monitors sending test emails)
- **Latency**: p95 send latency <500ms; p95 search latency <1s
