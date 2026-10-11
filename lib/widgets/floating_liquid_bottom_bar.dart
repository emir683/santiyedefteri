import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../performance_provider.dart';

class FloatingLiquidBottomBar extends StatelessWidget {
  const FloatingLiquidBottomBar({
    super.key,
    required this.selectedIndex,
    required this.finansalErisim,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool finansalErisim;
  final ValueChanged<int> onSelected;

  static const List<int> _visualToPageIndex = [1, 2, 0, 3, 4];
  static const List<int> _pageToVisualIndex = [2, 0, 1, 3, 4];
  static const Duration _slideDuration = Duration(milliseconds: 320);
  static const Duration _itemDuration = Duration(milliseconds: 260);
  static const Curve _slideCurve = Curves.easeOutCubic;
  static const Curve _itemCurve = Curves.easeOutQuart;
  static const GlassQuality _barQuality = GlassQuality.standard;
  static const LiquidGlassSettings _darkBarSettings = LiquidGlassSettings(
    thickness: 28,
    blur: 7,
    refractiveIndex: 1.12,
    lightIntensity: 1.18,
    ambientStrength: 0.34,
    saturation: 1.0,
    chromaticAberration: 0.016,
  );
  static const LiquidGlassSettings _lightBarSettings = LiquidGlassSettings(
    thickness: 24,
    blur: 6,
    refractiveIndex: 1.10,
    lightIntensity: 0.96,
    ambientStrength: 0.28,
    saturation: 1.0,
    chromaticAberration: 0.012,
  );
  static const LiquidGlassSettings _darkCapSettings = LiquidGlassSettings(
    thickness: 22,
    blur: 6,
    refractiveIndex: 1.10,
    lightIntensity: 1.08,
    ambientStrength: 0.30,
    saturation: 1.0,
    chromaticAberration: 0.014,
  );
  static const LiquidGlassSettings _lightCapSettings = LiquidGlassSettings(
    thickness: 18,
    blur: 5,
    refractiveIndex: 1.08,
    lightIntensity: 0.92,
    ambientStrength: 0.24,
    saturation: 1.0,
    chromaticAberration: 0.010,
  );
  static const LiquidGlassSettings _darkBubbleSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 8,
    refractiveIndex: 1.12,
    lightIntensity: 1.24,
    ambientStrength: 0.34,
    saturation: 1.02,
    chromaticAberration: 0.018,
  );
  static const LiquidGlassSettings _lightBubbleSettings = LiquidGlassSettings(
    thickness: 24,
    blur: 7,
    refractiveIndex: 1.10,
    lightIntensity: 1.0,
    ambientStrength: 0.28,
    saturation: 1.01,
    chromaticAberration: 0.014,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPerf = PerformanceProvider.of(context);
    final visualIndex = _pageToVisualIndex[selectedIndex];
    final items = _buildItems(finansalErisim);

    Widget barContent = SizedBox(
      height: 84,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;
          final bubbleCenterX = itemWidth * (visualIndex + 0.5);

          final navRow = Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Expanded(
                child: _BarItem(
                  data: item,
                  isSelected: index == visualIndex,
                  onTap: () => onSelected(_visualToPageIndex[index]),
                ),
              );
            }),
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 18,
                child: isPerf
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141A22) : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFD0DDE3),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: navRow,
                      )
                    : GlassContainer(
                        quality: _barQuality,
                        clipBehavior: Clip.antiAlias,
                        shape: const LiquidRoundedSuperellipse(borderRadius: 28),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: navRow,
                      ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: bubbleCenterX),
                duration: _slideDuration,
                curve: _slideCurve,
                builder: (context, animatedX, _) {
                  return Positioned(
                    left: animatedX - 29,
                    top: 0,
                    child: _SelectedProtrusion(
                      key: ValueKey<int>(visualIndex),
                      data: items[visualIndex],
                      isDark: isDark,
                      onTap: () => onSelected(_visualToPageIndex[visualIndex]),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: RepaintBoundary(
        child: isPerf
            ? barContent
            : AdaptiveLiquidGlassLayer(
                quality: _barQuality,
                blendAmount: 6,
                settings: _barLayerSettings(isDark),
                shape: const LiquidRoundedSuperellipse(borderRadius: 28),
                child: barContent,
              ),
      ),
    );
  }

  List<_NavItemData> _buildItems(bool finansalErisim) {
    return [
      const _NavItemData(
        label: 'Şantiye',
        icon: Icons.home_work_outlined,
        selectedIcon: Icons.home_work_rounded,
        color: Color(0xFF0F766E),
      ),
      const _NavItemData(
        label: 'İşçi',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
        color: Color(0xFF2563EB),
      ),
      const _NavItemData(
        label: 'Merkez',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        color: Color(0xFF14B8A6),
      ),
      _NavItemData(
        label: 'Ay Sonu',
        icon:
            finansalErisim
                ? Icons.assessment_outlined
                : Icons.lock_outline_rounded,
        selectedIcon:
            finansalErisim
                ? Icons.assessment_rounded
                : Icons.lock_outline_rounded,
        color:
            finansalErisim ? const Color(0xFFF59E0B) : Colors.grey.shade500,
      ),
      _NavItemData(
        label: 'Ödeme',
        icon:
            finansalErisim
                ? Icons.receipt_long_outlined
                : Icons.lock_outline_rounded,
        selectedIcon:
            finansalErisim
                ? Icons.receipt_long_rounded
                : Icons.lock_outline_rounded,
        color:
            finansalErisim ? const Color(0xFF8B5CF6) : Colors.grey.shade500,
      ),
    ];
  }

  LiquidGlassSettings _barLayerSettings(bool isDark) {
    return isDark ? _darkBarSettings : _lightBarSettings;
  }

  static LiquidGlassSettings capSettings(bool isDark) {
    return isDark ? _darkCapSettings : _lightCapSettings;
  }

  static LiquidGlassSettings bubbleSettings(bool isDark) {
    return isDark ? _darkBubbleSettings : _lightBubbleSettings;
  }
}

class _BarItem extends StatelessWidget {
  static const double _iconSize = 18.5;

  const _BarItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white70 : const Color(0xFF365965);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: isSelected ? 1 : 0),
        duration: FloatingLiquidBottomBar._itemDuration,
        curve: FloatingLiquidBottomBar._itemCurve,
        builder: (context, value, child) {
          final iconColor = Color.lerp(baseColor, data.color, value)!;
          final textColor = Color.lerp(baseColor, data.color, value)!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _iconSize,
                  height: _iconSize,
                  child:
                      isSelected
                          ? null
                          : AnimatedScale(
                            scale: 1.0 + (value * 0.05),
                            duration: FloatingLiquidBottomBar._itemDuration,
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              data.icon,
                              size: _iconSize,
                              color: iconColor,
                            ),
                          ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectedProtrusion extends StatelessWidget {
  const _SelectedProtrusion({
    super.key,
    required this.data,
    required this.isDark,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glowColor = data.color.withValues(alpha: isDark ? 0.18 : 0.12);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1.0),
      duration: FloatingLiquidBottomBar._itemDuration,
      curve: FloatingLiquidBottomBar._itemCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                child: GlassContainer(
                  quality: FloatingLiquidBottomBar._barQuality,
                  clipBehavior: Clip.antiAlias,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                  width: 36,
                  height: 18,
                  settings: FloatingLiquidBottomBar.capSettings(isDark),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 16,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: GlassButton.custom(
                  onTap: onTap,
                  width: 58,
                  height: 58,
                  quality: FloatingLiquidBottomBar._barQuality,
                  interactionScale: 1.02,
                  glowRadius: 0.6,
                  glowColor: glowColor,
                  shape: const LiquidOval(),
                  settings: FloatingLiquidBottomBar.bubbleSettings(isDark),
                  child: Icon(data.selectedIcon, size: 24, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
}
