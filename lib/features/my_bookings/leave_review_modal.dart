import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';

/// Модальное окно оценки и отзыва о прошедшем визите (ТЗ M-13)
class LeaveReviewModal extends StatefulWidget {
  final BookingItem booking;

  const LeaveReviewModal({
    super.key,
    required this.booking,
  });

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
  int _rating = 5;
  final Set<String> _selectedTags = {'Профессионализм мастера', 'Чистота и гигиена'};
  final TextEditingController _commentController = TextEditingController();
  final _appState = AppStateService();

  static const List<String> _positiveTags = [
    'Чистота и гигиена',
    'Профессионализм мастера',
    'Вежливый персонал',
    'Уютная атмосфера',
    'Быстро и аккуратно',
    'Вкусный кофе / чай',
    'Соотношение цена/качество',
  ];

  static const List<String> _criticalTags = [
    'Долгое ожидание',
    'Неаккуратная работа',
    'Недостаточная чистота',
    'Шумно в салоне',
    'Мастер был не в настроении',
  ];

  String _getRatingLabel(int rating) {
    switch (rating) {
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

  void _submitReview() {
    // [BACKEND NOTE]: При подключении NestJS этот вызов отправляет
    // POST /api/v1/bookings/:id/review
    // body: {
    //   "bookingId": widget.booking.id,
    //   "rating": _rating,
    //   "tags": _selectedTags.toList(),
    //   "comment": _commentController.text.trim(),
    // }
    _appState.addReview(
      bookingId: widget.booking.id,
      rating: _rating,
      tags: _selectedTags.toList(),
      comment: _commentController.text.trim(),
    );

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableTags = _rating >= 4 ? _positiveTags : _criticalTags;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
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
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Оцените визит',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ваш отзыв помогает делать сервис лучше',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.muted),
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
                border: Border.all(color: const Color(0xFFF3DCE8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Визит: ${widget.booking.date}, ${widget.booking.time}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
                        onTap: () {
                          setState(() {
                            _rating = starIndex;
                            _selectedTags.clear();
                          });
                        },
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Теги впечатления
            Text(
              _rating >= 4 ? 'Что вам понравилось?' : 'Что салону стоит улучшить?',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableTags.map((tag) {
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
                        color: isSelected ? AppColors.primary : const Color(0xFFE5E5EA),
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

            const SizedBox(height: 20),

            // Комментарий
            const Text(
              'Комментарий (по желанию)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Поделитесь впечатлениями о сервисе, мастере или атмосфере салона...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF3DCE8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF3DCE8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Кнопка отправки
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Отправить отзыв',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
