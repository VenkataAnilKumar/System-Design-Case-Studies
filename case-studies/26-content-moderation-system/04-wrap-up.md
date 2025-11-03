# Wrap-Up & Deep Dives

## Scaling Playbook

**Stage 1 (MVP)**: Single hate speech classifier (BERT), manual review queue, 10 moderators.
**Stage 2 (Production)**: Multi-class classifiers (hate, NSFW, spam), 1K moderators, appeals system, weekly retraining.
**Stage 3 (Scale)**: Ensemble models, 10K moderators, real-time video moderation, active learning, regional compliance (GDPR, CCPA).

## Failure Scenarios
- **Classifier Down**: Fall back to human review for all content (100× queue backlog).
- **False Positive Spike**: Retrain model immediately, manual review of recent blocks.
- **CSAM Miss**: Report to NCMEC within 24h (legal requirement), audit model.

## SLO Commitments
- **CSAM Detection**: 99.9% recall (catch harmful content)
- **False Positive Rate**: <0.5% (minimize wrongful blocks)
- **Human Review Latency**: p95 <10s assignment, <5min resolution for P0 (CSAM)
- **Appeals Turnaround**: <24h for standard, <1h for urgent

## Common Pitfalls
1. **Overfitting to Training Data**: Model memorizes examples, fails on new patterns. Use diverse training data.
2. **Moderator Burnout**: Viewing harmful content daily causes PTSD. Rotate moderators, provide counseling.
3. **No Appeals Process**: Users feel helpless when wrongfully blocked. Always allow appeals.
4. **Ignoring Edge Cases**: Sarcasm, satire, cultural context confuse AI. Use human review for borderline cases.
5. **Static Thresholds**: Spam tactics evolve → model accuracy degrades. Retrain weekly.

## Interview Talking Points
- **AI + Human Hybrid**: "AI handles 90% (high-confidence), humans review 10% (uncertain cases) → cost-efficient scaling."
- **Confidence-Based Routing**: "Score 95% → auto-block, 65% → human review, 30% → approve (CSAM uses lower threshold for recall)."
- **Active Learning**: "Moderator decisions → training data → retrain weekly → improve model accuracy from 95% → 97%."
- **CSAM Compliance**: "Perceptual hashing (PhotoDNA) for known images + ML for new variants → report to NCMEC within 24h."

## Follow-Up Questions
1. **Adversarial Attacks**: How do you detect users bypassing filters (leetspeak: "h4t3" instead of "hate")?
2. **Multi-Modal**: Combine text + image (meme with hateful caption) for holistic moderation?
3. **Real-Time Video**: Moderate live streams with <1s latency (frame-by-frame + audio)?
4. **Explainability**: Show users why content was blocked (SHAP values for transparency)?
5. **Cross-Platform**: Moderate content across web, mobile, VR (different abuse patterns)?

**Final Thought**: Content moderation balances **safety** (catch harmful content) with **freedom of speech** (minimize false positives). The key challenge is **context**—same word can be harmless or hateful depending on tone, culture, intent. AI provides scale, humans provide nuance.
