import 'dart:async';
import 'package:flutter/material.dart';

/// Giriş ve kayıt ekranlarında uygulamanın temel yeteneklerini
/// emoji kullanmadan, kurumsal ve modern bir dille tanıtan otomatik kayan vitrin kartı.
class AuthFeatureShowcaseCarousel extends StatefulWidget {
  const AuthFeatureShowcaseCarousel({
    super.key,
    this.height = 68,
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
      description: "Sesli komutla şantiye raporu ve anlık veri analizi",
    ),
    _FeatureItem(
      icon: Icons.badge_outlined,
      accentColor: Color(0xFF0EA5E9),
      tag: "PERSONEL TAKİBİ",
      title: "Hızlı Puantaj ve Mesai",
      description: "İşçi, usta ve taşeron çalışma saatlerini hatasız kaydedin",
    ),
    _FeatureItem(
      icon: Icons.account_balance_wallet_outlined,
      accentColor: Color(0xFF10B981),
      tag: "FİNANSAL DENETİM",
      title: "Maaş ve Hakediş Yönetimi",
      description: "Yevmiye, avans ve aylık maliyetleri anında hesaplayın",
    ),
    _FeatureItem(
      icon: Icons.wb_cloudy_outlined,
      accentColor: Color(0xFF38BDF8),
      tag: "CANLI METEOROLOJİ",
      title: "Şantiye Hava Durumu",
      description: "81 il ve ilçe için anlık hava tahmini ve çalışma şartları",
    ),
    _FeatureItem(
      icon: Icons.description_outlined,
      accentColor: Color(0xFFF59E0B),
      tag: "RESMİ BELGE",
      title: "Günlük Rapor ve PDF Çıktısı",
      description: "Resmi şantiye defteri ve dökümleri tek tıkla paylaşın",
    ),
    _FeatureItem(
      icon: Icons.hub_outlined,
      accentColor: Color(0xFF8B5CF6),
      tag: "MERKEZİ YÖNETİM",
      title: "Çoklu Şantiye & Ekip Koordinasyonu",
      description: "Tüm projelerinizi ve yetkili ekipleri tek merkezden yönetin",
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
            alpha: isDark ? 0.32 : 0.24,
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
        child: Stack(
          children: [
            // PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final item = _features[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Sol ikon rozeti (Liquid Glass efekti)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                          size: 20,
                          color: item.accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Metin Alanı
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.accentColor.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.tag,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.accentColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF10232C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2.5),
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
                      // Mikro Nokta Göstergeleri (Kompakt dikey / yatay gösterge)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_features.length, (dotIndex) {
                              final isSelected = dotIndex == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                width: isSelected ? 10 : 3.5,
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
          ],
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
    this.size = 52,
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.25 : 0.18),
            (isDark ? const Color(0xFF151A22) : Colors.white).withValues(
              alpha: isDark ? 0.94 : 0.98,
            ),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24B7A4).withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
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
