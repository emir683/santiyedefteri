import 'dart:ui'; // Blur efekti için gerekli
import 'animasyon_yardimcisi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'privacy_provider.dart';
import 'santiye_ekrani.dart';
import 'isci_ekrani.dart';
import 'tur_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/offline_sync_banner.dart';
import 'services/connectivity_sync_service.dart';
import 'puanlama_servisi.dart';

class GunlukRaporEkrani extends StatefulWidget {
  final String teamId;
  final bool baslatRehber;
  const GunlukRaporEkrani({
    super.key,
    required this.teamId,
    this.baslatRehber = false,
  });

  @override
  State<GunlukRaporEkrani> createState() => _GunlukRaporEkraniState();
}

class _GunlukRaporEkraniState extends State<GunlukRaporEkrani>
    with SingleTickerProviderStateMixin {
  DateTime _seciliGun = DateTime.now();
  DateTime _odaklanilanGun = DateTime.now();
  bool _calendarVisible = false;

  // Rehber Tur Anahtarları
  final GlobalKey _dateBarKey = GlobalKey();
  final GlobalKey _demoSantiyeCardKey = GlobalKey();
  final GlobalKey _demoGiderKey = GlobalKey();

  // Uyumluluk için eski buton anahtarları
  final GlobalKey _santiyeEkleKey = GlobalKey();
  final GlobalKey _isciEkleKey = GlobalKey();
  final GlobalKey _santiyeKartiKey = GlobalKey();
  final GlobalKey _hizliYoklamaKey = GlobalKey();
  final GlobalKey _kaydetKapatKey = GlobalKey();

  // İnteraktif Tur & Örnek Demo Veri Durumu
  bool _isTourActive = false;
  late AnimationController _demoAnimController;
  late Animation<double> _demoFadeAnimation;
  late Animation<Offset> _demoSlideAnimation;

  @override
  void initState() {
    super.initState();
    _demoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _demoFadeAnimation = CurvedAnimation(
      parent: _demoAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _demoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _demoAnimController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    if (widget.baslatRehber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _turKontrol();
      });
    }
  }

  @override
  void dispose() {
    _demoAnimController.dispose();
    super.dispose();
  }

  Future<void> _turKontrol() async {
    final gosterildi = await TurServisi.raporTurGosterildiMi();
    if (!gosterildi && mounted) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) _turBaslat();
    }
  }

  void _turBaslat({bool manual = false}) async {
    if (_isTourActive) return;
    setState(() {
      _isTourActive = true;
    });
    await _demoAnimController.forward();
  }

  Future<void> _turSonlandir() async {
    await _demoAnimController.reverse();
    if (mounted) {
      setState(() {
        _isTourActive = false;
      });
    }
    await TurServisi.raporTurGosterildiOlarakIsaretle();
    await TurServisi.adim3Isaretle();
  }

  List<TourStep> _buildTourSteps() {
    return [
      TourStep(
        id: 'gunluk_genel_tanitim',
        title: 'Günlük Puantaj ve Raporlama',
        description:
            'Şantiye sahalarınızın günlük yoklamalarını, usta ve işçilerin mesai durumlarını ve o gün yapılan harcamaları bu ekrandan yönetirsiniz.',
        icon: Icons.assignment_turned_in_rounded,
        targetKey: null,
      ),
      TourStep(
        id: 'tarih_secici',
        title: 'Tarih & Takvim Gezintisi',
        description:
            'Tarih alanına dokunarak takvimi açabilir, dilediğiniz güne gidip geçmiş veya gelecek günlerin puantajlarını inceleyebilirsiniz.',
        icon: Icons.calendar_month_rounded,
        targetKey: _dateBarKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 22.0,
      ),
      TourStep(
        id: 'santiye_puantaj_karti',
        title: 'Şantiye Puantaj Kartı',
        description:
            'Şantiye kartına dokunarak o projenin günlük yoklama sayfasına ulaşırsınız. Orada işçilerinize tek tıkla Tam Gün, Yarım Gün veya Yok verebilirsiniz.',
        icon: Icons.apartment_rounded,
        targetKey: _demoSantiyeCardKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 24.0,
      ),
      TourStep(
        id: 'gunluk_harcamalar',
        title: 'Günlük Giderler & Açıklama',
        description:
            'Sahada yapılan benzin, yemek veya malzeme harcamalarını ve günün notlarını şantiye kartı üzerinde anlık görürsünüz.',
        icon: Icons.receipt_long_rounded,
        targetKey: _demoGiderKey,
        targetPadding: const EdgeInsets.all(6),
        targetBorderRadius: 16.0,
      ),
    ];
  }

  Widget _buildGunlukOzetBanner({
    required BuildContext context,
    required bool isDark,
    required int toplamSantiye,
    required int raporlananSantiye,
    required double oran,
    required int toplamCalisan,
    required double toplamMasraf,
  }) {
    final bool hepsiTamam =
        toplamSantiye > 0 && raporlananSantiye == toplamSantiye;
    final bool hicYok = raporlananSantiye == 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    (hepsiTamam
                            ? const Color(0xFF065F46)
                            : const Color(0xFF1E293B))
                        .withValues(alpha: 0.70),
                    const Color(0xFF0F172A).withValues(alpha: 0.85),
                  ]
                  : [
                    hepsiTamam
                        ? const Color(0xFFECFDF5)
                        : Colors.white.withValues(alpha: 0.95),
                    hepsiTamam
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFF8FAFC).withValues(alpha: 0.95),
                  ],
        ),
        border: Border.all(
          color:
              hepsiTamam
                  ? const Color(
                    0xFF10B981,
                  ).withValues(alpha: isDark ? 0.6 : 0.45)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0)),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (hepsiTamam
                    ? const Color(0xFF10B981)
                    : (hicYok ? Colors.black : const Color(0xFF14B8A6)))
                .withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hepsiTamam
                          ? const Color(0xFF10B981)
                          : (hicYok
                              ? (isDark
                                  ? Colors.white24
                                  : const Color(0xFF94A3B8))
                              : const Color(0xFF14B8A6)))
                      .withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hepsiTamam
                      ? Icons.verified_rounded
                      : (hicYok
                          ? Icons.assignment_late_outlined
                          : Icons.pie_chart_rounded),
                  size: 18,
                  color:
                      hepsiTamam
                          ? const Color(0xFF10B981)
                          : (hicYok
                              ? (isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B))
                              : (isDark
                                  ? const Color(0xFF5EEAD4)
                                  : const Color(0xFF0F766E))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hepsiTamam
                          ? "Tüm Raporlar Girildi"
                          : (hicYok
                              ? "Henüz Rapor Girilmedi"
                              : "Günün Rapor Durumu"),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hepsiTamam
                          ? "Bugün için tüm şantiyelerin kayıtları eksiksiz"
                          : (hicYok
                              ? "Aşağıdaki listeden şantiye seçip raporlayın"
                              : "$toplamSantiye şantiyeden $raporlananSantiye tanesi tamamlandı"),
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: (hepsiTamam
                          ? const Color(0xFF10B981)
                          : (hicYok
                              ? (isDark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9))
                              : const Color(0xFF14B8A6)))
                      .withValues(alpha: isDark ? 0.25 : 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (hepsiTamam
                            ? const Color(0xFF10B981)
                            : (hicYok
                                ? (isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1))
                                : const Color(0xFF14B8A6)))
                        .withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  "$raporlananSantiye / $toplamSantiye",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color:
                        hepsiTamam
                            ? const Color(0xFF10B981)
                            : (hicYok
                                ? (isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B))
                                : (isDark
                                    ? const Color(0xFF5EEAD4)
                                    : const Color(0xFF0F766E))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 5,
              backgroundColor:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                hepsiTamam ? const Color(0xFF10B981) : const Color(0xFF14B8A6),
              ),
            ),
          ),
          if (raporlananSantiye > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.group_rounded,
                          size: 15,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$toplamCalisan Çalışan",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<PrivacyProvider>(
                  builder: (context, privacy, child) {
                    final String harcamaMetin =
                        privacy.isHidden
                            ? "**** TL"
                            : "${toplamMasraf.toStringAsFixed(2)} TL";
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.payments_rounded,
                              size: 15,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                harcamaMetin,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF5EEAD4)
                                          : const Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDemoDailyReportCard(bool isDark) {
    return AnimatedBuilder(
      animation: _demoAnimController,
      builder: (context, child) {
        if (_demoAnimController.value <= 0.001) return const SizedBox.shrink();
        return FadeTransition(
          opacity: _demoFadeAnimation,
          child: SlideTransition(
            position: _demoSlideAnimation,
            child: Container(
              key: _demoSantiyeCardKey,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDark
                          ? [
                            const Color(0xFF10B981).withValues(alpha: 0.16),
                            const Color(0xFF0F172A).withValues(alpha: 0.88),
                          ]
                          : [const Color(0xFFF0FDF4), Colors.white],
                ),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.60)
                          : const Color(0xFF059669).withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF10B981,
                    ).withValues(alpha: isDark ? 0.18 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Koru Konutları Projesi (Örnek)",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6.5,
                                    height: 6.5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Rapor Girildi",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? const Color(0xFF6EE7B7)
                                              : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: isDark ? 0.24 : 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "GİRİLDİ",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color:
                                      isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      key: _demoGiderKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.black.withValues(alpha: 0.28)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.group_rounded,
                            size: 15,
                            color: Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "5 Çalışan",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wallet_rounded,
                                  size: 15,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    "1.450,00 TL",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark
                                              ? const Color(0xFF5EEAD4)
                                              : const Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? const Color(0xFF5EEAD4)
                                    : const Color(0xFF0F766E),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📝 ", style: TextStyle(fontSize: 11)),
                          Expanded(
                            child: Text(
                              "1. Kat döşeme betonu döküldü",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- HIZLI YOKLAMA POPUP (Aynı) ---
  Set<String> _isciEslesmeAnahtarlari(Isci isci) {
    final anahtarlar = <String>{'ad:${isci.ad.trim().toLowerCase()}'};
    final id = isci.id?.trim();
    if (id != null && id.isNotEmpty) {
      anahtarlar.add('id:$id');
    }
    return anahtarlar;
  }

  Set<String> _raporlardakiIsciAnahtarlari(
    Iterable<GunlukSantiyeRaporu> raporlar,
  ) {
    final anahtarlar = <String>{};
    for (final rapor in raporlar) {
      for (final calisma in rapor.calisanlar) {
        anahtarlar.addAll(_isciEslesmeAnahtarlari(calisma.isci));
      }
    }
    return anahtarlar;
  }

  List<Isci> _gunIcinSecilebilirIsciler({
    required List<Isci> tumIsciler,
    required List<GunlukSantiyeRaporu> seciliGunRaporlari,
    required String aktifSantiyeAdi,
    required GunlukSantiyeRaporu aktifRapor,
  }) {
    final digerRaporlar = seciliGunRaporlari.where(
      (rapor) => rapor.santiyeAdi != aktifSantiyeAdi,
    );
    final digerSantiyeAnahtarlari = _raporlardakiIsciAnahtarlari(digerRaporlar);
    final aktifRaporAnahtarlari = _raporlardakiIsciAnahtarlari([aktifRapor]);

    final sonuc =
        tumIsciler.where((isci) {
          final isciAnahtarlari = _isciEslesmeAnahtarlari(isci);
          if (isciAnahtarlari.any(aktifRaporAnahtarlari.contains)) {
            return true;
          }
          return !isciAnahtarlari.any(digerSantiyeAnahtarlari.contains);
        }).toList();

    sonuc.sort(
      (a, b) => a.ad.trim().toLowerCase().compareTo(b.ad.trim().toLowerCase()),
    );
    return sonuc;
  }

  void _hizliYoklamaBaslat(
    BuildContext context,
    GunlukSantiyeRaporu rapor,
    List<Isci> secilebilirIsciler,
    StateSetter setMainModalState,
    VoidCallback onDegisiklik,
  ) {
    List<Isci> yerelIsciler = List.from(secilebilirIsciler);
    Map<String, String> geciciDurumlar = {};
    for (var isci in yerelIsciler) {
      var mevcutKayit =
          rapor.calisanlar.where((c) => c.isci.ad == isci.ad).firstOrNull;
      geciciDurumlar[isci.id ?? isci.ad] =
          mevcutKayit != null ? mevcutKayit.durum : "Yok";
    }

    void topluSecim(List<Isci> liste, String durum, StateSetter setSheetState) {
      setSheetState(() {
        for (var i in liste) {
          geciciDurumlar[i.id ?? i.ad] = durum;
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setSheetState) {
              final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
              final cekirdekEkip =
                  yerelIsciler
                      .where((i) => i.isciTuru == "Çekirdek Ekip")
                      .toList();
              final misafirler =
                  yerelIsciler.where((i) => i.isciTuru == "Misafir").toList();

              Widget buildIsciKart(Isci isci) {
                final String id = isci.id ?? isci.ad;
                final String durum = geciciDurumlar[id] ?? "Yok";
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF181E27)
                            : const Color(0xFFF9FCFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFDCE8ED),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isci.ad,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildYoklamaOption(
                            "Yok",
                            durum == "Yok",
                            Colors.grey,
                            isDark,
                            () =>
                                setSheetState(() => geciciDurumlar[id] = "Yok"),
                          ),
                          const SizedBox(width: 8),
                          _buildYoklamaOption(
                            "Yarım",
                            durum == "Yarım Gün",
                            Colors.orange,
                            isDark,
                            () => setSheetState(
                              () => geciciDurumlar[id] = "Yarım Gün",
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildYoklamaOption(
                            "Tam",
                            durum == "Tam Gün",
                            Colors.green,
                            isDark,
                            () => setSheetState(
                              () => geciciDurumlar[id] = "Tam Gün",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              Widget buildGrupBaslik(String baslik, List<Isci> liste) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        baslik,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap:
                                () => topluSecim(liste, "Yok", setSheetState),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Yok",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap:
                                () => topluSecim(
                                  liste,
                                  "Yarım Gün",
                                  setSheetState,
                                ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Yarım",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap:
                                () =>
                                    topluSecim(liste, "Tam Gün", setSheetState),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Tam",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF121821).withValues(alpha: 0.84)
                              : Colors.white.withValues(alpha: 0.86),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFD9E6EC),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.24 : 0.08,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Hızlı Yoklama",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF516772),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFD9E6EC),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (cekirdekEkip.isNotEmpty) ...[
                                buildGrupBaslik("Çekirdek Ekip", cekirdekEkip),
                                ...cekirdekEkip.map(buildIsciKart),
                              ] else if (misafirler.isEmpty) ...[
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Text("Kayıtlı işçi bulunamadı."),
                                  ),
                                ),
                              ],
                              if (misafirler.isNotEmpty) ...[
                                buildGrupBaslik("Misafirler", misafirler),
                                ...misafirler.map(buildIsciKart),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  TextEditingController adCtrl =
                                      TextEditingController();
                                  TextEditingController maasCtrl =
                                      TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder:
                                        (dc) => AlertDialog(
                                          title: const Text("Misafir Ekle"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: adCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: "Ad Soyad",
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              TextField(
                                                controller: maasCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          "Günlük Yevmiye (TL)",
                                                    ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(dc),
                                              child: const Text("İptal"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (adCtrl.text.isNotEmpty &&
                                                    maasCtrl.text.isNotEmpty) {
                                                  final isci = Isci(
                                                    ad: adCtrl.text.trim(),
                                                    gunlukMaas:
                                                        double.tryParse(
                                                          maasCtrl.text,
                                                        ) ??
                                                        0,
                                                    isciTuru: "Misafir",
                                                  );
                                                  final user =
                                                      Provider.of<UserModel?>(
                                                        context,
                                                        listen: false,
                                                      );
                                                  final servisi =
                                                      FirestoreServisi(
                                                        kullaniciId:
                                                            user?.uid ?? '',
                                                      );
                                                  await servisi.isciEkle(
                                                    widget.teamId,
                                                    isci,
                                                  );
                                                  setSheetState(() {
                                                    yerelIsciler.add(isci);
                                                    geciciDurumlar[isci.ad] =
                                                        "Tam Gün";
                                                  });
                                                  if (context.mounted) {
                                                    Navigator.pop(dc);
                                                  }
                                                }
                                              },
                                              child: const Text("Ekle"),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text("Misafir Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF14B8A6),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setMainModalState(() {
                                rapor.calisanlar.clear();
                                geciciDurumlar.forEach((id, seciliDurum) {
                                  if (seciliDurum != "Yok") {
                                    final isci = yerelIsciler.firstWhere(
                                      (i) => (i.id ?? i.ad) == id,
                                    );
                                    rapor.calisanlar.add(
                                      GunlukCalisma(
                                        isci: isci,
                                        durum: seciliDurum,
                                      ),
                                    );
                                  }
                                });
                              });
                              onDegisiklik();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "YOKLAMAYI ONAYLA",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildYoklamaOption(
    String text,
    bool isSelected,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? color.withValues(alpha: isDark ? 0.92 : 0.16)
                    : (isDark
                        ? const Color(0xFF0F141B)
                        : Colors.white.withValues(alpha: 0.82)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected
                      ? color.withValues(alpha: 0.90)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFD7E4EA)),
              width: 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: isDark ? 0.18 : 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Text(
            text,
            style: TextStyle(
              color:
                  isSelected
                      ? (isDark ? Colors.white : color)
                      : (isDark ? Colors.white70 : const Color(0xFF516772)),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // --- RAPOR DÜZENLEME EKRANI ---
  Widget _buildKaydedilmemisDialog(BuildContext context) {
    final dialogDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: dialogDark ? const Color(0xFF161A20) : const Color(0xFFF7FBFD),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                dialogDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFD8EAF0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dialogDark ? 0.30 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Kaydedilmemi\u015f De\u011fi\u015fiklikler",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color:
                          dialogDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Verileri kaydetmeden \u00e7\u0131kmak istiyor musunuz?",
              style: TextStyle(
                height: 1.45,
                color: dialogDark ? Colors.white70 : const Color(0xFF516772),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final darEkran = constraints.maxWidth < 380;

                Widget iptalButon() => OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'iptal'),
                  child: const Text(
                    "Vazge\u00e7",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

                Widget kapatButon() => ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'kapat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    "Kaydetme",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

                Widget kaydetButon() => ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    "Kaydet",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );

                if (darEkran) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      iptalButon(),
                      const SizedBox(height: 8),
                      kapatButon(),
                      const SizedBox(height: 8),
                      kaydetButon(),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: iptalButon()),
                    const SizedBox(width: 10),
                    Expanded(child: kapatButon()),
                    const SizedBox(width: 10),
                    Expanded(child: kaydetButon()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _raporDuzenle(
    BuildContext context,
    FirestoreServisi servisi,
    String santiyeAdi,
    GunlukSantiyeRaporu? mevcutRapor,
    List<Isci> tumIsciler,
    List<GunlukSantiyeRaporu> seciliGunRaporlari,
    List<GunlukSantiyeRaporu> tumRaporlar,
  ) {
    final rapor =
        mevcutRapor ??
        GunlukSantiyeRaporu(santiyeAdi: santiyeAdi, tarih: _seciliGun);
    final digerSantiyeAnahtarlari = _raporlardakiIsciAnahtarlari(
      seciliGunRaporlari.where((kayit) => kayit.santiyeAdi != santiyeAdi),
    );
    final kullanilabilirIsciler = _gunIcinSecilebilirIsciler(
      tumIsciler: tumIsciler,
      seciliGunRaporlari: seciliGunRaporlari,
      aktifSantiyeAdi: santiyeAdi,
      aktifRapor: rapor,
    );

    final benzinCtrl = TextEditingController(
      text: rapor.benzinGideri == 0 ? "" : rapor.benzinGideri.toString(),
    );
    final yemekCtrl = TextEditingController(
      text: rapor.yemekGideri == 0 ? "" : rapor.yemekGideri.toString(),
    );
    final ekMasrafCtrl = TextEditingController(
      text: rapor.ekMasraflar == 0 ? "" : rapor.ekMasraflar.toString(),
    );
    final aciklamaCtrl = TextEditingController(text: rapor.aciklama);
    String? benzinHarcayanId = rapor.benzinGideriIsciId;
    String? benzinHarcayanAd = rapor.benzinGideriIsciAdi;
    String? yemekHarcayanId = rapor.yemekGideriIsciId;
    String? yemekHarcayanAd = rapor.yemekGideriIsciAdi;
    String? ekMasrafHarcayanId = rapor.ekMasraflarIsciId;
    String? ekMasrafHarcayanAd = rapor.ekMasraflarIsciAdi;

    bool degisiklikVar = false;
    bool kaydetmeDevamEdiyor = false;

    void dunuKopyala(BuildContext modalCtx, StateSetter setModalState) {
      final oncekiRaporlar =
          tumRaporlar
              .where(
                (r) =>
                    r.santiyeAdi == santiyeAdi && r.tarih.isBefore(_seciliGun),
              )
              .toList();
      if (oncekiRaporlar.isEmpty) {
        showDialog(
          context: modalCtx,
          builder:
              (c) => AlertDialog(
                title: const Text('Bilgi'),
                content: const Text('Kopyalanacak geçmiş kayıt bulunamadı.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
        );
        return;
      }
      oncekiRaporlar.sort((a, b) => b.tarih.compareTo(a.tarih));
      final sonRapor = oncekiRaporlar.first;

      bool kopyalandi = false;
      for (var calisan in sonRapor.calisanlar) {
        if (!rapor.calisanlar.any(
          (c) =>
              (c.isci.id != null &&
                  c.isci.id!.isNotEmpty &&
                  c.isci.id == calisan.isci.id) ||
              c.isci.ad == calisan.isci.ad,
        )) {
          rapor.calisanlar.add(
            GunlukCalisma(isci: calisan.isci, durum: calisan.durum),
          );
          kopyalandi = true;
        }
      }

      if (kopyalandi) {
        degisiklikVar = true;
        setModalState(() {});
        showDialog(
          context: modalCtx,
          builder:
              (c) => AlertDialog(
                title: const Text('Başarılı'),
                content: const Text('Dünkü kayıtlar başarıyla kopyalandı!'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
        );
      } else {
        showDialog(
          context: modalCtx,
          builder:
              (c) => AlertDialog(
                title: const Text('Bilgi'),
                content: const Text(
                  'Dünkü tüm işçiler zaten bu raporda mevcut.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Tamam'),
                  ),
                ],
              ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent, // 1. ARKA PLAN ŞEFFAF
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final bool isDark = Theme.of(ctx).brightness == Brightness.dark;

              Future<void> verileriKaydet() async {
                if (kaydetmeDevamEdiyor) return;
                setModalState(() => kaydetmeDevamEdiyor = true);
                rapor.benzinGideri = double.tryParse(benzinCtrl.text) ?? 0;
                rapor.yemekGideri = double.tryParse(yemekCtrl.text) ?? 0;
                rapor.ekMasraflar = double.tryParse(ekMasrafCtrl.text) ?? 0;
                rapor.benzinGideriIsciId =
                    rapor.benzinGideri > 0 ? benzinHarcayanId : null;
                rapor.benzinGideriIsciAdi =
                    rapor.benzinGideri > 0 ? benzinHarcayanAd : null;
                rapor.yemekGideriIsciId =
                    rapor.yemekGideri > 0 ? yemekHarcayanId : null;
                rapor.yemekGideriIsciAdi =
                    rapor.yemekGideri > 0 ? yemekHarcayanAd : null;
                rapor.ekMasraflarIsciId =
                    rapor.ekMasraflar > 0 ? ekMasrafHarcayanId : null;
                rapor.ekMasraflarIsciAdi =
                    rapor.ekMasraflar > 0 ? ekMasrafHarcayanAd : null;
                rapor.aciklama = aciklamaCtrl.text.trim();
                rapor.calisanlar.removeWhere((calisma) {
                  final anahtarlar = _isciEslesmeAnahtarlari(calisma.isci);
                  return anahtarlar.any(digerSantiyeAnahtarlari.contains);
                });
                try {
                  await servisi.raporKaydet(widget.teamId, rapor);

                  if (widget.baslatRehber && mounted) {
                    await TurServisi.adim3Isaretle();
                    if (!ctx.mounted) return;
                    await showDialog(
                      context: ctx,
                      barrierDismissible: false,
                      builder:
                          (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Column(
                              children: [
                                Icon(
                                  Icons.celebration,
                                  color: Colors.amber,
                                  size: 60,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Tebrikler!",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            content: const Text(
                              "İlk günlük raporunuzu başarıyla girdiniz.\nArtık uygulamayı kullanmaya hazırsınız!",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            actionsAlignment: MainAxisAlignment.center,
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                },
                                child: const Text(
                                  "Uygulamayı Kullanmaya Hazırsınız",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    );
                  } else if (ctx.mounted) {
                    final isOffline =
                        Provider.of<ConnectivitySyncService>(
                          ctx,
                          listen: false,
                        ).isOffline;
                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                isOffline
                                    ? Icons.cloud_off_rounded
                                    : Icons.check_circle_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isOffline
                                      ? "Rapor telefonunuza kaydedildi. İnternet olduğunda otomatik eşitlenecektir."
                                      : "Rapor başarıyla kaydedildi.",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor:
                              isOffline
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF16A34A),
                          duration: const Duration(seconds: 4),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                      PuanlamaServisi.islemSonrasiKontrolEtVeGoster(context);
                    }
                  }
                } finally {
                  if (ctx.mounted) {
                    setModalState(() => kaydetmeDevamEdiyor = false);
                  }
                }
              }

              Future<bool> onWillPop() async {
                if (kaydetmeDevamEdiyor) return false;
                if (!degisiklikVar) return true;
                final sonuc = await showDialog<String>(
                  context: ctx,
                  builder: (c) => _buildKaydedilmemisDialog(c),
                );
                if (sonuc == 'kaydet') {
                  await verileriKaydet();
                  return false;
                } else if (sonuc == 'kapat') {
                  return true;
                }
                return false;
              }

              Future<void> kapatmayiDene() async {
                if (await onWillPop() && ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              }

              return PopScope(
                canPop: !degisiklikVar,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  await kapatmayiDene();
                },

                // 2. BLUR EFEKTİ İÇİN ClipRRect ve BackdropFilter KULLANIYORUZ
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10,
                      sigmaY: 10,
                    ), // Bulanıklık şiddeti
                    child: Container(
                      decoration: BoxDecoration(
                        // 3. RENK OPAKLIĞINI DÜŞÜRÜYORUZ (Şeffaflık)
                        color:
                            isDark
                                ? const Color(0xFF121212).withValues(
                                  alpha: 0.35,
                                ) // Koyu modda %85 opak siyah
                                : Colors.white.withValues(
                                  alpha: 0.40,
                                ), // Açık modda %90 opak beyaz
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ), // Üstte ince cam çizgisi
                      ),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).viewInsets.bottom,
                      ),
                      child: DraggableScrollableSheet(
                        initialChildSize: 1.0,
                        maxChildSize: 1.0,
                        minChildSize: 1.0,
                        expand: true,
                        builder:
                            (_, scrollController) => Column(
                              children: [
                                // Tutamaç
                                Center(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: kapatmayiDene,
                                    onVerticalDragEnd: (details) async {
                                      if ((details.primaryVelocity ?? 0) > 0) {
                                        await kapatmayiDene();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 24,
                                      ),
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(
                                            alpha: 0.3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                Expanded(
                                  child: ListView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(24),
                                    children: [
                                      Text(
                                        santiyeAdi,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                          'tr_TR',
                                        ).format(_seciliGun),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Çalışanlar Başlığı ve Butonlar
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "Çalışan Personeller",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Expanded(
                                            child: Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                ElevatedButton.icon(
                                                  icon: const Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    "Dünü Kopyala",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blueGrey,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed:
                                                      () => dunuKopyala(
                                                        ctx,
                                                        setModalState,
                                                      ),
                                                ),
                                                ElevatedButton.icon(
                                                  key: _hizliYoklamaKey,
                                                  icon: const Icon(
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    "Hızlı Yoklama",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFEF7C00),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed:
                                                      () => _hizliYoklamaBaslat(
                                                        context,
                                                        rapor,
                                                        kullanilabilirIsciler,
                                                        setModalState,
                                                        () =>
                                                            degisiklikVar =
                                                                true,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),

                                      // Çalışan Listesi
                                      if (rapor.calisanlar.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(0xFF171D25)
                                                    : const Color(0xFFF9FCFD),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? Colors.white.withValues(
                                                        alpha: 0.08,
                                                      )
                                                      : const Color(0xFFDCE8ED),
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              "Henüz çalışan eklenmedi.",
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...rapor.calisanlar.map(
                                          (c) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? const Color(0xFF171D25)
                                                      : const Color(0xFFF9FCFD),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                            .withValues(
                                                              alpha: 0.06,
                                                            )
                                                        : const Color(
                                                          0xFFDCE8ED,
                                                        ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Colors.blue
                                                      .withValues(alpha: 0.2),
                                                  child: Text(
                                                    c.isci.ad[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        c.isci.ad,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              c.durum ==
                                                                      "Tam Gün"
                                                                  ? Colors.green
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      )
                                                                  : Colors
                                                                      .orange
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          c.durum,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                c.durum ==
                                                                        "Tam Gün"
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .orange,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed:
                                                      () => setModalState(() {
                                                        rapor.calisanlar.remove(
                                                          c,
                                                        );
                                                        degisiklikVar = true;
                                                      }),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 24),
                                      const Text(
                                        "Günlük Masraflar",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Giderler (Focus Modlu)
                                      _buildFocusInput(
                                        context: context,
                                        controller: benzinCtrl,
                                        label: "Benzin Gideri",
                                        icon: Icons.local_gas_station_outlined,
                                        isDark: isDark,
                                        tumIsciler: tumIsciler,
                                        seciliIsciAdi: benzinHarcayanAd,
                                        onIsciSecildi: (isci) {
                                          setModalState(() {
                                            benzinHarcayanId = isci?.id;
                                            benzinHarcayanAd = isci?.ad;
                                            degisiklikVar = true;
                                          });
                                        },
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFocusInput(
                                        context: context,
                                        controller: yemekCtrl,
                                        label: "Yemek Gideri",
                                        icon: Icons.restaurant_outlined,
                                        isDark: isDark,
                                        tumIsciler: tumIsciler,
                                        seciliIsciAdi: yemekHarcayanAd,
                                        onIsciSecildi: (isci) {
                                          setModalState(() {
                                            yemekHarcayanId = isci?.id;
                                            yemekHarcayanAd = isci?.ad;
                                            degisiklikVar = true;
                                          });
                                        },
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFocusInput(
                                        context: context,
                                        controller: ekMasrafCtrl,
                                        label: "Ek Masraflar",
                                        icon: Icons.add_shopping_cart_outlined,
                                        isDark: isDark,
                                        tumIsciler: tumIsciler,
                                        seciliIsciAdi: ekMasrafHarcayanAd,
                                        onIsciSecildi: (isci) {
                                          setModalState(() {
                                            ekMasrafHarcayanId = isci?.id;
                                            ekMasrafHarcayanAd = isci?.ad;
                                            degisiklikVar = true;
                                          });
                                        },
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),

                                      const SizedBox(height: 24),
                                      const Text(
                                        "Açıklama / Not",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Not Alanı (Focus Modlu - MultiLine)
                                      _buildFocusInput(
                                        context: context,
                                        controller: aciklamaCtrl,
                                        label: "Notunuzu girin...",
                                        icon: Icons.note_alt_outlined,
                                        isDark: isDark,
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                        isMultiLine: true,
                                      ),

                                      const SizedBox(height: 32),
                                      SafeArea(
                                        top: false,
                                        minimum: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: ElevatedButton(
                                          key: _kaydetKapatKey,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                          ),
                                          onPressed:
                                              kaydetmeDevamEdiyor
                                                  ? null
                                                  : verileriKaydet,
                                          child:
                                              kaydetmeDevamEdiyor
                                                  ? const SizedBox(
                                                    height: 22,
                                                    width: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.4,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                  : const Text(
                                                    "KAYDET VE KAPAT",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<Isci?> _harcamaIscisiSec(
    BuildContext context,
    List<Isci> tumIsciler,
    String? seciliIsciAdi,
  ) async {
    return showModalBottomSheet<Isci?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171B20) : const Color(0xFFF7FBFD),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFD5E6EC),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Masraf Kimin Kartından Yapıldı?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.close_rounded),
                        title: const Text("Seçimi Temizle"),
                        onTap: () => Navigator.pop(sheetContext, null),
                      ),
                      ...tumIsciler.map(
                        (isci) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.withValues(
                              alpha: 0.14,
                            ),
                            child: Text(
                              isci.ad.isEmpty ? "?" : isci.ad[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(isci.ad),
                          trailing:
                              seciliIsciAdi == isci.ad
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.teal,
                                  )
                                  : null,
                          onTap: () => Navigator.pop(sheetContext, isci),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 3. ODAKLANAN INPUT WIDGET'I (YENİ) 👁️✨
  // ==========================================
  Widget _buildFocusInput({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onChanged,
    bool isMultiLine = false,
    List<Isci>? tumIsciler,
    String? seciliIsciAdi,
    ValueChanged<Isci?>? onIsciSecildi,
  }) {
    return Consumer<PrivacyProvider>(
      builder: (context, privacy, child) {
        final String displayValue =
            controller.text.isEmpty
                ? ""
                : (privacy.isHidden && !isMultiLine ? "****" : controller.text);

        return InkWell(
          onTap: () {
            String? dialogSeciliIsciAdi = seciliIsciAdi;
            // Tıklayınca Odak Modunu Aç (Dialog)
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: "Kapat",
              barrierColor: Colors.black.withValues(
                alpha: 0.8,
              ), // Arka planı karart
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (ctx, anim1, anim2) {
                return Scaffold(
                  // Klavye yönetimi için Scaffold şart
                  backgroundColor: Colors.transparent,
                  body: StatefulBuilder(
                    builder:
                        (dialogContext, setDialogState) => Stack(
                          children: [
                            // Bulanıklık Efekti
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(color: Colors.transparent),
                            ),
                            // İçerik
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: controller,
                                      autofocus: true, // Otomatik klavye aç
                                      keyboardType:
                                          isMultiLine
                                              ? TextInputType.multiline
                                              : TextInputType.number,
                                      maxLines: isMultiLine ? 3 : 1,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        prefixIcon: Icon(
                                          icon,
                                          color: Colors.black87,
                                        ),
                                        suffixText: isMultiLine ? null : "TL",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 20,
                                              horizontal: 20,
                                            ),
                                      ),
                                      onChanged: (val) {
                                        onChanged(); // Değişiklik var işaretle
                                      },
                                    ),
                                    if (!isMultiLine && tumIsciler != null) ...[
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final secilenIsci =
                                              await _harcamaIscisiSec(
                                                dialogContext,
                                                tumIsciler,
                                                dialogSeciliIsciAdi,
                                              );
                                          setDialogState(() {
                                            dialogSeciliIsciAdi =
                                                secilenIsci?.ad;
                                          });
                                          onIsciSecildi?.call(secilenIsci);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF22C55E,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.32,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.badge_outlined),
                                        label: Text(
                                          dialogSeciliIsciAdi == null ||
                                                  dialogSeciliIsciAdi!.isEmpty
                                              ? "\u0130\u015f\u00e7i Se\u00e7"
                                              : dialogSeciliIsciAdi!,
                                        ),
                                      ),
                                      if (dialogSeciliIsciAdi != null &&
                                          dialogSeciliIsciAdi!.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF22C55E,
                                            ).withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.34),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.credit_card_rounded,
                                                size: 18,
                                                color: Color(0xFF22C55E),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  "Kart\u0131 kullanan: $dialogSeciliIsciAdi",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "TAMAM",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text(
                                        "Kapat",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                );
              },
            ).then((_) {
              // Dialog kapanınca ana ekranı güncelle (değer değişmiş olabilir)
              onChanged();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 16),
                Expanded(
                  // Yazıyı sarmaladık, böylece taşma yapamaz
                  child: Text(
                    displayValue.isEmpty
                        ? "Girilmedi"
                        : "$displayValue${isMultiLine ? '' : ' TL'}",
                    textAlign: TextAlign.right, // Sağa yasla
                    maxLines: 1, // Tek satır olsun
                    overflow: TextOverflow.ellipsis, // Sığmazsa "..." koy
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          displayValue.isEmpty
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black),
                      fontSize: 16,
                    ),
                  ),
                ),
                // -------------------------------
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // YENİ KULLANICI ONBOARDING WIDGET'I
  // ==========================================
  Widget _buildOnboardingWidget({
    required BuildContext context,
    required bool isDark,
    required bool santiyelerBos,
    required bool iscilerBos,
  }) {
    const accent = Color(0xFF14B8A6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassSectionCard(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassIconBadge(
                icon: Icons.fact_check_outlined,
                color: accent,
                size: 82,
                iconSize: 34,
              ),
              const SizedBox(height: 18),
              Text(
                "Başlamak için hazır mısınız?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Günlük rapor oluşturabilmek için önce şantiye ve işçi eklemeniz gerekiyor.",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Şantiye Ekle Butonu
              if (santiyelerBos)
                Container(
                  key: _santiyeEkleKey,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.construction, size: 20),
                    label: const Text("Şantiye Ekle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        SayfaGecisi(
                          sayfa: SantiyeEkrani(teamId: widget.teamId),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                ),

              // İşçi Ekle Butonu
              if (!santiyelerBos && iscilerBos)
                Container(
                  key: _isciEkleKey,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text("İşçi Ekle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        SayfaGecisi(sayfa: IsciEkrani(teamId: widget.teamId)),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                ),

              // Durum bilgileri
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    santiyelerBos ? Icons.close : Icons.check_circle,
                    size: 16,
                    color: santiyelerBos ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    santiyelerBos ? "Şantiye yok" : "Şantiye ✓",
                    style: TextStyle(
                      color: santiyelerBos ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Icon(
                    iscilerBos ? Icons.close : Icons.check_circle,
                    size: 16,
                    color: iscilerBos ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    iscilerBos ? "İşçi yok" : "İşçi ✓",
                    style: TextStyle(
                      color: iscilerBos ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHazirlikChip({required String label, required bool aktif}) {
    final renk = aktif ? const Color(0xFF14B8A6) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: renk.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            aktif ? Icons.check_circle_rounded : Icons.close_rounded,
            size: 15,
            color: renk,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: renk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final genisBaslangic = DateTime(2024, 1, 1);
    final genisBitis = DateTime(2026, 12, 31);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: FloatingLiquidAppBar(
        title: 'Günlük Rapor',
        showPrivacyButton: false,
        showTourButton: true,
        onTourPressed: () => _turBaslat(manual: true),
      ),
      body: Stack(
        children: [
          GlassPageSurface(
            preferSoftLightBackground: true,
            child: StreamBuilder<List<GunlukSantiyeRaporu>>(
              stream: servisi.getRaporlarStream(
                widget.teamId,
                genisBaslangic,
                genisBitis,
              ),
              builder: (context, snapshotRaporlar) {
                if (!snapshotRaporlar.hasData) {
                  return const ShimmerYukleniyor(kartGorunumu: true);
                }
                final tumRaporlar = snapshotRaporlar.data!;
                List<GunlukSantiyeRaporu> gununEtkinlikleri(DateTime gun) {
                  return tumRaporlar
                      .where((rapor) => isSameDay(rapor.tarih, gun))
                      .toList();
                }

                final seciliGunRaporlari =
                    tumRaporlar
                        .where((r) => isSameDay(r.tarih, _seciliGun))
                        .toList();

                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      SizedBox(
                        height: FloatingLiquidAppBar.topPadding(
                          context,
                          extra: 4,
                        ),
                      ),
                      const OfflineSyncBanner(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: KeyedSubtree(
                          key: _dateBarKey,
                          child: GlassSectionCard(
                            padding: EdgeInsets.zero,
                            borderRadius: 22,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    tooltip: 'Önceki Gün',
                                    onPressed: () {
                                      setState(() {
                                        _seciliGun = _seciliGun.subtract(
                                          const Duration(days: 1),
                                        );
                                        _odaklanilanGun = _seciliGun;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap:
                                          () => setState(
                                            () =>
                                                _calendarVisible =
                                                    !_calendarVisible,
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 4,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    DateFormat.yMMMMEEEEd(
                                                      'tr_TR',
                                                    ).format(_seciliGun),
                                                    textAlign: TextAlign.center,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 15.5,
                                                    ),
                                                  ),
                                                ),
                                                if (isSameDay(
                                                  _seciliGun,
                                                  DateTime.now(),
                                                )) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF10B981,
                                                      ).withValues(
                                                        alpha:
                                                            isDark
                                                                ? 0.25
                                                                : 0.15,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFF10B981,
                                                        ).withValues(
                                                          alpha: 0.45,
                                                        ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Bugün",
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            isDark
                                                                ? const Color(
                                                                  0xFF6EE7B7,
                                                                )
                                                                : const Color(
                                                                  0xFF059669,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _calendarVisible
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  size: 16,
                                                  color:
                                                      isDark
                                                          ? Colors.white60
                                                          : const Color(
                                                            0xFF64748B,
                                                          ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _calendarVisible
                                                      ? "Takvimi Kapat"
                                                      : "Takvimi Göster",
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        isDark
                                                            ? Colors.white60
                                                            : const Color(
                                                              0xFF64748B,
                                                            ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isSameDay(_seciliGun, DateTime.now()))
                                    IconButton(
                                      icon: const Icon(
                                        Icons.today_rounded,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Bugüne Git',
                                      color:
                                          isDark
                                              ? const Color(0xFF5EEAD4)
                                              : const Color(0xFF0F766E),
                                      onPressed: () {
                                        setState(() {
                                          _seciliGun = DateTime.now();
                                          _odaklanilanGun = DateTime.now();
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 24,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    tooltip: 'Sonraki Gün',
                                    onPressed: () {
                                      setState(() {
                                        _seciliGun = _seciliGun.add(
                                          const Duration(days: 1),
                                        );
                                        _odaklanilanGun = _seciliGun;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_calendarVisible)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: GlassSectionCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: TableCalendar(
                              locale: 'tr_TR',
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              firstDay: genisBaslangic,
                              lastDay: genisBitis,
                              focusedDay: _odaklanilanGun,
                              currentDay: _seciliGun,
                              rowHeight: 38,
                              daysOfWeekHeight: 22,
                              eventLoader: gununEtkinlikleri,
                              calendarStyle: CalendarStyle(
                                isTodayHighlighted: true,
                                cellMargin: const EdgeInsets.all(2.5),
                                cellPadding: EdgeInsets.zero,
                                defaultTextStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                                weekendTextStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? const Color(
                                            0xFF5EEAD4,
                                          ).withValues(alpha: 0.8)
                                          : const Color(0xFF0F7C86),
                                ),
                                outsideTextStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color:
                                      isDark ? Colors.white24 : Colors.black26,
                                ),
                                selectedTextStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                todayTextStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? const Color(0xFF5EEAD4)
                                          : const Color(0xFF0F7C86),
                                ),
                                defaultDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                weekendDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                outsideDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                todayDecoration: BoxDecoration(
                                  color: const Color(
                                    0xFF14B8A6,
                                  ).withValues(alpha: isDark ? 0.22 : 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF14B8A6,
                                    ).withValues(alpha: isDark ? 0.6 : 0.45),
                                    width: 1.2,
                                  ),
                                ),
                                selectedDecoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF14B8A6),
                                      Color(0xFF0D9488),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0D9488,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                markerDecoration: const BoxDecoration(
                                  color: Color(0xFF14B8A6),
                                  shape: BoxShape.circle,
                                ),
                                markerSize: 4.5,
                                markerMargin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                markersMaxCount: 3,
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                headerPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                titleTextStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                                leftChevronPadding: const EdgeInsets.all(4),
                                rightChevronPadding: const EdgeInsets.all(4),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 20,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF516772),
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF516772),
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                ),
                                weekendStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? const Color(0xFF5EEAD4)
                                          : const Color(0xFF0F7C86),
                                ),
                              ),
                              onDaySelected:
                                  (s, f) => setState(() {
                                    _seciliGun = s;
                                    _odaklanilanGun = f;
                                  }),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _buildDemoDailyReportCard(isDark),
                      Expanded(
                        child: StreamBuilder<List<Santiye>>(
                          stream: servisi.getSantiyelerStream(widget.teamId),
                          builder: (context, snapshotSantiyeler) {
                            if (!snapshotSantiyeler.hasData) {
                              return const ShimmerYukleniyor(satirSayisi: 4);
                            }
                            final santiyeler = snapshotSantiyeler.data!;
                            return StreamBuilder<List<Isci>>(
                              stream: servisi.getIscilerStream(widget.teamId),
                              builder: (context, snapshotIsciler) {
                                if (!snapshotIsciler.hasData ||
                                    snapshotIsciler.connectionState ==
                                        ConnectionState.waiting) {
                                  return const ShimmerYukleniyor(
                                    satirSayisi: 4,
                                  );
                                }
                                final tumIsciler = snapshotIsciler.data ?? [];

                                // Yeni kullanıcı için onboarding kontrolü
                                if (!_isTourActive &&
                                    (santiyeler.isEmpty ||
                                        tumIsciler.isEmpty)) {
                                  return _buildOnboardingWidget(
                                    context: context,
                                    isDark: isDark,
                                    santiyelerBos: santiyeler.isEmpty,
                                    iscilerBos: tumIsciler.isEmpty,
                                  );
                                }

                                final int toplamSantiye = santiyeler.length;
                                final int raporlananSantiye =
                                    santiyeler
                                        .where(
                                          (s) => seciliGunRaporlari.any(
                                            (r) => r.santiyeAdi == s.ad,
                                          ),
                                        )
                                        .length;
                                final double oran =
                                    toplamSantiye > 0
                                        ? (raporlananSantiye / toplamSantiye)
                                        : 0.0;
                                final int toplamCalisan = seciliGunRaporlari
                                    .fold(
                                      0,
                                      (sum, r) => sum + r.calisanlar.length,
                                    );
                                final double toplamMasraf = seciliGunRaporlari
                                    .fold(
                                      0.0,
                                      (sum, r) =>
                                          sum +
                                          r.benzinGideri +
                                          r.yemekGideri +
                                          r.ekMasraflar,
                                    );

                                return ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    12,
                                    24,
                                  ),
                                  itemCount: santiyeler.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _buildGunlukOzetBanner(
                                        context: context,
                                        isDark: isDark,
                                        toplamSantiye: toplamSantiye,
                                        raporlananSantiye: raporlananSantiye,
                                        oran: oran,
                                        toplamCalisan: toplamCalisan,
                                        toplamMasraf: toplamMasraf,
                                      );
                                    }

                                    final santiyeIndex = index - 1;
                                    final santiyeAdi =
                                        santiyeler[santiyeIndex].ad;
                                    final mevcutRapor =
                                        seciliGunRaporlari
                                            .where(
                                              (r) => r.santiyeAdi == santiyeAdi,
                                            )
                                            .firstOrNull;
                                    final bool dolu = mevcutRapor != null;

                                    if (dolu) {
                                      return Container(
                                        key:
                                            santiyeIndex == 0
                                                ? _santiyeKartiKey
                                                : null,
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors:
                                                isDark
                                                    ? [
                                                      const Color(
                                                        0xFF10B981,
                                                      ).withValues(alpha: 0.16),
                                                      const Color(
                                                        0xFF0F172A,
                                                      ).withValues(alpha: 0.88),
                                                    ]
                                                    : [
                                                      const Color(0xFFF0FDF4),
                                                      Colors.white,
                                                    ],
                                          ),
                                          border: Border.all(
                                            color:
                                                isDark
                                                    ? const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.60)
                                                    : const Color(
                                                      0xFF059669,
                                                    ).withValues(alpha: 0.45),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(
                                                alpha: isDark ? 0.18 : 0.08,
                                              ),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            onTap:
                                                () => _raporDuzenle(
                                                  context,
                                                  servisi,
                                                  santiyeAdi,
                                                  mevcutRapor,
                                                  tumIsciler,
                                                  seciliGunRaporlari,
                                                  tumRaporlar,
                                                ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              9,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                                begin:
                                                                    Alignment
                                                                        .topLeft,
                                                                end:
                                                                    Alignment
                                                                        .bottomRight,
                                                                colors: [
                                                                  Color(
                                                                    0xFF10B981,
                                                                  ),
                                                                  Color(
                                                                    0xFF0D9488,
                                                                  ),
                                                                ],
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color:
                                                                  const Color(
                                                                    0xFF10B981,
                                                                  ).withValues(
                                                                    alpha: 0.35,
                                                                  ),
                                                              blurRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .apartment_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              santiyeAdi,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 16.5,
                                                                letterSpacing:
                                                                    -0.2,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  width: 6.5,
                                                                  height: 6.5,
                                                                  decoration: const BoxDecoration(
                                                                    color: Color(
                                                                      0xFF10B981,
                                                                    ),
                                                                    shape:
                                                                        BoxShape
                                                                            .circle,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 5,
                                                                ),
                                                                Text(
                                                                  "Rapor Girildi",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        isDark
                                                                            ? const Color(
                                                                              0xFF6EE7B7,
                                                                            )
                                                                            : const Color(
                                                                              0xFF059669,
                                                                            ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFF10B981,
                                                          ).withValues(
                                                            alpha:
                                                                isDark
                                                                    ? 0.24
                                                                    : 0.15,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFF10B981,
                                                            ).withValues(
                                                              alpha: 0.6,
                                                            ),
                                                            width: 1.2,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .check_circle_rounded,
                                                              size: 14,
                                                              color: Color(
                                                                0xFF10B981,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              "GİRİLDİ",
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                letterSpacing:
                                                                    0.5,
                                                                color:
                                                                    isDark
                                                                        ? const Color(
                                                                          0xFF6EE7B7,
                                                                        )
                                                                        : const Color(
                                                                          0xFF047857,
                                                                        ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Consumer<PrivacyProvider>(
                                                    builder: (
                                                      context,
                                                      privacy,
                                                      child,
                                                    ) {
                                                      final toplam =
                                                          mevcutRapor
                                                              .benzinGideri +
                                                          mevcutRapor
                                                              .yemekGideri +
                                                          mevcutRapor
                                                              .ekMasraflar;
                                                      final tutarMetni =
                                                          privacy.isHidden
                                                              ? "**** TL"
                                                              : "${toplam.toStringAsFixed(2)} TL";

                                                      return Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isDark
                                                                  ? Colors.black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.28,
                                                                      )
                                                                  : const Color(
                                                                    0xFFF1F5F9,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                isDark
                                                                    ? Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.06,
                                                                        )
                                                                    : const Color(
                                                                      0xFFE2E8F0,
                                                                    ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .group_rounded,
                                                              size: 15,
                                                              color: Color(
                                                                0xFF0D9488,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 5,
                                                            ),
                                                            Text(
                                                              "${mevcutRapor.calisanlar.length} Çalışan",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    isDark
                                                                        ? Colors
                                                                            .white
                                                                        : const Color(
                                                                          0xFF1E293B,
                                                                        ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Container(
                                                              width: 1,
                                                              height: 14,
                                                              color: Colors.grey
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Expanded(
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .wallet_rounded,
                                                                    size: 15,
                                                                    color: Color(
                                                                      0xFF10B981,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      tutarMetni,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        color:
                                                                            isDark
                                                                                ? const Color(
                                                                                  0xFF5EEAD4,
                                                                                )
                                                                                : const Color(
                                                                                  0xFF0F766E,
                                                                                ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .chevron_right_rounded,
                                                              size: 18,
                                                              color:
                                                                  isDark
                                                                      ? const Color(
                                                                        0xFF5EEAD4,
                                                                      )
                                                                      : const Color(
                                                                        0xFF0F766E,
                                                                      ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  if (mevcutRapor.aciklama
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            isDark
                                                                ? Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.04,
                                                                    )
                                                                : const Color(
                                                                  0xFFF8FAFC,
                                                                ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            "📝 ",
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              mevcutRapor
                                                                  .aciklama
                                                                  .trim(),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                                color:
                                                                    isDark
                                                                        ? Colors
                                                                            .white70
                                                                        : const Color(
                                                                          0xFF475569,
                                                                        ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // Rapor girilmemiş (bekliyor) şantiye kartı
                                    return Container(
                                      key:
                                          santiyeIndex == 0
                                              ? _santiyeKartiKey
                                              : null,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        color:
                                            isDark
                                                ? const Color(
                                                  0xFF1E293B,
                                                ).withValues(alpha: 0.45)
                                                : Colors.white.withValues(
                                                  alpha: 0.90,
                                                ),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                  : const Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.12 : 0.03,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          onTap:
                                              () => _raporDuzenle(
                                                context,
                                                servisi,
                                                santiyeAdi,
                                                mevcutRapor,
                                                tumIsciler,
                                                seciliGunRaporlari,
                                                tumRaporlar,
                                              ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    9,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                )
                                                            : const Color(
                                                              0xFFF1F5F9,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.apartment_outlined,
                                                    color:
                                                        isDark
                                                            ? Colors.white38
                                                            : const Color(
                                                              0xFF94A3B8,
                                                            ),
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        santiyeAdi,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                          color:
                                                              isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : const Color(
                                                                    0xFF334155,
                                                                  ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .white24
                                                                      : const Color(
                                                                        0xFFCBD5E1,
                                                                      ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            "Henüz rapor girilmedi",
                                                            style: TextStyle(
                                                              fontSize: 11.5,
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .white38
                                                                      : const Color(
                                                                        0xFF94A3B8,
                                                                      ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                )
                                                            : const Color(
                                                              0xFFF8FAFC,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  )
                                                              : const Color(
                                                                0xFFCBD5E1,
                                                              ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.add_rounded,
                                                        size: 14,
                                                        color:
                                                            isDark
                                                                ? Colors.white70
                                                                : const Color(
                                                                  0xFF475569,
                                                                ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        "Rapor Gir",
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : const Color(
                                                                    0xFF475569,
                                                                  ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isTourActive)
            InteractiveTourOverlay(
              steps: _buildTourSteps(),
              onFinish: _turSonlandir,
              onSkip: _turSonlandir,
            ),
        ],
      ),
    );
  }
}
