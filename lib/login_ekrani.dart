import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_servisi.dart';
import 'web_install_helper.dart';

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
      setState(() => _error = "L\u00fctfen t\u00fcm alanlar\u0131 doldurun.");
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
        _error = e.message ?? "Giri\u015f ba\u015far\u0131s\u0131z.";
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
        _error = "Google ile giri\u015f ba\u015far\u0131s\u0131z: $e";
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
      barrierColor: Colors.black.withOpacity(0.55),
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
                        _AuthIconBadge(
                          icon: Icons.lock_reset_rounded,
                          color: Color(0xFF24B7A4),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "\u015eifre S\u0131f\u0131rlama",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "E-posta adresini gir. Sana \u015fifre s\u0131f\u0131rlama ba\u011flant\u0131s\u0131 g\u00f6nderece\u011fiz.",
                      style: TextStyle(height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    _DialogInput(
                      controller: emailController,
                      hintText: "E-posta adresi",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: errorText,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(ctx),
                            child: const Text("\u0130ptal"),
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
                                            "Ge\u00e7erli bir e-posta adresi gir.";
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isLoading = true;
                                      errorText = null;
                                    });

                                    try {
                                      await _authServisi
                                          .sifreSifirlamaEmailiGonder(
                                        emailController.text.trim(),
                                      );
                                      if (!mounted) return;
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "S\u0131f\u0131rlama ba\u011flant\u0131s\u0131 ${emailController.text.trim()} adresine g\u00f6nderildi.",
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
                                : const Text("G\u00f6nder"),
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _AuthCardSurface(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const _AuthIconBadge(
                            icon: Icons.construction_rounded,
                            color: Color(0xFF24B7A4),
                            size: 60,
                            iconSize: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "\u015eantiye Puantaj Defteri",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Hesab\u0131na giri\u015f yap ve kontrol merkezine devam et.",
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
                        const _WebInstallCard(),
                      ],
                      const SizedBox(height: 26),
                      _GlassAuthInput(
                        controller: _emailOrUsernameController,
                        label: "E-posta veya kullan\u0131c\u0131 ad\u0131",
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _GlassAuthInput(
                        controller: _passwordController,
                        label: "\u015eifre",
                        icon: Icons.lock_outline_rounded,
                        obscureText: _isObscured,
                        suffixIcon: IconButton(
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
                          onPressed: () => _showForgotPasswordDialog(context),
                          child: const Text("\u015eifremi Unuttum"),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _AuthErrorBanner(message: _error),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _loading ? null : _signIn,
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
                                "Giri\u015f Yap",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 18),
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
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        icon: Image.asset('assets/google_logo.png', height: 20),
                        label: const Text(
                          "Google ile Devam Et",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _loading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFBFD0D6),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white.withOpacity(0.68),
                          foregroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF10232C),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Hesab\u0131n yok mu?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF5A707B),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onRegisterTap,
                            child: const Text("Kay\u0131t Ol"),
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
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFF8A8A),
              fontWeight: FontWeight.w600,
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

class _WebInstallCard extends StatelessWidget {
  const _WebInstallCard();

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
                icon: Icons.add_to_home_screen_rounded,
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
                      'Ana Ekrana Ekle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF10232C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Safari üzerinden uygulamayı tam ekran gibi kullan.',
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
          _InstallStep(
            no: '1',
            text: 'Safari alt menüsünde Paylaş düğmesine dokun.',
          ),
          const SizedBox(height: 8),
          _InstallStep(
            no: '2',
            text: 'Ana Ekrana Ekle seçeneğini aç.',
          ),
          const SizedBox(height: 8),
          _InstallStep(
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
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF24B7A4).withOpacity(isDark ? 0.18 : 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            no,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF24B7A4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              height: 1.4,
              fontSize: 12,
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

class _SimpleDialogCard extends StatelessWidget {
  const _SimpleDialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AuthCardSurface(
      padding: const EdgeInsets.all(24),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
