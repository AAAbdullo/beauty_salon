import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cards/app_card.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = false;
  bool _promoNotifs = true;
  bool _newsNotifs = true;
  bool _useLocation = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Text('Настройки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserSummary(),
              const SizedBox(height: 24),
              _buildSectionTitle('Аккаунт'),
              const SizedBox(height: 8),
              _buildAccountSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('Настройки приложения'),
              const SizedBox(height: 8),
              _buildAppSettingsSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('Поддержка'),
              const SizedBox(height: 8),
              _buildSupportSection(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
    );
  }

  Widget _buildUserSummary() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryTint,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 40),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Нигина Абдуллаева', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('+998 90 123 45 67', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                SizedBox(height: 4),
                Text('Постоянный клиент', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(Icons.person_outline, 'Личные данные'),
          _buildDivider(),
          _buildListTile(Icons.lock_outline, 'Безопасность'),
          _buildDivider(),
          _buildListTile(Icons.notifications_none_outlined, 'Уведомления'),
          _buildDivider(),
          _buildListTile(Icons.credit_card_outlined, 'Способы оплаты'),
          _buildDivider(),
          _buildListTile(Icons.location_on_outlined, 'Мои адреса'),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.language, color: AppColors.ink, size: 22),
                const SizedBox(width: 14),
                const Expanded(child: Text('Язык приложения', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                const Text('Русский', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ],
            ),
          ),
          _buildDivider(),
          _buildSwitchTile(Icons.dark_mode_outlined, 'Тёмная тема', _darkTheme, (v) => setState(() => _darkTheme = v)),
          _buildDivider(),
          _buildSwitchTile(Icons.notifications_active_outlined, 'Акции и специальные предложения', _promoNotifs, (v) => setState(() => _promoNotifs = v)),
          _buildDivider(),
          _buildSwitchTile(Icons.mail_outline, 'Полезные советы и новости', _newsNotifs, (v) => setState(() => _newsNotifs = v)),
          _buildDivider(),
          _buildSwitchTile(Icons.navigation_outlined, 'Использовать моё местоположение', _useLocation, (v) => setState(() => _useLocation = v)),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildListTile(Icons.help_outline, 'Часто задаваемые вопросы'),
          _buildDivider(),
          _buildListTile(Icons.chat_bubble_outline, 'Связаться с нами'),
          _buildDivider(),
          _buildListTile(Icons.verified_user_outlined, 'Правовая информация'),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, indent: 52, endIndent: 16, color: Color(0xFFF3DCE8));
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: widget.onLogout,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Выйти из аккаунта',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
