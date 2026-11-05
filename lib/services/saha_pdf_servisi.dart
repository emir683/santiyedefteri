// lib/services/saha_pdf_servisi.dart

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Türkiye İSG ve Çalışma Mevzuatına (6331 Sayılı İSG Kanunu, KKD Yönetmeliği,
/// İş Ekipmanlarının Kullanımında Sağlık ve Güvenlik Şartları Yönetmeliği) uygun
/// profesyonel, ıslak imzaya hazır resmi şantiye tutanakları üreten PDF servisi.
class SahaPdfServisi {
  static Future<pw.Font> _fontYukle() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      return pw.Font.ttf(fontData);
    } catch (_) {
      return await PdfGoogleFonts.robotoRegular();
    }
  }

  static Future<pw.Font> _boldFontYukle() async {
    try {
      return await PdfGoogleFonts.robotoBold();
    } catch (_) {
      return await _fontYukle();
    }
  }

  /// Tekil bir saha kaydı (Malzeme, Zimmet veya İSG) için mevzuata uygun resmi tutanak üretir ve yazdırır.
  static Future<void> kayitIcinResmiTutanakOlustur({
    required Map<String, dynamic> kayit,
    required String teamId,
    String? ekipAdi,
  }) async {
    final regularFont = await _fontYukle();
    final boldFont = await _boldFontYukle();

    final pdf = pw.Document();

    final String tip = (kayit['tip'] ?? 'malzeme').toString();
    final String baslik = (kayit['baslik'] ?? 'Belirtilmedi').toString();
    final String miktarVeyaKisi = (kayit['miktarVeyaKisi'] ?? '').toString();
    final String santiye = (kayit['santiye'] ?? 'Merkez Şantiye').toString();
    final String notlar = (kayit['not'] ?? '').toString();
    final String? standart = kayit['standart'] as String?;
    final String? seriNoVeyaPlaka = kayit['seriNo'] as String?;
    final String? calismaSaati = kayit['calismaSaati'] as String?;
    final String? tcKimlikNo = kayit['tcKimlikNo'] as String?;
    final String? ustaMeslek = kayit['ustaMeslek'] as String?;
    final bool acil = kayit['acil'] == true;

    final DateTime tarih;
    final dynamic t = kayit['tarih'];
    if (t != null && t is DateTime) {
      tarih = t;
    } else if (t != null && t.runtimeType.toString().contains('Timestamp')) {
      tarih = (t as dynamic).toDate();
    } else {
      tarih = DateTime.now();
    }

    final tarihStr = DateFormat('dd.MM.yyyy HH:mm').format(tarih);
    final evrakNo = 'SNT-${tarih.year}${tarih.month.toString().padLeft(2, '0')}-${kayit.hashCode.abs().toString().substring(0, 5)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. ÜST KURUMSAL BAŞLIK & EVRAK NUMARASI
              _buildHeader(
                regularFont: regularFont,
                boldFont: boldFont,
                ekipAdi: ekipAdi ?? 'ŞANTİYE YÖNETİMİ OPERASYON MERKEZİ',
                santiye: santiye,
                evrakNo: evrakNo,
                tarihStr: tarihStr,
              ),
              pw.SizedBox(height: 12),

              // 2. TUTANAK TİPİNE ÖZEL MEVZUAT BAŞLIĞI
              _buildMevzuatBasligi(tip: tip, boldFont: boldFont, regularFont: regularFont),
              pw.SizedBox(height: 14),

              // 3. TARAF & ŞANTİYE BİLGİLERİ TABLOSU
              _buildTaraflarTablosu(
                tip: tip,
                santiye: santiye,
                miktarVeyaKisi: miktarVeyaKisi,
                tcKimlikNo: tcKimlikNo,
                ustaMeslek: ustaMeslek,
                regularFont: regularFont,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 14),

              // 4. MALZEME / EKİPMAN / İSG DETAY TABLOSU
              _buildEkipmanVeyaMalzemeTablosu(
                tip: tip,
                baslik: baslik,
                miktarVeyaKisi: miktarVeyaKisi,
                standart: standart,
                seriNoVeyaPlaka: seriNoVeyaPlaka,
                calismaSaati: calismaSaati,
                acil: acil,
                notlar: notlar,
                regularFont: regularFont,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 14),

              // 5. YASAL TAAHHÜTNAME & CEZAİ ŞART BİLGİLENDİRMESİ
              _buildYasalTaahhutMetni(tip: tip, regularFont: regularFont, boldFont: boldFont),
              pw.Spacer(),

              // 6. ÇİFT ISLAK İMZA VE KAŞE ALANI
              _buildImzaKutulari(
                tip: tip,
                teslimAlanAd: miktarVeyaKisi.isNotEmpty ? miktarVeyaKisi : 'Çalışan / Yetkili',
                tcKimlikNo: tcKimlikNo,
                regularFont: regularFont,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 8),

              // 7. ALT DİPNOT (BİLGİSAYAR ÇIKTISI & DOĞRULAMA KODU)
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'İşbu tutanak iki nüsha olarak tanzim edilmiş olup bir nüshası teslim alana verilmiştir.',
                    style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Şantiye Puantaj Defteri v4.1 (6331 İSG Uyumlu)',
                    style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final filename = '${tip.toUpperCase()}_TUTANAGI_${DateFormat('yyyyMMdd').format(tarih)}_$evrakNo.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: filename,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // YARDIMCI PDF BİLEŞENLERİ
  // ──────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required pw.Font regularFont,
    required pw.Font boldFont,
    required String ekipAdi,
    required String santiye,
    required String evrakNo,
    required String tarihStr,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  ekipAdi.toUpperCase(),
                  style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.blueGrey900),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'ŞANTİYE SAHASI: $santiye',
                  style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.teal900),
                ),
              ],
            ),
          ),
          pw.Container(width: 1, height: 36, color: PdfColors.grey400, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('BELGE NO: $evrakNo', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('DÜZENLEME TARİHİ: $tarihStr', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMevzuatBasligi({
    required String tip,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    String mevzuatReferansi;
    String anaBaslik;

    if (tip == 'isg') {
      mevzuatReferansi = 'T.C. 6331 SAYILI İŞ SAĞLIĞI VE GÜVENLİĞİ KANUNU (MADDE 4, 19)\nVE KİŞİSEL KORUYUCU DONANIMLARIN İŞYERLERİNDE KULLANILMASI HAKKINDA YÖNETMELİK KAPSAMINDA';
      anaBaslik = 'KİŞİSEL KORUYUCU DONANIM (KKD) TESLİM VE TAAHHÜT TUTANAĞI';
    } else if (tip == 'zimmet') {
      mevzuatReferansi = 'T.C. 6331 SAYILI İŞ SAĞLIĞI VE GÜVENLİĞİ KANUNU İLE\nİŞ EKİPMANLARININ KULLANIMINDA SAĞLIK VE GÜVENLİK ŞARTLARI YÖNETMELİĞİ GEREĞİNCE';
      anaBaslik = 'İŞ EKİPMANI VE MAKİNE ZİMMET / TESLİM-TESELLÜM TUTANAĞI';
    } else {
      mevzuatReferansi = 'T.C. YAPI DENETİMİ UYGULAMA YÖNETMELİĞİ & 213 SAYILI VERGİ USUL KANUNU GEREĞİNCE';
      anaBaslik = 'ŞANTİYE MALZEME KABUL VE İRSALİYE TESLİM TUTANAĞI';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.teal800, width: 2),
          top: pw.BorderSide(color: PdfColors.teal800, width: 0.8),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            mevzuatReferansi,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            anaBaslik,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.teal900),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTaraflarTablosu({
    required String tip,
    required String santiye,
    required String miktarVeyaKisi,
    String? tcKimlikNo,
    String? ustaMeslek,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    final String teslimAlanUnvani = tip == 'zimmet'
        ? 'ZİMMET ALAN (OPERATÖR / USTA)'
        : (tip == 'isg' ? 'KKD TESLİM ALAN ÇALIŞAN' : 'MALZEME KABUL SORUMLUSU');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('İŞVEREN / ŞANTİYE BİLGİLERİ', style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(teslimAlanUnvani, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Şantiye Adı: $santiye', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                  pw.SizedBox(height: 2),
                  pw.Text('Yetkili: Şantiye Şefi / İSG Uzmanı', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                  pw.SizedBox(height: 2),
                  pw.Text('Denetim Durumu: Aktif Şantiye Denetimi', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Adı Soyadı: ${miktarVeyaKisi.isNotEmpty ? miktarVeyaKisi : "Belirtilmedi"}', style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
                  pw.SizedBox(height: 2),
                  pw.Text('Görevi / Mesleği: ${ustaMeslek ?? (tip == 'zimmet' ? 'Operatör / Formen' : 'Çalışan / Usta')}', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                  pw.SizedBox(height: 2),
                  pw.Text('T.C. Kimlik / Sicil No: ${tcKimlikNo ?? "............................."}', style: pw.TextStyle(font: regularFont, fontSize: 8.5)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildEkipmanVeyaMalzemeTablosu({
    required String tip,
    required String baslik,
    required String miktarVeyaKisi,
    String? standart,
    String? seriNoVeyaPlaka,
    String? calismaSaati,
    required bool acil,
    required String notlar,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('S.NO', style: pw.TextStyle(font: boldFont, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tip == 'malzeme' ? 'MALZEME CİNSİ & KALİTE TANIMI' : (tip == 'zimmet' ? 'İŞ MAKİNESİ / EKİPMAN TANIMI' : 'KKD / İSG DENETİM BAŞLIĞI'), style: pw.TextStyle(font: boldFont, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('STANDART / CE / PLAKA', style: pw.TextStyle(font: boldFont, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('MİKTAR / SAYAÇ', style: pw.TextStyle(font: boldFont, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('DURUM / KONDİSYON', style: pw.TextStyle(font: boldFont, fontSize: 8))),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('1', style: pw.TextStyle(font: regularFont, fontSize: 8.5))),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(baslik, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
                  if (notlar.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Not / İrsaliye: $notlar', style: pw.TextStyle(font: regularFont, fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ],
              ),
            ),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(standart ?? (seriNoVeyaPlaka ?? 'CE / Standartlara Uygun'), style: pw.TextStyle(font: regularFont, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(calismaSaati ?? (miktarVeyaKisi.isNotEmpty ? miktarVeyaKisi : '1 Adet'), style: pw.TextStyle(font: boldFont, fontSize: 8))),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                acil ? 'DİKKAT / EKSİK (ACİL)' : 'Eksiksiz & Faal',
                style: pw.TextStyle(font: boldFont, fontSize: 8, color: acil ? PdfColors.red800 : PdfColors.green800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildYasalTaahhutMetni({
    required String tip,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    String metin;

    if (tip == 'isg') {
      metin =
          '6331 Sayılı İş Sağlığı ve Güvenliği Kanunu\'nun 19. Maddesi ve "Kişisel Koruyucu Donanımların İşyerlerinde Kullanılması Hakkında Yönetmelik" hükümleri gereğince; '
          'yukarıda cinsi, standardı ve miktarı belirtilen kişisel koruyucu donanımları (KKD) sağlam, çalışır, CE işaretli ve eksiksiz olarak teslim aldım. '
          'Tarafıma verilen İSG eğitimi ve talimatlarına uygun olarak şantiye sınırları içerisinde çalışma süresince söz konusu donanımları KESİNTİSİZ KULLANACAĞIMI, '
          'temiz ve özenli muhafaza edeceğimi, hasar veya kayıp halinde amirlerime derhal bildireceğimi, donanımları kullanmamaktan doğacak her türlü hukuki, cezai ve idari '
          'sorumluluğun şahsıma ait olduğunu kabul, beyan ve taahhüt ederim.';
    } else if (tip == 'zimmet') {
      metin =
          '6331 Sayılı İSG Kanunu ve "İş Ekipmanlarının Kullanımında Sağlık ve Güvenlik Şartları Yönetmeliği" hükümleri doğrultusunda; yukarıda özellikleri yazılı iş makinesi / ekipmanı '
          'çalışır, bakımlı ve güvenlik donanımları (koruyucu muhafazalar, acil stop, ışıklı/sesli ikaz sistemleri) tam vaziyette teslim aldım. '
          'Ekipmanı üretici ve şantiye emniyet kurallarına uygun olarak kullanacağımı, yetkisiz veya ehliyetsiz kişilere KESİNLİKLE KULLANDIRMAYACAĞIMI, periyodik kontrollerini ve günlük '
          'ön kontrollerini yapacağımı, meydana gelebilecek herhangi bir arızada çalışmayı derhal durdurarak amirlerime bildireceğimi taahhüt ederim.';
    } else {
      metin =
          'Yukarıda dökümü yapılan inşaat malzemeleri şantiye sahasında kalite, standart, numune kontrolü ve irsaliye muhteviyatına uygunluk açısından fiziki olarak kontrol edilmiş '
          've eksiksiz olarak teslim alınmıştır. Malzemenin şantiye stok sahasında usulüne uygun şekilde istiflenmesi ve korunmasından teslim alan yetkili sorumludur.';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('YASAL TAAHHÜTNAME VE BEYAN METNİ:', style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.blueGrey900)),
          pw.SizedBox(height: 3),
          pw.Text(
            metin,
            textAlign: pw.TextAlign.justify,
            style: pw.TextStyle(font: regularFont, fontSize: 8, height: 1.35, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildImzaKutulari({
    required String tip,
    required String teslimAlanAd,
    String? tcKimlikNo,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    final String teslimEdenBaslik = tip == 'malzeme'
        ? 'TESLİM EDEN (NAKLİYECİ / SEVKİYAT)'
        : 'TESLİM EDEN (ŞANTİYE ŞEFİ / İSG UZMANI)';

    final String teslimAlanBaslik = tip == 'zimmet'
        ? 'TESLİM ALAN (OPERATÖR / USTA)'
        : (tip == 'isg' ? 'TESLİM ALAN ÇALIŞAN (ISLAK İMZA)' : 'TESLİM ALAN (ŞANTİYE KABUL SORUMLUSU)');

    return pw.Row(
      children: [
        // TESLİM EDEN
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1.0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(teslimEdenBaslik, style: pw.TextStyle(font: boldFont, fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text('Adı Soyadı: ...........................................', style: pw.TextStyle(font: regularFont, fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text('Unvanı: Şantiye Şefi / Yetkili', style: pw.TextStyle(font: regularFont, fontSize: 8)),
                pw.SizedBox(height: 25),
                pw.Text('İmza / Kaşe: .......................................', style: pw.TextStyle(font: regularFont, fontSize: 8)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        // TESLİM ALAN
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600, width: 1.0),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(teslimAlanBaslik, style: pw.TextStyle(font: boldFont, fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text('Adı Soyadı: $teslimAlanAd', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text('T.C. Kimlik No: ${tcKimlikNo ?? "..........................................."}', style: pw.TextStyle(font: regularFont, fontSize: 8)),
                pw.SizedBox(height: 25),
                pw.Text('Islak İmza: .........................................', style: pw.TextStyle(font: regularFont, fontSize: 8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Seçili sekmedeki tüm kayıtları tek bir toplu resmi denetim ve operasyon cetveli olarak PDF yapar.
  static Future<void> topluRaporOlustur({
    required List<Map<String, dynamic>> kayitlar,
    required String tip,
    required String teamId,
    String? santiyeFiltre,
  }) async {
    final regularFont = await _fontYukle();
    final boldFont = await _boldFontYukle();

    final pdf = pw.Document();
    final simdi = DateTime.now();
    final tarihStr = DateFormat('dd.MM.yyyy HH:mm').format(simdi);

    final String baslik = tip == 'malzeme'
        ? 'ŞANTİYE MALZEME, İRSALİYE VE SEVKİYAT İCMAL RAPORU'
        : (tip == 'zimmet'
            ? 'ŞANTİYE İŞ MAKİNESİ VE EKİPMAN ZİMMET İCMAL LİSTESİ'
            : 'ŞANTİYE İSG SAHA DENETİM VE KKD TAKİP İCMAL CETVELİ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ŞANTİYE OPERASYON VE SAHA DENETİM MERKEZİ', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.blueGrey800)),
                  pw.Text('Tarih: $tarihStr', style: pw.TextStyle(font: regularFont, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(baslik, style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.teal900)),
              if (santiyeFiltre != null && santiyeFiltre.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Filtrelenen Şantiye: $santiyeFiltre', style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey700)),
              ],
              pw.Divider(thickness: 1, color: PdfColors.teal800),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('NO', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TARİH', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('ŞANTİYE', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TANIM / KALİTE', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MİKTAR / SORUMLU', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('NOT / DURUM', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                  ],
                ),
                ...kayitlar.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final k = entry.value;
                  final bool acil = k['acil'] == true;
                  final d = k['tarih'];
                  DateTime rowDate;
                  if (d is DateTime) {
                    rowDate = d;
                  } else if (d != null && d.runtimeType.toString().contains('Timestamp')) {
                    rowDate = (d as dynamic).toDate();
                  } else {
                    rowDate = DateTime.now();
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$idx', style: pw.TextStyle(font: regularFont, fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd.MM.yy').format(rowDate), style: pw.TextStyle(font: regularFont, fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((k['santiye'] ?? '-').toString(), style: pw.TextStyle(font: regularFont, fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((k['baslik'] ?? '-').toString(), style: pw.TextStyle(font: boldFont, fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((k['miktarVeyaKisi'] ?? '-').toString(), style: pw.TextStyle(font: regularFont, fontSize: 7.5))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          acil ? 'ACİL / EKSİK: ${(k['not'] ?? '')}' : (k['not'] ?? 'Tamam'),
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 7.5,
                            color: acil ? PdfColors.red800 : PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOPLAM KAYIT: ${kayitlar.length}', style: pw.TextStyle(font: boldFont, fontSize: 9)),
                pw.Text('Raporu Onaylayan Şantiye Şefi: ....................................... (İmza)', style: pw.TextStyle(font: regularFont, fontSize: 9)),
              ],
            ),
          ];
        },
      ),
    );

    final filename = 'TOPLU_${tip.toUpperCase()}_ICMAL_${DateFormat('yyyyMMdd_HHmm').format(simdi)}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: filename,
    );
  }
}

