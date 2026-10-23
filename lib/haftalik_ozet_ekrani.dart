import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'animasyon_yardimcisi.dart';
import 'data_models.dart';
import 'firestore_servisi.dart';
import 'user_model.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';
import 'widgets/glass_empty_state.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class HaftalikOzetEkrani extends StatefulWidget {
  final String teamId;
  const HaftalikOzetEkrani({super.key, required this.teamId});

  @override
  State<HaftalikOzetEkrani> createState() => _HaftalikOzetEkraniState();
}

class _HaftalikOzetEkraniState extends State<HaftalikOzetEkrani> {
  int _seciliHaftaOfseti = 0; // 0: Bu hafta, -1: Geçen hafta, -2: 2 hafta önce

  DateTime _haftaBaslangici(DateTime tarih) {
    // Pazartesi gününü 1 kabul eder
    final weekday = tarih.weekday;
    final baslangic = tarih.subtract(Duration(days: weekday - 1));
    return DateTime(baslangic.year, baslangic.month, baslangic.day, 0, 0, 0);
  }

  DateTime _haftaBitisi(DateTime haftaBasi) {
    return haftaBasi.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
  }

  void _haftaDegistir(int offset) {
    HapticFeedback.selectionClick();
    setState(() {
      _seciliHaftaOfseti = offset;
    });
  }

  String _formatTutar(double tutar) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    ).format(tutar);
  }

  void _ozetiKopyala(
    DateTime baslangic,
    DateTime bitis,
    int raporSayisi,
    double calisanYevmiye,
    double toplamGider,
    double benzinGideri,
    double yemekGideri,
    double ekGideri,
    Map<String, int> santiyeSayilari,
  ) {
    HapticFeedback.mediumImpact();
    final dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final buffer = StringBuffer();
    buffer.writeln("📊 *ŞANTİYE HAFTALIK DURUM ÖZETİ*");
    buffer.writeln(
      "📅 Tarih: ${dateFormat.format(baslangic)} - ${dateFormat.format(bitis)}",
    );
    buffer.writeln("─────────────────────────");
    buffer.writeln("📋 Toplam Rapor: $raporSayisi adet");
    buffer.writeln(
      "👷 Toplam Puantaj: ${calisanYevmiye.toStringAsFixed(calisanYevmiye.truncateToDouble() == calisanYevmiye ? 0 : 1)} yevmiye",
    );
    buffer.writeln("💰 Toplam Saha Gideri: ${_formatTutar(toplamGider)}");
    if (toplamGider > 0) {
      buffer.writeln("   • Akaryakıt: ${_formatTutar(benzinGideri)}");
      buffer.writeln("   • Yemek: ${_formatTutar(yemekGideri)}");
      buffer.writeln("   • Ek Masraflar: ${_formatTutar(ekGideri)}");
    }
    buffer.writeln("─────────────────────────");
    buffer.writeln("🏗️ *Aktif Şantiyeler:*");
    if (santiyeSayilari.isEmpty) {
      buffer.writeln("  - Bu hafta rapor girilmedi.");
    } else {
      santiyeSayilari.forEach((ad, count) {
        buffer.writeln("  • $ad: $count gün çalışma");
      });
    }
    buffer.writeln("─────────────────────────");
    buffer.writeln("📱 Şantiye Puantaj Defteri ile hazırlandı.");

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Haftalık özet panoya kopyalandı! WhatsApp ile paylaşabilirsiniz.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F7C86),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // --- ANA EKRANDAKİ BİREBİR KUTUCUK TASARIMLARI (1-to-1) ---

  Widget _buildPanelGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF15181D) : const Color(0xFFE7EEF1))
                .withValues(alpha: isDark ? 0.96 : 0.90),
            (isDark ? const Color(0xFF090B0F) : const Color(0xFFD6E1E6))
                .withValues(alpha: isDark ? 0.98 : 0.94),
          ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFBFD0D6).withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(
              0xFF79E9D7,
            ).withValues(alpha: isDark ? 0.03 : 0.08),
            blurRadius: isDark ? 12 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildPanelGlassInset({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF171A1F) : const Color(0xFFE0EAEE))
                .withValues(alpha: isDark ? 0.88 : 0.82),
            (isDark ? const Color(0xFF0D0F13) : const Color(0xFFCCD9DE))
                .withValues(alpha: isDark ? 0.96 : 0.90),
          ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFBFD0D6).withValues(alpha: 0.88),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildPanelGlassIconBadge({
    required IconData icon,
    required Color accentColor,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = compact ? 38.0 : 48.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: isDark ? 0.20 : 0.18),
            (isDark ? const Color(0xFF15313A) : const Color(0xFFE9F8FA))
                .withValues(alpha: isDark ? 0.72 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.14),
        ),
      ),
      child: Center(
        child: Icon(icon, color: accentColor, size: compact ? 18 : 24),
      ),
    );
  }

  Widget _buildOverviewMiniCardMinimal({
    required IconData icon,
    required String value,
    required String label,
    VoidCallback? onTap,
    String? heroTag,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = _buildPanelGlassInset(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF0F7C86),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (heroTag != null) {
      content = Hero(
        tag: heroTag,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return Material(
            type: MaterialType.transparency,
            child: toHeroContext.widget,
          );
        },
        child: Material(type: MaterialType.transparency, child: content),
      );
    }

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }

  Widget _buildWorkerChipMinimal(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF102A43),
        ),
      ),
    );
  }

  void _showExpandedMiniCard(
    String heroTag,
    IconData icon,
    String label,
    String value,
    String details, {
    Widget? detailsWidget,
  }) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: (
                      flightContext,
                      animation,
                      flightDirection,
                      fromHeroContext,
                      toHeroContext,
                    ) {
                      return Material(
                        type: MaterialType.transparency,
                        child: toHeroContext.widget,
                      );
                    },
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildPanelGlassCard(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 24,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : const Color(0xFF0F7C86),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : Colors.black87,
                                    ),
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                details,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                  height: 1.5,
                                  fontSize: 14.5,
                                ),
                              ),
                              if (detailsWidget != null) ...[
                                const SizedBox(height: 16),
                                detailsWidget,
                              ],
                            ],
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final buHaftaBasi = _haftaBaslangici(now);
    final seciliHaftaBasi = buHaftaBasi.add(
      Duration(days: _seciliHaftaOfseti * 7),
    );
    final seciliHaftaSonu = _haftaBitisi(seciliHaftaBasi);

    final dateFormat = DateFormat('dd MMMM', 'tr_TR');
    final haftaMetni =
        "${dateFormat.format(seciliHaftaBasi)} - ${dateFormat.format(seciliHaftaSonu)}";

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: 'Haftalık Durum Özeti',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Stack(
          children: [
            // Ana Ekrandaki Birebir Üst Teal Gölgeleme Gradienti
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B5D68).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ana Ekrandaki Birebir Alt Radial Teal Işıma Katmanı
            Positioned(
              left: -40,
              right: -40,
              bottom: -28,
              child: IgnorePointer(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 0.92,
                      colors: [
                        const Color(
                          0xFF5EEAD4,
                        ).withValues(alpha: isDark ? 0.14 : 0.18),
                        const Color(
                          0xFFB6F5ED,
                        ).withValues(alpha: isDark ? 0.08 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: StreamBuilder<List<GunlukSantiyeRaporu>>(
                stream: servisi.getRaporlarStream(
                  widget.teamId,
                  seciliHaftaBasi,
                  seciliHaftaSonu,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _kBrandTeal),
                    );
                  }

                  final raporlar = snapshot.data ?? [];

                  int toplamRapor = raporlar.length;
                  double toplamYevmiye = 0;
                  double toplamGider = 0;
                  double toplamBenzin = 0;
                  double toplamYemek = 0;
                  double toplamEk = 0;

                  final Map<String, int> santiyeRaporSayisi = {};
                  final Map<String, double> santiyeMasraflari = {};
                  final Map<int, int> gunlukRaporSayisi = {
                    1: 0,
                    2: 0,
                    3: 0,
                    4: 0,
                    5: 0,
                    6: 0,
                    7: 0,
                  };
                  final Map<String, double> isciYevmiyeleri = {};
                  final Set<String> buHaftaCalisanlar = {};
                  final Set<String> buHaftaSantiyeler = {};

                  for (final rapor in raporlar) {
                    toplamGider +=
                        rapor.benzinGideri +
                        rapor.yemekGideri +
                        rapor.ekMasraflar;
                    toplamBenzin += rapor.benzinGideri;
                    toplamYemek += rapor.yemekGideri;
                    toplamEk += rapor.ekMasraflar;

                    buHaftaSantiyeler.add(rapor.santiyeAdi);
                    santiyeRaporSayisi[rapor.santiyeAdi] =
                        (santiyeRaporSayisi[rapor.santiyeAdi] ?? 0) + 1;
                    santiyeMasraflari[rapor.santiyeAdi] =
                        (santiyeMasraflari[rapor.santiyeAdi] ?? 0) +
                        rapor.benzinGideri +
                        rapor.yemekGideri +
                        rapor.ekMasraflar;

                    final w = rapor.tarih.weekday;
                    gunlukRaporSayisi[w] = (gunlukRaporSayisi[w] ?? 0) + 1;

                    for (final calisma in rapor.calisanlar) {
                      final isciAd = calisma.isci.ad;
                      buHaftaCalisanlar.add(isciAd);
                      final carpan = parseDurumCarpani(calisma.durum);
                      toplamYevmiye += carpan;
                      isciYevmiyeleri[isciAd] =
                          (isciYevmiyeleri[isciAd] ?? 0) + carpan;
                    }
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      FloatingLiquidAppBar.topPadding(context, extra: 8),
                      16,
                      120,
                    ),
                    children: [
                      // Başlık Alanı (Ana Menüdeki "Kontrol Merkezi" tasarım hiyerarşisi)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HAFTALIK SAHA ANALİZİ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color:
                                    isDark
                                        ? const Color(0xFF5EEAD4)
                                        : const Color(0xFF0F7C86),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Durum Özeti',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Hafta Seçim Sekmesi (Ana ekrandaki Inset Surface tasarımı)
                      _buildWeekSelector(isDark),
                      const SizedBox(height: 16),

                      // 1. ANA ÖZET KARTI (Birebir _buildTodayOverviewCardMinimal & _buildMonthSummaryCardMinimal)
                      _buildPanelGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _seciliHaftaOfseti == 0
                                            ? 'Bu Hafta'
                                            : (_seciliHaftaOfseti == -1
                                                ? 'Geçen Hafta'
                                                : '${_seciliHaftaOfseti.abs()} Hafta Önce'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          haftaMetni,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF102A43),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildPanelGlassInset(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    _seciliHaftaOfseti == 0
                                        ? 'Aktif Hafta'
                                        : 'Arşiv',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark
                                              ? const Color(0xFF5EEAD4)
                                              : const Color(0xFF0F7C86),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Birebir Ana Ekrandaki Mini Kartlar (2x2 Grid)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOverviewMiniCardMinimal(
                                    heroTag: 'week_summary_rapor',
                                    onTap:
                                        () => _showExpandedMiniCard(
                                          'week_summary_rapor',
                                          Icons.event_note_rounded,
                                          'Rapor Sayısı',
                                          '$toplamRapor Adet',
                                          'Seçili hafta boyunca girilen günlük şantiye raporları toplamıdır.',
                                        ),
                                    icon: Icons.event_note_rounded,
                                    value: '$toplamRapor Adet',
                                    label: 'Rapor Sayısı',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildOverviewMiniCardMinimal(
                                    heroTag: 'week_summary_yevmiye',
                                    onTap:
                                        () => _showExpandedMiniCard(
                                          'week_summary_yevmiye',
                                          Icons.groups_rounded,
                                          'Toplam Puantaj',
                                          '${toplamYevmiye.toStringAsFixed(toplamYevmiye.truncateToDouble() == toplamYevmiye ? 0 : 1)} Yevmiye',
                                          'Bu hafta sahada çalışan personellerin toplam yevmiye dökümü:',
                                          detailsWidget: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                buHaftaCalisanlar
                                                    .map(
                                                      (ad) =>
                                                          _buildWorkerChipMinimal(
                                                            ad,
                                                          ),
                                                    )
                                                    .toList(),
                                          ),
                                        ),
                                    icon: Icons.groups_rounded,
                                    value:
                                        '${toplamYevmiye.toStringAsFixed(toplamYevmiye.truncateToDouble() == toplamYevmiye ? 0 : 1)} Gün',
                                    label: 'Puantaj Toplamı',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOverviewMiniCardMinimal(
                                    heroTag: 'week_summary_santiye',
                                    onTap:
                                        () => _showExpandedMiniCard(
                                          'week_summary_santiye',
                                          Icons.apartment_rounded,
                                          'Aktif Şantiye',
                                          '${santiyeRaporSayisi.length} Proje',
                                          'Bu hafta çalışma yürütülen aktif şantiyeler:',
                                          detailsWidget: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                buHaftaSantiyeler
                                                    .map(
                                                      (ad) =>
                                                          _buildWorkerChipMinimal(
                                                            ad,
                                                          ),
                                                    )
                                                    .toList(),
                                          ),
                                        ),
                                    icon: Icons.apartment_rounded,
                                    value: '${santiyeRaporSayisi.length} Proje',
                                    label: 'Aktif Şantiye',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildOverviewMiniCardMinimal(
                                    heroTag: 'week_summary_masraf',
                                    onTap:
                                        () => _showExpandedMiniCard(
                                          'week_summary_masraf',
                                          Icons.receipt_long_rounded,
                                          'Saha Gideri',
                                          _formatTutar(toplamGider),
                                          'Bu haftanın şantiye saha gider kırılımı:',
                                          detailsWidget: Column(
                                            children: [
                                              _buildDetailCostRow(
                                                '⛽ Akaryakıt',
                                                toplamBenzin,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildDetailCostRow(
                                                '🍽️ Yemek',
                                                toplamYemek,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildDetailCostRow(
                                                '📦 Ek Masraflar',
                                                toplamEk,
                                              ),
                                            ],
                                          ),
                                        ),
                                    icon: Icons.receipt_long_rounded,
                                    value: _formatTutar(toplamGider),
                                    label: 'Toplam Masraf',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. HIZLI PAYLAŞIM VE WHATSAPP KARTI (Birebir _buildQuickReportCardMinimal)
                      AnimasyonluButon(
                        onPressed:
                            () => _ozetiKopyala(
                              seciliHaftaBasi,
                              seciliHaftaSonu,
                              toplamRapor,
                              toplamYevmiye,
                              toplamGider,
                              toplamBenzin,
                              toplamYemek,
                              toplamEk,
                              santiyeRaporSayisi,
                            ),
                        child: _buildPanelGlassCard(
                          child: Row(
                            children: [
                              _buildPanelGlassIconBadge(
                                icon: Icons.share_rounded,
                                accentColor: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Haftalık Özeti Paylaş',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'WhatsApp veya mesaj ile anında ilet.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (raporlar.isEmpty) ...[
                        const SizedBox(height: 20),
                        const GlassEmptyState(
                          icon: Icons.calendar_today_outlined,
                          title: 'Bu Haftaya Ait Kayıt Yok',
                          description:
                              'Seçili hafta aralığında girilmiş günlük şantiye raporu veya puantaj bulunamadı.',
                        ),
                      ] else ...[
                        // 3. HAFTALIK GÜNLÜK ÇİZELGE KARTI (Pzt - Paz)
                        _buildPanelGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Günlük Rapor Dağılımı',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pzt - Paz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDailyChart(gunlukRaporSayisi, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. ŞANTİYELERE GÖRE DAĞILIM VE SAHA GİDERLERİ
                        _buildPanelGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Şantiyelere Göre Dağılım',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildWorkerChipMinimal(
                                    '${santiyeRaporSayisi.length} Şantiye',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...santiyeRaporSayisi.entries.map((entry) {
                                final oran =
                                    toplamRapor > 0
                                        ? entry.value / toplamRapor
                                        : 0.0;
                                final santiyeMasraf =
                                    santiyeMasraflari[entry.key] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildPanelGlassInset(
                                    padding: const EdgeInsets.all(13),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildPanelGlassIconBadge(
                                              icon: Icons.apartment_rounded,
                                              accentColor: const Color(
                                                0xFF0F7C86,
                                              ),
                                              compact: true,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.key,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF102A43,
                                                              ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${entry.value} gün çalışma raporu',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color:
                                                          isDark
                                                              ? Colors.white60
                                                              : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _formatTutar(santiyeMasraf),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: _kBrandTeal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: oran,
                                            minHeight: 5,
                                            backgroundColor:
                                                isDark
                                                    ? Colors.white12
                                                    : const Color(0xFFD8EAF0),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(_kBrandTeal),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 5. BU HAFTA ÇALIŞAN PERSONEL LİSTESİ
                        if (isciYevmiyeleri.isNotEmpty) ...[
                          _buildPanelGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Personel Puantaj Dağılımı',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildWorkerChipMinimal(
                                      '${isciYevmiyeleri.length} Personel',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ...isciYevmiyeleri.entries.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildPanelGlassInset(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 11,
                                      ),
                                      child: Row(
                                        children: [
                                          _buildPanelGlassIconBadge(
                                            icon: Icons.person_rounded,
                                            accentColor: const Color(
                                              0xFF3B82F6,
                                            ),
                                            compact: true,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              e.key,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF102A43,
                                                        ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _kBrandTeal.withValues(
                                                alpha: isDark ? 0.20 : 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${e.value.toStringAsFixed(e.value.truncateToDouble() == e.value ? 0 : 1)} Gün',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: _kBrandTeal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 6. SAHA GİDERLERİ KIRILIMI KARTI
                        if (toplamGider > 0) ...[
                          _buildPanelGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Saha Harcama Dağılımı',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatTutar(toplamGider),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: _kBrandTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildExpenseItem(
                                  icon: Icons.local_gas_station_rounded,
                                  title: 'Akaryakıt / Yakıt',
                                  amount: toplamBenzin,
                                  total: toplamGider,
                                  accentColor: const Color(0xFFF59E0B),
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildExpenseItem(
                                  icon: Icons.restaurant_rounded,
                                  title: 'Yemek & Mutfak',
                                  amount: toplamYemek,
                                  total: toplamGider,
                                  accentColor: const Color(0xFFEC4899),
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildExpenseItem(
                                  icon: Icons.receipt_rounded,
                                  title: 'Ek Masraflar / Sarf',
                                  amount: toplamEk,
                                  total: toplamGider,
                                  accentColor: const Color(0xFF8B5CF6),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector(bool isDark) {
    return _buildPanelGlassInset(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _buildWeekTab(
              title: 'Bu Hafta',
              isSelected: _seciliHaftaOfseti == 0,
              onTap: () => _haftaDegistir(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildWeekTab(
              title: 'Geçen Hafta',
              isSelected: _seciliHaftaOfseti == -1,
              onTap: () => _haftaDegistir(-1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildWeekTab(
              title: '2 Hafta Önce',
              isSelected: _seciliHaftaOfseti == -2,
              onTap: () => _haftaDegistir(-2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F7C86) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF0F7C86).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color:
                    isSelected
                        ? Colors.white
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : const Color(0xFF486581)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyChart(Map<int, int> gunlukRapor, bool isDark) {
    const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    int maxRapor = 1;
    for (var count in gunlukRapor.values) {
      if (count > maxRapor) maxRapor = count;
    }

    return _buildPanelGlassInset(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final gunNo = index + 1;
          final count = gunlukRapor[gunNo] ?? 0;
          final double barHeight = count > 0 ? (count / maxRapor) * 58 + 10 : 6;
          final bool hasActivity = count > 0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasActivity ? '$count' : '',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kBrandTeal,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 20,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient:
                      hasActivity
                          ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF5EEAD4), Color(0xFF0F7C86)],
                          )
                          : null,
                  color:
                      hasActivity
                          ? null
                          : (isDark ? Colors.white12 : const Color(0xFFD8EAF0)),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow:
                      hasActivity
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFF0F7C86,
                              ).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gunler[index],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: hasActivity ? FontWeight.w700 : FontWeight.w500,
                  color:
                      hasActivity
                          ? (isDark ? Colors.white : const Color(0xFF102A43))
                          : (isDark ? Colors.white38 : const Color(0xFF829AB1)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildExpenseItem({
    required IconData icon,
    required String title,
    required double amount,
    required double total,
    required Color accentColor,
    required bool isDark,
  }) {
    final oran = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return _buildPanelGlassInset(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _buildPanelGlassIconBadge(
                icon: icon,
                accentColor: accentColor,
                compact: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatTutar(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
            ],
          ),
          if (amount > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: oran,
                minHeight: 4,
                backgroundColor:
                    isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCostRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatTutar(amount),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kBrandTeal,
            ),
          ),
        ),
      ],
    );
  }
}
