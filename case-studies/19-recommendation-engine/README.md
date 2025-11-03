# Recommendation Engine

## Problem Statement

Design a **Netflix/Amazon-like recommendation engine** that suggests personalized content to users based on their behavior and preferences.

**Core Challenge**: Generate personalized recommendations for 100M users with <100ms p99 latency while balancing relevance (CTR >10%) and diversity (avoid filter bubbles).

**Key Requirements**:
- Collaborative filtering (user-user, item-item similarity)
- Content-based filtering (item features, user preferences)
- Hybrid model combining multiple signals
- Real-time updates based on user actions
- A/B testing infrastructure for model variants
- Explainability (why this recommendation?)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100M users, <100ms latency, >10% CTR) |
| [02-architecture.md](./02-architecture.md) | Components (Offline Training, Online Serving, Feature Store, A/B Testing) |
| [03-key-decisions.md](./03-key-decisions.md) | Collaborative vs content-based, matrix factorization, neural networks |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to billions of items, failure scenarios, cold start problem |

## Key Metrics

| Metric | Target |
|--------|--------|
| **Recommendation Latency** | p99 <100ms |
| **Click-Through Rate** | >10% (recommendations clicked) |
| **Diversity** | >50% recommendations from different categories |
| **Coverage** | >80% of catalog recommended at least once |

## Technology Stack

- **Offline Training**: Spark for batch model training (daily/weekly)
- **Online Serving**: Pre-computed recommendations (Redis cache)
- **Feature Store**: User/item features (Feast, Tecton)
- **ML Models**: Matrix factorization (ALS), deep learning (two-tower, transformers)
- **A/B Testing**: Multi-armed bandits, Thompson sampling

## Interview Focus Areas

1. **Collaborative Filtering**: User-based vs item-based similarity
2. **Matrix Factorization**: SVD, ALS for latent factors
3. **Cold Start**: New user/item with no interaction history
4. **Online Learning**: Update models in real-time based on clicks
5. **Diversity**: Balance relevance with exploration (avoid echo chambers)
