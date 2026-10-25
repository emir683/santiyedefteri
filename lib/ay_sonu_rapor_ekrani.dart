import 'dart:ui'; // Blur için gerekli
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'privacy_provider.dart';
import 'format_yardimcisi.dart';
import 'animasyon_yardimcisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'tur_servisi.dart';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';

const double _shellDockBodyPadding = 132;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

// Yardımcı Sınıf
class MaasHesaplamaSonucu {
  final Isci isci;
  int tamGun = 0;
  int yarimGun = 0;
  int mesaiGun = 0;
  double toplamMesaiYevmiye = 0.0;
  double toplamHakedis = 0.0;
  double toplamGiderMasrafi = 0.0;
  double toplamAvans = 0.0;
  double odenecekTutar = 0.0;
  MaasHesaplamaSonucu(this.isci);

  double get toplamYevmiye => tamGun + (yarimGun * 0.5) + toplamMesaiYevmiye;
}

class OperasyonelHarcamaOzeti {
  double benzin = 0.0;
  double yemek = 0.0;
  double ekMasraf = 0.0;

  double get toplam => benzin + yemek + ekMasraf;
}

class OperasyonelHarcamaDetay {
  final String santiyeAdi;
  final DateTime tarih;
  final String kalem;
  final double tutar;

  const OperasyonelHarcamaDetay({
    required this.santiyeAdi,
    required this.tarih,
    required this.kalem,
    required this.tutar,
  });
}

class AySonuRaporEkrani extends StatefulWidget {
  final String teamId;
  const AySonuRaporEkrani({super.key, required this.teamId});

  @override
  State<AySonuRaporEkrani> createState() => _AySonuRaporEkraniState();
}

class _AySonuRaporEkraniState extends State<AySonuRaporEkrani>
    with SingleTickerProviderStateMixin {
  DateTime _seciliAy = DateTime.now();
  DateTimeRange? _seciliTarihAraligi;
  bool _finansDetayAcik = false;
  bool _personelKartAcik = true;
  String _personelFiltre = 'Tümü';
  bool _operasyonelKartAcik = true;
  int _operasyonelSekme = 0; // 0: Kategoriye Göre, 1: Harcayan Kişiye Göre

  // Rehber Tur Anahtarları
  final GlobalKey _dateSelectorKey = GlobalKey();
  final GlobalKey _summaryCardsKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _turKontrol();
    });
  }

  @override
  void dispose() {
    _demoAnimController.dispose();
    super.dispose();
  }

  Future<void> _turKontrol() async {
    final gosterildi = await TurServisi.aySonuTurGosterildiMi();
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
    await TurServisi.aySonuTurGosterildiOlarakIsaretle();
  }

  List<TourStep> _buildTourSteps() {
    return [
      TourStep(
        id: 'ay_sonu_genel_tanitim',
        title: 'Ay Sonu ve Hakediş Raporları',
        description:
            'Tüm şantiye ve çalışanlarınızın aylık hakediş hesaplarını, toplam masrafları ve genel maliyet tablosunu buradan takip edin.',
        icon: Icons.analytics_rounded,
        targetKey: null,
      ),
      TourStep(
        id: 'donem_secici',
        title: 'Dönem ve Tarih Seçimi',
        description:
            'Dilediğiniz ayı seçebilir veya özel bir başlangıç ve bitiş aralığı belirleyerek o dönemin hesaplamalarını getirebilirsiniz.',
        icon: Icons.calendar_month_rounded,
        targetKey: _dateSelectorKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 16.0,
      ),
      TourStep(
        id: 'finansal_ozet',
        title: 'Finansal Genel Toplamlar',
        description:
            'Toplam işçilik hakedişi, saha operasyon masrafları ve net durumu özet kartlar üzerinden anlık analiz edin.',
        icon: Icons.account_balance_wallet_rounded,
        targetKey: _summaryCardsKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 18.0,
      ),
      TourStep(
        id: 'rapor_sekmeleri',
        title: 'Genel Özet & Şantiye Dağılımı',
        description:
            'Genel Özet sekmesinde usta bazında hakedişleri, Şantiye Bazlı sekmesinde ise her projenin ayrı ayrı gider dağılımını inceleyebilirsiniz.',
        icon: Icons.tab_rounded,
        targetKey: _tabsKey,
        targetPadding: const EdgeInsets.all(4),
        targetBorderRadius: 14.0,
      ),
    ];
  }

  Widget _buildDemoSummaryCards(bool isDark) {
    return AnimatedBuilder(
      animation: _demoAnimController,
      builder: (context, child) {
        if (_demoAnimController.value <= 0.001) return const SizedBox.shrink();
        return FadeTransition(
          opacity: _demoFadeAnimation,
          child: SlideTransition(
            position: _demoSlideAnimation,
            child: Container(
              key: _summaryCardsKey,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF14B8A6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: Color(0xFF14B8A6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Örnek Dönem Özeti",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Toplam Hakediş",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "84.500,00 TL",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Saha Giderleri",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "12.300,00 TL",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _ozelAralikAktif => _seciliTarihAraligi != null;

  DateTime get _raporBaslangic =>
      _seciliTarihAraligi != null
          ? DateTime(
            _seciliTarihAraligi!.start.year,
            _seciliTarihAraligi!.start.month,
            _seciliTarihAraligi!.start.day,
          )
          : DateTime(_seciliAy.year, _seciliAy.month, 1);

  DateTime get _raporBitis =>
      _seciliTarihAraligi != null
          ? DateTime(
            _seciliTarihAraligi!.end.year,
            _seciliTarihAraligi!.end.month,
            _seciliTarihAraligi!.end.day,
            23,
            59,
            59,
          )
          : DateTime(_seciliAy.year, _seciliAy.month + 1, 0, 23, 59, 59);

  String get _donemBaslikMetni =>
      _seciliTarihAraligi != null
          ? "${DateFormat('d MMMM yyyy', 'tr_TR').format(_seciliTarihAraligi!.start)} - ${DateFormat('d MMMM yyyy', 'tr_TR').format(_seciliTarihAraligi!.end)}"
          : DateFormat.yMMMM('tr_TR').format(_seciliAy);

  // --- PDF OLUŞTURMA (9 Parametre Alıyor) ---
  String _raporuMetneDonustur(
    String donem,
    Map<String, MaasHesaplamaSonucu> sonuclar,
    Map<String, OperasyonelHarcamaOzeti> operasyonelHarcamaSahipleri,
    double maas,
    double benzin,
    double yemek,
    double ek,
    double kayitliGelir,
    double manuelGelir,
    double manuelGider,
    double kar,
  ) {
    final sb = StringBuffer();
    final personelSonuclari =
        sonuclar.values
            .where(
              (i) =>
                  i.toplamHakedis > 0 ||
                  i.toplamAvans > 0 ||
                  i.toplamGiderMasrafi > 0,
            )
            .toList()
          ..sort((a, b) => a.isci.ad.compareTo(b.isci.ad));
    sb.writeln('--- $donem GENEL RAPORU ---');
    sb.writeln('');
    sb.writeln('PERSONEL HAKED\u0130\u015e VE ALACAK \u00d6ZET\u0130:');
    sb.writeln('\nMAAŞLAR:');
    for (final s in personelSonuclari) {
      final mesaiMetni = s.mesaiGun > 0 ? ', ${s.mesaiGun}M (${s.toplamMesaiYevmiye.toStringAsFixed(1)}Y)' : '';
      sb.writeln(
        '${s.isci.ad}: ${s.tamGun}T, ${s.yarimGun}Y$mesaiMetni. Hakediş: ${Formatlayici.yap(s.toplamHakedis)} - Avans: ${Formatlayici.yap(s.toplamAvans)} = NET: ${Formatlayici.yap(s.odenecekTutar)}',
      );
    }
    sb.writeln('\nGİDERLER:');
    sb.writeln('Personel: ${Formatlayici.yap(maas)}');
    sb.writeln(
      'Benzin: ${Formatlayici.yap(benzin)}, Yemek: ${Formatlayici.yap(yemek)}, Ek Operasyonel: ${Formatlayici.yap(ek)}',
    );
    sb.writeln('Ekstra Giderler: ${Formatlayici.yap(manuelGider)}');

    sb.writeln('\nFİNANS:');
    sb.writeln('Kayıtlı Gelir: ${Formatlayici.yap(kayitliGelir)}');
    sb.writeln('Ekstra Gelirler: ${Formatlayici.yap(manuelGelir)}');
    sb.writeln('NET DURUM: ${Formatlayici.yap(kar)}');
    return sb.toString();
  }

  String _raporuMetneDonusturDetayli(
    String donem,
    Map<String, MaasHesaplamaSonucu> sonuclar,
    Map<String, OperasyonelHarcamaOzeti> operasyonelHarcamaSahipleri,
    double maas,
    double benzin,
    double yemek,
    double ek,
    double kayitliGelir,
    double manuelGelir,
    double manuelGider,
    double kar,
  ) {
    final sb = StringBuffer();
    final personelSonuclari =
        sonuclar.values
            .where(
              (i) =>
                  i.toplamHakedis > 0 ||
                  i.toplamAvans > 0 ||
                  i.toplamGiderMasrafi > 0,
            )
            .toList()
          ..sort((a, b) => a.isci.ad.compareTo(b.isci.ad));
    final harcamaSahipleri =
        operasyonelHarcamaSahipleri.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    sb.writeln('--- $donem GENEL RAPORU ---');
    sb.writeln('');
    sb.writeln('PERSONEL HAKEDIS VE ALACAK OZETI:');

    if (personelSonuclari.isEmpty) {
      sb.writeln('Kay\u0131t bulunmuyor.');
    } else {
      for (final s in personelSonuclari) {
        final mesaiMetin = s.mesaiGun > 0 ? ', ${s.mesaiGun} mesai (${s.toplamMesaiYevmiye.toStringAsFixed(1)} yevmiye)' : '';
        sb.writeln(
          '${s.isci.ad}: ${s.tamGun} tam, ${s.yarimGun} yarım$mesaiMetin gün | Hakediş: ${Formatlayici.yap(s.toplamHakedis)} | Gider Masrafı: ${Formatlayici.yap(s.toplamGiderMasrafi)} | Avans: ${Formatlayici.yap(s.toplamAvans)} | Net: ${Formatlayici.yap(s.odenecekTutar)}',
        );
      }
    }

    sb.writeln('');
    sb.writeln('G\u0130DERLER:');
    sb.writeln('Personel Maliyeti: ${Formatlayici.yap(maas)}');
    sb.writeln('Benzin: ${Formatlayici.yap(benzin)}');
    sb.writeln('Yemek: ${Formatlayici.yap(yemek)}');
    sb.writeln('Ek Operasyonel: ${Formatlayici.yap(ek)}');
    sb.writeln('Ekstra Giderler: ${Formatlayici.yap(manuelGider)}');

    if (harcamaSahipleri.isNotEmpty) {
      sb.writeln('');
      sb.writeln('KARTTAN YAPILAN HARCAMALAR:');
      for (final entry in harcamaSahipleri) {
        final detaylar = <String>[];
        if (entry.value.benzin > 0) {
          detaylar.add('Benzin ${Formatlayici.yap(entry.value.benzin)}');
        }
        if (entry.value.yemek > 0) {
          detaylar.add('Yemek ${Formatlayici.yap(entry.value.yemek)}');
        }
        if (entry.value.ekMasraf > 0) {
          detaylar.add('Ek ${Formatlayici.yap(entry.value.ekMasraf)}');
        }
        sb.writeln(
          '${entry.key}: ${detaylar.join(', ')} | Toplam: ${Formatlayici.yap(entry.value.toplam)}',
        );
      }
    }

    sb.writeln('');
    sb.writeln('F\u0130NANS:');
    sb.writeln('Kay\u0131tl\u0131 Gelir: ${Formatlayici.yap(kayitliGelir)}');
    sb.writeln('Ekstra Gelirler: ${Formatlayici.yap(manuelGelir)}');
    sb.writeln('Net Durum: ${Formatlayici.yap(kar)}');
    return sb.toString();
  }

  Future<Uint8List> _raporuPdfOlustur(String metin) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);
    pdf.addPage(
      pw.Page(
        build:
            (c) => pw.Text(metin, style: pw.TextStyle(font: ttf, fontSize: 12)),
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _raporuPdfOlusturDetayli(
    String donem,
    Map<String, MaasHesaplamaSonucu> sonuclar,
    Map<String, OperasyonelHarcamaOzeti> operasyonelHarcamaSahipleri,
    double maas,
    double benzin,
    double yemek,
    double ek,
    double kayitliGelir,
    double manuelGelir,
    double manuelGider,
    double kar,
  ) async {
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(font);

    final personelSonuclari =
        sonuclar.values
            .where(
              (i) =>
                  i.toplamHakedis > 0 ||
                  i.toplamAvans > 0 ||
                  i.toplamGiderMasrafi > 0,
            )
            .toList()
          ..sort((a, b) => a.isci.ad.compareTo(b.isci.ad));
    final harcamaSahipleri =
        operasyonelHarcamaSahipleri.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final toplamGelir = kayitliGelir + manuelGelir;
    final toplamGider = maas + benzin + yemek + ek + manuelGider;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: ttf),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F7C86'),
                  borderRadius: pw.BorderRadius.circular(18),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ay Sonu Raporu',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 22,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      donem,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Olusturma Tarihi: ${DateFormat('d.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now())}',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPdfInfoCard(
                    'Kayitli Gelir',
                    Formatlayici.yap(kayitliGelir),
                    '#DCFCE7',
                    '#166534',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Toplam Gider',
                    Formatlayici.yap(toplamGider),
                    '#FEE2E2',
                    '#B91C1C',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Net Durum',
                    Formatlayici.yap(kar),
                    kar >= 0 ? '#DCFCE7' : '#FEE2E2',
                    kar >= 0 ? '#166534' : '#B91C1C',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Personel Maliyeti',
                    Formatlayici.yap(maas),
                    '#F3E8FF',
                    '#7E22CE',
                    ttf,
                  ),
                ],
              ),
              pw.SizedBox(height: 22),
              _buildPdfSectionTitle('Finans Ozeti', ttf),
              pw.SizedBox(height: 8),
              _buildPdfValueRow(
                'Kayitli Gelir',
                Formatlayici.yap(kayitliGelir),
                ttf,
              ),
              _buildPdfValueRow(
                'Ekstra Gelirler',
                Formatlayici.yap(manuelGelir),
                ttf,
              ),
              _buildPdfValueRow(
                'Toplam Gelir',
                Formatlayici.yap(toplamGelir),
                ttf,
              ),
              _buildPdfValueRow(
                'Ekstra Giderler',
                Formatlayici.yap(manuelGider),
                ttf,
              ),
              _buildPdfValueRow('Benzin', Formatlayici.yap(benzin), ttf),
              _buildPdfValueRow('Yemek', Formatlayici.yap(yemek), ttf),
              _buildPdfValueRow('Ek Operasyonel', Formatlayici.yap(ek), ttf),
              _buildPdfValueRow(
                'Net Durum',
                Formatlayici.yap(kar),
                ttf,
                emphasize: true,
              ),
              pw.SizedBox(height: 20),
              _buildPdfSectionTitle('Personel Hakedis ve Alacak Ozeti', ttf),
              pw.SizedBox(height: 8),
              personelSonuclari.isEmpty
                  ? pw.Text(
                    'Kayit bulunmuyor.',
                    style: pw.TextStyle(font: ttf, fontSize: 11),
                  )
                  : pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(
                      font: ttf,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#111827'),
                    ),
                    cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    headers: const [
                      'Personel',
                      'Gun',
                      'Hakedis',
                      'Gider Masrafi',
                      'Avans',
                      'Net',
                    ],
                    data:
                        personelSonuclari
                            .map(
                              (s) => [
                                s.isci.ad,
                                '${s.tamGun}T / ${s.yarimGun}Y${s.mesaiGun > 0 ? " / ${s.mesaiGun}M" : ""}',
                                Formatlayici.yap(s.toplamHakedis),
                                Formatlayici.yap(s.toplamGiderMasrafi),
                                Formatlayici.yap(s.toplamAvans),
                                Formatlayici.yap(s.odenecekTutar),
                              ],
                            )
                            .toList(),
                  ),
              if (harcamaSahipleri.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                _buildPdfSectionTitle('Karttan Yapilan Harcamalar', ttf),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    font: ttf,
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F766E'),
                  ),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  headers: const ['Kisi', 'Benzin', 'Yemek', 'Ek', 'Toplam'],
                  data:
                      harcamaSahipleri
                          .map(
                            (entry) => [
                              entry.key,
                              Formatlayici.yap(entry.value.benzin),
                              Formatlayici.yap(entry.value.yemek),
                              Formatlayici.yap(entry.value.ekMasraf),
                              Formatlayici.yap(entry.value.toplam),
                            ],
                          )
                          .toList(),
                ),
              ],
            ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSectionTitle(String title, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E6F7F5'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 13,
          color: PdfColor.fromHex('#0F766E'),
        ),
      ),
    );
  }

  pw.Widget _buildPdfInfoCard(
    String title,
    String value,
    String bgHex,
    String textHex,
    pw.Font font,
  ) {
    return pw.Container(
      width: 125,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(bgHex),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColor.fromHex(textHex),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              color: PdfColor.fromHex(textHex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfValueRow(
    String label,
    String value,
    pw.Font font, {
    bool emphasize = false,
  }) {
    final color =
        emphasize ? PdfColor.fromHex('#0F766E') : PdfColor.fromHex('#334155');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: PdfColor.fromHex('#475569'),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  // --- MODERN AY SEÇİCİ DİYALOĞU ---
  void _aySeciciGoster(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return _AyYilSeciciDialog(
          baslangicTarihi: _seciliAy,
          onSecildi:
              (secilen) => setState(() {
                _seciliAy = secilen;
                _seciliTarihAraligi = null;
              }),
        );
      },
    );
  }

  Future<void> _tarihAraligiSeciciGoster(BuildContext context) async {
    final secilenAralik = await showDateRangePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      initialDateRange:
          _seciliTarihAraligi ??
          DateTimeRange(start: _raporBaslangic, end: _raporBitis),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _kBrandTeal,
              secondary: _kBrandTealDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (secilenAralik == null) return;
    setState(() {
      _seciliTarihAraligi = secilenAralik;
      _seciliAy = DateTime(secilenAralik.start.year, secilenAralik.start.month);
    });
  }

  // --- KALEM EKLEME DİYALOĞU (MODERN & BLUR) ---
  void _kalemEkleDialog(
    BuildContext context,
    String baslik,
    Function(String, double) onEkle,
  ) {
    final adController = TextEditingController();
    final miktarController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        baslik,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildBlurInput(
                        adController,
                        "Açıklama / İsim",
                        Icons.description,
                        isNumber: false,
                      ),
                      const SizedBox(height: 16),
                      _buildBlurInput(
                        miktarController,
                        "Tutar (TL)",
                        Icons.attach_money,
                        isNumber: true,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "İptal",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final ad = adController.text.trim();
                                final miktar = Formatlayici.parse(
                                  miktarController.text.trim(),
                                );
                                if (ad.isNotEmpty && miktar > 0) {
                                  onEkle(ad, miktar);
                                  Navigator.pop(ctx);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBrandTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Ekle",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        );
      },
    );
  }

  // --- YARDIMCI INPUT WIDGET ---
  Widget _buildBlurInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = true,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      keyboardType:
          isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // --- BLUR EFEKTLİ PAYLAŞIM MENÜSÜ ---
  void _paylasimMenusunuGoster(
    String metin, {
    required Future<Uint8List> Function() pdfOlusturucu,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (c) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E1E1E).withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                      ),
                      title: const Text(
                        "PDF Olarak Paylaş",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        Navigator.pop(c);
                        final bytes = await pdfOlusturucu();
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'rapor.pdf',
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.message, color: Colors.green),
                      ),
                      title: const Text(
                        "Metin Olarak Paylaş",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.pop(c);
                        Share.share(metin);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final baslangic = _raporBaslangic;
    final bitis = _raporBitis;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
        appBar: FloatingLiquidAppBar(
          title: "Ay Sonu Raporu",
          showPrivacyButton: true,
          showTourButton: true,
          onTourPressed: () => _turBaslat(manual: true),
          bottom: TabBar(
            key: _tabsKey,
            labelColor: _kBrandTeal,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
            indicatorColor: _kBrandTeal,
            indicatorWeight: 2.8,
            tabs: const [
              Tab(icon: Icon(Icons.analytics_outlined), text: "Genel Özet"),
              Tab(icon: Icon(Icons.location_city), text: "Şantiye Bazlı"),
            ],
          ),
        ),
        body: Stack(
          children: [
            GlassPageSurface(
              preferSoftLightBackground: true,
              child: Column(
                children: [
                  SizedBox(
                    height: FloatingLiquidAppBar.topPadding(
                      context,
                      hasBottom: true,
                      extra: 4,
                    ),
                  ),
                  // ORTAK TARİH SEÇİCİ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                    child: KeyedSubtree(
                      key: _dateSelectorKey,
                      child: Container(
                        decoration: _buildPanelGlassCardDecoration(
                          isDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kBrandTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: _kBrandTealDark,
                            ),
                          ),
                          title: Text(
                            _donemBaslikMetni,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle:
                              _ozelAralikAktif
                                  ? const Text("Seçili gün aralığı")
                                  : const Text("Aylık görünüm"),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                tooltip: "Ay Seç",
                                onPressed: () => _aySeciciGoster(context),
                                icon: const Icon(Icons.date_range_outlined),
                              ),
                              IconButton(
                                tooltip: "Gün Aralığı Seç",
                                onPressed:
                                    () => _tarihAraligiSeciciGoster(context),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildDemoSummaryCards(isDark),

                  // VERİ ZİNCİRİ
                  Expanded(
                    child: StreamBuilder<List<Santiye>>(
                      stream: servisi.getSantiyelerStream(widget.teamId),
                      builder: (context, snapSantiyeler) {
                        final santiyeler = snapSantiyeler.data ?? [];

                        return StreamBuilder<List<Isci>>(
                          stream: servisi.getIscilerStream(widget.teamId),
                          builder: (context, snapIsciler) {
                            final isciler = snapIsciler.data ?? [];

                            return StreamBuilder<List<GunlukSantiyeRaporu>>(
                              stream: servisi.getRaporlarStream(
                                widget.teamId,
                                baslangic,
                                bitis,
                              ),
                              builder: (context, snapRaporlar) {
                                final raporlar = snapRaporlar.data ?? [];

                                return StreamBuilder<List<VerilenAvans>>(
                                  stream: servisi.getAvanslarStream(
                                    widget.teamId,
                                  ),
                                  builder: (context, snapAvans) {
                                    final avanslar = snapAvans.data ?? [];

                                    return StreamBuilder<List<AlinanOdeme>>(
                                      stream: servisi.getOdemelerStream(
                                        widget.teamId,
                                      ),
                                      builder: (context, snapOdemeler) {
                                        final odemeler =
                                            snapOdemeler.data ?? [];

                                        return StreamBuilder<List<AylikFinans>>(
                                          stream: servisi
                                              .getTumAylikFinanslarStream(
                                                widget.teamId,
                                              ),
                                          builder: (context, snapFinans) {
                                            final tumAylikFinanslar =
                                                snapFinans.data ??
                                                const <AylikFinans>[];
                                            final aylikFinans =
                                                tumAylikFinanslar
                                                    .where(
                                                      (finans) =>
                                                          finans.yil ==
                                                              _seciliAy.year &&
                                                          finans.ay ==
                                                              _seciliAy.month,
                                                    )
                                                    .firstOrNull ??
                                                AylikFinans(
                                                  yil: _seciliAy.year,
                                                  ay: _seciliAy.month,
                                                );
                                            final araliktakiFinanslar =
                                                tumAylikFinanslar
                                                    .where(
                                                      (finans) =>
                                                          _aylikFinansAralikta(
                                                            finans,
                                                            baslangic,
                                                            bitis,
                                                          ),
                                                    )
                                                    .toList();

                                            // --- HESAPLAMA SIFIRLAMA ---
                                            // Her build işleminde sıfırdan hesaplamak için map'i burada oluşturuyoruz.
                                            final Map<
                                              String,
                                              MaasHesaplamaSonucu
                                            >
                                            hesaplar = {
                                              for (var i in isciler)
                                                i.ad: MaasHesaplamaSonucu(i),
                                            };

                                            // --- GENEL HESAPLAMALAR ---
                                            double topBenzin = 0,
                                                topYemek = 0,
                                                topEk = 0;
                                            final Map<
                                              String,
                                              OperasyonelHarcamaOzeti
                                            >
                                            operasyonelHarcamaSahipleri = {};
                                            final Map<
                                              String,
                                              List<OperasyonelHarcamaDetay>
                                            >
                                            operasyonelHarcamaDetaylari = {};

                                            for (var r in raporlar) {
                                              topBenzin += r.benzinGideri;
                                              topYemek += r.yemekGideri;
                                              topEk += r.ekMasraflar;
                                              if (r.benzinGideri > 0 &&
                                                  r.benzinGideriIsciAdi !=
                                                      null &&
                                                  hesaplar.containsKey(
                                                    r.benzinGideriIsciAdi,
                                                  )) {
                                                hesaplar[r.benzinGideriIsciAdi]!
                                                        .toplamGiderMasrafi +=
                                                    r.benzinGideri;
                                                operasyonelHarcamaSahipleri
                                                    .putIfAbsent(
                                                      r.benzinGideriIsciAdi!,
                                                      OperasyonelHarcamaOzeti
                                                          .new,
                                                    )
                                                    .benzin += r.benzinGideri;
                                                operasyonelHarcamaDetaylari
                                                    .putIfAbsent(
                                                      r.benzinGideriIsciAdi!,
                                                      () =>
                                                          <
                                                            OperasyonelHarcamaDetay
                                                          >[],
                                                    )
                                                    .add(
                                                      OperasyonelHarcamaDetay(
                                                        santiyeAdi:
                                                            r.santiyeAdi,
                                                        tarih: r.tarih,
                                                        kalem: "Benzin",
                                                        tutar: r.benzinGideri,
                                                      ),
                                                    );
                                              }
                                              if (r.yemekGideri > 0 &&
                                                  r.yemekGideriIsciAdi !=
                                                      null &&
                                                  hesaplar.containsKey(
                                                    r.yemekGideriIsciAdi,
                                                  )) {
                                                hesaplar[r.yemekGideriIsciAdi]!
                                                        .toplamGiderMasrafi +=
                                                    r.yemekGideri;
                                                operasyonelHarcamaSahipleri
                                                    .putIfAbsent(
                                                      r.yemekGideriIsciAdi!,
                                                      OperasyonelHarcamaOzeti
                                                          .new,
                                                    )
                                                    .yemek += r.yemekGideri;
                                                operasyonelHarcamaDetaylari
                                                    .putIfAbsent(
                                                      r.yemekGideriIsciAdi!,
                                                      () =>
                                                          <
                                                            OperasyonelHarcamaDetay
                                                          >[],
                                                    )
                                                    .add(
                                                      OperasyonelHarcamaDetay(
                                                        santiyeAdi:
                                                            r.santiyeAdi,
                                                        tarih: r.tarih,
                                                        kalem: "Yemek",
                                                        tutar: r.yemekGideri,
                                                      ),
                                                    );
                                              }
                                              if (r.ekMasraflar > 0 &&
                                                  r.ekMasraflarIsciAdi !=
                                                      null &&
                                                  hesaplar.containsKey(
                                                    r.ekMasraflarIsciAdi,
                                                  )) {
                                                hesaplar[r.ekMasraflarIsciAdi]!
                                                        .toplamGiderMasrafi +=
                                                    r.ekMasraflar;
                                                operasyonelHarcamaSahipleri
                                                    .putIfAbsent(
                                                      r.ekMasraflarIsciAdi!,
                                                      OperasyonelHarcamaOzeti
                                                          .new,
                                                    )
                                                    .ekMasraf += r.ekMasraflar;
                                                operasyonelHarcamaDetaylari
                                                    .putIfAbsent(
                                                      r.ekMasraflarIsciAdi!,
                                                      () =>
                                                          <
                                                            OperasyonelHarcamaDetay
                                                          >[],
                                                    )
                                                    .add(
                                                      OperasyonelHarcamaDetay(
                                                        santiyeAdi:
                                                            r.santiyeAdi,
                                                        tarih: r.tarih,
                                                        kalem: "Ek Masraf",
                                                        tutar: r.ekMasraflar,
                                                      ),
                                                    );
                                              }
                                              for (var c in r.calisanlar) {
                                                if (hesaplar.containsKey(
                                                  c.isci.ad,
                                                )) {
                                                  final carpan =
                                                      parseDurumCarpani(
                                                        c.durum,
                                                      );
                                                  if (c.durum == "Tam Gün") {
                                                    hesaplar[c.isci.ad]!
                                                        .tamGun++;
                                                    hesaplar[c.isci.ad]!
                                                            .toplamHakedis +=
                                                        c.isci.gunlukMaas;
                                                  } else if (c.durum ==
                                                      "Yarım Gün") {
                                                    hesaplar[c.isci.ad]!
                                                        .yarimGun++;
                                                    hesaplar[c.isci.ad]!
                                                            .toplamHakedis +=
                                                        (c.isci.gunlukMaas / 2);
                                                  } else if (c.durum.contains(
                                                    "Mesai",
                                                  ) || c.durum.contains("mesai")) {
                                                    hesaplar[c.isci.ad]!
                                                        .mesaiGun++;
                                                    hesaplar[c.isci.ad]!
                                                        .toplamMesaiYevmiye +=
                                                        carpan;
                                                    hesaplar[c.isci.ad]!
                                                            .toplamHakedis +=
                                                        (c.isci.gunlukMaas *
                                                            carpan);
                                                  }
                                                }
                                              }
                                            }

                                            for (var a in avanslar) {
                                              if (_tarihAralikta(
                                                a.tarih,
                                                baslangic,
                                                bitis,
                                              )) {
                                                if (hesaplar.containsKey(
                                                  a.isci.ad,
                                                )) {
                                                  hesaplar[a.isci.ad]!
                                                      .toplamAvans += a.miktar;
                                                }
                                              }
                                            }

                                            double toplamMaas = 0;
                                            hesaplar.forEach((_, h) {
                                              h.odenecekTutar =
                                                  h.toplamHakedis +
                                                  h.toplamGiderMasrafi -
                                                  h.toplamAvans;
                                              toplamMaas += h.toplamHakedis;
                                            });

                                            double kayitliGelir = 0;
                                            for (var o in odemeler) {
                                              if (_tarihAralikta(
                                                o.tarih,
                                                baslangic,
                                                bitis,
                                              )) {
                                                kayitliGelir += o.miktar;
                                              }
                                            }

                                            // Ek Gelir/Gider Toplamları
                                            double toplamEkstraGelir =
                                                araliktakiFinanslar
                                                    .expand(
                                                      (finans) =>
                                                          finans.ekstraGelirler,
                                                    )
                                                    .fold(
                                                      0.0,
                                                      (sum, item) =>
                                                          sum + item.miktar,
                                                    );
                                            double toplamEkstraGider =
                                                araliktakiFinanslar
                                                    .expand(
                                                      (finans) =>
                                                          finans.ekstraGiderler,
                                                    )
                                                    .fold(
                                                      0.0,
                                                      (sum, item) =>
                                                          sum + item.miktar,
                                                    );

                                            double toplamGelir =
                                                kayitliGelir +
                                                toplamEkstraGelir;

                                            // Gider Hesabı: User requested "WORKER TOTAL COST" (Hakediş) to be included in total expense,
                                            // not just paid amount.
                                            // "toplamGidere dahil edilmiyor" -> Fixed by using toplamMaas.
                                            double toplamGider =
                                                toplamMaas + // HAKEDİŞ ESASLI: Toplam hak edilen maaş gider sayılır
                                                topBenzin +
                                                topYemek +
                                                topEk +
                                                toplamEkstraGider;
                                            double netDurum =
                                                toplamGelir - toplamGider;

                                            return TabBarView(
                                              children: [
                                                // --- SEKME 1: GENEL ÖZET ---
                                                SingleChildScrollView(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        16,
                                                        16,
                                                        16,
                                                        _shellDockBodyPadding,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      _buildFinansCard(
                                                        context,
                                                        kayitliGelir,
                                                        toplamGelir,
                                                        toplamGider,
                                                        netDurum,
                                                        aylikFinans,
                                                        isDark,
                                                        servisi,
                                                        toplamMaas,
                                                        topBenzin,
                                                        topYemek,
                                                        topEk,
                                                      ),
                                                      const SizedBox(
                                                        height: 14,
                                                      ),
                                                      _buildPersonelHakedisKarti(
                                                        context: context,
                                                        isDark: isDark,
                                                        hesaplar: hesaplar,
                                                        toplamMaas: toplamMaas,
                                                      ),
                                                      const SizedBox(
                                                        height: 14,
                                                      ),
                                                      _buildOperasyonelGiderlerKarti(
                                                        context: context,
                                                        isDark: isDark,
                                                        topBenzin: topBenzin,
                                                        topYemek: topYemek,
                                                        topEk: topEk,
                                                        operasyonelHarcamaSahipleri:
                                                            operasyonelHarcamaSahipleri,
                                                        operasyonelHarcamaDetaylari:
                                                            operasyonelHarcamaDetaylari,
                                                        raporlar: raporlar,
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),

                                                      ElevatedButton.icon(
                                                        icon: const Icon(
                                                          Icons.share,
                                                        ),
                                                        label: const Text(
                                                          "Genel Raporu Paylaş",
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              _kBrandTeal,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 16,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          minimumSize:
                                                              const Size(
                                                                double.infinity,
                                                                50,
                                                              ),
                                                        ),
                                                        onPressed:
                                                            () => _paylasimMenusunuGoster(
                                                              _raporuMetneDonusturDetayli(
                                                                _donemBaslikMetni,
                                                                hesaplar,
                                                                operasyonelHarcamaSahipleri,
                                                                toplamMaas,
                                                                topBenzin,
                                                                topYemek,
                                                                topEk,
                                                                kayitliGelir,
                                                                toplamEkstraGelir,
                                                                toplamEkstraGider,
                                                                netDurum,
                                                              ),
                                                              pdfOlusturucu:
                                                                  () => _raporuPdfOlusturDetayli(
                                                                    _donemBaslikMetni,
                                                                    hesaplar,
                                                                    operasyonelHarcamaSahipleri,
                                                                    toplamMaas,
                                                                    topBenzin,
                                                                    topYemek,
                                                                    topEk,
                                                                    kayitliGelir,
                                                                    toplamEkstraGelir,
                                                                    toplamEkstraGider,
                                                                    netDurum,
                                                                  ),
                                                            ),
                                                      ),
                                                      const SizedBox(height: 10),
                                                      OutlinedButton.icon(
                                                        icon: const Icon(
                                                          Icons.send_rounded,
                                                          color: Color(0xFF10B981),
                                                        ),
                                                        label: const Text(
                                                          "Metin Olarak Paylaş (WhatsApp / SMS)",
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: isDark
                                                              ? Colors.white
                                                              : const Color(0xFF10B981),
                                                          side: const BorderSide(
                                                            color: Color(0xFF10B981),
                                                          ),
                                                          padding: const EdgeInsets.symmetric(
                                                            vertical: 16,
                                                          ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          minimumSize: const Size(
                                                            double.infinity,
                                                            50,
                                                          ),
                                                        ),
                                                        onPressed: () {
                                                          final metin = _raporuMetneDonusturDetayli(
                                                            _donemBaslikMetni,
                                                            hesaplar,
                                                            operasyonelHarcamaSahipleri,
                                                            toplamMaas,
                                                            topBenzin,
                                                            topYemek,
                                                            topEk,
                                                            kayitliGelir,
                                                            toplamEkstraGelir,
                                                            toplamEkstraGider,
                                                            netDurum,
                                                          );
                                                          Share.share(
                                                            metin,
                                                            subject: "$_donemBaslikMetni Genel Raporu",
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(
                                                        height:
                                                            _shellDockBodyPadding,
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // --- SEKME 2: ŞANTİYE BAZLI DETAY ---
                                                santiyeler.isEmpty
                                                    ? const Center(
                                                      child: Text(
                                                        "Şantiye bulunamadı.",
                                                      ),
                                                    )
                                                    : ListView.builder(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            16,
                                                            16,
                                                            _shellDockBodyPadding,
                                                          ),
                                                      itemCount:
                                                          santiyeler.length,
                                                      itemBuilder: (
                                                        ctx,
                                                        index,
                                                      ) {
                                                        final sAdi =
                                                            santiyeler[index]
                                                                .ad;
                                                        final sRaporlar =
                                                            raporlar
                                                                .where(
                                                                  (r) =>
                                                                      r.santiyeAdi ==
                                                                      sAdi,
                                                                )
                                                                .toList();
                                                        final sOdemeler =
                                                            odemeler
                                                                .where(
                                                                  (o) =>
                                                                      o.santiyeAdi ==
                                                                          sAdi &&
                                                                      _tarihAralikta(
                                                                        o.tarih,
                                                                        baslangic,
                                                                        bitis,
                                                                      ),
                                                                )
                                                                .toList();

                                                        double sBenzin = 0,
                                                            sYemek = 0,
                                                            sEk = 0,
                                                            sMaas = 0,
                                                            sGelir = 0;
                                                        for (var o
                                                            in sOdemeler) {
                                                          sGelir += o.miktar;
                                                        }

                                                        for (var r
                                                            in sRaporlar) {
                                                          sBenzin +=
                                                              r.benzinGideri;
                                                          sYemek +=
                                                              r.yemekGideri;
                                                          sEk += r.ekMasraflar;
                                                          for (var c
                                                              in r.calisanlar) {
                                                            sMaas +=
                                                                (c.isci.gunlukMaas *
                                                                    parseDurumCarpani(
                                                                      c.durum,
                                                                    ));
                                                          }
                                                        }

                                                        double sToplamGider =
                                                            sBenzin +
                                                            sYemek +
                                                            sEk +
                                                            sMaas;
                                                        double sKar =
                                                            sGelir -
                                                            sToplamGider;

                                                        return Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 12,
                                                              ),
                                                          decoration:
                                                              _buildPanelGlassCardDecoration(
                                                                isDark,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                          child: Theme(
                                                            data: Theme.of(
                                                              context,
                                                            ).copyWith(
                                                              dividerColor:
                                                                  Colors
                                                                      .transparent,
                                                            ),
                                                            child: ExpansionTile(
                                                              leading: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      8,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    begin:
                                                                        Alignment
                                                                            .topLeft,
                                                                    end:
                                                                        Alignment
                                                                            .bottomRight,
                                                                    colors: [
                                                                      Colors.teal.withValues(
                                                                        alpha:
                                                                            isDark
                                                                                ? 0.18
                                                                                : 0.14,
                                                                      ),
                                                                      (isDark
                                                                              ? const Color(
                                                                                0xFF171B20,
                                                                              )
                                                                              : Colors.white)
                                                                          .withValues(
                                                                            alpha:
                                                                                isDark
                                                                                    ? 0.82
                                                                                    : 0.92,
                                                                          ),
                                                                    ],
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .teal
                                                                        .withValues(
                                                                          alpha:
                                                                              isDark
                                                                                  ? 0.16
                                                                                  : 0.12,
                                                                        ),
                                                                  ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .location_city,
                                                                  color:
                                                                      Colors
                                                                          .teal,
                                                                ),
                                                              ),
                                                              title: Text(
                                                                sAdi,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              subtitle: Consumer<
                                                                PrivacyProvider
                                                              >(
                                                                builder: (
                                                                  context,
                                                                  privacy,
                                                                  child,
                                                                ) {
                                                                  return Text(
                                                                    privacy.isHidden
                                                                        ? "**** TL"
                                                                        : "${sKar >= 0 ? '+' : ''}${Formatlayici.yap(sKar)}",
                                                                    style: TextStyle(
                                                                      color:
                                                                          sKar >= 0
                                                                              ? Colors.green
                                                                              : Colors.red,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                              children: [
                                                                const Divider(
                                                                  height: 1,
                                                                ),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        16.0,
                                                                      ),
                                                                  child: Column(
                                                                    children: [
                                                                      _buildListRow(
                                                                        "Toplam Gelir",
                                                                        sGelir,
                                                                        Colors
                                                                            .green,
                                                                      ),
                                                                      const Divider(),
                                                                      _buildListRow(
                                                                        "Personel Maliyeti",
                                                                        sMaas,
                                                                        Colors
                                                                            .purple,
                                                                      ),
                                                                      _buildListRow(
                                                                        "Benzin",
                                                                        sBenzin,
                                                                        Colors
                                                                            .redAccent,
                                                                      ),
                                                                      _buildListRow(
                                                                        "Yemek",
                                                                        sYemek,
                                                                        Colors
                                                                            .orangeAccent,
                                                                      ),
                                                                      _buildListRow(
                                                                        "Ek Masraflar",
                                                                        sEk,
                                                                        Colors
                                                                            .blueAccent,
                                                                      ),
                                                                      const Divider(),
                                                                      _buildSummaryRow(
                                                                        "NET DURUM",
                                                                        sKar,
                                                                        sKar >= 0
                                                                            ? Colors.green
                                                                            : Colors.red,
                                                                        isLarge:
                                                                            true,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
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
            ),
            if (_isTourActive)
              InteractiveTourOverlay(
                steps: _buildTourSteps(),
                onFinish: _turSonlandir,
                onSkip: _turSonlandir,
              ),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGETLAR ---
  Widget _buildExpansionCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD8EAF0),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: isDark ? 0.18 : 0.14),
                (isDark ? const Color(0xFF171B20) : Colors.white).withValues(
                  alpha: isDark ? 0.82 : 0.92,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.16 : 0.12),
            ),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Consumer<PrivacyProvider>(
          builder:
              (context, privacy, child) =>
                  privacy.isHidden
                      ? Text(
                        "**** TL",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                      : SayiSayici(
                        hedefDeger: amount,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
        ),
        children: children,
      ),
    );
  }

  void _ekstraKalemEkleSecici(
    BuildContext context,
    AylikFinans aylikFinans,
    FirestoreServisi servisi,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E28) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFD4E7EF),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Ekstra Kalem Ekle",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Hakediş dışı ara gelir veya beklenmedik şantiye gideri ekleyin.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor:
                    isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8FCFE),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                title: Text(
                  "Ekstra Gelir Ekle",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "Hakediş dışı kasa ve ara gelir girişi",
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.grey,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _kalemEkleDialog(context, "Ekstra Gelir Ekle", (ad, miktar) {
                    aylikFinans.ekstraGelirler.add(
                      FinansalKalem(ad: ad, miktar: miktar),
                    );
                    servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
                  });
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor:
                    isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8FCFE),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                title: Text(
                  "Ekstra Gider Ekle",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "Beklenmedik veya şirket dışı gider girişi",
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.grey,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _kalemEkleDialog(context, "Ekstra Gider Ekle", (ad, miktar) {
                    aylikFinans.ekstraGiderler.add(
                      FinansalKalem(ad: ad, miktar: miktar),
                    );
                    servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _buildPanelGlassCardDecoration(
    bool isDark, {
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
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
      borderRadius: borderRadius ?? BorderRadius.circular(22),
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
    );
  }

  BoxDecoration _buildPanelGlassInsetDecoration(
    bool isDark, {
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
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
                : const Color(0xFFC7D7DC).withValues(alpha: 0.85),
      ),
      borderRadius: borderRadius ?? BorderRadius.circular(16),
    );
  }

  Widget _buildFinansCard(
    BuildContext context,
    double kayitliGelir,
    double toplamGelir,
    double toplamGider,
    double netDurum,
    AylikFinans aylikFinans,
    bool isDark,
    FirestoreServisi servisi,
    double odenenMaas,
    double benzin,
    double yemek,
    double ek,
  ) {
    final double ekstraGelirToplam = aylikFinans.ekstraGelirler.fold(
      0.0,
      (toplam, kalem) => toplam + kalem.miktar,
    );
    final double ekstraGiderToplam = aylikFinans.ekstraGiderler.fold(
      0.0,
      (toplam, kalem) => toplam + kalem.miktar,
    );

    final bool isPositive = netDurum >= 0;
    final primaryStatusColor =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    // Kâr Marjı ve Hacim Oranları
    final double margin =
        toplamGelir > 0
            ? ((netDurum / toplamGelir) * 100).clamp(-100.0, 100.0)
            : 0.0;
    final double totalVolume = (toplamGelir + toplamGider).clamp(
      1.0,
      double.infinity,
    );
    final double gelirShare = (toplamGelir / totalVolume).clamp(0.06, 0.94);
    final double giderShare = (toplamGider / totalVolume).clamp(0.06, 0.94);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _buildPanelGlassCardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Üst Başlık & Dinamik Rozet Satırı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Durum Kapsülü
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryStatusColor.withValues(
                        alpha: isDark ? 0.16 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryStatusColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 15,
                          color: primaryStatusColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isPositive
                                ? "NET DÖNEM KÂRI"
                                : "BÜTÇE AŞIMI / ZARAR",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: primaryStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Kâr / Aşım Oranı Rozeti
                if (toplamGelir > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFF0F172A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPositive
                          ? "+%${margin.toStringAsFixed(0)} Kâr Oranı"
                          : "-%${margin.abs().toStringAsFixed(0)} Açık",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Net Tutar ve Açıklama
            Text(
              "Dönem Net Kasa Dengesi",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Consumer<PrivacyProvider>(
              builder: (context, privacy, child) {
                if (privacy.isHidden) {
                  return Text(
                    "**** TL",
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: primaryStatusColor,
                    ),
                  );
                }
                return SayiSayici(
                  hedefDeger: netDurum,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: primaryStatusColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // 3. İki Renkli Sıvı Denge Çubuğu
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: (gelirShare * 1000).toInt().clamp(1, 1000),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: (giderShare * 1000).toInt().clamp(1, 1000),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF43F5E), Color(0xFFEF4444)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "%${(gelirShare * 100).toStringAsFixed(0)} Gelir Hacmi",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "%${(giderShare * 100).toStringAsFixed(0)} Gider Yükü",
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. İkili Gelir / Gider Metrik Blokları
            Row(
              children: [
                // Toplam Gelir Bloğu
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _buildPanelGlassInsetDecoration(
                      isDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "GELİR",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  privacy.isHidden
                                      ? "**** TL"
                                      : Formatlayici.yap(toplamGelir),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => Text(
                                privacy.isHidden
                                    ? "**** TL"
                                    : "Kayıtlı: ${Formatlayici.yap(kayitliGelir)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color:
                                      isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Toplam Gider Bloğu
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _buildPanelGlassInsetDecoration(
                      isDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "GİDER",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  privacy.isHidden
                                      ? "**** TL"
                                      : Formatlayici.yap(toplamGider),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Hakediş + Saha Gideri",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color:
                                isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Gider Dağılım Çipleri (4 Ana Kalem)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildGiderChip(
                  label: "İşçilik",
                  value: odenenMaas,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                _buildGiderChip(
                  label: "Yakıt",
                  value: benzin,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
                _buildGiderChip(
                  label: "Yemek",
                  value: yemek,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
                _buildGiderChip(
                  label: "Ekstra & Diğer",
                  value: ek + ekstraGiderToplam,
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 6. Alt Aksiyon & Detay Açma Barı
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ekstra Kalem Ekle Butonu
                Flexible(
                  child: TextButton.icon(
                    onPressed:
                        () => _ekstraKalemEkleSecici(
                          context,
                          aylikFinans,
                          servisi,
                        ),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 16,
                      color: Color(0xFF14B8A6),
                    ),
                    label: Text(
                      "Ek Kalem Ekle",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF14B8A6),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Grafik & Detayları Aç/Kapat Butonu
                Flexible(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _finansDetayAcik = !_finansDetayAcik;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _finansDetayAcik
                                  ? "Detayları Gizle"
                                  : "Grafik & Kalemler",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _finansDetayAcik
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 7. Açılır Genişletilebilir Detay Bölümü
            if (_finansDetayAcik) ...[
              const SizedBox(height: 12),
              _buildGiderPastaGrafik(
                context,
                odenenMaas: odenenMaas,
                benzin: benzin,
                yemek: yemek,
                ek: ek,
                ekstraGider: ekstraGiderToplam,
              ),
              const SizedBox(height: 12),
              _buildEkstraKalemlerKarti(
                context: context,
                aylikFinans: aylikFinans,
                servisi: servisi,
                ekstraGelirToplam: ekstraGelirToplam,
                ekstraGiderToplam: ekstraGiderToplam,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : const Color(0xFFF8FCFE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildListRow(
                      "Personel Maliyeti (Hakediş)",
                      odenenMaas,
                      const Color(0xFF10B981),
                    ),
                    _buildListRow(
                      "Benzin Gideri",
                      benzin,
                      const Color(0xFFEF4444),
                    ),
                    _buildListRow(
                      "Yemek Gideri",
                      yemek,
                      const Color(0xFFF59E0B),
                    ),
                    _buildListRow(
                      "Ek Operasyonel",
                      ek,
                      const Color(0xFF06B6D4),
                    ),
                    if (ekstraGiderToplam > 0)
                      _buildListRow(
                        "Ekstra Giderler",
                        ekstraGiderToplam,
                        const Color(0xFFEC4899),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGiderChip({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          Consumer<PrivacyProvider>(
            builder:
                (context, privacy, child) => Text(
                  privacy.isHidden ? "****" : Formatlayici.yap(value),
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // --- MİNİ LİSTE WIDGETI ---
  bool _tarihAralikta(DateTime tarih, DateTime baslangic, DateTime bitis) {
    return !tarih.isBefore(baslangic) && !tarih.isAfter(bitis);
  }

  bool _aylikFinansAralikta(
    AylikFinans finans,
    DateTime baslangic,
    DateTime bitis,
  ) {
    final ayBaslangici = DateTime(finans.yil, finans.ay, 1);
    final ayBitisi = DateTime(finans.yil, finans.ay + 1, 0, 23, 59, 59);
    return !ayBitisi.isBefore(baslangic) && !ayBaslangici.isAfter(bitis);
  }

  // ==========================================
  // 1. PERSONEL HAKEDİŞ GİDERİ KARTI (LİKİT CAM)
  // ==========================================
  Widget _buildPersonelHakedisKarti({
    required BuildContext context,
    required bool isDark,
    required Map<String, MaasHesaplamaSonucu> hesaplar,
    required double toplamMaas,
  }) {
    final double toplamAvans = hesaplar.values.fold(
      0.0,
      (sum, s) => sum + s.toplamAvans,
    );
    final double kalanNetBorc = hesaplar.values.fold(
      0.0,
      (sum, s) => sum + s.odenecekTutar,
    );

    final aktifHesaplar =
        hesaplar.values
            .where(
              (s) =>
                  s.toplamHakedis > 0 ||
                  s.toplamAvans > 0 ||
                  s.toplamGiderMasrafi > 0,
            )
            .toList();

    final int toplamTam = aktifHesaplar.fold(0, (sum, s) => sum + s.tamGun);
    final int toplamYarim = aktifHesaplar.fold(0, (sum, s) => sum + s.yarimGun);
    final double toplamMesaiYevmiye =
        aktifHesaplar.fold(0.0, (sum, s) => sum + s.toplamMesaiYevmiye);
    final double toplamYevmiye =
        toplamTam + (toplamYarim * 0.5) + toplamMesaiYevmiye;
    final String yevmiyeMetni =
        "${toplamYevmiye % 1 == 0 ? toplamYevmiye.toInt() : toplamYevmiye.toStringAsFixed(1)} Yevmiye";

    // Dağılım Çubuğu Hacimleri
    final double totalHakedisVolume = (toplamAvans +
            (kalanNetBorc > 0 ? kalanNetBorc : 0.0))
        .clamp(1.0, double.infinity);
    final double avansShare = (toplamAvans / totalHakedisVolume).clamp(
      0.04,
      0.96,
    );
    final double kalanShare = ((kalanNetBorc > 0 ? kalanNetBorc : 0.0) /
            totalHakedisVolume)
        .clamp(0.04, 0.96);

    // Filtreleme ve Sıralama
    List<MaasHesaplamaSonucu> filtrelenmisListe = List.from(aktifHesaplar);
    if (_personelFiltre == 'Kalanı Olanlar') {
      filtrelenmisListe =
          filtrelenmisListe.where((s) => s.odenecekTutar > 0).toList();
    } else if (_personelFiltre == 'Yüksek Hakediş') {
      filtrelenmisListe.sort(
        (a, b) => b.toplamHakedis.compareTo(a.toplamHakedis),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _buildPanelGlassCardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÜST BAŞLIK VE TIKLANABİLİR PANEL
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _personelKartAcik = !_personelKartAcik;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // İkon Rozeti (Sleek White Glass)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.08),
                            isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.engineering_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Başlık ve Rozet
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                "PERSONEL HAKEDİŞLERİ",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              // Kapsül Rozet: XX Personel • YY Yevmiye (Clean White / Slate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(
                                            0xFF0F172A,
                                          ).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? Colors.white.withValues(
                                              alpha: 0.18,
                                            )
                                            : const Color(
                                              0xFF0F172A,
                                            ).withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  "${aktifHesaplar.length} Personel • $yevmiyeMetni",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Toplam Hakediş Tutarı
                          Consumer<PrivacyProvider>(
                            builder: (context, privacy, child) {
                              if (privacy.isHidden) {
                                return Text(
                                  "**** TL",
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                  ),
                                );
                              }
                              return SayiSayici(
                                hedefDeger: toplamMaas,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Aç/Kapa Ok İkonu
                    AnimatedRotation(
                      turns: _personelKartAcik ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AÇILABİLİR İÇERİK
            if (_personelKartAcik) ...[
              const SizedBox(height: 14),

              // Ödenen Avans vs. Kalan Borç Dağılım Çubuğu (Yalnızca avans verilmişse aktif)
              if (toplamAvans > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 7,
                    child: Row(
                      children: [
                        // Ödenen Avans (Yeşil)
                        Expanded(
                          flex: (avansShare * 1000).toInt(),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Kalan Net Borç (Turkuaz)
                        Expanded(
                          flex: (kalanShare * 1000).toInt(),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Alt Açıklama Etiketleri
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 4,
                  spacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => Text(
                                "Ödenen Avans: ${privacy.isHidden ? '****' : Formatlayici.yap(toplamAvans)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF06B6D4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => Text(
                                "Kalan Net: ${privacy.isHidden ? '****' : Formatlayici.yap(kalanNetBorc)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF06B6D4),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Hızlı Filtre / Sıralama Çipleri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: "Tümü (${aktifHesaplar.length})",
                      selected: _personelFiltre == 'Tümü',
                      isDark: isDark,
                      onTap: () => setState(() => _personelFiltre = 'Tümü'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label:
                          "Kalanı Olanlar (${aktifHesaplar.where((s) => s.odenecekTutar > 0).length})",
                      selected: _personelFiltre == 'Kalanı Olanlar',
                      isDark: isDark,
                      onTap:
                          () => setState(
                            () => _personelFiltre = 'Kalanı Olanlar',
                          ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: "Yüksek Hakediş",
                      selected: _personelFiltre == 'Yüksek Hakediş',
                      isDark: isDark,
                      onTap:
                          () => setState(
                            () => _personelFiltre = 'Yüksek Hakediş',
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Personel Cam Satırları (Glass Tiles)
              if (filtrelenmisListe.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      "Seçili kriterde personel bulunamadı.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                ...filtrelenmisListe.map(
                  (s) => _buildModernPersonelSatiri(s, isDark),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              selected
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFF0F172A))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : const Color(0xFF0F172A))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0)),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color:
                selected
                    ? (isDark ? Colors.white : Colors.white)
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPersonelSatiri(MaasHesaplamaSonucu s, bool isDark) {
    final double toplamGelirMaliyeti = s.toplamHakedis + s.toplamGiderMasrafi;
    final double avansOrani =
        toplamGelirMaliyeti > 0
            ? (s.toplamAvans / toplamGelirMaliyeti).clamp(0.0, 1.0)
            : 0.0;

    // Baş harfleri al
    final words = s.isci.ad.trim().split(RegExp(r'\s+'));
    final initials =
        words.length > 1
            ? '${words.first[0]}${words.last[0]}'.toUpperCase()
            : (s.isci.ad.isNotEmpty
                ? s.isci.ad
                    .substring(0, math.min(2, s.isci.ad.length))
                    .toUpperCase()
                : "P");

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _buildPanelGlassInsetDecoration(
        isDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar (White / Dark Slate)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.09),
                            ]
                            : [
                              const Color(0xFF334155),
                              const Color(0xFF0F172A),
                            ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // İsim ve Yevmiye Rozeti
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.isci.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${s.toplamYevmiye % 1 == 0 ? s.toplamYevmiye.toInt() : s.toplamYevmiye.toStringAsFixed(1)} Yevmiye (${s.tamGun} Tam${s.yarimGun > 0 ? ' / ${s.yarimGun} Yarım' : ''}${s.mesaiGun > 0 ? ' / ${s.mesaiGun} Mesai' : ''})",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (s.toplamGiderMasrafi > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: isDark ? 0.16 : 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "+${Formatlayici.yap(s.toplamGiderMasrafi)} Gider",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Sağ Taraf: Net Ödenecek Rakamı
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Kalan Net",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                  Consumer<PrivacyProvider>(
                    builder:
                        (context, privacy, child) => Text(
                          privacy.isHidden
                              ? "**** TL"
                              : Formatlayici.yap(s.odenecekTutar),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color:
                                s.odenecekTutar > 0
                                    ? (isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF059669))
                                    : (isDark
                                        ? Colors.white54
                                        : const Color(0xFF64748B)),
                          ),
                        ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 18),
                color: _kBrandTeal,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "İşçi Raporunu Metin Olarak Paylaş",
                onPressed: () {
                  final metin =
                      "🏗️ ${s.isci.ad} - Ay Sonu Hakediş Özeti ($_donemBaslikMetni)\n"
                      "• Çalışma: ${s.tamGun} Tam, ${s.yarimGun} Yarım${s.mesaiGun > 0 ? ', ${s.mesaiGun} Mesai (${s.toplamMesaiYevmiye.toStringAsFixed(1)} Yevmiye)' : ''}\n"
                      "• Toplam Hakediş: ${Formatlayici.yap(s.toplamHakedis)}\n"
                      "${s.toplamGiderMasrafi > 0 ? '• Karşılanan Gider Masrafı: +${Formatlayici.yap(s.toplamGiderMasrafi)}\n' : ''}"
                      "• Alınan Avans: ${Formatlayici.yap(s.toplamAvans)}\n"
                      "--------------------------\n"
                      "• KALAN NET: ${Formatlayici.yap(s.odenecekTutar)}";
                  final box = context.findRenderObject() as RenderBox?;
                  final origin = (box != null && box.hasSize)
                      ? (box.localToGlobal(Offset.zero) & box.size)
                      : const Rect.fromLTWH(0, 0, 100, 100);
                  Share.share(metin, subject: "${s.isci.ad} Ay Sonu Raporu", sharePositionOrigin: origin);
                },
              ),
            ],
          ),
          // Alt İlerleme Çizgisi: Yalnızca Avans Verilmişse Göster
          if (s.toplamAvans > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: avansOrani,
                  backgroundColor:
                      isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    avansOrani >= 1.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  "%${(avansOrani * 100).toStringAsFixed(0)} avansla kapatıldı",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                Consumer<PrivacyProvider>(
                  builder:
                      (context, privacy, child) => Text(
                        "Avans: ${privacy.isHidden ? '****' : Formatlayici.yap(s.toplamAvans)}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 2. OPERASYONEL GİDERLER KARTI (LİKİT CAM)
  // ==========================================
  Widget _buildOperasyonelGiderlerKarti({
    required BuildContext context,
    required bool isDark,
    required double topBenzin,
    required double topYemek,
    required double topEk,
    required Map<String, OperasyonelHarcamaOzeti> operasyonelHarcamaSahipleri,
    required Map<String, List<OperasyonelHarcamaDetay>>
    operasyonelHarcamaDetaylari,
    required List<GunlukSantiyeRaporu> raporlar,
  }) {
    final double topOperasyonel = topBenzin + topYemek + topEk;

    // Fiş ve Kayıt Adetleri
    final int benzinKayitSayisi =
        raporlar.where((r) => r.benzinGideri > 0).length;
    final int yemekKayitSayisi =
        raporlar.where((r) => r.yemekGideri > 0).length;
    final int ekKayitSayisi = raporlar.where((r) => r.ekMasraflar > 0).length;
    final int toplamFisSayisi =
        benzinKayitSayisi + yemekKayitSayisi + ekKayitSayisi;

    // Yüzdesel Hacimler (minimum 0.04 görsel genişlik)
    final double benzinShare =
        topOperasyonel > 0
            ? (topBenzin / topOperasyonel).clamp(0.04, 0.92)
            : 0.33;
    final double yemekShare =
        topOperasyonel > 0
            ? (topYemek / topOperasyonel).clamp(0.04, 0.92)
            : 0.33;
    final double ekShare =
        topOperasyonel > 0 ? (topEk / topOperasyonel).clamp(0.04, 0.92) : 0.34;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _buildPanelGlassCardDecoration(isDark),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÜST BAŞLIK VE TIKLANABİLİR PANEL
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _operasyonelKartAcik = !_operasyonelKartAcik;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // İkon Rozeti
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(
                              0xFF06B6D4,
                            ).withValues(alpha: isDark ? 0.25 : 0.16),
                            const Color(
                              0xFF0891B2,
                            ).withValues(alpha: isDark ? 0.18 : 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        color: Color(0xFF06B6D4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Başlık ve Rozet
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                "OPERASYONEL GİDERLER",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              // Fiş Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withValues(alpha: isDark ? 0.16 : 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF06B6D4,
                                    ).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  "$toplamFisSayisi Fiş / Kayıt",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF06B6D4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Toplam Operasyonel Tutarı
                          Consumer<PrivacyProvider>(
                            builder: (context, privacy, child) {
                              if (privacy.isHidden) {
                                return Text(
                                  "**** TL",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF06B6D4),
                                  ),
                                );
                              }
                              return SayiSayici(
                                hedefDeger: topOperasyonel,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF06B6D4),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Aç/Kapa Ok İkonu
                    AnimatedRotation(
                      turns: _operasyonelKartAcik ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // AÇILABİLİR İÇERİK
            if (_operasyonelKartAcik) ...[
              const SizedBox(height: 14),

              // 3 Renkli Kategori Dağılım Barı
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 7,
                  child: Row(
                    children: [
                      // Benzin (Turkuaz)
                      Expanded(
                        flex: (benzinShare * 1000).toInt(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Yemek (Amber)
                      Expanded(
                        flex: (yemekShare * 1000).toInt(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Ek Masraf (Mor)
                      Expanded(
                        flex: (ekShare * 1000).toInt(),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Yüzdesel Gösterge Etiketleri
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildLegendItem(
                    label: "Benzin",
                    ratio:
                        topOperasyonel > 0
                            ? (topBenzin / topOperasyonel) * 100
                            : 0,
                    color: const Color(0xFF06B6D4),
                  ),
                  _buildLegendItem(
                    label: "Yemek",
                    ratio:
                        topOperasyonel > 0
                            ? (topYemek / topOperasyonel) * 100
                            : 0,
                    color: const Color(0xFFF59E0B),
                  ),
                  _buildLegendItem(
                    label: "Ek Masraf",
                    ratio:
                        topOperasyonel > 0 ? (topEk / topOperasyonel) * 100 : 0,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Görünüm Seçici (Segmented Switch - No Overflow)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFEDF4F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFDBE8EE),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _operasyonelSekme = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _operasyonelSekme == 0
                                    ? (isDark
                                        ? const Color(0xFF0F1720)
                                        : Colors.white)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow:
                                _operasyonelSekme == 0
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.3 : 0.06,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 14,
                                  color:
                                      _operasyonelSekme == 0
                                          ? const Color(0xFF06B6D4)
                                          : (isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Kategoriye Göre",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight:
                                        _operasyonelSekme == 0
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color:
                                        _operasyonelSekme == 0
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))
                                            : (isDark
                                                ? Colors.white60
                                                : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _operasyonelSekme = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 7,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _operasyonelSekme == 1
                                    ? (isDark
                                        ? const Color(0xFF0F1720)
                                        : Colors.white)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow:
                                _operasyonelSekme == 1
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.3 : 0.06,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 14,
                                  color:
                                      _operasyonelSekme == 1
                                          ? const Color(0xFF06B6D4)
                                          : (isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Kişiye Göre",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight:
                                        _operasyonelSekme == 1
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color:
                                        _operasyonelSekme == 1
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))
                                            : (isDark
                                                ? Colors.white60
                                                : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // GÖRÜNÜM 1: Kategoriye Göre (3 Görsel Harcama Segmenti)
              if (_operasyonelSekme == 0) ...[
                Row(
                  children: [
                    // 1. Yakıt / Benzin Kartı
                    Expanded(
                      child: _buildCategorySegmentCard(
                        title: "Yakıt / Benzin",
                        amount: topBenzin,
                        countText: "$benzinKayitSayisi Fiş / İşlem",
                        icon: Icons.local_gas_station_rounded,
                        color: const Color(0xFF06B6D4),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. Yemek Kartı
                    Expanded(
                      child: _buildCategorySegmentCard(
                        title: "Yemek Gideri",
                        amount: topYemek,
                        countText: "$yemekKayitSayisi Harcama",
                        icon: Icons.restaurant_rounded,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. Ek / Diğer Kartı
                    Expanded(
                      child: _buildCategorySegmentCard(
                        title: "Ek / Diğer",
                        amount: topEk,
                        countText: "$ekKayitSayisi Kalem",
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],

              // GÖRÜNÜM 2: Harcayan Kişiye Göre
              if (_operasyonelSekme == 1) ...[
                if (operasyonelHarcamaSahipleri.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Kayıtlı kişi bazlı operasyonel harcama bulunamadı.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  ...operasyonelHarcamaSahipleri.entries.map(
                    (entry) => _buildModernHarcamaSahibiSatiri(
                      ad: entry.key,
                      ozet: entry.value,
                      detaylar:
                          operasyonelHarcamaDetaylari[entry.key] ?? const [],
                      isDark: isDark,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required double ratio,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          "$label %${ratio.toStringAsFixed(0)}",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySegmentCard({
    required String title,
    required double amount,
    required String countText,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Consumer<PrivacyProvider>(
              builder:
                  (context, privacy, child) => Text(
                    privacy.isHidden ? "****" : Formatlayici.yap(amount),
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            countText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHarcamaSahibiSatiri({
    required String ad,
    required OperasyonelHarcamaOzeti ozet,
    required List<OperasyonelHarcamaDetay> detaylar,
    required bool isDark,
  }) {
    // İsim baş harfi
    final words = ad.trim().split(RegExp(r'\s+'));
    final initials =
        words.length > 1
            ? '${words.first[0]}${words.last[0]}'.toUpperCase()
            : (ad.isNotEmpty
                ? ad.substring(0, math.min(2, ad.length)).toUpperCase()
                : "O");

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _buildPanelGlassInsetDecoration(
        isDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: 0.8),
                      const Color(0xFF0F7C86),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Harcayan Adı ve Tutar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Consumer<PrivacyProvider>(
                        builder:
                            (context, privacy, child) => Text(
                              "Toplam: ${privacy.isHidden ? '**** TL' : Formatlayici.yap(ozet.toplam)}",
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF06B6D4),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // "Detaylandır" Cam Butonu
              if (detaylar.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _operasyonelDetayDallanmaGoster(ad, detaylar),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Detaylandır",
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0891B2),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: Color(0xFF0891B2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Mikro Renkli Kategori Noktaları
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (ozet.benzin > 0)
                _buildMicroChip(
                  label: "Benzin: ${Formatlayici.yap(ozet.benzin)}",
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
              if (ozet.yemek > 0)
                _buildMicroChip(
                  label: "Yemek: ${Formatlayici.yap(ozet.yemek)}",
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              if (ozet.ekMasraf > 0)
                _buildMicroChip(
                  label: "Ek: ${Formatlayici.yap(ozet.ekMasraf)}",
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroChip({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Consumer<PrivacyProvider>(
            builder:
                (context, privacy, child) => Text(
                  privacy.isHidden ? "****" : label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _operasyonelDetayBottomSheetGoster(
    String kisiAdi,
    List<OperasyonelHarcamaDetay> detaylar,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final siraliDetaylar = [...detaylar]
      ..sort((a, b) => b.tarih.compareTo(a.tarih));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark
              ? const Color(0xFF0F1720)
              : const Color.fromARGB(255, 13, 22, 25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$kisiAdi - Harcama Detayı",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: siraliDetaylar.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = siraliDetaylar[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "${d.kalem} • ${d.santiyeAdi}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            DateFormat('d MMMM yyyy', 'tr_TR').format(d.tarih),
                          ),
                          trailing: Consumer<PrivacyProvider>(
                            builder:
                                (context, privacy, child) => Text(
                                  privacy.isHidden
                                      ? "**** TL"
                                      : Formatlayici.yap(d.tutar),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _operasyonelDetayDallanmaGoster(
    String kisiAdi,
    List<OperasyonelHarcamaDetay> detaylar,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, List<OperasyonelHarcamaDetay>> santiyeBazli = {};
    for (final d in detaylar) {
      santiyeBazli
          .putIfAbsent(d.santiyeAdi, () => <OperasyonelHarcamaDetay>[])
          .add(d);
    }
    final santiyeler = santiyeBazli.keys.toList()..sort();
    final double kisiToplam = detaylar.fold(0.0, (t, d) => t + d.tutar);

    final words = kisiAdi.trim().split(RegExp(r'\s+'));
    final initials =
        words.length > 1
            ? '${words.first[0]}${words.last[0]}'.toUpperCase()
            : (kisiAdi.isNotEmpty
                ? kisiAdi
                    .substring(0, math.min(2, kisiAdi.length))
                    .toUpperCase()
                : "O");

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
          decoration: _buildPanelGlassCardDecoration(
            isDark,
            borderRadius: BorderRadius.circular(26),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sürüklenebilir Üst Çubuk
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Başlık ve Profil Bilgisi
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kisiAdi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                "${detaylar.length} harcama kaydı • ${santiyeler.length} şantiye",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF06B6D4,
                            ).withValues(alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF06B6D4,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Consumer<PrivacyProvider>(
                            builder:
                                (context, privacy, child) => Text(
                                  privacy.isHidden
                                      ? "**** TL"
                                      : Formatlayici.yap(kisiToplam),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0891B2),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                      height: 16,
                    ),
                  ),

                  // Şantiye Bazlı Harcama Kartları Listesi
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: santiyeler.length,
                      itemBuilder: (context, idx) {
                        final santiyeAdi = santiyeler[idx];
                        final kayitlar = [
                          ...(santiyeBazli[santiyeAdi] ??
                              const <OperasyonelHarcamaDetay>[]),
                        ]..sort((a, b) => b.tarih.compareTo(a.tarih));
                        final double santiyeToplam = kayitlar.fold(
                          0.0,
                          (t, e) => t + e.tutar,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: _buildPanelGlassInsetDecoration(
                            isDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                8,
                                0,
                                8,
                                8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withValues(alpha: isDark ? 0.16 : 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_city_rounded,
                                  color: Color(0xFF06B6D4),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                santiyeAdi,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                "${kayitlar.length} fiş / kayıt",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color:
                                      isDark
                                          ? Colors.white60
                                          : const Color(0xFF64748B),
                                ),
                              ),
                              trailing: Consumer<PrivacyProvider>(
                                builder:
                                    (context, privacy, child) => Text(
                                      privacy.isHidden
                                          ? "**** TL"
                                          : Formatlayici.yap(santiyeToplam),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: const Color(0xFF06B6D4),
                                      ),
                                    ),
                              ),
                              children:
                                  kayitlar.map((d) {
                                    final Color kalemRengi =
                                        d.kalem.toLowerCase().contains(
                                                  'benzin',
                                                ) ||
                                                d.kalem.toLowerCase().contains(
                                                  'yakıt',
                                                )
                                            ? const Color(0xFF06B6D4)
                                            : (d.kalem.toLowerCase().contains(
                                                  'yemek',
                                                )
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF10B981));
                                    final IconData kalemIkonu =
                                        d.kalem.toLowerCase().contains(
                                                  'benzin',
                                                ) ||
                                                d.kalem.toLowerCase().contains(
                                                  'yakıt',
                                                )
                                            ? Icons.local_gas_station_rounded
                                            : (d.kalem.toLowerCase().contains(
                                                  'yemek',
                                                )
                                                ? Icons.restaurant_rounded
                                                : Icons.receipt_long_rounded);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? Colors.white.withValues(
                                                  alpha: 0.03,
                                                )
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                  : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: kalemRengi.withValues(
                                                alpha: isDark ? 0.16 : 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              kalemIkonu,
                                              size: 14,
                                              color: kalemRengi,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  d.kalem,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                            : const Color(
                                                              0xFF0F172A,
                                                            ),
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat(
                                                    'd MMMM yyyy',
                                                    'tr_TR',
                                                  ).format(d.tarih),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color:
                                                        isDark
                                                            ? Colors.white54
                                                            : const Color(
                                                              0xFF94A3B8,
                                                            ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Consumer<PrivacyProvider>(
                                            builder:
                                                (
                                                  context,
                                                  privacy,
                                                  child,
                                                ) => Text(
                                                  privacy.isHidden
                                                      ? "****"
                                                      : Formatlayici.yap(
                                                        d.tutar,
                                                      ),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: kalemRengi,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniList(dynamic first, dynamic second, [Function(int)? onSil]) {
    // New usage: _buildMiniList('Label', 'Value')
    if (first is String && second is String) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.90)
                      : Colors.grey[800],
              fontSize: 12,
            ),
            children: [
              TextSpan(
                text: '$first: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: second,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // Legacy usage: _buildMiniList(List<FinansalKalem>, Color, onSil)
    final liste = first as List<FinansalKalem>;
    final renk = second as Color;
    final silFn = onSil!;
    return Column(
      children: List.generate(liste.length, (index) {
        final item = liste[index];
        return Padding(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.ad,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
              Text(
                Formatlayici.yap(item.miktar),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: renk,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => silFn(index),
                child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildListRow(
    String label,
    double value,
    Color color, {
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: fontWeight),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, maxWidth: 170),
            child: Consumer<PrivacyProvider>(
              builder:
                  (context, privacy, child) => Text(
                    privacy.isHidden ? "**** TL" : Formatlayici.yap(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiderPastaGrafik(
    BuildContext context, {
    required double odenenMaas,
    required double benzin,
    required double yemek,
    required double ek,
    required double ekstraGider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dilimler =
        <_PastaDilim>[
          _PastaDilim("Personel", odenenMaas, const Color(0xFF10B981)),
          _PastaDilim("Benzin", benzin, const Color(0xFFEF4444)),
          _PastaDilim("Yemek", yemek, const Color(0xFFF59E0B)),
          _PastaDilim("Ek Operasyonel", ek, const Color(0xFF3B82F6)),
          _PastaDilim("Ekstra Gider", ekstraGider, const Color(0xFFEC4899)),
        ].where((d) => d.tutar > 0).toList();

    final toplamGider = dilimler.fold<double>(0.0, (t, d) => t + d.tutar);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFDCE8EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GİDER ORANLARI",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: isDark ? Colors.white70 : const Color(0xFF5A6C78),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) {
                  return SizedBox(
                    width: 112,
                    height: 112,
                    child: CustomPaint(
                      painter: _PastaGrafikPainter(
                        dilimler: dilimler,
                        progress: progress,
                      ),
                      child: Center(
                        child: Consumer<PrivacyProvider>(
                          builder:
                              (context, privacy, child) => Text(
                                privacy.isHidden
                                    ? "****"
                                    : Formatlayici.yap(toplamGider),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155),
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  runSpacing: 6,
                  children:
                      dilimler.map((d) {
                        final oran =
                            toplamGider <= 0
                                ? 0.0
                                : (d.tutar / toplamGider) * 100;
                        return Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: d.renk,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d.ad,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${oran.toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEkstraKalemlerKarti({
    required BuildContext context,
    required AylikFinans aylikFinans,
    required FirestoreServisi servisi,
    required double ekstraGelirToplam,
    required double ekstraGiderToplam,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFDCE8EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Ekstra Kalemler",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildEkstraEkleButonu(
                color: Colors.green,
                icon: Icons.add_rounded,
                onTap: () {
                  _kalemEkleDialog(context, "Ekstra Gelir Ekle", (ad, miktar) {
                    aylikFinans.ekstraGelirler.add(
                      FinansalKalem(ad: ad, miktar: miktar),
                    );
                    servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildEkstraEkleButonu(
                color: Colors.red,
                icon: Icons.remove_rounded,
                onTap: () {
                  _kalemEkleDialog(context, "Ekstra Gider Ekle", (ad, miktar) {
                    aylikFinans.ekstraGiderler.add(
                      FinansalKalem(ad: ad, miktar: miktar),
                    );
                    servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniList(
                "Ekstra Gelir",
                Formatlayici.yap(ekstraGelirToplam),
              ),
              _buildMiniList(
                "Ekstra Gider",
                Formatlayici.yap(ekstraGiderToplam),
              ),
            ],
          ),
          if (aylikFinans.ekstraGelirler.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniList(aylikFinans.ekstraGelirler, Colors.green[700]!, (
              index,
            ) {
              aylikFinans.ekstraGelirler.removeAt(index);
              servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
            }),
          ],
          if (aylikFinans.ekstraGiderler.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniList(aylikFinans.ekstraGiderler, Colors.red[700]!, (
              index,
            ) {
              aylikFinans.ekstraGiderler.removeAt(index);
              servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEkstraEkleButonu({
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    double value,
    Color color, {
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isLarge ? 18 : 15,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Consumer<PrivacyProvider>(
          builder:
              (context, privacy, child) => FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  privacy.isHidden ? "**** TL" : Formatlayici.yap(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: isLarge ? 20 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
        ),
      ],
    );
  }
}

class _PastaDilim {
  final String ad;
  final double tutar;
  final Color renk;
  const _PastaDilim(this.ad, this.tutar, this.renk);
}

class _PastaGrafikPainter extends CustomPainter {
  final List<_PastaDilim> dilimler;
  final double progress;

  const _PastaGrafikPainter({required this.dilimler, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (dilimler.isEmpty) {
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..color = const Color(0xFF94A3B8).withValues(alpha: 0.25);
      final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: (math.min(size.width, size.height) / 2) - 10,
      );
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);
      return;
    }

    final toplam = dilimler.fold<double>(0.0, (t, d) => t + d.tutar);
    if (toplam <= 0) return;

    final strokeWidth = 16.0;
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    var startAngle = -math.pi / 2;
    for (final dilim in dilimler) {
      final oran = dilim.tutar / toplam;
      final sweep = (math.pi * 2 * oran) * progress;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = strokeWidth
            ..color = dilim.renk;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += math.pi * 2 * oran;
    }
  }

  @override
  bool shouldRepaint(covariant _PastaGrafikPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.dilimler != dilimler;
  }
}

// --- AY/YIL SEÇİCİ ---
class _AyYilSeciciDialog extends StatefulWidget {
  final DateTime baslangicTarihi;
  final ValueChanged<DateTime> onSecildi;
  const _AyYilSeciciDialog({
    required this.baslangicTarihi,
    required this.onSecildi,
  });
  @override
  State<_AyYilSeciciDialog> createState() => _AyYilSeciciDialogState();
}

class _AyYilSeciciDialogState extends State<_AyYilSeciciDialog> {
  late int _seciliYil;
  @override
  void initState() {
    super.initState();
    _seciliYil = widget.baslangicTarihi.year;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(color: Colors.transparent),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => _seciliYil--),
                      ),
                      Text(
                        _seciliYil.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => _seciliYil++),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final ayDate = DateTime(_seciliYil, index + 1);
                      final isSelected =
                          ayDate.month == widget.baslangicTarihi.month &&
                          ayDate.year == widget.baslangicTarihi.year;
                      return ChoiceChip(
                        label: Text(DateFormat.MMM('tr_TR').format(ayDate)),
                        selected: isSelected,
                        onSelected: (val) {
                          widget.onSecildi(ayDate);
                          Navigator.pop(context);
                        },
                        selectedColor: _kBrandTealDark,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "İptal",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
