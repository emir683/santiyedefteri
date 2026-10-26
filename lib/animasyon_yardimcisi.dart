import 'package:flutter/material.dart';
import 'format_yardimcisi.dart';

// ============================================
// 1. SAYFA GEÇİŞ ANİMASYONU
// ============================================

import 'package:flutter/cupertino.dart';

/// iOS yerel geri kaydırma (interactive swipe-back) hareketini destekleyen sayfa geçişi
class SayfaGecisi<T> extends CupertinoPageRoute<T> {
  final Widget sayfa;

  SayfaGecisi({required this.sayfa})
    : super(builder: (context) => sayfa);
}

// ============================================
// 2. DİALOG ANİMASYONU (Scale-up + Fade)
// ============================================

class AnimasyonluDialog {
  /// Scale-up efektli dialog gösterir
  static Future<T?> goster<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => builder(ctx),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnimation = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}

// ============================================
// 3. BUTON BOUNCE EFEKTİ
// ============================================

class AnimasyonluButon extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;

  const AnimasyonluButon({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleFactor = 0.95,
  });

  @override
  State<AnimasyonluButon> createState() => _AnimasyonluButonState();
}

class _AnimasyonluButonState extends State<AnimasyonluButon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse().then((_) {
      widget.onPressed?.call();
    });
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================
// 4. SAYI SAYMA ANİMASYONU
// ============================================

class SayiSayici extends StatefulWidget {
  final double hedefDeger;
  final TextStyle? style;
  final Duration sure;
  final String onEk;
  final String sonEk;

  const SayiSayici({
    super.key,
    required this.hedefDeger,
    this.style,
    this.sure = const Duration(milliseconds: 1200),
    this.onEk = '',
    this.sonEk = '',
  });

  @override
  State<SayiSayici> createState() => _SayiSayiciState();
}

class _SayiSayiciState extends State<SayiSayici>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oncekiDeger = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.sure);
    _animation = Tween<double>(
      begin: 0,
      end: widget.hedefDeger,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(SayiSayici oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hedefDeger != widget.hedefDeger) {
      _oncekiDeger = oldWidget.hedefDeger;
      _animation = Tween<double>(
        begin: _oncekiDeger,
        end: widget.hedefDeger,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.onEk}${Formatlayici.yap(_animation.value)}${widget.sonEk}',
          style: widget.style,
        );
      },
    );
  }
}

// ============================================
// 5. SHİMMER LOADING EFEKTİ
// ============================================

class ShimmerYukleniyor extends StatefulWidget {
  final int satirSayisi;
  final bool kartGorunumu;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  const ShimmerYukleniyor({
    super.key,
    this.satirSayisi = 5,
    this.kartGorunumu = false,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  State<ShimmerYukleniyor> createState() => _ShimmerYukleniyorState();
}

class _ShimmerYukleniyorState extends State<ShimmerYukleniyor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final children = List.generate(
      widget.kartGorunumu ? 3 : widget.satirSayisi,
      (i) => Padding(
        padding: EdgeInsets.only(bottom: widget.kartGorunumu ? 16 : 12),
        child: widget.kartGorunumu
            ? _buildShimmerKart(isDark)
            : _buildShimmerSatir(isDark),
      ),
    );

    if (widget.shrinkWrap) {
      return Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: children,
      ),
    );
  }

  Widget _buildShimmerKart(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _controller.value, 0),
              end: Alignment(-0.5 + 2 * _controller.value, 0),
              colors:
                  isDark
                      ? [
                        const Color(0xFF1C1C1E),
                        const Color(0xFF2C2C2E),
                        const Color(0xFF1C1C1E),
                      ]
                      : [
                        Colors.grey[300]!,
                        Colors.grey[100]!,
                        Colors.grey[300]!,
                      ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerSatir(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          children: [
            // Avatar placeholder
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2 * _controller.value, 0),
                  end: Alignment(-0.5 + 2 * _controller.value, 0),
                  colors:
                      isDark
                          ? [
                            const Color(0xFF1C1C1E),
                            const Color(0xFF2C2C2E),
                            const Color(0xFF1C1C1E),
                          ]
                          : [
                            Colors.grey[300]!,
                            Colors.grey[100]!,
                            Colors.grey[300]!,
                          ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + 2 * _controller.value, 0),
                        end: Alignment(-0.5 + 2 * _controller.value, 0),
                        colors:
                            isDark
                                ? [
                                  const Color(0xFF1C1C1E),
                                  const Color(0xFF2C2C2E),
                                  const Color(0xFF1C1C1E),
                                ]
                                : [
                                  Colors.grey[300]!,
                                  Colors.grey[100]!,
                                  Colors.grey[300]!,
                                ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + 2 * _controller.value, 0),
                        end: Alignment(-0.5 + 2 * _controller.value, 0),
                        colors:
                            isDark
                                ? [
                                  const Color(0xFF1C1C1E),
                                  const Color(0xFF2C2C2E),
                                  const Color(0xFF1C1C1E),
                                ]
                                : [
                                  Colors.grey[300]!,
                                  Colors.grey[100]!,
                                  Colors.grey[300]!,
                                ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
