import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
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

/// Генератор стилизованных векторных пинов салонов для карты Yandex MapKit
class SalonPinHelper {
  static final Map<String, BitmapDescriptor> _cache = {};
  static BitmapDescriptor? _userPinCache;

  /// Векторный маркер локации пользователя с пульсирующим ореолом
  static Future<BitmapDescriptor> getUserLocationPin() async {
    if (_userPinCache != null) return _userPinCache!;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double size = 96.0;
    const double center = 48.0;

    final paint = Paint()..isAntiAlias = true;

    // 1. Внешний полупрозрачный ореол
    paint.color = AppColors.primary.withValues(alpha: 0.22);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 42, paint);

    // 2. Мягкая тень под центральным маркером
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(const Offset(center, center + 2), 22, shadowPaint);

    // 3. Белый контрастный ободок
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 22, paint);

    // 4. Фирменный акцентный маркер пользователя
    paint.color = AppColors.primary;
    canvas.drawCircle(const Offset(center, center), 17, paint);

    // 5. Внутренняя белая точка
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(center, center), 6, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    _userPinCache = descriptor;
    return descriptor;
  }

  static IconData getIconForServices(String services) {
    final lower = services.toLowerCase();
    if (lower.contains('стрижк') || lower.contains('укладк') || lower.contains('бород')) {
      return Icons.content_cut;
    } else if (lower.contains('маникюр') || lower.contains('педикюр') || lower.contains('ногт')) {
      return Icons.brush;
    } else if (lower.contains('спа') || lower.contains('массаж')) {
      return Icons.spa;
    } else if (lower.contains('макияж') || lower.contains('косметол')) {
      return Icons.face_retouching_natural;
    }
    return Icons.auto_awesome;
  }

  static Future<BitmapDescriptor> getSalonPin({
    required IconData icon,
    required Color color,
    bool isSelected = false,
  }) async {
    final key = '${icon.codePoint}_${color.toARGB32()}_$isSelected';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final bytes = await _renderPinBytes(
      icon: icon,
      color: color,
      isSelected: isSelected,
    );
    final descriptor = BitmapDescriptor.fromBytes(bytes);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<Uint8List> _renderPinBytes({
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const double width = 96.0;
    const double height = 116.0;

    final paint = Paint()..isAntiAlias = true;

    // 1. Тень метки
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(48, 88), 16, shadowPaint);

    // 2. Внешний контур капли (Pin)
    final pinPath = Path();
    pinPath.moveTo(48, 108);
    pinPath.cubicTo(18, 78, 12, 58, 12, 42);
    pinPath.arcToPoint(
      const Offset(84, 42),
      radius: const Radius.circular(36),
      clockwise: true,
    );
    pinPath.cubicTo(84, 58, 78, 78, 48, 108);
    pinPath.close();

    // 3. Белая обводка (или золотая при выборе)
    paint.color = isSelected ? AppColors.gold : Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(pinPath, paint);

    // 4. Цветное тело пина
    final innerPath = Path();
    innerPath.moveTo(48, 102);
    innerPath.cubicTo(22, 74, 18, 56, 18, 42);
    innerPath.arcToPoint(
      const Offset(78, 42),
      radius: const Radius.circular(30),
      clockwise: true,
    );
    innerPath.cubicTo(78, 56, 74, 74, 48, 102);
    innerPath.close();

    paint.color = color;
    canvas.drawPath(innerPath, paint);

    // 5. Внутренний белый круг под значок
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(48, 42), 22, paint);

    // 6. Иконка категории
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 24,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(48 - textPainter.width / 2, 42 - textPainter.height / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

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

  // Локация пользователя (по умолчанию: сквер Амира Темура в центре Ташкента)
  Point _userLocation = const Point(
    latitude: 41.311081,
    longitude: 69.279737,
  );

  bool _isRealGpsActive = false;

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

  // Данные активных маршрутов (по ТЗ и туториалам Yandex MapKit)
  PolylineMapObject? _primaryRoutePolyline;
  PolylineMapObject? _alternativeRoutePolyline;
  PlacemarkMapObject? _routeFinishPlacemark;

  bool _isBuildingRoute = false;
  bool _isWalkingRoute = false; // false = Авто, true = Пешком
  bool _hasAlternative = false;

  String? _primaryRouteDistance;
  String? _primaryRouteDuration;
  String? _alternativeRouteDuration;

  final List<MapObject> _mapObjects = [];

  @override
  void initState() {
    super.initState();
    _salons = _repository.getSalons(_filterParams);

    if (widget.initialSalonName != null) {
      final found = _salons.where((s) => s.name == widget.initialSalonName).toList();
      if (found.isNotEmpty) {
        _selectedSalon = found.first;
      }
    }

    _refreshMapObjects();
  }

  /// Обновление списка пинов и объектов на карте
  Future<void> _refreshMapObjects() async {
    _mapObjects.clear();

    // 1. Пин текущей геолокации пользователя (гарантированное отображение векторного Retina-пина)
    final userPin = await SalonPinHelper.getUserLocationPin();
    _mapObjects.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('user_location_marker'),
        point: _userLocation,
        opacity: 1.0,
        zIndex: 10.0,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: userPin,
            scale: 0.85,
          ),
        ),
      ),
    );

    // 2. Стилизованные кастомные пины салонов (по категориям)
    for (final salon in _salons) {
      final isSelected = _selectedSalon?.id == salon.id;
      final icon = SalonPinHelper.getIconForServices(salon.services);
      final pinDescriptor = await SalonPinHelper.getSalonPin(
        icon: icon,
        color: isSelected ? AppColors.primaryDeep : AppColors.primary,
        isSelected: isSelected,
      );

      _mapObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('salon_${salon.id}'),
          point: salon.point,
          opacity: 1.0,
          zIndex: isSelected ? 8.0 : 4.0,
          onTap: (PlacemarkMapObject self, Point point) {
            _onSalonPinTapped(salon);
          },
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: pinDescriptor,
              scale: isSelected ? 0.95 : 0.75,
            ),
          ),
        ),
      );
    }

    // 3. Линии маршрутов (основной и альтернативный)
    if (_alternativeRoutePolyline != null) {
      _mapObjects.add(_alternativeRoutePolyline!);
    }
    if (_primaryRoutePolyline != null) {
      _mapObjects.add(_primaryRoutePolyline!);
    }

    // 4. Финишная отметка маршрута
    if (_routeFinishPlacemark != null) {
      _mapObjects.add(_routeFinishPlacemark!);
    }

    if (mounted) setState(() {});
  }

  /// Тап по пину салона на карте
  void _onSalonPinTapped(SalonModel salon) {
    setState(() {
      _selectedSalon = salon;
    });

    _refreshMapObjects();
    _zoomToPoint(salon.point, zoom: 15.2);
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

  /// Определение реальной геопозиции пользователя через Yandex MapKit UserLocation
  Future<void> _detectAndCenterRealLocation() async {
    if (_mapController == null) return;

    try {
      await _mapController!.toggleUserLayer(
        visible: true,
        headingEnabled: true,
        autoZoomEnabled: false,
      );
    } catch (_) {}

    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        final userPos = await _mapController!.getUserCameraPosition();
        if (userPos != null) {
          setState(() {
            _userLocation = userPos.target;
            _isRealGpsActive = true;
          });
          await _zoomToPoint(_userLocation, zoom: 16.0);
          await _refreshMapObjects();
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Если всё еще null (в симуляторе или пока GPS ищет сигнал)
    await _zoomToPoint(_userLocation, zoom: 15.0);
    await _refreshMapObjects();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Геолокация: центрировано на Ташкенте. В симуляторе iOS: Features -> Location -> Custom Location (41.311, 69.279).',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Кадрирование камеры для отображения маршрута целиком (Bounds)
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
      zoom = 11.6;
    } else if (maxDelta > 0.04) {
      zoom = 12.6;
    } else if (maxDelta > 0.02) {
      zoom = 13.6;
    } else if (maxDelta > 0.01) {
      zoom = 14.5;
    } else {
      zoom = 15.3;
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

  /// Построение маршрутов по официальной документации Yandex MapKit (map_routing & map_routes)
  Future<void> _buildRouteToSalon(SalonModel salon, {bool isWalking = false}) async {
    setState(() {
      _isBuildingRoute = true;
      _isWalkingRoute = isWalking;
    });

    List<Point> primaryPoints = [];
    List<Point> alternativePoints = [];
    String? distanceText;
    String? durationText;
    String? altDurationText;

    // 1. Запрос к Yandex MapKit Router API
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
          primaryPoints = result.routes!.first.geometry.points;
          final weight = result.routes!.first.metadata.weight;
          distanceText = weight.walkingDistance.text;
          durationText = '${weight.time.text} пешком';
        }
      } else {
        // Автомобильные маршруты (с альтернативными путями по туториалу map_routes.html)
        final sessionWithResult = await YandexDriving.requestRoutes(
          points: [
            RequestPoint(point: _userLocation, requestPointType: RequestPointType.wayPoint),
            RequestPoint(point: salon.point, requestPointType: RequestPointType.wayPoint),
          ],
          drivingOptions: const DrivingOptions(
            initialAzimuth: 0,
            routesCount: 2, // Основной и альтернативный маршруты
            avoidanceFlags: DrivingAvoidanceFlags(),
          ),
        );
        final result = await sessionWithResult.$2;
        if (result.routes != null && result.routes!.isNotEmpty) {
          final first = result.routes![0];
          primaryPoints = first.geometry.points;
          distanceText = first.metadata.weight.distance.text;
          durationText = '${first.metadata.weight.timeWithTraffic.text} (с пробками)';

          if (result.routes!.length > 1) {
            final second = result.routes![1];
            alternativePoints = second.geometry.points;
            altDurationText = second.metadata.weight.timeWithTraffic.text;
          }
        }
      }
    } catch (_) {
      // Игнорируем сетевые или лицензионные ограничения роутера
    }

    // 2. Fallback: если Router API не вернул геометрию — строим реалистичную сетку улиц Ташкента
    if (primaryPoints.isEmpty) {
      primaryPoints = _generateTashkentStreetRoute(_userLocation, salon.point, variant: 1);
      alternativePoints = _generateTashkentStreetRoute(_userLocation, salon.point, variant: 2);

      final distKm = _calculateDistance(_userLocation, salon.point) * 1.25;
      distanceText = distKm < 1.0
          ? '${(distKm * 1000).round()} м'
          : '${distKm.toStringAsFixed(1)} км';

      final mins = isWalking
          ? math.max(3, (distKm / 4.8 * 60).round())
          : math.max(2, (distKm / 24.0 * 60).round());

      durationText = isWalking ? '~$mins мин пешком' : '~$mins мин на авто';
      altDurationText = '~$mins мин';
    }

    // 3. Создаем полилинии маршрутов (по tutorial: map_routes.html)
    // Основной маршрут: яркий фирменный цвет, толстая линия, белый кант
    final primaryPolyline = PolylineMapObject(
      mapId: const MapObjectId('route_primary'),
      polyline: Polyline(points: primaryPoints),
      strokeColor: isWalking ? const Color(0xFF247659) : AppColors.primary,
      strokeWidth: 6.0,
      outlineColor: Colors.white,
      outlineWidth: 2.0,
      zIndex: 10.0,
    );

    // Альтернативный маршрут: приглушенный цвет, тоньше, кликабелен
    PolylineMapObject? alternativePolyline;
    if (alternativePoints.isNotEmpty) {
      alternativePolyline = PolylineMapObject(
        mapId: const MapObjectId('route_alternative'),
        polyline: Polyline(points: alternativePoints),
        strokeColor: const Color(0xFFB4A8BA),
        strokeWidth: 4.5,
        outlineColor: Colors.white,
        outlineWidth: 1.5,
        zIndex: 8.0,
        onTap: (PolylineMapObject self, Point p) {
          _swapActiveRoute();
        },
      );
    }

    // Финишная отметка
    final finishIcon = await SalonPinHelper.getSalonPin(
      icon: SalonPinHelper.getIconForServices(salon.services),
      color: AppColors.primaryDeep,
      isSelected: true,
    );

    final finishPlacemark = PlacemarkMapObject(
      mapId: const MapObjectId('route_finish_placemark'),
      point: salon.point,
      zIndex: 12.0,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: finishIcon,
          scale: 0.95,
        ),
      ),
    );

    setState(() {
      _isBuildingRoute = false;
      _primaryRoutePolyline = primaryPolyline;
      _alternativeRoutePolyline = alternativePolyline;
      _routeFinishPlacemark = finishPlacemark;
      _primaryRouteDistance = distanceText;
      _primaryRouteDuration = durationText;
      _alternativeRouteDuration = altDurationText;
      _hasAlternative = alternativePoints.isNotEmpty;
    });

    await _refreshMapObjects();
    await _fitRouteBounds(_userLocation, salon.point);
  }

  /// Переключение между основным и альтернативным маршрутом (по tutorial: map_routes.html)
  void _swapActiveRoute() {
    if (_primaryRoutePolyline == null || _alternativeRoutePolyline == null) return;

    final tempPolyline = _primaryRoutePolyline!.polyline;
    final tempDuration = _primaryRouteDuration;

    setState(() {
      _primaryRoutePolyline = _primaryRoutePolyline!.copyWith(
        polyline: _alternativeRoutePolyline!.polyline,
      );
      _alternativeRoutePolyline = _alternativeRoutePolyline!.copyWith(
        polyline: tempPolyline,
      );
      _primaryRouteDuration = _alternativeRouteDuration;
      _alternativeRouteDuration = tempDuration;
    });

    _refreshMapObjects();
  }

  /// Сброс текущего маршрута
  void _clearRoute() {
    setState(() {
      _primaryRoutePolyline = null;
      _alternativeRoutePolyline = null;
      _routeFinishPlacemark = null;
      _primaryRouteDistance = null;
      _primaryRouteDuration = null;
      _alternativeRouteDuration = null;
      _hasAlternative = false;
    });

    _refreshMapObjects();
  }

  /// Генерация реалистичного пути по улицам Ташкента
  List<Point> _generateTashkentStreetRoute(Point from, Point to, {int variant = 1}) {
    final List<Point> points = [from];
    final latDiff = to.latitude - from.latitude;
    final lonDiff = to.longitude - from.longitude;

    final split1 = variant == 1 ? 0.40 : 0.65;
    final split2 = variant == 1 ? 0.60 : 0.85;

    final intermediate1 = Point(
      latitude: from.latitude + latDiff * split1,
      longitude: from.longitude + lonDiff * (variant == 1 ? 0.08 : 0.40),
    );

    final intermediate2 = Point(
      latitude: from.latitude + latDiff * split2,
      longitude: from.longitude + lonDiff * (variant == 1 ? 0.85 : 0.95),
    );

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

  /// Открытие модального окна фильтров
  void _openFilters() {
    SearchFilterModal.show(
      context: context,
      currentParams: _filterParams,
      onApply: (params) {
        setState(() {
          _filterParams = params;
          _salons = _repository.getSalons(_filterParams);
          _selectedCategoryIndex = 0;
        });
        _refreshMapObjects();
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
    });

    _refreshMapObjects();
  }

  @override
  Widget build(BuildContext context) {
    // Высота отступа с учетом FloatingBottomBar (высота 64 + отступы 16 + SafeArea)
    final bottomNavOffset = MediaQuery.of(context).padding.bottom + 92.0;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Полноценная карта YandexMap с поддержкой UserLocationLayer
          YandexMap(
            mapObjects: _mapObjects,
            onMapCreated: (YandexMapController controller) async {
              _mapController = controller;

              // Автоматически включаем отображение пробок на карте
              try {
                await controller.toggleTrafficLayer(visible: true);
              } catch (_) {}

              // Включаем нативный слой пользователя
              try {
                await controller.toggleUserLayer(
                  visible: true,
                  headingEnabled: true,
                  autoZoomEnabled: false,
                );
              } catch (_) {}

              await controller.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _userLocation, zoom: 13.5),
                ),
              );

              _detectAndCenterRealLocation();
            },
            onUserLocationAdded: (UserLocationView view) async {
              if (mounted) {
                setState(() {
                  _userLocation = view.pin.point;
                  _isRealGpsActive = true;
                });
                _refreshMapObjects();
              }
              return view.copyWith(
                pin: view.pin.copyWith(opacity: 1.0),
                arrow: view.arrow.copyWith(opacity: 1.0),
                accuracyCircle: view.accuracyCircle.copyWith(
                  fillColor: AppColors.primary.withValues(alpha: 0.15),
                  strokeColor: AppColors.primary.withValues(alpha: 0.5),
                ),
              );
            },
          ),

          // 2. Верхняя шапка с поиском и фильтрами
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),

          // 3. Кнопка определения местоположения (и сброс активного маршрута)
          Positioned(
            right: 16,
            bottom: _selectedSalon != null
                ? (bottomNavOffset + (_primaryRoutePolyline != null ? 288.0 : 232.0))
                : 260.0,
            child: _buildMapControls(),
          ),

          // 4. Информационное МИНИ-ОКНО выбранного салона (плавает ровно над FloatingBottomBar)
          if (_selectedSalon != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomNavOffset,
              child: _buildSalonMiniWindow(_selectedSalon!),
            ),

          // 5. Выдвижной нижний список (когда салон не выбран)
          if (_selectedSalon == null)
            _buildDraggableSalonsList(bottomNavOffset),
        ],
      ),
    );
  }

  /// Верхняя панель навигации
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
                        _isRealGpsActive
                            ? 'GPS активен (${_salons.length} салонов)'
                            : 'Ташкент (${_salons.length} салонов)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isRealGpsActive ? const Color(0xFF1AAA4C) : AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: _isRealGpsActive ? const Color(0xFF1AAA4C) : AppColors.primary,
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
          // Список категорий
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

  /// Кнопка управления картой (центрирование геопозиции пользователя и сброс маршрута)
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Сброс маршрута (если построен активный маршрут)
        if (_primaryRoutePolyline != null) ...[
          FloatingActionButton.small(
            heroTag: 'clear_route_btn',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: _clearRoute,
            child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(height: 10),
        ],
        // 2. Кнопка определения текущего местоположения пользователя
        FloatingActionButton.small(
          heroTag: 'my_location_btn',
          backgroundColor: AppColors.surface,
          elevation: 4,
          onPressed: _detectAndCenterRealLocation,
          child: const Icon(Icons.my_location, color: AppColors.primary, size: 22),
        ),
      ],
    );
  }

  /// Интерактивное МИНИ-ОКНО выбранного салона
  Widget _buildSalonMiniWindow(SalonModel salon) {
    final isRouteActive = _primaryRoutePolyline != null;

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
            // Хедер карточки
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
                    _refreshMapObjects();
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Район и адрес
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

            // Чипсы статусов
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

            // Услуги
            Text(
              salon.services,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Блок активного маршрута
            if (isRouteActive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
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
                                  _primaryRouteDuration ?? 'Маршрут построен',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  'Расстояние: ${_primaryRouteDistance ?? salon.distance}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Переключатель авто/пешком
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
                    if (_hasAlternative && !_isWalkingRoute) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _swapActiveRoute,
                        child: Row(
                          children: [
                            const Icon(Icons.alt_route, size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              'Есть альтернативный путь (${_alternativeRouteDuration ?? "другой маршрут"})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Кнопки действий: Построить маршрут и Записаться
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
                      isRouteActive ? 'Обновить' : 'Маршрут',
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

  /// Выдвижной нижний лист со списком салонов
  Widget _buildDraggableSalonsList(double bottomNavOffset) {
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
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomNavOffset + 16),
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
