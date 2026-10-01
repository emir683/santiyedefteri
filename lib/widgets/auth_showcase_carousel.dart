import 'dart:async';
import 'package:flutter/material.dart';

/// Giriş ve kayıt ekranlarında uygulamanın temel yeteneklerini
/// emoji kullanmadan, az ve öz, kurumsal bir dille tanıtan kompakt vitrin kartı.
class AuthFeatureShowcaseCarousel extends StatefulWidget {
  const AuthFeatureShowcaseCarousel({
    super.key,
    this.height = 60,
    this.autoSlideDuration = const Duration(milliseconds: 3800),
  });

  final double height;
  final Duration autoSlideDuration;

  @override
  State<AuthFeatureShowcaseCarousel> createState() =>
      _AuthFeatureShowcaseCarouselState();
}

class _AuthFeatureShowcaseCarouselState
    extends State<AuthFeatureShowcaseCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  static const List<_FeatureItem> _features = [
    _FeatureItem(
      icon: Icons.smart_toy_outlined,
      accentColor: Color(0xFF24B7A4),
      title: "Akıllı Şantiye Asistanı",
      description: "Sesli komutla anlık rapor ve analiz",
    ),
    _FeatureItem(
      icon: Icons.badge_outlined,
      accentColor: Color(0xFF0EA5E9),
      title: "Hızlı Puantaj Takibi",
      description: "İşçi ve usta mesailerini kolayca yönetin",
    ),
    _FeatureItem(
      icon: Icons.account_balance_wallet_outlined,
      accentColor: Color(0xFF10B981),
      title: "Maaş ve Hakediş",
      description: "Yevmiye ve maliyetleri anında hesaplayın",
    ),
    _FeatureItem(
      icon: Icons.wb_cloudy_outlined,
      accentColor: Color(0xFF38BDF8),
      title: "Şantiye Hava Durumu",
      description: "81 il ve ilçe için canlı meteoroloji",
    ),
    _FeatureItem(
      icon: Icons.description_outlined,
      accentColor: Color(0xFFF59E0B),
      title: "Günlük Rapor & PDF",
      description: "Şantiye defterini tek tıkla paylaşın",
    ),
    _FeatureItem(
      icon: Icons.hub_outlined,
      accentColor: Color(0xFF8B5CF6),
      title: "Merkezi Ekip Yönetimi",
      description: "Tüm projelerinizi tek merkezden koordine edin",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoSlideDuration, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _features.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentItem = _features[_currentPage];

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF141920).withValues(alpha: 0.90),
                  const Color(0xFF0C1015).withValues(alpha: 0.95),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  const Color(0xFFEFF5F8).withValues(alpha: 0.96),
                ],
        ),
        border: Border.all(
          color: currentItem.accentColor.withValues(
            alpha: isDark ? 0.35 : 0.28,
          ),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: currentItem.accentColor.withValues(
              alpha: isDark ? 0.08 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemCount: _features.length,
          itemBuilder: (context, index) {
            final item = _features[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sol ikon rozeti (Kompakt Liquid Glass)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          item.accentColor.withValues(
                            alpha: isDark ? 0.28 : 0.20,
                          ),
                          (isDark ? const Color(0xFF181E26) : Colors.white)
                              .withValues(alpha: isDark ? 0.85 : 0.95),
                        ],
                      ),
                      border: Border.all(
                        color: item.accentColor.withValues(
                          alpha: isDark ? 0.45 : 0.35,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: item.accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Az ama öz metin alanı (Taşma yapmayan tek satırlı net hiyerarşi)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF10232C),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF5A707B),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sağda şık sayfa sayacı etiketi (Örn: 1/6)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: item.accentColor.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${index + 1}/${_features.length}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: item.accentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Uygulamanın gerçek kurumsal logosunu (`assets/logo.png`)
/// şık bir sıvı cam (Liquid Glass) rozet içinde sunan widget.
class AuthLogoBadge extends StatelessWidget {
  const AuthLogoBadge({
    super.key,
    this.size = 60,
    this.fallbackIcon = Icons.construction_rounded,
  });

  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.28 : 0.20),
            (isDark ? const Color(0xFF151A22) : Colors.white).withValues(
              alpha: isDark ? 0.94 : 0.98,
            ),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.38 : 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            fallbackIcon,
            color: const Color(0xFF24B7A4),
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
  });
}
