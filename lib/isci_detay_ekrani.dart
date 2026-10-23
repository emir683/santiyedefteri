import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'rol_provider.dart';
import 'format_yardimcisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

const double _shellDockBodyPadding = 132;
const Color _kBrandTealDark = Color(0xFF0F7C86);

class IsciDetayEkrani extends StatefulWidget {
  final Isci isci;
  final String teamId;

  const IsciDetayEkrani({super.key, required this.isci, required this.teamId});

  @override
  State<IsciDetayEkrani> createState() => _IsciDetayEkraniState();
}

class _IsciDetayEkraniState extends State<IsciDetayEkrani> {
  late DateTime _gosterilenAy;

  @override
  void initState() {
    super.initState();
    _gosterilenAy = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFinans = Provider.of<RolProvider>(context).isFinansalErisim;

    // Ayın başı ve sonu
    final baslangic = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final bitis = DateTime(
      _gosterilenAy.year,
      _gosterilenAy.month + 1,
      0,
      23,
      59,
      59,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: widget.isci.ad,
        showPrivacyButton: true,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Column(
          children: [
            SizedBox(
              height: FloatingLiquidAppBar.topPadding(context, extra: 0),
            ),
            // 1. TARİH SEÇİCİ (Modern)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF101317).withValues(alpha: 0.94)
                          : const Color(0xFFF7FBFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFD8EAF0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: _kBrandTealDark,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _gosterilenAy = DateTime(
                                  _gosterilenAy.year,
                                  _gosterilenAy.month - 1,
                                ),
                          ),
                    ),
                    Text(
                      DateFormat.yMMMM('tr_TR').format(_gosterilenAy),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: _kBrandTealDark,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _gosterilenAy = DateTime(
                                  _gosterilenAy.year,
                                  _gosterilenAy.month + 1,
                                ),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. VERİLERİ ÇEK (Raporlar + Avanslar)
            Expanded(
              child: StreamBuilder<List<GunlukSantiyeRaporu>>(
                stream: servisi.getRaporlarStream(
                  widget.teamId,
                  baslangic,
                  bitis,
                ),
                builder: (context, snapshotRaporlar) {
                  // Raporlar yüklenirken bekleme
                  if (!snapshotRaporlar.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<VerilenAvans>>(
                    stream: servisi.getAvanslarStream(widget.teamId),
                    builder: (context, snapshotAvanslar) {
                      // Avanslar yüklenirken bekleme
                      if (!snapshotAvanslar.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // --- HESAPLAMA MOTORU ---
                      final raporlar = snapshotRaporlar.data!;
                      final avanslar = snapshotAvanslar.data!;

                      // Listeyi oluşturacak veri havuzu
                      final tumHareketler = <Map<String, dynamic>>[];

                      int tamGun = 0;
                      int yarimGun = 0;
                      double toplamHakedis = 0;
                      double toplamAvans = 0;
                      double toplamKarsilananGider = 0;
                      final Map<String, List<Map<String, dynamic>>>
                      giderDetayGruplari = {};

                      bool isciEslesiyor({
                        required String? raporIsciId,
                        required String? raporIsciAdi,
                      }) {
                        final hedefId = widget.isci.id?.trim();
                        final raporId = raporIsciId?.trim();
                        if (hedefId != null &&
                            hedefId.isNotEmpty &&
                            raporId != null &&
                            raporId.isNotEmpty) {
                          return hedefId == raporId;
                        }
                        return (raporIsciAdi ?? '').trim().toLowerCase() ==
                            widget.isci.ad.trim().toLowerCase();
                      }

                      // 1. Çalışma Verilerini İşle
                      for (var rapor in raporlar) {
                        for (var calisma in rapor.calisanlar) {
                          if (calisma.isci.ad == widget.isci.ad) {
                            // İstatistikleri topla
                            final carpan = parseDurumCarpani(calisma.durum);
                            if (calisma.durum == "Tam Gün") {
                              tamGun++;
                            } else if (calisma.durum == "Yarım Gün") {
                              yarimGun++;
                            } else if (calisma.durum.contains("Mesai")) {
                              tamGun++;
                            }

                            // Listeye ekle
                            tumHareketler.add({
                              'tip': 'calisma',
                              'tarih': rapor.tarih,
                              'baslik': rapor.santiyeAdi,
                              'detay': calisma.durum,
                              'tutar': widget.isci.gunlukMaas * carpan,
                            });
                          }
                        }

                        if (rapor.benzinGideri > 0 &&
                            isciEslesiyor(
                              raporIsciId: rapor.benzinGideriIsciId,
                              raporIsciAdi: rapor.benzinGideriIsciAdi,
                            )) {
                          toplamKarsilananGider += rapor.benzinGideri;
                          tumHareketler.add({
                            'tip': 'gider',
                            'giderTipi': 'Benzin Gideri',
                            'tarih': rapor.tarih,
                            'baslik': rapor.santiyeAdi,
                            'detay': 'Benzin karşıladı',
                            'tutar': rapor.benzinGideri,
                          });
                          giderDetayGruplari
                              .putIfAbsent(
                                rapor.santiyeAdi,
                                () => <Map<String, dynamic>>[],
                              )
                              .add({
                                'tarih': rapor.tarih,
                                'kalem': 'Benzin',
                                'tutar': rapor.benzinGideri,
                              });
                        }

                        if (rapor.yemekGideri > 0 &&
                            isciEslesiyor(
                              raporIsciId: rapor.yemekGideriIsciId,
                              raporIsciAdi: rapor.yemekGideriIsciAdi,
                            )) {
                          toplamKarsilananGider += rapor.yemekGideri;
                          tumHareketler.add({
                            'tip': 'gider',
                            'giderTipi': 'Yemek Gideri',
                            'tarih': rapor.tarih,
                            'baslik': rapor.santiyeAdi,
                            'detay': 'Yemek karşıladı',
                            'tutar': rapor.yemekGideri,
                          });
                          giderDetayGruplari
                              .putIfAbsent(
                                rapor.santiyeAdi,
                                () => <Map<String, dynamic>>[],
                              )
                              .add({
                                'tarih': rapor.tarih,
                                'kalem': 'Yemek',
                                'tutar': rapor.yemekGideri,
                              });
                        }

                        if (rapor.ekMasraflar > 0 &&
                            isciEslesiyor(
                              raporIsciId: rapor.ekMasraflarIsciId,
                              raporIsciAdi: rapor.ekMasraflarIsciAdi,
                            )) {
                          toplamKarsilananGider += rapor.ekMasraflar;
                          tumHareketler.add({
                            'tip': 'gider',
                            'giderTipi': 'Ek Masraf',
                            'tarih': rapor.tarih,
                            'baslik': rapor.santiyeAdi,
                            'detay': 'Ek masraf karşıladı',
                            'tutar': rapor.ekMasraflar,
                          });
                          giderDetayGruplari
                              .putIfAbsent(
                                rapor.santiyeAdi,
                                () => <Map<String, dynamic>>[],
                              )
                              .add({
                                'tarih': rapor.tarih,
                                'kalem': 'Ek Masraf',
                                'tutar': rapor.ekMasraflar,
                              });
                        }
                      }

                      // 2. Avans Verilerini İşle (Sadece seçili ay)
                      for (var avans in avanslar) {
                        if (avans.isci.ad == widget.isci.ad &&
                            avans.tarih.year == _gosterilenAy.year &&
                            avans.tarih.month == _gosterilenAy.month) {
                          toplamAvans += avans.miktar;

                          tumHareketler.add({
                            'tip': 'avans',
                            'tarih': avans.tarih,
                            'baslik': "Avans Alındı",
                            'detay': "Ödeme",
                            'tutar':
                                -avans
                                    .miktar, // Eksi bakiye olarak gösterelim (görsel amaçlı)
                          });
                        }
                      }

                      // Maaş Hesabı
                      double toplamCalismaTutari = 0.0;
                      for (var h in tumHareketler) {
                        if (h['tip'] == 'calisma') {
                          toplamCalismaTutari += (h['tutar'] as num).toDouble();
                        }
                      }
                      toplamHakedis = toplamCalismaTutari;
                      double kalanAlacak =
                          toplamHakedis - toplamAvans + toplamKarsilananGider;

                      // Listeyi tarihe göre sırala
                      tumHareketler.sort(
                        (a, b) =>
                            (a['tarih'] as DateTime).compareTo(b['tarih']),
                      );

                      return Column(
                        children: [
                          // 3. ÖZET KARTI (HESAP TABLOSU)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors:
                                      isDark
                                          ? const [
                                            Color(0xFF182330),
                                            Color(0xFF10212A),
                                          ]
                                          : const [
                                            Color(0xFFEAF4F8),
                                            Color(0xFFDDECF3),
                                          ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFD8EAF0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.2 : 0.06,
                                    ),
                                    blurRadius: isDark ? 8 : 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 20,
                                            sections: [
                                              PieChartSectionData(
                                                color: _kBrandTealDark,
                                                value: tamGun.toDouble(),
                                                title:
                                                    tamGun > 0 ? '$tamGun' : '',
                                                radius: 15,
                                                titleStyle: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              PieChartSectionData(
                                                color: Colors.orangeAccent,
                                                value: yarimGun.toDouble(),
                                                title:
                                                    yarimGun > 0
                                                        ? '$yarimGun'
                                                        : '',
                                                radius: 15,
                                                titleStyle: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildSummaryItem(
                                              "Çalışılan",
                                              "${tamGun}T, ${yarimGun}Y",
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F2A44),
                                            ),
                                            _buildSummaryItem(
                                              "Hakediş",
                                              isFinans
                                                  ? "${toplamHakedis.toStringAsFixed(0)} ₺"
                                                  : "--",
                                              isDark
                                                  ? Colors.lightGreenAccent
                                                  : const Color(0xFF1B7F4D),
                                            ),
                                            _buildSummaryItem(
                                              "Avans",
                                              isFinans
                                                  ? "${toplamAvans.toStringAsFixed(0)} ₺"
                                                  : "--",
                                              isDark
                                                  ? Colors.orangeAccent
                                                  : const Color(0xFFB46900),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isFinans) ...[
                                    Divider(
                                      color:
                                          isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                      height: 24,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "KALAN ALACAK: ",
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "${kalanAlacak.toStringAsFixed(2)} TL",
                                          style: TextStyle(
                                            color:
                                                kalanAlacak >= 0
                                                    ? (isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF0F2A44,
                                                        ))
                                                    : Colors.redAccent,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Karşıladığı gider: ",
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "${toplamKarsilananGider.toStringAsFixed(2)} TL",
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? const Color(0xFF5EEAD4)
                                                    : const Color(0xFF0F7C86),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (giderDetayGruplari.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      TextButton.icon(
                                        onPressed:
                                            () => _giderDetayBottomSheetGoster(
                                              giderDetayGruplari,
                                            ),
                                        icon: const Icon(
                                          Icons.list_alt,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "Giderleri detaylandir",
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // ÖZET KARTININ ALTINDAKİ ŞIK PAYLAŞ BUTONU
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              0,
                              16.0,
                              10.0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors:
                                      isDark
                                          ? const [
                                            Color(0xFF0F766E),
                                            Color(0xFF14B8A6),
                                          ]
                                          : const [
                                            Color(0xFF0D9488),
                                            Color(0xFF14B8A6),
                                          ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0D9488,
                                    ).withValues(alpha: isDark ? 0.35 : 0.22),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    final donemStr = DateFormat.yMMMM(
                                      'tr_TR',
                                    ).format(_gosterilenAy);
                                    final metin = _isciRaporuMetniOlustur(
                                      donem: donemStr,
                                      tamGun: tamGun,
                                      yarimGun: yarimGun,
                                      toplamHakedis: toplamHakedis,
                                      toplamAvans: toplamAvans,
                                      toplamKarsilananGider:
                                          toplamKarsilananGider,
                                      kalanAlacak: kalanAlacak,
                                      isFinans: isFinans,
                                      tumHareketler: tumHareketler,
                                      giderDetayGruplari: giderDetayGruplari,
                                    );
                                    _paylasimMenusunuGoster(
                                      context: context,
                                      baslik:
                                          "${widget.isci.ad} - Rapor Paylaşımı",
                                      metin: metin,
                                      isDark: isDark,
                                      pdfDosyaAdi:
                                          "isci_raporu_${widget.isci.ad}_$donemStr.pdf",
                                      pdfOlusturucu:
                                          () => _isciRaporuPdfOlustur(
                                            donem: donemStr,
                                            tamGun: tamGun,
                                            yarimGun: yarimGun,
                                            toplamHakedis: toplamHakedis,
                                            toplamAvans: toplamAvans,
                                            toplamKarsilananGider:
                                                toplamKarsilananGider,
                                            kalanAlacak: kalanAlacak,
                                            isFinans: isFinans,
                                            tumHareketler: tumHareketler,
                                            giderDetayGruplari:
                                                giderDetayGruplari,
                                          ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.share_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.center,
                                            child: Text(
                                              "İşçi Raporunu Paylaş",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            "PDF & Metin",
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child:
                                tumHareketler.isEmpty
                                    ? Center(
                                      child: Text(
                                        "Bu ay kayıt bulunamadı.",
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        _shellDockBodyPadding,
                                      ),
                                      itemCount: tumHareketler.length,
                                      itemBuilder: (context, index) {
                                        final item = tumHareketler[index];
                                        final bool isAvans =
                                            item['tip'] == 'avans';
                                        final bool isGider =
                                            item['tip'] == 'gider';
                                        final double tutar =
                                            (item['tutar'] as double)
                                                .abs(); // Mutlak değer

                                        return Card(
                                          elevation: 2,
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color:
                                                  isAvans
                                                      ? Colors.red.withValues(
                                                        alpha: 0.3,
                                                      )
                                                      : isGider
                                                      ? Colors.orange
                                                          .withValues(
                                                            alpha: 0.3,
                                                          )
                                                      : Colors.green.withValues(
                                                        alpha: 0.3,
                                                      ),
                                              width: 1,
                                            ),
                                          ),
                                          color:
                                              isDark
                                                  ? const Color(0xFF101317)
                                                  : const Color(0xFFF7FBFD),
                                          child: ListTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color:
                                                    isAvans
                                                        ? Colors.red.withValues(
                                                          alpha: 0.1,
                                                        )
                                                        : isGider
                                                        ? Colors.orange
                                                            .withValues(
                                                              alpha: 0.1,
                                                            )
                                                        : Colors.green
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                isAvans
                                                    ? Icons.money_off
                                                    : isGider
                                                    ? Icons.receipt_long
                                                    : Icons.engineering,
                                                color:
                                                    isAvans
                                                        ? Colors.red
                                                        : isGider
                                                        ? Colors.orange
                                                        : Colors.green,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              item['baslik'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "${DateFormat('dd MMM EEEE', 'tr_TR').format(item['tarih'])} • ${item['detay']}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            trailing:
                                                isFinans
                                                    ? Text(
                                                      "${isAvans ? '-' : '+'}${tutar.toStringAsFixed(0)} ₺",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color:
                                                            isAvans
                                                                ? Colors.red
                                                                : isGider
                                                                ? Colors.orange
                                                                : Colors.green,
                                                      ),
                                                    )
                                                    : null,
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Özet Kartı İçin Yardımcı Widget
  Widget _buildSummaryItem(String title, String value, Color valueColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _giderDetayBottomSheetGoster(
    Map<String, List<Map<String, dynamic>>> gruplar,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final santiyeler = gruplar.keys.toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF0F1720) : const Color(0xFFF2FAFD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                const Text(
                  "Karsiladigi Gider Detayi",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  "Şantiye satırına dokunarak gün bazlı kayıtları açabilirsiniz.",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
                  ),
                ),
                const SizedBox(height: 12),
                ...santiyeler.map((santiye) {
                  final detaylar = [...gruplar[santiye] ?? []]..sort(
                    (a, b) => (b['tarih'] as DateTime).compareTo(
                      a['tarih'] as DateTime,
                    ),
                  );
                  final toplam = detaylar.fold<double>(
                    0.0,
                    (t, e) => t + (e['tutar'] as double),
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF11212B)
                              : const Color(0xFFEAF5FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF1E3A47)
                                : const Color(0xFFCCE3EC),
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 6,
                      ),
                      leading: const Icon(
                        Icons.domain_rounded,
                        color: Color(0xFF0F7C86),
                      ),
                      title: Text(
                        santiye,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text("${detaylar.length} kayıt • Detayı aç"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${toplam.toStringAsFixed(2)} TL",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.expand_more_rounded),
                        ],
                      ),
                      children:
                          detaylar.map((d) {
                            final tarih = d['tarih'] as DateTime;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(
                                left: 8,
                                right: 6,
                              ),
                              leading: const Icon(
                                Icons.receipt_long_rounded,
                                size: 18,
                                color: Color(0xFF0F7C86),
                              ),
                              title: Text("${d['kalem']}"),
                              subtitle: Text(
                                DateFormat(
                                  'd MMMM yyyy',
                                  'tr_TR',
                                ).format(tarih),
                              ),
                              trailing: Text(
                                "${(d['tutar'] as double).toStringAsFixed(2)} TL",
                              ),
                            );
                          }).toList(),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- İŞÇİ RAPOR METNİ OLUŞTURUCU ---
  String _isciRaporuMetniOlustur({
    required String donem,
    required int tamGun,
    required int yarimGun,
    required double toplamHakedis,
    required double toplamAvans,
    required double toplamKarsilananGider,
    required double kalanAlacak,
    required bool isFinans,
    required List<Map<String, dynamic>> tumHareketler,
    required Map<String, List<Map<String, dynamic>>> giderDetayGruplari,
  }) {
    final sb = StringBuffer();
    sb.writeln('📋 İŞÇİ ÇALIŞMA VE HAKEDİŞ RAPORU');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('👷 Personel: ${widget.isci.ad}');
    if (widget.isci.isciTuru.isNotEmpty) {
      sb.writeln('🏷️ Ekip Durumu: ${widget.isci.isciTuru}');
    }
    sb.writeln('📅 Dönem: $donem');
    sb.writeln('');

    final double toplamYevmiye = tamGun + (yarimGun * 0.5);
    final String yevmiyeStr =
        toplamYevmiye % 1 == 0
            ? toplamYevmiye.toInt().toString()
            : toplamYevmiye.toStringAsFixed(1);

    sb.writeln('📊 ÇALIŞMA ÖZETİ');
    sb.writeln('• Tam Gün: $tamGun gün');
    if (yarimGun > 0) {
      sb.writeln('• Yarım Gün: $yarimGun gün');
    }
    sb.writeln('• Toplam Yevmiye: $yevmiyeStr yevmiye');
    if (isFinans) {
      sb.writeln(
        '• Günlük Yevmiye: ${Formatlayici.yap(widget.isci.gunlukMaas)}',
      );
    }

    // Günlük Çalışma Çizelgesi (Hangi gün nerede çalıştı)
    final calismaHareketleri =
        tumHareketler.where((h) => h['tip'] == 'calisma').toList();
    if (calismaHareketleri.isNotEmpty) {
      sb.writeln('');
      sb.writeln('📅 GÜNLÜK ÇALIŞMA DETAYI (HANGİ GÜN NEREDE ÇALIŞTI)');
      sb.writeln('──────────────────────────────');
      for (final h in calismaHareketleri) {
        final t = h['tarih'] as DateTime;
        final tStr = DateFormat('dd.MM.yyyy EEEE', 'tr_TR').format(t);
        final sAdi = (h['baslik'] as String?) ?? 'Şantiye';
        final durum = (h['detay'] as String?) ?? 'Tam Gün';
        final tutarStr =
            isFinans
                ? ' (${Formatlayici.yap((h['tutar'] as num).toDouble())})'
                : '';
        sb.writeln('• $tStr');
        sb.writeln('  📍 $sAdi — $durum$tutarStr');
      }
    }

    // Çalışılan Şantiyeler Dağılımı
    final Map<String, double> santiyeCalismaGunleri = {};
    for (final h in calismaHareketleri) {
      final sAdi = (h['baslik'] as String?)?.trim() ?? 'Diğer';
      final durum = (h['detay'] as String?) ?? 'Tam Gün';
      final double gunDegeri = durum == 'Tam Gün' ? 1.0 : 0.5;
      santiyeCalismaGunleri[sAdi] =
          (santiyeCalismaGunleri[sAdi] ?? 0) + gunDegeri;
    }

    if (santiyeCalismaGunleri.isNotEmpty) {
      sb.writeln('');
      sb.writeln('🏢 ŞANTİYE DAĞILIMI (TOPLAM GÜN)');
      for (final entry in santiyeCalismaGunleri.entries) {
        final gunMetin =
            entry.value % 1 == 0
                ? '${entry.value.toInt()} gün'
                : '${entry.value.toStringAsFixed(1)} gün';
        sb.writeln('• ${entry.key}: $gunMetin');
      }
    }

    // Finansal Durum (yetki varsa)
    if (isFinans) {
      sb.writeln('');
      sb.writeln('💵 FİNANSAL HESAP');
      sb.writeln('• Toplam Hakediş: ${Formatlayici.yap(toplamHakedis)}');
      sb.writeln('• Alınan Avans: ${Formatlayici.yap(toplamAvans)}');
      if (toplamKarsilananGider > 0) {
        sb.writeln(
          '• Karşılanan Şantiye Masrafı: ${Formatlayici.yap(toplamKarsilananGider)}',
        );
      }
      sb.writeln('──────────────────────────────');
      sb.writeln('💰 NET KALAN ALACAK: ${Formatlayici.yap(kalanAlacak)}');
    }

    // Alınan Avanslar Listesi
    final avansHareketleri =
        tumHareketler.where((h) => h['tip'] == 'avans').toList();
    if (avansHareketleri.isNotEmpty && isFinans) {
      sb.writeln('');
      sb.writeln('💸 ALINAN AVANSLAR');
      for (final h in avansHareketleri) {
        final t = h['tarih'] as DateTime;
        final tStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(t);
        final tutar = (h['tutar'] as num).abs().toDouble();
        sb.writeln('• $tStr: ${Formatlayici.yap(tutar)}');
      }
    }

    // Varsa Karşıladığı Giderler Detayı
    if (giderDetayGruplari.isNotEmpty) {
      sb.writeln('');
      sb.writeln('⛽ KARŞILANAN GİDER DETAYLARI');
      for (final entry in giderDetayGruplari.entries) {
        sb.writeln('📍 ${entry.key}:');
        for (final g in entry.value) {
          final tarihStr = DateFormat(
            'dd.MM.yyyy',
          ).format(g['tarih'] as DateTime);
          final tutarVal = (g['tutar'] as num).toDouble();
          sb.writeln(
            '  - $tarihStr | ${g['kalem']}: ${Formatlayici.yap(tutarVal)}',
          );
        }
      }
    }

    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📱 Şantiye Yönetim Sistemi');
    return sb.toString();
  }

  // --- İŞÇİ RAPOR PDF OLUŞTURUCU ---
  Future<Uint8List> _isciRaporuPdfOlustur({
    required String donem,
    required int tamGun,
    required int yarimGun,
    required double toplamHakedis,
    required double toplamAvans,
    required double toplamKarsilananGider,
    required double kalanAlacak,
    required bool isFinans,
    required List<Map<String, dynamic>> tumHareketler,
    required Map<String, List<Map<String, dynamic>>> giderDetayGruplari,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final double toplamYevmiye = tamGun + (yarimGun * 0.5);
    final String yevmiyeStr =
        toplamYevmiye % 1 == 0
            ? toplamYevmiye.toInt().toString()
            : toplamYevmiye.toStringAsFixed(1);

    // Günlük Çalışma Hareketleri
    final calismaHareketleri =
        tumHareketler.where((h) => h['tip'] == 'calisma').toList();

    // Şantiyelere Göre Dağılım
    final Map<String, double> santiyeCalismaGunleri = {};
    for (final h in calismaHareketleri) {
      final sAdi = (h['baslik'] as String?)?.trim() ?? 'Diğer';
      final durum = (h['detay'] as String?) ?? 'Tam Gün';
      final double gunDegeri = durum == 'Tam Gün' ? 1.0 : 0.5;
      santiyeCalismaGunleri[sAdi] =
          (santiyeCalismaGunleri[sAdi] ?? 0) + gunDegeri;
    }

    // Avans Hareketleri
    final avansHareketleri =
        tumHareketler.where((h) => h['tip'] == 'avans').toList();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: ttf),
        build:
            (context) => [
              // 1. Üst Başlık Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F7C86'),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'İşçi Çalışma ve Hakediş Raporu',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Personel: ${widget.isci.ad} (${widget.isci.isciTuru})',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Dönem: $donem',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 10.5,
                            color: PdfColor.fromHex('#E0F2FE'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Şantiye Yönetim',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#E0F2FE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 2. Özet Bilgi Kartları
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPdfInfoCard(
                    'Toplam Çalışma',
                    '$yevmiyeStr Yevmiye ($tamGun Tam, $yarimGun Yarım)',
                    '#EFF6FF',
                    '#1D4ED8',
                    ttf,
                  ),
                  if (isFinans) ...[
                    _buildPdfInfoCard(
                      'Günlük Yevmiye',
                      Formatlayici.yap(widget.isci.gunlukMaas),
                      '#F0FDF4',
                      '#15803D',
                      ttf,
                    ),
                    _buildPdfInfoCard(
                      'Toplam Hakediş',
                      Formatlayici.yap(toplamHakedis),
                      '#F0FDF4',
                      '#166534',
                      ttf,
                    ),
                    _buildPdfInfoCard(
                      'Alınan Avans',
                      Formatlayici.yap(toplamAvans),
                      '#FEF2F2',
                      '#B91C1C',
                      ttf,
                    ),
                    if (toplamKarsilananGider > 0)
                      _buildPdfInfoCard(
                        'Karşılanan Masraf',
                        Formatlayici.yap(toplamKarsilananGider),
                        '#FFFBEB',
                        '#B45309',
                        ttf,
                      ),
                    _buildPdfInfoCard(
                      'Net Kalan Alacak',
                      Formatlayici.yap(kalanAlacak),
                      kalanAlacak >= 0 ? '#DCFCE7' : '#FEE2E2',
                      kalanAlacak >= 0 ? '#166534' : '#B91C1C',
                      ttf,
                      isBold: true,
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 18),

              // 3. Şantiyelere Göre Dağılım Tablosu
              if (santiyeCalismaGunleri.isNotEmpty) ...[
                _buildPdfSectionTitle('Şantiyelere Göre Çalışma Dağılımı', ttf),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    font: ttf,
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#334155'),
                  ),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  headers: ['Şantiye Adı', 'Çalışılan Gün / Yevmiye'],
                  data:
                      santiyeCalismaGunleri.entries.map((e) {
                        final gunStr =
                            e.value % 1 == 0
                                ? '${e.value.toInt()} gün'
                                : '${e.value.toStringAsFixed(1)} gün';
                        return [e.key, gunStr];
                      }).toList(),
                ),
                pw.SizedBox(height: 18),
              ],

              // 4. Günlük Çalışma Çizelgesi (Hangi gün nerede çalıştı)
              _buildPdfSectionTitle(
                'Günlük Çalışma Çizelgesi (Hangi Gün Nerede Çalıştı)',
                ttf,
              ),
              pw.SizedBox(height: 6),
              calismaHareketleri.isEmpty
                  ? pw.Text(
                    'Bu dönemde kayıtlı çalışma bulunmamaktadır.',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  )
                  : pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(
                      font: ttf,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0F7C86'),
                    ),
                    cellStyle: pw.TextStyle(font: ttf, fontSize: 8.5),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    headers: [
                      'Tarih',
                      'Gün',
                      'Şantiye',
                      'Çalışma Durumu',
                      if (isFinans) 'Hakediş',
                    ],
                    data:
                        calismaHareketleri.map((h) {
                          final t = h['tarih'] as DateTime;
                          return [
                            DateFormat('dd.MM.yyyy').format(t),
                            DateFormat('EEEE', 'tr_TR').format(t),
                            (h['baslik'] as String?) ?? '-',
                            (h['detay'] as String?) ?? 'Tam Gün',
                            if (isFinans)
                              Formatlayici.yap((h['tutar'] as num).toDouble()),
                          ];
                        }).toList(),
                  ),
              pw.SizedBox(height: 18),

              // 5. Varsa Avans Tablosu
              if (avansHareketleri.isNotEmpty && isFinans) ...[
                _buildPdfSectionTitle('Alınan Avans Kayıtları', ttf),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    font: ttf,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#DC2626'),
                  ),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 8.5),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  headers: ['Tarih', 'İşlem', 'Avans Tutarı'],
                  data:
                      avansHareketleri.map((h) {
                        final t = h['tarih'] as DateTime;
                        final tutar = (h['tutar'] as num).abs().toDouble();
                        return [
                          DateFormat('dd.MM.yyyy').format(t),
                          'Avans Ödemesi',
                          Formatlayici.yap(tutar),
                        ];
                      }).toList(),
                ),
                pw.SizedBox(height: 18),
              ],

              // 6. Varsa Karşılanan Gider Tablosu
              if (giderDetayGruplari.isNotEmpty) ...[
                _buildPdfSectionTitle(
                  'İşçinin Karşıladığı Şantiye Giderleri',
                  ttf,
                ),
                pw.SizedBox(height: 6),
                ...giderDetayGruplari.entries.map((entry) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Şantiye: ${entry.key}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.TableHelper.fromTextArray(
                        headerStyle: pw.TextStyle(
                          font: ttf,
                          fontSize: 8.5,
                          color: PdfColors.white,
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#D97706'),
                        ),
                        cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                        cellPadding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        headers: ['Tarih', 'Gider Kalemi', 'Tutar'],
                        data:
                            entry.value.map((g) {
                              final t = g['tarih'] as DateTime;
                              final val = (g['tutar'] as num).toDouble();
                              return [
                                DateFormat('dd.MM.yyyy').format(t),
                                '${g['kalem']}',
                                Formatlayici.yap(val),
                              ];
                            }).toList(),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                  );
                }),
                pw.SizedBox(height: 10),
              ],

              // Alt Bilgi Notu
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bu rapor Şantiye Puantaj ve Yönetim Sistemi ile üretilmiştir.',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Sayfa 1',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfInfoCard(
    String title,
    String value,
    String bgColorHex,
    String textColorHex,
    pw.Font font, {
    bool isBold = false,
  }) {
    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(bgColorHex),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 8.5,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSectionTitle(String title, pw.Font font) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: font,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#0F172A'),
      ),
    );
  }

  // --- MODERN PAYLAŞIM MENÜSÜ ---
  void _paylasimMenusunuGoster({
    required BuildContext context,
    required String baslik,
    required String metin,
    required bool isDark,
    required Future<Uint8List> Function() pdfOlusturucu,
    required String pdfDosyaAdi,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (c) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF131922).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: Color(0xFF0D9488),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            baslik,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(c),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          metin,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            height: 1.45,
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buton 1: PDF Olarak Paylaş / Yazdır
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7C86),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      label: Text(
                        "PDF Olarak Paylaş / Yazdır",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(c);
                        try {
                          final bytes = await pdfOlusturucu();
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: pdfDosyaAdi,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("PDF oluşturulurken hata: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Buton 2: Metin Olarak Paylaş (WhatsApp / SMS)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        "Metin Olarak Paylaş (WhatsApp / SMS)",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(c);
                        Share.share(metin, subject: baslik);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Buton 3: Metni Kopyala
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                        side: BorderSide(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : const Color(0xFFCBD5E1),
                        ),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        "Metni Kopyala",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: metin));
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text("Rapor metni panoya kopyalandı!"),
                              ],
                            ),
                            backgroundColor: const Color(0xFF0D9488),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
