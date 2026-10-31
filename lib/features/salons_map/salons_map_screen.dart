import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
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
  YandexMapController? _mapController;
  int _selectedCategoryIndex = 0;
  final _categories = [
    'Все',
    'Маникюр',
    'Педикюр',
    'Брови',
    'Стрижки',
    'Макияж',
  ];
  // Координаты Ташкента (Центр: сквер Амира Темура)
  final Point _tashkentCenter = const Point(
    latitude: 41.311081,
    longitude: 69.279737,
  );

  final List<Map<String, dynamic>> _salons = [
    {
      'name': 'Nur Beauty',
      'services': 'Маникюр · Педикюр · Брови · Макияж',
      'rating': '4.8',
      'reviews': '126 отзывов',
      'dist': '0,6 км · Мирзо-Улугбекский район',
      'status': 'Открыто до 21:00',
      'point': const Point(latitude: 41.314500, longitude: 69.285000),
    },
    {
      'name': 'Lola Studio',
      'services': 'Стрижки · Окрашивание · Укладка',
      'rating': '4.7',
      'reviews': '98 отзывов',
      'dist': '1,2 км · Яшнабадский район',
      'status': 'Открыто до 20:00',
      'point': const Point(latitude: 41.305000, longitude: 69.292000),
    },
    {
      'name': 'Mira Hair',
      'services': 'Стрижки · Укладка · Окрашивание',
      'rating': '4.9',
      'reviews': '210 отзывов',
      'dist': '1,9 км · Шайхантахурский район',
      'status': 'Открыто до 22:00',
      'point': const Point(latitude: 41.318000, longitude: 69.262000),
    },
    {
      'name': 'Glow & Go',
      'services': 'Макияж · Косметология · Уход',
      'rating': '4.9',
      'reviews': '84 отзыва',
      'dist': '2,4 км · Яккасарайский район',
      'status': 'Открыто до 21:00',
      'point': const Point(latitude: 41.299000, longitude: 69.268000),
    },
    {
      'name': 'Zara Beauty Lab',
      'services': 'Ресницы · Ногти · Макияж',
      'rating': '4.6',
      'reviews': '55 отзывов',
      'dist': '3,1 км · Юнусабадский район',
      'status': 'Открыто до 20:00',
      'point': const Point(latitude: 41.332000, longitude: 69.289000),
    },
  ];

  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    _initMapObjects();
  }

  void _initMapObjects() {
    _mapObjects.clear();

    // 1. Пин текущей геолокации пользователя (синяя точка)
    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('user_location'),
        point: _tashkentCenter,
        opacity: 0.95,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('web/icons/Icon-192.png'),
            scale: 0.22,
          ),
        ),
      ),
    );

    // 2. Пины салонов
    for (int i = 0; i < _salons.length; i++) {
      final s = _salons[i];
      final point = s['point'] as Point;
      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('salon_${s['name']}'),
          point: point,
          opacity: 1.0,
          onTap: (PlacemarkMapObject self, Point p) {
            _showSalonMiniDialog(s);
          },
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('web/favicon.png'),
              scale: 0.8,
            ),
          ),
        ),
      );
    }
  }

  void _showSalonMiniDialog(Map<String, dynamic> salon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    salon['name']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.gold, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        salon['rating']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                salon['services']!,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                salon['dist']!,
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _zoomToPoint(salon['point'] as Point);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Приблизить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSelectSalon(salon['name']!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Записаться',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _zoomToPoint(Point point) async {
    if (_mapController == null) return;
    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 16.0)),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Полноценный виджет YandexMap
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (YandexMapController controller) async {
              _mapController = controller;
              await controller.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _tashkentCenter, zoom: 13.5),
                ),
              );
            },
          ),

          // Верхняя плашка с поиском и фильтрами
          Positioned(top: 0, left: 0, right: 0, child: _buildHeader(context)),

          // Кнопка приближения к локации пользователя
          Positioned(
            right: 16,
            bottom: 280,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'my_loc',
                  backgroundColor: AppColors.surface,
                  child: const Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _zoomToPoint(_tashkentCenter),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.add, color: AppColors.ink),
                  onPressed: () {
                    _mapController?.moveCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: AppColors.surface,
                  child: const Icon(Icons.remove, color: AppColors.ink),
                  onPressed: () {
                    _mapController?.moveCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),

          // Выдвижной нижний лист со списком салонов
          _buildDraggableSalonsList(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Ташкент, Яндекс Карты',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.primary,
                      ),
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
          // Полоска категорий
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
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

  Widget _buildDraggableSalonsList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _salons.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }
              final s = _salons[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s['name']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s['rating']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['services']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['dist']!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppStatusBadge(text: s['status']!),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.near_me_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _zoomToPoint(s['point'] as Point),
                              ),
                              AppPillButton(
                                text: 'Записаться',
                                onPressed: () =>
                                    widget.onSelectSalon(s['name']!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
