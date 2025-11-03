# Key Technical Decisions

## 1. Pre-Moderation vs. Post-Moderation
**Decision**: **Post-moderation** (publish first, moderate after) for user experience.
**Rationale**: Pre-moderation adds 1-10s delay (AI + human) → hurts UX. Post-moderation allows instant publish, take down within 1min if harmful.
**Reconsider**: For high-risk platforms (kids' apps), use pre-moderation.

## 2. Confidence Thresholds: Fixed vs. Adaptive
**Decision**: **Adaptive thresholds** based on content type/region.
**Rationale**: CSAM requires 99.9% recall (low threshold 30%) vs. spam tolerates false positives (high threshold 80%).
**Reconsider**: For simple use cases, fixed threshold (70%) is easier to tune.

## 3. Human Review: Centralized Queue vs. Per-Moderator Assignment
**Decision**: **Centralized queue** with load balancing.
**Rationale**: Avoids idle moderators (uneven workload), enables prioritization (CSAM first).
**Reconsider**: For specialized teams (CSAM experts), use dedicated queues.

## 4. Model Retraining: Batch vs. Online Learning
**Decision**: **Batch retraining** (weekly) with new labeled data.
**Rationale**: Online learning risks concept drift (model forgets old patterns). Batch allows validation before deploy.
**Reconsider**: For fast-evolving threats (new spam tactics), use daily retraining.

## 5. Video Moderation: Frame Sampling vs. Full Video
**Decision**: **Frame sampling** (1 FPS) + audio transcription.
**Rationale**: Full video analysis = 1000× cost (10 min video = 600 frames). Sampling catches most violations.
**Reconsider**: For high-risk content (live streams), use real-time full-frame analysis.

## 6. Appeals: Automatic Re-Review vs. Human Escalation
**Decision**: **Human escalation** to senior moderators.
**Rationale**: Appeals are low-volume (<5% of blocks), high-stakes (user trust). Humans provide empathy, nuance.
**Reconsider**: For spam/low-severity, use automatic re-classification.

## 7. CSAM Detection: Perceptual Hashing vs. ML Classification
**Decision**: **Both** (perceptual hashing for known images, ML for new variants).
**Rationale**: PhotoDNA hash catches 99% of known CSAM (instant lookup). ML catches new images (95% recall).
**Reconsider**: For non-CSAM use cases, ML-only is sufficient.

## 8. Multi-Language: Single Model vs. Per-Language Models
**Decision**: **Single multilingual model** (mBERT) for common languages, **per-language** for critical markets.
**Rationale**: Single model is simpler (one deployment), but per-language models are more accurate (99% vs. 95%).
**Reconsider**: For <10 languages, use per-language models (higher accuracy).
