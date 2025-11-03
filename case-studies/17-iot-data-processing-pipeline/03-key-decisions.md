# 3) Key Design Decisions & Trade-Offs

## 1. MQTT vs. HTTP for Ingestion

**Decision**: Support both; prefer MQTT for persistent connections.

**Rationale**: MQTT lower overhead for high-frequency telemetry; HTTP for simple devices.

**Trade-off**: Two protocols to maintain; MQTT brokers harder to scale.

**When to reconsider**: If devices are all cloud-native; HTTP-only is simpler.

---

## 2. Schema Enforcement: Strict vs. Flexible

**Decision**: Strict schema with versioning; reject invalid payloads.

**Rationale**: Prevent downstream errors; easier to evolve schema with versions.

**Trade-off**: Device firmware updates required for schema changes.

**When to reconsider**: Rapid prototyping; allow flexible JSON but validate critical fields only.

---

## 3. Stream Processing: Stateless vs. Stateful

**Decision**: Stateful (Flink with checkpoints).

**Rationale**: Windowed aggregations and anomaly detection require state (last N values).

**Trade-off**: Checkpoint overhead; recovery slower; operational complexity.

**When to reconsider**: Simple use cases (no aggregations); stateless processors are simpler.

---

## 4. Time-Series DB: Single vs. Sharded

**Decision**: Sharded by time (monthly) and device_id range.

**Rationale**: Queries typically scoped by time; even load distribution.

**Trade-off**: Cross-shard queries need federation; complex routing.

**When to reconsider**: If all queries are single-device; no sharding needed.

---

## 5. Alerting: Real-Time vs. Batched

**Decision**: Real-time with sub-second latency.

**Rationale**: Critical alerts (fire, equipment failure) need immediate action.

**Trade-off**: Higher infrastructure cost; alert storms risk.

**When to reconsider**: Non-critical metrics; batch every 1–5 min to reduce cost.

---

## 6. Cold Storage: Retention Forever vs. TTL

**Decision**: TTL (7 years) with option to export before expiry.

**Rationale**: Compliance (e.g., GDPR right to delete); cost control.

**Trade-off**: Data loss if not exported; need proactive archival.

**When to reconsider**: Regulatory requirements mandate longer retention; adjust TTL.

---

## 7. OTA Updates: Full vs. Delta Patches

**Decision**: Delta patches with fallback to full.

**Rationale**: Save bandwidth (critical for cellular devices); faster apply.

**Trade-off**: Complexity in diff generation; corruption risk.

**When to reconsider**: High-bandwidth devices (WiFi); full firmware is simpler.
