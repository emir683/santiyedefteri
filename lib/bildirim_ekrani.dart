// lib/bildirim_ekrani.dart
//
// In-app bildirim gelen kutusu (Inbox).
// - Firestore'dan gerçek zamanlı bildirim stream'i
// - Okundu/okunmadı durumu
// - Bildirime tıklandığında ilgili ekrana derin yönlendirme (Deep Navigation)
// - Tümünü okundu yap butonu

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firestore_servisi.dart';
import 'user_model.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';
import 'widgets/glass_empty_state.dart';

import 'gunluk_rapor_ekrani.dart';
import 'isci_ekrani.dart';
import 'santiye_ekrani.dart';
import 'odemeler_ekrani.dart';
import 'ekip_yonetimi_ekrani.dart';
import 'haftalik_ozet_ekrani.dart';
import 'cad_webgl_ekrani.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class BildirimEkrani extends StatelessWidget {
  final String teamId;
  const BildirimEkrani({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final uid = user?.uid ?? '';
    final servisi = FirestoreServisi(kullaniciId: uid);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: 'Bildirimler',
        showPrivacyButton: false,
        actions: [
          IconButton(
            tooltip: 'Tümünü Okundu Yap',
            onPressed: () async {
              await servisi.tumBildirimleriOkunduYap(teamId, uid);
            },
            icon: Icon(
              Icons.done_all_rounded,
              size: 20,
              color: isDark ? Colors.white70 : _kBrandTeal,
            ),
          ),
        ],
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: servisi.getKullaniciBildirimleri(teamId, uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _kBrandTeal),
              );
            }

            final bildirimler = snapshot.data ?? [];

            if (bildirimler.isEmpty) {
              return const GlassEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Henüz Bildirim Yok',
                description:
                    'Ekip içi güncellemeler, duyurular, puantaj ve sistem bildirimleri burada görüntülenecektir.',
              );
            }

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                FloatingLiquidAppBar.topPadding(context, extra: 4),
                12,
                16,
              ),
              itemCount: bildirimler.length,
              itemBuilder: (context, index) {
                final bildirim = bildirimler[index];
                return _BildirimKarti(
                  bildirim: bildirim,
                  teamId: teamId,
                  servisi: servisi,
                  isDark: isDark,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BildirimKarti extends StatelessWidget {
  final Map<String, dynamic> bildirim;
  final String teamId;
  final FirestoreServisi servisi;
  final bool isDark;

  const _BildirimKarti({
    required this.bildirim,
    required this.teamId,
    required this.servisi,
    required this.isDark,
  });

  Map<String, dynamic> _getStyle(String? islemTipi) {
    switch (islemTipi) {
      case 'ISCI_EKLEME':
        return {'icon': Icons.person_add_rounded, 'color': const Color(0xFF3B82F6)};
      case 'ISCI_GUNCELLEME':
      case 'ISCI_KART_ESLESMESI':
        return {'icon': Icons.badge_rounded, 'color': const Color(0xFFF59E0B)};
      case 'ISCI_SILME':
      case 'UYE_CIKARMA':
        return {'icon': Icons.person_remove_rounded, 'color': const Color(0xFFEF4444)};
      case 'SANTIYE_EKLEME':
        return {'icon': Icons.domain_add_rounded, 'color': const Color(0xFF8B5CF6)};
      case 'SANTIYE_SILME':
        return {'icon': Icons.delete_forever_rounded, 'color': const Color(0xFFEF4444)};
      case 'GUNLUK_RAPOR_EKLEME':
      case 'GUNLUK_RAPOR_GUNCELLEME':
        return {'icon': Icons.edit_calendar_rounded, 'color': const Color(0xFF10B981)};
      case 'ODEME_EKLEME':
        return {'icon': Icons.payments_rounded, 'color': _kBrandTeal};
      case 'AVANS_EKLEME':
        return {'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFFEC4899)};
      case 'ROL_DEGISIMI':
        return {'icon': Icons.admin_panel_settings_rounded, 'color': const Color(0xFF6366F1)};
      case 'EKIBE_KATILIM':
        return {'icon': Icons.group_add_rounded, 'color': const Color(0xFF06B6D4)};
      case 'HAFTALIK_OZET':
        return {'icon': Icons.analytics_rounded, 'color': const Color(0xFFF97316)};
      default:
        return {'icon': Icons.notifications_rounded, 'color': Colors.grey};
    }
  }

  void _ilgiliSayfayaGit(BuildContext context, String islemTipi, Map<String, dynamic> detaylar) {
    Widget? hedefSayfa;

    switch (islemTipi) {
      case 'GUNLUK_RAPOR_EKLEME':
      case 'GUNLUK_RAPOR_GUNCELLEME':
        hedefSayfa = GunlukRaporEkrani(teamId: teamId);
        break;
      case 'ISCI_EKLEME':
      case 'ISCI_GUNCELLEME':
      case 'ISCI_SILME':
      case 'ISCI_KART_ESLESMESI':
        hedefSayfa = IsciEkrani(teamId: teamId);
        break;
      case 'SANTIYE_EKLEME':
      case 'SANTIYE_SILME':
        hedefSayfa = SantiyeEkrani(teamId: teamId);
        break;
      case 'ODEME_EKLEME':
      case 'AVANS_EKLEME':
        hedefSayfa = OdemelerEkrani(teamId: teamId);
        break;
      case 'ROL_DEGISIMI':
      case 'EKIBE_KATILIM':
      case 'UYE_CIKARMA':
        hedefSayfa = EkipYonetimiEkrani(teamId: teamId);
        break;
      case 'HAFTALIK_OZET':
        hedefSayfa = HaftalikOzetEkrani(teamId: teamId);
        break;
      case 'CAD_PROJECT':
        final webglUrl = detaylar['webgl_url']?.toString() ?? '';
        final projectName = detaylar['project_name']?.toString() ?? 'CAD Çizimi';
        if (webglUrl.isNotEmpty) {
          hedefSayfa = CadWebglEkrani(webglUrl: webglUrl, projeAdi: projectName);
        }
        break;
    }

    if (hedefSayfa != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => hedefSayfa!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool okundu = bildirim['okundu'] ?? false;
    final String islemTipi = bildirim['islemTipi'] ?? '';
    final String mesaj = bildirim['mesaj'] ?? '';
    final String bildirimId = bildirim['id'] ?? '';
    final Map<String, dynamic> detaylar = bildirim['detaylar'] != null
        ? Map<String, dynamic>.from(bildirim['detaylar'])
        : {};
    final timestamp = bildirim['tarih'] as Timestamp?;
    final zaman =
        timestamp != null
            ? DateFormat('dd MMM, HH:mm', 'tr_TR').format(timestamp.toDate())
            : '';

    final style = _getStyle(islemTipi);
    final Color renk = style['color'] as Color;
    final IconData ikon = style['icon'] as IconData;

    return GestureDetector(
      onTap: () async {
        if (!okundu && bildirimId.isNotEmpty) {
          await servisi.bildirimiOkunduIsaretle(teamId, bildirimId);
        }
        if (context.mounted) {
          _ilgiliSayfayaGit(context, islemTipi, detaylar);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: okundu
              ? (isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD))
              : (isDark
                  ? renk.withValues(alpha: 0.08)
                  : renk.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: okundu
                ? (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFD8EAF0))
                : renk.withValues(alpha: 0.25),
            width: okundu ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, color: renk, size: 20),
            ),
            const SizedBox(width: 12),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mesaj,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: okundu ? FontWeight.w400 : FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        zaman,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'İncele →',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: renk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
