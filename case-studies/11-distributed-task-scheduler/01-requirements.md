# 1) Functional & Non-Functional Requirements

## Functional Requirements

- Scheduling: One-off (run at 2025-11-01T10:00Z), recurring (cron), backfill (re-run past windows)
- DAGs: Define task graphs with dependencies (A → B, C); conditional branches; retries; timeouts
- Execution: Distribute tasks to workers; priorities; concurrency limits per queue/tenant
- Retries: Exponential backoff; max attempts; dead-letter queue; jitter; pause/resume
- Idempotency: Exactly-once effect via idempotent tasks and dedupe keys
- Observability: Task logs, metrics, traces; SLAs and alerts; audit trail
- Multi-Tenancy: Namespaces; quotas; isolation; per-tenant rate limits
- Artifacts: Pass small payloads via queue; large artifacts via object storage (S3)
- Human-in-the-Loop: Approvals for high-risk tasks; manual retries/cancels
- APIs/UI: Create/trigger DAGs; monitor runs; search by status; fetch logs

## Non-Functional Requirements

- Availability: 99.99% for the control plane (scheduler/orchestrator)
- Durability: No task lost; logs retained 30 days (hot) → 1 year (cold)
- Semantics: At-least-once delivery; tasks must be idempotent; dedupe window 24h
- Latency: Schedule → dispatch < 500ms p95; heartbeats every 10s; failure detection < 30s
- Throughput: 1M task dispatches/min; 50K DAG submissions/min; 100K worker heartbeats/sec
- Scalability: 100K workers; 2M concurrent timers; 1B tasks/day
- Security: mTLS between components; per-tenant authz; secret management (KMS)

## Scale Estimate

- Tasks/day: 1B → avg 11.6K/sec; peaks 60K/sec (top-of-hour crons)
- Timers: 2M active cron schedules; tick granularity 1s (hierarchical timing wheel)
- Metadata: 1B task records/day × 500B = 500GB/day (cold store S3; hot index: 3 days)
- Logs: Avg 10KB/task → 10TB/day (compressed; tier to cold storage)

## Constraints

- Worker heterogeneity: Some tasks require GPUs, some CPU-only; scheduling must respect labels
- Long-running tasks: Hours/days; heartbeats must sustain outages/restarts
- Clock skew: Control plane must tolerate ±100ms skew across nodes
- Backpressure: Protect DB/queues from spikes (e.g., mass retries)

## Success Measures

- Orchestration Availability: 99.99% during business hours
- Schedule Latency: p95 < 500ms from schedule to dispatch
- Task Success Rate: >99% (excluding user-code failures)
- No Lost Tasks: 0 tasks dropped; verifiable via end-to-end counters
- SLA Adherence: % of DAGs meeting deadlines; alert on breaches
