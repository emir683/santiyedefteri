// lib/data_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// --- YARDIMCI FONKSİYONLAR ---
DateTime _tarihCevir(dynamic val) {
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.parse(val);
  return DateTime.now();
}

// --- VERİ MODELLERİ ---

class Santiye {
  String ad;

  Santiye({required this.ad});

  Map<String, dynamic> toMap() {
    return {'ad': ad};
  }

  factory Santiye.fromMap(Map<String, dynamic> map) {
    return Santiye(ad: map['ad'] ?? '');
  }
}

class Isci {
  String? id;
  String ad;
  double gunlukMaas;

  Isci({this.id, required this.ad, required this.gunlukMaas});

  Map<String, dynamic> toMap() {
    return {'ad': ad, 'gunlukMaas': gunlukMaas};
  }

  factory Isci.fromMap(Map<String, dynamic> map, String documentId) {
    return Isci(
      id: documentId,
      ad: map['ad'] ?? '',
      gunlukMaas: (map['gunlukMaas'] ?? 0).toDouble(),
    );
  }

  // Eski kodlardan kalan uyumluluk için (Opsiyonel)
  Map<String, dynamic> toJson() => toMap();
}

class GunlukCalisma {
  final Isci isci;
  final String durum; // "Tam Gün" veya "Yarım Gün"

  GunlukCalisma({required this.isci, required this.durum});

  Map<String, dynamic> toMap() {
    return {'isci': isci.toMap(), 'durum': durum};
  }

  factory GunlukCalisma.fromMap(Map<String, dynamic> map) {
    return GunlukCalisma(
      isci: Isci.fromMap(map['isci'] ?? {}, ''),
      durum: map['durum'] ?? 'Tam Gün',
    );
  }
}

class GunlukSantiyeRaporu {
  String? id;
  final String santiyeAdi;
  double benzinGideri;
  double yemekGideri;
  double ekMasraflar;
  String aciklama;
  List<GunlukCalisma> calisanlar;
  DateTime tarih; // "tarih is required" hatası için bu alan zorunlu

  GunlukSantiyeRaporu({
    this.id,
    required this.santiyeAdi,
    required this.tarih,
    this.benzinGideri = 0,
    this.yemekGideri = 0,
    this.ekMasraflar = 0,
    this.aciklama = '',
    List<GunlukCalisma>? calisanlar,
  }) : this.calisanlar = calisanlar ?? [];

  Map<String, dynamic> toMap() {
    return {
      'santiyeAdi': santiyeAdi,
      'tarih': Timestamp.fromDate(tarih),
      'benzinGideri': benzinGideri,
      'yemekGideri': yemekGideri,
      'ekMasraflar': ekMasraflar,
      'aciklama': aciklama, // Veritabanına yaz
      'calisanlar': calisanlar.map((c) => c.toMap()).toList(),
    };
  }

  factory GunlukSantiyeRaporu.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return GunlukSantiyeRaporu(
      id: documentId,
      santiyeAdi: map['santiyeAdi'] ?? '',
      tarih: _tarihCevir(map['tarih']),
      benzinGideri: (map['benzinGideri'] ?? 0).toDouble(),
      yemekGideri: (map['yemekGideri'] ?? 0).toDouble(),
      ekMasraflar: (map['ekMasraflar'] ?? 0).toDouble(),
      aciklama: map['aciklama'] ?? '', // Veritabanından oku
      calisanlar:
          (map['calisanlar'] as List<dynamic>? ?? [])
              .map((c) => GunlukCalisma.fromMap(c))
              .toList(),
    );
  }
}

class AlinanOdeme {
  String? id;
  double miktar;
  String santiyeAdi;
  String alanKisi;
  DateTime tarih;

  AlinanOdeme({
    this.id,
    required this.miktar,
    required this.santiyeAdi,
    required this.alanKisi,
    required this.tarih,
  });

  Map<String, dynamic> toMap() {
    return {
      'miktar': miktar,
      'santiyeAdi': santiyeAdi,
      'alanKisi': alanKisi,
      'tarih': Timestamp.fromDate(tarih),
    };
  }

  factory AlinanOdeme.fromMap(Map<String, dynamic> map, String documentId) {
    return AlinanOdeme(
      id: documentId,
      miktar: (map['miktar'] ?? 0).toDouble(),
      santiyeAdi: map['santiyeAdi'] ?? '',
      alanKisi: map['alanKisi'] ?? '',
      tarih: _tarihCevir(map['tarih']),
    );
  }
}

class VerilenAvans {
  String? id;
  double miktar;
  Isci isci;
  DateTime tarih;

  VerilenAvans({
    this.id,
    required this.miktar,
    required this.isci,
    required this.tarih,
  });

  Map<String, dynamic> toMap() {
    return {
      'miktar': miktar,
      'isci': isci.toMap(),
      'tarih': Timestamp.fromDate(tarih),
    };
  }

  factory VerilenAvans.fromMap(Map<String, dynamic> map, String documentId) {
    return VerilenAvans(
      id: documentId,
      miktar: (map['miktar'] ?? 0).toDouble(),
      isci: Isci.fromMap(map['isci'] ?? {}, ''),
      tarih: _tarihCevir(map['tarih']),
    );
  }
}

class FinansalKalem {
  final String ad;
  final double miktar;

  FinansalKalem({required this.ad, required this.miktar});

  Map<String, dynamic> toMap() {
    return {'ad': ad, 'miktar': miktar};
  }

  factory FinansalKalem.fromMap(Map<String, dynamic> map) {
    return FinansalKalem(
      ad: map['ad'] ?? '',
      miktar: (map['miktar'] ?? 0).toDouble(),
    );
  }
}

class AylikFinans {
  String? id;
  int yil;
  int ay;
  List<FinansalKalem> ekstraGelirler;
  List<FinansalKalem> ekstraGiderler;

  AylikFinans({
    this.id,
    required this.yil,
    required this.ay,
    List<FinansalKalem>? ekstraGelirler,
    List<FinansalKalem>? ekstraGiderler,
  }) : ekstraGelirler = ekstraGelirler ?? [],
       ekstraGiderler = ekstraGiderler ?? [];

  Map<String, dynamic> toMap() {
    return {
      'yil': yil,
      'ay': ay,
      'ekstraGelirler': ekstraGelirler.map((e) => e.toMap()).toList(),
      'ekstraGiderler': ekstraGiderler.map((e) => e.toMap()).toList(),
    };
  }

  factory AylikFinans.fromMap(Map<String, dynamic> map, String documentId) {
    return AylikFinans(
      id: documentId,
      yil: map['yil'] ?? 2024,
      ay: map['ay'] ?? 1,
      ekstraGelirler:
          (map['ekstraGelirler'] as List<dynamic>? ?? [])
              .map((e) => FinansalKalem.fromMap(e))
              .toList(),
      ekstraGiderler:
          (map['ekstraGiderler'] as List<dynamic>? ?? [])
              .map((e) => FinansalKalem.fromMap(e))
              .toList(),
    );
  }
}
