import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fcm_servisi.dart';
import 'glass_surface.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class BildirimOnboardingDialog extends StatelessWidget {
  const BildirimOnboardingDialog({super.key});

  static Future<void> kontrolEtVeGoster(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool gosterildi = prefs.getBool('bildirim_onboarding_gosterildi') ?? false;
    if (gosterildi) return;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      await prefs.setBool('bildirim_onboarding_gosterildi', true);
      return;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BildirimOnboardingDialog(),
    );
  }

  Future<void> _izinVer(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bildirim_onboarding_gosterildi', true);

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    final status = await Permission.notification.request();
    if (status.isGranted) {
      await FcmServisi().kullaniciBagla();
    }
  }

  Future<void> _dahaSonra(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bildirim_onboarding_gosterildi', true);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassSectionCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // İkon Rozeti
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _kBrandTeal.withValues(alpha: 0.25),
                      _kBrandTeal.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: _kBrandTeal.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: _kBrandTeal,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Başlık
            Text(
              'Bildirimleri Etkinleştirin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF102A43),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Açıklama
            Text(
              'Şantiye sahasını ve çizimlerinizi anlık takip edebilmek için bildirimlere izin verin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white70 : const Color(0xFF486581),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Maddeler
            _buildFeatureRow(
              isDark: isDark,
              icon: Icons.architecture_rounded,
              color: const Color(0xFF00F0FF),
              title: 'CAD Çizim Bildirimleri',
              subtitle: 'Büyük DWG dosyaları hazır olduğunda anında açın.',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              isDark: isDark,
              icon: Icons.edit_calendar_rounded,
              color: const Color(0xFF10B981),
              title: 'Akıllı Puantaj Hatırlatması',
              subtitle: 'Gününüzü kaydetmeyi unuttuğunuzda akşam uyarılırsınız.',
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              isDark: isDark,
              icon: Icons.cloud_sync_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Ekip ve Saha Uyarıları',
              subtitle: 'Yeni üye, rol atamaları ve hava durumu uyarıları.',
            ),
            const SizedBox(height: 26),

            // Aksiyon Butonları
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [_kBrandTeal, Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kBrandTeal.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _izinVer(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Bildirimleri Aç',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _dahaSonra(context),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white60 : const Color(0xFF627D98),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Daha Sonra',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : const Color(0xFF627D98),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
