/// ŞPD AI - Akıllı İnşaat Metraj ve Malzeme Hesaplayıcı 🧱📐
/// Tamamen yerel, deterministik, formüllere dayalı şantiye malzeme motoru.
/// Gemini API veya harici sunucu KULLANMAZ; anlık, hatasız, internetsiz ve limitsiz çalışır.
/// Fire payları, paket/kutu/palet/mikser lojistiği ve yaklaşık piyasa maliyeti döker.
class InsaatMetrajHesaplayici {
  /// Prompt'u analiz eder, inşaat metrajı hesabı içeriyorsa formatlanmış rapor döner.
  /// Metraj hesabı değilse null döner.
  static String? hesapla(String prompt) {
    final lower = prompt.toLowerCase();
    final norm = _normalize(lower);

    // 0. Yardım Menüsü
    if (_isHelpRequest(norm)) {
      return _metrajYardimMenusu();
    }

    // 1. Beton & Tabliye / Temel / Kolon / Saha Betonu
    if (_isBetonHesabi(norm)) {
      return _hesaplaBeton(prompt, norm);
    }

    // 2. Tuğla / Bims / Gazbeton (Ytong) Duvar
    if (_isTuglaHesabi(norm)) {
      return _hesaplaTugla(prompt, norm);
    }

    // 3. Seramik / Fayans / Granit
    if (_isSeramikHesabi(norm)) {
      return _hesaplaSeramik(prompt, norm);
    }

    // 4. Şap (Tesviye Betonu)
    if (_isSapHesabi(norm)) {
      return _hesaplaSap(prompt, norm);
    }

    // 5. Sıva & Alçı
    if (_isSivaHesabi(norm)) {
      return _hesaplaSiva(prompt, norm);
    }

    // 6. Boya & Astar
    if (_isBoyaHesabi(norm)) {
      return _hesaplaBoya(prompt, norm);
    }

    // 7. Demir (Donatı)
    if (_isDemirHesabi(norm)) {
      return _hesaplaDemir(prompt, norm);
    }

    // 8. Alçıpan (Asma Tavan & Bölme Duvar)
    if (_isAlcipanHesabi(norm)) {
      return _hesaplaAlcipan(prompt, norm);
    }

    // 9. Dış Cephe Mantolama / Isı Yalıtımı
    if (_isMantolamaHesabi(norm)) {
      return _hesaplaMantolama(prompt, norm);
    }

    // 10. Su Yalıtımı & Membran
    if (_isYalitimHesabi(norm)) {
      return _hesaplaYalitim(prompt, norm);
    }

    // 11. Hafriyat & Kazı & Kamyon Seferi
    if (_isHafriyatHesabi(norm)) {
      return _hesaplaHafriyat(prompt, norm);
    }

    // 12. Parke / Laminat
    if (_isParkeHesabi(norm)) {
      return _hesaplaParke(prompt, norm);
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // 1. BETON HESAPLAYICI (Tabliye, Temel, Kolon, Saha)
  // ═══════════════════════════════════════════════════════════
  static bool _isBetonHesabi(String norm) {
    // Kazı ve hafriyat beton hesabı değildir
    if (norm.contains('kazi') || norm.contains('hafriyat')) {
      return false;
    }

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
    final hasKw = keywords.any((k) => norm.contains(k));
    final hasNumbers = RegExp(r'\d+').hasMatch(norm);
    return hasKw && hasNumbers;
  }

  static String _hesaplaBeton(String original, String norm) {
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

    // Varsayılan kalınlık
    if (kalinlikCm == null && direktHacim == null) {
      if (norm.contains('radye') || norm.contains('temel')) {
        kalinlikCm = 50.0;
      } else if (norm.contains('saha')) {
        kalinlikCm = 12.0;
      } else {
        kalinlikCm = 15.0; // Standart tabliye
      }
    }

    double netHacim = 0;
    if (direktHacim != null && direktHacim > 0) {
      netHacim = direktHacim;
    } else if (alan != null && alan > 0 && kalinlikCm != null) {
      netHacim = alan * (kalinlikCm / 100.0);
    } else {
      return '📐 **Beton Metrajı İçin Bilgi Gerekli:**\n\n'
          'Beton hesabı için lütfen alan (m²) ve kalınlık (cm) belirtin.\n'
          'Örnek: *"350 m2 tabliyeye 15 cm C30 beton kaç mikser tutar?"*';
    }

    // Beton sınıfı tespiti
    String betonSinifi = 'C25/30';
    double m3BirimFiyat = 2650.0; // 2025-2026 ortalama m³ beton fiyatı (KDV hariç)
    final gradeMatch = RegExp(r'(c\s?16|c\s?20|c\s?25|c\s?30|c\s?35|c\s?40)', caseSensitive: false).firstMatch(original);
    if (gradeMatch != null) {
      final g = gradeMatch.group(1)!.toUpperCase().replaceAll(' ', '');
      betonSinifi = g;
      if (g == 'C20') {
        m3BirimFiyat = 2400.0;
      } else if (g == 'C25') {
        m3BirimFiyat = 2550.0;
      } else if (g == 'C30') {
        m3BirimFiyat = 2700.0;
      } else if (g == 'C35') {
        m3BirimFiyat = 2900.0;
      } else if (g == 'C40') {
        m3BirimFiyat = 3150.0;
      }
    }

    String elemanAdi = 'Tabliye / Döşeme Betonu';
    if (norm.contains('radye')) {
      elemanAdi = 'Radye Temel Betonu';
    } else if (norm.contains('temel')) {
      elemanAdi = 'Mütemadi / Tekil Temel';
    } else if (norm.contains('kolon')) {
      elemanAdi = 'Kolon / Perde Betonu';
    } else if (norm.contains('saha')) {
      elemanAdi = 'Saha / Zemin Betonu';
    } else if (norm.contains('grobeton')) {
      elemanAdi = 'Grobeton';
    }

    // Fire payı (%5 tabliye, %7 temel)
    final double fireOrani = (norm.contains('temel') || norm.contains('grobeton')) ? 0.07 : 0.05;
    final double fireHacmi = netHacim * fireOrani;
    final double toplamSiparis = netHacim + fireHacmi;

    // Transmikser hesabı (1 mikser standart 8.5 m³ baz alınır)
    const double mikserKapasite = 8.5;
    final int mikserSayisi = (toplamSiparis / mikserKapasite).ceil();

    // Yaklaşık donatı ihtiyacı (90 kg/m³)
    final double tahminiDemirTon = (netHacim * 90.0) / 1000.0;

    // Maliyet hesabı
    final double betonMaliyeti = toplamSiparis * m3BirimFiyat;
    final double pompaMaliyeti = toplamSiparis >= 15 ? 12000.0 : 0.0; // Pompa bedeli
    final double toplamMaliyet = betonMaliyeti + pompaMaliyeti;

    final buffer = StringBuffer();
    buffer.writeln('🏗️ **ŞPD AI - Hazır Beton & Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📋 **Uygulama:** $elemanAdi ($betonSinifi)');
    if (alan != null) {
      buffer.writeln('📐 **Döküm Alanı:** ${_f(alan)} m²');
      buffer.writeln('📏 **Döküm Kalınlığı:** ${_f(kalinlikCm!)} cm');
    }
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
    buffer.writeln('• **Hazır Beton (${_f(toplamSiparis)} m³ x ${_para(m3BirimFiyat)}):** ${_para(betonMaliyeti)}');
    if (pompaMaliyeti > 0) {
      buffer.writeln('• **Mobil Beton Pompası Hizmeti:** ${_para(pompaMaliyeti)}');
    }
    buffer.writeln('• **Toplam Tahmini Beton Gideri:** **${_para(toplamMaliyet)}** (+KDV)');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Vibratör yedekli bulundurulmalı; döküm esnasında demire değil betona daldırılmalıdır.');
    buffer.writeln('2. Döküm sonrası ilk 24 saat rötre çatlaklarına karşı nemlendirilmeli, 7 gün boyunca düzenli sulanmalıdır.');
    buffer.writeln('3. Son mikser şantiyeye çıkmadan önce kalıp içi ölçülüp kalan net hacim santrale iletilmelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 2. TUĞLA & BİMS & GAZBETON (YTONG) DUVAR HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isTuglaHesabi(String norm) {
    final keywords = [
      'tugla',
      'tuğla',
      'duvar',
      'bims',
      'gazbeton',
      'ytong',
      'briket',
    ];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaTugla(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🧱 **Duvar Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen duvar alanını (m²) belirtin.\n'
          'Örnek: *"120 m2 duvara 13.5 tuğla öreceğiz, kaç adet tuğla ve ne kadar harç gider?"*';
    }

    // Malzeme cinsi
    String malzemeAdi = "13.5'luk Yatay Delikli Tuğla (Standart)";
    double adetPerM2 = 25.0;
    int paletAdedi = 420;
    double birimFiyat = 7.5; // Adet tuğla TL
    bool isGazbeton = false;

    if (norm.contains('8.5') || norm.contains('8,5')) {
      malzemeAdi = "8.5'luk İnce Bölme Tuğlası";
      adetPerM2 = 28.0;
      paletAdedi = 550;
      birimFiyat = 6.2;
    } else if (norm.contains('19') || norm.contains('izo')) {
      malzemeAdi = "19'luk Isı Yalıtımlı Dış Duvar Tuğlası";
      adetPerM2 = 22.0;
      paletAdedi = 320;
      birimFiyat = 11.5;
    } else if (norm.contains('bims')) {
      malzemeAdi = "15'lik veya 20'lik Bims Blok";
      adetPerM2 = 12.5;
      paletAdedi = 80;
      birimFiyat = 16.0;
    } else if (norm.contains('gazbeton') || norm.contains('ytong')) {
      malzemeAdi = "Gazbeton / Ytong Blok (60x25 cm)";
      adetPerM2 = 6.67;
      paletAdedi = 48;
      birimFiyat = 42.0;
      isGazbeton = true;
    }

    final double netAdet = alan * adetPerM2;
    final double fireAdet = netAdet * 0.05; // %5 fire
    final int toplamAdet = (netAdet + fireAdet).ceil();
    final int paletSayisi = (toplamAdet / paletAdedi).ceil();

    final buffer = StringBuffer();
    buffer.writeln('🧱 **ŞPD AI - Duvar Örme & Malzeme Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📋 **Malzeme Cinsi:** $malzemeAdi');
    buffer.writeln('📐 **Toplam Duvar Alanı:** ${_f(alan)} m²');
    buffer.writeln('📊 **Birim Sarfiyat:** ${_f(adetPerM2)} adet / m²');
    buffer.writeln('⚠️ **Önerilen Fire Payı:** +%5 (kırılma ve köşe kesimleri)');
    buffer.writeln('📦 **Sipariş Edilecek Toplam:** **$toplamAdet Adet** (~**$paletSayisi Palet**)');
    buffer.writeln('');
    buffer.writeln('🥣 **Harç & Bağlayıcı İhtiyacı:**');

    double harcMaliyeti = 0.0;
    if (isGazbeton) {
      final double tutkalKg = alan * 2.5; // ~2.5 kg/m²
      final int torbaTutkal = (tutkalKg / 25.0).ceil();
      harcMaliyeti = torbaTutkal * 190.0;
      buffer.writeln('• **Gazbeton Örgü Tutkalı:** ~**$torbaTutkal Torba** (25 kg\'lık) — Toplam ${_f(tutkalKg)} kg');
      buffer.writeln('• Taraklı gazbeton malası ile 2-3 mm derz kalınlığında örülmelidir.');
    } else {
      final double harcHacmiM3 = alan * 0.035; // 1 m² duvara ~0.035 m³ harç
      final double cimentoKg = alan * 7.5; // ~7.5 kg çimento
      final int cimentoTorba50 = (cimentoKg / 50.0).ceil();
      final double kumM3 = harcHacmiM3 * 0.9;
      final double cimentoTutari = cimentoTorba50 * 200.0;
      final double kumTutari = kumM3 * 650.0;
      harcMaliyeti = cimentoTutari + kumTutari;

      buffer.writeln('• **Gereken Harç Hacmi:** ~${_f(harcHacmiM3)} m³');
      buffer.writeln('• **Portland Çimentosu:** ~**$cimentoTorba50 Torba** (50 kg\'lık) — Toplam ${_f(cimentoKg)} kg');
      buffer.writeln('• **Duvar/Sıva Kumu:** ~**${_f(kumM3)} m³** (0-3 mm dişli kum)');
    }

    final double tuglaMaliyeti = toplamAdet * birimFiyat;
    final double toplamTahmini = tuglaMaliyeti + harcMaliyeti;

    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Duvar Blok Malzemesi ($toplamAdet adet):** ${_para(tuglaMaliyeti)}');
    buffer.writeln('• **Harç & Bağlayıcı Gideri:** ${_para(harcMaliyeti)}');
    buffer.writeln('• **Toplam Tahmini Duvar Malzemesi:** **${_para(toplamTahmini)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Tuğlalar örülmeden önce ıslatılmalıdır (harcın suyunu hızla emip yakmaması için).');
    buffer.writeln('2. Günde 1.5 metreden (yaklaşık 7-8 sıra) fazla yükseklik örülmemelidir; priz alması beklenmelidir.');
    buffer.writeln('3. Kolon-duvar birleşimlerine en az her 3 sırada bir L ankraj demiri çakılmalıdır.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 3. SERAMİK / FAYANS / GRANİT HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSeramikHesabi(String norm) {
    final keywords = [
      'seramik',
      'fayans',
      'granit',
      'kalebodur',
      'porselen',
      'yer dosemesi',
      'derz',
      'kalekim',
    ];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaSeramik(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '✨ **Seramik Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen kaplanacak alanı (m²) belirtin.\n'
          'Örnek: *"80 m2 alana seramik döşemek için kaç paket seramik ve kaç torba yapıştırıcı lazım?"*';
    }

    // %10 fire (kesim, köşe ve süpürgelik payı)
    final double fireOrani = 0.10;
    final double toplamSeramikM2 = alan * (1 + fireOrani);

    // Kutu hesabı: 1 kutu standart 1.44 m² kabul edilir (60x60 veya 60x120)
    const double kutuM2 = 1.44;
    final int paketSayisi = (toplamSeramikM2 / kutuM2).ceil();

    // Seramik yapıştırıcısı: m² başına 4.8 kg
    final double yapistiriciKg = alan * 4.8;
    final int yapistiriciTorba = (yapistiriciKg / 25.0).ceil();

    // Derz dolgusu: m² başına ~0.5 kg (2-3 mm derz için)
    final double derzKg = alan * 0.5;
    final int derzTorba5Kg = (derzKg / 5.0).ceil();

    // Maliyet hesapları
    final double seramikBirimM2 = 450.0; // 60x60 / 60x120 1. sınıf porselen seramik ortalaması
    final double seramikTutari = toplamSeramikM2 * seramikBirimM2;
    final double yapistiriciTutari = yapistiriciTorba * 220.0; // 25kg C2TE
    final double derzTutari = derzTorba5Kg * 140.0; // 5kg Fuga
    final double klipsSarf = (alan * 12) * 0.45; // Klips & takoz birim maliyeti
    final double toplamMaliyet = seramikTutari + yapistiriciTutari + derzTutari + klipsSarf;

    final buffer = StringBuffer();
    buffer.writeln('✨ **ŞPD AI - Seramik, Granit & Yapıştırıcı Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Kaplama Alanı:** ${_f(alan)} m²');
    buffer.writeln('⚠️ **Önerilen Fire Payı (%10):** +${_f(alan * fireOrani)} m² (Köşe, süpürgelik & kesim)');
    buffer.writeln('📦 **Sipariş Edilecek Seramik:** **${_f(toplamSeramikM2)} m²** (~**$paketSayisi Kutu/Paket** [1.44 m²/kutu])');
    buffer.writeln('');
    buffer.writeln('🥣 **Kimyasal & Sarf Malzeme İhtiyacı:**');
    buffer.writeln('• **Seramik Yapıştırıcısı (C2TE):** **$yapistiriciTorba Torba** (25 kg\'lık) — Toplam ${_f(yapistiriciKg)} kg');
    buffer.writeln('• **Derz Dolgusu (Fuga):** **$derzTorba5Kg Kutu/Torba** (5 kg\'lık) — Toplam ${_f(derzKg)} kg');
    buffer.writeln('• **Derz Artısı / Terazi Klipsi:** Yaklaşık ${(alan * 12).toInt()} adet klips ve takoz');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **Porselen Seramik (${_f(toplamSeramikM2)} m² x ${_para(seramikBirimM2)}):** ${_para(seramikTutari)}');
    buffer.writeln('• **Yapıştırıcı ($yapistiriciTorba torba) & Fuga ($derzTorba5Kg adet):** ${_para(yapistiriciTutari + derzTutari)}');
    buffer.writeln('• **Klips & Yardımcı Sarf:** ${_para(klipsSarf)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Zemin eğimi kontrol edilmeli; 5 mm üzeri sapmalarda önce tesviye şapı çekilmelidir.');
    buffer.writeln('2. 60x60 ve üzeri porselen seramiklerde hem zemine hem seramiğin arkasına çift taraflı yapıştırma yapılmalıdır.');
    buffer.writeln('3. Derz dolgusu yapıştırmadan en az 24-48 saat sonra uygulanmalıdır.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 4. ŞAP (TESVİYE BETONU) HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSapHesabi(String norm) {
    final keywords = ['şap', 'sap', 'tesviye betonu', 'yer şapı', 'yer sapi'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaSap(String original, String norm) {
    double? alan = _extractAlan(original, norm);
    double? kalinlikCm = _extractKalinlikCm(original, norm) ?? 5.0; // Standart 5 cm

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '📐 **Şap Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen alanı (m²) ve şap kalınlığını (cm) belirtin.\n'
          'Örnek: *"150 m2 daireye 5 cm şap atacağız, ne kadar kum ve çimento gider?"*';
    }

    final double hacimM3 = alan * (kalinlikCm / 100.0);
    const double cimentoDoz = 350.0; // 350 doz standardı
    final double toplamCimentoKg = hacimM3 * cimentoDoz;
    final int cimentoTorba50 = (toplamCimentoKg / 50.0).ceil();
    final double kumM3 = hacimM3 * 1.15;
    final double elyafKg = hacimM3 * 0.9;

    final double cimentoTutari = cimentoTorba50 * 200.0;
    final double kumTutari = kumM3 * 650.0;
    final double elyafTutari = elyafKg * 160.0;
    final double toplamMaliyet = cimentoTutari + kumTutari + elyafTutari;

    final buffer = StringBuffer();
    buffer.writeln('📐 **ŞPD AI - Zemin Şapı & Tesviye Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Uygulama Alanı:** ${_f(alan)} m²');
    buffer.writeln('📏 **Ortalama Şap Kalınlığı:** ${_f(kalinlikCm)} cm');
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
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Zemin temizlenip tozdan arındırılmalı ve aderans köprüsü (şerbet/astar) uygulanmalıdır.');
    buffer.writeln('2. Geniş mekanlarda 25-30 m²\'de bir derz kesilerek oturma çatlakları engellenmelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 5. SIVA & ALÇI HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isSivaHesabi(String norm) {
    final keywords = ['sıva', 'siva', 'alçı', 'alci', 'kara sıva', 'alçı sıva', 'saten'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaSiva(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🖌️ **Sıva & Alçı Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen alanı (m²) belirtin.\n'
          'Örnek: *"200 m2 duvara alçı sıva yapacağız, kaç torba alçı gider?"*';
    }

    final bool isKaraSiva = norm.contains('kara') || norm.contains('cimento') || norm.contains('kaba');
    final buffer = StringBuffer();
    buffer.writeln('🖌️ **ŞPD AI - Sıva & Alçı Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Uygulama Alanı:** ${_f(alan)} m²');

    double toplamMaliyet = 0.0;
    if (isKaraSiva) {
      final double kumM3 = alan * 0.024;
      final double cimentoKg = alan * 7.5;
      final int cimentoTorba50 = (cimentoKg / 50.0).ceil();
      final double cimentoTutari = cimentoTorba50 * 200.0;
      final double kumTutari = kumM3 * 650.0;
      toplamMaliyet = cimentoTutari + kumTutari;

      buffer.writeln('📋 **Tür:** Çimento Esaslı Kaba Sıva (Kara Sıva - ~2 cm)');
      buffer.writeln('• **Sıva Kumu:** ~**${_f(kumM3)} m³**');
      buffer.writeln('• **Çimento:** ~**$cimentoTorba50 Torba** (50 kg\'lık) — Toplam ${_f(cimentoKg)} kg');
      buffer.writeln('• **Kireç:** ~${(alan * 2.5 / 25).ceil()} Torba torbalı sönmüş kireç');
      buffer.writeln('');
      buffer.writeln('💰 **Tahmini Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    } else {
      final double alciKg = alan * 9.0;
      final int alciTorba35 = (alciKg / 35.0).ceil();
      final double satenKg = alan * 1.0;
      final int satenTorba25 = (satenKg / 25.0).ceil();
      final double alciTutari = alciTorba35 * 165.0;
      final double satenTutari = satenTorba25 * 145.0;
      final double kosebentAstar = alan * 15.0;
      toplamMaliyet = alciTutari + satenTutari + kosebentAstar;

      buffer.writeln('📋 **Tür:** İç Mekan Perlitli Sıva Alçısı + Saten Perdah');
      buffer.writeln('📦 **Malzeme İhtiyacı:**');
      buffer.writeln('• **Perlitli Sıva Alçısı (1 cm):** **$alciTorba35 Torba** (35 kg\'lık) — Toplam ${_f(alciKg)} kg');
      buffer.writeln('• **Saten Perdah Alçısı (Son Kat):** **$satenTorba25 Torba** (25 kg\'lık) — Toplam ${_f(satenKg)} kg');
      buffer.writeln('• **Fileli Sıva Köşebenti:** Kapı ve kolon kenarları için köşe profili');
      buffer.writeln('• **Brüt Beton Astarı:** ~${_f(alan * 0.25)} kg kumlu astar');
      buffer.writeln('');
      buffer.writeln('💰 **Tahmini Malzeme Maliyeti:**');
      buffer.writeln('• **Perlitli Sıva ($alciTorba35 torba):** ${_para(alciTutari)}');
      buffer.writeln('• **Saten Alçı ($satenTorba25 torba):** ${_para(satenTutari)}');
      buffer.writeln('• **Köşebent & Astar:** ${_para(kosebentAstar)}');
      buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    }

    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Brüt beton yüzeylerde aderansı artırmak için kesinlikle brüt beton astarı (kumlu astar) uygulanmalıdır.');
    buffer.writeln('2. Alçı karışımı temiz su ve temiz teknede yapılmalı, priz almaya başlayan harca su ilave edilmemelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 6. BOYA & ASTAR HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isBoyaHesabi(String norm) {
    final keywords = ['boya', 'astar', 'iç cephe', 'ic cephe', 'dış cephe', 'dis cephe', 'tavan boya'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaBoya(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🎨 **Boya Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen boyanacak alanı (m²) belirtin.\n'
          'Örnek: *"250 m2 duvara silikonlu iç cephe boyası kaç kova gider?"*';
    }

    // 1 Litre boya çift katta ortalama 7.5 m²
    final double boyaLitre = alan / 7.5;
    final int kova15Litre = (boyaLitre / 15.0).ceil();

    // 1 Litre astar tek katta ortalama 11 m²
    final double astarLitre = alan / 11.0;
    final int astarKova15Litre = (astarLitre / 15.0).ceil();

    final double tavanBoyaKg = (alan * 0.35);
    final int tavanKova17_5Kg = (tavanBoyaKg / 17.5).ceil();

    final double boyaTutari = kova15Litre * 2250.0;
    final double astarTutari = astarKova15Litre * 1350.0;
    final double tavanTutari = tavanKova17_5Kg * 750.0;
    final double sarfMalzeme = 450.0; // Bant, hışır, rulo
    final double toplamMaliyet = boyaTutari + astarTutari + tavanTutari + sarfMalzeme;

    final buffer = StringBuffer();
    buffer.writeln('🎨 **ŞPD AI - Boya & Astar Metraj Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Boya Alanı:** ${_f(alan)} m²');
    buffer.writeln('🎨 **Uygulama:** Çift Kat Silikonlu İç Cephe');
    buffer.writeln('');
    buffer.writeln('📦 **Gereken Ambalaj Sayıları:**');
    buffer.writeln('• **Duvar Boyası (Çift Kat):** **$kova15Litre Kova** (15 Litrelik) — Toplam ${_f(boyaLitre)} Litre');
    buffer.writeln('• **Şeffaf / Dönüşüm Astarı:** **$astarKova15Litre Kova** (15 Litrelik) — Toplam ${_f(astarLitre)} Litre');
    buffer.writeln('• **Tavan Boyası:** ~**$tavanKova17_5Kg Kova** (17.5 kg plastik tavan boyası)');
    buffer.writeln('• **Yardımcı Malzemeler:** 3-4 rulo maskeleme bandı, 2 adet zemin hışır örtü');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Piyasa Rayici):**');
    buffer.writeln('• **İç Cephe Boyası ($kova15Litre kova):** ${_para(boyaTutari)}');
    buffer.writeln('• **Astar ($astarKova15Litre kova) & Tavan ($tavanKova17_5Kg kova):** ${_para(astarTutari + tavanTutari)}');
    buffer.writeln('• **Rulo, Bant & Örtü Sarfiyatı:** ${_para(sarfMalzeme)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Alçı yüzeylerin zımparası bittikten sonra toz tamamen temizlenmeden astar atılmamalıdır.');
    buffer.writeln('2. Katlar arasında en az 4-6 saat kuruma süresi beklenmelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 7. DEMİR (DONATI) HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isDemirHesabi(String norm) {
    final keywords = ['demir', 'donatı', 'donati', 'inşaat demiri', 'insaat demiri', 'ton demir'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaDemir(String original, String norm) {
    double? hacimM3 = _extractHacimM3(original, norm);
    double? alan = _extractAlan(original, norm);

    if (hacimM3 == null && alan == null) {
      return '🔩 **Demir Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen beton hacmini (m³) veya toplam inşaat kapalı alanını (m²) belirtin.\n'
          'Örnek: *"120 m3 betona kaç ton demir gider?"* veya *"500 m2 inşaata ne kadar demir gerekir?"*';
    }

    double toplamTon = 0;
    String aciklama = '';

    if (hacimM3 != null && hacimM3 > 0) {
      const double kgPerM3 = 90.0;
      final double toplamKg = hacimM3 * kgPerM3;
      toplamTon = toplamKg / 1000.0;
      aciklama = '${_f(hacimM3)} m³ beton hacmi baz alındı (90 kg/m³)';
    } else if (alan != null && alan > 0) {
      const double kgPerM2 = 40.0;
      final double toplamKg = alan * kgPerM2;
      toplamTon = toplamKg / 1000.0;
      aciklama = '${_f(alan)} m² kapalı inşaat alanı baz alındı (40 kg/m²)';
    }

    final double bagTeliKg = toplamTon * 15.0; // Ton başına 15 kg bağ teli
    const double demirTonFiyati = 31000.0; // Güncel nervürlü donatı ton fiyatı TL
    final double demirMaliyeti = toplamTon * demirTonFiyati;
    final double bagTeliMaliyeti = bagTeliKg * 55.0;
    final double toplamMaliyet = demirMaliyeti + bagTeliMaliyeti;

    final buffer = StringBuffer();
    buffer.writeln('🔩 **ŞPD AI - İnşaat Demiri (Donatı) Yaklaşık Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📋 **Ölçüt:** $aciklama');
    buffer.writeln('📊 **Tahmini Donatı Miktarı:** **${_f(toplamTon)} Ton** (~${_f(toplamTon * 1000)} kg)');
    buffer.writeln('🧵 **Tavlı Bağ Teli:** ~**${_f(bagTeliKg)} kg** (Ton başına 15 kg)');
    buffer.writeln('');
    buffer.writeln('📐 **Kaba Çap Dağılım Tahmini:**');
    buffer.writeln('• **İnce Çaplar (Ø8 - Ø10):** ~%25 (${_f(toplamTon * 0.25)} Ton - Etriye & döşeme)');
    buffer.writeln('• **Orta Çaplar (Ø12 - Ø16):** ~%45 (${_f(toplamTon * 0.45)} Ton - Kiriş & kolon boyuna)');
    buffer.writeln('• **Kalın Çaplar (Ø18 - Ø25):** ~%30 (${_f(toplamTon * 0.30)} Ton - Kolon & temel donatısı)');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Yaklaşık Maliyet (Fabrika/Tüccar Rayici):**');
    buffer.writeln('• **Nervürlü Demir (${_f(toplamTon)} Ton x ${_para(demirTonFiyati)}):** ${_para(demirMaliyeti)}');
    buffer.writeln('• **Tavlı Bağ Teli (${_f(bagTeliKg)} kg):** ${_para(bagTeliMaliyeti)}');
    buffer.writeln('• **Toplam Demir Maliyeti:** **${_para(toplamMaliyet)}** (+Nakliye & KDV)');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Paspayı takozları ihmal edilmemeli (temelde 5 cm, kolon/kirişte 3 cm).');
    buffer.writeln('2. Kesin tonaj statik aplikasyon projesindeki donatı metraj cetvelinden teyit edilmelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 8. ALÇIPAN HESAPLAYICI (Asma Tavan & Bölme Duvar)
  // ═══════════════════════════════════════════════════════════
  static bool _isAlcipanHesabi(String norm) {
    final keywords = ['alçıpan', 'alcipan', 'asma tavan', 'bölme duvar', 'bolme duvar'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaAlcipan(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🏗️ **Alçıpan Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen alanı (m²) belirtin.\n'
          'Örnek: *"60 m2 asma tavan için kaç plaka alçıpan ve profil gider?"*';
    }

    // 1 adet standart alçıpan = 1.20 x 2.50 = 3.0 m² (+%7 fire)
    final int plakaSayisi = ((alan * 1.07) / 3.0).ceil();
    final double tcProfilMetre = alan * 1.8;
    final int tcBoy3m = (tcProfilMetre / 3.0).ceil();
    final int vidaAdet = (alan * 25).toInt();
    final double derzBandiMetre = alan * 1.5;
    final int derzAlciTorba = (alan * 0.4 / 25.0).ceil();

    final double plakaTutari = plakaSayisi * 210.0;
    final double profilTutari = tcBoy3m * 95.0;
    final double sarfTutari = vidaAdet * 0.35 + derzAlciTorba * 180.0 + 200.0;
    final double toplamMaliyet = plakaTutari + profilTutari + sarfTutari;

    final buffer = StringBuffer();
    buffer.writeln('🏗️ **ŞPD AI - Alçıpan Asma Tavan & Bölme Duvar Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Alan:** ${_f(alan)} m²');
    buffer.writeln('📦 **Gereken Plaka:** **$plakaSayisi Adet Plaka** (12.5mm Alçıpan [1.2x2.5m])');
    buffer.writeln('');
    buffer.writeln('🔩 **Karkas & Bağlantı Elemanları:**');
    buffer.writeln('• **Tavan C (TC) Profili:** ~**$tcBoy3m Boy** (3 metrelik) — Toplam ${_f(tcProfilMetre)} metre');
    buffer.writeln('• **Tavan U (TU) Profili:** Odanın çevre uzunluğu kadar');
    buffer.writeln('• **Borazan Vida (25 mm):** ~**$vidaAdet Adet**');
    buffer.writeln('• **Derz Bandı (File):** ~${_f(derzBandiMetre)} Metre');
    buffer.writeln('• **Derz Dolgu Alçısı (Fugagips):** ~**$derzAlciTorba Torba**');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti:**');
    buffer.writeln('• **Alçıpan Plakalar ($plakaSayisi adet):** ${_para(plakaTutari)}');
    buffer.writeln('• **Galvaniz Profiller ($tcBoy3m boy TC):** ${_para(profilTutari)}');
    buffer.writeln('• **Vida, Dübel, File & Derz Alçısı:** ${_para(sarfTutari)}');
    buffer.writeln('• **Toplam Karkas & Plaka Maliyeti:** **${_para(toplamMaliyet)}**');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 9. DIŞ CEPHE MANTOLAMA / ISI YALITIMI HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isMantolamaHesabi(String norm) {
    final keywords = ['mantolama', 'isi yalitim', 'ısı yalıtım', 'tasyunu', 'taşyünü', 'eps', 'karbonlu eps'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaMantolama(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🧱 **Mantolama Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen cephe alanını (m²) belirtin.\n'
          'Örnek: *"300 m2 dış cepheye mantolama yapacağız, ne kadar strafor, yapıştırıcı ve file gider?"*';
    }

    // %5 fire
    final double toplamLevhaM2 = alan * 1.05;
    final int paketSayisi = (toplamLevhaM2 / 5.0).ceil(); // Standart 1 paket EPS ~5 m² (5 cm kalınlık)

    // Yapıştırıcı (4.5 kg/m²) ve Sıva (4.5 kg/m²)
    final int yapistiriciTorba = ((alan * 4.5) / 25.0).ceil();
    final int sivaTorba = ((alan * 4.5) / 25.0).ceil();

    // Donatı Filesi (160 gr): alan * 1.10 (%10 bini payı)
    final double fileM2 = alan * 1.10;
    final int fileRulo = (fileM2 / 50.0).ceil(); // 50 m² rulo

    // Dübel: m² başına 6 adet
    final int dubelAdet = (alan * 6).toInt();

    // Dekoratif mineral sıva: m² başına ~2.8 kg
    final int mineralSivaTorba = ((alan * 2.8) / 25.0).ceil();

    // Maliyet hesabı
    final double levhaTutari = toplamLevhaM2 * 180.0; // 5 cm EPS m²
    final double yapistiriciSivaTutari = (yapistiriciTorba + sivaTorba) * 190.0;
    final double fileDubelTutari = (fileRulo * 950.0) + (dubelAdet * 1.2);
    final double mineralSivaTutari = mineralSivaTorba * 220.0;
    final double toplamMaliyet = levhaTutari + yapistiriciSivaTutari + fileDubelTutari + mineralSivaTutari;

    final buffer = StringBuffer();
    buffer.writeln('🏠 **ŞPD AI - Dış Cephe Isı Yalıtımı (Mantolama) Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Cephe Alanı:** ${_f(alan)} m²');
    buffer.writeln('📦 **Yalıtım Levhası (5 cm EPS):** **${_f(toplamLevhaM2)} m²** (~**$paketSayisi Paket**)');
    buffer.writeln('');
    buffer.writeln('🧱 **Sıva, Yapıştırıcı & Donatı Malzemeleri:**');
    buffer.writeln('• **Mantolama Yapıştırıcısı:** **$yapistiriciTorba Torba** (25 kg\'lık)');
    buffer.writeln('• **Mantolama Sıvası:** **$sivaTorba Torba** (25 kg\'lık)');
    buffer.writeln('• **Donatı Filesi (160 gr):** **$fileRulo Rulo** (50 m²\'lik) — Toplam ${_f(fileM2)} m²');
    buffer.writeln('• **Plastik/Çelik Çivili Dübel:** **$dubelAdet Adet** (6 adet/m²)');
    buffer.writeln('• **Dekoratif Mineral Kaplama Sıvası:** **$mineralSivaTorba Torba** (25 kg\'lık)');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti (Piyasa Rayici):**');
    buffer.writeln('• **EPS Yalıtım Levhaları:** ${_para(levhaTutari)}');
    buffer.writeln('• **Yapıştırıcı & Sıva:** ${_para(yapistiriciSivaTutari)}');
    buffer.writeln('• **File, Dübel & Aksesuar:** ${_para(fileDubelTutari)}');
    buffer.writeln('• **Dekoratif Mineral Sıva:** ${_para(mineralSivaTutari)}');
    buffer.writeln('• **Toplam Paket Malzeme:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Levhalar şaşırtmalı örülmeli, köşe ve pencere kenarlarında L şeklinde kesim (çatlak önleyici) yapılmalıdır.');
    buffer.writeln('2. Donatı filesi ek yerlerinde en az 10 cm üst üste bindirilmelidir.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 10. SU YALITIMI & MEMBRAN HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isYalitimHesabi(String norm) {
    final keywords = ['membran', 'su yalitim', 'su yalitimi', 'izolasyon', 'likit membran', 'bitum'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaYalitim(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '💧 **Su Yalıtımı Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen yalıtım yapılacak alanı (m²) belirtin.\n'
          'Örnek: *"180 m2 çatı terasına bitümlü membran kaç rulo ve astar gider?"*';
    }

    // %12 bini ve parapet dönme payı
    final double toplamMembranM2 = alan * 1.12;
    // 1 rulo membran standart 10 m² (1m x 10m)
    final int ruloSayisi = (toplamMembranM2 / 10.0).ceil();

    // Bitüm astar: m² başına ~0.35 kg
    final double astarKg = alan * 0.35;
    final int astarTeneke = (astarKg / 16.0).ceil(); // 16 kg teneke

    // Şaloma tüpü: Yaklaşık her 100 m²'ye 1 sanayi tüpü
    final int tupSayisi = (alan / 100.0).ceil();

    final double membranTutari = ruloSayisi * 1450.0; // 3mm / 4mm kumlu/mineral rulo
    final double astarTutari = astarTeneke * 980.0;
    final double gazTutari = tupSayisi * 900.0;
    final double toplamMaliyet = membranTutari + astarTutari + gazTutari;

    final buffer = StringBuffer();
    buffer.writeln('💧 **ŞPD AI - Su Yalıtımı & Bitümlü Membran Metrajı**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Yalıtım Alanı:** ${_f(alan)} m²');
    buffer.writeln('⚠️ **Bini & Parapet Payı (%12):** +${_f(toplamMembranM2 - alan)} m²');
    buffer.writeln('📦 **Membran İhtiyacı:** **$ruloSayisi Rulo** (10 m²\'lik rulolar halinde) — Toplam ${_f(toplamMembranM2)} m²');
    buffer.writeln('');
    buffer.writeln('🥣 **Astar & Sarf Malzeme:**');
    buffer.writeln('• **Bitümlü Astar:** **$astarTeneke Teneke** (16 kg\'lık) — Toplam ${_f(astarKg)} kg');
    buffer.writeln('• **Şaloma Gazı (Sanayi Tüpü):** ~**$tupSayisi Adet**');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti:**');
    buffer.writeln('• **Bitümlü Membran ($ruloSayisi rulo):** ${_para(membranTutari)}');
    buffer.writeln('• **Bitüm Astarı ($astarTeneke teneke):** ${_para(astarTutari)}');
    buffer.writeln('• **Tüp & Sarfiyat:** ${_para(gazTutari)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Parapet dönüşlerinde pah bantları ihmal edilmemeli, membran dik eksende en az 25-30 cm yukarı döndürülmelidir.');
    buffer.writeln('2. Boyuna bindirmelerde 10 cm, enine bindirmelerde 15 cm şaloma ile tam eritilerek yapıştırılmalıdır.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 11. HAFRİYAT & KAZI & KAMYON SEFERİ HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isHafriyatHesabi(String norm) {
    final keywords = ['hafriyat', 'kazi', 'kazı', 'kamyon seferi', 'kamyon'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaHafriyat(String original, String norm) {
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

    double netKaziM3 = 0;
    if (direktM3 != null && direktM3 > 0) {
      netKaziM3 = direktM3;
    } else if (alan != null && derinlikM != null) {
      netKaziM3 = alan * derinlikM;
    } else {
      return '🚜 **Hafriyat Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen kazı alanını (m²) ve derinliğini (m) ya da toplam kazı hacmini (m³) belirtin.\n'
          'Örnek: *"400 m2 arsada 2.5 metre temel kazısı kaç kamyon hafriyat çıkar?"*';
    }

    // Toprak kabarma katsayısı: %20 - %25 kabarma
    const double kabarmaOrani = 0.25;
    final double kabarikHacim = netKaziM3 * (1 + kabarmaOrani);

    // Standart 3 veya 4 dingilli hafriyat kamyonu faydalı hacmi ~15 m³
    const double kamyonKapasiteM3 = 15.0;
    final int kamyonSeferSayisi = (kabarikHacim / kamyonKapasiteM3).ceil();

    // Yaklaşık sefer başı nakliye + döküm ücreti (İstanbul/Büyükşehir ortalaması ~2.800 ₺/sefer)
    final double seferBirimFiyat = 2800.0;
    final double toplamHafriyatMaliyeti = kamyonSeferSayisi * seferBirimFiyat;

    final buffer = StringBuffer();
    buffer.writeln('🚜 **ŞPD AI - Temel Kazısı & Hafriyat Lojistik Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('🧊 **Sıkışık (Net) Kazı Hacmi:** ${_f(netKaziM3)} m³');
    buffer.writeln('📈 **Zemin Kabarma Payı (%${(kabarmaOrani * 100).toInt()}):** +${_f(kabarikHacim - netKaziM3)} m³');
    buffer.writeln('🚚 **Toplam Taşınacak Hacim:** **${_f(kabarikHacim)} m³**');
    buffer.writeln('');
    buffer.writeln('🚛 **Lojistik & Kamyon İhtiyacı:**');
    buffer.writeln('• **Hafriyat Kamyonu Kapasitesi:** 15 m³ (Standart 4 dingilli damperli kamyon)');
    buffer.writeln('• **Gereken Toplam Sefer Sayısı:** ~**$kamyonSeferSayisi Sefer**');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Hafriyat & Döküm Maliyeti:**');
    buffer.writeln('• **Ortalama Sefer Bedeli (Nakliye + Döküm):** ${_para(seferBirimFiyat)} / sefer');
    buffer.writeln('• **Toplam Tahmini Hafriyat Gideri:** **${_para(toplamHafriyatMaliyeti)}**');
    buffer.writeln('');
    buffer.writeln('💡 **Şantiye Şefine Tavsiyeler:**');
    buffer.writeln('1. Kazı kotu laser nivo ile kontrol edilmeli; temel altı lüzumsuz derin kazılıp grobeton zayiatı yaratılmamalıdır.');
    buffer.writeln('2. Derin kazılarda komşu bina ve yol güvenliği için iksa/şev emniyeti alınmalıdır.');

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 12. PARKE / LAMİNAT HESAPLAYICI
  // ═══════════════════════════════════════════════════════════
  static bool _isParkeHesabi(String norm) {
    final keywords = ['parke', 'laminat', 'silte', 'şilte', 'kapron', 'supurgelik', 'süpürgelik'];
    return keywords.any((k) => norm.contains(k)) && RegExp(r'\d+').hasMatch(norm);
  }

  static String _hesaplaParke(String original, String norm) {
    double? alan = _extractAlan(original, norm);

    if (alan == null) {
      final dim = _extractDimensions(original);
      if (dim.length >= 2) alan = dim[0] * dim[1];
    }

    if (alan == null || alan <= 0) {
      return '🪵 **Laminat Parke Metrajı İçin Bilgi Gerekli:**\n\n'
          'Lütfen kaplanacak alanı (m²) belirtin.\n'
          'Örnek: *"90 m2 daireye laminat parke döşeyeceğiz, kaç paket parke ve süpürgelik gider?"*';
    }

    // %7 fire payı
    final double toplamParkeM2 = alan * 1.07;
    // 1 paket laminat parke standart ~2.13 m² (8mm derzsiz/derzli)
    const double paketM2 = 2.13;
    final int paketSayisi = (toplamParkeM2 / paketM2).ceil();

    // Şilte / Kapron: alan * 1.05
    final double silteM2 = alan * 1.05;

    // Süpürgelik: Ortalama m²'nin ~0.8 katı kadar mt tül çevre gerekir
    final double supurgelikMetre = alan * 0.85;
    final int supurgelikBoy = (supurgelikMetre / 2.8).ceil(); // 1 boy süpürgelik 2.80 mt

    final double parkeBirimM2 = 320.0; // 8mm AC4 laminat
    final double parkeTutari = toplamParkeM2 * parkeBirimM2;
    final double silteTutari = silteM2 * 25.0;
    final double supurgelikTutari = supurgelikBoy * 110.0;
    final double toplamMaliyet = parkeTutari + silteTutari + supurgelikTutari;

    final buffer = StringBuffer();
    buffer.writeln('🪵 **ŞPD AI - Laminat Parke & Süpürgelik Raporu**');
    buffer.writeln('────────────────────────────');
    buffer.writeln('📐 **Net Zemin Alanı:** ${_f(alan)} m²');
    buffer.writeln('⚠️ **Önerilen Fire Payı (%7):** +${_f(toplamParkeM2 - alan)} m²');
    buffer.writeln('📦 **Sipariş Parke:** **${_f(toplamParkeM2)} m²** (~**$paketSayisi Paket** [2.13 m²/paket])');
    buffer.writeln('');
    buffer.writeln('🧶 **Yalıtım Şiltesi & Aksesuarlar:**');
    buffer.writeln('• **Kapron / Taban Şiltesi (3-5 mm):** ~**${_f(silteM2)} m²**');
    buffer.writeln('• **Süpürgelik:** ~**$supurgelikBoy Boy** (2.80 mt) — Toplam ${_f(supurgelikMetre)} mt');
    buffer.writeln('• **Kapı Geçiş Profili:** Oda sayısı kadar kot/geçiş profili');
    buffer.writeln('');
    buffer.writeln('💰 **Tahmini Malzeme Maliyeti:**');
    buffer.writeln('• **Laminat Parke (${_f(toplamParkeM2)} m² x ${_para(parkeBirimM2)}):** ${_para(parkeTutari)}');
    buffer.writeln('• **Şilte / Kapron:** ${_para(silteTutari)}');
    buffer.writeln('• **Süpürgelik ($supurgelikBoy boy):** ${_para(supurgelikTutari)}');
    buffer.writeln('• **Toplam Malzeme Maliyeti:** **${_para(toplamMaliyet)}**');

    return buffer.toString();
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
        'Bana şantiyedeki ölçüleri doğrudan yazın; anında fire payları, paket/kutu/mikser sayıları ve yaklaşık piyasa maliyeti listesini dökeyim:\n\n'
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
        '_⚡ Bu hesaplamalar tamamen yerel mühendislik formülleriyle çalışır, kotanızdan düşmez ve anında yanıtlanır!_';
  }

  // ═══════════════════════════════════════════════════════════
  // PARSER YARDIMCILARI
  // ═══════════════════════════════════════════════════════════
  static double? _extractAlan(String original, String norm) {
    // 350 m2, 350 m², 350 metrekare, 350 metre kare
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
    // 15 cm, 15 santim, 15 santimetre
    final cmMatch = RegExp(r'(\d+[\.,]?\d*)\s*(cm|santim|santimetre)', caseSensitive: false).firstMatch(original);
    if (cmMatch != null) {
      return double.tryParse(cmMatch.group(1)!.replaceAll(',', '.'));
    }
    // 0.15 m, 0,15 metre
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
