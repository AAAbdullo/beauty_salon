import 'package:flutter/material.dart' hide Text;
import '../../l10n/app_text.dart';
import '../../theme/app_theme.dart';

/// «Ручка» сверху нижней шторки
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Единая нижняя шторка приложения: ручка, заголовок, прокручиваемое содержимое.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  double maxHeightFactor = 0.8,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFactor),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSheetHandle(),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, subtitle == null ? 8 : 2),
                child: Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              Flexible(child: Builder(builder: builder)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Короткое уведомление внизу экрана в едином стиле
void showAppSnack(BuildContext context, String message, {bool success = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primary : AppColors.snackBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Функция зависит от сервера, которого пока нет: честно сообщаем пользователю
void showServerPendingSnack(BuildContext context, String feature) {
  showAppSnack(context, '$feature появится после подключения сервера.');
}
