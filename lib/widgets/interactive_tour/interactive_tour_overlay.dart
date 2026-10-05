import 'dart:ui';
import 'package:flutter/material.dart';
import 'interactive_tour_model.dart';

/// Ekran üzerine yerleşen, hedef widget'ı neon halka ile vurgulayan
/// ve kesinlikle alt/üst sınır taşması (overpixel) yapmayan responsive tur katmanı.
class InteractiveTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const InteractiveTourOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<InteractiveTourOverlay> createState() => _InteractiveTourOverlayState();
}

class _InteractiveTourOverlayState extends State<InteractiveTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _triggerStepEnter();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerStepEnter() {
    if (widget.steps.isNotEmpty && _currentStepIndex < widget.steps.length) {
      widget.steps[_currentStepIndex].onStepEnter?.call();
    }
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _triggerStepEnter();
    } else {
      widget.onFinish();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _triggerStepEnter();
    }
  }

  Rect? _calculateTargetRect(TourStep step) {
    if (step.targetKey == null) return null;
    final targetContext = step.targetKey!.currentContext;
    if (targetContext == null) return null;

    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(
      offset.dx - step.targetPadding.left,
      offset.dy - step.targetPadding.top,
      size.width + step.targetPadding.horizontal,
      size.height + step.targetPadding.vertical,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final currentStep = widget.steps[_currentStepIndex];
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    final targetRect = _calculateTargetRect(currentStep);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Arka Plan Karartması & Hedef Çerçeve Vurgusu (Spotlight)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  borderRadius: currentStep.targetBorderRadius,
                  pulseValue: _pulseAnimation.value,
                ),
              );
            },
          ),

          // 2. Taşmayı Kesinlikle Engelleyen Responsive Bilgi Kartı
          _buildResponsiveTooltip(
            context: context,
            step: currentStep,
            targetRect: targetRect,
            screenSize: screenSize,
            safePadding: safePadding,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveTooltip({
    required BuildContext context,
    required TourStep step,
    required Rect? targetRect,
    required Size screenSize,
    required EdgeInsets safePadding,
  }) {
    final double cardHorizontalMargin = 16.0;
    final double availableWidth = screenSize.width - (cardHorizontalMargin * 2);

    // Ekranın yüksekliğine göre kart için güvenli maksimum yükseklik
    final double maxCardHeight = (screenSize.height * 0.38).clamp(160.0, 290.0);
    final double estimatedCardHeight = 220.0;

    double topPosition;

    if (targetRect == null) {
      // Hedef yoksa (Ekran Giriş/Bitiş adımı) ekranın dikey olarak tam ortasına hizala
      topPosition = (screenSize.height - estimatedCardHeight) / 2;
    } else {
      final targetCenterY = targetRect.center.dy;
      final screenCenterY = screenSize.height / 2;

      if (targetCenterY > screenCenterY) {
        // Hedef ekranın alt yarısında -> Kartı hedefin ÜSTÜNE yerleştir
        topPosition = targetRect.top - estimatedCardHeight - 16;
      } else {
        // Hedef ekranın üst yarısında -> Kartı hedefin ALTINA yerleştir
        topPosition = targetRect.bottom + 16;
      }
    }

    // Taşmaları (Overpixel) sıfırlamak için kesin alt ve üst sınırlar
    final minTop = safePadding.top + 16.0;
    final maxTop = screenSize.height - safePadding.bottom - estimatedCardHeight - 16.0;

    if (maxTop > minTop) {
      topPosition = topPosition.clamp(minTop, maxTop);
    } else {
      topPosition = minTop;
    }

    final isLastStep = _currentStepIndex == widget.steps.length - 1;
    final isFirstStep = _currentStepIndex == 0;

    return Positioned(
      top: topPosition,
      left: cardHorizontalMargin,
      width: availableWidth,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<String>('step_${step.id}'),
          constraints: BoxConstraints(maxHeight: maxCardHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF141A23).withValues(alpha: 0.96),
                const Color(0xFF0D1218).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.70),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kart Başlığı ve Adım Bilgisi
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            step.icon,
                            color: const Color(0xFF2DD4BF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_currentStepIndex + 1} / ${widget.steps.length}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Açıklama Metni (Taşma riskine karşı Scrollable)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          step.description,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Alt Butonlar ve Adım Noktaları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Sol Buton: Atla veya Geri
                        if (isFirstStep)
                          TextButton(
                            onPressed: widget.onSkip,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[400],
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Turu Atla',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: _previousStep,
                            icon: const Icon(Icons.arrow_back_rounded, size: 14),
                            label: const Text('Geri', style: TextStyle(fontSize: 12.5)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[300],
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),

                        // Ortadaki İlerleme Noktaları (Dots)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            widget.steps.length,
                            (index) {
                              final isSelected = index == _currentStepIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                height: 5,
                                width: isSelected ? 16 : 5,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF14B8A6)
                                      : Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              );
                            },
                          ),
                        ),

                        // Sağ Buton: İleri veya Bitir
                        ElevatedButton.icon(
                          onPressed: _nextStep,
                          icon: Icon(
                            isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            size: 15,
                          ),
                          label: Text(
                            isLastStep ? 'Anladım' : 'İleri',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}

/// Arka planı karartan ve hedef widget'ı keserek etrafına neon halka çizen painter
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;
  final double pulseValue;

  _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.76)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      // Hedef yoksa tüm ekranı eşit karart
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
      return;
    }

    final targetRRect = RRect.fromRectAndRadius(
      targetRect!,
      Radius.circular(borderRadius),
    );

    // Tüm ekranı kaplayan yoldan hedef alanı çıkar (Cutout)
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(targetRRect);

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, backgroundPaint);

    // Hedef etrafında dinamik neon teal çerçeve (Pulsing Glow)
    final glowPaint = Paint()
      ..color = const Color(0xFF14B8A6).withValues(alpha: 0.35 + (0.35 * pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (1.2 * pulseValue)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + (4 * pulseValue));

    canvas.drawRRect(targetRRect, glowPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF5EEAD4).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawRRect(targetRRect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.pulseValue != pulseValue;
  }
}
