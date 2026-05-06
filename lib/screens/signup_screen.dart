import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/elbites_logo.dart';
import '../widgets/app_text_field.dart';
import '../widgets/dietary_tag_chip.dart';
import '../models/dietary_tag.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  // Page 1 controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _displayCtrl = TextEditingController();
  final _page1Key = GlobalKey<FormState>();

  // Page 2 controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _page2Key = GlobalKey<FormState>();
  bool _obscure = true;

  // Page 3 — dietary tags
  final Set<String> _selectedTags = {};

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _displayCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    FocusScope.of(context).unfocus();

    if (_currentPage == 0 && !_page1Key.currentState!.validate()) return;
    if (_currentPage == 1 && !_page2Key.currentState!.validate()) return;

    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    final success = await context.read<UserAuthProvider>().signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      displayName: _displayCtrl.text.trim(),
      dietaryTags: _selectedTags.toList(),
    );

    if (!success && mounted) {
      final err = context.read<UserAuthProvider>().error;
      if (err != null) _showError(err);
    } else if (success && mounted) {
      // Pop all the way back to home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFcf6679),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'At least 6 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Add a lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Add a number';
    if (!value.contains(RegExp(r'[!@#\$&*~%^()_\-+=\[\]{}|;:,.<>?]'))) {
      return 'Add a special character';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserAuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.white,
                      ),
                      onPressed: _goBack,
                    ),
                    const Spacer(),
                    // Step indicator
                    Row(
                      children: List.generate(_totalPages, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? AppColors.yellow : AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // ── Pages ──
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _Page1(
                      formKey: _page1Key,
                      firstNameCtrl: _firstNameCtrl,
                      lastNameCtrl: _lastNameCtrl,
                      displayCtrl: _displayCtrl,
                    ),
                    _Page2(
                      formKey: _page2Key,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      validatePassword: _validatePassword,
                    ),
                    _Page3(
                      selectedTags: _selectedTags,
                      onToggle: (id) {
                        setState(() {
                          if (_selectedTags.contains(id)) {
                            _selectedTags.remove(id);
                          } else {
                            _selectedTags.add(id);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              // ── Bottom CTA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _goNext,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.black,
                                ),
                              )
                            : Text(
                                _currentPage == _totalPages - 1
                                    ? 'Join ELBites 🌿'
                                    : 'Continue',
                              ),
                      ),
                    ),
                    if (_currentPage == _totalPages - 1) ...[
                      const SizedBox(height: 10),
                      Text(
                        _selectedTags.isEmpty
                            ? 'You can skip this step and add tags later.'
                            : '${_selectedTags.length} tag${_selectedTags.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 1: Name & Display Name ──
class _Page1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController displayCtrl;

  const _Page1({
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.displayCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElbitesLogo(size: 44, showText: false),
            const SizedBox(height: 28),
            const Text(
              "Let's get to\nknow you ✨",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us who you are in the ELBites community.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: firstNameCtrl,
                    label: 'First Name',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: lastNameCtrl,
                    label: 'Last Name',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: displayCtrl,
              label: 'Display Name',
              hint: 'How others will see you',
              prefixIcon: Icons.alternate_email_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Display name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: const [
                  Text('💡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your display name is what neighbors see when you post.',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 2: Email & Password ──
class _Page2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? Function(String?) validatePassword;

  const _Page2({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.validatePassword,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElbitesLogo(size: 44, showText: false),
            const SizedBox(height: 28),
            const Text(
              'Set up your\naccount 🔐',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your credentials keep your account safe.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            AppTextField(
              controller: emailCtrl,
              label: 'Email address',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v))
                  return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: passCtrl,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.mutedText,
                ),
                onPressed: onToggleObscure,
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            // Password strength hints
            _PasswordHints(passCtrl: passCtrl),
          ],
        ),
      ),
    );
  }
}

class _PasswordHints extends StatefulWidget {
  final TextEditingController passCtrl;
  const _PasswordHints({required this.passCtrl});

  @override
  State<_PasswordHints> createState() => _PasswordHintsState();
}

class _PasswordHintsState extends State<_PasswordHints> {
  @override
  void initState() {
    super.initState();
    widget.passCtrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final val = widget.passCtrl.text;
    final hints = [
      ('6+ characters', val.length >= 6),
      ('Uppercase letter', val.contains(RegExp(r'[A-Z]'))),
      ('Lowercase letter', val.contains(RegExp(r'[a-z]'))),
      ('Number', val.contains(RegExp(r'[0-9]'))),
      ('Special character', val.contains(RegExp(r'[!@#\$&*~%^]'))),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hints.map((h) {
        final met = h.$2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: met ? AppColors.green.withOpacity(0.15) : AppColors.cardBg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: met ? AppColors.green : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                met
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: met ? AppColors.green : AppColors.mutedText,
              ),
              const SizedBox(width: 5),
              Text(
                h.$1,
                style: TextStyle(
                  color: met ? AppColors.green : AppColors.mutedText,
                  fontSize: 12,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Page 3: Dietary Tags ──
class _Page3 extends StatelessWidget {
  final Set<String> selectedTags;
  final void Function(String) onToggle;

  const _Page3({required this.selectedTags, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ElbitesLogo(size: 44, showText: false),
              const SizedBox(height: 28),
              const Text(
                'What are your\nfood interests? 🥗',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick your dietary preferences. We\'ll personalise your feed.',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: AppTags.dietary.map((tag) {
                return DietaryTagChip(
                  tag: tag,
                  isSelected: selectedTags.contains(tag.id),
                  onTap: () => onToggle(tag.id),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
