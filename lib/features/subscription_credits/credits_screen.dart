import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repositories/payments_repository.dart';
import '../../core/data/repository_exception.dart';
import '../../core/models/booking_error.dart';
import '../../core/models/credit_package.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../core/utils/uuid.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';

class CreditsScreen extends StatefulWidget {
  /// «Назад» (например, в профиль). Если не задан, кнопки нет: экран открыт из нижней панели
  final VoidCallback? onBack;

  const CreditsScreen({super.key, this.onBack});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late final _appState = AppScope.read(context).appState;

  // Пакеты приходят из репозитория (каталог на сервере), а не зашиты в экран
  List<CreditPackage>? _packages;
  bool _packagesFailed = false;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
    unawaited(_loadPackages());
  }

  Future<void> _loadPackages() async {
    setState(() => _packagesFailed = false);
    try {
      final packages = await AppScope.read(context).subscription.packages();
      if (mounted) setState(() => _packages = packages);
    } on RepositoryException {
      if (mounted) setState(() => _packagesFailed = true);
    }
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  /// K-08: заморозка 7–30 дней, 1 раз в 3 месяца; срок действия сдвигается
  /// Выполнить операцию с абонементом и показать результат; сбой сети и отказ объясняются пользователю
  Future<void> _runSubscriptionAction(
    Future<Result<void, BookingError>> Function() action, {
    required String Function() successMessage,
  }) async {
    try {
      final result = await action();
      if (!mounted) return;
      switch (result) {
        case Success():
          showAppSnack(context, successMessage(), success: true);
        case Failure(:final error):
          showAppSnack(context, error.message);
      }
    } on RepositoryException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  void _showFreezeDialog() {
    // Ключ идемпотентности привязан к открытому окну: двойной тап выполнит операцию один раз
    final requestKey = Uuid.v4();
    var submitting = false;
    if (_appState.isFrozen) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Разморозить абонемент?'),
          content: Text(
            'Абонемент заморожен до ${Formatters.fullDate(_appState.frozenUntil ?? DateTime.now())}. '
            'Неиспользованные дни заморозки не добавятся к сроку действия.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (submitting) return;
                submitting = true;
                Navigator.pop(ctx);
                _runSubscriptionAction(
                  () => AppScope.read(context).subscription.unfreeze(idempotencyKey: requestKey),
                  successMessage: () => 'Абонемент снова активен',
                );
              },
              child: const Text('Разморозить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final blockReason = _appState.freezeBlockReason;
    if (blockReason != null) {
      showAppSnack(context, blockReason);
      return;
    }

    int days = 14;
    showAppSheet<void>(
      context: context,
      title: 'Заморозить абонемент',
      subtitle:
          'От 7 до 30 дней, не чаще 1 раза в 3 месяца. На время заморозки срок действия кредитов останавливается.',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [7, 14, 21, 30].map((d) {
                  final selected = days == d;
                  return ChoiceChip(
                    label: Text('$d дн.'),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                    onSelected: (_) => setSheet(() => days = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Новый срок действия: ${Formatters.fullDate(_appState.subscriptionExpiresAt.add(Duration(days: days)))}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
              ),
              const SizedBox(height: 16),
              AppGradientButton(
                text: 'Заморозить на $days дн.',
                onPressed: () {
                  if (submitting) return;
                  submitting = true;
                  Navigator.pop(ctx);
                  _runSubscriptionAction(
                    () => AppScope.read(context).subscription.freeze(days: days, idempotencyKey: requestKey),
                    successMessage: () => 'Абонемент заморожен на $days дн.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Способы онлайн-оплаты пакета (как на экране оплаты записи)
  static const _providers = ['Click', 'Payme', 'Uzum', 'Сохранённая карта ···· 4417'];

  void _buyPackage(CreditPackage pkg) {
    final name = pkg.name;
    final credits = pkg.credits;
    // Ключи привязаны к открытому окну покупки: двойной тап не спишет деньги и не начислит кредиты дважды
    final payKey = Uuid.v4();
    final purchaseKey = Uuid.v4();
    var provider = _providers.first;
    PaymentReceipt? receipt; // деньги списаны, пакет ещё не выдан
    var purchased = false;
    final isCurrent = name == _appState.subscriptionPlan;
    final preview = _appState.previewPurchase(credits);
    final carryNote = _appState.clientCredits == 0
        ? 'Остатка нет — будет начислено $credits кр.'
        : preview.burned > 0
        ? 'Из текущих ${_appState.clientCredits} кр. перенесётся ${preview.carried} кр. (не больше 20% прежнего пакета), '
              '${preview.burned} кр. сгорят.'
        : 'Текущие ${_appState.clientCredits} кр. сохранятся.';
    final deps = AppScope.read(context);

    Future<void> payAndActivate(BuildContext sheetContext) async {
      try {
        if (receipt == null) {
          final paid = await deps.payments.pay(amount: pkg.price, provider: provider, idempotencyKey: payKey);
          if (!mounted) return;
          switch (paid) {
            case Success(:final value):
              receipt = value;
            case Failure(:final error):
              showAppSnack(context, error.message);
              return;
          }
        }
        final result = await deps.subscription.purchasePackage(
          planName: name,
          paymentReceiptId: receipt!.id,
          idempotencyKey: purchaseKey,
        );
        if (!mounted) return;
        switch (result) {
          case Success():
            purchased = true;
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            showAppSnack(context, 'Пакет «$name» активирован! На балансе ${_appState.clientCredits} кр.', success: true);
          case Failure(:final error):
            // Пакет не выдан — возвращаем деньги, окно закрывается
            unawaited(deps.payments.refund(receiptId: receipt!.id, idempotencyKey: 'refund-$purchaseKey'));
            receipt = null;
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            showAppSnack(context, '${error.message} Платёж будет возвращён.');
        }
      } on RepositoryException catch (e) {
        // Связь оборвалась: если деньги уже списаны, повторное нажатие не платит второй раз
        if (mounted) showAppSnack(context, e.message);
      }
    }

    showAppSheet<void>(
      context: context,
      title: isCurrent ? 'Продлить «$name»' : 'Перейти на «$name»',
      subtitle: '+$credits кредитов на 30 дней. $carryNote Итого на балансе: ${preview.total} кр.',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Способ оплаты', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final p in _providers)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p),
                  leading: Icon(
                    p == provider ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                  ),
                  // После списания способ уже не сменить: деньги ушли через выбранный
                  onTap: receipt != null ? null : () => setSheetState(() => provider = p),
                ),
              const SizedBox(height: 8),
              AppGradientButton(
                text: 'Оплатить ${Formatters.formatSum(pkg.price)}',
                onPressed: () => payAndActivate(ctx),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Окно закрыли после списания, но без выдачи пакета: деньги возвращаются
      final stuck = receipt;
      if (stuck != null && !purchased) {
        unawaited(deps.payments.refund(receiptId: stuck.id, idempotencyKey: 'refund-$purchaseKey'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(icon: Icon(Icons.arrow_back, color: AppColors.ink), onPressed: widget.onBack),
        title: Text(
          'Кредиты и Абонемент',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка баланса
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: AppGradients.promo,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Текущий тариф', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                Text(
                                  _appState.subscriptionPlan,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_appState.isFrozen)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Заморожен до ${Formatters.dayLabel(_appState.frozenUntil ?? DateTime.now())}',
                              style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Доступно кредитов', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 2),
                            Text(
                              '${_appState.clientCredits} кр.',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        AppPillButton(
                          text: _appState.isFrozen ? 'Разморозить' : 'Заморозить',
                          backgroundColor: AppColors.surface,
                          textColor: AppColors.ink,
                          onPressed: _showFreezeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _appState.planTotalCredits == 0
                            ? 0
                            : _appState.usedPlanCredits / _appState.planTotalCredits,
                        minHeight: 6,
                        backgroundColor: AppColors.isDark ? Colors.white24 : Colors.white70,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Использовано ${_appState.usedPlanCredits} из ${_appState.planTotalCredits} кр. · действует до ${_appState.subscriptionExpiry}',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('Пакеты кредитов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Кредиты действуют во всех салонах-партнерах Go\'zallik',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),

              if (_packages == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: _packagesFailed
                        ? Column(
                            children: [
                              Text('Не удалось загрузить пакеты', style: TextStyle(color: AppColors.muted)),
                              TextButton(onPressed: _loadPackages, child: const Text('Повторить')),
                            ],
                          )
                        : const CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                ..._packages!.map((pkg) {
                final isPopular = pkg.popular;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    border: isPopular ? Border.all(color: AppColors.primary, width: 2) : null,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    pkg.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  if (isPopular) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ХИТ',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${pkg.credits} кредитов / месяц',
                                style: TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                              Text(
                                '${Formatters.formatSum(pkg.pricePerCredit)}/кр.',
                                style: TextStyle(fontSize: 10, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.formatSum(pkg.price),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            AppPillButton(
                              text: pkg.name == _appState.subscriptionPlan ? 'Продлить' : 'Купить',
                              backgroundColor: AppColors.primary,
                              textColor: Colors.white,
                              height: 30,
                              onPressed: () => _buyPackage(pkg),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
