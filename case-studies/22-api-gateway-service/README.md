# API Gateway Service

## Problem Statement

Design an **Kong/Apigee-like API Gateway** that serves as a single entry point for all client requests with routing, authentication, rate limiting, and monitoring.

**Core Challenge**: Handle 100K requests/sec with <50ms p99 latency overhead while providing authentication, rate limiting, and request transformation without becoming a bottleneck.

**Key Requirements**:
- Request routing to backend services
- Authentication and authorization (JWT, OAuth)
- Rate limiting per API key/user (token bucket)
- Request/response transformation
- Caching for GET requests
- Monitoring and analytics (latency, errors, traffic)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100K req/sec, <50ms overhead, rate limiting) |
| [02-architecture.md](./02-architecture.md) | Components (Gateway Nodes, Rate Limiter, Auth Service, Cache) |
| [03-key-decisions.md](./03-key-decisions.md) | Rate limiting algorithms, caching strategies, circuit breakers |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to millions of APIs, failure scenarios, observability |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Gateway Overhead** | <50ms p99 (added latency) |
| **Throughput** | 100K req/sec per node |
| **Availability** | 99.99% |
| **Rate Limit Accuracy** | >99% (minimal false positives) |

## Technology Stack

- **Gateway**: Nginx/Envoy for request routing
- **Rate Limiting**: Token bucket (Redis for distributed state)
- **Authentication**: JWT validation, OAuth token introspection
- **Caching**: Redis for GET request caching
- **Monitoring**: Prometheus + Grafana for metrics

## Interview Focus Areas

1. **Rate Limiting**: Token bucket algorithm (distributed with Redis)
2. **Circuit Breaker**: Prevent cascading failures (fail fast)
3. **Caching**: Cache GET responses with cache-control headers
4. **Authentication**: JWT vs API keys (stateless vs stateful)
5. **Service Discovery**: Dynamic routing to backend services
