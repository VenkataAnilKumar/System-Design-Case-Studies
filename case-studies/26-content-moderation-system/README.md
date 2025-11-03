# Content Moderation System

## Problem Statement

Design a **Facebook/YouTube-like content moderation system** that automatically detects and removes harmful content (hate speech, NSFW, violence) at scale.

**Core Challenge**: Moderate 100M posts/day (1,157 posts/sec) with <1s AI classification and 99.5% precision (minimize false positives) while escalating 10% uncertain cases to human review.

**Key Requirements**:
- AI classification (text, images, video)
- Human review queue for uncertain cases
- Appeals process for false positives
- Multi-language support (100+ languages)
- Real-time moderation (pre-publish or post-publish)
- Feedback loop (retrain models with human decisions)

## Design Documents

| Document | Description |
|----------|-------------|
| [01-requirements.md](./01-requirements.md) | Scale estimates (100M posts/day, <1s AI, 99.5% precision) |
| [02-architecture.md](./02-architecture.md) | Components (AI Classifiers, Review Queue, Appeals, Feedback Loop) |
| [03-key-decisions.md](./03-key-decisions.md) | Pre vs post-moderation, confidence thresholds, active learning |
| [04-wrap-up.md](./04-wrap-up.md) | Scaling to billions, failure scenarios, compliance (CSAM reporting) |

## Key Metrics

| Metric | Target |
|--------|--------|
| **AI Classification** | <1s per item |
| **Precision** | >99.5% (minimize false positives) |
| **Recall** | >95% (catch harmful content) |
| **Human Review SLA** | <10min for high-priority (CSAM) |

## Technology Stack

- **Text AI**: BERT-based hate speech detection
- **Image AI**: ResNet/EfficientNet for NSFW/violence
- **Video AI**: Frame sampling (1 FPS) + audio transcription
- **Review Queue**: Priority queue (CSAM → violence → hate speech)
- **Retraining**: Active learning (weekly model updates)

## Interview Focus Areas

1. **Confidence Thresholds**: High (>80%) auto-block, medium (50-80%) human review
2. **Pre vs Post-Moderation**: Post-moderation for UX, pre-moderation for kids apps
3. **Active Learning**: Use human decisions to retrain models
4. **Multi-Language**: Single multilingual model (mBERT) vs per-language models
5. **CSAM Detection**: Perceptual hashing (PhotoDNA) + ML classification
