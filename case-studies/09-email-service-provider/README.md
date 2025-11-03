# Email Service Provider

## Problem Statement

Design a **Gmail/Outlook-like email service** that reliably sends, receives, and stores billions of emails daily with high deliverability and spam protection.

**Core Challenge**: Handle 10B emails/day (115K emails/sec average, 500K peak) with <5s delivery latency, 99.99% deliverability, and <0.1% spam false positive rate.

**Key Requirements**:
- Send and receive emails via SMTP
- Spam and malware filtering (ML-based + rules)
- Email storage with search (full-text, filters)
- Delivery retries with exponential backoff
- Bounce and complaint handling
- Email authentication (SPF, DKIM, DMARC)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10B emails/day, 99.99% deliverability, <0.1% spam FP) |
| [02-architecture.md](./02-architecture.md) | Components (SMTP Gateway, Spam Filter, Storage, Delivery Service) |
| [03-key-decisions.md](./03-key-decisions.md) | Spam filtering (ML + rules), retry policies, storage optimization |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to enterprise customers, failure scenarios, monitoring |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Delivery Latency** | p95 <5s (SMTP send → inbox) |
| **Deliverability Rate** | >99.99% (not bounced/rejected) |
| **Spam False Positive** | <0.1% (legitimate emails marked spam) |
| **Availability** | 99.95% |

## Technology Stack

- **SMTP Gateway**: Postfix/Exim for inbound/outbound
- **Spam Filtering**: ML models (Naive Bayes, neural nets) + SpamAssassin rules
- **Storage**: Cassandra for emails, Elasticsearch for search
- **Delivery Queue**: Kafka for async sending with retries
- **Authentication**: SPF/DKIM/DMARC validation

## Interview Focus Areas

1. **Spam Filtering**: ML model training (labeled data), rule-based heuristics
2. **Retry Policies**: Exponential backoff (1min, 5min, 1h, 24h)
3. **Email Storage**: Compression, hot/cold tiering (recent emails on SSD)
4. **Deliverability**: IP reputation, domain warming, bounce handling
5. **Search**: Full-text indexing (Elasticsearch), query performance
