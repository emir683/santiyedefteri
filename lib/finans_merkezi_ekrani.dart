import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'animasyon_yardimcisi.dart';
import 'ay_sonu_rapor_ekrani.dart';
import 'data_models.dart';
import 'firestore_servisi.dart';
import 'format_yardimcisi.dart';
import 'models/kullanici_saha_profili.dart';
import 'odemeler_ekrani.dart';
import 'privacy_provider.dart';
import 'user_model.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';
import 'tema_ayarlari.dart';

class FinansMerkeziEkrani extends StatefulWidget {
  final String teamId;
  final int baslangicAltSekme; // 0: Genel Bakış, 1: Ay Sonu & Hakediş, 2: Ödemeler & Avanslar
  final ValueChanged<int>? onAltSekmeDegisti;

  const FinansMerkeziEkrani({
    super.key,
    required this.teamId,
    this.baslangicAltSekme = 0,
    this.onAltSekmeDegisti,
  });

  @override
  State<FinansMerkeziEkrani> createState() => _FinansMerkeziEkraniState();
}

class _FinansMerkeziEkraniState extends State<FinansMerkeziEkrani> {
  void _altSayfayaGit(Widget sayfa) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      SayfaGecisi(sayfa: sayfa),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final uid = user?.uid ?? '';
    final servisi = FirestoreServisi(kullaniciId: uid);
    final privacy = context.watch<PrivacyProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final ayBaslangic = DateTime(now.year, now.month, 1);
    final ayBitis = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingLiquidAppBar(
        title: 'Finans',
        showHamburger: true,
        showPrivacyButton: true,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<List<AlinanOdeme>>(
          stream: servisi.getOdemelerStream(widget.teamId),
          builder: (context, odemeSnap) {
            final odemeler = odemeSnap.data ?? const [];
            return StreamBuilder<List<VerilenAvans>>(
              stream: servisi.getAvanslarStream(widget.teamId),
              builder: (context, avansSnap) {
                final avanslar = avansSnap.data ?? const [];
                return StreamBuilder<List<GunlukSantiyeRaporu>>(
                  stream: servisi.getRaporlarStream(
                    widget.teamId,
                    ayBaslangic,
                    ayBitis,
                  ),
                  builder: (context, raporSnap) {
                    final raporlar = raporSnap.data ?? const [];

                    // Hesaplamalar (Bu Ay)
                    final buAyOdemeler = odemeler.where(
                      (o) => o.tarih.year == now.year && o.tarih.month == now.month,
                    );
                    final toplamOdeme = buAyOdemeler.fold<double>(
                      0,
                      (t, o) => t + o.miktar,
                    );

                    final buAyAvanslar = avanslar.where(
                      (a) => a.tarih.year == now.year && a.tarih.month == now.month,
                    );
                    final toplamAvans = buAyAvanslar.fold<double>(
                      0,
                      (t, a) => t + a.miktar,
                    );

                    double toplamMasraf = 0;
                    double toplamYevmiye = 0;
                    for (final r in raporlar) {
                      toplamMasraf += r.benzinGideri + r.yemekGideri + r.ekMasraflar;
                      for (final c in r.calisanlar) {
                        toplamYevmiye += parseDurumCarpani(c.durum);
                      }
                    }

                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        FloatingLiquidAppBar.topPadding(context, extra: 8),
                        16,
                        130,
                      ),
                      children: [
                        // ÜST KÜÇÜK DURUM BİLGİSİ
                        PanelGlassWidgets.buildCard(
                          context: context,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  PanelGlassWidgets.buildIconBadge(
                                    context: context,
                                    icon: Icons.account_balance_wallet_rounded,
                                    accentColor: const Color(0xFFD97706),
                                    compact: true,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Finans & Kasa',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF102A43),
                                        ),
                                      ),
                                      Text(
                                        '${_ayAdi(now.month)} ${now.year}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              PanelGlassWidgets.buildInset(
                                context: context,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(
                                  privacy.isHidden
                                      ? '•••• ₺'
                                      : FormatYardimcisi.paraFormatla(toplamOdeme - toplamAvans - toplamMasraf),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: (toplamOdeme - toplamAvans - toplamMasraf) >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 1. KART: AY SONU & HAKEDİŞ RAPORU ÖZETİ
                        _buildOzetKarti(
                          context: context,
                          isDark: isDark,
                          icon: Icons.assessment_rounded,
                          accentColor: AppTheme.contrastIcon(context, isDark: isDark),
                          baslik: 'Ay Sonu & Hakediş',
                          altBilgi: '${raporlar.length} Rapor • ${toplamYevmiye.toStringAsFixed(1)} Yevmiye • Masraf: ${privacy.isHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(toplamMasraf)}',
                          butonMetni: 'Raporu Aç',
                          onTap: () => _altSayfayaGit(
                            AySonuRaporEkrani(teamId: widget.teamId),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. KART: ÖDEMELER & AVANSLAR ÖZETİ
                        _buildOzetKarti(
                          context: context,
                          isDark: isDark,
                          icon: Icons.receipt_long_rounded,
                          accentColor: const Color(0xFFD97706),
                          baslik: 'Ödemeler & Avanslar',
                          altBilgi: 'Tahsilat: ${privacy.isHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(toplamOdeme)} • Avans: ${privacy.isHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(toplamAvans)}',
                          butonMetni: 'Kasa & Ödemeler',
                          onTap: () => _altSayfayaGit(
                            OdemelerEkrani(teamId: widget.teamId),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOzetKarti({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String baslik,
    required String altBilgi,
    required String butonMetni,
    required VoidCallback onTap,
  }) {
    return PanelGlassWidgets.buildCard(
      context: context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: icon,
                accentColor: accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      altBilgi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: PanelGlassWidgets.buildInset(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderColor: accentColor.withValues(alpha: 0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    butonMetni,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ayAdi(int ay) {
    const aylar = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return aylar[(ay - 1).clamp(0, 11)];
  }
}


