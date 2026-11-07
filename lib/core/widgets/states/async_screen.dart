import 'package:flutter/material.dart';
import '../../data/repository_exception.dart';
import '../../theme/app_theme.dart';
import '../buttons/app_gradient_button.dart';

/// Текст ошибки для пользователя: сообщение репозитория или общая фраза
String errorMessageOf(Object? error) =>
    error is RepositoryException ? error.message : 'Не удалось загрузить данные. Попробуйте ещё раз.';

/// Полноэкранная загрузка
class LoadingScreen extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const LoadingScreen({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink), onPressed: onBack),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
  }
}

/// Полноэкранная ошибка загрузки с кнопкой «Повторить»
class ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const ErrorScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink), onPressed: onBack),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        padding: const EdgeInsets.all(AppSizes.screenPadding * 1.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              AppGradientButton(text: 'Повторить', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран, который грузит данные: показывает загрузку, ошибку с повтором или готовый экран.
///
/// [load] вызывается при открытии и при каждом нажатии «Повторить»; смена [reloadKey] перезагружает данные.
class AsyncScreen<T> extends StatefulWidget {
  final String title;
  final VoidCallback onBack;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final Object? reloadKey;

  const AsyncScreen({
    super.key,
    required this.title,
    required this.onBack,
    required this.load,
    required this.builder,
    this.reloadKey,
  });

  @override
  State<AsyncScreen<T>> createState() => _AsyncScreenState<T>();
}

class _AsyncScreenState<T> extends State<AsyncScreen<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant AsyncScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) _reload();
  }

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingScreen(title: widget.title, onBack: widget.onBack);
        }
        if (snapshot.hasError) {
          return ErrorScreen(
            title: widget.title,
            message: errorMessageOf(snapshot.error),
            onRetry: _reload,
            onBack: widget.onBack,
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}

/// Блок внутри экрана (не весь экран): загрузка, ошибка с повтором или данные
class AsyncSection extends StatelessWidget {
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final Widget child;
  final double minHeight;

  const AsyncSection({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.child,
    this.minHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: minHeight,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (error != null) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessageOf(error),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Повторить', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    return child;
  }
}
