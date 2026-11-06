import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../tema_ayarlari.dart';

/// Uygulamadaki 4 ana kullanıcı rolü
class KullaniciRolu {
  static const String muteahhit = 'muteahhit';
  static const String santiyeSefi = 'santiye_sefi';
  static const String taseronKalfa = 'taseron_kalfa';
  static const String isciUsta = 'isci_usta';

  static const List<Map<String, dynamic>> tumRoller = [
    {
      'id': muteahhit,
      'baslik': 'Müteahhit / Şirket Sahibi',
      'altBaslik': 'Şantiye yönetimi, taşeron/usta ilanı ve kurumsal ekip takibi',
      'ikon': Icons.domain_rounded,
      'renk': Color(0xFF0F7C86),
    },
    {
      'id': santiyeSefi,
      'baslik': 'Şantiye Şefi / Mühendis / Mimar',
      'altBaslik': 'Saha koordinasyonu, ekip puantajı, CAD proje ve günlük rapor',
      'ikon': Icons.engineering_rounded,
      'renk': Color(0xFF0E7490),
    },
    {
      'id': taseronKalfa,
      'baslik': 'Taşeron / Ekip Başı / Kalfa',
      'altBaslik': 'Kendi ekibinin puantajı, götürü/metraj iş alma ve ekip vitrini',
      'ikon': Icons.groups_rounded,
      'renk': Color(0xFF0F766E),
    },
    {
      'id': isciUsta,
      'baslik': 'Usta / İşçi / Operatör',
      'altBaslik': 'Kişisel yevmiye & mesai defteri, iş ilanları ve usta kartviziti',
      'ikon': Icons.handyman_rounded,
      'renk': Color(0xFFD97706),
    },
  ];

  static String rolBasligi(String? rolId) {
    switch (rolId) {
      case muteahhit:
        return 'Müteahhit / Şirket';
      case santiyeSefi:
        return 'Şantiye Şefi / Mühendis';
      case taseronKalfa:
        return 'Taşeron / Ekip Başı';
      case isciUsta:
        return 'Usta / İşçi';
      default:
        return 'Belirtilmedi';
    }
  }

  static IconData rolIkonu(String? rolId) {
    switch (rolId) {
      case muteahhit:
        return Icons.domain_rounded;
      case santiyeSefi:
        return Icons.engineering_rounded;
      case taseronKalfa:
        return Icons.groups_rounded;
      case isciUsta:
        return Icons.handyman_rounded;
      default:
        return Icons.badge_outlined;
    }
  }

  /// Seçilen role göre "Ne iş yapıyor / Hangi branşta?" seçenekleri
  static List<String> bransSecenekleri(String rolId) {
    switch (rolId) {
      case muteahhit:
        return const [
          'Anahtar Teslim Konut & Yapı',
          'Kaba İnşaat & Betonarme',
          'Kentsel Dönüşüm & Taahhüt',
          'Tadilat, Dekorasyon & İnce İşler',
          'Altyapı, Yol & Hafriyat',
          'Çelik & Endüstriyel Yapı',
          'Yapı Malzemeleri & Tedarik',
        ];
      case santiyeSefi:
        return const [
          'İnşaat Mühendisi',
          'Mimar / İç Mimar',
          'Şantiye Şefi / Saha Koordinatörü',
          'İnşaat Teknikeri / Teknisyeni',
          'Harita / Elektrik / Makine Mühendisi',
          'İSG Uzmanı / Yapı Denetim',
        ];
      case taseronKalfa:
        return const [
          'Kalıp & Demir Ekibi',
          'Duvar, Sıva & Alçı Ekibi',
          'Boya & Dış Cephe Mantolama',
          'Seramik, Fayans & Mermer',
          'Elektrik & Mekanik Tesisat',
          'Çatı, İzolasyon & Su Yalıtımı',
          'Hafriyat, Yıkım & İş Makinesi',
          'Anahtar Teslim İnce İşler',
        ];
      case isciUsta:
      default:
        return const [
          'Kalıp Ustası / Kalıpçı',
          'Demir Ustası / Demirci',
          'Duvar & Sıva Ustası',
          'Alçı, Alçıpan & Boya Ustası',
          'Seramik & Fayans Ustası',
          'Elektrik / Sıhhi Tesisat Ustası',
          'Dış Cephe & İzolasyon Ustası',
          'Kaynakçı / Çelik Montaj Ustası',
          'Kepçe / Vinç / Kamyon Operatörü',
          'Saha Elemanı / Düz İşçi',
        ];
    }
  }

  /// Seçilen role göre "O işte ne görevde ve ne seviyede?" seçenekleri
  static List<String> seviyeSecenekleri(String rolId) {
    switch (rolId) {
      case muteahhit:
        return const [
          'Şirket Sahibi / Müteahhit',
          'Şirket Ortağı / Yönetim',
          'Proje & Taahhüt Yöneticisi',
          'Satınalma & İhale Sorumlusu',
        ];
      case santiyeSefi:
        return const [
          'Proje Müdürü / Baş Şef (10+ Yıl)',
          'Kıdemli Şantiye Şefi (5-10 Yıl)',
          'Saha Şefi / Mühendisi (2-5 Yıl)',
          'Yardımcı Saha Mühendisi / Tekniker',
        ];
      case taseronKalfa:
        return const [
          'Taşeron Firma Sahibi',
          'Baş Kalfa / Ekip Çavuşu',
          'Formen / Ekip Sorumlusu',
          'Götürü Ustası / Ekip Başı',
        ];
      case isciUsta:
      default:
        return const [
          'Baş Usta (10+ Yıl Deneyim)',
          'Usta (Kendi Başına İş Çıkaran)',
          'Kalfa / Kıdemli Usta',
          'Usta Yardımcısı / Kalfa Adayı',
          'Çırak / Yetiştirilmek Üzere',
          'Sertifikalı Operatör',
          'Düz İşçi / Yevmiyeli Çalışan',
        ];
    }
  }

  /// Çalışma şekli / ekip büyüklüğü seçenekleri
  static List<String> kapasiteVeyaCalismaSekliSecenekleri(String rolId) {
    switch (rolId) {
      case muteahhit:
      case santiyeSefi:
        return const [
          '1-3 Aktif Şantiye',
          '4-10 Aktif Şantiye',
          '10+ Büyük Ölçekli Proje',
          'Tekil Proje / Tadilat',
        ];
      case taseronKalfa:
        return const [
          '2 - 5 Kişilik Ekip',
          '6 - 12 Kişilik Ekip',
          '13 - 25 Kişilik Ekip',
          '25+ Kişilik Büyük Ekip',
        ];
      case isciUsta:
      default:
        return const [
          'Günlük Yevmiye Usulü',
          'Metrekare / Götürü Usulü',
          'Aylık Sabit Maaşlı',
          'Yevmiye veya Götürü (Farketmez)',
        ];
    }
  }
}

class KullaniciSahaProfili {
  final String kullaniciTipi; // muteahhit, santiye_sefi, taseron_kalfa, isci_usta
  final String brans; // Ne iş yaptığı / uzmanlık alanı
  final String seviye; // Görevi ve seviyesi
  final String calismaKapasitesi; // Ekip büyüklüğü veya çalışma şekli
  final String sirketAdi; // Müteahhit/Taşeron/Şef için firma adı
  final String sehir;
  final String telefon;
  final String hakkinda;
  final String webSitesi;
  final List<String> fotograflar;
  final double gunlukYevmiyeBeklentisi;
  final bool isAriyorum; // Usta/Taşeron için "İş Arıyorum / Ekibim Boşta"
  final bool ustaAriyorum; // Müteahhit/Şef için "Usta / Taşeron Arıyorum"
  final bool vitrindeGoster; // Şantiye Pazarı rehberinde gösterilsin mi

  const KullaniciSahaProfili({
    this.kullaniciTipi = '',
    this.brans = '',
    this.seviye = '',
    this.calismaKapasitesi = '',
    this.sirketAdi = '',
    this.sehir = 'İstanbul',
    this.telefon = '',
    this.hakkinda = '',
    this.webSitesi = '',
    this.fotograflar = const [],
    this.gunlukYevmiyeBeklentisi = 0,
    this.isAriyorum = false,
    this.ustaAriyorum = false,
    this.vitrindeGoster = true,
  });

  bool get tamamlandiMi =>
      kullaniciTipi.trim().isNotEmpty &&
      brans.trim().isNotEmpty &&
      seviye.trim().isNotEmpty;

  bool get isciVeyaUstaMi => kullaniciTipi == KullaniciRolu.isciUsta;
  bool get muteahhitVeyaYoneticiMi =>
      kullaniciTipi == KullaniciRolu.muteahhit ||
      kullaniciTipi == KullaniciRolu.santiyeSefi ||
      kullaniciTipi == KullaniciRolu.taseronKalfa;

  factory KullaniciSahaProfili.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return const KullaniciSahaProfili();
    final nested = data['sahaProfili'] is Map
        ? Map<String, dynamic>.from(data['sahaProfili'] as Map)
        : <String, dynamic>{};

    String pickStr(String key, [String fallback = '']) {
      final v1 = (nested[key] ?? data[key])?.toString().trim() ?? '';
      return v1.isNotEmpty ? v1 : fallback;
    }

    return KullaniciSahaProfili(
      kullaniciTipi: pickStr('kullaniciTipi'),
      brans: pickStr('brans'),
      seviye: pickStr('seviye'),
      calismaKapasitesi: pickStr('calismaKapasitesi'),
      sirketAdi: pickStr('sirketAdi'),
      sehir: pickStr('sehir', 'İstanbul'),
      telefon: pickStr('telefon'),
      hakkinda: pickStr('hakkinda'),
      webSitesi: pickStr('webSitesi'),
      fotograflar: List<String>.from(
        (nested['fotograflar'] ?? data['fotograflar']) as List? ?? const [],
      ),
      gunlukYevmiyeBeklentisi:
          ((nested['gunlukYevmiyeBeklentisi'] ?? data['gunlukYevmiyeBeklentisi'] ?? 0)
                  as num)
              .toDouble(),
      isAriyorum: (nested['isAriyorum'] ?? data['isAriyorum']) == true,
      ustaAriyorum: (nested['ustaAriyorum'] ?? data['ustaAriyorum']) == true,
      vitrindeGoster:
          (nested['vitrindeGoster'] ?? data['vitrindeGoster'] ?? true) == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kullaniciTipi': kullaniciTipi,
      'brans': brans,
      'seviye': seviye,
      'calismaKapasitesi': calismaKapasitesi,
      'sirketAdi': sirketAdi,
      'sehir': sehir,
      'telefon': telefon,
      'hakkinda': hakkinda,
      'webSitesi': webSitesi,
      'fotograflar': fotograflar,
      'gunlukYevmiyeBeklentisi': gunlukYevmiyeBeklentisi,
      'isAriyorum': isAriyorum,
      'ustaAriyorum': ustaAriyorum,
      'vitrindeGoster': vitrindeGoster,
      'profilGuncellemeTarihi': FieldValue.serverTimestamp(),
    };
  }
}

/// İnşaat Sektörü Bütün İş Kolları & Branş Kategorileri
class InsaatKategorileri {
  static const List<Map<String, dynamic>> tumu = [
    {
      'id': 'kalip_demir',
      'baslik': 'Kalıp & Demir (Birlikte)',
      'aciklama': 'Kalıp çakımı ve donatı demir bağlama ekibi',
      'ikon': Icons.foundation_rounded,
    },
    {
      'id': 'kalip',
      'baslik': 'Sadece Kalıp',
      'aciklama': 'Ahşap, çelik, tünel veya tırmanır kalıp işçiliği',
      'ikon': Icons.carpenter_rounded,
    },
    {
      'id': 'demir',
      'baslik': 'Sadece Demir',
      'aciklama': 'Temel, perde, kolon donatı bağlama ve büküm',
      'ikon': Icons.hardware_rounded,
    },
    {
      'id': 'duz_isci',
      'baslik': 'Genel Şantiye Düz İşçisi (İşçi Arama)',
      'aciklama': 'Beden işçisi, malzeme taşıma, temizlik ve yevmiyeli saha elemanı',
      'ikon': Icons.person_search_rounded,
    },
    {
      'id': 'kaba_iscilik',
      'baslik': 'Kaba İşçilik & Duvar',
      'aciklama': 'Tuğla, gazbeton, bims duvar örme ve kaba yapı işleri',
      'ikon': Icons.layers_rounded,
    },
    {
      'id': 'siva',
      'baslik': 'Sıva (Kara, Alçı & Makine)',
      'aciklama': 'İç/dış kaba kara sıva, alçı perdah, makine alçı sıvası',
      'ikon': Icons.format_paint_rounded,
    },
    {
      'id': 'ince_iscilik',
      'baslik': 'İnce İşçilik & Boya',
      'aciklama': 'İç/dış boya badana, alçıpan, asma tavan, kartonpiyer',
      'ikon': Icons.brush_rounded,
    },
    {
      'id': 'seramik_fayans',
      'baslik': 'Seramik, Fayans & Granit',
      'aciklama': 'Zemin ve banyo fayans kaplama, mermer, granit döşeme',
      'ikon': Icons.grid_view_rounded,
    },
    {
      'id': 'sap',
      'baslik': 'Şap Dökümü',
      'aciklama': 'Helikopterli şap, tesviye betonu, kuru/yaş düz şap',
      'ikon': Icons.water_damage_rounded,
    },
    {
      'id': 'mantolama_cephe',
      'baslik': 'Dış Cephe Mantolama & Kompozit',
      'aciklama': 'Isı yalıtımı, kompozit panel, silikon/mekanik giydirme cephe',
      'ikon': Icons.domain_rounded,
    },
    {
      'id': 'cati_izolasyon',
      'baslik': 'Çatı, Su & Isı Yalıtımı',
      'aciklama': 'Çatı karkas, membran, şıngıl, temel ve perde su izolasyonu',
      'ikon': Icons.roofing_rounded,
    },
    {
      'id': 'elektrik',
      'baslik': 'Elektrik & Zayıf Akım',
      'aciklama': 'Şantiye elektrik hattı, kablo tavası, aydınlatma, pano',
      'ikon': Icons.electric_bolt_rounded,
    },
    {
      'id': 'mekanik_tesisat',
      'baslik': 'Sıhhi & Mekanik Tesisat',
      'aciklama': 'Temiz/pis su tesisatı, kalorifer, doğalgaz, yangın hattı',
      'ikon': Icons.plumbing_rounded,
    },
    {
      'id': 'celik_kaynak',
      'baslik': 'Çelik Konstrüksiyon & Kaynak',
      'aciklama': 'Ağır/hafif çelik montajı, gazaltı ve elektrik kaynağı',
      'ikon': Icons.precision_manufacturing_rounded,
    },
    {
      'id': 'hafriyat_yikim',
      'baslik': 'Hafriyat, Kazı & Yıkım',
      'aciklama': 'Temel kazısı, moloz nakliyesi, kontrollü bina yıkımı',
      'ikon': Icons.terrain_rounded,
    },
    {
      'id': 'operator',
      'baslik': 'İş Makinesi Operatörü',
      'aciklama': 'Ekskavatör, beko loder, kule vinç, forklift, kamyon şoförü',
      'ikon': Icons.construction_rounded,
    },
    {
      'id': 'peyzaj_cevre',
      'baslik': 'Peyzaj & Çevre Düzenleme',
      'aciklama': 'Kilit taşı, bordür, bahçe duvarı ve saha peyzajı',
      'ikon': Icons.park_rounded,
    },
    {
      'id': 'iskele',
      'baslik': 'İskele Kurulum & Söküm',
      'aciklama': 'Güvenlikli flanşlı dış cephe iskelesi montaj ve kiralama',
      'ikon': Icons.stairs_rounded,
    },
  ];

  static String kategoriAdi(String id) {
    final bul = tumu.firstWhere((e) => e['id'] == id, orElse: () => const {});
    return (bul['baslik'] as String?) ?? id;
  }
}

/// Şantiye Pazarı İlan / Şirket / İş Arıyorum modeli
class SantiyePazarIlani {
  final String id;
  final String olusturanUid;
  final String olusturanAd;
  final String kullaniciTipi;
  final String ilanKategorisi; // 'is_ilani' | 'usta_ekip' | 'normal_isci' | 'sirket_vitrini'
  final String arananSeviye; // 'ekip' | 'usta' | 'normal_isci' | 'operator'
  final String ucretTipi; // 'metrekare' | 'goturu' | 'gunluk' | 'teklife_acik'
  final double ucretTutari;
  final String tahminiMetrajVeyaGun;
  final int ekipKisiSayisi;
  final bool konaklamaVarMi;
  final bool yemekVarMi;
  final String baslik;
  final String brans;
  final String seviye;
  final String sehir;
  final String ilce;
  final String sirketAdi;
  final String kapasiteVeyaUcret;
  final String aciklama;
  final String telefon;
  final DateTime tarih;
  final bool acilMi;

  // Sektörel / Web İlan Standart Alanları
  final String kategoriKodu; // 'kalip_demir', 'kalip', 'demir', 'duz_isci', 'siva', vb.
  final String projeTipi; // 'konut' | 'villa' | 'ticari' | 'fabrika' | 'altyapi' | 'tadilat'
  final String sgkDurumu; // 'sgk_yapilacak' | 'taseron_sozlesmesi' | 'yevmiyeli'
  final bool ulasimServisVarMi;
  final bool isgKkdSaglanacakMi;
  final bool fazlaMesaiVarMi;
  final String aletEkipmanDurumu; // 'santiyeden' | 'ustadan' | 'ortak'
  final String odemePeriyodu; // 'haftalik' | 'onbes_gunluk' | 'aylik' | 'is_bitimi'
  final bool avansImkaniVarMi;
  final String deneyimYili;
  final bool belgeGerekliMi;
  final String baslamaTarihiTipi; // 'hemen' | 'bir_hafta' | 'belirli_tarih'
  final String webSitesi; // İlan sahibinin veya şirketin web sitesi
  final List<String> fotograflar; // İlanın veya referans işlerin fotoğrafları

  // İstatistik & Favori Alanları
  final int goruntulenmeSayisi;
  final int favoriSayisi;
  final List<String> favorileyenUidler;

  // Süre & Premium Alanları
  final int ilanSuresiGun; // 3 (ücretsiz), 7 (1 hafta), 14 (2 hafta), 30 (1 ay)
  final DateTime? bitisTarihi;
  final bool oneCikarildiMi; // Vitrinde öne çıkarılan ilan

  const SantiyePazarIlani({
    required this.id,
    required this.olusturanUid,
    required this.olusturanAd,
    required this.kullaniciTipi,
    required this.ilanKategorisi,
    this.arananSeviye = 'ekip',
    this.ucretTipi = 'gunluk',
    this.ucretTutari = 0,
    this.tahminiMetrajVeyaGun = '',
    this.ekipKisiSayisi = 1,
    this.konaklamaVarMi = false,
    this.yemekVarMi = true,
    required this.baslik,
    required this.brans,
    required this.seviye,
    required this.sehir,
    this.ilce = '',
    this.sirketAdi = '',
    this.kapasiteVeyaUcret = '',
    required this.aciklama,
    this.telefon = '',
    required this.tarih,
    this.acilMi = false,
    this.kategoriKodu = '',
    this.projeTipi = 'konut',
    this.sgkDurumu = 'sgk_yapilacak',
    this.ulasimServisVarMi = false,
    this.isgKkdSaglanacakMi = true,
    this.fazlaMesaiVarMi = false,
    this.aletEkipmanDurumu = 'santiyeden',
    this.odemePeriyodu = 'haftalik',
    this.avansImkaniVarMi = true,
    this.deneyimYili = '',
    this.belgeGerekliMi = false,
    this.baslamaTarihiTipi = 'hemen',
    this.webSitesi = '',
    this.fotograflar = const [],
    this.goruntulenmeSayisi = 0,
    this.favoriSayisi = 0,
    this.favorileyenUidler = const [],
    this.ilanSuresiGun = 3,
    this.bitisTarihi,
    this.oneCikarildiMi = false,
  });

  bool get suresiDolduMu {
    final bitis = bitisTarihi ?? tarih.add(Duration(days: ilanSuresiGun));
    return DateTime.now().isAfter(bitis);
  }

  Duration get kalanSure {
    final bitis = bitisTarihi ?? tarih.add(Duration(days: ilanSuresiGun));
    return bitis.difference(DateTime.now());
  }

  String get kalanSureMetni {
    final sure = kalanSure;
    if (sure.isNegative) return 'Süresi Doldu';
    final gun = sure.inDays;
    final saat = sure.inHours % 24;
    final dakika = sure.inMinutes % 60;
    if (gun > 0) {
      return '$gun gün $saat saat';
    } else if (saat > 0) {
      return '$saat saat $dakika dk';
    } else {
      return '$dakika dakika kaldı';
    }
  }

  static String ucretTipiBasligi(String tip) {
    switch (tip) {
      case 'metrekare':
        return 'm² Hesabı';
      case 'goturu':
        return 'Götürü / Paket';
      case 'gunluk':
        return 'Günlük Yevmiye';
      case 'teklife_acik':
      default:
        return 'Teklife Açık';
    }
  }

  static String arananSeviyeBasligi(String seviyeKod) {
    switch (seviyeKod) {
      case 'ekip':
        return 'Taşeron / Usta Ekibi';
      case 'usta':
        return 'Kıdemli Usta / Kalfa';
      case 'normal_isci':
        return 'Normal İşçi / Yevmiyeci';
      case 'operator':
        return 'Operatör / Şoför';
      default:
        return 'Usta / Ekip';
    }
  }

  static String projeTipiBasligi(String kod) {
    switch (kod) {
      case 'konut':
        return 'Konut / Toplu Konut';
      case 'villa':
        return 'Villa / Müstakil';
      case 'ticari':
        return 'Ticari / AVM / Plaza';
      case 'fabrika':
        return 'Fabrika / Sanayi';
      case 'altyapi':
        return 'Altyapı / Yol / Köprü';
      case 'tadilat':
        return 'Tadilat / Restorasyon';
      default:
        return 'Genel Şantiye';
    }
  }

  static String sgkDurumBasligi(String kod) {
    switch (kod) {
      case 'sgk_yapilacak':
        return 'SGK Girişi Yapılacaktır';
      case 'taseron_sozlesmesi':
        return 'Fatura & Taşeron Sözleşmesi';
      case 'yevmiyeli':
        return 'Serbest / Günlük Yevmiye';
      default:
        return 'Görüşülecek';
    }
  }

  String get ucretEtiketi {
    final tipMetin = ucretTipiBasligi(ucretTipi);
    if (ucretTutari > 0) {
      final tutarStr = ucretTutari.toStringAsFixed(0);
      if (ucretTipi == 'metrekare') {
        return '$tipMetin • $tutarStr ₺/m²';
      } else if (ucretTipi == 'goturu') {
        return '$tipMetin • $tutarStr ₺';
      } else if (ucretTipi == 'gunluk') {
        return '$tipMetin • $tutarStr ₺/Gün';
      }
      return '$tipMetin • $tutarStr ₺';
    }
    if (kapasiteVeyaUcret.trim().isNotEmpty) {
      return '$tipMetin • $kapasiteVeyaUcret';
    }
    return tipMetin;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'olusturanUid': olusturanUid,
      'olusturanAd': olusturanAd,
      'kullaniciTipi': kullaniciTipi,
      'ilanKategorisi': ilanKategorisi,
      'arananSeviye': arananSeviye,
      'ucretTipi': ucretTipi,
      'ucretTutari': ucretTutari,
      'tahminiMetrajVeyaGun': tahminiMetrajVeyaGun,
      'ekipKisiSayisi': ekipKisiSayisi,
      'konaklamaVarMi': konaklamaVarMi,
      'yemekVarMi': yemekVarMi,
      'baslik': baslik,
      'brans': brans,
      'seviye': seviye,
      'sehir': sehir,
      'ilce': ilce,
      'sirketAdi': sirketAdi,
      'kapasiteVeyaUcret': kapasiteVeyaUcret,
      'aciklama': aciklama,
      'telefon': telefon,
      'tarih': Timestamp.fromDate(tarih),
      'acilMi': acilMi,
      'kategoriKodu': kategoriKodu,
      'projeTipi': projeTipi,
      'sgkDurumu': sgkDurumu,
      'ulasimServisVarMi': ulasimServisVarMi,
      'isgKkdSaglanacakMi': isgKkdSaglanacakMi,
      'fazlaMesaiVarMi': fazlaMesaiVarMi,
      'aletEkipmanDurumu': aletEkipmanDurumu,
      'odemePeriyodu': odemePeriyodu,
      'avansImkaniVarMi': avansImkaniVarMi,
      'deneyimYili': deneyimYili,
      'belgeGerekliMi': belgeGerekliMi,
      'baslamaTarihiTipi': baslamaTarihiTipi,
      'webSitesi': webSitesi,
      'fotograflar': fotograflar,
      'goruntulenmeSayisi': goruntulenmeSayisi,
      'favoriSayisi': favoriSayisi,
      'favorileyenUidler': favorileyenUidler,
      'ilanSuresiGun': ilanSuresiGun,
      'bitisTarihi': bitisTarihi != null ? Timestamp.fromDate(bitisTarihi!) : null,
      'oneCikarildiMi': oneCikarildiMi,
    };
  }

  factory SantiyePazarIlani.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['tarih'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final int suresiGun = ((map['ilanSuresiGun'] ?? 3) as num).toInt();
    DateTime? parsedBitis;
    final rawBitis = map['bitisTarihi'];
    if (rawBitis is Timestamp) {
      parsedBitis = rawBitis.toDate();
    } else if (rawBitis is String) {
      parsedBitis = DateTime.tryParse(rawBitis);
    }
    parsedBitis ??= parsedDate.add(Duration(days: suresiGun));

    return SantiyePazarIlani(
      id: (map['id'] ?? '').toString(),
      olusturanUid: (map['olusturanUid'] ?? '').toString(),
      olusturanAd: (map['olusturanAd'] ?? 'Şantiye Üyesi').toString(),
      kullaniciTipi:
          (map['kullaniciTipi'] ?? KullaniciRolu.muteahhit).toString(),
      ilanKategorisi: (map['ilanKategorisi'] ?? 'is_ilani').toString(),
      arananSeviye: (map['arananSeviye'] ?? 'ekip').toString(),
      ucretTipi: (map['ucretTipi'] ?? 'gunluk').toString(),
      ucretTutari: ((map['ucretTutari'] ?? 0) as num).toDouble(),
      tahminiMetrajVeyaGun: (map['tahminiMetrajVeyaGun'] ?? '').toString(),
      ekipKisiSayisi: ((map['ekipKisiSayisi'] ?? 1) as num).toInt(),
      konaklamaVarMi: map['konaklamaVarMi'] == true,
      yemekVarMi: (map['yemekVarMi'] ?? true) == true,
      baslik: (map['baslik'] ?? '').toString(),
      brans: (map['brans'] ?? '').toString(),
      seviye: (map['seviye'] ?? '').toString(),
      sehir: (map['sehir'] ?? 'İstanbul').toString(),
      ilce: (map['ilce'] ?? '').toString(),
      sirketAdi: (map['sirketAdi'] ?? '').toString(),
      kapasiteVeyaUcret: (map['kapasiteVeyaUcret'] ?? '').toString(),
      aciklama: (map['aciklama'] ?? '').toString(),
      telefon: (map['telefon'] ?? '').toString(),
      tarih: parsedDate,
      acilMi: map['acilMi'] == true,
      kategoriKodu: (map['kategoriKodu'] ?? '').toString(),
      projeTipi: (map['projeTipi'] ?? 'konut').toString(),
      sgkDurumu: (map['sgkDurumu'] ?? 'sgk_yapilacak').toString(),
      ulasimServisVarMi: map['ulasimServisVarMi'] == true,
      isgKkdSaglanacakMi: (map['isgKkdSaglanacakMi'] ?? true) == true,
      fazlaMesaiVarMi: map['fazlaMesaiVarMi'] == true,
      aletEkipmanDurumu: (map['aletEkipmanDurumu'] ?? 'santiyeden').toString(),
      odemePeriyodu: (map['odemePeriyodu'] ?? 'haftalik').toString(),
      avansImkaniVarMi: (map['avansImkaniVarMi'] ?? true) == true,
      deneyimYili: (map['deneyimYili'] ?? '').toString(),
      belgeGerekliMi: map['belgeGerekliMi'] == true,
      baslamaTarihiTipi: (map['baslamaTarihiTipi'] ?? 'hemen').toString(),
      webSitesi: (map['webSitesi'] ?? '').toString(),
      fotograflar: List<String>.from(
        map['fotograflar'] as List? ?? const [],
      ),
      goruntulenmeSayisi: ((map['goruntulenmeSayisi'] ?? 0) as num).toInt(),
      favoriSayisi: ((map['favoriSayisi'] ?? 0) as num).toInt(),
      favorileyenUidler: List<String>.from(map['favorileyenUidler'] as List? ?? const []),
      ilanSuresiGun: suresiGun,
      bitisTarihi: parsedBitis,
      oneCikarildiMi: map['oneCikarildiMi'] == true,
    );
  }
}

/// Şantiye Pazarında İlan Sahibi / Ekip Yöneticisi ile Müteahhit Arasındaki İletişim & Anlaşma Teklifi Modeli
class PazarAnlasmaTeklifi {
  final String id;
  final String ilanId;
  final String ilanBaslik;
  final String gonderenUid;
  final String gonderenAd;
  final String gonderenTelefon;
  final String gonderenTeamId;
  final String aliciUid;
  final String aliciAd;
  final String aliciTelefon;
  final String brans;
  final String ekipAdi; // Örn: "Sıvacı Ekibi", "Kalıpçı Ekibi", "Demir Ustası"
  final String santiyeId;
  final String santiyeAdi;
  final String ucretTipi; // 'metrekare' | 'goturu' | 'gunluk'
  final double birimUcret;
  final double tahminiIsMiktari; // m², gün veya 1 paket
  final int ekipKisiSayisi;
  final String durum; // 'bekliyor' | 'karsi_teklif' | 'onaylandi' | 'ekibe_aktarildi' | 'reddedildi'
  final List<Map<String, dynamic>> mesajlar;
  final DateTime guncellenmeTarihi;

  const PazarAnlasmaTeklifi({
    required this.id,
    required this.ilanId,
    required this.ilanBaslik,
    required this.gonderenUid,
    required this.gonderenAd,
    this.gonderenTelefon = '',
    this.gonderenTeamId = '',
    required this.aliciUid,
    required this.aliciAd,
    this.aliciTelefon = '',
    required this.brans,
    required this.ekipAdi,
    this.santiyeId = '',
    this.santiyeAdi = 'Genel Şantiye',
    required this.ucretTipi,
    required this.birimUcret,
    this.tahminiIsMiktari = 1,
    this.ekipKisiSayisi = 1,
    this.durum = 'bekliyor',
    this.mesajlar = const [],
    required this.guncellenmeTarihi,
  });

  double get toplamTahminiTutar {
    if (ucretTipi == 'goturu') return birimUcret;
    return birimUcret * (tahminiIsMiktari <= 0 ? 1 : tahminiIsMiktari);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ilanId': ilanId,
      'ilanBaslik': ilanBaslik,
      'gonderenUid': gonderenUid,
      'gonderenAd': gonderenAd,
      'gonderenTelefon': gonderenTelefon,
      'gonderenTeamId': gonderenTeamId,
      'aliciUid': aliciUid,
      'aliciAd': aliciAd,
      'aliciTelefon': aliciTelefon,
      'brans': brans,
      'ekipAdi': ekipAdi,
      'santiyeId': santiyeId,
      'santiyeAdi': santiyeAdi,
      'ucretTipi': ucretTipi,
      'birimUcret': birimUcret,
      'tahminiIsMiktari': tahminiIsMiktari,
      'ekipKisiSayisi': ekipKisiSayisi,
      'durum': durum,
      'mesajlar': mesajlar,
      'guncellenmeTarihi': Timestamp.fromDate(guncellenmeTarihi),
    };
  }

  factory PazarAnlasmaTeklifi.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['guncellenmeTarihi'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    final rawMsgs = map['mesajlar'] as List<dynamic>? ?? const [];
    return PazarAnlasmaTeklifi(
      id: (map['id'] ?? '').toString(),
      ilanId: (map['ilanId'] ?? '').toString(),
      ilanBaslik: (map['ilanBaslik'] ?? '').toString(),
      gonderenUid: (map['gonderenUid'] ?? '').toString(),
      gonderenAd: (map['gonderenAd'] ?? '').toString(),
      gonderenTelefon: (map['gonderenTelefon'] ?? '').toString(),
      gonderenTeamId: (map['gonderenTeamId'] ?? '').toString(),
      aliciUid: (map['aliciUid'] ?? '').toString(),
      aliciAd: (map['aliciAd'] ?? '').toString(),
      aliciTelefon: (map['aliciTelefon'] ?? '').toString(),
      brans: (map['brans'] ?? '').toString(),
      ekipAdi: (map['ekipAdi'] ?? 'Saha Ekibi').toString(),
      santiyeId: (map['santiyeId'] ?? '').toString(),
      santiyeAdi: (map['santiyeAdi'] ?? 'Genel Şantiye').toString(),
      ucretTipi: (map['ucretTipi'] ?? 'metrekare').toString(),
      birimUcret: ((map['birimUcret'] ?? 0) as num).toDouble(),
      tahminiIsMiktari: ((map['tahminiIsMiktari'] ?? 1) as num).toDouble(),
      ekipKisiSayisi: ((map['ekipKisiSayisi'] ?? 1) as num).toInt(),
      durum: (map['durum'] ?? 'bekliyor').toString(),
      mesajlar:
          rawMsgs
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(),
      guncellenmeTarihi: parsedDate,
    );
  }
}

/// Şantiyeye Özel Atanmış Taşeron / Usta Ekibi (Örn: "Sıvacı Ekibi") ve Hakediş / Puantaj Modeli
class SantiyeOzelEkibi {
  final String id;
  final String ekipAdi; // Örn: "Sıvacı Ekibi", "Kalıpçı Ekibi"
  final String brans;
  final String ekipBasiAd;
  final String ekipBasiTelefon;
  final String? ekipBasiUid;
  final String santiyeId;
  final String santiyeAdi;
  final int kisiSayisi;
  final String anlasmaTipi; // 'metrekare' | 'goturu' | 'gunluk'
  final double birimUcret; // m² birim fiyatı, götürü paket tutarı veya günlük ekip yevmiyesi
  final double toplamAnlasmaMiktari; // Toplam m², toplam gün veya 100 (%)
  final double tamamlananMiktar; // Yapılan m², çalışılan gün veya tamamlanan %
  final double toplamHakedisTutari;
  final double odenenTutar;
  final String? bagliIsciId; // İşçiler sekmesindeki karşılığı
  final List<Map<String, dynamic>> hakedisKayitlari;
  final DateTime olusturulmaTarihi;

  const SantiyeOzelEkibi({
    required this.id,
    required this.ekipAdi,
    required this.brans,
    required this.ekipBasiAd,
    this.ekipBasiTelefon = '',
    this.ekipBasiUid,
    this.santiyeId = '',
    required this.santiyeAdi,
    this.kisiSayisi = 1,
    required this.anlasmaTipi,
    required this.birimUcret,
    this.toplamAnlasmaMiktari = 100,
    this.tamamlananMiktar = 0,
    this.toplamHakedisTutari = 0,
    this.odenenTutar = 0,
    this.bagliIsciId,
    this.hakedisKayitlari = const [],
    required this.olusturulmaTarihi,
  });

  double get kalanBakiye => toplamHakedisTutari - odenenTutar;

  double get ilerlemeOrani {
    if (toplamAnlasmaMiktari <= 0) return 0;
    final ratio = tamamlananMiktar / toplamAnlasmaMiktari;
    return ratio.clamp(0.0, 1.0);
  }

  String get birimEtiketi {
    switch (anlasmaTipi) {
      case 'metrekare':
        return 'm²';
      case 'goturu':
        return '%';
      case 'gunluk':
      default:
        return 'Gün';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ekipAdi': ekipAdi,
      'brans': brans,
      'ekipBasiAd': ekipBasiAd,
      'ekipBasiTelefon': ekipBasiTelefon,
      if (ekipBasiUid != null) 'ekipBasiUid': ekipBasiUid,
      'santiyeId': santiyeId,
      'santiyeAdi': santiyeAdi,
      'kisiSayisi': kisiSayisi,
      'anlasmaTipi': anlasmaTipi,
      'birimUcret': birimUcret,
      'toplamAnlasmaMiktari': toplamAnlasmaMiktari,
      'tamamlananMiktar': tamamlananMiktar,
      'toplamHakedisTutari': toplamHakedisTutari,
      'odenenTutar': odenenTutar,
      if (bagliIsciId != null) 'bagliIsciId': bagliIsciId,
      'hakedisKayitlari': hakedisKayitlari,
      'olusturulmaTarihi': Timestamp.fromDate(olusturulmaTarihi),
    };
  }

  factory SantiyeOzelEkibi.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['olusturulmaTarihi'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    final rawLogs = map['hakedisKayitlari'] as List<dynamic>? ?? const [];
    return SantiyeOzelEkibi(
      id: docId.isNotEmpty ? docId : (map['id'] ?? '').toString(),
      ekipAdi: (map['ekipAdi'] ?? 'Saha Ekibi').toString(),
      brans: (map['brans'] ?? '').toString(),
      ekipBasiAd: (map['ekipBasiAd'] ?? '').toString(),
      ekipBasiTelefon: (map['ekipBasiTelefon'] ?? '').toString(),
      ekipBasiUid: map['ekipBasiUid'] as String?,
      santiyeId: (map['santiyeId'] ?? '').toString(),
      santiyeAdi: (map['santiyeAdi'] ?? 'Genel Şantiye').toString(),
      kisiSayisi: ((map['kisiSayisi'] ?? 1) as num).toInt(),
      anlasmaTipi: (map['anlasmaTipi'] ?? 'metrekare').toString(),
      birimUcret: ((map['birimUcret'] ?? 0) as num).toDouble(),
      toplamAnlasmaMiktari:
          ((map['toplamAnlasmaMiktari'] ?? 100) as num).toDouble(),
      tamamlananMiktar: ((map['tamamlananMiktar'] ?? 0) as num).toDouble(),
      toplamHakedisTutari:
          ((map['toplamHakedisTutari'] ?? 0) as num).toDouble(),
      odenenTutar: ((map['odenenTutar'] ?? 0) as num).toDouble(),
      bagliIsciId: map['bagliIsciId'] as String?,
      hakedisKayitlari:
          rawLogs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
      olusturulmaTarihi: parsedDate,
    );
  }
}

/// Benzer İlan ve Arama Bildirim Alarmı Modeli
class PazarIlanAlarmi {
  final String id;
  final String sehir; // 'Tüm Türkiye' veya il adı
  final String bransFiltre; // Boş ise tüm branşlar
  final String arananSeviye; // 'tumu' | 'ekip' | 'usta' | 'normal_isci'
  final String ucretTipi; // 'tumu' | 'metrekare' | 'goturu' | 'gunluk'
  final String anahtarKelime;
  final bool aktif;

  const PazarIlanAlarmi({
    required this.id,
    this.sehir = 'Tüm Türkiye',
    this.bransFiltre = '',
    this.arananSeviye = 'tumu',
    this.ucretTipi = 'tumu',
    this.anahtarKelime = '',
    this.aktif = true,
  });

  bool ilanaUyuyorMu(SantiyePazarIlani ilan) {
    if (!aktif) return false;
    if (sehir != 'Tüm Türkiye' && ilan.sehir != sehir) return false;
    if (arananSeviye != 'tumu' && ilan.arananSeviye != arananSeviye) {
      return false;
    }
    if (ucretTipi != 'tumu' && ilan.ucretTipi != ucretTipi) return false;
    if (bransFiltre.trim().isNotEmpty &&
        !ilan.brans.toLowerCase().contains(bransFiltre.toLowerCase()) &&
        !ilan.baslik.toLowerCase().contains(bransFiltre.toLowerCase())) {
      return false;
    }
    if (anahtarKelime.trim().isNotEmpty) {
      final q = anahtarKelime.toLowerCase();
      final hay =
          '${ilan.baslik} ${ilan.brans} ${ilan.aciklama} ${ilan.seviye}'
              .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sehir': sehir,
      'bransFiltre': bransFiltre,
      'arananSeviye': arananSeviye,
      'ucretTipi': ucretTipi,
      'anahtarKelime': anahtarKelime,
      'aktif': aktif,
    };
  }

  factory PazarIlanAlarmi.fromMap(Map<String, dynamic> map) {
    return PazarIlanAlarmi(
      id: (map['id'] ?? '').toString(),
      sehir: (map['sehir'] ?? 'Tüm Türkiye').toString(),
      bransFiltre: (map['bransFiltre'] ?? '').toString(),
      arananSeviye: (map['arananSeviye'] ?? 'tumu').toString(),
      ucretTipi: (map['ucretTipi'] ?? 'tumu').toString(),
      anahtarKelime: (map['anahtarKelime'] ?? '').toString(),
      aktif: (map['aktif'] ?? true) == true,
    );
  }
}

/// Kullanıcının veya Şirketin Tamamladığı Geçmiş İşler & Portföy Modeli
class KullaniciIsGecmisi {
  final String id;
  final String kullaniciUid;
  final String projeAdi;
  final String isVerenVeyaSirket;
  final String rolVeyaKapsam;
  final String sehir;
  final String tamamlanmaYili;
  final String metrajVeyaBuyukluk;
  final String aciklama;
  final DateTime tarih;

  const KullaniciIsGecmisi({
    required this.id,
    required this.kullaniciUid,
    required this.projeAdi,
    required this.isVerenVeyaSirket,
    this.rolVeyaKapsam = '',
    this.sehir = '',
    this.tamamlanmaYili = '',
    this.metrajVeyaBuyukluk = '',
    this.aciklama = '',
    required this.tarih,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kullaniciUid': kullaniciUid,
      'projeAdi': projeAdi,
      'isVerenVeyaSirket': isVerenVeyaSirket,
      'rolVeyaKapsam': rolVeyaKapsam,
      'sehir': sehir,
      'tamamlanmaYili': tamamlanmaYili,
      'metrajVeyaBuyukluk': metrajVeyaBuyukluk,
      'aciklama': aciklama,
      'tarih': Timestamp.fromDate(tarih),
    };
  }

  factory KullaniciIsGecmisi.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['tarih'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return KullaniciIsGecmisi(
      id: (map['id'] ?? '').toString(),
      kullaniciUid: (map['kullaniciUid'] ?? '').toString(),
      projeAdi: (map['projeAdi'] ?? '').toString(),
      isVerenVeyaSirket: (map['isVerenVeyaSirket'] ?? '').toString(),
      rolVeyaKapsam: (map['rolVeyaKapsam'] ?? '').toString(),
      sehir: (map['sehir'] ?? '').toString(),
      tamamlanmaYili: (map['tamamlanmaYili'] ?? '').toString(),
      metrajVeyaBuyukluk: (map['metrajVeyaBuyukluk'] ?? '').toString(),
      aciklama: (map['aciklama'] ?? '').toString(),
      tarih: parsedDate,
    );
  }
}

/// Şantiye Pazarı ve Profesyonel Profil Referans & Değerlendirme Modeli
class KullaniciReferansi {
  final String id;
  final String hedefUid; // Referansı alan usta/şirket
  final String hedefAd;
  final String referansVerenUid; // Referansı yazan kişi/şirket
  final String referansVerenAd;
  final String referansVerenSirket;
  final String referansVerenUnvan;
  final String referansVerenTelefon;
  final String projeAdi;
  final String yorum;
  final double puan; // 1.0 - 5.0
  final DateTime tarih;

  const KullaniciReferansi({
    required this.id,
    required this.hedefUid,
    this.hedefAd = '',
    required this.referansVerenUid,
    required this.referansVerenAd,
    this.referansVerenSirket = '',
    this.referansVerenUnvan = '',
    this.referansVerenTelefon = '',
    this.projeAdi = '',
    required this.yorum,
    this.puan = 5.0,
    required this.tarih,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hedefUid': hedefUid,
      'hedefAd': hedefAd,
      'referansVerenUid': referansVerenUid,
      'referansVerenAd': referansVerenAd,
      'referansVerenSirket': referansVerenSirket,
      'referansVerenUnvan': referansVerenUnvan,
      'referansVerenTelefon': referansVerenTelefon,
      'projeAdi': projeAdi,
      'yorum': yorum,
      'puan': puan,
      'tarih': Timestamp.fromDate(tarih),
    };
  }

  factory KullaniciReferansi.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['tarih'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return KullaniciReferansi(
      id: (map['id'] ?? '').toString(),
      hedefUid: (map['hedefUid'] ?? '').toString(),
      hedefAd: (map['hedefAd'] ?? '').toString(),
      referansVerenUid: (map['referansVerenUid'] ?? '').toString(),
      referansVerenAd: (map['referansVerenAd'] ?? 'Şantiye Üyesi').toString(),
      referansVerenSirket: (map['referansVerenSirket'] ?? '').toString(),
      referansVerenUnvan: (map['referansVerenUnvan'] ?? '').toString(),
      referansVerenTelefon: (map['referansVerenTelefon'] ?? '').toString(),
      projeAdi: (map['projeAdi'] ?? '').toString(),
      yorum: (map['yorum'] ?? '').toString(),
      puan: ((map['puan'] ?? 5.0) as num).toDouble(),
      tarih: parsedDate,
    );
  }
}

/// AnaMenuEkrani içerisindeki kart tasarımlarının (_buildPanelGlassCard, _buildPanelGlassInset,
/// _buildPanelGlassIconBadge) birebir aynısını tüm ekranlarda kullanmak için ortak Liquid Glass bileşenleri.
class PanelGlassWidgets {
  static Widget buildCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Color? borderAccent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.cardGradient(isDark),
        ),
        border: Border.all(
          color: borderAccent ?? AppTheme.cardBorder(isDark),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.glow(context).withValues(alpha: isDark ? 0.04 : 0.08),
            blurRadius: isDark ? 12 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  /// Pazar yeri ve form diyalogları için derin siyah buzlu cam (Frosted Glass with Blur)
  static Widget buildModalSheet({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0C0E14).withValues(alpha: 0.90),
                      const Color(0xFF040508).withValues(alpha: 0.95),
                    ]
                  : [
                      const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                      const Color(0xFFE2E8F0).withValues(alpha: 0.96),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            borderRadius: r,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.glow(context).withValues(alpha: isDark ? 0.06 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  static Widget buildInset({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    Color? borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.cardInsetGradient(isDark),
        ),
        border: Border.all(
          color: borderColor ?? AppTheme.cardInsetBorder(isDark),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  static Widget buildIconBadge({
    required BuildContext context,
    required IconData icon,
    Color? accentColor,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accentColor ?? AppTheme.contrastIcon(context, isDark: isDark);
    final size = compact ? 38.0 : 48.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.22 : 0.18),
            (isDark
                    ? color.withValues(alpha: 0.12)
                    : color.withValues(alpha: 0.08))
                .withValues(alpha: isDark ? 0.72 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.20),
        ),
      ),
      child: Icon(icon, color: color, size: compact ? 18 : 24),
    );
  }
}

