import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_links.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class HakkindaEkrani extends StatefulWidget {
  const HakkindaEkrani({super.key});

  @override
  State<HakkindaEkrani> createState() => _HakkindaEkraniState();
}

class _HakkindaEkraniState extends State<HakkindaEkrani> {
  String _version = 'Yükleniyor...';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    }
  }

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
    final textColor = isDark ? Colors.white : const Color(0xFF102A43);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF526772);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'Hakkında',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        performanceMode: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            FloatingLiquidAppBar.topPadding(context, extra: 4),
            20,
            24,
          ),
          children: [
            // 1. Logo ve Başlık
            GlassSectionCard(
              lightweight: true,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: _kBrandTeal.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      size: 44,
                      color: _kBrandTeal,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Şantiye Puantaj Defteri',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profesyonel saha yönetimi ve puantaj takibi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: subTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Bilgiler (Versiyon, Geliştirici, İletişim)
            GlassSectionCard(
              lightweight: true,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  _InfoRow(label: 'Versiyon', value: _version),
                  Divider(height: 1, color: dividerColor),
                  const _InfoRow(label: 'Geliştirici', value: 'Emir Çiftçi'),
                  Divider(height: 1, color: dividerColor),
                  const _InfoRow(label: 'İletişim', value: 'info@emrcore.com'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Bağlantılar (Tek kart altında derli toplu)
            GlassSectionCard(
              lightweight: true,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Gizlilik Politikası',
                    subtitle: 'Verilerin nasıl işlendiğini görüntüle',
                    onTap: () => _linkAc(context, AppLinks.privacyPolicy),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _LinkItem(
                    icon: Icons.description_outlined,
                    title: 'Kullanım Şartları',
                    subtitle: 'Uygulama kullanım koşullarını görüntüle',
                    onTap: () => _linkAc(context, AppLinks.termsOfUse),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _LinkItem(
                    icon: Icons.camera_alt_outlined,
                    title: 'Instagram',
                    subtitle: '@emr.core',
                    onTap: () => _linkAc(context, AppLinks.instagram),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              '© 2026 Tüm Hakları Saklıdır',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF102A43),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkItem extends StatelessWidget {
  const _LinkItem({
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

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kBrandTeal.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _kBrandTeal, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF102A43),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 18,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}
