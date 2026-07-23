import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'puanlama_servisi.dart';

class OnboardingHelper {
  static Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('show_onboarding_after_reg') ?? false) {
      await prefs.setBool('show_onboarding_after_reg', false);
      if (context.mounted) {
        await bildirimOnboardingGoster(context);
        if (context.mounted) {
          await puanlamaOnboardingGoster(context);
        }
      }
    }
  }

  static Future<void> bildirimOnboardingGoster(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'bildirim_onboarding',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF151B24), Color(0xFF0D1117)]
                    : const [Color(0xFFFFFFFF), Color(0xFFF0F7FA)],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : const Color(0xFFB6DDE8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0F7C86)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Bildirimlerden Haberdar Ol',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ekibindeki işlemler, avans ve rapor girdiğinde anında bildirim al. Uygulama kapalıyken de çalışır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: isDark ? Colors.white60 : const Color(0xFF526772),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._bildirimOzellikleri(isDark),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.notifications_active_rounded, size: 18),
                      label: const Text(
                        'Bildirimleri Aç',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Daha sonra',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
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

  static List<Widget> _bildirimOzellikleri(bool isDark) {
    final ozellikler = [
      ('👷 İşçi işlemleri', 'Ekleme, güncelleme ve ödeme bildirimleri'),
      ('📄 Rapor girilince', 'Günlük rapor kaydedilince haberdar ol'),
      ('⏰ Kapalıyken de çalışır', 'Uygulamanı açman gerekmez'),
    ];
    return [
      const SizedBox(height: 16),
      ...ozellikler.map(
        (o) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o.$1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F7C86),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF526772),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  static Future<void> puanlamaOnboardingGoster(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int seciliPuan = 0;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'puanlama_onboarding',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF151B24), Color(0xFF0D1117)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF0F7FA)],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFFB6DDE8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rate_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Uygulamayı Puanla',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Şantiye Puantaj Defteri size yardımcı oluyor mu? Bize 5 yıldız vererek destek olabilirsiniz!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: isDark ? Colors.white60 : const Color(0xFF526772),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isHighlighted = starIndex <= seciliPuan;
                          return IconButton(
                            icon: Icon(
                              isHighlighted ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isHighlighted ? const Color(0xFFFFB300) : (isDark ? Colors.white24 : Colors.grey[400]),
                              size: 42,
                            ),
                            onPressed: () {
                              setState(() {
                                seciliPuan = starIndex;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: seciliPuan == 0
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  if (seciliPuan >= 4) {
                                    await PuanlamaServisi.markRated();
                                    await PuanlamaServisi.openStore();
                                  } else {
                                    await PuanlamaServisi.remindLater();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Geri bildiriminiz için teşekkürler!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB300),
                            disabledBackgroundColor: (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Gönder',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: seciliPuan == 0 ? (isDark ? Colors.white30 : Colors.black26) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await PuanlamaServisi.remindLater();
                        },
                        child: Text(
                          'Daha sonra',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
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
      },
    );
  }
}
