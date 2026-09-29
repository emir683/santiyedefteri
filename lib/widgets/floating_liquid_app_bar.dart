import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../privacy_provider.dart';

void openAppDrawer(BuildContext context) {
  ScaffoldState? state;
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is ScaffoldState) {
      final s = element.state as ScaffoldState;
      if (s.hasDrawer) {
        state = s;
        return false;
      }
    }
    return true;
  });
  if (state != null) {
    state!.openDrawer();
  } else {
    Scaffold.maybeOf(context)?.openDrawer();
  }
}

class FloatingLiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FloatingLiquidAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.showHamburger,
    this.showPrivacyButton = true,
    this.showTourButton = false,
    this.onTourPressed,
    this.actions,
    this.bottom,
    this.centerTitle = true,
    this.borderRadius = 24.0,
    this.onMenuPressed,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final bool? showHamburger;
  final bool showPrivacyButton;
  final bool showTourButton;
  final VoidCallback? onTourPressed;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final double borderRadius;
  final VoidCallback? onMenuPressed;

  static const double toolbarHeight = 52.0;
  static const double topMargin = 6.0;
  static const double bottomMargin = 4.0;
  static const double horizontalMargin = 16.0;

  static const LiquidGlassSettings _darkSettings = LiquidGlassSettings(
    thickness: 24,
    blur: 7,
    refractiveIndex: 1.12,
    lightIntensity: 1.18,
    ambientStrength: 0.34,
    saturation: 1.0,
    chromaticAberration: 0.014,
  );

  static const LiquidGlassSettings _lightSettings = LiquidGlassSettings(
    thickness: 20,
    blur: 6,
    refractiveIndex: 1.10,
    lightIntensity: 0.96,
    ambientStrength: 0.28,
    saturation: 1.0,
    chromaticAberration: 0.010,
  );

  static double topPadding(
    BuildContext context, {
    bool hasBottom = false,
    double bottomHeight = 72.0,
    double extra = 2.0,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    final barHeight = toolbarHeight + (hasBottom ? bottomHeight : 0.0);
    // If Scaffold with extendBodyBehindAppBar is used, MediaQuery.paddingOf(context).top
    // already includes the status bar AND the AppBar height. Adding barHeight again
    // would double the gap!
    if (top >= barHeight) {
      return top + extra;
    }
    return top + topMargin + barHeight + extra;
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(toolbarHeight + bottomHeight + topMargin + bottomMargin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowHamburger = showHamburger ?? !canPop;

    final textColor = isDark ? Colors.white : const Color(0xFF102A43);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.65);
    final glassTint = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.12);

    Widget effectiveLeading;
    if (leading != null) {
      effectiveLeading = leading!;
    } else if (shouldShowHamburger) {
      effectiveLeading = _AppBarIconButton(
        icon: Icons.menu_rounded,
        tooltip: 'Menü',
        onPressed: onMenuPressed ?? () => openAppDrawer(context),
      );
    } else if (canPop) {
      effectiveLeading = _AppBarIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        size: 19,
        tooltip: 'Geri',
        onPressed: () => Navigator.maybePop(context),
      );
    } else {
      effectiveLeading = const SizedBox(width: 40);
    }

    final effectiveActions = <Widget>[
      if (actions != null) ...actions!,
      if (showTourButton && onTourPressed != null)
        _AppBarIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Sayfa Rehberi',
          onPressed: onTourPressed,
        ),
      if (showPrivacyButton)
        Consumer<PrivacyProvider>(
          builder: (context, privacy, _) {
            return _AppBarIconButton(
              icon: privacy.isHidden
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              tooltip: privacy.isHidden ? 'Gizliliği Kaldır' : 'Gizle',
              onPressed: () => privacy.togglePrivacy(),
            );
          },
        ),
    ];

    Widget titleRow = SizedBox(
      height: toolbarHeight - 8,
      child: Row(
        children: [
          effectiveLeading,
          const SizedBox(width: 4),
          Expanded(
            child: titleWidget ??
                Text(
                  title ?? '',
                  textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
          ),
          const SizedBox(width: 4),
          if (effectiveActions.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: effectiveActions,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );

    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        top + topMargin,
        horizontalMargin,
        bottomMargin,
      ),
      child: RepaintBoundary(
        child: AdaptiveLiquidGlassLayer(
          quality: GlassQuality.standard,
          blendAmount: 6,
          settings: isDark ? _darkSettings : _lightSettings,
          shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: GlassContainer(
                quality: GlassQuality.standard,
                clipBehavior: Clip.antiAlias,
                shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
                padding: EdgeInsets.zero,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: glassTint,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: borderColor,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF5EEAD4).withValues(alpha: isDark ? 0.05 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: bottom == null
                        ? titleRow
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              titleRow,
                              bottom!,
                            ],
                          ),
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

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  const _AppBarIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : const Color(0xFF102A43);

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: defaultColor,
            size: size,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
