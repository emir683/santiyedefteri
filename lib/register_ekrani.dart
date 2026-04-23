import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_servisi.dart';
import 'web_install_helper.dart';

class RegisterEkrani extends StatefulWidget {
  const RegisterEkrani({super.key, required this.onLoginTap});

  final VoidCallback onLoginTap;

  @override
  State<RegisterEkrani> createState() => _RegisterEkraniState();
}

class _RegisterEkraniState extends State<RegisterEkrani> {
  final _adSoyadController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthServisi _authServisi = AuthServisi();

  String _error = '';
  bool _loading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  @override
  void dispose() {
    _adSoyadController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_adSoyadController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _error = "L\u00fctfen t\u00fcm alanlar\u0131 doldurun.");
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() => _error = "\u015eifreler birbiriyle uyu\u015fmuyor.");
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _authServisi.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _adSoyadController.text.trim(),
        _usernameController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? "Bir hata olu\u015ftu.";
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _AuthCardSurface(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _AuthIconBadge(
                            icon: Icons.person_add_alt_1_rounded,
                            color: Color(0xFF24B7A4),
                            size: 60,
                            iconSize: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Yeni Hesap Olu\u015ftur",
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Ekibini ve \u015fantiye takibini y\u00f6netmek i\u00e7in yeni hesab\u0131n\u0131 olu\u015ftur.",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF526772),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (WebInstallHelper.shouldShowInstallCard) ...[
                        const SizedBox(height: 18),
                        const _RegisterWebInstallCard(),
                      ],
                      const SizedBox(height: 26),
                      _GlassAuthInput(
                        controller: _adSoyadController,
                        label: "Ad Soyad",
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 14),
                      _GlassAuthInput(
                        controller: _usernameController,
                        label: "Kullan\u0131c\u0131 Ad\u0131",
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 14),
                      _GlassAuthInput(
                        controller: _emailController,
                        label: "E-posta",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _GlassAuthInput(
                        controller: _passwordController,
                        label: "\u015eifre",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _isPasswordObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GlassAuthInput(
                        controller: _confirmPasswordController,
                        label: "\u015eifre Tekrar",
                        icon: Icons.lock_reset_outlined,
                        obscureText: _isConfirmObscured,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmObscured = !_isConfirmObscured;
                            });
                          },
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _AuthErrorBanner(message: _error),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF24B7A4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Kay\u0131t Ol",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Zaten hesab\u0131n var m\u0131?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A707B),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onLoginTap,
                            child: const Text("Giri\u015f Yap"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassAuthInput extends StatelessWidget {
  const _GlassAuthInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _AuthFieldSurface(
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF607480),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF030405),
                        Color(0xFF070A0D),
                        Color(0xFF0B1115),
                        Color(0xFF080B0E),
                      ]
                    : const [
                        Color(0xFFF7FCFD),
                        Color(0xFFEFF6F8),
                        Color(0xFFE7EFF2),
                        Color(0xFFF4FAFC),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          child: IgnorePointer(
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    const Color(0xFF24B7A4).withOpacity(isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          right: -30,
          bottom: -80,
          child: IgnorePointer(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.95,
                  colors: [
                    const Color(0xFF24B7A4).withOpacity(isDark ? 0.10 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _RegisterWebInstallCard extends StatelessWidget {
  const _RegisterWebInstallCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFEAF6F8).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark
                  ? const Color(0xFF24B7A4).withOpacity(0.18)
                  : const Color(0xFFB9DDE1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AuthIconBadge(
                icon: Icons.phone_iphone_rounded,
                color: Color(0xFF24B7A4),
                size: 48,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'iPhone Kullanımı',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF10232C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kayıttan sonra Safari ile ana ekrana sabitleyebilirsin.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? Colors.white70
                                : const Color(0xFF607480),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InstallHint(
            text: 'Safari > Paylaş > Ana Ekrana Ekle yolunu kullan.',
          ),
        ],
      ),
    );
  }
}

class _InstallHint extends StatelessWidget {
  const _InstallHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: isDark ? Colors.white70 : const Color(0xFF526772),
      ),
    );
  }
}

class _AuthCardSurface extends StatelessWidget {
  const _AuthCardSurface({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF171B20), Color(0xFF0E1115)]
              : const [Color(0xFFFFFFFF), Color(0xFFF0F6F8)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFD1DEE3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.24 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AuthFieldSurface extends StatelessWidget {
  const _AuthFieldSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFD5E0E5),
        ),
      ),
      child: child,
    );
  }
}

class _AuthIconBadge extends StatelessWidget {
  const _AuthIconBadge({
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.22 : 0.16),
            (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
              isDark ? 0.92 : 0.98,
            ),
          ],
        ),
        border: Border.all(color: color.withOpacity(isDark ? 0.16 : 0.12)),
      ),
      child: Icon(
        icon,
        color: isDark ? Colors.white70 : color,
        size: iconSize,
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: Color(0xFFFF7A7A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
