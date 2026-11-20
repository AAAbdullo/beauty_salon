import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/models/master_review.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards/app_card.dart';

/// Ряд из пяти звёзд
class StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: AppColors.gold),
      ),
    );
  }
}

/// Карточка отзыва: автор, оценка, давность, пометка «Подтверждённый визит», теги, текст, ответ мастера.
/// [showMaster] — подпись «Мастер: Алена С.» (на странице салона).
class ReviewCard extends StatelessWidget {
  final MasterReview review;
  final bool showMaster;

  /// Дополнительное содержимое внизу (например, кнопка «Ответить» в кабинете мастера)
  final Widget? footer;

  const ReviewCard({super.key, required this.review, this.showMaster = false, this.footer});

  @override
  Widget build(BuildContext context) {
    final r = review;
    final reply = r.reply;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                StarRow(rating: r.rating),
                const SizedBox(width: 4),
                Text('${r.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  r.editedAt == null
                      ? Formatters.relativeDay(r.createdAt)
                      : '${Formatters.relativeDay(r.createdAt)} · изменён',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 12, color: AppColors.successText),
                    const SizedBox(width: 3),
                    Text('Подтверждённый визит', style: TextStyle(fontSize: 10, color: AppColors.successText)),
                  ],
                ),
              ],
            ),
            if (showMaster && r.masterName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Мастер: ${r.masterName}', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
            if (r.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in r.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.comment, style: TextStyle(fontSize: 12, color: AppColors.ink, height: 1.3)),
            ],
            if (reply != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ответ мастера',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(reply.text, style: TextStyle(fontSize: 12, color: AppColors.ink, height: 1.3)),
                  ],
                ),
              ),
            ],
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

/// Сводка по отзывам: среднее, количество и полоски по звёздам 5→1
class ReviewSummaryCard extends StatelessWidget {
  final ReviewSummary summary;

  const ReviewSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.byStars.values.fold<int>(0, (a, b) => a + b);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.count == 0 ? '—' : summary.average.toStringAsFixed(1),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              StarRow(rating: summary.average.round()),
              const SizedBox(height: 2),
              Text(Formatters.reviews(summary.count), style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final stars in const [5, 4, 3, 2, 1])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$stars', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ),
                        Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : (summary.byStars[stars] ?? 0) / total,
                              minHeight: 6,
                              backgroundColor: AppColors.line,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
