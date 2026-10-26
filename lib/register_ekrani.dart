import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'auth_servisi.dart';
import 'fcm_servisi.dart';
import 'web_install_helper.dart';
import 'widgets/auth_showcase_carousel.dart';

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
      setState(() => _error = "Lütfen tüm alanları doldurun.");
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() => _error = "Şifreler birbiriyle uyuşmuyor.");
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

      // Kayıt başarılı: FCM token'ı kaydet (Bildirim onboarding AnaMenuEkrani'nda gösterilir)
      await FcmServisi().kullaniciBagla();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? "Bir hata oluştu.";
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


  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _authServisi.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Google ile giriş başarısız: $e";
        _loading = false;
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _authServisi.signInWithApple();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msgLower = (e.message ?? '').toLowerCase();
      if (e.code == 'canceled' ||
          e.code == 'cancelled' ||
          msgLower.contains('cancel') ||
          msgLower.contains('1001')) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = "Apple ile giriş: ${e.message ?? e.code}";
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') ||
          errStr.contains('1001') ||
          errStr.contains('com.apple.authenticationservices.authorizationerror')) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = "Apple ile giriş: $e";
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
      barrierColor: Colors.black.withValues(alpha: 0.75),
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
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFB6DDE8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
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
                  // Özellik listesi (Emoji içermeyen temiz kurumsal dil)
                  ..._bildirimOzellikleri(isDark),
                  const SizedBox(height: 24),
                  // Aktif et butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
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
      ('İşçi ve Puantaj', 'Ekleme, güncelleme ve ödeme bildirimleri'),
      ('Günlük Raporlar', 'Günlük rapor kaydedilince anında haberdar olun'),
      ('Kesintisiz Bildirim', 'Uygulama kapalıyken de bildirimler iletilir'),
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
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _AuthCardSurface(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // En üstte logo (ortalanmış)
                      const Center(
                        child: AuthLogoBadge(size: 60),
                      ),
                      const SizedBox(height: 10),
                      // Altına bir satıra ortalanmış Şantiye Puantaj Defteri
                      Text(
                        "Şantiye Puantaj Defteri",
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F1E26),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Altına daha küçük fontla hoşgeldiniz yazısı
                      Text(
                        "Hoş Geldiniz • Yeni Hesap Oluşturun",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? const Color(0xFF24B7A4)
                              : const Color(0xFF0F766E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Otomatik Kayan Özellik Vitrini (Kompakt, taşma yapmaz)
                      const AuthFeatureShowcaseCarousel(height: 60),
                      if (WebInstallHelper.shouldShowInstallCard) ...[
                        const SizedBox(height: 10),
                        const _RegisterWebInstallCard(),
                      ],
                      const SizedBox(height: 12),
                      // Kayıt Form Alanları (Kompakt ve taşma korumalı)
                      _GlassAuthInput(
                        controller: _adSoyadController,
                        label: "Ad Soyad",
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 10),
                      _GlassAuthInput(
                        controller: _usernameController,
                        label: "Kullanıcı Adı",
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 10),
                      _GlassAuthInput(
                        controller: _emailController,
                        label: "E-posta",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      _GlassAuthInput(
                        controller: _passwordController,
                        label: "Şifre",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _isPasswordObscured,
                        suffixIcon: IconButton(
                          iconSize: 21,
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
                      const SizedBox(height: 10),
                      _GlassAuthInput(
                        controller: _confirmPasswordController,
                        label: "Şifre Tekrar",
                        icon: Icons.lock_reset_outlined,
                        obscureText: _isConfirmObscured,
                        suffixIcon: IconButton(
                          iconSize: 21,
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
                        const SizedBox(height: 12),
                        _AuthErrorBanner(message: _error),
                      ],
                      const SizedBox(height: 16),
                      // Kayıt Butonu
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2DD4BF),
                              Color(0xFF14B8A6),
                              Color(0xFF0F766E),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14B8A6)
                                  .withValues(alpha: isDark ? 0.35 : 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Kayıt Ol",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFBFD0D6),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              "veya",
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF607480),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFBFD0D6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: Image.asset('assets/google_logo.png', height: 20),
                        label: const Text(
                          "Google ile Devam Et",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        ),
                        onPressed: _loading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFBFD0D6),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.85),
                          foregroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF10232C),
                        ),
                      ),
                      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.apple,
                            size: 22,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Apple ile Devam Et",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          onPressed: _loading ? null : _signInWithApple,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.20)
                                  : const Color(0xFF0F172A),
                            ),
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Zaten hesabın var mı?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A707B),
                              fontSize: 13.5,
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onLoginTap,
                            child: const Text(
                              "Giriş Yap",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
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
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          color: isDark ? Colors.white : const Color(0xFF10232C),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF5E727D),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.9 : 0.8),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                        Color(0xFF030406),
                        Color(0xFF06090D),
                        Color(0xFF0A0F15),
                        Color(0xFF06080B),
                      ]
                    : const [
                        Color(0xFFF7FCFD),
                        Color(0xFFEFF5F8),
                        Color(0xFFE6EFF3),
                        Color(0xFFF4FAFC),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -60,
          right: -60,
          child: IgnorePointer(
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    const Color(0xFF24B7A4).withValues(
                      alpha: isDark ? 0.16 : 0.10,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -40,
          right: -40,
          bottom: -70,
          child: IgnorePointer(
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.95,
                  colors: [
                    const Color(0xFF0EA5E9).withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFEAF6F8).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF24B7A4).withValues(alpha: 0.22)
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
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'iPhone Kullanımı',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF10232C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kayıttan sonra Safari ile ana ekrana sabitleyebilirsin.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF607480),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _InstallHint(
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
        fontSize: 11.5,
        height: 1.35,
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
              ? const [Color(0xFF161B22), Color(0xFF0D1014)]
              : const [Color(0xFFFFFFFF), Color(0xFFF1F6F8)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0xFFCFDDE2),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.07),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF24B7A4).withValues(
              alpha: isDark ? 0.06 : 0.04,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD6E2E6),
          width: 1,
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
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.22 : 0.16),
            (isDark ? const Color(0xFF171B20) : Colors.white).withValues(
              alpha: isDark ? 0.92 : 0.98,
            ),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.16),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: Color(0xFFFF7A7A),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
