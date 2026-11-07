import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/inputs/app_text_field.dart';

/// Экран онбординга и регистрации клиента (ТЗ M-01, M-02)
/// Шаг 1: Номер телефона (+998 XX XXX XX XX)
/// Шаг 2: Ввод SMS-кода с таймером 00:45
/// Шаг 3: Заполнение анкеты (Имя, Фамилия, Дата рождения, Пол)
class OnboardingRegistrationScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onBackToLogin;

  const OnboardingRegistrationScreen({
    super.key,
    required this.onCompleted,
    required this.onBackToLogin,
  });

  @override
  State<OnboardingRegistrationScreen> createState() => _OnboardingRegistrationScreenState();
}

class _OnboardingRegistrationScreenState extends State<OnboardingRegistrationScreen> {
  int _currentStep = 1; // 1: Телефон, 2: SMS OTP, 3: Анкета

  // Шаг 1: Телефон
  final _phoneController = TextEditingController(text: '90 123 45 67');
  String? _phoneError;

  // Шаг 2: OTP
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  int _timerSeconds = 45;
  Timer? _countdownTimer;
  String? _otpError;

  // Шаг 3: Анкета
  final _firstNameController = TextEditingController(text: 'Азиза');
  final _lastNameController = TextEditingController(text: 'Каримова');
  final _birthDateController = TextEditingController(text: '14.05.1998');
  String _selectedGender = 'Женский';
  String? _profileError;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _timerSeconds = 45);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _submitPhone() {
    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length != UzPhoneInputFormatter.digitsCount) {
      setState(() => _phoneError = 'Введите корректный 9-значный номер');
      return;
    }
    FocusScope.of(context).unfocus();
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _phoneError = null;
      _otpError = null;
      _currentStep = 2;
    });
    _startTimer();
    // Фокус на первое поле SMS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_otpFocusNodes[0].canRequestFocus) {
        _otpFocusNodes[0].requestFocus();
      }
    });
  }

  void _submitOtp() {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 4) {
      setState(() => _otpError = 'Введите 4-значный код из SMS');
      return;
    }
    FocusScope.of(context).unfocus();
    _countdownTimer?.cancel();
    setState(() {
      _otpError = null;
      _currentStep = 3;
    });
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseBirthDate() ?? DateTime(1998, 5, 14),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _birthDateController.text = '$day.$month.$year';
      });
    }
  }

  DateTime? _parseBirthDate() {
    final parts = _birthDateController.text.split('.');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    final date = DateTime(y, m, d);
    return date.isAfter(DateTime.now()) ? null : date;
  }

  void _showSocialUnavailable(String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ink,
          content: Text('Вход через $provider появится после подключения сервера. Используйте номер телефона.'),
        ),
      );
  }

  void _submitProfile() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty) {
      setState(() => _profileError = 'Пожалуйста, введите ваше имя');
      return;
    }

    final fullName = last.isNotEmpty ? '$first $last' : first;
    final phone = '+998 ${_phoneController.text.trim()}';

    // Обновляем синглтон состояния
    AppStateService().updateClientProfile(
      name: fullName,
      phone: phone,
      birthDate: _birthDateController.text,
      gender: _selectedGender,
    );

    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 16),
                  child: _buildCurrentStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.ink),
            onPressed: () {
              if (_currentStep > 1) {
                setState(() => _currentStep--);
              } else {
                widget.onBackToLogin();
              }
            },
          ),
          Text(
            'Шаг $_currentStep из 3',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          TextButton(
            onPressed: widget.onBackToLogin,
            child: const Text('Войти', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 4),
      child: Row(
        children: List.generate(3, (index) {
          final stepNum = index + 1;
          final isActive = stepNum <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.muted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildPhoneStep();
      case 2:
        return _buildOtpStep();
      case 3:
      default:
        return _buildProfileStep();
    }
  }

  // ШАГ 1: Ввод номера
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Регистрация',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите ваш номер телефона для входа в приложение и получения кода подтверждения',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 32),
        Text('Номер телефона', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC5238A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    bottomLeft: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Text('🇺🇿', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text('+998', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryText)),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitPhone(),
                  inputFormatters: const [UzPhoneInputFormatter()],
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  decoration: const InputDecoration(
                    hintText: '90 123 45 67',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_phoneError != null) ...[
          const SizedBox(height: 8),
          Text(_phoneError!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 32),
        AppGradientButton(
          text: 'Получить код',
          onPressed: _submitPhone,
        ),
        const SizedBox(height: 32),
        Center(
          child: Text('Или продолжить через', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(Icons.g_mobiledata, 'Google'),
            const SizedBox(width: 14),
            _buildSocialButton(Icons.apple, 'Apple'),
            const SizedBox(width: 14),
            _buildSocialButton(Icons.send_rounded, 'Telegram'),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSocialUnavailable(label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ink),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ШАГ 2: Ввод SMS OTP
  Widget _buildOtpStep() {
    final timerText = '00:${_timerSeconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Код подтверждения',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Мы отправили 4-значный SMS-код на номер +998 ${_phoneController.text}',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 60,
              height: 64,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _otpControllers[index].text.isNotEmpty ? AppColors.primary : Colors.black12,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      // Вставка/автозаполнение всего кода в одно поле — раскладываем по ячейкам
                      if (val.length > 1) {
                        final digits = val.split('');
                        for (var i = 0; i < 4; i++) {
                          final src = index + i < 4 ? i : -1;
                          if (src >= 0 && src < digits.length) {
                            _otpControllers[index + i].text = digits[src];
                          }
                        }
                        setState(() {});
                        final filled = _otpControllers.every((c) => c.text.isNotEmpty);
                        if (filled) {
                          _submitOtp();
                        } else {
                          final next = (index + digits.length).clamp(0, 3);
                          _otpFocusNodes[next].requestFocus();
                        }
                        return;
                      }
                      setState(() {});
                      if (val.isNotEmpty && index < 3) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (val.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                      if (val.isNotEmpty && _otpControllers.every((c) => c.text.isNotEmpty)) {
                        _submitOtp();
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 12),
          Center(child: Text(_otpError!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
        const SizedBox(height: 32),
        Center(
          child: _timerSeconds > 0
              ? Text(
                  'Отправить код повторно через $timerText',
                  style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                )
              : TextButton(
                  onPressed: _startTimer,
                  child: const Text(
                    'Отправить код повторно',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        AppGradientButton(
          text: 'Подтвердить код',
          onPressed: _submitOtp,
        ),
      ],
    );
  }

  // ШАГ 3: Заполнение анкеты
  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Заполните анкету',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Text(
          'Расскажите немного о себе, чтобы салоны и мастера обращались к вам правильно',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 24),

        // Аватар (загрузка фото появится вместе с бэкендом — пока без кнопки камеры,
        // чтобы не показывать нерабочее действие)
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTint,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.person, size: 50, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),

        // Имя
        Text('Имя', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        AppTextField(
          controller: _firstNameController,
          hintText: 'Ваше имя',
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
        ),
        const SizedBox(height: 14),

        // Фамилия
        Text('Фамилия', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        AppTextField(
          controller: _lastNameController,
          hintText: 'Ваша фамилия (необязательно)',
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
        ),
        const SizedBox(height: 14),

        // Дата рождения
        Text('Дата рождения', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        AppTextField(
          controller: _birthDateController,
          hintText: 'ДД.ММ.ГГГГ',
          readOnly: true,
          onTap: _selectBirthDate,
          prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
          suffixIcon: Icon(Icons.edit_calendar, color: AppColors.muted, size: 20),
        ),
        const SizedBox(height: 18),

        // Пол
        Text('Пол', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildGenderChoice('Женский', Icons.female),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderChoice('Мужской', Icons.male),
            ),
          ],
        ),

        if (_profileError != null) ...[
          const SizedBox(height: 12),
          Text(_profileError!, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],

        const SizedBox(height: 28),
        AppGradientButton(
          text: 'Завершить регистрацию',
          onPressed: _submitProfile,
        ),
      ],
    );
  }

  Widget _buildGenderChoice(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return InkWell(
      onTap: () => setState(() => _selectedGender = gender),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.muted, size: 20),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primaryText : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
