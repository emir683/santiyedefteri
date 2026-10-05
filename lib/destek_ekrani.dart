import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_links.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class DestekEkrani extends StatelessWidget {
  const DestekEkrani({super.key});

  Future<void> _linkAc(BuildContext context, Uri uri) async {
    final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'Destek',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            FloatingLiquidAppBar.topPadding(context, extra: 4),
            20,
            20,
          ),
          children: [
            GlassSectionCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _kBrandTeal.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: _kBrandTeal,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Nasıl yardımcı olabiliriz?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sorun, öneri veya hesap desteği için bize Instagram ya da e-posta üzerinden ulaşabilirsin.',
                    style: TextStyle(fontSize: 15, height: 1.45, color: bodyColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SupportLinkCard(
              icon: Icons.camera_alt_outlined,
              title: 'Instagram',
              subtitle: '@emr.core',
              onTap: () => _linkAc(context, AppLinks.instagram),
            ),
            const SizedBox(height: 12),
            _SupportLinkCard(
              icon: Icons.mail_outline_rounded,
              title: 'E-posta',
              subtitle: 'info@emrcore.com',
              onTap: () => _linkAc(context, AppLinks.supportEmail),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportLinkCard extends StatelessWidget {
  const _SupportLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassSectionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kBrandTeal.withValues(alpha: isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _kBrandTeal),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF102A43),
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new_rounded),
      ),
    );
  }
}
