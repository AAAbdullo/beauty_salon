import 'package:image_picker/image_picker.dart';
import '../../core/data/app_scope.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/services/profile_photo_storage.dart';
import '../../core/widgets/avatars/avatar_image.dart';
import '../../core/l10n/app_text.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/inputs/app_text_field.dart';
import '../../core/widgets/sheets/app_sheet.dart';

/// Шторки профиля, общие для экранов «Профиль» и «Настройки»
class ProfileSheets {
  ProfileSheets._();

  /// Редактирование личных данных (M-02: имя, телефон, дата рождения, пол).
  /// Форма — отдельный StatefulWidget: её контроллеры освобождаются при закрытии шторки.
  static void editProfile(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: 'Личные данные',
      maxHeightFactor: 0.9,
      builder: (ctx) => _EditProfileForm(
        onSaved: () {
          Navigator.pop(ctx);
          showAppSnack(context, 'Данные сохранены');
        },
      ),
    );
  }

  /// Смена фото профиля: галерея, камера или удаление текущего фото
  static void changePhoto(BuildContext context) {
    final state = AppScope.read(context).appState;
    showAppSheet<void>(
      context: context,
      title: 'Фото профиля',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(context, ImageSource.camera);
              },
            ),
            if (isCustomAvatar(state.clientAvatar))
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.primaryText),
                title: const Text('Удалить фото'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final state = AppScope.read(context).appState;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (picked == null) return; // пользователь закрыл выбор
      final path = await ProfilePhotoStorage.save(picked.path);
      state.updateClientAvatar(path);
      if (context.mounted) showAppSnack(context, 'Фото профиля обновлено');
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Не удалось получить фото. Проверьте доступ к камере и фото в настройках телефона.');
      }
    }
  }

  static Future<void> _removePhoto(BuildContext context) async {
    final state = AppScope.read(context).appState;
    await ProfilePhotoStorage.clear();
    state.resetClientAvatar();
    if (context.mounted) showAppSnack(context, 'Фото удалено');
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
                  children: [Text(item.$2, style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4))],
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
                title: Text(c.$2, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                subtitle: Text(
                  c.$3,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                trailing: Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
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
      builder: (ctx) => SingleChildScrollView(
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
        content: Text(
          'Чтобы войти снова, понадобится номер телефона и код из SMS.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: AppColors.muted)),
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
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
    );
  }
}

/// Маленькая круглая кнопка с камерой на углу аватара: подсказывает, что фото можно сменить
class PhotoEditBadge extends StatelessWidget {
  const PhotoEditBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: const Icon(Icons.photo_camera, size: 13, color: Colors.white),
    );
  }
}

/// Форма редактирования профиля; владеет своими контроллерами и освобождает их в dispose
class _EditProfileForm extends StatefulWidget {
  final VoidCallback onSaved;

  const _EditProfileForm({required this.onSaved});

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late final _appState = AppScope.read(context).appState;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthController;
  late String _gender;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _appState.clientName);
    final phoneDigits = _appState.clientPhone.replaceAll(RegExp(r'\D'), '');
    _phoneController = TextEditingController(
      text: UzPhoneInputFormatter.format(phoneDigits.startsWith('998') ? phoneDigits.substring(3) : phoneDigits),
    );
    _birthController = TextEditingController(text: _appState.clientBirthDate);
    _gender = _appState.clientGender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final parts = _birthController.text.split('.');
    final initial = parts.length == 3
        ? DateTime(int.tryParse(parts[2]) ?? 1998, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[0]) ?? 1)
        : DateTime(1998);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime(1998) : initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      _birthController.text =
          '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    if (digits.length != UzPhoneInputFormatter.digitsCount) {
      setState(() => _error = 'Введите 9 цифр номера после +998');
      return;
    }
    // [BACKEND NOTE]: PATCH /api/v1/me (смена телефона — с подтверждением по SMS)
    _appState.updateClientProfile(
      name: name,
      phone: '+998 ${UzPhoneInputFormatter.format(digits)}',
      birthDate: _birthController.text,
      gender: _gender,
    );
    widget.onSaved();
  }

  /// Префикс поля фиксированной ширины: иконки и «+998» стоят в одной колонке,
  /// а введённый текст во всех полях начинается с одного и того же места.
  Widget _prefix(Widget child) => SizedBox(width: 56, child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ListenableBuilder(
              listenable: _appState,
              builder: (context, _) => GestureDetector(
                onTap: () => ProfileSheets.changePhoto(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: ClipOval(
                        child: Image(
                          image: avatarProvider(_appState.clientAvatar),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.primaryTint,
                            child: const Icon(Icons.person, size: 52, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(right: -2, bottom: -2, child: PhotoEditBadge()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => ProfileSheets.changePhoto(context),
              child: const Text('Изменить фото'),
            ),
          ),
          const SizedBox(height: 6),
          const _FieldLabel('Имя и фамилия'),
          AppTextField(
            controller: _nameController,
            hintText: 'Ваше имя',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            prefixIcon: _prefix(const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22)),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Телефон'),
          AppTextField(
            controller: _phoneController,
            hintText: '90 123 45 67',
            keyboardType: TextInputType.phone,
            inputFormatters: const [UzPhoneInputFormatter()],
            prefixIcon: _prefix(
              Text(
                '+998',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryText),
              ),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Дата рождения'),
          AppTextField(
            controller: _birthController,
            readOnly: true,
            prefixIcon: _prefix(const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 22)),
            onTap: _pickBirthDate,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Пол'),
          Row(
            children: ['Женский', 'Мужской'].map((g) {
              final selected = _gender == g;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _gender = g),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          AppGradientButton(text: 'Сохранить', onPressed: _save),
        ],
      ),
    );
  }
}
