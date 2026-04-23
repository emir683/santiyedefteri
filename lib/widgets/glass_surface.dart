import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:liquid_glass_widgets/types/glass_quality.dart';
import 'package:liquid_glass_widgets/widgets/containers/glass_card.dart';
import 'package:liquid_glass_widgets/widgets/containers/glass_container.dart';
import 'package:liquid_glass_widgets/widgets/shared/adaptive_liquid_glass_layer.dart';

class GlassPageSurface extends StatelessWidget {
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
                stops: const [0.0, 0.18, 0.52, 1.0],
                colors:
                    isDark
                        ? const [
                          Color(0xFF020304),
                          Color(0xFF06080B),
                          Color(0xFF0A1115),
                          Color(0xFF07090C),
                        ]
                        : (preferSoftLightBackground
                            ? const [
                              Color(0xFFF8FCFE),
                              Color(0xFFF2F8FC),
                              Color(0xFFEAF2F8),
                              Color(0xFFE4EDF5),
                            ]
                            : const [
                              Color(0xFF020304),
                              Color(0xFF12171C),
                              Color(0xFFE7EFF2),
                              Color(0xFFF4FAFC),
                            ]),
              ),
            ),
          ),
        ),
        if (!performanceMode)
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF5EEAD4).withOpacity(
                        isDark
                            ? 0.08
                            : (preferSoftLightBackground ? 0.035 : 0.05),
                      ),
                      const Color(0xFF2DD4BF).withOpacity(
                        isDark
                            ? 0.04
                            : (preferSoftLightBackground ? 0.02 : 0.03),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!performanceMode)
          Positioned(
            left: -40,
            right: -40,
            bottom: -36,
            child: IgnorePointer(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 0.95,
                    colors: [
                      const Color(0xFF5EEAD4).withOpacity(
                        isDark
                            ? 0.10
                            : (preferSoftLightBackground ? 0.09 : 0.14),
                      ),
                      const Color(0xFFB6F5ED).withOpacity(
                        isDark
                            ? 0.05
                            : (preferSoftLightBackground ? 0.055 : 0.08),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: AdaptiveLiquidGlassLayer(
            settings: _layerSettings(isDark, performanceMode),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ],
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
      chromaticAberration: performanceMode ? 0.014 : 0.028,
      glassColor:
          isDark
              ? const Color(0xFF0A0C10).withOpacity(0.20)
              : const Color(0xFFCDD9DD).withOpacity(0.24),
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

    Widget content = GlassCard(
      padding: EdgeInsets.zero,
      quality: lightweight ? GlassQuality.standard : GlassQuality.premium,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? const Color(0xFF15181D) : const Color(0xFFD7E3E7))
                  .withOpacity(isDark ? 0.96 : 0.72),
              (isDark ? const Color(0xFF090B0F) : const Color(0xFFC6D2D7))
                  .withOpacity(isDark ? 0.98 : 0.90),
            ],
          ),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.07)
                    : const Color(0xFFBFD0D6).withOpacity(0.92),
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
              blurRadius: isDark ? 22 : 18,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF79E9D7).withOpacity(isDark ? 0.04 : 0.10),
              blurRadius: isDark ? 18 : 28,
              offset: const Offset(0, 14),
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
            colors: [
              (isDark ? const Color(0xFF171A1F) : const Color(0xFFD6E1E5))
                  .withOpacity(
                isDark ? 0.88 : 0.40,
              ),
              (isDark ? const Color(0xFF0D0F13) : const Color(0xFFC7D2D7))
                  .withOpacity(isDark ? 0.96 : 0.94),
            ],
          ),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFBFD0D6).withOpacity(0.95),
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
              color.withOpacity(isDark ? 0.20 : 0.16),
              (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
                isDark ? 0.82 : 0.94,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(isDark ? 0.16 : 0.12)),
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
      chromaticAberration: 0.028,
      glassColor:
          isDark
              ? const Color(0xFF0A0C10).withOpacity(0.20)
              : const Color(0xFFCDD9DD).withOpacity(0.24),
    );
  }
}
