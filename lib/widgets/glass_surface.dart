import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/types/glass_quality.dart';
import 'package:liquid_glass_widgets/widgets/containers/glass_card.dart';
import 'package:liquid_glass_widgets/widgets/containers/glass_container.dart';
import 'package:liquid_glass_widgets/widgets/shared/adaptive_liquid_glass_layer.dart';
import '../performance_provider.dart';
import '../tema_ayarlari.dart';

class GlassPageSurface extends StatefulWidget {
  const GlassPageSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.preferSoftLightBackground = false,
    this.performanceMode = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool preferSoftLightBackground;
  final bool performanceMode;

  @override
  State<GlassPageSurface> createState() => _GlassPageSurfaceState();
}

class _GlassPageSurfaceState extends State<GlassPageSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (!widget.performanceMode) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPerf = widget.performanceMode || PerformanceProvider.of(context);
    if (isPerf) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPerf = widget.performanceMode || PerformanceProvider.of(context);

    if (isPerf) {
      return Container(
        color: isDark ? const Color(0xFF000000) : const Color(0xFFF1F5F8),
        padding: widget.padding,
        child: widget.child,
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Color glowCol = themeProvider.glowColor;
    final Color secCol = themeProvider.secondaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final angle = t * 2 * math.pi;

        // Ekranın çevresinde (kenar ve köşelerde) kesintisiz dönen koordinatlar
        final double x1 = math.cos(angle) * 1.30;
        final double y1 = math.sin(angle) * 1.15;

        final double x2 = math.cos(angle + math.pi * 0.85) * 1.20;
        final double y2 = math.sin(angle + math.pi * 0.85) * 1.10;

        return Stack(
          children: [
            // 1. Zemin taban rengi (Karanlık modda saf simsiyah)
            Positioned.fill(
              child: ColoredBox(
                color: isDark
                    ? const Color(0xFF000000)
                    : (widget.preferSoftLightBackground
                        ? const Color(0xFFF8FCFE)
                        : const Color(0xFFF1F6F8)),
              ),
            ),

            // 2. Ana yeşil gradyan - Ekranın çevresinde yumuşakça döner
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(x1, y1),
                      radius: 1.35,
                      colors: [
                        glowCol.withValues(
                          alpha: isDark ? 0.22 : 0.16,
                        ),
                        glowCol.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 3. İkincil yumuşak aura gradyanı - Karşı çevreden eşlik eder
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(x2, y2),
                      radius: 1.20,
                      colors: [
                        secCol.withValues(
                          alpha: isDark ? 0.14 : 0.10,
                        ),
                        secCol.withValues(
                          alpha: isDark ? 0.04 : 0.03,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Ön plan içeriği
            Positioned.fill(
              child: AdaptiveLiquidGlassLayer(
                settings: _layerSettings(isDark, widget.performanceMode),
                child: Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  LiquidGlassSettings _layerSettings(bool isDark, bool performanceMode) {
    return LiquidGlassSettings(
      thickness: performanceMode ? (isDark ? 24 : 20) : (isDark ? 34 : 28),
      blur: performanceMode ? (isDark ? 8 : 7) : (isDark ? 12 : 10),
      refractiveIndex: 1.14,
      lightIntensity: performanceMode ? (isDark ? 1.15 : 0.98) : (isDark ? 1.35 : 1.05),
      ambientStrength: 0.42,
      saturation: 1.02,
      chromaticAberration: 0.0,
      glassColor:
          isDark
              ? const Color(0xFF0A0C10).withValues(alpha: 0.20)
              : const Color(0xFFCDD9DD).withValues(alpha: 0.24),
    );
  }
}

class GlassSectionCard extends StatelessWidget {
  const GlassSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.onTap,
    this.lightweight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool lightweight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPerf = lightweight || PerformanceProvider.of(context);

    if (isPerf) {
      Widget content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.cardGradient(isDark),
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppTheme.cardBorder(isDark),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      );

      if (onTap != null) {
        content = InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        );
      }

      return content;
    }

    final decoratedBox = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.cardGradient(isDark),
          ),
          border: Border.all(
            color: AppTheme.cardBorder(isDark),
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
              blurRadius: isDark ? 22 : 18,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppTheme.glow(context).withValues(alpha: isDark ? 0.04 : 0.10),
              blurRadius: isDark ? 18 : 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      );

    Widget content = lightweight
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: decoratedBox,
          )
        : GlassCard(
            padding: EdgeInsets.zero,
            quality: GlassQuality.standard,
            clipBehavior: Clip.antiAlias,
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
            child: decoratedBox,
          );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }
}

class GlassInsetSurface extends StatelessWidget {
  const GlassInsetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPerf = PerformanceProvider.of(context);

    if (isPerf) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.cardInsetGradient(isDark),
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: AppTheme.cardInsetBorder(isDark),
          ),
        ),
        child: child,
      );
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      quality: GlassQuality.premium,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.cardInsetGradient(isDark),
          ),
          border: Border.all(
            color: AppTheme.cardInsetBorder(isDark),
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class GlassIconBadge extends StatelessWidget {
  const GlassIconBadge({
    super.key,
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
    final isPerf = PerformanceProvider.of(context);

    if (isPerf) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.20 : 0.14)),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : color,
          size: iconSize,
        ),
      );
    }

    return GlassContainer(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      quality: GlassQuality.premium,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.20 : 0.16),
              (isDark ? const Color(0xFF171B20) : Colors.white).withValues(alpha: 
                isDark ? 0.82 : 0.94,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.16 : 0.12)),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : color,
          size: iconSize,
        ),
      ),
    );
  }
}

class GlassDialogFrame extends StatelessWidget {
  const GlassDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 460,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AdaptiveLiquidGlassLayer(
            settings: _dialogLayerSettings(isDark),
            child: GlassSectionCard(
              borderRadius: 26,
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  LiquidGlassSettings _dialogLayerSettings(bool isDark) {
    return LiquidGlassSettings(
      thickness: isDark ? 34 : 28,
      blur: isDark ? 12 : 10,
      refractiveIndex: 1.14,
      lightIntensity: isDark ? 1.35 : 1.05,
      ambientStrength: 0.42,
      saturation: 1.02,
      chromaticAberration: 0.0,
      glassColor:
          isDark
              ? const Color(0xFF0A0C10).withValues(alpha: 0.20)
              : const Color(0xFFCDD9DD).withValues(alpha: 0.24),
    );
  }
}
