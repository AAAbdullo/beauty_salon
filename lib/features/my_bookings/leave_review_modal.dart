import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repository_exception.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../core/utils/uuid.dart';
import '../../core/l10n/app_locale.dart';

/// Модальное окно отзыва о мастере по подтверждённому визиту (ТЗ M-13).
/// Если по записи уже есть отзыв ([BookingItem.reviewId]), окно открывается для правки.
class LeaveReviewModal extends StatefulWidget {
  final BookingItem booking;

  const LeaveReviewModal({super.key, required this.booking});

  static Future<bool?> show(BuildContext context, BookingItem booking) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LeaveReviewModal(booking: booking),
    );
  }

  @override
  State<LeaveReviewModal> createState() => _LeaveReviewModalState();
}

class _LeaveReviewModalState extends State<LeaveReviewModal> {
  // Оценка не выбрана, пока клиент сам не поставит звёзды: по умолчанию 5 завышала бы рейтинг мастера
  late int _rating = widget.booking.reviewRating ?? 0;
  String? _error;
  bool _submitting = false;

  bool get _isEdit => widget.booking.reviewId != null;

  // Ключ идемпотентности: один отзыв на одну попытку
  String _requestKey = Uuid.v4();
  late final Set<String> _selectedTags = {...?widget.booking.reviewTags};
  late final TextEditingController _commentController = TextEditingController(text: widget.booking.reviewComment ?? '');

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 0:
        return 'Выберите оценку';
      case 1:
        return 'Очень плохо 😞';
      case 2:
        return 'Не понравилось 🙁';
      case 3:
        return 'Нормально 😐';
      case 4:
        return 'Хорошо 🙂';
      case 5:
      default:
        return 'Великолепно! 😍';
    }
  }

  /// Теги, подходящие к выбранной оценке (положительные при 4–5, проблемные при 1–3)
  Set<String> get _availableTags => {...ReviewTags.master(_rating), ...ReviewTags.salon(_rating)};

  void _setRating(int stars) {
    setState(() {
      _rating = stars;
      // Тег из другой группы (положительный ↔ проблемный) к новой оценке не подходит
      _selectedTags.retainAll(_availableTags);
    });
  }

  Future<void> _submitReview() async {
    if (_submitting || _rating == 0) return; // повторный тап или оценка не выбрана
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // [BACKEND NOTE]: POST /api/v1/bookings/:id/review (новый) или PATCH /api/v1/reviews/:id (правка)
      final repo = AppScope.read(context).reviews;
      final tags = _selectedTags.toList();
      final comment = _commentController.text.trim();
      final result = _isEdit
          ? await repo.edit(reviewId: widget.booking.reviewId!, rating: _rating, tags: tags, comment: comment)
          : await repo.submit(
              bookingId: widget.booking.id,
              rating: _rating,
              tags: tags,
              comment: comment,
              idempotencyKey: _requestKey,
            );
      if (!mounted) return;
      switch (result) {
        case Success():
          Navigator.pop(context, true);
        case Failure(:final error):
          setState(() {
            _submitting = false;
            _error = error.message;
            _requestKey = Uuid.v4(); // следующая попытка — новый запрос
          });
      }
    } on RepositoryException catch (e) {
      // Связь оборвалась: ключ сохраняется, повтор не отправит отзыв дважды
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _tagGroup(String title, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryTint : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.handle,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryText : AppColors.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? 'Изменить отзыв' : 'Оцените мастера',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ваша оценка формирует рейтинг мастера',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Инфо о визите
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.booking.serviceName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.booking.salonName} · Мастер: ${widget.booking.masterName}',
                          style: TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Визит: ${widget.booking.date}, ${widget.booking.time}',
                          style: TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5 звезд
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isFilled = starIndex <= _rating;
                      return GestureDetector(
                        onTap: () => _setRating(starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: isFilled ? const Color(0xFFFFA800) : const Color(0xFFD2D0DC),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingLabel(_rating),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Теги: отдельно о мастере и о салоне; появляются, когда выбрана оценка
            if (_rating > 0) ...[
              _tagGroup('О мастере', ReviewTags.master(_rating)),
              const SizedBox(height: 14),
              _tagGroup('О салоне', ReviewTags.salon(_rating)),
              const SizedBox(height: 20),
            ],

            // Комментарий
            Text(
              'Комментарий (по желанию)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: ReviewRules.maxCommentLength,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: tr('Поделитесь впечатлениями о сервисе, мастере или атмосфере салона...'),
                hintStyle: TextStyle(fontSize: 12, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            if (_rating > 0 && _rating <= ReviewRules.lowRatingMax) ...[
              const SizedBox(height: 8),
              Text(
                'Выберите причину или опишите, что не понравилось',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],

            const SizedBox(height: 24),

            // Кнопка отправки
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_submitting || _rating == 0) ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.handle,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isEdit ? 'Сохранить' : 'Отправить отзыв',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
