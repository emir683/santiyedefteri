import '../../models/metraj_hesap_model.dart';

/// ŞPD AI - Akıllı İnşaat Metraj ve Malzeme Hesaplayıcı 🧱📐
/// Tamamen yerel, deterministik, formüllere dayalı şantiye malzeme motoru.
/// Gemini API veya harici sunucu KULLANMAZ; anlık, hatasız, internetsiz ve limitsiz çalışır.
/// Fire payları, paket/kutu/palet/mikser lojistiği ve yaklaşık piyasa maliyeti döker.
class InsaatMetrajHesaplayici {
  static String formatDouble(double val) => _f(val);
  static String formatPara(double tutar) => _para(tutar);

  /// Prompt'u analiz eder, inşaat metrajı hesabı içeriyorsa formatlanmış rapor döner.
  /// Metraj hesabı değilse null döner.
  static String? hesapla(String prompt) {
    final lower = prompt.toLowerCase();
    final norm = _normalize(lower);

    // 0. Yardım Menüsü
    if (_isHelpRequest(norm)) {
      return _metrajYardimMenusu();
    }

    final model = hesaplaModel(prompt);
    return model?.raporMetni;
  }

  /// Prompt'u analiz eder, yapılandırılmış MetrajHesapModel nesnesi döner.
  static MetrajHesapModel? hesaplaModel(String prompt) {
    final lower = prompt.toLowerCase();
    final norm = _normalize(lower);

    if (_isHelpRequest(norm)) return null;

    if (_isBetonHesabi(norm)) {
      return _extractAndBuildBeton(prompt, norm);
    }
    if (_isTuglaHesabi(norm)) {
      return _extractAndBuildTugla(prompt, norm);
    }
    if (_isSeramikHesabi(norm)) {
      return _extractAndBuildSeramik(prompt, norm);
    }
    if (_isSapHesabi(norm)) {
      return _extractAndBuildSap(prompt, norm);
    }
    if (_isSivaHesabi(norm)) {
      return _extractAndBuildSiva(prompt, norm);
    }
    if (_isBoyaHesabi(norm)) {
      return _extractAndBuildBoya(prompt, norm);
    }
    if (_isDemirHesabi(norm)) {
      return _extractAndBuildDemir(prompt, norm);
    }
    if (_isAlcipanHesabi(norm)) {
      return _extractAndBuildAlcipan(prompt, norm);
    }
    if (_isMantolamaHesabi(norm)) {
      return _extractAndBuildMantolama(prompt, norm);
    }
    if (_isYalitimHesabi(norm)) {
      return _extractAndBuildYalitim(prompt, norm);
    }
    if (_isHafriyatHesabi(norm)) {
      return _extractAndBuildHafriyat(prompt, norm);
    }
    if (_isParkeHesabi(norm)) {
      return _extractAndBuildParke(prompt, norm);
    }

    return null;
  }

  /// Kart üzerinden parametreler değiştirildiğinde anında yeniden hesaplama yapar.
  static MetrajHesapModel recalculate(
    MetrajHesapModel current, {
    double? primaryValue,
    double? secondaryValue,
    String? variant,
    double? birimFiyat,
  }) {
    final pVal = primaryValue ?? current.primaryValue;
    final sVal = secondaryValue ?? current.secondaryValue;
    final vr = variant ?? current.selectedVariant;
    final bFiyat = birimFiyat ?? current.birimFiyat;

    switch (current.category) {
      case 'beton':
        return buildBetonModel(
          alan: pVal,
          kalinlikCm: sVal,
          variant: vr,
          birimFiyat: bFiyat,
          elemanAdi: current.elementAdi,
        );
      case 'tugla':
        return buildTuglaModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'seramik':
        return buildSeramikModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'sap':
        return buildSapModel(
          alan: pVal,
          kalinlikCm: sVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'siva':
        return buildSivaModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'boya':
        return buildBoyaModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'demir':
        return buildDemirModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'alcipan':
        return buildAlcipanModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'mantolama':
        return buildMantolamaModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'yalitim':
        return buildYalitimModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'hafriyat':
        return buildHafriyatModel(
          alan: pVal,
          derinlikM: sVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      case 'parke':
        return buildParkeModel(
          alan: pVal,
          variant: vr,
          birimFiyat: bFiyat,
        );
      default:
        return current;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 1. BETON HESAPLAYICI (Tabliye, Temel, Kolon, Saha)
  // ═══════════════════════════════════════════════════════════
  static bool _isBetonHesabi(String norm) {
    if (norm.contains('kazi') || norm.contains('hafriyat')) return false;
    final keywords = [
      'beton',
      'tabliye',
      'radye',
      'temel',
      'kolon',
      'kiris',
      'grobeton',
      'saha betonu',
      'perde betonu',
      'mikser',
    ];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildBeton(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    double? kalinlikCm = _extractKalinlikCm(original, norm);
    double? direktHacim = _extractHacimM3(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) {
        alan = dim[0] * dim[1];
        if (dim.length >= 3 && kalinlikCm == null) {
          kalinlikCm = dim[2] > 2 ? dim[2] : dim[2] * 100;
        }
      }
    }

    if (kalinlikCm == null && direktHacim == null) {
      if (norm.contains('radye') || norm.contains('temel')) {
        kalinlikCm = 50.0;
      } else if (norm.contains('saha')) {
        kalinlikCm = 12.0;
      } else {
        kalinlikCm = 15.0;
      }
    }

    if (alan == null && direktHacim != null && direktHacim > 0) {
      alan = direktHacim / (kalinlikCm != null ? (kalinlikCm / 100.0) : 0.15);
    }

    if (alan == null || alan <= 0) return null;

    String betonSinifi = 'C25/30';
    final gradeMatch = RegExp(r'(c\s?16|c\s?20|c\s?25|c\s?30|c\s?35|c\s?40)', caseSensitive: false).firstMatch(original);
    if (gradeMatch != null) {
      final g = gradeMatch.group(1)!.toUpperCase().replaceAll(' ', '');
      if (g == 'C25') betonSinifi = 'C25/30';
      else betonSinifi = g;
    }

    String elemanAdi = 'Tabliye / Döşeme Betonu';
    if (norm.contains('radye')) elemanAdi = 'Radye Temel Betonu';
    else if (norm.contains('temel')) elemanAdi = 'Mütemadi / Tekil Temel';
    else if (norm.contains('kolon')) elemanAdi = 'Kolon / Perde Betonu';
    else if (norm.contains('saha')) elemanAdi = 'Saha / Zemin Betonu';
    else if (norm.contains('grobeton')) elemanAdi = 'Grobeton';

    return buildBetonModel(
      alan: alan,
      kalinlikCm: kalinlikCm ?? 15.0,
      variant: betonSinifi,
      elemanAdi: elemanAdi,
    );
  }

  static MetrajHesapModel buildBetonModel({
    double? alan,
    double? kalinlikCm,
    String? variant,
    double? birimFiyat,
    String? elemanAdi,
  }) {
    final a = alan ?? 100.0;
    final k = kalinlikCm ?? 15.0;
    final v = variant ?? 'C25/30';
    final el = elemanAdi ?? 'Tabliye / Döşeme Betonu';

    double bf = birimFiyat ?? 2650.0;
    if (birimFiyat == null) {
      if (v == 'C20') bf = 2400.0;
      else if (v == 'C25' || v == 'C25/30') bf = 2650.0;
      else if (v == 'C30') bf = 2700.0;
      else if (v == 'C35') bf = 2900.0;
      else if (v == 'C40') bf = 3150.0;
    }

    final double netHacim = a * (k / 100.0);
    final double fireOrani = (el.contains('Temel') || el.contains('Grobeton')) ? 0.07 : 0.05;
    final double fireHacmi = netHacim * fireOrani;
    final double toplamSiparis = netHacim + fireHacmi;

    const double mikserKapasite = 8.5;
    final int mikserSayisi = (toplamSiparis / mikserKapasite).ceil();
    final double tahminiDemirTon = (netHacim * 90.0) / 1000.0;
    final double betonMaliyeti = toplamSiparis * bf;
    final double pompaMaliyeti = toplamSiparis >= 15 ? 12000.0 : 0.0;
    final double toplamMaliyet = betonMaliyeti + pompaMaliyeti;

    final buffer = StringBuffer();
    buffer.writeln('🏗️ **ŞPD AI - Hazır Beton & Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📋 **Uygulama:** $el ($v)');
    buffer.writeln('📐 **Döküm Alanı:** ${_f(a)} m²');
    buffer.writeln('📏 **Döküm Kalınlığı:** ${_f(k)} cm');
    buffer.writeln('🧊 **Net Hacim:** ${_f(netHacim)} m³');
    buffer.writeln('⚠️ **Önerilen Fire Payı (%${(fireOrani * 100).toInt()}):** +${_f(fireHacmi)} m³');
    buffer.writeln('🚚 **Toplam Sipariş Hacmi:** **${_f(toplamSiparis)} m³**');
    buffer.writeln('');
    buffer.writeln('📦 **Lojistik & Ekipman İhtiyacı:**');
    buffer.writeln('• **Transmikser Sayısı:** ~**$mikserSayisi Mikser** (8.5 m³ mikser kapasitesiyle)');
    if (toplamSiparis >= 15) {
      buffer.writeln('• **Beton Pompası:** 🚨 Mobil pompa talep edilmelidir (36m - 42m boom).');
    } else {
      buffer.writeln('• **Beton Pompası:** Mikser oluğu ile direkt döküm veya sabit boru yeterli olabilir.');
    }
    buffer.writeln('• **Tahmini Donatı İhtiyacı:** ~${_f(tahminiDemirTon)} Ton demir (90 kg/m³ ortalama)');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Hazır Beton (${_f(toplamSiparis)} m³ x ${_para(bf)}):** ${_para(betonMaliyeti)}');
    if (pompaMaliyeti > 0) {
      buffer.writeln('• **Mobil Beton Pompası Hizmeti:** ${_para(pompaMaliyeti)}');
    }
    buffer.writeln('• **Toplam Tahmini Beton Gideri:** **${_para(toplamMaliyet)}** (+KDV)');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Vibratör yedekli bulundurulmalı; döküm esnasında demire değil betona daldırılmalıdır.');
    buffer.writeln('2. Döküm sonrası ilk 24 saat rötre çatlaklarına karşı nemlendirilmeli, 7 gün boyunca düzenli sulanmalıdır.');
    buffer.writeln('3. Son mikser şantiyeye çıkmadan önce kalıp içi ölçülüp kalan net hacim santrale iletilmelidir.');

    return MetrajHesapModel(
      category: 'beton',
      title: 'Hazır Beton & Metraj Hesabı',
      icon: '🏗️',
      elementAdi: el,
      primaryValue: a,
      primaryLabel: 'Döküm Alanı',
      primaryUnit: 'm²',
      secondaryValue: k,
      secondaryLabel: 'Döküm Kalınlığı',
      secondaryUnit: 'cm',
      selectedVariant: v,
      availableVariants: const ['C20', 'C25/30', 'C30', 'C35', 'C40'],
      birimFiyat: bf,
      birimFiyatLabel: 'm³ Beton Fiyatı (TL)',
      anaMiktar: '${_f(toplamSiparis)} m³',
      anaMiktarLabel: 'Toplam Sipariş Hacmi',
      lojistik: '~$mikserSayisi Mikser',
      lojistikLabel: 'Lojistik (8.5 m³)',
      firePayi: '%${(fireOrani * 100).toInt()} (+${_f(fireHacmi)} m³)',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Tahmini Beton Maliyeti',
      sarfMalzemeler: [
        'Transmikser: ~$mikserSayisi Sefer (8.5 m³)',
        if (toplamSiparis >= 15) 'Beton Pompası: Mobil pompa (36m-42m boom)' else 'Beton Pompası: Mikser oluğu ile direkt döküm',
        'Tahmini Donatı: ~${_f(tahminiDemirTon)} Ton demir (90 kg/m³)',
      ],
      tavsiyeler: const [
        'Vibratör yedekli bulundurulmalı; döküm esnasında demire değil betona daldırılmalıdır.',
        'Döküm sonrası ilk 24 saat rötre çatlaklarına karşı nemlendirilmeli, 7 gün boyunca düzenli sulanmalıdır.',
        'Son mikser şantiyeye çıkmadan önce kalıp içi ölçülüp kalan net hacim santrale iletilmelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. TUĞLA & BİMS & GAZBETON (YTONG) DUVAR HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isTuglaHesabi(String norm) {
    final keywords = ['tugla', 'tuğla', 'duvar', 'bims', 'gazbeton', 'ytong', 'briket'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildTugla(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    String variant = "13.5'luk Tuğla (Standart)";
    if (norm.contains('8.5') || norm.contains('8,5')) {
      variant = "8.5'luk İnce Tuğla";
    } else if (norm.contains('19') || norm.contains('izo')) {
      variant = "19'luk Dış Duvar Tuğlası";
    } else if (norm.contains('bims')) {
      variant = "15-20'lik Bims Blok";
    } else if (norm.contains('gazbeton') || norm.contains('ytong')) {
      variant = "Gazbeton / Ytong";
    }

    return buildTuglaModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildTuglaModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 100.0;
    final v = variant ?? "13.5'luk Tuğla (Standart)";

    double adetPerM2 = 25.0;
    int paletAdedi = 420;
    double defBirimFiyat = 7.5;
    bool isGazbeton = false;

    if (v.contains('8.5')) {
      adetPerM2 = 28.0;
      paletAdedi = 550;
      defBirimFiyat = 6.2;
    } else if (v.contains('19')) {
      adetPerM2 = 22.0;
      paletAdedi = 320;
      defBirimFiyat = 11.5;
    } else if (v.contains('Bims')) {
      adetPerM2 = 12.5;
      paletAdedi = 80;
      defBirimFiyat = 16.0;
    } else if (v.contains('Gazbeton') || v.contains('Ytong')) {
      adetPerM2 = 6.67;
      paletAdedi = 48;
      defBirimFiyat = 42.0;
      isGazbeton = true;
    }

    final bf = birimFiyat ?? defBirimFiyat;
    final double netAdet = a * adetPerM2;
    final double fireAdet = netAdet * 0.05;
    final int toplamAdet = (netAdet + fireAdet).ceil();
    final int paletSayisi = (toplamAdet / paletAdedi).ceil();

    double harcMaliyeti = 0.0;
    final sarfList = <String>[];
    if (isGazbeton) {
      final double tutkalKg = a * 2.5;
      final int torbaTutkal = (tutkalKg / 25.0).ceil();
      harcMaliyeti = torbaTutkal * 190.0;
      sarfList.add('Gazbeton Örgü Tutkalı: ~$torbaTutkal Torba (25 kg) — Toplam ${_f(tutkalKg)} kg');
      sarfList.add('Taraklı mala ile 2-3 mm derz kalınlığında örülmelidir.');
    } else {
      final double harcHacmiM3 = a * 0.035;
      final double cimentoKg = a * 7.5;
      final int cimentoTorba50 = (cimentoKg / 50.0).ceil();
      final double kumM3 = harcHacmiM3 * 0.9;
      final double cimentoTutari = cimentoTorba50 * 200.0;
      final double kumTutari = kumM3 * 650.0;
      harcMaliyeti = cimentoTutari + kumTutari;
      sarfList.add('Harç Hacmi: ~${_f(harcHacmiM3)} m³');
      sarfList.add('Portland Çimento: ~$cimentoTorba50 Torba (50 kg) — Toplam ${_f(cimentoKg)} kg');
      sarfList.add('Duvar Kumu: ~${_f(kumM3)} m³ (0-3 mm dişli kum)');
    }

    final double tuglaMaliyeti = toplamAdet * bf;
    final double toplamMaliyet = tuglaMaliyeti + harcMaliyeti;

    final buffer = StringBuffer();
    buffer.writeln('🧱 **ŞPD AI - Duvar Örme & Malzeme Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📋 **Malzeme Cinsi:** $v');
    buffer.writeln('📐 **Toplam Duvar Alanı:** ${_f(a)} m²');
    buffer.writeln('📊 **Birim Sarfiyat:** ${_f(adetPerM2)} adet / m²');
    buffer.writeln('⚠️ **Önerilen Fire Payı:** +%5 (kırılma ve köşe kesimleri)');
    buffer.writeln('📦 **Sipariş Edilecek Toplam:** **$toplamAdet Adet** (~**$paletSayisi Palet**)');
    buffer.writeln('');
    buffer.writeln('🥣 **Harç & Bağlayıcı İhtiyacı:**');
    for (final s in sarfList) {
      buffer.writeln('• $s');
    }
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Duvar Blok Malzemesi ($toplamAdet adet):** ${_para(tuglaMaliyeti)}');
    buffer.writeln('• **Harç & Bağlayıcı Gideri:** ${_para(harcMaliyeti)}');
    buffer.writeln('• **Toplam Tahmini Duvar Malzemesi:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Tuğlalar örülmeden önce ıslatılmalıdır (harcın suyunu hızla emip yakmaması için).');
    buffer.writeln('2. Günde 1.5 metreden fazla yükseklik örülmemelidir; priz alması beklenmelidir.');
    buffer.writeln('3. Kolon-duvar birleşimlerine en az her 3 sırada bir L ankraj demiri çakılmalıdır.');

    return MetrajHesapModel(
      category: 'tugla',
      title: 'Tuğla & Blok Duvar Hesabı',
      icon: '🧱',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Duvar Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        "13.5'luk Tuğla (Standart)",
        "8.5'luk İnce Tuğla",
        "19'luk Dış Duvar Tuğlası",
        "15-20'lik Bims Blok",
        "Gazbeton / Ytong",
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'Adet Fiyatı (TL)',
      anaMiktar: '$toplamAdet Adet',
      anaMiktarLabel: 'Sipariş Edilecek Toplam',
      lojistik: '~$paletSayisi Palet',
      lojistikLabel: 'Lojistik & Palet',
      firePayi: '%5 (+${_f(fireAdet)} Adet)',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: sarfList,
      tavsiyeler: const [
        'Tuğlalar örülmeden önce ıslatılmalıdır (harcın suyunu emmemesi için).',
        'Günde 1.5 metreden (7-8 sıra) fazla örülmemeli, priz alması beklenmelidir.',
        'Kolon-duvar birleşimlerine her 3 sırada bir L ankraj demiri çakılmalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3. SERAMİK / FAYANS / GRANİT HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSeramikHesabi(String norm) {
    final keywords = ['seramik', 'fayans', 'granit', 'kalebodur', 'porselen', 'yer dosemesi', 'derz', 'kalekim'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildSeramik(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    String variant = '60x60 Porselen Seramik';
    if (norm.contains('granit')) variant = '60x120 Granit Seramik';
    else if (norm.contains('fayans') || norm.contains('duvar')) variant = 'Standart Duvar/Yer Seramiği';

    return buildSeramikModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildSeramikModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 80.0;
    final v = variant ?? '60x60 Porselen Seramik';
    final bf = birimFiyat ?? (v.contains('Granit') ? 580.0 : 450.0);

    const double fireOrani = 0.10;
    final double toplamM2 = a * (1 + fireOrani);
    const double kutuM2 = 1.44;
    final int paketSayisi = (toplamM2 / kutuM2).ceil();

    final double yapistiriciKg = a * 4.8;
    final int yapistiriciTorba = (yapistiriciKg / 25.0).ceil();
    final double derzKg = a * 0.5;
    final int derzTorba = (derzKg / 5.0).ceil();

    final double seramikTutari = toplamM2 * bf;
    final double yapistiriciTutari = yapistiriciTorba * 220.0;
    final double derzTutari = derzTorba * 140.0;
    final double klipsSarf = (a * 12) * 0.45;
    final double toplamMaliyet = seramikTutari + yapistiriciTutari + derzTutari + klipsSarf;

    final buffer = StringBuffer();
    buffer.writeln('✨ **ŞPD AI - Seramik, Granit & Yapıştırıcı Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Kaplama Alanı:** ${_f(a)} m²');
    buffer.writeln('⚠️ **Önerilen Fire Payı (%10):** +${_f(a * fireOrani)} m² (Köşe, süpürgelik & kesim)');
    buffer.writeln('📦 **Sipariş Edilecek Seramik:** **${_f(toplamM2)} m²** (~**$paketSayisi Kutu/Paket** [1.44 m²/kutu])');
    buffer.writeln('');
    buffer.writeln('🥣 **Kimyasal & Sarf Malzeme İhtiyacı:**');
    buffer.writeln('• **Seramik Yapıştırıcısı (C2TE):** **$yapistiriciTorba Torba** (25 kg\'lık) — Toplam ${_f(yapistiriciKg)} kg');
    buffer.writeln('• **Derz Dolgusu (Fuga):** **$derzTorba Kutu/Torba** (5 kg\'lık) — Toplam ${_f(derzKg)} kg');
    buffer.writeln('• **Derz Artısı / Terazi Klipsi:** Yaklaşık ${(a * 12).toInt()} adet klips ve takoz');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Porselen Seramik (${_f(toplamM2)} m² x ${_para(bf)}):** ${_para(seramikTutari)}');
    buffer.writeln('• **Yapıştırıcı ($yapistiriciTorba torba) & Fuga ($derzTorba adet):** ${_para(yapistiriciTutari + derzTutari)}');
    buffer.writeln('• **Klips & Yardımcı Sarf:** ${_para(klipsSarf)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Zemin eğimi kontrol edilmeli; 5 mm üzeri sapmalarda önce tesviye şapı çekilmelidir.');
    buffer.writeln('2. 60x60 ve üzeri seramiklerde hem zemine hem arkasına çift taraflı yapıştırma yapılmalıdır.');
    buffer.writeln('3. Derz dolgusu yapıştırmadan en az 24-48 saat sonra uygulanmalıdır.');

    return MetrajHesapModel(
      category: 'seramik',
      title: 'Seramik, Granit & Derz Hesabı',
      icon: '✨',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Kaplama Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        '60x60 Porselen Seramik',
        '60x120 Granit Seramik',
        'Standart Duvar/Yer Seramiği',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'm² Seramik Fiyatı (TL)',
      anaMiktar: '${_f(toplamM2)} m²',
      anaMiktarLabel: 'Sipariş Edilecek Seramik',
      lojistik: '~$paketSayisi Kutu',
      lojistikLabel: 'Paket / Kutu (1.44 m²)',
      firePayi: '%10 (+${_f(a * fireOrani)} m²)',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Seramik Yapıştırıcısı (C2TE): $yapistiriciTorba Torba (25 kg)',
        'Derz Dolgusu (Fuga): $derzTorba Kutu (5 kg)',
        'Terazi Klipsi & Takoz: ~${(a * 12).toInt()} Adet',
      ],
      tavsiyeler: const [
        'Zemin eğimi kontrol edilmeli; 5 mm üzeri sapmalarda tesviye şapı çekilmelidir.',
        '60x60 ve üzeri porselen seramiklerde çift taraflı yapıştırma uygulanmalıdır.',
        'Derz dolgusu yapıştırmadan 24-48 saat sonra uygulanmalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4. ŞAP (TESVİYE BETONU) HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSapHesabi(String norm) {
    final keywords = ['şap', 'sap', 'tesviye betonu', 'yer şapı', 'yer sapi'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildSap(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    double? kalinlikCm = _extractKalinlikCm(original, norm) ?? 5.0;
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    return buildSapModel(alan: alan, kalinlikCm: kalinlikCm);
  }

  static MetrajHesapModel buildSapModel({
    double? alan,
    double? kalinlikCm,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 100.0;
    final k = kalinlikCm ?? 5.0;
    final v = variant ?? '350 Doz Standart Şap';
    final bf = birimFiyat ?? 650.0; // Kum m³

    final double hacimM3 = a * (k / 100.0);
    const double cimentoDoz = 350.0;
    final double toplamCimentoKg = hacimM3 * cimentoDoz;
    final int cimentoTorba50 = (toplamCimentoKg / 50.0).ceil();
    final double kumM3 = hacimM3 * 1.15;
    final double elyafKg = hacimM3 * 0.9;

    final double cimentoTutari = cimentoTorba50 * 200.0;
    final double kumTutari = kumM3 * bf;
    final double elyafTutari = elyafKg * 160.0;
    final double toplamMaliyet = cimentoTutari + kumTutari + elyafTutari;

    final buffer = StringBuffer();
    buffer.writeln('📐 **ŞPD AI - Zemin Şapı & Tesviye Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Uygulama Alanı:** ${_f(a)} m²');
    buffer.writeln('📏 **Ortalama Şap Kalınlığı:** ${_f(k)} cm');
    buffer.writeln('🧊 **Toplam Şap Hacmi:** **${_f(hacimM3)} m³**');
    buffer.writeln('');
    buffer.writeln('📦 **Gereken Malzeme Listesi (350 Doz Standardı):**');
    buffer.writeln('• **Çimento (Portland):** **$cimentoTorba50 Torba** (50 kg\'lık) — Toplam ${_f(toplamCimentoKg)} kg');
    buffer.writeln('• **Şap Kumu (0-3 Mil Kumu):** **${_f(kumM3)} m³** (~${_f(kumM3 * 1.6)} Ton)');
    buffer.writeln('• **Polipropilen Şap Elyafı:** ~${_f(elyafKg)} kg (Rötre çatlaklarını engellemek için)');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti:**');
    buffer.writeln('• **Çimento ($cimentoTorba50 torba):** ${_para(cimentoTutari)}');
    buffer.writeln('• **Mil Kumu (${_f(kumM3)} m³):** ${_para(kumTutari)}');
    buffer.writeln('• **Şap Elyafı & Katkı:** ${_para(elyafTutari)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'sap',
      title: 'Zemin Şapı & Tesviye Hesabı',
      icon: '📐',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Uygulama Alanı',
      primaryUnit: 'm²',
      secondaryValue: k,
      secondaryLabel: 'Şap Kalınlığı',
      secondaryUnit: 'cm',
      selectedVariant: v,
      availableVariants: const [
        '350 Doz Standart Şap',
        '400 Doz Mukavemetli Şap',
        'Hazır Kuru Harç Şapı',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'Kum m³ Fiyatı (TL)',
      anaMiktar: '${_f(hacimM3)} m³',
      anaMiktarLabel: 'Toplam Şap Hacmi',
      lojistik: '$cimentoTorba50 Torba Çimento',
      lojistikLabel: 'Bağlayıcı Çimento (50 kg)',
      firePayi: '%5 tesviye toleransı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Portland Çimentosu: $cimentoTorba50 Torba (50 kg) — ${_f(toplamCimentoKg)} kg',
        '0-3 Mil Kumu: ${_f(kumM3)} m³ (~${_f(kumM3 * 1.6)} Ton)',
        'Polipropilen Şap Elyafı: ~${_f(elyafKg)} kg',
      ],
      tavsiyeler: const [
        'Zemin temizlenip aderans köprüsü (şerbet/astar) uygulanmalıdır.',
        'Geniş mekanlarda 25-30 m²\'de bir derz kesilerek oturma çatlakları engellenmelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 5. SIVA & ALÇI HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSivaHesabi(String norm) {
    final keywords = ['sıva', 'siva', 'alçı', 'alci', 'kara sıva', 'alçı sıva', 'saten'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildSiva(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    final bool isKara = norm.contains('kara') || norm.contains('kaba') || norm.contains('cimento');
    final variant = isKara ? 'Çimento Esaslı Kara Sıva' : 'Perlitli Sıva Alçısı + Saten';

    return buildSivaModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildSivaModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 150.0;
    final v = variant ?? 'Perlitli Sıva Alçısı + Saten';
    final isKara = v.contains('Kara');

    double toplamMaliyet = 0.0;
    final sarfList = <String>[];
    String anaMiktar = '';
    String lojistik = '';

    if (isKara) {
      final double kumM3 = a * 0.024;
      final double cimentoKg = a * 7.5;
      final int cimentoTorba50 = (cimentoKg / 50.0).ceil();
      final double cimentoTutari = cimentoTorba50 * 200.0;
      final double kumTutari = kumM3 * (birimFiyat ?? 650.0);
      toplamMaliyet = cimentoTutari + kumTutari;

      anaMiktar = '${_f(kumM3)} m³ Kum';
      lojistik = '$cimentoTorba50 Torba Çimento';
      sarfList.add('Sıva Kumu: ~${_f(kumM3)} m³');
      sarfList.add('Portland Çimento: ~$cimentoTorba50 Torba (50 kg)');
      sarfList.add('Torbalı Kireç: ~${(a * 2.5 / 25).ceil()} Torba');
    } else {
      final double alciKg = a * 9.0;
      final int alciTorba35 = (alciKg / 35.0).ceil();
      final double satenKg = a * 1.0;
      final int satenTorba25 = (satenKg / 25.0).ceil();
      final double alciTutari = alciTorba35 * (birimFiyat ?? 165.0);
      final double satenTutari = satenTorba25 * 145.0;
      final double kosebentAstar = a * 15.0;
      toplamMaliyet = alciTutari + satenTutari + kosebentAstar;

      anaMiktar = '$alciTorba35 Torba Alçı';
      lojistik = '$alciTorba35 Torba + $satenTorba25 Saten';
      sarfList.add('Perlitli Sıva Alçısı: $alciTorba35 Torba (35 kg) — Toplam ${_f(alciKg)} kg');
      sarfList.add('Saten Perdah Alçısı: $satenTorba25 Torba (25 kg) — Toplam ${_f(satenKg)} kg');
      sarfList.add('Brüt Beton Astarı: ~${_f(a * 0.25)} kg');
    }

    final buffer = StringBuffer();
    buffer.writeln('🖌️ **ŞPD AI - Sıva & Alçı Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Uygulama Alanı:** ${_f(a)} m²');
    buffer.writeln('📋 **Tür:** $v');
    buffer.writeln('📦 **Malzeme İhtiyacı:**');
    for (final s in sarfList) {
      buffer.writeln('• $s');
    }
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'siva',
      title: 'Sıva & Alçı Metraj Hesabı',
      icon: '🖌️',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Sıva Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        'Perlitli Sıva Alçısı + Saten',
        'Çimento Esaslı Kara Sıva',
        'Hazır Dış Cephe Sıvası',
      ],
      birimFiyat: birimFiyat ?? (isKara ? 650.0 : 165.0),
      birimFiyatLabel: isKara ? 'Kum m³ Fiyatı (TL)' : 'Alçı Torba Fiyatı (TL)',
      anaMiktar: anaMiktar,
      anaMiktarLabel: 'Ana Malzeme İhtiyacı',
      lojistik: lojistik,
      lojistikLabel: 'Paket / Ambalaj',
      firePayi: '%5 dökülme payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: sarfList,
      tavsiyeler: const [
        'Brüt beton yüzeylerde aderans için brüt beton astarı (kumlu astar) uygulanmalıdır.',
        'Alçı karışımı temiz su ve teknede yapılmalı, priz alan harca su ilave edilmemelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 6. BOYA & ASTAR HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isBoyaHesabi(String norm) {
    final keywords = ['boya', 'astar', 'iç cephe', 'ic cephe', 'dış cephe', 'dis cephe', 'tavan boya'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildBoya(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    String variant = 'Silikonlu İç Cephe (Çift Kat)';
    if (norm.contains('dis') || norm.contains('dış')) {
      variant = 'Akrilik Dış Cephe (Çift Kat)';
    }

    return buildBoyaModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildBoyaModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 200.0;
    final v = variant ?? 'Silikonlu İç Cephe (Çift Kat)';
    final bf = birimFiyat ?? 2250.0;

    final double boyaLitre = a / 7.5;
    final int kova15Litre = (boyaLitre / 15.0).ceil();
    final double astarLitre = a / 11.0;
    final int astarKova15Litre = (astarLitre / 15.0).ceil();
    final double tavanBoyaKg = (a * 0.35);
    final int tavanKova17_5Kg = (tavanBoyaKg / 17.5).ceil();

    final double boyaTutari = kova15Litre * bf;
    final double astarTutari = astarKova15Litre * 1350.0;
    final double tavanTutari = tavanKova17_5Kg * 750.0;
    const double sarfMalzeme = 450.0;
    final double toplamMaliyet = boyaTutari + astarTutari + tavanTutari + sarfMalzeme;

    final buffer = StringBuffer();
    buffer.writeln('🎨 **ŞPD AI - Boya & Astar Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Boya Alanı:** ${_f(a)} m²');
    buffer.writeln('🎨 **Uygulama:** $v');
    buffer.writeln('');
    buffer.writeln('📦 **Gereken Ambalaj Sayıları:**');
    buffer.writeln('• **Duvar Boyası (Çift Kat):** **$kova15Litre Kova** (15 Litrelik) — Toplam ${_f(boyaLitre)} Litre');
    buffer.writeln('• **Şeffaf / Dönüşüm Astarı:** **$astarKova15Litre Kova** (15 Litrelik) — Toplam ${_f(astarLitre)} Litre');
    buffer.writeln('• **Tavan Boyası:** ~**$tavanKova17_5Kg Kova** (17.5 kg plastik tavan boyası)');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Duvar Boyası ($kova15Litre kova):** ${_para(boyaTutari)}');
    buffer.writeln('• **Astar ($astarKova15Litre kova) & Tavan ($tavanKova17_5Kg kova):** ${_para(astarTutari + tavanTutari)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'boya',
      title: 'Boya, Astar & Tavan Hesabı',
      icon: '🎨',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Boya Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        'Silikonlu İç Cephe (Çift Kat)',
        'Akrilik Dış Cephe (Çift Kat)',
        'Plastik Mat İç Cephe Boyası',
      ],
      birimFiyat: bf,
      birimFiyatLabel: '15L Boya Kova Fiyatı (TL)',
      anaMiktar: '$kova15Litre Kova Boya',
      anaMiktarLabel: 'Ana Duvar Boyası (15L)',
      lojistik: '$kova15Litre Kova + $astarKova15Litre Astar',
      lojistikLabel: 'Ambalaj / Kova',
      firePayi: '%5 yüzey emme payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Duvar Boyası: $kova15Litre Kova (15L) — ${_f(boyaLitre)} Litre',
        'Dönüşüm Astarı: $astarKova15Litre Kova (15L)',
        'Tavan Boyası: ~$tavanKova17_5Kg Kova (17.5 kg)',
        'Maskeleme bandı & zemin hışır örtü',
      ],
      tavsiyeler: const [
        'Alçı yüzeylerin zımparası bittikten sonra toz tamamen temizlenmeden astar atılmamalıdır.',
        'Katlar arasında en az 4-6 saat kuruma süresi beklenmelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 7. DEMİR (DONATI) HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isDemirHesabi(String norm) {
    final keywords = ['demir', 'donatı', 'donati', 'inşaat demiri', 'insaat demiri', 'ton demir'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildDemir(String original, String norm) {
    double? hacimM3 = _extractHacimM3(original, norm);
    double? alan = _extractAlan(original, norm);
    final pVal = hacimM3 ?? alan;
    if (pVal == null || pVal <= 0) return null;

    return buildDemirModel(alan: pVal, isHacim: hacimM3 != null);
  }

  static MetrajHesapModel buildDemirModel({
    double? alan,
    String? variant,
    double? birimFiyat,
    bool isHacim = true,
  }) {
    final a = alan ?? 100.0;
    final v = variant ?? 'Nervürlü Donatı (90 kg/m³)';
    final bf = birimFiyat ?? 31000.0;

    double kgPerUnit = 90.0;
    if (v.contains('75')) kgPerUnit = 75.0;
    else if (v.contains('115')) kgPerUnit = 115.0;

    final double toplamKg = a * kgPerUnit;
    final double toplamTon = toplamKg / 1000.0;
    final double bagTeliKg = toplamTon * 15.0;
    final double demirMaliyeti = toplamTon * bf;
    final double bagTeliMaliyeti = bagTeliKg * 55.0;
    final double toplamMaliyet = demirMaliyeti + bagTeliMaliyeti;

    final buffer = StringBuffer();
    buffer.writeln('🔩 **ŞPD AI - İnşaat Demiri (Donatı) Yaklaşık Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📊 **Tahmini Donatı Miktarı:** **${_f(toplamTon)} Ton** (~${_f(toplamKg)} kg)');
    buffer.writeln('🧵 **Tavlı Bağ Teli:** ~**${_f(bagTeliKg)} kg** (Ton başına 15 kg)');
    buffer.writeln('💰 **Toplam Demir Maliyeti:** **${_para(toplamMaliyet)}** (+Nakliye & KDV)');

    return MetrajHesapModel(
      category: 'demir',
      title: 'İnşaat Demiri (Donatı) Hesabı',
      icon: '🔩',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: isHacim ? 'Beton Hacmi' : 'İnşaat Alanı',
      primaryUnit: isHacim ? 'm³' : 'm²',
      selectedVariant: v,
      availableVariants: const [
        'Nervürlü Donatı (90 kg/m³)',
        'Hafif Yapı Donatısı (75 kg/m³)',
        'Ağır Sanayi / Radye (115 kg/m³)',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'Ton Demir Fiyatı (TL)',
      anaMiktar: '${_f(toplamTon)} Ton',
      anaMiktarLabel: 'Tahmini Donatı Miktarı',
      lojistik: '~${_f(toplamKg)} kg',
      lojistikLabel: 'Toplam Net Kilo',
      firePayi: '%3 bindirme payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Demir Maliyeti',
      sarfMalzemeler: [
        'Nervürlü Donatı: ${_f(toplamTon)} Ton',
        'Tavlı Bağ Teli: ~${_f(bagTeliKg)} kg',
        'Paspayı takozları (temel 5cm, kolon/kiriş 3cm)',
      ],
      tavsiyeler: const [
        'Paspayı takozları ihmal edilmemeli (temelde 5 cm, kolon/kirişte 3 cm).',
        'Kesin tonaj statik aplikasyon projesindeki donatı metraj cetvelinden teyit edilmelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 8. ALÇIPAN HESAPLAYICI (Asma Tavan & Bölme Duvar)
  // ═══════════════════════════════════════════════════════════
  static bool _isAlcipanHesabi(String norm) {
    final keywords = ['alçıpan', 'alcipan', 'asma tavan', 'bölme duvar', 'bolme duvar'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildAlcipan(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    return buildAlcipanModel(alan: alan);
  }

  static MetrajHesapModel buildAlcipanModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 60.0;
    final v = variant ?? '12.5mm Asma Tavan Alçıpanı';
    final bf = birimFiyat ?? 210.0;

    final int plakaSayisi = ((a * 1.07) / 3.0).ceil();
    final double tcProfilMetre = a * 1.8;
    final int tcBoy3m = (tcProfilMetre / 3.0).ceil();
    final int vidaAdet = (a * 25).toInt();
    final double derzBandiMetre = a * 1.5;
    final int derzAlciTorba = (a * 0.4 / 25.0).ceil();

    final double plakaTutari = plakaSayisi * bf;
    final double profilTutari = tcBoy3m * 95.0;
    final double sarfTutari = vidaAdet * 0.35 + derzAlciTorba * 180.0 + 200.0;
    final double toplamMaliyet = plakaTutari + profilTutari + sarfTutari;

    final buffer = StringBuffer();
    buffer.writeln('🏗️ **ŞPD AI - Alçıpan Asma Tavan & Bölme Duvar Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Alan:** ${_f(a)} m²');
    buffer.writeln('📦 **Gereken Plaka:** **$plakaSayisi Adet Plaka** (12.5mm [1.2x2.5m])');
    buffer.writeln('🔩 **Tavan C (TC) Profili:** ~**$tcBoy3m Boy** (3 metrelik)');
    buffer.writeln('💰 **Toplam Karkas & Plaka Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'alcipan',
      title: 'Alçıpan & Karkas Hesabı',
      icon: '🔨',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Net Alan',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        '12.5mm Asma Tavan Alçıpanı',
        'Suya Dayanıklı Yeşil Alçıpan',
        'Yangına Dayanıklı Kırmızı Alçıpan',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'Plaka Fiyatı (TL)',
      anaMiktar: '$plakaSayisi Adet Plaka',
      anaMiktarLabel: 'Gereken Alçıpan Plaka',
      lojistik: '$tcBoy3m Boy Profil',
      lojistikLabel: 'Galvaniz TC Profil (3m)',
      firePayi: '%7 kesim payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Alçıpan Plaka: $plakaSayisi Adet (1.20x2.50m)',
        'Tavan C Profili: ~$tcBoy3m Boy (3m) — ${_f(tcProfilMetre)} mt',
        'Borazan Vida (25mm): ~$vidaAdet Adet',
        'Derz Bandı: ~${_f(derzBandiMetre)} Metre',
        'Derz Dolgu Alçısı (Fugagips): ~$derzAlciTorba Torba',
      ],
      tavsiyeler: const [
        'Vidalama 20-25 cm aralıkla yapılmalı, vida başları plaka yüzeyine hafifçe gömülmelidir.',
        'Derz bandı çekilmeden derz dolgu alçısı uygulanmamalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 9. DIŞ CEPHE MANTOLAMA / ISI YALITIMI HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isMantolamaHesabi(String norm) {
    final keywords = ['mantolama', 'isi yalitim', 'ısı yalıtım', 'tasyunu', 'taşyünü', 'eps', 'karbonlu eps'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildMantolama(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    String variant = '5 cm Karbonlu EPS Levha';
    if (norm.contains('tasyunu') || norm.contains('taşyünü')) {
      variant = '5 cm Taşyünü (150 kg/m³)';
    } else if (norm.contains('4 cm') || norm.contains('4cm')) {
      variant = '4 cm Karbonlu EPS Levha';
    }

    return buildMantolamaModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildMantolamaModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 250.0;
    final v = variant ?? '5 cm Karbonlu EPS Levha';
    final bf = birimFiyat ?? (v.contains('Taşyünü') ? 310.0 : 180.0);

    final double toplamLevhaM2 = a * 1.05;
    final int paketSayisi = (toplamLevhaM2 / 5.0).ceil();
    final int yapistiriciTorba = ((a * 4.5) / 25.0).ceil();
    final int sivaTorba = ((a * 4.5) / 25.0).ceil();
    final double fileM2 = a * 1.10;
    final int fileRulo = (fileM2 / 50.0).ceil();
    final int dubelAdet = (a * 6).toInt();
    final int mineralSivaTorba = ((a * 2.8) / 25.0).ceil();

    final double levhaTutari = toplamLevhaM2 * bf;
    final double yapistiriciSivaTutari = (yapistiriciTorba + sivaTorba) * 190.0;
    final double fileDubelTutari = (fileRulo * 950.0) + (dubelAdet * 1.2);
    final double mineralSivaTutari = mineralSivaTorba * 220.0;
    final double toplamMaliyet = levhaTutari + yapistiriciSivaTutari + fileDubelTutari + mineralSivaTutari;

    final buffer = StringBuffer();
    buffer.writeln('🏠 **ŞPD AI - Dış Cephe Isı Yalıtımı (Mantolama) Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Cephe Alanı:** ${_f(a)} m²');
    buffer.writeln('📦 **Yalıtım Levhası:** **${_f(toplamLevhaM2)} m²** (~**$paketSayisi Paket**)');
    buffer.writeln('🧱 **Yapıştırıcı & Sıva:** ${yapistiriciTorba + sivaTorba} Torba (25 kg)');
    buffer.writeln('💰 **Toplam Paket Malzeme:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'mantolama',
      title: 'Dış Cephe Mantolama Hesabı',
      icon: '🏠',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Cephe Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        '5 cm Karbonlu EPS Levha',
        '4 cm Karbonlu EPS Levha',
        '5 cm Taşyünü (150 kg/m³)',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'm² Levha Fiyatı (TL)',
      anaMiktar: '${_f(toplamLevhaM2)} m²',
      anaMiktarLabel: 'Yalıtım Levhası (m²)',
      lojistik: '~$paketSayisi Paket',
      lojistikLabel: 'Levha Paketi (~5 m²)',
      firePayi: '%5 kesim payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Mantolama Yapıştırıcısı: $yapistiriciTorba Torba (25 kg)',
        'Mantolama Sıvası: $sivaTorba Torba (25 kg)',
        'Donatı Filesi (160 gr): $fileRulo Rulo (50 m²)',
        'Plastik/Çelik Çivili Dübel: $dubelAdet Adet',
        'Dekoratif Mineral Sıva: $mineralSivaTorba Torba (25 kg)',
      ],
      tavsiyeler: const [
        'Levhalar şaşırtmalı örülmeli, pencere köşelerinde L kesim yapılmalıdır.',
        'Donatı filesi ek yerlerinde en az 10 cm bindirilmelidir.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 10. SU YALITIMI & MEMBRAN HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isYalitimHesabi(String norm) {
    final keywords = ['membran', 'su yalitim', 'su yalitimi', 'izolasyon', 'likit membran', 'bitum'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildYalitim(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    return buildYalitimModel(alan: alan);
  }

  static MetrajHesapModel buildYalitimModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 120.0;
    final v = variant ?? '3mm/4mm Bitümlü Membran';
    final bf = birimFiyat ?? 1450.0;

    final double toplamMembranM2 = a * 1.12;
    final int ruloSayisi = (toplamMembranM2 / 10.0).ceil();
    final double astarKg = a * 0.35;
    final int astarTeneke = (astarKg / 16.0).ceil();
    final int tupSayisi = (a / 100.0).ceil();

    final double membranTutari = ruloSayisi * bf;
    final double astarTutari = astarTeneke * 980.0;
    final double gazTutari = tupSayisi * 900.0;
    final double toplamMaliyet = membranTutari + astarTutari + gazTutari;

    final buffer = StringBuffer();
    buffer.writeln('💧 **ŞPD AI - Su Yalıtımı & Bitümlü Membran Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Yalıtım Alanı:** ${_f(a)} m²');
    buffer.writeln('📦 **Membran İhtiyacı:** **$ruloSayisi Rulo** (10 m²\'lik rulolar)');
    buffer.writeln('💰 **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'yalitim',
      title: 'Su Yalıtımı & Membran Hesabı',
      icon: '💧',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Yalıtım Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        '3mm/4mm Bitümlü Membran',
        'Kumlu Arduvazlı Membran (Üst Kat)',
        'Çift Kat Membran (2 Kat)',
      ],
      birimFiyat: bf,
      birimFiyatLabel: '10 m² Rulo Fiyatı (TL)',
      anaMiktar: '$ruloSayisi Rulo Membran',
      anaMiktarLabel: 'Gereken Membran Rulosu',
      lojistik: '${_f(toplamMembranM2)} m²',
      lojistikLabel: 'Toplam Kaplama (10 m²/rulo)',
      firePayi: '%12 bini ve parapet payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Bitümlü Membran: $ruloSayisi Rulo (10 m²)',
        'Bitümlü Astar: $astarTeneke Teneke (16 kg)',
        'Sanayi Tüpü: ~$tupSayisi Adet',
      ],
      tavsiyeler: const [
        'Parapet dönüşlerinde pah bantları ihmal edilmemeli, en az 25 cm döndürülmelidir.',
        'Ek yerlerinde 10-15 cm bini payı şaloma ile eritilerek yapıştırılmalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 11. HAFRİYAT & KAZI & KAMYON SEFERİ HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isHafriyatHesabi(String norm) {
    final keywords = ['hafriyat', 'kazi', 'kazı', 'kamyon seferi', 'kamyon'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildHafriyat(String original, String norm) {
    double? direktM3 = _extractHacimM3(original, norm);
    double? alan = _extractAlan(original, norm);
    double? derinlikM;

    final dim = _extractDimensions(original);
    if (dim.length >= 3) {
      direktM3 = dim[0] * dim[1] * dim[2];
    } else if (dim.length == 2 && alan == null) {
      alan = dim[0] * dim[1];
    }

    final depthMatch = RegExp(
      r'(\d+[\.,]?\d*)\s*(?:m|mt|metre)?\s*(?:derinlik|derinliginde|derinliğinde|temel\s+kazisi|temel\s+kazısı|kazi|kazı)',
      caseSensitive: false,
    ).firstMatch(original);
    if (depthMatch != null) {
      derinlikM = double.tryParse(depthMatch.group(1)!.replaceAll(',', '.'));
    }

    if (direktM3 != null && direktM3 > 0 && alan == null) {
      alan = direktM3 / (derinlikM ?? 2.5);
    }

    if (alan == null || alan <= 0) return null;

    return buildHafriyatModel(
      alan: alan,
      derinlikM: derinlikM ?? 2.5,
    );
  }

  static MetrajHesapModel buildHafriyatModel({
    double? alan,
    double? derinlikM,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 300.0;
    final d = derinlikM ?? 2.5;
    final v = variant ?? 'Killi/Toprak Zemin (%25 Kabarma)';
    final bf = birimFiyat ?? 2800.0;

    final double netKaziM3 = a * d;
    double kabarmaOrani = 0.25;
    if (v.contains('30')) kabarmaOrani = 0.30;
    else if (v.contains('35')) kabarmaOrani = 0.35;

    final double kabarikHacim = netKaziM3 * (1 + kabarmaOrani);
    const double kamyonKapasiteM3 = 15.0;
    final int kamyonSeferSayisi = (kabarikHacim / kamyonKapasiteM3).ceil();
    final double toplamHafriyatMaliyeti = kamyonSeferSayisi * bf;

    final buffer = StringBuffer();
    buffer.writeln('🚜 **ŞPD AI - Temel Kazısı & Hafriyat Lojistik Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('🧊 **Sıkışık (Net) Kazı Hacmi:** ${_f(netKaziM3)} m³');
    buffer.writeln('📈 **Zemin Kabarma Payı (%${(kabarmaOrani * 100).toInt()}):** +${_f(kabarikHacim - netKaziM3)} m³');
    buffer.writeln('🚚 **Toplam Taşınacak Hacim:** **${_f(kabarikHacim)} m³**');
    buffer.writeln('🚛 **Gereken Kamyon Seferi:** ~**$kamyonSeferSayisi Sefer** (15 m³ kamyon)');
    buffer.writeln('💰 **Toplam Tahmini Hafriyat Gideri:** **${_para(toplamHafriyatMaliyeti)}**');

    return MetrajHesapModel(
      category: 'hafriyat',
      title: 'Temel Kazısı & Hafriyat Hesabı',
      icon: '🚜',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Kazı Taban Alanı',
      primaryUnit: 'm²',
      secondaryValue: d,
      secondaryLabel: 'Kazı Derinliği',
      secondaryUnit: 'm',
      selectedVariant: v,
      availableVariants: const [
        'Killi/Toprak Zemin (%25 Kabarma)',
        'Sert Küskülük Zemin (%30 Kabarma)',
        'Kaya Zemin / Kırıcı (%35 Kabarma)',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'Kamyon Sefer Ücreti (TL)',
      anaMiktar: '~${_f(kabarikHacim)} m³',
      anaMiktarLabel: 'Taşınacak Kabarık Hacim',
      lojistik: '~$kamyonSeferSayisi Sefer',
      lojistikLabel: 'Damperli Kamyon (15 m³)',
      firePayi: '%${(kabarmaOrani * 100).toInt()} kabarma',
      toplamMaliyet: toplamHafriyatMaliyeti,
      toplamMaliyetLabel: 'Toplam Hafriyat Maliyeti',
      sarfMalzemeler: [
        'Net Sıkışık Kazı: ${_f(netKaziM3)} m³',
        'Kabarık Kazı Hacmi: ${_f(kabarikHacim)} m³',
        'Damperli Kamyon: ~$kamyonSeferSayisi Sefer (15 m³)',
      ],
      tavsiyeler: const [
        'Kazı kotu lazer nivo ile kontrol edilmeli, temel altı lüzumsuz derin kazılmamalıdır.',
        'Derin kazılarda komşu bina ve yol güvenliği için iksa emniyeti alınmalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 12. PARKE / LAMİNAT HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isParkeHesabi(String norm) {
    final keywords = ['parke', 'laminat', 'silte', 'şilte', 'kapron', 'supurgelik', 'süpürgelik'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static MetrajHesapModel? _extractAndBuildParke(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }
    if (alan == null || alan <= 0) return null;

    String variant = '8 mm 32. Sınıf Derzli Laminat';
    if (norm.contains('33')) variant = '10 mm 33. Sınıf Yoğun Trafik';
    else if (norm.contains('31')) variant = '8 mm 31. Sınıf Düz Laminat';

    return buildParkeModel(alan: alan, variant: variant);
  }

  static MetrajHesapModel buildParkeModel({
    double? alan,
    String? variant,
    double? birimFiyat,
  }) {
    final a = alan ?? 85.0;
    final v = variant ?? '8 mm 32. Sınıf Derzli Laminat';
    final bf = birimFiyat ?? (v.contains('33') ? 420.0 : 320.0);

    final double toplamParkeM2 = a * 1.07;
    const double paketM2 = 2.13;
    final int paketSayisi = (toplamParkeM2 / paketM2).ceil();
    final double silteM2 = a * 1.05;
    final double supurgelikMetre = a * 0.85;
    final int supurgelikBoy = (supurgelikMetre / 2.8).ceil();

    final double parkeTutari = toplamParkeM2 * bf;
    final double silteTutari = silteM2 * 25.0;
    final double supurgelikTutari = supurgelikBoy * 110.0;
    final double toplamMaliyet = parkeTutari + silteTutari + supurgelikTutari;

    final buffer = StringBuffer();
    buffer.writeln('🪵 **ŞPD AI - Laminat Parke & Süpürgelik Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Zemin Alanı:** ${_f(a)} m²');
    buffer.writeln('📦 **Sipariş Parke:** **${_f(toplamParkeM2)} m²** (~**$paketSayisi Paket** [2.13 m²/paket])');
    buffer.writeln('🧶 **Kapron / Taban Şiltesi:** ~**${_f(silteM2)} m²**');
    buffer.writeln('• **Süpürgelik:** ~**$supurgelikBoy Boy** (2.80 mt)');
    buffer.writeln('💰 **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return MetrajHesapModel(
      category: 'parke',
      title: 'Laminat Parke & Süpürgelik Hesabı',
      icon: '🪵',
      elementAdi: v,
      primaryValue: a,
      primaryLabel: 'Zemin Alanı',
      primaryUnit: 'm²',
      selectedVariant: v,
      availableVariants: const [
        '8 mm 32. Sınıf Derzli Laminat',
        '8 mm 31. Sınıf Düz Laminat',
        '10 mm 33. Sınıf Yoğun Trafik',
      ],
      birimFiyat: bf,
      birimFiyatLabel: 'm² Parke Fiyatı (TL)',
      anaMiktar: '${_f(toplamParkeM2)} m²',
      anaMiktarLabel: 'Sipariş Edilecek Parke',
      lojistik: '~$paketSayisi Paket',
      lojistikLabel: 'Parke Paketi (2.13 m²)',
      firePayi: '%7 kesim & fire payı',
      toplamMaliyet: toplamMaliyet,
      toplamMaliyetLabel: 'Toplam Malzeme Maliyeti',
      sarfMalzemeler: [
        'Laminat Parke: ${_f(toplamParkeM2)} m² (~$paketSayisi Paket)',
        'Kapron / Taban Şiltesi: ~${_f(silteM2)} m²',
        'Süpürgelik: ~$supurgelikBoy Boy (2.80 mt) — ${_f(supurgelikMetre)} mt',
      ],
      tavsiyeler: const [
        'Parke paketleri döşeme öncesinde en az 48 saat mekanda bekletilmelidir.',
        'Duvar kenarlarında 10-15 mm genleşme boşluğu bırakılmalıdır.',
      ],
      raporMetni: buffer.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 0. YARDIM MENÜSÜ
  // ═══════════════════════════════════════════════════════════
  static bool _isHelpRequest(String norm) {
    final helpPhrases = [
      'metraj yardim',
      'neler hesaplayabilirsin',
      'ne hesaplayabilirsin',
      'malzeme hesabi nasil',
      'metraj komutlari',
      'hesaplayici',
    ];
    return helpPhrases.any((h) => norm.contains(h)) ||
        (norm.contains('metraj') && (norm.contains('nasil') || norm.contains('nedir') || norm.contains('yardim')));
  }

  static String _metrajYardimMenusu() {
    return '📐 **ŞPD AI - Akıllı Metraj ve Malzeme Hesaplayıcı**\n\n'
        'Bana şantiyedeki ölçüleri doğrudan yazın; anında interaktif hesaplama kartları, fire payları, paket/kutu/mikser sayıları ve piyasa maliyetini çıkarayım:\n\n'
        '🧱 **Desteklenen Hesaplama Kalemleri:**\n'
        '• **Beton & Tabliye:** *"350 m2 tabliyeye 15 cm C30 beton kaç mikser gider?"*\n'
        '• **Tuğla / Duvar:** *"120 m2 duvara 13.5 tuğla öreceğiz, kaç adet tuğla ve harç lazım?"*\n'
        '• **Seramik & Fayans:** *"80 m2 banyo seramik döşemeye kaç paket ve kaç torba yapıştırıcı gider?"*\n'
        '• **Zemin Şapı:** *"150 m2 daireye 5 cm şap atacağız, ne kadar kum ve çimento gerekir?"*\n'
        '• **Sıva & Alçı:** *"200 m2 alana alçı sıva kaç torba perlitli ve saten alçı tutar?"*\n'
        '• **Boya & Astar:** *"250 m2 duvara silikonlu iç cephe boyası kaç kova gider?"*\n'
        '• **İnşaat Demiri:** *"100 m3 betona kaç ton demir gerekir?"*\n'
        '• **Alçıpan Asma Tavan:** *"60 m2 asma tavan için kaç plaka alçıpan ve profil lazım?"*\n'
        '• **Mantolama / Isı Yalıtım:** *"300 m2 dış cepheye mantolama ne kadar strafor ve file tutar?"*\n'
        '• **Membran / Su Yalıtımı:** *"180 m2 terasa bitümlü membran kaç rulo gider?"*\n'
        '• **Hafriyat & Kazı:** *"400 m2 arsada 2.5m temel kazısı kaç kamyon çıkar?"*\n'
        '• **Parke / Laminat:** *"90 m2 daireye laminat parke ve süpürgelik ne kadar lazım?"*\n\n'
        '_⚡ Hesaplanan kartın üzerindeki "Düzenle" butonuna dokunarak değerleri dilediğiniz an değiştirebilir ve yeniden hesaplatabilirsiniz!_';
  }

  // ═══════════════════════════════════════════════════════════
  // PARSER YARDIMCILARI
  // ═══════════════════════════════════════════════════════════
  static double? _extractAlan(String original, String norm) {
    final m2Match = RegExp(r'(\d+[\.,]?\d*)\s*(m2|m²|metrekare|metre\s*kare|mt2)', caseSensitive: false).firstMatch(original);
    if (m2Match != null) {
      return double.tryParse(m2Match.group(1)!.replaceAll(',', '.'));
    }
    final genericMatch = RegExp(r'(\d+[\.,]?\d*)\s*(alan|tabliye|duvar|zemin|daire|arsa|cephe)', caseSensitive: false).firstMatch(norm);
    if (genericMatch != null) {
      return double.tryParse(genericMatch.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }

  static double? _extractKalinlikCm(String original, String norm) {
    final cmMatch = RegExp(r'(\d+[\.,]?\d*)\s*(cm|santim|santimetre)', caseSensitive: false).firstMatch(original);
    if (cmMatch != null) {
      return double.tryParse(cmMatch.group(1)!.replaceAll(',', '.'));
    }
    final mMatch = RegExp(r'(0[\.,]\d+)\s*(m|metre)', caseSensitive: false).firstMatch(original);
    if (mMatch != null) {
      final val = double.tryParse(mMatch.group(1)!.replaceAll(',', '.'));
      if (val != null) return val * 100.0;
    }
    return null;
  }

  static double? _extractHacimM3(String original, String norm) {
    final m3Match = RegExp(r'(\d+[\.,]?\d*)\s*(m3|m³|metrekup|metreküp)', caseSensitive: false).firstMatch(original);
    if (m3Match != null) {
      return double.tryParse(m3Match.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }

  static List<double> _extractDimensions(String text) {
    final match = RegExp(r'(\d+[\.,]?\d*)\s*[xX*]\s*(\d+[\.,]?\d*)(?:\s*[xX*]\s*(\d+[\.,]?\d*))?').firstMatch(text);
    if (match != null) {
      final a = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0.0;
      final b = double.tryParse(match.group(2)!.replaceAll(',', '.')) ?? 0.0;
      final c = match.group(3) != null ? (double.tryParse(match.group(3)!.replaceAll(',', '.')) ?? 0.0) : 0.0;
      return <double>[a, b, if (c > 0) c];
    }
    return [];
  }

  static String _normalize(String input) {
    return input
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  static String _f(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  static String _para(double tutar) {
    final intTam = tutar.toInt();
    final str = intTam.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join('')} ₺';
  }
}
