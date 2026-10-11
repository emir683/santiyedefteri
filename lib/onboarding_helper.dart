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
      barrierColor: Colors.black.withValues(alpha: 0.75),
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
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFB6DDE8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
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
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
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
    await PuanlamaServisi.diyalogGoster(context);
  }
}
