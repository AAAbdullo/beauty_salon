import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';

class SalonsMapScreen extends StatefulWidget {
  final Function(String salonName) onSelectSalon;
  final VoidCallback onBack;

  const SalonsMapScreen({
    super.key,
    required this.onSelectSalon,
    required this.onBack,
  });

  @override
  State<SalonsMapScreen> createState() => _SalonsMapScreenState();
}

class _SalonsMapScreenState extends State<SalonsMapScreen> {
  int _selectedCategoryIndex = 0;
  final _categories = ['Все', 'Маникюр', 'Педикюр', 'Брови', 'Стрижки', 'Макияж'];

  final _salons = [
    {
      'name': 'Nur Beauty',
      'services': 'Маникюр · Педикюр · Брови · Макияж',
      'rating': '4.8',
      'reviews': '126 отзывов',
      'dist': '0,6 км · Мирзо-Улугбекский район',
      'status': 'Открыто до 21:00',
    },
    {
      'name': 'Lola Studio',
      'services': 'Стрижки · Окрашивание · Укладка',
      'rating': '4.7',
      'reviews': '98 отзывов',
      'dist': '1,2 км · Яшнабадский район',
      'status': 'Открыто до 20:00',
    },
    {
      'name': 'Mira Hair',
      'services': 'Стрижки · Укладка · Окрашивание',
      'rating': '4.9',
      'reviews': '210 отзывов',
      'dist': '1,9 км · Шайхантахурский район',
      'status': 'Открыто до 22:00',
    },
    {
      'name': 'Sana Brow',
      'services': 'Брови · Ресницы · Ламинирование',
      'rating': '4.6',
      'reviews': '85 отзывов',
      'dist': '2,4 км · Мирабадский район',
      'status': 'Открыто до 20:00',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Карта (стилизованный фон карты Ташкента с пинами)
          Positioned.fill(
            child: _buildMapBackground(),
          ),

          // Верхний бар поиска и фильтров
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopOverlay(),
          ),

          // Нижняя шторка со списком салонов
          _buildDraggableSalonsSheet(),
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shadowColor: Colors.black12,
                  elevation: 4,
                ),
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: widget.onBack,
              ),
              const Column(
                children: [
                  Text(
                    'Салоны рядом',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  Row(
                    children: [
                      Text('Ташкент', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.muted),
                    ],
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shadowColor: Colors.black12,
                  elevation: 4,
                ),
                icon: const Icon(Icons.tune, color: AppColors.ink),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Поисковая строка
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.muted, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Поиск салонов, услуг или мастеров',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Чипсы категорий
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      color: const Color(0xFFF3F1EC),
      child: Stack(
        children: [
          // Центр (геолокация пользователя)
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7BFF).withValues(alpha: 0.2),
              ),
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E7BFF),
                  ),
                ),
              ),
            ),
          ),
          // Пины салонов
          Positioned(
            top: 240,
            left: 50,
            child: _buildMapPin('Nur Beauty', '4.8', '0,6 км'),
          ),
          Positioned(
            top: 280,
            right: 40,
            child: _buildMapPin('Lola Studio', '4.7', '1,2 км'),
          ),
          Positioned(
            top: 400,
            left: 70,
            child: _buildMapPin('Mira Hair', '4.9', '1,9 км'),
          ),
          Positioned(
            top: 420,
            right: 60,
            child: _buildMapPin('Sana Brow', '4.6', '2,4 км'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin(String name, String rating, String dist) {
    return InkWell(
      onTap: () => widget.onSelectSalon(name),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryTint,
                  child: const Icon(Icons.storefront, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 12, color: AppColors.primary),
                Text(rating, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                Text(dist, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSalonsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Список салонов',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      Text('Сортировка', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._salons.map((s) => _buildSalonCard(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalonCard(Map<String, String> s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => widget.onSelectSalon(s['name']!),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront, color: AppColors.primary, size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s['name']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          AppStatusBadge(text: s['status']!),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s['services']!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text('${s["rating"]!} (${s["reviews"]!})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text(s['dist']!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppPillButton(
                  text: 'Записаться',
                  onPressed: () => widget.onSelectSalon(s['name']!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
