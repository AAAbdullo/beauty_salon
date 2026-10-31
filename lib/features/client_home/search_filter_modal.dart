import 'package:flutter/material.dart';
import '../../core/models/salon_filter_params.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';

/// Модальное окно фильтрации каталога салонов (ТЗ M-04)
class SearchFilterModal extends StatefulWidget {
  final SalonFilterParams initialParams;
  final ValueChanged<SalonFilterParams> onApply;

  const SearchFilterModal({
    super.key,
    required this.initialParams,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required SalonFilterParams currentParams,
    required ValueChanged<SalonFilterParams> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(
        initialParams: currentParams,
        onApply: onApply,
      ),
    );
  }

  @override
  State<SearchFilterModal> createState() => _SearchFilterModalState();
}

class _SearchFilterModalState extends State<SearchFilterModal> {
  late String? _selectedDistrict;
  late bool _onlyWomen;
  late bool _homeVisit;
  late bool _creditsOnly;
  late bool _availableToday;
  late double _minRating;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.initialParams.district;
    _onlyWomen = widget.initialParams.onlyWomen;
    _homeVisit = widget.initialParams.homeVisit;
    _creditsOnly = widget.initialParams.creditsOnly;
    _availableToday = widget.initialParams.availableToday;
    _minRating = widget.initialParams.minRating;
    _priceRange = RangeValues(
      widget.initialParams.minPrice,
      widget.initialParams.maxPrice,
    );
  }

  void _reset() {
    setState(() {
      _selectedDistrict = null;
      _onlyWomen = false;
      _homeVisit = false;
      _creditsOnly = false;
      _availableToday = false;
      _minRating = 0.0;
      _priceRange = const RangeValues(0.0, 1000000.0);
    });
  }

  void _apply() {
    final updated = widget.initialParams.copyWith(
      district: _selectedDistrict,
      clearDistrict: _selectedDistrict == null,
      onlyWomen: _onlyWomen,
      homeVisit: _homeVisit,
      creditsOnly: _creditsOnly,
      availableToday: _availableToday,
      minRating: _minRating,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Хедер шторки
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Фильтры',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Сбросить', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Тело фильтров со скроллом
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Быстрые опции по ТЗ (Особые условия)
                  const Text('Особенности (ТЗ)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Только для женщин',
                    subtitle: 'Faqat ayollar uchun (закрытый женский зал)',
                    icon: Icons.female,
                    value: _onlyWomen,
                    onChanged: (v) => setState(() => _onlyWomen = v),
                  ),
                  _buildToggleTile(
                    title: 'Выезд на дом',
                    subtitle: 'Uyga chiqish (мастер выезжает к клиенту)',
                    icon: Icons.home_work_outlined,
                    value: _homeVisit,
                    onChanged: (v) => setState(() => _homeVisit = v),
                  ),
                  _buildToggleTile(
                    title: 'Оплата по абонементу (Кредиты)',
                    subtitle: 'Kredit bilan (принимают кредиты Go\'zallik)',
                    icon: Icons.credit_card,
                    value: _creditsOnly,
                    onChanged: (v) => setState(() => _creditsOnly = v),
                  ),
                  _buildToggleTile(
                    title: 'Свободно сегодня',
                    subtitle: 'Bugun bo\'sh (есть открытые слоты на сегодня)',
                    icon: Icons.bolt,
                    value: _availableToday,
                    onChanged: (v) => setState(() => _availableToday = v),
                  ),
                  const SizedBox(height: 20),

                  // 2. Районы Ташкента (ТЗ M-04)
                  const Text('Район Ташкента', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SalonsRepository.tashkentDistricts.map((district) {
                      final isSelected = _selectedDistrict == district;
                      return ChoiceChip(
                        label: Text(district),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.ink,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedDistrict = selected ? district : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 3. Минимальный рейтинг
                  const Text('Рейтинг салона', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [0.0, 4.0, 4.5, 4.8].map((rating) {
                      final isSelected = _minRating == rating;
                      final label = rating == 0.0 ? 'Любой' : '★ $rating+';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.background,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.ink,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (s) => setState(() => _minRating = s ? rating : 0.0),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 4. Диапазон цен
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Цена услуги', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(
                        '${(_priceRange.start / 1000).toInt()}k – ${(_priceRange.end / 1000).toInt()}k сум',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0.0,
                    max: 1000000.0,
                    divisions: 20,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primaryTint,
                    onChanged: (vals) => setState(() => _priceRange = vals),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка применения
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: AppGradientButton(
              text: 'Показать результаты',
              onPressed: _apply,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? AppColors.primaryTint.withValues(alpha: 0.4) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: value ? Colors.white : AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
