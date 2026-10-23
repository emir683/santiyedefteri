import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    // Pazartesi'yi 1 kabul eder
    final weekday = tarih.weekday;
    final baslangic = tarih.subtract(Duration(days: weekday - 1));
    return DateTime(baslangic.year, baslangic.month, baslangic.day, 0, 0, 0);
  }

  DateTime _haftaBitisi(DateTime haftaBasi) {
    return haftaBasi.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  void _haftaDegistir(int offset) {
    setState(() {
      _seciliHaftaOfseti = offset;
    });
  }

  String _formatTutar(double tutar) {
    return NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0)
        .format(tutar);
  }

  void _ozetiKopyala(
    DateTime baslangic,
    DateTime bitis,
    int raporSayisi,
    int calisanYevmiye,
    double toplamGider,
    Map<String, int> santiyeSayilari,
  ) {
    final dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final buffer = StringBuffer();
    buffer.writeln("📊 *ŞANTİYE HAFTALIK DURUM ÖZETİ*");
    buffer.writeln("📅 Tarih: ${dateFormat.format(baslangic)} - ${dateFormat.format(bitis)}");
    buffer.writeln("─────────────────────────");
    buffer.writeln("📋 Toplam Rapor: $raporSayisi adet");
    buffer.writeln("👷 Toplam Puantaj: $calisanYevmiye yevmiye");
    buffer.writeln("💰 Toplam Saha Gideri: ${_formatTutar(toplamGider)}");
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
      const SnackBar(
        content: Text('Haftalık özet panoya kopyalandı! WhatsApp ile paylaşabilirsiniz.'),
        backgroundColor: _kBrandTeal,
        behavior: SnackBarBehavior.floating,
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
    final seciliHaftaBasi = buHaftaBasi.add(Duration(days: _seciliHaftaOfseti * 7));
    final seciliHaftaSonu = _haftaBitisi(seciliHaftaBasi);

    final dateFormat = DateFormat('dd MMMM', 'tr_TR');
    final haftaMetni =
        "${dateFormat.format(seciliHaftaBasi)} - ${dateFormat.format(seciliHaftaSonu)}";

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: 'Haftalık Durum Özeti',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: SafeArea(
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

              // İstatistikleri hesapla
              int toplamRapor = raporlar.length;
              int toplamYevmiye = 0;
              double toplamGider = 0;
              final Map<String, int> santiyeRaporSayisi = {};
              final Map<int, int> gunlukRaporSayisi = {
                1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
              };
              final Map<String, double> isciYevmiyeleri = {};

              for (final rapor in raporlar) {
                toplamGider += rapor.benzinGideri + rapor.yemekGideri + rapor.ekMasraflar;
                santiyeRaporSayisi[rapor.santiyeAdi] =
                    (santiyeRaporSayisi[rapor.santiyeAdi] ?? 0) + 1;
                final w = rapor.tarih.weekday;
                gunlukRaporSayisi[w] = (gunlukRaporSayisi[w] ?? 0) + 1;

                for (final calisma in rapor.calisanlar) {
                  toplamYevmiye++;
                  final isciAd = calisma.isci.ad;
                  double carpan = 1.0;
                  if (calisma.durum.contains('Yarım')) carpan = 0.5;
                  if (calisma.durum.contains('Mesai')) carpan = 1.5;
                  isciYevmiyeleri[isciAd] =
                      (isciYevmiyeleri[isciAd] ?? 0) + carpan;
                }
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  FloatingLiquidAppBar.topPadding(context, extra: 4),
                  16,
                  32,
                ),
                children: [
                  // Hafta Seçim Sekmesi
                  _buildWeekSelector(isDark),
                  const SizedBox(height: 14),

                  // Tarih Aralığı Kartı
                  GlassSectionCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _kBrandTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.date_range_rounded,
                            color: _kBrandTeal,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _seciliHaftaOfseti == 0
                                    ? 'Bu Hafta'
                                    : (_seciliHaftaOfseti == -1
                                        ? 'Geçen Hafta'
                                        : '${_seciliHaftaOfseti.abs()} Hafta Önce'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                haftaMetni,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Özeti Paylaş',
                          onPressed: () => _ozetiKopyala(
                            seciliHaftaBasi,
                            seciliHaftaSonu,
                            toplamRapor,
                            toplamYevmiye,
                            toplamGider,
                            santiyeRaporSayisi,
                          ),
                          icon: const Icon(Icons.share_rounded, color: _kBrandTeal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (raporlar.isEmpty) ...[
                    const SizedBox(height: 20),
                    const GlassEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: 'Bu Haftaya Ait Kayıt Yok',
                      description:
                          'Seçili hafta aralığında girilmiş günlük şantiye raporu veya puantaj bulunamadı.',
                    ),
                  ] else ...[
                    // KPI Izgarası (4'lü Kart)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.45,
                      children: [
                        _buildKpiCard(
                          isDark: isDark,
                          icon: Icons.edit_calendar_rounded,
                          color: const Color(0xFF10B981),
                          title: 'Rapor Sayısı',
                          value: '$toplamRapor Adet',
                        ),
                        _buildKpiCard(
                          isDark: isDark,
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFF3B82F6),
                          title: 'Toplam Puantaj',
                          value: '$toplamYevmiye Yevmiye',
                        ),
                        _buildKpiCard(
                          isDark: isDark,
                          icon: Icons.domain_rounded,
                          color: const Color(0xFF8B5CF6),
                          title: 'Aktif Şantiye',
                          value: '${santiyeRaporSayisi.length} Proje',
                        ),
                        _buildKpiCard(
                          isDark: isDark,
                          icon: Icons.payments_rounded,
                          color: _kBrandTeal,
                          title: 'Saha Gideri',
                          value: _formatTutar(toplamGider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Haftalık Günlük Çizelge
                    Text(
                      'Haftalık Rapor Dağılımı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDailyChart(gunlukRaporSayisi, isDark),
                    const SizedBox(height: 22),

                    // Şantiyeler Dağılımı
                    Text(
                      'Şantiyelere Göre Dağılım',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...santiyeRaporSayisi.entries.map((entry) {
                      final oran = toplamRapor > 0 ? entry.value / toplamRapor : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassSectionCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${entry.value} Gün',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _kBrandTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: oran,
                                  minHeight: 7,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFD8EAF0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    _kBrandTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Çalışan İşçiler Özeti
                    if (isciYevmiyeleri.isNotEmpty) ...[
                      Text(
                        'Bu Hafta Çalışanlar (${isciYevmiyeleri.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassSectionCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Column(
                          children: isciYevmiyeleri.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _kBrandTeal.withValues(alpha: 0.12),
                                    child: Text(
                                      e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: _kBrandTeal,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${e.value.toStringAsFixed(e.value.truncateToDouble() == e.value ? 0 : 1)} Gün',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : const Color(0xFF334E68),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSelector(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildWeekTab(
            title: 'Bu Hafta',
            isSelected: _seciliHaftaOfseti == 0,
            onTap: () => _haftaDegistir(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildWeekTab(
            title: 'Geçen Hafta',
            isSelected: _seciliHaftaOfseti == -1,
            onTap: () => _haftaDegistir(-1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildWeekTab(
            title: '2 Hafta Önce',
            isSelected: _seciliHaftaOfseti == -2,
            onTap: () => _haftaDegistir(-2),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _kBrandTeal
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF101317)
                  : const Color(0xFFE6F3F6)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kBrandTeal : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : const Color(0xFF486581)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return GlassSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF627D98),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart(Map<int, int> gunlukRapor, bool isDark) {
    const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    int maxRapor = 1;
    for (var count in gunlukRapor.values) {
      if (count > maxRapor) maxRapor = count;
    }

    return GlassSectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final gunNo = index + 1;
          final count = gunlukRapor[gunNo] ?? 0;
          final double barHeight = count > 0 ? (count / maxRapor) * 60 + 12 : 6;
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
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  color: hasActivity
                      ? _kBrandTeal
                      : (isDark ? Colors.white12 : const Color(0xFFD8EAF0)),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gunler[index],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: hasActivity ? FontWeight.w700 : FontWeight.w500,
                  color: hasActivity
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
}
