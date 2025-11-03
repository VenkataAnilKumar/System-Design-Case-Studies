# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Ingestion: MQTT, CoAP, HTTP; device auth (certs, tokens); protocol translation
- Data Validation: Schema enforcement, range checks, deduplication
- Stream Processing: Aggregation (1-min/5-min windows), enrichment, anomaly detection
- Storage: Time-series DB; hot (7 days), warm (90 days), cold (years)
- Alerting: Rule-based + ML anomalies; fan-out to SMS/email/webhooks; deduplication
- Device Management: Registry, twin state (desired/reported), OTA firmware updates
- Visualization: Dashboards, historical queries, drill-downs
- Data Export: Batch to data lake (Parquet/Avro) for analytics

## Non-Functional Requirements

- Throughput: 1M events/sec; bursts to 5M/sec
- Latency: Ingestion p95 < 500ms; alerting p95 < 2s
- Availability: 99.9% for ingestion; 99.5% for query
- Durability: Zero message loss; at-least-once delivery with idempotency
- Cost: Optimize storage tiering; compression; sampling for non-critical metrics

## Scale Estimate

- Devices: 100M; send telemetry every 10s avg → 10M events/sec baseline
- Event size: 500B avg → 5GB/sec → 400TB/day (compressed to ~100TB/day)
- Hot storage: 7 days × 100TB = 700TB SSD
- Warm/cold: 10PB total over years

## Constraints

- Device heterogeneity: Firmware versions, network (2G/3G/4G/5G/LTE-M/NB-IoT), power
- Clock skew: Devices may lack NTP; server-side timestamping required
- Bandwidth: Constrain payload size; batch when possible

## Success Measures

- Ingestion success rate > 99.9%; message loss < 0.01%
- Alert latency p95 < 2s; false positive rate < 1%
- Query p95 < 3s for 24h window; < 30s for 90-day
- Cost per device per month within budget ($0.10 target)