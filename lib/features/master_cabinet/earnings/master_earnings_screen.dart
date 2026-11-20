import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../../core/l10n/app_text.dart';
import '../../../core/data/app_scope.dart';
import '../../../core/data/repositories/master_cabinet_repository.dart';
import '../../../core/data/repository_exception.dart';
import '../../../core/utils/clock.dart';
import '../../../core/services/master_cabinet_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/badges/app_status_badge.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/sheets/app_sheet.dart';
import '../../../core/widgets/states/async_screen.dart';

/// Доход мастера (ТЗ S-05): начисления за месяц, визиты, комиссия салона, выплаты
class MasterEarningsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MasterEarningsScreen({super.key, required this.onBack});

  @override
  State<MasterEarningsScreen> createState() => _MasterEarningsScreenState();
}

class _MasterEarningsScreenState extends State<MasterEarningsScreen> {
  // Данные месяца приходят асинхронно: пока грузятся — индикатор, при сбое — «Повторить»
  MasterEarningsData? _data;
  Object? _error;
  bool _isLoading = true;
  late final _appState = AppScope.read(context).appState;

  // Вкладка остаётся живой: доход пересчитывается, когда меняются записи
  @override
  void initState() {
    super.initState();
    _appState.bookingChanges.addListener(_onStateChanged);
    unawaited(_load());
  }

  // Номер последнего запроса: ответ на более старый запрос (другой месяц или прежнее состояние) игнорируется
  int _loadId = 0;

  Future<void> _load({bool silent = false}) async {
    final id = ++_loadId;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final offset = _monthOffset;
    try {
      final data = await AppScope.read(context).masterCabinet.earnings(offset);
      // Пока шёл запрос, пользователь мог переключить месяц — устаревший ответ не показываем
      if (mounted && id == _loadId && offset == _monthOffset) {
        setState(() {
          _data = data;
          _error = null;
          _isLoading = false;
        });
      }
    } on RepositoryException catch (e) {
      if (mounted && id == _loadId && offset == _monthOffset && !silent) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  // Доход пересчитывается, когда меняются записи
  void _onStateChanged() {
    if (mounted) unawaited(_load(silent: true));
  }

  @override
  void dispose() {
    _appState.bookingChanges.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 0 — текущий месяц, 1 — предыдущий
  int _monthOffset = 0;

  String _monthName(int offset) {
    final now = AppClock.now();
    final month = DateTime(now.year, now.month - offset);
    const names = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return names[month.month - 1];
  }

  List<MasterVisitIncome> get _visits => _data?.visits ?? const [];
  int get _revenue => _data?.revenue ?? 0;
  double get _commission => _appState.salonCommissionPercent;
  int get _payout => (_revenue * (1 - _commission / 100)).round();

  String _visitSubtitle(MasterVisitIncome v) =>
      '${Formatters.dayLabel(v.date)}, ${Formatters.time(v.date)} · ${v.clientName}';

  void _showAllVisits() {
    showAppSheet<void>(
      context: context,
      title: 'Визиты · ${_monthName(_monthOffset)}',
      subtitle: '${_visits.length} визитов на ${Formatters.formatSum(_revenue)}',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: _visits
            .map(
              (v) => ListTile(
                title: Text(v.serviceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: Text('${_visitSubtitle(v)} · ${v.paymentMethod}'),
                trailing: Text(
                  '+${Formatters.formatSum(v.sum)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showStatistics() {
    final byService = <String, (int, int)>{};
    for (final v in _visits) {
      final current = byService[v.serviceName] ?? (0, 0);
      byService[v.serviceName] = (current.$1 + 1, current.$2 + v.sum);
    }
    final entries = byService.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    showAppSheet<void>(
      context: context,
      title: 'Статистика · ${_monthName(_monthOffset)}',
      subtitle: 'Доход по услугам',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: entries.map((e) {
          final share = _revenue == 0 ? 0.0 : e.value.$2 / _revenue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      '${e.value.$1} виз. · ${Formatters.formatSum(e.value.$2)}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: AppColors.primaryTint,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showPayouts() {
    showAppSheet<void>(
      context: context,
      title: 'История выплат',
      subtitle: 'Выплата за месяц — 1-го числа следующего месяца, за вычетом комиссии салона',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: (_data?.payouts ?? const <MasterPayout>[])
            .map(
              (p) => ListTile(
                leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
                title: Text(
                  Formatters.formatSum(p.amount),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${Formatters.fullDate(p.date)} · ${p.method}'),
                trailing: const AppStatusBadge(text: 'Выплачено'),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.ink), onPressed: widget.onBack),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Мастер · ${_appState.masterSalon}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text('Мой доход', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthToggle(),
              const SizedBox(height: 16),
              AsyncSection(
                isLoading: _isLoading,
                error: _error,
                onRetry: _load,
                minHeight: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIncomeSummaryCard(),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildRecentVisitsHeader(),
                    const SizedBox(height: 12),
                    _buildRecentVisitsList(),
                    const SizedBox(height: 20),
                    _buildBottomActionCards(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthToggle() {
    Widget chip(int offset) {
      final selected = _monthOffset == offset;
      return Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (_monthOffset == offset) return;
            setState(() => _monthOffset = offset);
            unawaited(_load());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              _monthName(offset),
              style: TextStyle(
                color: selected ? Colors.white : AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [chip(0), const SizedBox(width: 8), chip(1)]);
  }

  Widget _buildIncomeSummaryCard() {
    final previous = _data?.previousRevenue ?? 0;
    final change = previous == 0 ? null : ((_revenue - previous) / previous * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _monthOffset == 0 ? 'Начислено за месяц' : 'Начислено за ${_monthName(_monthOffset).toLowerCase()}',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: change >= 0 ? AppColors.successBg : AppColors.soft(const Color(0xFFFFECEF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${change >= 0 ? '+' : ''}$change%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: change >= 0 ? AppColors.successText : AppColors.primary,
                        ),
                      ),
                      Icon(
                        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: change >= 0 ? AppColors.successText : AppColors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.formatSum(_revenue),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Расчёт в конце месяца: процент или фиксированная ставка, как задал салон.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final count = _visits.length;
    final avg = count == 0 ? 0 : (_revenue / count).round();
    final metrics = [
      ('Выполнено\nвизитов', '$count', Icons.calendar_today_outlined),
      ('Средний\nчек', Formatters.formatSum(avg), Icons.payments_outlined),
      ('Комиссия\nсалона', '${_commission.toStringAsFixed(0)}%', Icons.percent),
      ('К выплате\n(примерно)', Formatters.formatSum(_payout), Icons.account_balance_wallet_outlined),
    ];

    return Row(
      children: metrics.map((m) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(m.$3, size: 18, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(m.$1, maxLines: 2, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(m.$2, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentVisitsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Text(
            'Последние визиты',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (_visits.length > 5)
          GestureDetector(
            onTap: _showAllVisits,
            child: Row(
              children: [
                Text(
                  'Все визиты',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                ),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryText),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentVisitsList() {
    if (_visits.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Визитов в этом месяце нет', style: TextStyle(color: AppColors.muted)),
      );
    }
    return Column(
      children: _visits.take(5).map((v) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.spa_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.serviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(_visitSubtitle(v), style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${Formatters.formatSum(v.sum)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(v.paymentMethod, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActionCards() {
    Widget card(IconData icon, String title, String subtitle, VoidCallback onTap) {
      return Expanded(
        child: AppCard(
          padding: const EdgeInsets.all(12),
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(subtitle, style: TextStyle(fontSize: 9, color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(Icons.pie_chart_outline, 'Статистика', 'Доход по услугам', _showStatistics),
        const SizedBox(width: 10),
        card(Icons.history, 'История выплат', 'Переводы и комиссии', _showPayouts),
      ],
    );
  }
}
