import '../../core/data/app_scope.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/theme/app_appearance.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import 'profile_sheets.dart';

/// Настройки аккаунта и приложения (общие для клиента и мастера)
class SettingsScreen extends StatefulWidget {
  final bool isMaster;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenCredits;

  const SettingsScreen({
    super.key,
    this.isMaster = false,
    required this.onBack,
    required this.onLogout,
    this.onOpenNotifications,
    this.onOpenCredits,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _appState = AppScope.read(context).appState;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _pickLanguage() {
    // ТЗ: uz-Latn, uz-Cyrl, ru
    const languages = [
      ("O'zbekcha (lotin)", AppLanguage.uz),
      ('Ўзбекча (кирилл)', AppLanguage.uzCyrl),
      ('Русский', AppLanguage.ru),
    ];
    showAppSheet<void>(
      context: context,
      title: 'Язык приложения',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: languages
            .map(
              (l) => ListTile(
                title: Text(l.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: l.$2 == AppLocale.instance.language ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  AppLocale.instance.setLanguage(l.$2);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String get _languageLabel => switch (AppLocale.instance.language) {
    AppLanguage.uz => "O'zbekcha",
    AppLanguage.uzCyrl => 'Ўзбекча',
    AppLanguage.ru => 'Русский',
  };

  void _pickTheme() {
    const options = [(ThemeMode.system, 'Как в системе'), (ThemeMode.light, 'Светлая'), (ThemeMode.dark, 'Тёмная')];
    showAppSheet<void>(
      context: context,
      title: 'Тема оформления',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: options
            .map(
              (o) => ListTile(
                title: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: AppAppearance.instance.mode == o.$1 ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  AppAppearance.instance.setMode(o.$1);
                  setState(() {});
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  String get _themeLabel => switch (AppAppearance.instance.mode) {
    ThemeMode.system => 'Как в системе',
    ThemeMode.light => 'Светлая',
    ThemeMode.dark => 'Тёмная',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: Text(
          'Настройки',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserSummary(),
                const SizedBox(height: 24),
                if (!widget.isMaster) ...[
                  _buildSectionTitle('Аккаунт'),
                  const SizedBox(height: 8),
                  _buildAccountSection(),
                  const SizedBox(height: 24),
                ],
                _buildSectionTitle('Настройки приложения'),
                const SizedBox(height: 8),
                _buildAppSettingsSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('Поддержка'),
                const SizedBox(height: 8),
                _buildSupportSection(),
                const SizedBox(height: 24),
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
    );
  }

  Widget _buildUserSummary() {
    final name = widget.isMaster ? _appState.masterName : _appState.clientName;
    final subtitle = widget.isMaster ? 'Мастер · ${_appState.masterSalon}' : _appState.clientPhone;
    final avatar = widget.isMaster ? _appState.masterAvatar : _appState.clientAvatar;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: widget.isMaster ? null : () => ProfileSheets.editProfile(context),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person, color: AppColors.primary, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                if (!widget.isMaster) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Тариф ${_appState.subscriptionPlan}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.isMaster) Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(Icons.person_outline, 'Личные данные', () => ProfileSheets.editProfile(context)),
          if (widget.onOpenNotifications != null) ...[
            _buildDivider(),
            _buildListTile(Icons.notifications_none_outlined, 'Уведомления', widget.onOpenNotifications!),
          ],
          if (widget.onOpenCredits != null) ...[
            _buildDivider(),
            _buildListTile(Icons.credit_card_outlined, 'Абонемент и оплата', widget.onOpenCredits!),
          ],
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(Icons.language, 'Язык приложения', _pickLanguage, value: _languageLabel),
          _buildDivider(),
          _buildListTile(Icons.dark_mode_outlined, 'Тема оформления', _pickTheme, value: _themeLabel),
          _buildDivider(),
          _buildSwitchTile(
            Icons.notifications_active_outlined,
            'Акции и специальные предложения',
            _appState.promoNotificationsEnabled,
            (v) => _appState.updateSettings(promo: v),
          ),
          _buildDivider(),
          _buildSwitchTile(
            Icons.mail_outline,
            'Полезные советы и новости',
            _appState.newsNotificationsEnabled,
            (v) => _appState.updateSettings(news: v),
          ),
          _buildDivider(),
          _buildSwitchTile(
            Icons.navigation_outlined,
            'Показывать салоны рядом со мной',
            _appState.useLocationEnabled,
            (v) => _appState.updateSettings(location: v),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(Icons.help_outline, 'Часто задаваемые вопросы', () => ProfileSheets.faq(context)),
          _buildDivider(),
          _buildListTile(Icons.chat_bubble_outline, 'Связаться с нами', () => ProfileSheets.support(context)),
          _buildDivider(),
          _buildListTile(Icons.verified_user_outlined, 'Правовая информация', () => ProfileSheets.legal(context)),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {String? value}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.ink, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (value != null) ...[
              Text(value, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool>? onChanged, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: onChanged == null ? AppColors.muted : AppColors.ink, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onChanged == null ? AppColors.muted : AppColors.ink,
                  ),
                ),
                if (hint != null) Text(hint, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 0.5, indent: 52, endIndent: 16, color: AppColors.line);
  }

  Widget _buildLogoutButton() {
    return Material(
      color: AppColors.soft(const Color(0xFFFFF0F5)),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => ProfileSheets.confirmLogout(context, widget.onLogout),
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Выйти из аккаунта',
                style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
