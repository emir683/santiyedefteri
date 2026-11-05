// lib/data/saha_katalog_verileri.dart

/// Şantiye saha operasyonları için zengin, Türkiye mevzuatına ve standartlarına uygun
/// hazır malzeme, iş makinesi / ekipman ve İSG/KKD katalog tanımları.
class SahaKatalogItem {
  final String ad;
  final String kategori;
  final String? standartKodu; // Örn: EN 397, EN ISO 20345 S3, B420C, C30/37
  final String varsayilanBirim;
  final String? aciklama;

  const SahaKatalogItem({
    required this.ad,
    required this.kategori,
    this.standartKodu,
    required this.varsayilanBirim,
    this.aciklama,
  });
}

class SahaKatalogVerileri {
  // ──────────────────────────────────────────────────────────────────────────
  // 1. İŞ MAKİNESİ & EKİPMAN / ZİMMET KATALOGU
  // ──────────────────────────────────────────────────────────────────────────
  static const List<SahaKatalogItem> isMakineleriVeEkipmanlar = [
    // Ağır İş Makineleri
    SahaKatalogItem(
      ad: 'Paletli Ekskavatör (20-35 Ton)',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Temel kazı, kırım ve hafriyat yükleme',
    ),
    SahaKatalogItem(
      ad: 'Lastikli Ekskavatör',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Kanal kazısı ve çevre düzenleme',
    ),
    SahaKatalogItem(
      ad: 'Bekoloder (JCB / Kepçe)',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Kanal kazıcı ve ön yükleyici',
    ),
    SahaKatalogItem(
      ad: 'Dozer (D6 / D8 Sınıfı)',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Zemin tesviye ve küreme',
    ),
    SahaKatalogItem(
      ad: 'Greyder',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Yol ve zemin eğim tesviyesi',
    ),
    SahaKatalogItem(
      ad: 'Toprak / Asfalt Silindiri',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Zemin sıkıştırma ve kompaktaj',
    ),
    SahaKatalogItem(
      ad: 'Mini Yükleyici (Bobcat)',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Dar alan hafriyat ve malzeme taşıma',
    ),
    SahaKatalogItem(
      ad: 'Teleskopik Yükleyici (Manitou)',
      kategori: 'Ağır İş Makineleri',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Yüksek katlara paletli malzeme verme',
    ),

    // Kaldırma ve Taşıma Ekipmanları
    SahaKatalogItem(
      ad: 'Kule Vinç',
      kategori: 'Kaldırma & Taşıma',
      varsayilanBirim: 'Gün / Ay',
      aciklama: 'Yüksek yapı malzeme nakli ve kalıp taşıma',
    ),
    SahaKatalogItem(
      ad: 'Mobil Vinç (Hiyap)',
      kategori: 'Kaldırma & Taşıma',
      varsayilanBirim: 'Saat / Sefer',
      aciklama: 'Ağır parça montajı ve sevkiyat indirme',
    ),
    SahaKatalogItem(
      ad: 'Forklift (Dizel / Akülü)',
      kategori: 'Kaldırma & Taşıma',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Şantiye içi palet ve kasa taşıma',
    ),
    SahaKatalogItem(
      ad: 'Yük Asansörü (Gırgır Vinç)',
      kategori: 'Kaldırma & Taşıma',
      varsayilanBirim: 'Adet / Takım',
      aciklama: 'Katlara harç, tuğla ve malzeme çekme',
    ),
    SahaKatalogItem(
      ad: 'Alüminyum Hareketli İskele Platformu',
      kategori: 'Kaldırma & Taşıma',
      varsayilanBirim: 'Modül / Takım',
      aciklama: 'Tavan ve mekanik tesisat montaj platformu',
    ),

    // Enerji ve Tesisat Ekipmanları
    SahaKatalogItem(
      ad: 'Dizel Jeneratör (50-250 kVA)',
      kategori: 'Saha Enerji & Tesisat',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Şantiye elektrik kesintisi yedek güç kaynağı',
    ),
    SahaKatalogItem(
      ad: 'Vidalı Hava Kompresörü',
      kategori: 'Saha Enerji & Tesisat',
      varsayilanBirim: 'Çalışma Saati',
      aciklama: 'Pnömatik tabanca ve püskürtme besleme',
    ),
    SahaKatalogItem(
      ad: 'Dalgıç Su Tahliye Pompası',
      kategori: 'Saha Enerji & Tesisat',
      varsayilanBirim: 'Adet',
      aciklama: 'Temel ve asansör kuyusu su tahliyesi',
    ),
    SahaKatalogItem(
      ad: 'Dizel Su Motoru (Motopomp)',
      kategori: 'Saha Enerji & Tesisat',
      varsayilanBirim: 'Adet',
      aciklama: 'Yüksek debili saha suyu tahliyesi',
    ),

    // Elektrikli ve Mekanik El Aletleri (Zimmet)
    SahaKatalogItem(
      ad: 'Ağır Kırıcı-Delici (Hilti SDS-Max)',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Beton kırım ve delik açma ekipmanı',
    ),
    SahaKatalogItem(
      ad: 'Darbeli Matkap & Akülü Vidalama',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Kalıp, alçıpan ve montaj vidalama',
    ),
    SahaKatalogItem(
      ad: 'Demir Bükme & Kesme Makinesi',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Takım',
      aciklama: 'Şantiye demir atölyesi işleme tezgahı',
    ),
    SahaKatalogItem(
      ad: 'Profil Taşlama Makinesi (Büyük Spiral)',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Demir, sac ve profil kesme aleti',
    ),
    SahaKatalogItem(
      ad: 'Perdah Makinesi (Helikopter / Şap)',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Saha betonu ve şap düzeltme',
    ),
    SahaKatalogItem(
      ad: 'Kompaktör (Tabla / Zıpzıp)',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Temel altı ve dolgu sıkıştırma aleti',
    ),
    SahaKatalogItem(
      ad: 'İnverter Çanta Kaynak Makinesi',
      kategori: 'Elektrikli El Aletleri',
      varsayilanBirim: 'Adet',
      aciklama: 'Şantiye çelik yapı ve ankraj kaynağı',
    ),
    SahaKatalogItem(
      ad: 'Optik Nivo & Lazer Hizalama Metresi',
      kategori: 'Ölçüm Ekipmanları',
      varsayilanBirim: 'Takım',
      aciklama: 'Kot, terazi ve aks hizalama ölçüm aleti',
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // 2. İSG / KKD ZİMMETİ & SAHA DENETİMİ (6331 İSG KANUNU & MEVZUAT UYUMLU)
  // ──────────────────────────────────────────────────────────────────────────
  static const List<SahaKatalogItem> isgVeKkdKatalogu = [
    // Baş ve Yüz Koruma
    SahaKatalogItem(
      ad: 'Mühendis / İşçi Bareti (Çene Bantlı)',
      kategori: 'Baş ve Yüz Koruma',
      standartKodu: 'EN 397',
      varsayilanBirim: 'Adet',
      aciklama: 'Darbe emici, UV dayanımlı, ayarlanabilir çene bantlı baret',
    ),
    SahaKatalogItem(
      ad: 'Vizörlü Elektrikçi Bareti (1000V Yalıtımlı)',
      kategori: 'Baş ve Yüz Koruma',
      standartKodu: 'EN 397 / EN 50365',
      varsayilanBirim: 'Adet',
      aciklama: 'Elektrik arkı ve kıvılcım korumalı entegre siperlikli',
    ),
    SahaKatalogItem(
      ad: 'Darbeye Dayanıklı Koruyucu İş Gözlüğü',
      kategori: 'Baş ve Yüz Koruma',
      standartKodu: 'EN 166 1F',
      varsayilanBirim: 'Adet',
      aciklama: 'Çizilmez, buğu yapmaz polikarbonat iş gözlüğü',
    ),
    SahaKatalogItem(
      ad: 'Taşlama / Çapak Yüz Koruma Siperliği',
      kategori: 'Baş ve Yüz Koruma',
      standartKodu: 'EN 166 1B',
      varsayilanBirim: 'Adet',
      aciklama: 'Spiral taşlama ve kırım için şeffaf polikarbon yüz kalkanı',
    ),
    SahaKatalogItem(
      ad: 'Otomatik Kararan Kaynakçı Başlığı',
      kategori: 'Baş ve Yüz Koruma',
      standartKodu: 'EN 175 / EN 379',
      varsayilanBirim: 'Adet',
      aciklama: 'Kaynak ışını ve radyasyona karşı otomatik kararan kask',
    ),

    // Ayak Koruma
    SahaKatalogItem(
      ad: 'Çelik Burunlu ve Çelik Tabanlı İş Ayakkabısı',
      kategori: 'Ayak Koruma',
      standartKodu: 'EN ISO 20345 S3 SRC',
      varsayilanBirim: 'Çift',
      aciklama: '200J çelik burun, çivi batmaz çelik ara taban, suya dirençli deri',
    ),
    SahaKatalogItem(
      ad: 'Kompozit Burunlu Hafif Yazlık İş Ayakkabısı',
      kategori: 'Ayak Koruma',
      standartKodu: 'EN ISO 20345 S1P SRC',
      varsayilanBirim: 'Çift',
      aciklama: 'Metal içermeyen kompozit burunlu, kevlar ara tabanlı ayakkabı',
    ),
    SahaKatalogItem(
      ad: 'Çelik Burunlu ve Tabanlı Şantiye Çizmesi',
      kategori: 'Ayak Koruma',
      standartKodu: 'EN ISO 20345 S5 SRC',
      varsayilanBirim: 'Çift',
      aciklama: 'Sulu zemin, beton dökümü ve çamur için PVC iş çizmesi',
    ),

    // Yüksekte Çalışma ve Düşüş Durdurma
    SahaKatalogItem(
      ad: 'Paraşüt Tipi Emniyet Kemeri (Bel Destekli)',
      kategori: 'Yüksekte Çalışma',
      standartKodu: 'EN 361 / EN 358',
      varsayilanBirim: 'Adet',
      aciklama: 'Göğüs ve sırt D halkalı, ergonomik bel takviyeli tam gövde kemeri',
    ),
    SahaKatalogItem(
      ad: 'Şok Emicili Çift Kollu Lanyard (Halat)',
      kategori: 'Yüksekte Çalışma',
      standartKodu: 'EN 355',
      varsayilanBirim: 'Adet',
      aciklama: 'Büyük iskele kancalı (karabina), şok absorbe edici lanyard',
    ),
    SahaKatalogItem(
      ad: 'Geri Sarımlı Düşüş Durdurucu Makara',
      kategori: 'Yüksekte Çalışma',
      standartKodu: 'EN 360',
      varsayilanBirim: 'Adet',
      aciklama: 'Çelik halatlı, ani kilitlenen otomatik geri sarımlı sistem',
    ),
    SahaKatalogItem(
      ad: 'Dikey Yaşam Hattı Halat Tutucu (Kobra)',
      kategori: 'Yüksekte Çalışma',
      standartKodu: 'EN 353-2',
      varsayilanBirim: 'Adet',
      aciklama: 'Dikey tırmanış emniyet halatı kayar kilit aparatı',
    ),

    // Görünürlük ve Vücut Koruma
    SahaKatalogItem(
      ad: 'Reflektif Yüksek Görünürlüklü İkaz Yeleği',
      kategori: 'Vücut & Görünürlük',
      standartKodu: 'EN ISO 20471 Sınıf 2',
      varsayilanBirim: 'Adet',
      aciklama: 'Fosforlu sarı/turuncu, çift reflektif şeritli iş yeleği',
    ),
    SahaKatalogItem(
      ad: 'Reflektif Kışlık Şantiye Parkası / Montu',
      kategori: 'Vücut & Görünürlük',
      standartKodu: 'EN 343 / EN ISO 20471',
      varsayilanBirim: 'Adet',
      aciklama: 'Su ve rüzgar geçirmez kapitone astarlı reflektif kaban',
    ),
    SahaKatalogItem(
      ad: 'Deri Kaynakçı Önlüğü & Kolluğu',
      kategori: 'Vücut & Görünürlük',
      standartKodu: 'EN ISO 11611 Sınıf 2',
      varsayilanBirim: 'Takım',
      aciklama: 'Cüruf ve kıvılcım sıçramasına dayanıklı sığır yarma deri',
    ),

    // El ve Kol Koruma
    SahaKatalogItem(
      ad: 'Mekanik Risk ve Montaj İş Eldiveni',
      kategori: 'El & Kol Koruma',
      standartKodu: 'EN 388 (4131X)',
      varsayilanBirim: 'Çift',
      aciklama: 'Poliüretan kaplı, hassas kavrama ve aşınma dirençli eldiven',
    ),
    SahaKatalogItem(
      ad: 'Ağır Hizmet Deri Kaynakçı Eldiveni',
      kategori: 'El & Kol Koruma',
      standartKodu: 'EN 388 / EN 407 / EN 12477',
      varsayilanBirim: 'Çift',
      aciklama: 'Yüksek ısı ve ergimiş metal sıçramasına dayanıklı uzun konçlu',
    ),
    SahaKatalogItem(
      ad: 'Seviye 5 Kesilmez Güvenlik Eldiveni',
      kategori: 'El & Kol Koruma',
      standartKodu: 'EN 388:2016 (4X43D)',
      varsayilanBirim: 'Çift',
      aciklama: 'Cam, sac ve keskin kenarlı demir işleri için kesilmez dokuma',
    ),

    // İşitme ve Solunum Koruma
    SahaKatalogItem(
      ad: 'Ventilli FFP2 / FFP3 Toz ve Sis Maskesi',
      kategori: 'Solunum Koruma',
      standartKodu: 'EN 149:2001+A1:2009',
      varsayilanBirim: 'Kutu / Adet',
      aciklama: 'Beton tozu, kırım ve silika tozlarına karşı ventilli solunum maskesi',
    ),
    SahaKatalogItem(
      ad: 'Manşonlu Baret Uyumlu Kulaklık',
      kategori: 'İşitme Koruma',
      standartKodu: 'EN 352-3 (SNR 28dB)',
      varsayilanBirim: 'Adet',
      aciklama: 'Şantiye baretine takılabilir yüksek gürültü kesici kulaklık',
    ),
    SahaKatalogItem(
      ad: 'Kordonlu Silikon Kulak Tıkacı',
      kategori: 'İşitme Koruma',
      standartKodu: 'EN 352-2 (SNR 32dB)',
      varsayilanBirim: 'Kutu / Çift',
      aciklama: 'Yıkanabilir, ipli ergonomik gürültü önleyici kulak tıkacı',
    ),

    // İSG Periyodik Denetimleri & Tutanaklar
    SahaKatalogItem(
      ad: 'Dış Cephe İskele Güvenlik Kontrolü (Yeşil Etiket)',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: 'TS EN 12810 / TS EN 12811',
      varsayilanBirim: 'Tutanak / Rapor',
      aciklama: 'Ankraj, topuk tahtası, çift sıra korkuluk ve çapraz bağlantı denetimi',
    ),
    SahaKatalogItem(
      ad: 'Ana Pano & Kaçak Akım Rölesi (30mA) Kontrolü',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: 'İş Ekipmanları Yönetmeliği',
      varsayilanBirim: 'Tutanak / Test',
      aciklama: 'Hayat koruma (30mA) ve yangın koruma (300mA) röle açma testi',
    ),
    SahaKatalogItem(
      ad: '6 Kg KKT Yangın Söndürme Tüpü Kontrolü',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: 'Binaların Yangından Korunması Yön.',
      varsayilanBirim: 'Adet / Tutanak',
      aciklama: 'Basınç manometresi, mühür, piktogram ve son dolum tarihi kontrolü',
    ),
    SahaKatalogItem(
      ad: 'Derin Kazı, İksa ve Şev Güvenlik Kontrolü',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: 'Yapı İşlerinde İSG Yönetmeliği',
      varsayilanBirim: 'Rapor / Tutanak',
      aciklama: 'Çatlak izleme, iksa perdesi, drenaj ve zemin hareket kontrolü',
    ),
    SahaKatalogItem(
      ad: 'Kat Kenarları ve Asansör Boşlukları Korkuluk Denetimi',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: 'Yapı İşlerinde İSG Yönetmeliği',
      varsayilanBirim: 'Denetim Tutanağı',
      aciklama: 'En az 100cm üst korkuluk, 50cm ara korkuluk ve 15cm topukluk kontrolü',
    ),
    SahaKatalogItem(
      ad: 'İSG Toolbox (İşe Başlama Güvenlik Konuşması) Eğitimi',
      kategori: 'Saha İSG Denetimleri',
      standartKodu: '6331 Sayılı Kanun Mad. 17',
      varsayilanBirim: 'Katılım Tutanağı',
      aciklama: 'Günlük riskler, yüksekte çalışma ve KKD kullanımı saha eğitimi',
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // 3. MALZEME & İRSALİYE KATALOGU
  // ──────────────────────────────────────────────────────────────────────────
  static const List<SahaKatalogItem> malzemeKatalogu = [
    // Kaba Yapı Malzemeleri
    SahaKatalogItem(
      ad: 'Hazır Beton C25/30 (Pompalı)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 206',
      varsayilanBirim: 'm³',
      aciklama: 'Taşıyıcı sistem, perde ve döşeme hazır betonu',
    ),
    SahaKatalogItem(
      ad: 'Hazır Beton C30/37 (Pompalı)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 206',
      varsayilanBirim: 'm³',
      aciklama: 'Yüksek dayanımlı kolon, perde ve radye temel betonu',
    ),
    SahaKatalogItem(
      ad: 'Hazır Beton C35/45 (Pompalı)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 206',
      varsayilanBirim: 'm³',
      aciklama: 'Özel mühendislik yapıları ve zemin güçlendirme betonu',
    ),
    SahaKatalogItem(
      ad: 'Grobeton C16/20',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 206',
      varsayilanBirim: 'm³',
      aciklama: 'Temel altı tesviye ve koruma betonu',
    ),
    SahaKatalogItem(
      ad: 'Nervürlü İnşaat Demiri Ø8 - Ø12',
      kategori: 'Kaba Yapı',
      standartKodu: 'B420C / B500C (TS 708)',
      varsayilanBirim: 'Ton',
      aciklama: 'Döşeme donatısı, etriye ve çiroz demiri',
    ),
    SahaKatalogItem(
      ad: 'Nervürlü İnşaat Demiri Ø14 - Ø25',
      kategori: 'Kaba Yapı',
      standartKodu: 'B420C / B500C (TS 708)',
      varsayilanBirim: 'Ton',
      aciklama: 'Kolon, kiriş ve radye temel ana boy donatısı',
    ),
    SahaKatalogItem(
      ad: 'Çelik Hasır (Q131 / Q188 / Q221)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS 4559',
      varsayilanBirim: 'Adet / Plaka',
      aciklama: 'Saha betonu, hasır döşeme ve perde donatısı',
    ),
    SahaKatalogItem(
      ad: 'Portland Çimento (CEM I / CEM II 42.5 R)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 197-1',
      varsayilanBirim: 'Torba (50 kg)',
      aciklama: 'Şantiye harç, tamirat ve kalıp montaj çimentosu',
    ),
    SahaKatalogItem(
      ad: '13.5\'luk Yatay Delikli Tuğla',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 771-1',
      varsayilanBirim: 'Adet',
      aciklama: 'İç bölme duvar blok elemanı',
    ),
    SahaKatalogItem(
      ad: '19\'luk Yatay Delikli Tuğla',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 771-1',
      varsayilanBirim: 'Adet',
      aciklama: 'Dış çevre ve yangın korunum duvarı',
    ),
    SahaKatalogItem(
      ad: 'Gazbeton Duvar Blok (Ytong 10/15/20 cm)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 771-4',
      varsayilanBirim: 'Palet / m³',
      aciklama: 'Hafif, ısı yalıtımlı iç ve dış duvar örme bloğu',
    ),
    SahaKatalogItem(
      ad: '0-3 mm Şap ve Sıva Kumu',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 12620',
      varsayilanBirim: 'm³ / Ton',
      aciklama: 'Şap betonu ve kara sıva agregası',
    ),
    SahaKatalogItem(
      ad: '1-2 No Kırmataş Mıcır (Agrega)',
      kategori: 'Kaba Yapı',
      standartKodu: 'TS EN 12620',
      varsayilanBirim: 'Ton',
      aciklama: 'Drenaj, temel altı balast ve beton agregası',
    ),

    // Kalıp, Kereste ve İskele
    SahaKatalogItem(
      ad: '5x10 İnşaatlık Çam Kereste',
      kategori: 'Kalıp & İskele',
      varsayilanBirim: 'm³',
      aciklama: 'Kalıp ızgarası, payanda ve kanat destek kerestesi',
    ),
    SahaKatalogItem(
      ad: '10x10 Kalas / Dikme Kereste',
      kategori: 'Kalıp & İskele',
      varsayilanBirim: 'm³',
      aciklama: 'Ağır yük taşıyıcı mahya ve döşeme dikmesi',
    ),
    SahaKatalogItem(
      ad: 'Plywood Film Kaplı Su Kontraplağı (18mm / 21mm)',
      kategori: 'Kalıp & İskele',
      standartKodu: 'Huş (Birch) / Çam',
      varsayilanBirim: 'Plaka (250x125cm)',
      aciklama: 'Pürüzsüz brüt beton döşeme ve perde kalıp yüzeyi',
    ),
    SahaKatalogItem(
      ad: 'H20 Ahşap Kalıp Kirişi',
      kategori: 'Kalıp & İskele',
      standartKodu: 'EN 13377',
      varsayilanBirim: 'Metre / Adet',
      aciklama: 'Yüksek taşıma kapasiteli kalıp ana ve tali kirişi',
    ),
    SahaKatalogItem(
      ad: 'Teleskopik Çelik Kalıp Dikmesi (3.00m - 3.50m)',
      kategori: 'Kalıp & İskele',
      standartKodu: 'TS EN 1065',
      varsayilanBirim: 'Adet',
      aciklama: 'Ağır yük ayarlı döşeme altı destek direği',
    ),
    SahaKatalogItem(
      ad: 'Çiroz (Kalıp Kilidi) & Tayrot Mili Takımı',
      kategori: 'Kalıp & İskele',
      varsayilanBirim: 'Takım / Çuval',
      aciklama: 'Perde ve kolon kalıplarını birbirine bağlayan gergi elemanı',
    ),
    SahaKatalogItem(
      ad: 'Dış Cephe Flanşlı Güvenlikli İskele',
      kategori: 'Kalıp & İskele',
      standartKodu: 'TS EN 12810-1',
      varsayilanBirim: 'Takım / m²',
      aciklama: 'Korumalı, merdivenli tip onaylı şantiye dış cephe iskelesi',
    ),

    // Yalıtım & Kimyasallar
    SahaKatalogItem(
      ad: '4mm Arduvazlı / Mineral Su Yalıtım Membranı',
      kategori: 'Yalıtım & Kimyasallar',
      standartKodu: 'TS EN 13707',
      varsayilanBirim: 'Rulo (10 m²)',
      aciklama: 'Temel bohçalama ve çatı su yalıtım bitümlü örtüsü',
    ),
    SahaKatalogItem(
      ad: 'Likit Membran / Sürme İzolasyon',
      kategori: 'Yalıtım & Kimyasallar',
      varsayilanBirim: 'Teneke (20 kg)',
      aciklama: 'Islak hacim, balkon ve perde beton su izolasyonu',
    ),
    SahaKatalogItem(
      ad: '5cm / 8cm Taşyünü Mantolama Levhası',
      kategori: 'Yalıtım & Kimyasallar',
      standartKodu: 'TS EN 13162 (A1 Yangın)',
      varsayilanBirim: 'Paket / m²',
      aciklama: 'A1 yanmaz sınıfı dış cephe ısı ve ses yalıtım levhası',
    ),
    SahaKatalogItem(
      ad: 'EPS / Karbonlu Isı Yalıtım Levhası',
      kategori: 'Yalıtım & Kimyasallar',
      standartKodu: 'TS EN 13163',
      varsayilanBirim: 'Paket / m²',
      aciklama: 'Dış cephe ısı mantolama paketi',
    ),
    SahaKatalogItem(
      ad: 'Kalıp Ayırıcı Yağ',
      kategori: 'Yalıtım & Kimyasallar',
      varsayilanBirim: 'Varil (200 L) / Bidon',
      aciklama: 'Plywood ve çelik kalıpların betona yapışmasını önleyici yağ',
    ),
    SahaKatalogItem(
      ad: 'Grout / Ankraj ve Tamir Harcı',
      kategori: 'Yalıtım & Kimyasallar',
      standartKodu: 'EN 1504-3',
      varsayilanBirim: 'Torba (25 kg)',
      aciklama: 'Rötresiz, yüksek mukavemetli makine taban ve kolon altı dolgusu',
    ),

    // İnce Yapı ve Tesisat
    SahaKatalogItem(
      ad: '12.5mm Standart Beyaz Alçıpan',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS EN 520',
      varsayilanBirim: 'Plaka (1.20x2.50m)',
      aciklama: 'Asma tavan ve iç bölme duvar alçı levhası',
    ),
    SahaKatalogItem(
      ad: '12.5mm Suya Dayanıklı Yeşil Alçıpan',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS EN 520 (Tip H)',
      varsayilanBirim: 'Plaka (1.20x2.50m)',
      aciklama: 'Banyo, wc ve nemli ortamlar için neme dayanıklı plaka',
    ),
    SahaKatalogItem(
      ad: 'Saten ve Perlitli Sıva Alçısı',
      kategori: 'İnce Yapı & Tesisat',
      varsayilanBirim: 'Torba (30 kg)',
      aciklama: 'İç mekan duvar düzeltme ve boya öncesi perdah sıvası',
    ),
    SahaKatalogItem(
      ad: 'Fayans & Seramik Yapıştırıcısı (C2TE S1)',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS EN 12004',
      varsayilanBirim: 'Torba (25 kg)',
      aciklama: 'Esnek, yüksek tutunma mukavemetli seramik harcı',
    ),
    SahaKatalogItem(
      ad: 'PPRC Ø20 - Ø32 Temiz Su Borusu',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS 9937',
      varsayilanBirim: 'Metre / Boy',
      aciklama: 'Sıcak ve soğuk sıhhi tesisat borusu',
    ),
    SahaKatalogItem(
      ad: 'PVC Ø50 - Ø100 Atık Su / Gider Borusu',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS 275-1',
      varsayilanBirim: 'Metre / Boy',
      aciklama: 'Bina içi pis su ve yağmur iniş borusu',
    ),
    SahaKatalogItem(
      ad: '3x2.5mm² NYM Antigron Elektrik Kablosu',
      kategori: 'İnce Yapı & Tesisat',
      standartKodu: 'TS HD 21.4 S2',
      varsayilanBirim: 'Metre / Rulo',
      aciklama: 'Şantiye ve daire içi priz besleme kablosu',
    ),
  ];
}

