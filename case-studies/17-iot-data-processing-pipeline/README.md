# IoT Data Processing Pipeline

## Problem Statement

Design an **AWS IoT-like data processing pipeline** that ingests, processes, and analyzes data from millions of IoT devices in real-time.

**Core Challenge**: Handle 10M IoT devices sending 1 message/sec (10M msgs/sec, 600M msgs/min) with <1s processing latency and support real-time alerting and analytics.

**Key Requirements**:
- Device connection management (MQTT/CoAP)
- Message ingestion with backpressure handling
- Real-time stream processing (aggregations, alerts)
- Device state management (shadow/digital twin)
- Time-series data storage and querying
- Anomaly detection and alerting

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (10M devices, 10M msgs/sec, <1s latency) |
| [02-architecture.md](./02-architecture.md) | Components (MQTT Broker, Stream Processor, Time-Series DB, Alerting) |
| [03-key-decisions.md](./03-key-decisions.md) | MQTT vs HTTP, stream processing, time-series optimization |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to 100M devices, failure scenarios, cost optimization |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Ingestion Latency** | <100ms (device → broker → storage) |
| **Processing Latency** | <1s (message → alert/aggregation) |
| **Concurrent Connections** | 10M devices |
| **Availability** | 99.95% |

## Technology Stack

- **Device Protocol**: MQTT (lightweight, pub/sub) or CoAP (constrained devices)
- **Message Broker**: Kafka/Pulsar for buffering and fan-out
- **Stream Processing**: Apache Flink/Spark Streaming for real-time analytics
- **Time-Series DB**: InfluxDB/TimescaleDB for sensor data
- **Alerting**: Rules engine (Drools) + notification service

## Interview Focus Areas

1. **MQTT Broker**: Scalable pub/sub for millions of connections
2. **Backpressure**: Handle bursts without data loss (buffer, rate limit)
3. **Stream Processing**: Windowed aggregations (avg temperature per 5min)
4. **Device Shadow**: Cache latest state for offline devices
5. **Anomaly Detection**: ML models for predictive maintenance
