import 'dart:ui'; // Blur için gerekli
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const double _shellDockBodyPadding = 132;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

// Yardımcı Sınıf
class MaasHesaplamaSonucu {
  final Isci isci;
  int tamGun = 0;
  int yarimGun = 0;
  double toplamHakedis = 0.0;
  double toplamGiderMasrafi = 0.0;
  double toplamAvans = 0.0;
  double odenecekTutar = 0.0;
  MaasHesaplamaSonucu(this.isci);
}

class OperasyonelHarcamaOzeti {
  double benzin = 0.0;
  double yemek = 0.0;
  double ekMasraf = 0.0;

  double get toplam => benzin + yemek + ekMasraf;
}

class AySonuRaporEkrani extends StatefulWidget {
  final String teamId;
  const AySonuRaporEkrani({super.key, required this.teamId});

  @override
  State<AySonuRaporEkrani> createState() => _AySonuRaporEkraniState();
}

class _AySonuRaporEkraniState extends State<AySonuRaporEkrani> {
  DateTime _seciliAy = DateTime.now();
  DateTimeRange? _seciliTarihAraligi;

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
    final harcamaSahipleri = operasyonelHarcamaSahipleri.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    sb.writeln('--- $donem GENEL RAPORU ---');
    sb.writeln('');
    sb.writeln('PERSONEL HAKED\u0130\u015e VE ALACAK \u00d6ZET\u0130:');
    sb.writeln('\nMAAŞLAR:');
    for (final s in personelSonuclari) {
      sb.writeln(
        '${s.isci.ad}: ${s.tamGun}T, ${s.yarimGun}Y. Hakediş: ${Formatlayici.yap(s.toplamHakedis)} - Avans: ${Formatlayici.yap(s.toplamAvans)} = NET: ${Formatlayici.yap(s.odenecekTutar)}',
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
    final harcamaSahipleri = operasyonelHarcamaSahipleri.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    sb.writeln('--- $donem GENEL RAPORU ---');
    sb.writeln('');
    sb.writeln('PERSONEL HAKEDIS VE ALACAK OZETI:');

    if (personelSonuclari.isEmpty) {
      sb.writeln('Kay\u0131t bulunmuyor.');
    } else {
      for (final s in personelSonuclari) {
        sb.writeln(
          '${s.isci.ad}: ${s.tamGun} tam, ${s.yarimGun} yar\u0131m g\u00fcn | Hakedi\u015f: ${Formatlayici.yap(s.toplamHakedis)} | Gider Masraf\u0131: ${Formatlayici.yap(s.toplamGiderMasrafi)} | Avans: ${Formatlayici.yap(s.toplamAvans)} | Net: ${Formatlayici.yap(s.odenecekTutar)}',
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
    final harcamaSahipleri = operasyonelHarcamaSahipleri.entries.toList()
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
                  _buildPdfInfoCard('Kayitli Gelir', Formatlayici.yap(kayitliGelir), '#DCFCE7', '#166534', ttf),
                  _buildPdfInfoCard('Toplam Gider', Formatlayici.yap(toplamGider), '#FEE2E2', '#B91C1C', ttf),
                  _buildPdfInfoCard('Net Durum', Formatlayici.yap(kar), kar >= 0 ? '#DCFCE7' : '#FEE2E2', kar >= 0 ? '#166534' : '#B91C1C', ttf),
                  _buildPdfInfoCard('Personel Maliyeti', Formatlayici.yap(maas), '#F3E8FF', '#7E22CE', ttf),
                ],
              ),
              pw.SizedBox(height: 22),
              _buildPdfSectionTitle('Finans Ozeti', ttf),
              pw.SizedBox(height: 8),
              _buildPdfValueRow('Kayitli Gelir', Formatlayici.yap(kayitliGelir), ttf),
              _buildPdfValueRow('Ekstra Gelirler', Formatlayici.yap(manuelGelir), ttf),
              _buildPdfValueRow('Toplam Gelir', Formatlayici.yap(toplamGelir), ttf),
              _buildPdfValueRow('Ekstra Giderler', Formatlayici.yap(manuelGider), ttf),
              _buildPdfValueRow('Benzin', Formatlayici.yap(benzin), ttf),
              _buildPdfValueRow('Yemek', Formatlayici.yap(yemek), ttf),
              _buildPdfValueRow('Ek Operasyonel', Formatlayici.yap(ek), ttf),
              _buildPdfValueRow('Net Durum', Formatlayici.yap(kar), ttf, emphasize: true),
              pw.SizedBox(height: 20),
              _buildPdfSectionTitle('Personel Hakedis ve Alacak Ozeti', ttf),
              pw.SizedBox(height: 8),
              personelSonuclari.isEmpty
                  ? pw.Text('Kayit bulunmuyor.', style: pw.TextStyle(font: ttf, fontSize: 11))
                  : pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#111827')),
                    cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    headers: const ['Personel', 'Gun', 'Hakedis', 'Gider Masrafi', 'Avans', 'Net'],
                    data:
                        personelSonuclari
                            .map(
                              (s) => [
                                s.isci.ad,
                                '${s.tamGun}T / ${s.yarimGun}Y',
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
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F766E')),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
        style: pw.TextStyle(font: font, fontSize: 13, color: PdfColor.fromHex('#0F766E')),
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
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColor.fromHex(textHex))),
          pw.SizedBox(height: 8),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 14, color: PdfColor.fromHex(textHex))),
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
    final color = emphasize ? PdfColor.fromHex('#0F766E') : PdfColor.fromHex('#334155');
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
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColor.fromHex('#475569'))),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10, color: color)),
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
      barrierColor: Colors.black.withOpacity(0.8),
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
      barrierColor: Colors.black.withOpacity(0.8),
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
                  color: const Color(0xFF1E1E1E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
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
        fillColor: Colors.white.withOpacity(0.05),
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
                          ? const Color(0xFF1E1E1E).withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
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
                          color: Colors.green.withOpacity(0.2),
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
        backgroundColor:
            isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor:
              isDark
                  ? const Color(0xFF101317).withOpacity(0.92)
                  : Colors.white.withOpacity(0.88),
          surfaceTintColor: Colors.transparent,
          title: const Text("Ay Sonu Raporu"),
          bottom: TabBar(
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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  isDark
                      ? const [Color(0xFF06090D), Color(0xFF0C1219), Color(0xFF111827)]
                      : const [Color(0xFFF6FBFD), Color(0xFFECF5F9), Color(0xFFE4EEF4)],
            ),
          ),
          child: Column(
          children: [
            // ORTAK TARİH SEÇİCİ
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF101317).withOpacity(0.94)
                          : const Color(0xFFF7FBFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFD8EAF0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kBrandTeal.withOpacity(0.12),
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
                        onPressed: () => _tarihAraligiSeciciGoster(context),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                            stream: servisi.getAvanslarStream(widget.teamId),
                            builder: (context, snapAvans) {
                              final avanslar = snapAvans.data ?? [];

                              return StreamBuilder<List<AlinanOdeme>>(
                                stream: servisi.getOdemelerStream(
                                  widget.teamId,
                                ),
                                builder: (context, snapOdemeler) {
                                  final odemeler = snapOdemeler.data ?? [];

                                  return StreamBuilder<List<AylikFinans>>(
                                    stream: servisi.getTumAylikFinanslarStream(
                                      widget.teamId,
                                    ),
                                    builder: (context, snapFinans) {
                                      final tumAylikFinanslar =
                                          snapFinans.data ?? const <AylikFinans>[];
                                      final aylikFinans =
                                          tumAylikFinanslar
                                              .where(
                                                (finans) =>
                                                    finans.yil == _seciliAy.year &&
                                                    finans.ay == _seciliAy.month,
                                              )
                                              .firstOrNull ??
                                          AylikFinans(
                                            yil: _seciliAy.year,
                                            ay: _seciliAy.month,
                                          );
                                      final araliktakiFinanslar =
                                          tumAylikFinanslar
                                              .where(
                                                (finans) => _aylikFinansAralikta(
                                                  finans,
                                                  baslangic,
                                                  bitis,
                                                ),
                                              )
                                              .toList();

                                      // --- HESAPLAMA SIFIRLAMA ---
                                      // Her build işleminde sıfırdan hesaplamak için map'i burada oluşturuyoruz.
                                      final Map<String, MaasHesaplamaSonucu>
                                      hesaplar = {
                                        for (var i in isciler)
                                          i.ad: MaasHesaplamaSonucu(i),
                                      };

                                      // --- GENEL HESAPLAMALAR ---
                                      double topBenzin = 0,
                                          topYemek = 0,
                                          topEk = 0;
                                      final Map<String, OperasyonelHarcamaOzeti>
                                      operasyonelHarcamaSahipleri = {};

                                      for (var r in raporlar) {
                                        topBenzin += r.benzinGideri;
                                        topYemek += r.yemekGideri;
                                        topEk += r.ekMasraflar;
                                        if (r.benzinGideri > 0 &&
                                            r.benzinGideriIsciAdi != null &&
                                            hesaplar.containsKey(
                                              r.benzinGideriIsciAdi,
                                            )) {
                                          hesaplar[r.benzinGideriIsciAdi]!
                                                  .toplamGiderMasrafi +=
                                              r.benzinGideri;
                                          operasyonelHarcamaSahipleri
                                              .putIfAbsent(
                                                r.benzinGideriIsciAdi!,
                                                OperasyonelHarcamaOzeti.new,
                                              )
                                              .benzin += r.benzinGideri;
                                        }
                                        if (r.yemekGideri > 0 &&
                                            r.yemekGideriIsciAdi != null &&
                                            hesaplar.containsKey(
                                              r.yemekGideriIsciAdi,
                                            )) {
                                          hesaplar[r.yemekGideriIsciAdi]!
                                                  .toplamGiderMasrafi +=
                                              r.yemekGideri;
                                          operasyonelHarcamaSahipleri
                                              .putIfAbsent(
                                                r.yemekGideriIsciAdi!,
                                                OperasyonelHarcamaOzeti.new,
                                              )
                                              .yemek += r.yemekGideri;
                                        }
                                        if (r.ekMasraflar > 0 &&
                                            r.ekMasraflarIsciAdi != null &&
                                            hesaplar.containsKey(
                                              r.ekMasraflarIsciAdi,
                                            )) {
                                          hesaplar[r.ekMasraflarIsciAdi]!
                                                  .toplamGiderMasrafi +=
                                              r.ekMasraflar;
                                          operasyonelHarcamaSahipleri
                                              .putIfAbsent(
                                                r.ekMasraflarIsciAdi!,
                                                OperasyonelHarcamaOzeti.new,
                                              )
                                              .ekMasraf += r.ekMasraflar;
                                        }
                                        for (var c in r.calisanlar) {
                                          if (hesaplar.containsKey(c.isci.ad)) {
                                            if (c.durum == "Tam Gün") {
                                              hesaplar[c.isci.ad]!.tamGun++;
                                              hesaplar[c.isci.ad]!
                                                      .toplamHakedis +=
                                                  c.isci.gunlukMaas;
                                            }
                                            if (c.durum == "Yarım Gün") {
                                              hesaplar[c.isci.ad]!.yarimGun++;
                                              hesaplar[c.isci.ad]!
                                                      .toplamHakedis +=
                                                  (c.isci.gunlukMaas / 2);
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
                                          if (hesaplar.containsKey(a.isci.ad))
                                            hesaplar[a.isci.ad]!.toplamAvans +=
                                                a.miktar;
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
                                          .expand((finans) => finans.ekstraGelirler)
                                          .fold(
                                            0.0,
                                            (sum, item) => sum + item.miktar,
                                          );
                                      double toplamEkstraGider =
                                          araliktakiFinanslar
                                          .expand((finans) => finans.ekstraGiderler)
                                          .fold(
                                            0.0,
                                            (sum, item) => sum + item.miktar,
                                          );

                                      double toplamGelir =
                                          kayitliGelir + toplamEkstraGelir;

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
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              16,
                                              16,
                                              _shellDockBodyPadding,
                                            ),
                                            child: Column(
                                              children: [
                                                _buildExpansionCard(
                                                  context,
                                                  "PERSONEL HAKEDİŞ GİDERİ", // Renamed from Odenen
                                                  toplamMaas, // Showing Accrued amount
                                                  Icons.people_alt_outlined,
                                                  Colors.purple,
                                                  [
                                                    if (false) SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: DataTable(
                                                        columnSpacing: 16,
                                                        headingRowHeight: 40,
                                                        columns: const [
                                                          DataColumn(
                                                            label: Text('İşçi'),
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Hakediş',
                                                            ),
                                                            numeric: true,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Avans',
                                                            ),
                                                            numeric: true,
                                                          ),
                                                          DataColumn(
                                                            label: Text(
                                                              'Gider Masrafı',
                                                            ),
                                                            numeric: true,
                                                          ),
                                                          DataColumn(
                                                            label: Text('Net'),
                                                            numeric: true,
                                                          ),
                                                        ],
                                                        rows:
                                                            hesaplar.values
                                                                .where(
                                                                  (s) =>
                                                                      s.toplamHakedis >
                                                                          0 ||
                                                                      s.toplamAvans >
                                                                          0,
                                                                )
                                                                .map(
                                                                  (
                                                                    s,
                                                                  ) => DataRow(
                                                                    cells: [
                                                                      DataCell(
                                                                        Text(
                                                                          s.isci.ad,
                                                                          style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          Formatlayici.yap(
                                                                            s.toplamHakedis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          Formatlayici.yap(
                                                                            s.toplamAvans,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          Formatlayici.yap(
                                                                            s.toplamGiderMasrafi,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      DataCell(
                                                                        Text(
                                                                          Formatlayici.yap(
                                                                            s.odenecekTutar,
                                                                          ),
                                                                          style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color:
                                                                                Colors.green,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                )
                                                                .toList(),
                                                      ),
                                                    ),
                                                    ...hesaplar.values
                                                        .where(
                                                          (s) =>
                                                              s.toplamHakedis > 0 ||
                                                              s.toplamAvans > 0 ||
                                                              s.toplamGiderMasrafi > 0,
                                                        )
                                                        .map(
                                                          (s) => Container(
                                                            margin: const EdgeInsets.only(
                                                              bottom: 10,
                                                            ),
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainerHighest
                                                                  .withOpacity(
                                                                    Theme.of(context).brightness ==
                                                                            Brightness.dark
                                                                        ? 0.18
                                                                        : 0.18,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(12),
                                                              border: Border.all(
                                                                color: Theme.of(context)
                                                                    .dividerColor
                                                                    .withOpacity(
                                                                      Theme.of(context).brightness ==
                                                                              Brightness.dark
                                                                          ? 0.45
                                                                          : 0.28,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              children: [
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 10,
                                                                    vertical: 8,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        Theme.of(context).brightness ==
                                                                                Brightness.dark
                                                                            ? Colors.white.withOpacity(
                                                                              0.08,
                                                                            )
                                                                            : Colors.black.withOpacity(
                                                                              0.08,
                                                                            ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(10),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child: Text(
                                                                          s.isci.ad,
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                            color: Theme.of(context)
                                                                                .colorScheme
                                                                                .onSurface,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(width: 10),
                                                                      Text(
                                                                        'Net: ${Formatlayici.yap(s.odenecekTutar)}',
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Theme.of(context).brightness ==
                                                                                      Brightness.dark
                                                                                  ? const Color(
                                                                                    0xFF6EE7B7,
                                                                                  )
                                                                                  : Colors.green,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Divider(
                                                                  color: Theme.of(context)
                                                                      .dividerColor
                                                                      .withOpacity(
                                                                        Theme.of(context).brightness ==
                                                                                Brightness.dark
                                                                            ? 0.5
                                                                            : 0.35,
                                                                      ),
                                                                  height: 1,
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Wrap(
                                                                  spacing: 8,
                                                                  runSpacing: 8,
                                                                  children: [
                                                                    _buildMiniList(
                                                                      'Hakediş',
                                                                      Formatlayici.yap(
                                                                        s.toplamHakedis,
                                                                      ),
                                                                    ),
                                                                    _buildMiniList(
                                                                      'Gider Masrafı',
                                                                      Formatlayici.yap(
                                                                        s.toplamGiderMasrafi,
                                                                      ),
                                                                    ),
                                                                    _buildMiniList(
                                                                      'Yevmiye',
                                                                      '${s.tamGun} tam / ${s.yarimGun} yarim',
                                                                    ),
                                                                    _buildMiniList(
                                                                      'Avans',
                                                                      Formatlayici.yap(
                                                                        s.toplamAvans,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                    const SizedBox(height: 10),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _buildExpansionCard(
                                                  context,
                                                  "OPERASYONEL GİDERLER",
                                                  topBenzin + topYemek + topEk,
                                                  Icons.pie_chart_outline,
                                                  Colors.orange,
                                                  [
                                                    _buildOperasyonelToplamKart(
                                                      topBenzin: topBenzin,
                                                      topYemek: topYemek,
                                                      topEk: topEk,
                                                    ),
                                                    if (operasyonelHarcamaSahipleri
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 12),
                                                      const Divider(),
                                                      const SizedBox(height: 8),
                                                      ...operasyonelHarcamaSahipleri
                                                          .entries
                                                          .map(
                                                            (entry) =>
                                                                _buildOperasyonelHarcamaSatiri(
                                                                  entry.key,
                                                                  entry.value,
                                                                ),
                                                          ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _buildFinansCard(
                                                  context,
                                                  kayitliGelir,
                                                  toplamGelir,
                                                  toplamGider,
                                                  netDurum,
                                                  aylikFinans,
                                                  isDark,
                                                  servisi,
                                                  toplamMaas, // Passing Accrued (Hakediş) instead of Paid
                                                  topBenzin,
                                                  topYemek,
                                                  topEk,
                                                ),
                                                const SizedBox(height: 24),

                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.share),
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
                                                    minimumSize: const Size(
                                                      double.infinity,
                                                      50,
                                                    ),
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _paylasimMenusunuGoster(
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
                                                const SizedBox(
                                                  height: _shellDockBodyPadding,
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
                                                padding: const EdgeInsets.fromLTRB(
                                                  16,
                                                  16,
                                                  16,
                                                  _shellDockBodyPadding,
                                                ),
                                                itemCount: santiyeler.length,
                                                itemBuilder: (ctx, index) {
                                                  final sAdi =
                                                      santiyeler[index].ad;
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
                                                  for (var o in sOdemeler)
                                                    sGelir += o.miktar;

                                                  for (var r in sRaporlar) {
                                                    sBenzin += r.benzinGideri;
                                                    sYemek += r.yemekGideri;
                                                    sEk += r.ekMasraflar;
                                                    for (var c
                                                        in r.calisanlar) {
                                                      sMaas +=
                                                          (c.durum == "Tam Gün"
                                                              ? c
                                                                  .isci
                                                                  .gunlukMaas
                                                              : (c
                                                                      .isci
                                                                      .gunlukMaas /
                                                                  2));
                                                    }
                                                  }

                                                  double sToplamGider =
                                                      sBenzin +
                                                      sYemek +
                                                      sEk +
                                                      sMaas;
                                                  double sKar =
                                                      sGelir - sToplamGider;

                                                  return Card(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    elevation: 4,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      side: BorderSide(
                                                        color:
                                                            isDark
                                                                ? Colors.white
                                                                    .withOpacity(
                                                                      0.08,
                                                                    )
                                                                : const Color(
                                                                  0xFFD8EAF0,
                                                                ),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    color:
                                                        isDark
                                                            ? const Color(
                                                              0xFF101317,
                                                            )
                                                            : const Color(
                                                              0xFFF7FBFD,
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
                                                              Colors.teal
                                                                  .withOpacity(
                                                                    isDark
                                                                        ? 0.18
                                                                        : 0.14,
                                                                  ),
                                                              (isDark
                                                                      ? const Color(
                                                                        0xFF171B20,
                                                                      )
                                                                      : Colors
                                                                          .white)
                                                                  .withOpacity(
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
                                                            color: Colors.teal
                                                                .withOpacity(
                                                                  isDark
                                                                      ? 0.16
                                                                      : 0.12,
                                                                ),
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.location_city,
                                                          color: Colors.teal,
                                                        ),
                                                      ),
                                                      title: Text(
                                                        sAdi,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .red,
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
                                                                Colors.green,
                                                              ),
                                                              const Divider(),
                                                              _buildListRow(
                                                                "Personel Maliyeti",
                                                                sMaas,
                                                                Colors.purple,
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
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .red,
                                                                isLarge: true,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
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
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFD8EAF0),
          width: 1.5,
        ),
      ),
      color:
          isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isDark ? 0.18 : 0.14),
                (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
                  isDark ? 0.82 : 0.92,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(isDark ? 0.16 : 0.12)),
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

    return Card(
      elevation: 2,
      shadowColor:
          isDark
              ? Colors.black.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFD8EAF0).withOpacity(0.9),
          width: 1,
        ),
      ),
      color:
          isDark ? const Color(0xFF10141A) : const Color(0xFFF7FBFD),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (netDurum >= 0 ? Colors.green : Colors.red).withOpacity(
                    isDark ? 0.18 : 0.14,
                  ),
                  (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
                    isDark ? 0.82 : 0.92,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (netDurum >= 0 ? Colors.green : Colors.red).withOpacity(
                  isDark ? 0.16 : 0.12,
                ),
              ),
            ),
            child: Icon(
              netDurum >= 0 ? Icons.trending_up : Icons.trending_down,
              color: netDurum >= 0 ? Colors.green : Colors.red,
              size: 28,
            ),
          ),
          title: const Text(
            "FİNANSAL DURUM",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Consumer<PrivacyProvider>(
            builder: (context, privacy, child) {
              return Text(
                privacy.isHidden
                    ? "**** TL"
                    : "${netDurum >= 0 ? '+' : ''}${Formatlayici.yap(netDurum)}",
                style: TextStyle(
                  color: netDurum >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              );
            },
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.grey[50]!,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactFinanceStatCard(
                                title: "Kayıtlı Gelir",
                                value: kayitliGelir,
                                color: const Color(0xFF16A34A),
                                icon: Icons.account_balance_wallet_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCompactFinanceStatCard(
                                title: "Toplam Gelir",
                                value: toplamGelir,
                                color: const Color(0xFF0EA5A4),
                                icon: Icons.trending_up_rounded,
                              ),
                            ),
                          ],
                        ),
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

                        const SizedBox(height: 16),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 16),

                        // --- TOPLAM ÖZETİ (GELİR/GİDER) ---
                        _buildListRow(
                          "Toplam Gelir",
                          toplamGelir,
                          Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        _buildListRow(
                          "Toplam Gider",
                          toplamGider,
                          Colors.red,
                          fontWeight: FontWeight.bold,
                        ),

                        const SizedBox(height: 16),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 16),

                        // --- GİDER KALEMLERİ LİSTESİ ---
                        Text(
                          "GİDER DETAYLARI",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildListRow(
                          "Personel Maliyeti (Hakediş)",
                          odenenMaas,
                          Colors.purple,
                        ),
                        _buildListRow(
                          "Benzin Gideri",
                          benzin,
                          Colors.redAccent,
                        ),
                        _buildListRow(
                          "Yemek Gideri",
                          yemek,
                          Colors.orangeAccent,
                        ),
                        _buildListRow("Ek Operasyonel", ek, Colors.blueAccent),

                        const SizedBox(height: 12),

                        const Divider(height: 24),
                        _buildSummaryRow(
                          "NET KÂR/ZARAR",
                          netDurum,
                          netDurum >= 0 ? Colors.green : Colors.red,
                          isLarge: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildOperasyonelToplamKart({
    required double topBenzin,
    required double topYemek,
    required double topEk,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.18 : 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Toplam Operasyonel",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Consumer<PrivacyProvider>(
                  builder:
                      (context, privacy, child) => Text(
                        privacy.isHidden
                            ? "**** TL"
                            : Formatlayici.yap(topBenzin + topYemek + topEk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? const Color(0xFFFBBF24)
                                  : Colors.orange,
                        ),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.5 : 0.35),
            height: 1,
          ),
          const SizedBox(height: 8),
          Consumer<PrivacyProvider>(
            builder:
                (context, privacy, child) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniList(
                      'Benzin',
                      privacy.isHidden ? "**** TL" : Formatlayici.yap(topBenzin),
                    ),
                    _buildMiniList(
                      'Yemek',
                      privacy.isHidden ? "**** TL" : Formatlayici.yap(topYemek),
                    ),
                    _buildMiniList(
                      'Ek Operasyonel',
                      privacy.isHidden ? "**** TL" : Formatlayici.yap(topEk),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperasyonelHarcamaSatiri(
    String ad,
    OperasyonelHarcamaOzeti ozet,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.14 : 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.4 : 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Consumer<PrivacyProvider>(
                builder:
                    (context, privacy, child) => Text(
                      privacy.isHidden ? "**** TL" : Formatlayici.yap(ozet.toplam),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFBBF24) : Colors.orange,
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer<PrivacyProvider>(
            builder:
                (context, privacy, child) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (ozet.benzin > 0)
                      _buildMiniList(
                        'Benzin',
                        privacy.isHidden ? "**** TL" : Formatlayici.yap(ozet.benzin),
                      ),
                    if (ozet.yemek > 0)
                      _buildMiniList(
                        'Yemek',
                        privacy.isHidden ? "**** TL" : Formatlayici.yap(ozet.yemek),
                      ),
                    if (ozet.ekMasraf > 0)
                      _buildMiniList(
                        'Ek',
                        privacy.isHidden ? "**** TL" : Formatlayici.yap(ozet.ekMasraf),
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniList(
    dynamic first,
    dynamic second, [
    Function(int)? onSil,
  ]) {
    // New usage: _buildMiniList('Label', 'Value')
    if (first is String && second is String) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.black.withOpacity(0.08),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.90) : Colors.grey[800],
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

  Widget _buildCompactFinanceStatCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFDCE8EE),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF607482),
                  ),
                ),
                const SizedBox(height: 2),
                Consumer<PrivacyProvider>(
                  builder:
                      (context, privacy, child) => Text(
                        privacy.isHidden ? "**** TL" : Formatlayici.yap(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                ),
              ],
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
    final dilimler = <_PastaDilim>[
      _PastaDilim("Personel", odenenMaas, const Color(0xFF8B5CF6)),
      _PastaDilim("Benzin", benzin, const Color(0xFFEF4444)),
      _PastaDilim("Yemek", yemek, const Color(0xFFF59E0B)),
      _PastaDilim("Ek Operasyonel", ek, const Color(0xFF3B82F6)),
      _PastaDilim("Ekstra Gider", ekstraGider, const Color(0xFFEC4899)),
    ].where((d) => d.tutar > 0).toList();

    final toplamGider = dilimler.fold<double>(0.0, (t, d) => t + d.tutar);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFDCE8EE),
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
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
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
                        final oran = toplamGider <= 0
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${oran.toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
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
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFDCE8EE),
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
                    aylikFinans.ekstraGelirler.add(FinansalKalem(ad: ad, miktar: miktar));
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
                    aylikFinans.ekstraGiderler.add(FinansalKalem(ad: ad, miktar: miktar));
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
              _buildMiniList("Ekstra Gelir", Formatlayici.yap(ekstraGelirToplam)),
              _buildMiniList("Ekstra Gider", Formatlayici.yap(ekstraGiderToplam)),
            ],
          ),
          if (aylikFinans.ekstraGelirler.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniList(
              aylikFinans.ekstraGelirler,
              Colors.green[700]!,
              (index) {
                aylikFinans.ekstraGelirler.removeAt(index);
                servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
              },
            ),
          ],
          if (aylikFinans.ekstraGiderler.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMiniList(
              aylikFinans.ekstraGiderler,
              Colors.red[700]!,
              (index) {
                aylikFinans.ekstraGiderler.removeAt(index);
                servisi.aylikFinansGuncelle(widget.teamId, aylikFinans);
              },
            ),
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

  const _PastaGrafikPainter({
    required this.dilimler,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dilimler.isEmpty) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = const Color(0xFF94A3B8).withOpacity(0.25);
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
      final paint = Paint()
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
              color: const Color(0xFF1E1E1E).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
