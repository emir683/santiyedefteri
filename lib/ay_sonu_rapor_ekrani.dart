import 'dart:ui'; // Blur için gerekli
import 'dart:typed_data';
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

// Yardımcı Sınıf
class MaasHesaplamaSonucu {
  final Isci isci;
  int tamGun = 0;
  int yarimGun = 0;
  double toplamHakedis = 0.0;
  double toplamAvans = 0.0;
  double odenecekTutar = 0.0;
  MaasHesaplamaSonucu(this.isci);
}

class AySonuRaporEkrani extends StatefulWidget {
  final String teamId;
  const AySonuRaporEkrani({super.key, required this.teamId});

  @override
  State<AySonuRaporEkrani> createState() => _AySonuRaporEkraniState();
}

class _AySonuRaporEkraniState extends State<AySonuRaporEkrani> {
  DateTime _seciliAy = DateTime.now();

  // --- PDF OLUŞTURMA (9 Parametre Alıyor) ---
  String _raporuMetneDonustur(
    String ay,
    Map<String, MaasHesaplamaSonucu> sonuclar,
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
    sb.writeln('--- $ay GENEL RAPORU ---');
    sb.writeln('\nMAAŞLAR:');
    for (var s in sonuclar.values.where(
      (i) => i.toplamHakedis > 0 || i.toplamAvans > 0,
    )) {
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
          onSecildi: (secilen) => setState(() => _seciliAy = secilen),
        );
      },
    );
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
                                backgroundColor: Colors.blue,
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
  void _paylasimMenusunuGoster(String metin) {
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
                        final bytes = await _raporuPdfOlustur(metin);
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
    final baslangic = DateTime(_seciliAy.year, _seciliAy.month, 1);
    final bitis = DateTime(_seciliAy.year, _seciliAy.month + 1, 0, 23, 59, 59);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ay Sonu Raporu"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: "Genel Özet"),
              Tab(icon: Icon(Icons.location_city), text: "Şantiye Bazlı"),
            ],
          ),
        ),
        body: Column(
          children: [
            // ORTAK TARİH SEÇİCİ
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month, color: Colors.blue),
                  ),
                  title: Text(
                    DateFormat.yMMMM('tr_TR').format(_seciliAy),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () => _aySeciciGoster(context),
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

                                  return StreamBuilder<AylikFinans?>(
                                    stream: servisi.getAylikFinansStream(
                                      widget.teamId,
                                      _seciliAy.year,
                                      _seciliAy.month,
                                    ),
                                    builder: (context, snapFinans) {
                                      final aylikFinans =
                                          snapFinans.data ??
                                          AylikFinans(
                                            yil: _seciliAy.year,
                                            ay: _seciliAy.month,
                                          );

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

                                      for (var r in raporlar) {
                                        topBenzin += r.benzinGideri;
                                        topYemek += r.yemekGideri;
                                        topEk += r.ekMasraflar;
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
                                        if (a.tarih.year == _seciliAy.year &&
                                            a.tarih.month == _seciliAy.month) {
                                          if (hesaplar.containsKey(a.isci.ad))
                                            hesaplar[a.isci.ad]!.toplamAvans +=
                                                a.miktar;
                                        }
                                      }

                                      double toplamMaas = 0;
                                      hesaplar.forEach((_, h) {
                                        // h.toplamHakedis is now accumulated in the loop above
                                        h.odenecekTutar =
                                            h.toplamHakedis - h.toplamAvans;
                                        toplamMaas += h.toplamHakedis;
                                      });

                                      double kayitliGelir = 0;
                                      for (var o in odemeler) {
                                        if (o.tarih.year == _seciliAy.year &&
                                            o.tarih.month == _seciliAy.month)
                                          kayitliGelir += o.miktar;
                                      }

                                      // Ek Gelir/Gider Toplamları
                                      double toplamEkstraGelir = aylikFinans
                                          .ekstraGelirler
                                          .fold(
                                            0.0,
                                            (sum, item) => sum + item.miktar,
                                          );
                                      double toplamEkstraGider = aylikFinans
                                          .ekstraGiderler
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
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              children: [
                                                _buildExpansionCard(
                                                  context,
                                                  "PERSONEL HAKEDİŞ GİDERİ", // Renamed from Odenen
                                                  toplamMaas, // Showing Accrued amount
                                                  Icons.people_alt_outlined,
                                                  Colors.purple,
                                                  [
                                                    SingleChildScrollView(
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
                                                    _buildListRow(
                                                      "Benzin",
                                                      topBenzin,
                                                      Colors.redAccent,
                                                    ),
                                                    _buildListRow(
                                                      "Yemek",
                                                      topYemek,
                                                      Colors.orangeAccent,
                                                    ),
                                                    _buildListRow(
                                                      "Ek Operasyonel",
                                                      topEk,
                                                      Colors.blueAccent,
                                                    ),
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
                                                        Colors.blue,
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
                                                            _raporuMetneDonustur(
                                                              DateFormat.yMMMM(
                                                                'tr_TR',
                                                              ).format(
                                                                _seciliAy,
                                                              ),
                                                              hesaplar,
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
                                                padding: const EdgeInsets.all(
                                                  16,
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
                                                                o.tarih.year ==
                                                                    _seciliAy
                                                                        .year &&
                                                                o.tarih.month ==
                                                                    _seciliAy
                                                                        .month,
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
                                                                ? Colors
                                                                    .grey[800]!
                                                                : Colors
                                                                    .grey[300]!,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    color:
                                                        isDark
                                                            ? const Color(
                                                              0xFF1E1E1E,
                                                            )
                                                            : Colors.white,
                                                    child: ExpansionTile(
                                                      leading: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.teal
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
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
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Consumer<PrivacyProvider>(
          builder:
              (context, privacy, child) => Text(
                privacy.isHidden ? "**** TL" : Formatlayici.yap(amount),
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
    return Card(
      elevation: 4,
      shadowColor:
          isDark
              ? Colors.black.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  netDurum >= 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                        // --- 1. KAYITLI GELİRLER KUTUSU (BÜYÜK) ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "KAYITLI GELİRLER",
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Consumer<PrivacyProvider>(
                                builder:
                                    (context, privacy, child) => Text(
                                      privacy.isHidden
                                          ? "**** TL"
                                          : Formatlayici.yap(kayitliGelir),
                                      style: TextStyle(
                                        color: Colors.green[900],
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- 2. EKSTRA GELİRLER KUTUSU ---
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Ekstra Gelirler",
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      _kalemEkleDialog(
                                        context,
                                        "Ekstra Gelir Ekle",
                                        (ad, miktar) {
                                          aylikFinans.ekstraGelirler.add(
                                            FinansalKalem(
                                              ad: ad,
                                              miktar: miktar,
                                            ),
                                          );
                                          servisi.aylikFinansGuncelle(
                                            widget.teamId,
                                            aylikFinans,
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (aylikFinans.ekstraGelirler.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildMiniList(
                                  aylikFinans.ekstraGelirler,
                                  Colors.green[700]!,
                                  (index) {
                                    aylikFinans.ekstraGelirler.removeAt(index);
                                    servisi.aylikFinansGuncelle(
                                      widget.teamId,
                                      aylikFinans,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- 3. EKSTRA GİDERLER KUTUSU (MOVED UP) ---
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Ekstra Giderler",
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      _kalemEkleDialog(
                                        context,
                                        "Ekstra Gider Ekle",
                                        (ad, miktar) {
                                          aylikFinans.ekstraGiderler.add(
                                            FinansalKalem(
                                              ad: ad,
                                              miktar: miktar,
                                            ),
                                          );
                                          servisi.aylikFinansGuncelle(
                                            widget.teamId,
                                            aylikFinans,
                                          );
                                        },
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (aylikFinans.ekstraGiderler.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildMiniList(
                                  aylikFinans.ekstraGiderler,
                                  Colors.red[700]!,
                                  (index) {
                                    aylikFinans.ekstraGiderler.removeAt(index);
                                    servisi.aylikFinansGuncelle(
                                      widget.teamId,
                                      aylikFinans,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
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
  Widget _buildMiniList(
    List<FinansalKalem> liste,
    Color renk,
    Function(int) onSil,
  ) {
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
                onTap: () => onSil(index),
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
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: fontWeight)),
      trailing: Consumer<PrivacyProvider>(
        builder:
            (context, privacy, child) => Text(
              privacy.isHidden ? "**** TL" : Formatlayici.yap(value),
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
      ),
      dense: true,
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
        Text(
          title,
          style: TextStyle(
            fontSize: isLarge ? 18 : 15,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Consumer<PrivacyProvider>(
          builder:
              (context, privacy, child) => Text(
                privacy.isHidden ? "**** TL" : Formatlayici.yap(value),
                style: TextStyle(
                  fontSize: isLarge ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
        ),
      ],
    );
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
                        selectedColor: Colors.blue,
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
