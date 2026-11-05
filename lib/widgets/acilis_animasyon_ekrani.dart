import 'package:flutter/material.dart';
import '../auth_gate.dart';

/// Twitter / X tarzı açılış geçişi:
/// UI isolate'ini %100 boşta tutarak animasyonun 120 FPS yağ gibi akmasını sağlar.
/// Arka plandaki ağır Firebase ve ekran yüklemeleri bu animasyon bitene kadar başlatılmaz.
class AcilisAnimasyonEkrani extends StatefulWidget {
  final VoidCallback? onAnimationComplete;
  final Duration duration;

  const AcilisAnimasyonEkrani({
    super.key,
    this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 980),
  });

  @override
  State<AcilisAnimasyonEkrani> createState() => _AcilisAnimasyonEkraniState();
}

class _AcilisAnimasyonEkraniState extends State<AcilisAnimasyonEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Twitter / X ritmi:
    // 0.0 - 0.15: Logo merkezde sabit (işletim sistemi splash'inden sıfır atlamayla devralır)
    // 0.15 - 0.45: Tok ve hafif küçülme (1.0 -> 0.88)
    // 0.45 - 1.00: Akıcı genleşme (0.88 -> 2.15)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 14.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 55,
      ),
    ]).animate(_controller);

    // 0.48 - 0.95 aralığında logo ekran dışına fırlarken arka plan eriyerek ana ekranı açar
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.96, curve: Curves.easeOutQuad),
      ),
    );

    _controller.forward().whenComplete(() {
      if (mounted) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: bgColor,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: 110,
              height: 110,
              child: Image.asset(
                'assets/spd_clean_icon.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) {
                  return Image.asset(
                    'assets/notification_icon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uygulama açılış kapısı:
/// TAM İZOLASYON: Animasyon çalışırken ana ekran (AuthGate) henüz widget ağacına eklenmez.
/// Böylece ana ekranın Firestore sorguları ve ağır widget çizimleri animasyonun FPS'ini DÜŞÜREMEZ.
/// Animasyon bittiği anda 200ms ipeksi bir cross-fade ile ana ekran devreye girer.
class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  bool _animationFinished = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,
      child: !_animationFinished
          ? AcilisAnimasyonEkrani(
              key: const ValueKey('isolated_splash_screen'),
              onAnimationComplete: () {
                if (mounted) {
                  setState(() {
                    _animationFinished = true;
                  });
                }
              },
            )
          : const AuthGate(key: ValueKey('main_auth_gate')),
    );
  }
}
