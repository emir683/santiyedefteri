import 'dart:async';
import 'package:flutter/material.dart';

/// Giriş ve kayıt ekranlarında uygulamanın temel yeteneklerini
/// emoji kullanmadan, kurumsal ve modern bir dille tanıtan otomatik kayan vitrin kartı.
class AuthFeatureShowcaseCarousel extends StatefulWidget {
  const AuthFeatureShowcaseCarousel({
    super.key,
    this.height = 92,
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
      tag: "YAPAY ZEKA",
      title: "Akıllı Şantiye Asistanı",
      description: "Sesli komut ile anlık şantiye raporu ve akıllı veri analizi.",
    ),
    _FeatureItem(
      icon: Icons.badge_outlined,
      accentColor: Color(0xFF0EA5E9),
      tag: "PUANTAJ",
      title: "Hızlı Puantaj ve Mesai",
      description: "İşçi, usta ve taşeron çalışma saatlerini hatasız kaydedin.",
    ),
    _FeatureItem(
      icon: Icons.account_balance_wallet_outlined,
      accentColor: Color(0xFF10B981),
      tag: "FİNANS",
      title: "Maaş ve Hakediş Yönetimi",
      description: "Yevmiye, avans ve aylık maliyetleri anında hesaplayın.",
    ),
    _FeatureItem(
      icon: Icons.wb_cloudy_outlined,
      accentColor: Color(0xFF38BDF8),
      tag: "HAVA DURUMU",
      title: "Canlı Şantiye Meteorolojisi",
      description: "81 il ve ilçe için canlı hava tahmini ve saha şartları.",
    ),
    _FeatureItem(
      icon: Icons.description_outlined,
      accentColor: Color(0xFFF59E0B),
      tag: "RAPORLAMA",
      title: "Günlük Rapor ve PDF Çıktısı",
      description: "Resmi şantiye defteri ve dökümleri tek tıkla paylaşın.",
    ),
    _FeatureItem(
      icon: Icons.hub_outlined,
      accentColor: Color(0xFF8B5CF6),
      tag: "YÖNETİM",
      title: "Çoklu Şantiye & Ekip Takibi",
      description: "Tüm projelerinizi ve yetkili ekipleri tek merkezden yönetin.",
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
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemCount: _features.length,
          itemBuilder: (context, index) {
            final item = _features[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Üst Satır: İkon Rozeti + Başlık + Kategori Rozeti
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
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
                          size: 16,
                          color: item.accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF10232C),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(
                            alpha: isDark ? 0.20 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.tag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: item.accentColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // Alt Satır: 2 satırlı tam okunaklı açıklama ve sağda mikro nokta göstergesi
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF526772),
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_features.length, (dotIndex) {
                          final isSelected = dotIndex == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: isSelected ? 12 : 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? item.accentColor
                                  : (isDark
                                      ? Colors.white24
                                      : const Color(0xFFC0D2D7)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ],
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
    this.size = 64,
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
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.24 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
  final String tag;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.accentColor,
    required this.tag,
    required this.title,
    required this.description,
  });
}
