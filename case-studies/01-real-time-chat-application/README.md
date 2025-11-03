# Real-Time Chat Application

## Problem Statement

Design a **WhatsApp/Slack-like messaging system** that enables users to send and receive messages instantly with high reliability and scale.

**Core Challenge**: Handle 100M daily active users sending 10B messages/day (115K msgs/sec average, 500K peak) while maintaining real-time delivery (p99 <100ms) and 99.95% availability.

**Key Requirements**:
- Real-time bidirectional communication (send/receive instantly)
- Group chats with delivery/read receipts
- Online presence and typing indicators
- Media sharing (images, videos, files)
- Offline message delivery via push notifications
- Message persistence and history

## Key Features

### Core Capabilities
- **1-on-1 & Group Messaging**: Text, images, videos, files
- **Delivery Receipts**: Sent ✓, Delivered ✓✓, Read ✓✓ (blue)
- **Presence & Typing Indicators**: Online/offline, last seen, typing status
- **Message History**: Persistent storage with pagination
- **Push Notifications**: For offline users
- **Media Handling**: Upload/download with CDN distribution

### Technical Highlights
- **WebSocket** persistent connections for real-time bidirectional communication
- **Message Queue** (Kafka) for reliable async message delivery
- **NoSQL** (Cassandra) for horizontal scalability of message history
- **Redis** for presence/online status tracking
- **CDN** for media delivery (images, videos, files)

## Architecture Approach

- **Stateful Gateway**: WebSocket servers maintain persistent connections
- **Message Broker**: Kafka for fan-out to group members and offline queuing
- **Database Sharding**: Partition messages by conversation_id
- **Session Service**: Track user→server mapping for message routing
- **Push Notification Service**: APNs/FCM integration for offline delivery

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Functional/non-functional requirements, scale estimates (10B msgs/day, 100M DAU) |
| [02-architecture.md](./02-architecture.md) | High-level architecture, components (Gateway, Message Service, Presence), data flows |
| [03-key-decisions.md](./03-key-decisions.md) | Technical trade-offs: WebSocket vs polling, message ordering, read receipts, media storage |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling playbook (MVP→1B users), failure scenarios, SLO commitments, common pitfalls |

## Quick Start

1. **Understand Requirements**: Start with [01-requirements.md](./01-requirements.md) to grasp scale (10B msgs/day) and constraints (p99 <100ms delivery)
2. **Study Architecture**: Review [02-architecture.md](./02-architecture.md) for component breakdown and data flows
3. **Deep Dive Decisions**: Read [03-key-decisions.md](./03-key-decisions.md) for trade-offs (pull vs push, message durability)
4. **Explore Edge Cases**: Check [04-wrap-up.md](./04-wrap-up.md) for failure handling, scaling stages, interview tips

## Key Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| **Latency** | p99 <100ms | Message delivery for online users |
| **Throughput** | 500K msgs/sec | Peak traffic (10× average) |
| **Availability** | 99.95% | ~22 min/month downtime |
| **Storage** | 2PB | 10B msgs/day × 200 bytes × 365 days |
| **Connections** | 100M concurrent | WebSocket connections (50M online users × 2 devices) |

## Technology Stack

- **Real-Time**: WebSocket (persistent connections)
- **Message Queue**: Apache Kafka (fan-out, offline queuing)
- **Database**: Cassandra (messages), PostgreSQL (users/groups), Redis (presence)
- **Storage**: S3/CDN for media files
- **Push**: APNs (iOS), FCM (Android)
- **Load Balancing**: Consistent hashing for WebSocket servers

## Interview Focus Areas

When discussing this design in interviews, emphasize:

1. **WebSocket Management**: How to handle 100M persistent connections (scale horizontally, session affinity)
2. **Message Ordering**: Per-conversation ordering with sequence numbers (avoid global ordering)
3. **Group Message Fan-Out**: Kafka for async delivery to N members (avoid synchronous N writes)
4. **Read Receipts**: Aggregate read status per message (track last-read message_id per user)
5. **Offline Delivery**: Queue messages in Kafka, deliver on reconnect + push notification
6. **Presence at Scale**: Heartbeat every 30s, Redis TTL for online status (avoid database writes)

## Related Case Studies

- [02-ride-sharing](../02-ride-sharing) - Real-time location tracking (similar WebSocket patterns)
- [12-live-streaming-platform](../12-live-streaming-platform) - Real-time media delivery
- [21-distributed-message-broker](../21-distributed-message-broker) - Message queue internals (Kafka-like)

---

**Note**: This is a design-only case study focused on architecture, trade-offs, and scalability. Implementation details (code) are out of scope.
