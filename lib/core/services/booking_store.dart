import 'package:flutter/foundation.dart';
import '../models/booking_item.dart';
import 'booking_seed.dart';

/// Единый источник записей. Клиентские «Мои записи», расписание и доход мастера, занятость слотов —
/// всё это проекции одного списка: изменили запись здесь — обновились все экраны.
///
/// Стор хранит только данные и не знает правил (кредиты, отмена, слоты) — они в `AppStateService`
/// и `SlotService`. Модель записи неизменяемая: изменение = [replace] новой версией.
///
/// [BACKEND NOTE]: заменится на репозиторий с GET /api/v1/bookings.
class BookingStore extends ChangeNotifier {
  static final BookingStore _instance = BookingStore._internal();
  factory BookingStore() => _instance;
  BookingStore._internal() : _items = seedBookings();

  List<BookingItem> _items;

  List<BookingItem> get all => List.unmodifiable(_items);

  BookingItem? byId(String id) {
    for (final b in _items) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Записи клиента
  List<BookingItem> forClient(String clientId) => _items.where((b) => b.clientId == clientId).toList();

  /// Записи мастера
  List<BookingItem> forMaster(String masterId) => _items.where((b) => b.masterId == masterId).toList();

  /// Записи, занимающие время мастера (или салона, если мастеров в каталоге нет)
  List<BookingItem> occupying({required String salonId, String? masterId}) => _items
      .where(
        (b) =>
            b.occupiesTime && b.salonId == salonId && (masterId == null ? b.masterId == null : b.masterId == masterId),
      )
      .toList();

  void add(BookingItem booking) {
    _items = [booking, ..._items];
    notifyListeners();
  }

  /// Подменяет запись новой версией с тем же id. Возвращает false, если записи нет.
  bool replace(BookingItem booking) {
    final index = _items.indexWhere((b) => b.id == booking.id);
    if (index == -1) return false;
    final next = [..._items];
    next[index] = booking;
    _items = next;
    notifyListeners();
    return true;
  }

  /// Вернуть начальные данные (выход из аккаунта)
  void reset() {
    _items = seedBookings();
    notifyListeners();
  }
}
