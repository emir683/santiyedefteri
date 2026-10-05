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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'Hakkında',
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
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: _kBrandTeal.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      size: 48,
                      color: _kBrandTeal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Şantiye Puantaj Defteri',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profesyonel saha yönetimi ve puantaj takibi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: subTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassSectionCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _InfoRow(label: 'Versiyon', value: _version),
                  const Divider(),
                  _InfoRow(label: 'Geliştirici', value: 'Emir Çiftçi'),
                  const Divider(),
                  _InfoRow(label: 'İletişim', value: 'info@emrcore.com'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LinkTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik Politikası',
              subtitle: 'Verilerin nasıl işlendiğini görüntüle',
              onTap: () => _linkAc(context, AppLinks.privacyPolicy),
            ),
            const SizedBox(height: 12),
            _LinkTile(
              icon: Icons.description_outlined,
              title: 'Kullanım Şartları',
              subtitle: 'Uygulama kullanım koşullarını görüntüle',
              onTap: () => _linkAc(context, AppLinks.termsOfUse),
            ),
            const SizedBox(height: 12),
            _LinkTile(
              icon: Icons.camera_alt_outlined,
              title: 'Instagram',
              subtitle: '@emr.core',
              onTap: () => _linkAc(context, AppLinks.instagram),
            ),
            const SizedBox(height: 28),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF102A43),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: _kBrandTeal),
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
