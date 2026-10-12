import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/inputs/app_text_field.dart';

class AuthScreen extends StatefulWidget {
  final Function(bool isMaster) onLoginSuccess;
  final VoidCallback? onRegisterTap;

  const AuthScreen({
    super.key,
    required this.onLoginSuccess,
    this.onRegisterTap,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    final login = _loginController.text.trim();
    final pass = _passwordController.text;

    setState(() => _errorMessage = null);

    if (login == 'client' && pass == '12345678') {
      widget.onLoginSuccess(false); // Вход под клиентом
    } else if (login == 'master' && pass == '12345678') {
      widget.onLoginSuccess(true); // Вход под мастером
    } else {
      setState(() {
        _errorMessage = 'Неверный логин или пароль.\nДля клиента: client / 12345678\nДля мастера: master / 12345678';
      });
    }
  }

  void _fillCredentials(String login, String pass) {
    setState(() {
      _loginController.text = login;
      _passwordController.text = pass;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(Icons.spa, size: 45, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      "Go'zallik",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Платформа красоты и ухода',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Вход в систему',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Введите ваш логин и пароль для авторизации',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),

                  // Поле логина
                  const Text('Логин', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _loginController,
                    hintText: 'client или master',
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),

                  // Поле пароля
                  const Text('Пароль', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  AppTextField(
                    controller: _passwordController,
                    hintText: '12345678',
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                  // Ошибка
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  AppGradientButton(
                    text: 'Войти',
                    onPressed: _submitLogin,
                  ),
                  const SizedBox(height: 14),
                  if (widget.onRegisterTap != null)
                    Center(
                      child: TextButton(
                        onPressed: widget.onRegisterTap,
                        child: RichText(
                          text: const TextSpan(
                            text: 'Нет аккаунта? ',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Зарегистрироваться',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Быстрый выбор аккаунта:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _fillCredentials('client', '12345678'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.person, color: AppColors.primary, size: 18),
                          label: const Text('Клиент', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _fillCredentials('master', '12345678'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC5238A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.brush, color: Color(0xFFC5238A), size: 18),
                          label: const Text('Мастер', style: TextStyle(color: Color(0xFFC5238A), fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
