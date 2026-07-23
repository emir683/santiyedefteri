import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_servisi.dart';
import 'fcm_servisi.dart';
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

      // Kayıt başarılı: FCM token'a kaydet ve bildirim onboarding göster
      await FcmServisi().kullaniciBagla();
      if (mounted) {
        await _bildirimOnboardingGoster();
      }
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

  /// Kayıt sonrası bildirim izin onboarding dialog'ı.
  Future<void> _bildirimOnboardingGoster() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'bildirim_onboarding',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF151B24), Color(0xFF0D1117)]
                    : const [Color(0xFFFFFFFF), Color(0xFFF0F7FA)],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : const Color(0xFFB6DDE8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İkon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0F7C86)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Bildirimlerden Haberdar Ol',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ekibindeki işlemler, avans ve rapor girdiğinde anında bildirim al. Uygulama kapalıyken de çalışır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: isDark ? Colors.white60 : const Color(0xFF526772),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Özellik listesi
                  ..._bildirimOzellikleri(isDark),
                  const SizedBox(height: 24),
                  // Aktif et butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        // FCM izni init() sırasında zaten isteniyor;
                        // burada sadece kapatıyoruz.
                      },
                      icon: const Icon(Icons.notifications_active_rounded, size: 18),
                      label: const Text(
                        'Bildirimleri Aç',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Daha sonra',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  List<Widget> _bildirimOzellikleri(bool isDark) {
    final ozellikler = [
      ('👷 İşçi işlemleri', 'Ekleme, güncelleme ve ödeme bildirimleri'),
      ('📄 Rapor girilince', 'Günlük rapor kaydedilince haberdar ol'),
      ('⏰ Kapalıyken de çalışır', 'Uygulamanı açman gerekmez'),
    ];
    return [
      const SizedBox(height: 16),
      ...ozellikler.map(
        (o) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F7C86),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF526772),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _AuthCardSurface(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _AuthIconBadge(
                            icon: Icons.person_add_alt_1_rounded,
                            color: Color(0xFF24B7A4),
                            size: 52,
                            iconSize: 25,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Yeni Hesap Olu\u015ftur",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 21,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Yeni hesab\u0131n\u0131 olu\u015ftur.",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF526772),
                                    height: 1.3,
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
                      const SizedBox(height: 22),
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
                          iconSize: 22,
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
                          iconSize: 22,
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
                            borderRadius: BorderRadius.circular(18),
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
                      const SizedBox(height: 16),
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
          prefixIcon: Icon(icon, size: 22),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF607480),
            fontSize: 15,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
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
