import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/inputs/app_text_field.dart';
import '../../core/widgets/sheets/app_sheet.dart';

/// Шторки профиля, общие для экранов «Профиль» и «Настройки»
class ProfileSheets {
  ProfileSheets._();

  /// Редактирование личных данных (M-02: имя, телефон, дата рождения, пол)
  static void editProfile(BuildContext context) {
    final appState = AppStateService();
    final nameController = TextEditingController(text: appState.clientName);
    final phoneDigits = appState.clientPhone.replaceAll(RegExp(r'\D'), '');
    final phoneController = TextEditingController(
      text: UzPhoneInputFormatter.format(phoneDigits.startsWith('998') ? phoneDigits.substring(3) : phoneDigits),
    );
    String birthDate = appState.clientBirthDate;
    final birthController = TextEditingController(text: birthDate);
    String gender = appState.clientGender;
    String? error;

    showAppSheet<void>(
      context: context,
      title: 'Личные данные',
      maxHeightFactor: 0.9,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Имя и фамилия'),
              AppTextField(
                controller: nameController,
                hintText: 'Ваше имя',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Телефон'),
              AppTextField(
                controller: phoneController,
                hintText: '90 123 45 67',
                keyboardType: TextInputType.phone,
                inputFormatters: const [UzPhoneInputFormatter()],
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    '+998',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Дата рождения'),
              AppTextField(
                controller: birthController,
                readOnly: true,
                prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                onTap: () async {
                  final parts = birthDate.split('.');
                  final initial = parts.length == 3
                      ? DateTime(
                          int.tryParse(parts[2]) ?? 1998,
                          int.tryParse(parts[1]) ?? 1,
                          int.tryParse(parts[0]) ?? 1,
                        )
                      : DateTime(1998);
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: initial.isAfter(DateTime.now()) ? DateTime(1998) : initial,
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheet(() {
                      birthDate =
                          '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
                      birthController.text = birthDate;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Пол'),
              Row(
                children: ['Женский', 'Мужской'].map((g) {
                  final selected = gender == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setSheet(() => gender = g),
                    ),
                  );
                }).toList(),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
              AppGradientButton(
                text: 'Сохранить',
                onPressed: () {
                  final name = nameController.text.trim();
                  final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
                  if (name.isEmpty) {
                    setSheet(() => error = 'Введите имя');
                    return;
                  }
                  if (digits.length != UzPhoneInputFormatter.digitsCount) {
                    setSheet(() => error = 'Введите 9 цифр номера после +998');
                    return;
                  }
                  // [BACKEND NOTE]: PATCH /api/v1/me (смена телефона — с подтверждением по SMS)
                  appState.updateClientProfile(
                    name: name,
                    phone: '+998 ${UzPhoneInputFormatter.format(digits)}',
                    birthDate: birthDate,
                    gender: gender,
                  );
                  Navigator.pop(ctx);
                  showAppSnack(context, 'Данные сохранены');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Частые вопросы — по правилам сервиса из ТЗ
  static void faq(BuildContext context) {
    const items = [
      (
        'Как работают кредиты?',
        'Вы покупаете пакет кредитов (Lite, Standart или Premium) и тратите их в любом салоне-партнёре. '
            'Кредиты действуют 30 дней, при продлении до 20% неиспользованных переносятся.',
      ),
      (
        'Можно ли отменить или перенести запись?',
        'Да, бесплатно — не позднее чем за 2 часа до визита. Кредиты или оплата вернутся полностью. '
            'Позже отмена недоступна, а при неявке кредиты не возвращаются.',
      ),
      (
        'Зачем нужен QR-код?',
        'QR подтверждает, что визит состоялся. Покажите его мастеру в салоне: код обновляется каждые 60 секунд '
            'и действует за 30 минут до начала и в течение часа после.',
      ),
      (
        'Сколько раз можно ходить в один салон?',
        'За кредиты — до 4 записей в месяц в один салон. Сверх лимита можно оплатить онлайн или в салоне.',
      ),
      (
        'Как заморозить абонемент?',
        'В разделе «Кредиты» — на 7–30 дней, не чаще раза в 3 месяца. На это время срок действия кредитов останавливается.',
      ),
      (
        'Когда можно оставить отзыв?',
        'После подтверждённого визита, в течение 7 дней — в разделе «Мои записи» → «Прошедшие».',
      ),
    ];

    showAppSheet<void>(
      context: context,
      title: 'Частые вопросы',
      maxHeightFactor: 0.85,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: items
            .map(
              (item) => Theme(
                data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(item.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  iconColor: AppColors.primary,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [Text(item.$2, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4))],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Контакты поддержки (копирование в буфер — без внешних пакетов)
  static void support(BuildContext context) {
    const contacts = [
      (Icons.phone_outlined, 'Телефон', '+998 71 200 00 00'),
      (Icons.send_outlined, 'Telegram', '@gozallik_support'),
      (Icons.mail_outline, 'Почта', 'support@gozallik.uz'),
    ];
    showAppSheet<void>(
      context: context,
      title: 'Связаться с нами',
      subtitle: 'Ежедневно с 9:00 до 21:00. Нажмите на контакт, чтобы скопировать.',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: contacts
            .map(
              (c) => ListTile(
                leading: Icon(c.$1, color: AppColors.primary),
                title: Text(c.$2, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                subtitle: Text(
                  c.$3,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                trailing: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: c.$3));
                  Navigator.pop(ctx);
                  showAppSnack(context, 'Скопировано: ${c.$3}');
                },
              ),
            )
            .toList(),
      ),
    );
  }

  /// Правовая информация
  static void legal(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: 'Правовая информация',
      builder: (ctx) => const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Text(
          'Go\'zallik — платформа записи в салоны красоты Ташкента.\n\n'
          '• Пользовательское соглашение и политика конфиденциальности публикуются на gozallik.uz.\n'
          '• Персональные данные хранятся на серверах в Республике Узбекистан в соответствии с законом «О персональных данных».\n'
          '• Платежи обрабатывают Click, Payme и Uzum — данные карт приложение не хранит.\n'
          '• Услуги оказывают салоны-партнёры; претензии по качеству рассматриваются через поддержку.',
          style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5),
        ),
      ),
    );
  }

  /// Подтверждение выхода из аккаунта
  static Future<void> confirmLogout(BuildContext context, VoidCallback onLogout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выйти из аккаунта?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text(
          'Чтобы войти снова, понадобится номер телефона и код из SMS.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) onLogout();
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
    );
  }
}
