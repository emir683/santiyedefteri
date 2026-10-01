import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_servisi.dart';
import 'web_install_helper.dart';
import 'widgets/auth_showcase_carousel.dart';

class LoginEkrani extends StatefulWidget {
  const LoginEkrani({super.key, required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  @override
  State<LoginEkrani> createState() => _LoginEkraniState();
}

class _LoginEkraniState extends State<LoginEkrani> {
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthServisi _authServisi = AuthServisi();

  String _error = '';
  bool _loading = false;
  bool _isObscured = true;

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailOrUsernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = "Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _authServisi.signInWithEmailOrUsername(
        _emailOrUsernameController.text.trim(),
        _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? "Giriş başarısız.";
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

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SimpleDialogCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        AuthLogoBadge(size: 44),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Şifre Sıfırlama",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "E-posta adresini gir. Sana şifre sıfırlama bağlantısı göndereceğiz.",
                      style: TextStyle(height: 1.45, fontSize: 13.5),
                    ),
                    const SizedBox(height: 16),
                    _DialogInput(
                      controller: emailController,
                      hintText: "E-posta adresi",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: errorText,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(ctx),
                            child: const Text("İptal"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (emailController.text.trim().isEmpty) {
                                      setDialogState(() {
                                        errorText = "E-posta adresi gerekli.";
                                      });
                                      return;
                                    }
                                    if (!emailController.text.contains('@')) {
                                      setDialogState(() {
                                        errorText =
                                            "Geçerli bir e-posta adresi gir.";
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isLoading = true;
                                      errorText = null;
                                    });

                                    try {
                                      final sentEmail = emailController.text.trim();
                                      await _authServisi
                                          .sifreSifirlamaEmailiGonder(
                                        sentEmail,
                                      );
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Sıfırlama bağlantısı $sentEmail adresine gönderildi.",
                                          ),
                                          backgroundColor: const Color(
                                            0xFF24B7A4,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      setDialogState(() {
                                        isLoading = false;
                                        errorText = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF24B7A4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Gönder"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                        "Hoş Geldiniz",
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
                        const _WebInstallCard(),
                      ],
                      const SizedBox(height: 12),
                      // Giriş Alanları
                      _GlassAuthInput(
                        controller: _emailOrUsernameController,
                        label: "E-posta / kullanıcı adı",
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 11),
                      _GlassAuthInput(
                        controller: _passwordController,
                        label: "Şifre",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _isObscured,
                        suffixIcon: IconButton(
                          iconSize: 21,
                          icon: Icon(
                            _isObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscured = !_isObscured;
                            });
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showForgotPasswordDialog(context),
                          child: const Text(
                            "Şifremi Unuttum",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _AuthErrorBanner(message: _error),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 10),
                      // Giriş Butonu
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
                          onPressed: _loading ? null : _signIn,
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
                                  "Giriş Yap",
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
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Hesabın yok mu?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A707B),
                              fontSize: 13.5,
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onRegisterTap,
                            child: const Text(
                              "Kayıt Ol",
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

class _DialogInput extends StatelessWidget {
  const _DialogInput({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.errorText,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthFieldSurface(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, size: 20),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFF8A8A),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ],
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

class _WebInstallCard extends StatelessWidget {
  const _WebInstallCard();

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
                icon: Icons.add_to_home_screen_rounded,
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
                      'Ana Ekrana Ekle',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF10232C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Safari üzerinden uygulamayı tam ekran gibi kullan.',
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
          const _InstallStep(
            no: '1',
            text: 'Safari alt menüsünde Paylaş düğmesine dokun.',
          ),
          const SizedBox(height: 6),
          const _InstallStep(
            no: '2',
            text: 'Ana Ekrana Ekle seçeneğini aç.',
          ),
          const SizedBox(height: 6),
          const _InstallStep(
            no: '3',
            text: 'Kaydedince uygulama ana ekranda kart olarak görünür.',
          ),
        ],
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({required this.no, required this.text});

  final String no;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF24B7A4).withValues(
              alpha: isDark ? 0.20 : 0.14,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            no,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF24B7A4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              height: 1.35,
              fontSize: 11.5,
              color: isDark ? Colors.white70 : const Color(0xFF526772),
            ),
          ),
        ),
      ],
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

class _SimpleDialogCard extends StatelessWidget {
  const _SimpleDialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AuthCardSurface(
      padding: const EdgeInsets.all(22),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
