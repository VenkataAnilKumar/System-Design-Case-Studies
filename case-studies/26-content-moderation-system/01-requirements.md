# Requirements & Scale

## Functional Requirements
1. **AI Classification**: Text (hate speech, spam), Images (NSFW, violence), Video (frame-by-frame + audio analysis)
2. **Human Review Queue**: Escalate uncertain cases (confidence 50-80%) to moderators
3. **Appeals Process**: Users can appeal takedowns, secondary review by senior moderators
4. **Feedback Loop**: Moderator decisions retrain ML models (active learning)
5. **Multi-Language**: Support 100+ languages with locale-specific policies
6. **Real-Time**: Moderate content before publishing (pre-moderation) or immediately after (post-moderation)

## Non-Functional Requirements
**Performance**: <1s AI classification, <10s human review assignment
**Accuracy**: 99.5% precision (minimize false positives), 95% recall (catch harmful content)
**Scalability**: 100M items/day, 10K concurrent moderators
**Compliance**: GDPR (data retention 90 days), CSAM reporting (NCMEC)

## Scale Estimates
**Traffic**: 100M posts/day = 1,157 posts/sec avg, 5K posts/sec peak
**Content Mix**: 60% text, 30% images, 10% video
**Moderation**: AI handles 90% (pass/block), humans review 10% (1M items/day)
**Moderators**: 10K moderators × 100 reviews/day = 1M reviews/day capacity

**Infrastructure**:
- AI Servers: 100 GPU nodes (NVIDIA T4) for image/video classification
- Text NLP: 50 CPU nodes (BERT/GPT models)
- Review Platform: 20 web servers for moderator UI

**Cost**: ~$150K/mo (compute) + $10M/year (moderator labor @ $15/hr × 10K moderators)
