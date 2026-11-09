import 'package:flutter/foundation.dart';

/// Пакет кредитов (ТЗ): название, объём в месяц и цена. Единый источник для экрана «Кредиты» и сервера;
/// цену за кредит считает модель, а не написана руками.
@immutable
class CreditPackage {
  final String name;
  final int credits;

  /// Цена пакета, сум
  final int price;
  final bool popular;

  const CreditPackage({required this.name, required this.credits, required this.price, this.popular = false});

  /// Цена одного кредита, сум (округлённая)
  int get pricePerCredit => (price / credits).round();
}

/// Каталог пакетов мока.
/// [BACKEND NOTE]: GET /api/v1/subscription/packages
const mockCreditPackages = [
  CreditPackage(name: 'Lite', credits: 60, price: 249000),
  CreditPackage(name: 'Standart', credits: 120, price: 449000, popular: true),
  CreditPackage(name: 'Premium', credits: 250, price: 849000),
];
