import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../../core/data/app_scope.dart';
import '../../../core/data/repository_exception.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/app_text.dart';
import '../../../core/models/master_review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/buttons/app_gradient_button.dart';
import '../../../core/widgets/sheets/app_sheet.dart';
import '../../reviews/review_widgets.dart';

/// Кабинет мастера → «Отзывы»: сводка и список отзывов о себе (свежие сверху, страницы по 20).
/// На каждый отзыв мастер может один раз публично ответить; ответ можно править, удалить нельзя.
class MasterReviewsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MasterReviewsScreen({super.key, required this.onBack});

  @override
  State<MasterReviewsScreen> createState() => _MasterReviewsScreenState();
}

class _MasterReviewsScreenState extends State<MasterReviewsScreen> {
  ReviewSummary? _summary;
  final List<MasterReview> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _loadId = 0; // ответ на устаревший запрос игнорируется

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deps = AppScope.read(context);
      final summary = await deps.reviews.masterSummary(deps.appState.masterId);
      final page = await deps.reviews.myReviewsAsMaster();
      if (!mounted || id != _loadId) return;
      setState(() {
        _summary = summary;
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AppScope.read(context).reviews.myReviewsAsMaster(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showAppSnack(context, e.message);
    }
  }

  Future<void> _reply(MasterReview review) async {
    final updated = await showModalBottomSheet<MasterReview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(review: review),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final index = _items.indexWhere((r) => r.id == updated.id);
      if (index != -1) _items[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.ink),
          tooltip: tr('Назад'),
          onPressed: widget.onBack,
        ),
        title: Text('Отзывы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null || summary == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.screenPadding * 1.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? 'Не удалось загрузить данные. Попробуйте ещё раз.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      AppGradientButton(text: 'Повторить', onPressed: _load),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
                children: [
                  ReviewSummaryCard(summary: summary),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Отзывов пока нет', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ),
                    ),
                  for (final r in _items)
                    ReviewCard(
                      review: r,
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _reply(r),
                          icon: Icon(r.reply == null ? Icons.reply : Icons.edit_outlined, size: 16),
                          label: Text(r.reply == null ? 'Ответить' : 'Изменить ответ'),
                        ),
                      ),
                    ),
                  if (_nextCursor != null)
                    Center(
                      child: _loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            )
                          : TextButton(onPressed: _loadMore, child: const Text('Показать ещё')),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Лист ответа на отзыв: до 500 символов, без контактов (проверяет сервер)
class _ReplySheet extends StatefulWidget {
  final MasterReview review;

  const _ReplySheet({required this.review});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.review.reply?.text ?? '');
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await AppScope.read(context).reviews.reply(
        reviewId: widget.review.id,
        text: _controller.text,
      );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          Navigator.pop(context, value);
        case Failure(:final error):
          setState(() {
            _sending = false;
            _error = error.message;
          });
      }
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.review.reply == null ? 'Ответ на отзыв' : 'Изменить ответ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Ответ увидят все клиенты под отзывом. Удалить его нельзя, но можно изменить.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: ReviewRules.maxReplyLength,
              decoration: InputDecoration(
                hintText: tr('Ваш ответ клиенту'),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.line),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
            const SizedBox(height: 12),
            AppGradientButton(text: 'Отправить', onPressed: _send),
          ],
        ),
      ),
    );
  }
}
