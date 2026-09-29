import 'data_models.dart';

class SesliPuantajSonucu {
  Santiye? algilananSantiye;
  Map<String, String> isciDurumlari;
  double benzinGideri;
  double yemekGideri;
  double ekMasraflar;
  String santiyeNotu;
  String? hamSantiyeMetni;
  String? rawWorkersText;
  String? rawExpensesText;

  SesliPuantajSonucu({
    this.algilananSantiye,
    required this.isciDurumlari,
    this.benzinGideri = 0,
    this.yemekGideri = 0,
    this.ekMasraflar = 0,
    this.santiyeNotu = "",
    this.hamSantiyeMetni,
    this.rawWorkersText,
    this.rawExpensesText,
  });
}

class AkilliSesAyristirici {
  static String normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static Map<String, String> ayristirIsciler({
    required String metin,
    required List<Isci> isciler,
  }) {
    final Map<String, String> durumlari = {};
    if (metin.trim().isEmpty || isciler.isEmpty) return durumlari;

    final m = metin.toLowerCase().trim();
    final normMetin = normalize(m);

    // 1. Toplu İfadeler (Bütün Ekip / Tüm Ekip / Ustalar / Herkes / Hepsi)
    const tamGunTopluPatterns = [
      "bütün ekip",
      "butun ekip",
      "tüm ekip",
      "tum ekip",
      "ekip tam",
      "ekip tamam",
      "bütün ustalar",
      "butun ustalar",
      "tüm ustalar",
      "tum ustalar",
      "ustalar tam",
      "herkes tam",
      "hepsi tam",
      "herkes çalıştı",
      "herkes calisti",
      "hepsi çalıştı",
      "hepsi calisti",
      "herkes burada",
      "herkes geldi",
      "herkes full",
      "herkes ful",
      "tamamı",
      "tamami",
      "tümü",
      "tumu",
      "tam kadro",
      "hepsi",
      "herkes",
      "ekip",
    ];

    const yarimGunTopluPatterns = [
      "bütün ekip yarım",
      "butun ekip yarim",
      "tüm ekip yarım",
      "tum ekip yarim",
      "ekip yarım",
      "ekip yarim",
      "herkes yarım",
      "herkes yarim",
      "bütün ustalar yarım",
      "herkes buçuk",
      "herkes bucuk",
      "ekip buçuk",
      "ekip bucuk",
      "yarım gün çalıştı herkes",
    ];

    bool topluYarim = false;
    for (var pat in yarimGunTopluPatterns) {
      if (m.contains(pat) || normMetin.contains(normalize(pat))) {
        topluYarim = true;
        break;
      }
    }

    if (topluYarim) {
      for (var isci in isciler) {
        durumlari[isci.ad] = "Yarım Gün";
      }
      return durumlari;
    }

    bool topluTam = false;
    for (var pat in tamGunTopluPatterns) {
      if (m == pat ||
          m == "$pat çalıştı" ||
          m == "$pat calisti" ||
          m == "$pat geldi" ||
          m == "$pat tam" ||
          m.contains(pat) ||
          normMetin == normalize(pat) ||
          normMetin.contains(normalize(pat))) {
        topluTam = true;
        break;
      }
    }

    if (topluTam) {
      for (var isci in isciler) {
        durumlari[isci.ad] = "Tam Gün";
      }
      return durumlari;
    }

    // 2. Kelime (Token) ve Pozisyon Bazlı Eşleştirme
    // Metni kelimelere ayır ve her kelimenin normalize halini çıkar
    final List<String> rawTokens = m.split(RegExp(r'[\s,\.\+&]+')).where((t) => t.isNotEmpty).toList();
    final List<String> normTokens = rawTokens.map(normalize).toList();

    // Her işçinin metin içinde eşleşen ilk token pozisyonunu bul
    final List<({Isci isci, int startIndex, int tokenLength})> matches = [];

    for (var isci in isciler) {
      final List<String> isciTokens = isci.ad.toLowerCase().split(RegExp(r'\s+')).map(normalize).toList();
      if (isciTokens.isEmpty) continue;

      int foundIdx = -1;
      int matchLen = 1;

      // Tam isim eşleşmesi ara (örn. ["kadir", "celik"])
      if (isciTokens.length > 1) {
        for (int i = 0; i <= normTokens.length - isciTokens.length; i++) {
          bool allMatch = true;
          for (int j = 0; j < isciTokens.length; j++) {
            if (normTokens[i + j] != isciTokens[j]) {
              allMatch = false;
              break;
            }
          }
          if (allMatch) {
            foundIdx = i;
            matchLen = isciTokens.length;
            break;
          }
        }
      }

      // Tekil isim veya isim parçası eşleşmesi ara
      if (foundIdx == -1) {
        for (var it in isciTokens) {
          if (it.length < 2) continue;
          for (int i = 0; i < normTokens.length; i++) {
            if (normTokens[i] == it) {
              foundIdx = i;
              matchLen = 1;
              break;
            }
          }
          if (foundIdx != -1) break;
        }
      }

      if (foundIdx != -1) {
        matches.add((isci: isci, startIndex: foundIdx, tokenLength: matchLen));
      }
    }

    // Eşleşmeleri metin sırasına göre sırala
    matches.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    // Her işçinin kendi segmentindeki duruma bak
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final start = match.startIndex + match.tokenLength;
      final end = (i + 1 < matches.length) ? matches[i + 1].startIndex : normTokens.length;

      // Bu işçi ile bir sonraki işçi arasındaki kelimeleri al
      final segmentWords = normTokens.sublist(start < normTokens.length ? start : normTokens.length, end < normTokens.length ? end : normTokens.length);
      final segmentStr = segmentWords.join(' ');

      if (segmentStr.contains("yarim") ||
          segmentStr.contains("bucuk") ||
          segmentStr.contains("0.5") ||
          segmentWords.contains("yarim") ||
          segmentWords.contains("bucuk")) {
        durumlari[match.isci.ad] = "Yarım Gün";
      } else if (segmentWords.contains("gelmedi") ||
          segmentWords.contains("calismadi") ||
          segmentWords.contains("izinli") ||
          segmentWords.contains("raporlu") ||
          (segmentWords.contains("yok") && !segmentStr.contains("gider") && !segmentStr.contains("masraf"))) {
        durumlari[match.isci.ad] = "Yok";
      } else {
        durumlari[match.isci.ad] = "Tam Gün";
      }
    }

    return durumlari;
  }

  static ({double benzin, double yemek, double ek, String not}) ayristirGiderler(
    String expensesStr,
  ) {
    double benzin = 0;
    double yemek = 0;
    double ek = 0;
    String kalanMetin = expensesStr.toLowerCase().trim();

    final benzinReg1 = RegExp(
      r'(\d+)\s*(lira|tl|bin)?\s*(benzine|benzin|mazota|mazot|yakıta|yakıt)',
      caseSensitive: false,
    );
    final benzinReg2 = RegExp(
      r'(benzine|benzin|mazota|mazot|yakıta|yakıt)\s*(\d+)',
      caseSensitive: false,
    );
    final benzinReg3 = RegExp(
      r'(\d+)\s*(lira|tl)?\s*(benzin|mazot)\s*(aldık|harcadık|verdik|gitti|ödedik)?',
      caseSensitive: false,
    );

    var bMatch =
        benzinReg1.firstMatch(kalanMetin) ??
        benzinReg2.firstMatch(kalanMetin) ??
        benzinReg3.firstMatch(kalanMetin);
    if (bMatch != null) {
      final valStr = bMatch.group(1) ?? bMatch.group(2) ?? "0";
      benzin = double.tryParse(valStr) ?? 0;
      kalanMetin = kalanMetin.replaceAll(bMatch.group(0)!, "");
    }

    final yemekReg1 = RegExp(
      r'(\d+)\s*(lira|tl|bin)?\s*(yemeğe|yemek|gıdaya|gıda|lokanta)',
      caseSensitive: false,
    );
    final yemekReg2 = RegExp(
      r'(yemeğe|yemek|gıdaya|gıda|lokanta)\s*(\d+)',
      caseSensitive: false,
    );
    final yemekReg3 = RegExp(
      r'(\d+)\s*(lira|tl)?\s*(yemeğe|yemek)\s*(verdik|gitti|harcadık|ödedik|yaptık)?',
      caseSensitive: false,
    );

    var yMatch =
        yemekReg1.firstMatch(kalanMetin) ??
        yemekReg2.firstMatch(kalanMetin) ??
        yemekReg3.firstMatch(kalanMetin);
    if (yMatch != null) {
      final valStr = yMatch.group(1) ?? yMatch.group(2) ?? "0";
      yemek = double.tryParse(valStr) ?? 0;
      kalanMetin = kalanMetin.replaceAll(yMatch.group(0)!, "");
    }

    final ekReg1 = RegExp(
      r'(\d+)\s*(lira|tl|bin)?\s*(masrafa|masraf|malzemeye|malzeme|ek)',
      caseSensitive: false,
    );
    final ekReg2 = RegExp(
      r'(masrafa|masraf|malzemeye|malzeme|ek)\s*(\d+)',
      caseSensitive: false,
    );

    var eMatch = ekReg1.firstMatch(kalanMetin) ?? ekReg2.firstMatch(kalanMetin);
    if (eMatch != null) {
      final valStr = eMatch.group(1) ?? eMatch.group(2) ?? "0";
      ek = double.tryParse(valStr) ?? 0;
      kalanMetin = kalanMetin.replaceAll(eMatch.group(0)!, "");
    }

    if (benzin == 0 && yemek == 0 && ek == 0) {
      final genelSayiReg = RegExp(
        r'(\d+)\s*(lira|tl|bin)?',
        caseSensitive: false,
      );
      final gMatch = genelSayiReg.firstMatch(kalanMetin);
      if (gMatch != null) {
        final valStr = gMatch.group(1) ?? "0";
        yemek = double.tryParse(valStr) ?? 0;
        kalanMetin = kalanMetin.replaceAll(gMatch.group(0)!, "");
      }
    }

    kalanMetin = kalanMetin
        .replaceAll(
          RegExp(
            r'\b(lira|tl|bin|verdik|gitti|harcadık|ödedik|aldık|yok|gider yok|masraf yok|harcama yok|not yok|bir şey yok|yoktur)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    String nihaiNot = "";
    if (kalanMetin.length >= 3) {
      nihaiNot = kalanMetin;
    }

    return (benzin: benzin, yemek: yemek, ek: ek, not: nihaiNot);
  }

  static SesliPuantajSonucu ayristirSihirbaz({
    required Map<String, dynamic> wizardData,
    required List<Santiye> santiyeler,
    required List<Isci> isciler,
  }) {
    final siteStr = wizardData['site']?.toString().trim() ?? "";
    final workersStr = wizardData['workers']?.toString().trim() ?? "";
    final expensesStr = wizardData['expenses']?.toString().trim() ?? "";

    Santiye? bulunanSantiye;
    if (siteStr.isNotEmpty) {
      final normSite = normalize(siteStr);
      for (var s in santiyeler) {
        final normS = normalize(s.ad);
        final temizAd = normalize(
          s.ad
              .toLowerCase()
              .replaceAll("şantiyesi", "")
              .replaceAll("santiyesi", "")
              .replaceAll("şantiye", "")
              .replaceAll("santiye", "")
              .trim(),
        );
        if (normS.isNotEmpty &&
            (normSite.contains(normS) ||
                normSite.contains(normSite) ||
                (temizAd.length >= 3 && normSite.contains(temizAd)))) {
          bulunanSantiye = s;
          break;
        }
      }
    }

    final durumlari = ayristirIsciler(metin: workersStr, isciler: isciler);
    final giderler = ayristirGiderler(expensesStr);

    return SesliPuantajSonucu(
      algilananSantiye: bulunanSantiye,
      isciDurumlari: durumlari,
      benzinGideri: giderler.benzin,
      yemekGideri: giderler.yemek,
      ekMasraflar: giderler.ek,
      santiyeNotu: giderler.not,
      hamSantiyeMetni: siteStr,
      rawWorkersText: workersStr,
      rawExpensesText: expensesStr,
    );
  }

  static SesliPuantajSonucu ayristir({
    required String sesMetni,
    required List<Santiye> santiyeler,
    required List<Isci> isciler,
  }) {
    final metin = sesMetni.toLowerCase().trim();
    final normMetin = normalize(metin);
    String kalanMetin = metin;

    Santiye? bulunanSantiye;
    for (var s in santiyeler) {
      final santiyeAd = s.ad.toLowerCase();
      final temizAd = santiyeAd
          .replaceAll("şantiyesi", "")
          .replaceAll("santiyesi", "")
          .replaceAll("şantiye", "")
          .replaceAll("santiye", "")
          .trim();

      final normTemizAd = normalize(temizAd);

      if (normTemizAd.isNotEmpty && normMetin.contains(normTemizAd)) {
        bulunanSantiye = s;
        kalanMetin =
            kalanMetin.replaceAll(santiyeAd, "").replaceAll(temizAd, "");
        break;
      }
    }

    final giderler = ayristirGiderler(kalanMetin);
    final durumlari = ayristirIsciler(metin: kalanMetin, isciler: isciler);

    return SesliPuantajSonucu(
      algilananSantiye: bulunanSantiye,
      isciDurumlari: durumlari,
      benzinGideri: giderler.benzin,
      yemekGideri: giderler.yemek,
      ekMasraflar: giderler.ek,
      santiyeNotu: giderler.not,
      hamSantiyeMetni: sesMetni,
      rawWorkersText: sesMetni,
      rawExpensesText: sesMetni,
    );
  }
}
