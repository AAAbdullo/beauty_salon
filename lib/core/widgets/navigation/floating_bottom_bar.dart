import 'package:flutter/material.dart' hide Text;
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';
import '../layout/fixed_height_box.dart';
import '../../l10n/app_locale.dart';

/// Плавающий BottomNavigationBar ("таблетка") по спецификации:
/// Радиус ~28, отступы от краев 16, высота 64, активный пункт подсвечен primaryTint.
/// Используется как `Scaffold.bottomNavigationBar`: тело экрана заканчивается над баром,
/// поэтому экранам не нужны ручные нижние отступы под него.
class FloatingBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingBarItem> items;

  const FloatingBottomBar({super.key, required this.currentIndex, required this.onTap, required this.items});

  /// Цвет «подложки» бара — совпадает с нижним цветом [AppGradients.page],
  /// чтобы бар визуально продолжал экран, а не лежал поверх контента.
  static Color get backgroundColor => AppColors.barBackground;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: fixedHeightMaxTextScale, child: _buildBar(context));

  Widget _buildBar(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: tr(item.label),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(index),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected ? AppColors.primary : AppColors.muted,
                                size: 22,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primary : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingBarItem({required this.icon, required this.selectedIcon, required this.label});
}
