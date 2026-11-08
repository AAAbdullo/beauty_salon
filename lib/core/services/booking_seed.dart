import '../models/booking_item.dart';
import '../utils/clock.dart';

/// МОК-ДАННЫЕ: начальный набор записей. Все записи ссылаются на реальные салоны, мастеров и услуги
/// каталога (по id). Бэкенд заменит это ответом GET /api/v1/bookings.
///
/// Здесь и записи текущего клиента (`seedClientId`), и записи других клиентов к мастеру Sabina Nur
/// (`m-002`, салон Nur Beauty): кабинет мастера строится из тех же записей, что и «Мои записи» клиента.
const seedClientId = 'c-001';
const seedClientName = 'Wazow';
const seedClientAvatar = 'assets/images/clients/client_wazow.jpg';

/// Услуги мастера m-002 (Сабина): id, название, минуты, кредиты, сумма
const _brows = ('m-002-s1', 'Архитектура бровей + окрашивание', 45, 24, 110000);
const _lashes = ('m-002-s2', 'Ламинирование ресниц с ботоксом', 60, 38, 170000);

typedef _Service = (String, String, int, int, int);

BookingItem _sabinaBooking({
  required String id,
  required String clientId,
  required String clientName,
  String? clientAvatar,
  required _Service service,
  required DateTime startsAt,
  String paymentMethod = PaymentMethods.credits,
  BookingStatus status = BookingStatus.active,
}) {
  return BookingItem(
    id: id,
    clientId: clientId,
    clientName: clientName,
    clientAvatar: clientAvatar,
    salonId: 's-001',
    salonName: 'Nur Beauty',
    serviceId: service.$1,
    serviceName: service.$2,
    masterId: 'm-002',
    masterName: 'Сабина',
    durationMinutes: service.$3,
    startsAt: startsAt,
    baseCredits: service.$4,
    credits: service.$4,
    sumPrice: service.$5,
    paymentMethod: paymentMethod,
    status: status,
  );
}

List<BookingItem> seedBookings() {
  final now = AppClock.now();
  DateTime at(int dayOffset, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

  // Завершённый визит в текущем календарном месяце: [daysAgo] дней назад, но не раньше 1-го числа
  DateTime thisMonth(int daysAgo, int hour) {
    final d = DateTime(now.year, now.month, now.day - daysAgo, hour);
    return d.month == now.month ? d : DateTime(now.year, now.month, 1, hour);
  }

  DateTime lastMonth(int day, int hour) => DateTime(now.year, now.month - 1, day, hour);

  return [
    // --- Записи текущего клиента -------------------------------------------------
    _sabinaBooking(
      id: 'b-001',
      clientId: seedClientId,
      clientName: seedClientName,
      clientAvatar: seedClientAvatar,
      service: _brows,
      // Осталось ~1 час 20 минут (< 2 часов) для проверки блокировки отмены
      startsAt: now.add(const Duration(minutes: 80)),
    ),
    BookingItem(
      id: 'b-005',
      clientId: seedClientId,
      clientName: seedClientName,
      clientAvatar: seedClientAvatar,
      salonId: 's-003',
      salonName: 'Mira Hair',
      serviceId: 'm-003-s3',
      serviceName: 'Женская стрижка',
      masterId: 'm-003',
      masterName: 'Дилноза',
      durationMinutes: 45,
      baseCredits: 26,
      credits: 26,
      sumPrice: 110000,
      paymentMethod: PaymentMethods.credits,
      // Осталось > 2 часов для проверки успешной отмены с возвратом кредитов
      startsAt: now.add(const Duration(hours: 22)),
    ),
    _sabinaBooking(
      id: 'b-002',
      clientId: seedClientId,
      clientName: seedClientName,
      clientAvatar: seedClientAvatar,
      service: _brows,
      // Визит 2 дня назад — ещё можно оставить отзыв (окно 7 дней, M-13)
      startsAt: at(-2, 14),
      status: BookingStatus.completed,
    ),
    BookingItem(
      id: 'b-003',
      clientId: seedClientId,
      clientName: seedClientName,
      clientAvatar: seedClientAvatar,
      salonId: 's-003',
      salonName: 'Mira Hair',
      serviceId: 'm-003-s1',
      serviceName: 'Женская стрижка + брашинг',
      masterId: 'm-003',
      masterName: 'Дилноза',
      durationMinutes: 60,
      baseCredits: 32,
      credits: 32,
      sumPrice: 140000,
      paymentMethod: PaymentMethods.online,
      startsAt: DateTime(2026, 9, 28, 10, 0),
      status: BookingStatus.completed,
      reviewRating: 5,
      reviewTags: const ['Профессионализм мастера', 'Чистота и гигиена'],
      reviewComment: 'Очень понравилась стрижка! Мастер Дилноза учла все пожелания.',
      reviewDate: DateTime(2026, 9, 28, 12, 30),
    ),

    // --- Записи других клиентов к мастеру Sabina Nur: сегодня и завтра -------------
    _sabinaBooking(id: 'x-101', clientId: 'c-101', clientName: 'Алина Каримова', service: _brows, startsAt: at(0, 10)),
    _sabinaBooking(
      id: 'x-102',
      clientId: 'c-102',
      clientName: 'Мадина Турсунова',
      service: _lashes,
      startsAt: at(0, 12),
    ),
    _sabinaBooking(
      id: 'x-103',
      clientId: 'c-103',
      clientName: 'Санобар Алиева',
      service: _brows,
      startsAt: at(0, 14),
      paymentMethod: PaymentMethods.online,
    ),
    _sabinaBooking(
      id: 'x-104',
      clientId: 'c-104',
      clientName: 'Нилуфар Рахимова',
      service: _lashes,
      startsAt: at(0, 16),
      status: BookingStatus.cancelled,
    ),
    _sabinaBooking(id: 'x-105', clientId: 'c-105', clientName: 'Дилноза Юсупова', service: _lashes, startsAt: at(1, 9)),
    _sabinaBooking(id: 'x-106', clientId: 'c-106', clientName: 'Камила Ахмедова', service: _brows, startsAt: at(1, 11)),

    // --- Завершённые визиты Sabina Nur: текущий месяц ----------------------------
    _sabinaBooking(
      id: 'x-201',
      clientId: 'c-201',
      clientName: 'Дилноза К.',
      service: _lashes,
      startsAt: thisMonth(1, 14),
      paymentMethod: PaymentMethods.online,
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-202',
      clientId: 'c-202',
      clientName: 'Сабина М.',
      service: _brows,
      startsAt: thisMonth(1, 11),
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-203',
      clientId: 'c-203',
      clientName: 'Марьям Т.',
      service: _lashes,
      startsAt: thisMonth(2, 16),
      paymentMethod: PaymentMethods.inSalon,
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-204',
      clientId: 'c-204',
      clientName: 'Нигина С.',
      service: _brows,
      startsAt: thisMonth(3, 12),
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-205',
      clientId: 'c-205',
      clientName: 'Зарина А.',
      service: _brows,
      startsAt: thisMonth(4, 15),
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-206',
      clientId: 'c-206',
      clientName: 'Лола Х.',
      service: _lashes,
      startsAt: thisMonth(5, 13),
      paymentMethod: PaymentMethods.online,
      status: BookingStatus.completed,
    ),

    // --- Завершённые визиты Sabina Nur: прошлый месяц ----------------------------
    _sabinaBooking(
      id: 'x-301',
      clientId: 'c-301',
      clientName: 'Гузаль Б.',
      service: _brows,
      startsAt: lastMonth(3, 11),
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-302',
      clientId: 'c-302',
      clientName: 'Феруза Н.',
      service: _lashes,
      startsAt: lastMonth(8, 15),
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-303',
      clientId: 'c-303',
      clientName: 'Ойша Р.',
      service: _lashes,
      startsAt: lastMonth(14, 12),
      paymentMethod: PaymentMethods.inSalon,
      status: BookingStatus.completed,
    ),
    _sabinaBooking(
      id: 'x-304',
      clientId: 'c-304',
      clientName: 'Сарвиноз Т.',
      service: _brows,
      startsAt: lastMonth(20, 10),
      paymentMethod: PaymentMethods.online,
      status: BookingStatus.completed,
    ),
  ];
}
