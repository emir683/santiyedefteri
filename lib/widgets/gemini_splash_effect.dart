import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DIRECT REPRODUCTION FROM:
// https://github.com/flutterfx/flutterfx_widgets/tree/main/lib/gemini-splash
// ─────────────────────────────────────────────────────────────────────────────

/// Full Gemini Splash View (Direct implementation of SparkleDemo with our app colors)
class GeminiSplashView extends StatefulWidget {
  final VoidCallback? onClose;
  final Color starColor;
  final List<Color>? waveColors;
  final Color backgroundColor;

  const GeminiSplashView({
    super.key,
    this.onClose,
    this.starColor = const Color(0xFF10B981), // Emerald
    this.waveColors,
    this.backgroundColor = const Color(0xFF0F172A), // Dark
  });

  @override
  State<GeminiSplashView> createState() => _GeminiSplashViewState();
}

class _GeminiSplashViewState extends State<GeminiSplashView> {
  Key _combinedKey = UniqueKey();
  final GlobalKey<MysticalWavesState> _wavesKey = GlobalKey();

  List<Color> get _effectiveWaveColors =>
      widget.waveColors ??
      [
        const Color(0xFF10B981).withValues(alpha: 0.55), // Emerald
        const Color(0xFF06B6D4).withValues(alpha: 0.45), // Cyan
        const Color(0xFF34D399).withValues(alpha: 0.35), // Mint
      ];

  void _replayAnimation() {
    setState(() {
      _combinedKey = UniqueKey();
      _wavesKey.currentState?.stopAnimation();
    });
  }

  void _onStarAnimationComplete() {
    // Start waves animation when star animation completes
    _wavesKey.currentState?.startAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. GitHub repodaki UnifiedStarAnimation
          UnifiedStarAnimation(
            key: _combinedKey,
            size: 50,
            color: widget.starColor,
            totalDuration: const Duration(milliseconds: 2400),
            onAnimationComplete: _onStarAnimationComplete,
          ),

          // 2. GitHub repodaki MysticalWaves
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MysticalWaves(
              key: _wavesKey,
              height: 220,
              animationDuration: const Duration(milliseconds: 400),
              waveDuration: const Duration(seconds: 3),
              waveColors: _effectiveWaveColors,
            ),
          ),

          // 3. Alt Butonlar (Yeniden Oynat & Kapat)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yeniden Oynat Butonu (GitHub reposundaki replay butonu)
                  IconButton(
                    onPressed: _replayAnimation,
                    icon: const Icon(
                      Icons.replay_circle_filled_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                    tooltip: 'Yeniden Oynat',
                  ),
                  if (widget.onClose != null) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.starColor.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: widget.starColor.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'Sohbete Devam Et',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Sağ Üst Kapatma Çarpısı
          if (widget.onClose != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: IconButton(
                onPressed: widget.onClose,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Statik veya buton içi Gemini Yıldızı (GitHub StarPainter tabanlı)
class GeminiLogo extends StatelessWidget {
  final double size;
  final Color color;

  const GeminiLogo({
    super.key,
    this.size = 48.0,
    this.color = const Color(0xFF10B981),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: StarPainter(color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FROM combined_.dart (GitHub Repo)
// ─────────────────────────────────────────────────────────────────────────────

class UnifiedStarAnimation extends StatefulWidget {
  final Color color;
  final double size;
  final Duration totalDuration;
  final VoidCallback? onAnimationComplete;

  const UnifiedStarAnimation({
    super.key,
    this.color = Colors.pink,
    this.size = 50.0,
    this.totalDuration = const Duration(milliseconds: 4800),
    this.onAnimationComplete,
  });

  @override
  State<UnifiedStarAnimation> createState() => _UnifiedStarAnimationState();
}

class _UnifiedStarAnimationState extends State<UnifiedStarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Phase 1 animations (circle to star)
  late Animation<double> _starScale;
  late Animation<double> _circleRadius;
  late Animation<double> _circleOpacity;
  late Animation<double> _initialRotation;
  late Animation<double> _initialPosition;

  // Phase 2 animations (falling star)
  late Animation<double> _laterRotation;
  late Animation<double> _fallPosition;
  late Animation<double> _blurEffect;
  late Animation<double> _glowIntensity;
  late Animation<double> _stretchFactor;
  late Animation<double> _explosionProgress;
  late Animation<double> _particleSpread;

  // Particle system
  late List<Particle> _particles;
  final int particleCount = 12;

  double? _screenHeight;
  bool _isFirstPhase = true;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _controller = AnimationController(
      duration: widget.totalDuration,
      vsync: this,
    );

    _controller.addListener(() {
      if (_controller.value >= 0.4) {
        if (_isFirstPhase) {
          setState(() {
            _isFirstPhase = false;
          });
        }
      } else {
        if (!_isFirstPhase) {
          setState(() {
            _isFirstPhase = true;
          });
        }
      }

      if (_controller.value >= 0.85) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  void _initializeParticles() {
    _particles = List.generate(particleCount, (index) {
      final angle = (index * 2 * math.pi) / particleCount;
      return Particle(angle: angle);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenHeight = MediaQuery.of(context).size.height;
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    if (_screenHeight == null) return;

    // Phase 1 Animations (0% - 40% of total duration)
    _starScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _circleRadius = Tween<double>(
      begin: 0.0,
      end: widget.size * 0.20,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    ));

    _circleOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.4, curve: Curves.easeOut),
    ));

    _initialRotation = Tween<double>(
      begin: 0.0,
      end: math.pi / 2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.linear),
    ));

    _initialPosition = Tween<double>(
      begin: 0.0,
      end: -60.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    // Phase 2 Animations (40% - 100% of total duration)
    final fallStartY = -60.0 + MediaQuery.of(context).size.height * 0.5;
    final fallEndY = _screenHeight! - MediaQuery.of(context).padding.bottom;

    _laterRotation = Tween<double>(
      begin: math.pi / 2, // starts from where _initialRotation ended
      end: math.pi, // rotates another 90 degrees
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    ));

    _fallPosition = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: fallStartY, end: fallEndY - 100)
            .chain(CurveTween(curve: Curves.easeInQuart)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: fallEndY - 100, end: fallEndY - 50)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0),
    ));

    _blurEffect = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 25.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 25.0, end: 35.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0),
    ));

    _glowIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0),
    ));

    _stretchFactor = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 5.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 5.0, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0),
    ));

    _explosionProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
    );

    _particleSpread = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenHeight == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final xPosition = screenWidth / 2 - widget.size / 2;
        final yPosition = _isFirstPhase
            ? MediaQuery.of(context).size.height * 0.5 + _initialPosition.value
            : _fallPosition.value;

        return Positioned(
          left: xPosition,
          top: yPosition,
          child: SizedBox(
            width: widget.size *
                (1 + (_isFirstPhase ? 0 : _explosionProgress.value * 3)),
            height: widget.size *
                (1 + (_isFirstPhase ? 0 : _explosionProgress.value * 3)),
            child: _controller.value < 0.4
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _initialRotation.value,
                        child: Transform.scale(
                          scale: _starScale.value,
                          child: CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: StarPainter(color: widget.color),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: _circleOpacity.value,
                        child: Container(
                          width: _circleRadius.value * 2,
                          height: _circleRadius.value * 2,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  )
                : CustomPaint(
                    painter: EnhancedStarPainter(
                      primaryColor: widget.color,
                      blur: _blurEffect.value,
                      rotation: _laterRotation.value,
                      stretchFactor: _stretchFactor.value,
                      explosionProgress: _explosionProgress.value,
                      particles: _particles,
                      particleSpread: _particleSpread.value,
                      glowIntensity: _glowIntensity.value,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class StarPainter extends CustomPainter {
  final Color color;

  StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    final radius = size.width / 2 * 0.8; // Star size
    final controlPointDistance =
        size.width * 0.4 * 0.5; // Control point distance

    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final pointX = center.dx + math.cos(angle) * radius;
      final pointY = center.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(pointX, pointY);
      } else {
        final prevAngle = ((i - 1) * math.pi / 2);
        final midAngle = prevAngle + math.pi / 4;

        final controlX = center.dx + math.cos(midAngle) * controlPointDistance;
        final controlY = center.dy + math.sin(midAngle) * controlPointDistance;

        path.quadraticBezierTo(controlX, controlY, pointX, pointY);
      }
    }

    // Close the shape with the final curve
    final controlX =
        center.dx + math.cos(7 * math.pi / 4) * controlPointDistance;
    final controlY =
        center.dy + math.sin(7 * math.pi / 4) * controlPointDistance;
    path.quadraticBezierTo(controlX, controlY, center.dx + radius, center.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class Particle {
  final double angle;
  final double speed;
  final double size;

  Particle({
    required this.angle,
    this.speed = 1.0,
    this.size = 1.0,
  });
}

class EnhancedStarPainter extends CustomPainter {
  final Color primaryColor;
  final double blur;
  final double stretchFactor;
  final double explosionProgress;
  final List<Particle> particles;
  final double particleSpread;
  final double glowIntensity;
  final double rotation;

  EnhancedStarPainter({
    required this.primaryColor,
    required this.blur,
    required this.stretchFactor,
    required this.explosionProgress,
    required this.particles,
    required this.particleSpread,
    required this.glowIntensity,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final starPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    // Enhanced base glow
    final glowPaint = Paint()
      ..color =
          primaryColor.withValues(alpha: (glowIntensity * 0.7).clamp(0.0, 1.0))
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, blur * 3);

    if (explosionProgress > 0) {
      // Draw bottom screen glow
      final screenGlowRect = Rect.fromLTWH(
          -size.width,
          size.height * 0.5,
          size.width * 3, // Wider to ensure full coverage
          size.height);

      final screenGlowGradient = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          primaryColor.withValues(alpha: (0.4 * explosionProgress).clamp(0.0, 1.0)),
          primaryColor.withValues(alpha: (0.1 * explosionProgress).clamp(0.0, 1.0)),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      canvas.drawRect(screenGlowRect,
          Paint()..shader = screenGlowGradient.createShader(screenGlowRect));

      // Enhanced explosion effect
      final radius =
          size.width / 2 * (1 + explosionProgress * 2.5); // Increased radius

      // Outer glow
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = primaryColor.withValues(alpha: (0.5 * (1 - explosionProgress)).clamp(0.0, 1.0))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 3));

      // Enhanced particle trails
      for (var particle in particles) {
        final spread = radius * particleSpread;
        final dx = math.cos(particle.angle) * spread;
        final dy = math.sin(particle.angle) * spread;

        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + dx, center.dy + dy);

        canvas.drawPath(
            path,
            Paint()
              ..color = primaryColor.withValues(alpha: (0.9 * (1 - explosionProgress)).clamp(0.0, 1.0))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 // Increased width
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 1.5));
      }

      // Enhanced center glow
      canvas.drawCircle(
          center,
          radius * 0.4, // Increased center glow size
          glowPaint
            ..color = primaryColor.withValues(alpha: (1.0 * (1 - explosionProgress)).clamp(0.0, 1.0)));
    } else {
      // Enhanced star glow
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1.0, stretchFactor);
      canvas.translate(-center.dx, -center.dy);

      final starPath = _createStarPath(center, size.width / 2 * 0.8);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
      // Multiple layers of glow for increased brightness
      for (var i = 3; i > 0; i--) {
        canvas.drawPath(
            starPath,
            Paint()
              ..color = primaryColor.withValues(alpha: (glowIntensity * 0.3).clamp(0.0, 1.0))
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * i));
      }
      canvas.drawPath(starPath, glowPaint);
      canvas.drawPath(starPath, starPaint);
      canvas.restore();

      canvas.restore();
    }
  }

  Path _createStarPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final controlX =
            center.dx + math.cos(angle - math.pi / 4) * (radius * 0.5);
        final controlY =
            center.dy + math.sin(angle - math.pi / 4) * (radius * 0.5);
        path.quadraticBezierTo(controlX, controlY, x, y);
      }
    }

    final lastControlX = center.dx + math.cos(-math.pi / 4) * (radius * 0.5);
    final lastControlY = center.dy + math.sin(-math.pi / 4) * (radius * 0.5);
    path.quadraticBezierTo(
        lastControlX, lastControlY, center.dx + radius, center.dy);

    return path;
  }

  @override
  bool shouldRepaint(EnhancedStarPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// FROM glowing_fog.dart (GitHub Repo)
// ─────────────────────────────────────────────────────────────────────────────

class MysticalWaves extends StatefulWidget {
  final double height;
  final Duration animationDuration;
  final Duration waveDuration;
  final List<Color>? waveColors;

  const MysticalWaves({
    super.key,
    this.height = 200.0,
    this.animationDuration = const Duration(seconds: 2),
    this.waveDuration = const Duration(seconds: 3),
    this.waveColors,
  });

  @override
  State<MysticalWaves> createState() => MysticalWavesState();
}

class MysticalWavesState extends State<MysticalWaves>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _visibilityController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _typingIdleTimer;
  bool _isLockedActive = false;
  double _surgeOffset = 0.0;

  // Ses Etkileşimli Aura Mesh Durumu
  bool _isVoiceActive = false;
  double _voiceLevel = 0.0;

  List<Color> get _waveColors {
    if (_isVoiceActive) {
      return [
        const Color(0xFF10B981).withValues(alpha: 0.70), // Emerald
        const Color(0xFF06B6D4).withValues(alpha: 0.65), // Cyan
        const Color(0xFF8B5CF6).withValues(alpha: 0.45), // Electric Violet Aura
        const Color(0xFF34D399).withValues(alpha: 0.50), // Mint
      ];
    }
    return widget.waveColors ??
        [
          const Color(0xFF10B981).withValues(alpha: 0.5), // Emerald
          const Color(0xFF06B6D4).withValues(alpha: 0.4), // Cyan
          const Color(0xFF34D399).withValues(alpha: 0.3), // Soft mint
        ];
  }

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: widget.waveDuration,
    )..repeat();

    _visibilityController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    _waveController.dispose();
    _visibilityController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Sesli etkileşim aktif veya pasif olduğunda dalgayı yumuşakça açıp kapatır
  void setVoiceActive(bool active) {
    if (!mounted) return;
    _isVoiceActive = active;
    _typingIdleTimer?.cancel();
    if (active) {
      _visibilityController.animateTo(
        0.92,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _voiceLevel = 0.0;
      if (!_isLockedActive) {
        _visibilityController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOut,
        );
      }
    }
    setState(() {});
  }

  /// Mikrofon ses genliğine (0.0 - 1.0) bağlı olarak dalgayı gerçek zamanlı canlandırır
  void updateVoiceLevel(double normalizedLevel) {
    if (!mounted || !_isVoiceActive) return;
    final clamped = normalizedLevel.clamp(0.0, 1.0);
    // Yumuşatılmış ses dalgası interpolasyonu
    _voiceLevel = (_voiceLevel * 0.40) + (clamped * 0.60);
    _surgeOffset += 0.08 + (_voiceLevel * 0.22);
    setState(() {});
  }

  /// Klavyede her karakter basıldığında dalgayı yukarı fırlatan ve dalgalandıran metot
  void pulse() {
    if (!mounted) return;

    // Tuşa basıldığında anlık sıvı sıçrama ve yer değiştirme
    _surgeOffset += 0.45;

    // Zirveye vurup sönümlenen nabız animasyonu
    _pulseController.forward(from: 0.0);

    // Eğer mesaj gönderimi gibi kilitli aktiflik veya ses kaydı yoksa, yazma esnasında dalgayı görünür kıl
    if (!_isLockedActive && !_isVoiceActive) {
      if (_visibilityController.value < 0.70) {
        _visibilityController.animateTo(
          0.70,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutQuad,
        );
      }

      // Kullanıcı yazmayı bıraktıktan 1.3 saniye sonra dalgayı sakince aşağı çek
      _typingIdleTimer?.cancel();
      _typingIdleTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted && !_isLockedActive && !_isVoiceActive) {
          _visibilityController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> startAnimation() async {
    if (!mounted) return;
    _isLockedActive = true;
    _typingIdleTimer?.cancel();
    setState(() {});
    await _visibilityController.forward();
  }

  Future<void> stopAnimation() async {
    if (!mounted) return;
    _isLockedActive = false;
    _typingIdleTimer?.cancel();
    await _visibilityController.reverse();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [_waveController, _visibilityController, _pulseController],
      ),
      builder: (context, child) {
        final vis = _visibilityController.value;
        if (vis <= 0.01) return const SizedBox.shrink();

        final pulseVal = _pulseAnimation.value;
        // Dinamik yükseklik: Hem klavye nabzı hem de gerçek zamanlı ses desibeli
        final dynamicBoost = (0.22 * pulseVal) + (0.55 * _voiceLevel);
        final currentHeight = widget.height * vis * (1.0 + dynamicBoost);

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: (30 + 12 * pulseVal + 16 * _voiceLevel) * vis,
              sigmaY: (30 + 12 * pulseVal + 16 * _voiceLevel) * vis,
            ),
            child: SizedBox(
              height: currentHeight,
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  // Ses etkileşimli arka plan Aura Mesh parıltısı
                  if (_isVoiceActive || _voiceLevel > 0.02)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, 1.0),
                              radius: 1.25,
                              colors: [
                                const Color(0xFF10B981).withValues(
                                  alpha: (0.30 + 0.35 * _voiceLevel) * vis,
                                ),
                                const Color(0xFF06B6D4).withValues(
                                  alpha: (0.20 + 0.28 * _voiceLevel) * vis,
                                ),
                                const Color(0xFF8B5CF6).withValues(
                                  alpha: (0.10 + 0.20 * _voiceLevel) * vis,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.40, 0.70, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Canlı Sıvı Dalgalar
                  ...List.generate(
                    _waveColors.length,
                    (index) => CustomPaint(
                      size: Size.infinite,
                      painter: _WavePainter(
                        waveColor: _waveColors[index],
                        animation: _waveController,
                        waveOffset: index * 0.35 + _surgeOffset,
                        amplitude: (25 - (index * 4.5)) *
                            (1.0 + 1.15 * pulseVal + 2.2 * _voiceLevel),
                        frequency: 1.5 +
                            (index * 0.45) +
                            (0.35 * pulseVal) +
                            (0.85 * _voiceLevel),
                        blur: (30 + 10 * pulseVal + 14 * _voiceLevel) * vis,
                        opacity: ((0.50 + 0.30 * pulseVal + 0.35 * _voiceLevel) * vis)
                            .clamp(0.0, 1.0),
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
}

class _WavePainter extends CustomPainter {
  final Color waveColor;
  final Animation<double> animation;
  final double waveOffset;
  final double amplitude;
  final double frequency;
  final double blur;
  final double opacity;

  _WavePainter({
    required this.waveColor,
    required this.animation,
    this.waveOffset = 0.0,
    this.amplitude = 20.0,
    this.frequency = 1.5,
    this.blur = 30.0,
    this.opacity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(0, height);

    for (double x = 0; x <= width; x++) {
      final relativeX = x / width;
      final normalizedX = (relativeX * frequency * 2 * math.pi) +
          (animation.value * 2 * math.pi) +
          waveOffset;

      final y = height - (math.sin(normalizedX) * amplitude) - (height * 0.2);
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
