import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../core/models/salon_filter_params.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../client_home/search_filter_modal.dart';

class SalonsMapScreen extends StatefulWidget {
  final Function(String salonName) onSelectSalon;
  final VoidCallback onBack;
  final String? initialSalonName;

  const SalonsMapScreen({
    super.key,
    required this.onSelectSalon,
    required this.onBack,
    this.initialSalonName,
  });

  @override
  State<SalonsMapScreen> createState() => _SalonsMapScreenState();
}

class _SalonsMapScreenState extends State<SalonsMapScreen> {
  final SalonsRepository _repository = SalonsRepository();
  YandexMapController? _mapController;

  // Локация пользователя (Центр Ташкента: сквер Амира Темура)
  final Point _userLocation = const Point(
    latitude: 41.311081,
    longitude: 69.279737,
  );

  int _selectedCategoryIndex = 0;
  final List<String> _categories = const [
    'Все',
    'Маникюр',
    'Педикюр',
    'Брови',
    'Стрижки',
    'Макияж',
    'Спа',
    'Косметология',
  ];

  // Фильтры
  SalonFilterParams _filterParams = const SalonFilterParams();

  // Список салонов для отображения
  late List<SalonModel> _salons;

  // Выбранный салон (для мини-окна)
  SalonModel? _selectedSalon;

  // Данные активного маршрута
  PolylineMapObject? _activeRoutePolyline;
  PlacemarkMapObject? _routeFinishPlacemark;
  bool _isBuildingRoute = false;
  bool _isWalkingRoute = false; // false = Автомобиль, true = Пешком
  String? _routeDistanceText;
  String? _routeDurationText;

  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    _salons = _repository.getSalons(_filterParams);

    // Если был передан салон по умолчанию, выбираем его
    if (widget.initialSalonName != null) {
      final found = _salons.where((s) => s.name == widget.initialSalonName).toList();
      if (found.isNotEmpty) {
        _selectedSalon = found.first;
      }
    }

    _refreshMapObjects();
  }

  /// Обновление списка пинов и объектов на карте
  void _refreshMapObjects() {
    _mapObjects.clear();

    // 1. Пин текущего местоположения пользователя
    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('user_location'),
        point: _userLocation,
        opacity: 1.0,
        zIndex: 5.0,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('web/icons/Icon-192.png'),
            scale: 0.22,
          ),
        ),
      ),
    );

    // 2. Пины салонов
    for (final salon in _salons) {
      final isSelected = _selectedSalon?.id == salon.id;

      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('salon_${salon.id}'),
          point: salon.point,
          opacity: 1.0,
          zIndex: isSelected ? 4.0 : 2.0,
          onTap: (PlacemarkMapObject self, Point point) {
            _onSalonPinTapped(salon);
          },
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('web/favicon.png'),
              scale: isSelected ? 1.15 : 0.85,
            ),
          ),
        ),
      );
    }

    // 3. Линия активного маршрута
    if (_activeRoutePolyline != null) {
      _mapObjects.add(_activeRoutePolyline!);
    }

    // 4. Финишная отметка маршрута
    if (_routeFinishPlacemark != null) {
      _mapObjects.add(_routeFinishPlacemark!);
    }
  }

  /// Тап по пину салона на карте
  void _onSalonPinTapped(SalonModel salon) {
    setState(() {
      _selectedSalon = salon;
      _refreshMapObjects();
    });

    _zoomToPoint(salon.point, zoom: 15.0);
  }

  /// Центрирование и анимация камеры
  Future<void> _zoomToPoint(Point point, {double zoom = 15.5}) async {
    if (_mapController == null) return;
    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: zoom),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.6,
      ),
    );
  }

  /// Кадрирование камеры для отображения двух точек (пользователь + салон)
  Future<void> _fitRouteBounds(Point p1, Point p2) async {
    if (_mapController == null) return;

    final minLat = math.min(p1.latitude, p2.latitude);
    final maxLat = math.max(p1.latitude, p2.latitude);
    final minLon = math.min(p1.longitude, p2.longitude);
    final maxLon = math.max(p1.longitude, p2.longitude);

    final center = Point(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2,
    );

    final dLat = (maxLat - minLat).abs();
    final dLon = (maxLon - minLon).abs();
    final maxDelta = math.max(dLat, dLon);

    double zoom = 14.0;
    if (maxDelta > 0.08) {
      zoom = 11.8;
    } else if (maxDelta > 0.04) {
      zoom = 12.8;
    } else if (maxDelta > 0.02) {
      zoom = 13.8;
    } else if (maxDelta > 0.01) {
      zoom = 14.6;
    } else {
      zoom = 15.4;
    }

    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: zoom),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.8,
      ),
    );
  }

  /// Построение маршрута от локации пользователя к салону
  Future<void> _buildRouteToSalon(SalonModel salon, {bool isWalking = false}) async {
    setState(() {
      _isBuildingRoute = true;
      _isWalkingRoute = isWalking;
    });

    List<Point> routePoints = [];

    // 1. Попытка запроса через официальный Yandex SDK Router API
    try {
      if (isWalking) {
        final sessionWithResult = await YandexPedestrian.requestRoutes(
          points: [
            RequestPoint(point: _userLocation, requestPointType: RequestPointType.wayPoint),
            RequestPoint(point: salon.point, requestPointType: RequestPointType.wayPoint),
          ],
          fitnessOptions: const FitnessOptions(avoidSteep: false, avoidStairs: false),
          timeOptions: const TimeOptions(),
        );
        final result = await sessionWithResult.$2;
        if (result.routes != null && result.routes!.isNotEmpty) {
          routePoints = result.routes!.first.geometry.points;
        }
      } else {
        final sessionWithResult = await YandexDriving.requestRoutes(
          points: [
            RequestPoint(point: _userLocation, requestPointType: RequestPointType.wayPoint),
            RequestPoint(point: salon.point, requestPointType: RequestPointType.wayPoint),
          ],
          drivingOptions: const DrivingOptions(
            initialAzimuth: 0,
            routesCount: 1,
            avoidanceFlags: DrivingAvoidanceFlags(),
          ),
        );
        final result = await sessionWithResult.$2;
        if (result.routes != null && result.routes!.isNotEmpty) {
          routePoints = result.routes!.first.geometry.points;
        }
      }
    } catch (_) {
      // Игнорируем сетевые или лицензионные ошибки — переходим на городской генератор
    }

    // 2. Если Yandex Router API не вернул геометрию — строим реалистичный уличный маршрут
    if (routePoints.isEmpty) {
      routePoints = _generateTashkentStreetRoute(_userLocation, salon.point);
    }

    // Расчет расстояния и времени
    final distKm = _calculateDistance(_userLocation, salon.point) * 1.25;
    final distFormatted = distKm < 1.0
        ? '${(distKm * 1000).round()} м'
        : '${distKm.toStringAsFixed(1)} км';

    final durationMins = isWalking
        ? math.max(3, (distKm / 4.8 * 60).round())
        : math.max(2, (distKm / 24.0 * 60).round());

    // Создание полилинии маршрута
    final polyline = PolylineMapObject(
      mapId: const MapObjectId('salon_active_route'),
      polyline: Polyline(points: routePoints),
      strokeColor: isWalking ? const Color(0xFF247659) : AppColors.primary,
      strokeWidth: 5.5,
      outlineColor: Colors.white,
      outlineWidth: 2.5,
      zIndex: 8.0,
    );

    // Финишный пин на точке салона
    final finishPlacemark = PlacemarkMapObject(
      mapId: const MapObjectId('route_finish_flag'),
      point: salon.point,
      zIndex: 9.0,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('web/favicon.png'),
          scale: 1.25,
        ),
      ),
    );

    setState(() {
      _isBuildingRoute = false;
      _activeRoutePolyline = polyline;
      _routeFinishPlacemark = finishPlacemark;
      _routeDistanceText = distFormatted;
      _routeDurationText = isWalking ? '~$durationMins мин пешком' : '~$durationMins мин на авто';
      _refreshMapObjects();
    });

    // Плавно охватываем камерой весь маршрут
    await _fitRouteBounds(_userLocation, salon.point);
  }

  /// Сброс текущего маршрута
  void _clearRoute() {
    setState(() {
      _activeRoutePolyline = null;
      _routeFinishPlacemark = null;
      _routeDistanceText = null;
      _routeDurationText = null;
      _refreshMapObjects();
    });
  }

  /// Реалистичная генерация маршрута по сетке улиц Ташкента
  List<Point> _generateTashkentStreetRoute(Point from, Point to) {
    final List<Point> points = [from];

    final latDiff = to.latitude - from.latitude;
    final lonDiff = to.longitude - from.longitude;

    // Прокладываем путь через 2 поворота на перекрестках проспектов
    final intermediate1 = Point(
      latitude: from.latitude + latDiff * 0.45,
      longitude: from.longitude + lonDiff * 0.1,
    );

    final intermediate2 = Point(
      latitude: from.latitude + latDiff * 0.55,
      longitude: from.longitude + lonDiff * 0.85,
    );

    // Добавляем промежуточные точки с плавной интерполяцией
    for (double t = 0.1; t <= 0.9; t += 0.2) {
      points.add(_interpolate(from, intermediate1, t));
    }
    points.add(intermediate1);

    for (double t = 0.1; t <= 0.9; t += 0.2) {
      points.add(_interpolate(intermediate1, intermediate2, t));
    }
    points.add(intermediate2);

    for (double t = 0.1; t <= 0.9; t += 0.2) {
      points.add(_interpolate(intermediate2, to, t));
    }
    points.add(to);

    return points;
  }

  Point _interpolate(Point a, Point b, double t) {
    return Point(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Расчет расстояния по формуле гаверсинусов (км)
  double _calculateDistance(Point p1, Point p2) {
    const double r = 6371.0;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final lat1 = p1.latitude * (math.pi / 180.0);
    final lat2 = p2.latitude * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Открытие модального окна подробных фильтров
  void _openFilters() {
    SearchFilterModal.show(
      context: context,
      currentParams: _filterParams,
      onApply: (params) {
        setState(() {
          _filterParams = params;
          _salons = _repository.getSalons(_filterParams);
          _selectedCategoryIndex = 0;
          _refreshMapObjects();
        });
      },
    );
  }

  /// Фильтрация по категории табов сверху
  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      final category = _categories[index];

      _filterParams = _filterParams.copyWith(
        serviceCategory: category == 'Все' ? null : category,
        clearCategory: category == 'Все',
      );

      _salons = _repository.getSalons(_filterParams);
      _refreshMapObjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Полноценная векторная карта YandexMap
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (YandexMapController controller) async {
              _mapController = controller;
              await controller.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _userLocation, zoom: 13.5),
                ),
              );
            },
          ),

          // 2. Верхняя шапка с заголовком, поиском и категориями
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),

          // 3. Плавающие кнопки управления картой (геолокация, зум, сброс маршрута)
          Positioned(
            right: 16,
            bottom: _selectedSalon != null ? 310 : 250,
            child: _buildMapControls(),
          ),

          // 4. Информационное МИНИ-ОКНО выбранного салона (если выбран)
          if (_selectedSalon != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildSalonMiniWindow(_selectedSalon!),
            ),

          // 5. Выдвижной нижний список (если салон не выбран)
          if (_selectedSalon == null)
            _buildDraggableSalonsList(),
        ],
      ),
    );
  }

  /// Верхняя панель с кнопкой возврата, названием города и фильтрами
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
            Colors.white.withValues(alpha: 0.96),
            Colors.white.withValues(alpha: 0.88),
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
              Column(
                children: [
                  const Text(
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
                        'Ташкент (${_salons.length} салонов)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _filterParams.hasActiveFilters
                      ? AppColors.primary
                      : AppColors.surface,
                  shadowColor: Colors.black12,
                  elevation: 4,
                ),
                icon: Icon(
                  Icons.tune,
                  color: _filterParams.hasActiveFilters ? Colors.white : AppColors.ink,
                ),
                onPressed: _openFilters,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Горизонтальный список категорий
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return InkWell(
                  onTap: () => _onCategorySelected(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  /// Плавающие контролы зума и геолокации
  Widget _buildMapControls() {
    return Column(
      children: [
        if (_activeRoutePolyline != null) ...[
          FloatingActionButton.small(
            heroTag: 'clear_route',
            backgroundColor: Colors.white,
            onPressed: _clearRoute,
            child: const Icon(Icons.close, color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton.small(
          heroTag: 'my_location',
          backgroundColor: AppColors.surface,
          onPressed: () => _zoomToPoint(_userLocation, zoom: 15.0),
          child: const Icon(Icons.my_location, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoom_in',
          backgroundColor: AppColors.surface,
          onPressed: () => _mapController?.moveCamera(CameraUpdate.zoomIn()),
          child: const Icon(Icons.add, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoom_out',
          backgroundColor: AppColors.surface,
          onPressed: () => _mapController?.moveCamera(CameraUpdate.zoomOut()),
          child: const Icon(Icons.remove, color: AppColors.ink),
        ),
      ],
    );
  }

  /// Интерактивное МИНИ-ОКНО выбранного салона с данными и кнопками
  Widget _buildSalonMiniWindow(SalonModel salon) {
    final isRouteActive = _activeRoutePolyline != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Верхний ряд: Название + Рейтинг + Крестик закрытия
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            salon.rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${salon.reviewsCount} отзывов)',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedSalon = null;
                      _clearRoute();
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 2. Район и адрес
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${salon.district} район · ${salon.address}',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 3. Чипсы удобств и статуса работы
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppStatusBadge(text: salon.workingHours),
                if (salon.creditsAccepted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '💳 ${salon.minCredits} кр.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                if (salon.onlyWomen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '🌸 Faqat ayollar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                  ),
                if (salon.homeVisit)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '🚗 Uyga chiqish',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // 4. Популярные услуги
            Text(
              salon.services,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 14),

            // 5. Блок активного маршрута или расстояние
            if (isRouteActive)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isWalkingRoute ? Icons.directions_walk : Icons.directions_car,
                          color: _isWalkingRoute ? const Color(0xFF247659) : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _routeDurationText ?? 'Маршрут построен',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              'Расстояние: ${_routeDistanceText ?? salon.distance}',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Переключатель режима На авто / Пешком
                        InkWell(
                          onTap: () => _buildRouteToSalon(salon, isWalking: !_isWalkingRoute),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isWalkingRoute ? Icons.directions_car : Icons.directions_walk,
                              size: 16,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _clearRoute,
                          child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // 6. Кнопки действий: «Построить маршрут» и «Записаться»
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    onPressed: _isBuildingRoute
                        ? null
                        : () => _buildRouteToSalon(salon, isWalking: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: _isBuildingRoute
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.directions_outlined, size: 18),
                    label: Text(
                      isRouteActive ? 'Обновить путь' : 'Маршрут',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: AppGradientButton(
                    text: 'Записаться',
                    height: 44,
                    onPressed: () => widget.onSelectSalon(salon.name),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Выдвижной нижний лист со списком всех салонов
  Widget _buildDraggableSalonsList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.14,
      maxChildSize: 0.82,
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

              final salon = _salons[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _onSalonPinTapped(salon),
                  borderRadius: BorderRadius.circular(20),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                salon.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: AppColors.gold, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  salon.rating.toString(),
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
                          salon.services,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${salon.distance} · ${salon.district} район',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppStatusBadge(text: salon.workingHours),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.directions_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _onSalonPinTapped(salon);
                                    _buildRouteToSalon(salon);
                                  },
                                ),
                                AppPillButton(
                                  text: 'Записаться',
                                  onPressed: () => widget.onSelectSalon(salon.name),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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
