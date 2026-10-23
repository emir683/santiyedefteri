import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _tarihCevir(dynamic val) {
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.parse(val);
  return DateTime.now();
}

class Santiye {
  String? id;
  String ad;
  String? il;
  String? ilce;

  Santiye({this.id, required this.ad, this.il, this.ilce});

  Map<String, dynamic> toMap() {
    return {'ad': ad, 'il': il, 'ilce': ilce};
  }

  factory Santiye.fromMap(Map<String, dynamic> map, String documentId) {
    return Santiye(
      id: documentId,
      ad: map['ad'] ?? '',
      il: map['il'] as String?,
      ilce: map['ilce'] as String?,
    );
  }
}

class Isci {
  String? id;
  String ad;
  double gunlukMaas;
  String?
  linkedUserId; // Bağlı Firebase kullanıcısının UID'si (admin tarafından atanır)
  String isciTuru; // "Çekirdek Ekip" veya "Misafir"

  Isci({
    this.id,
    required this.ad,
    required this.gunlukMaas,
    this.linkedUserId,
    this.isciTuru = "Çekirdek Ekip",
  });

  Map<String, dynamic> toMap() {
    return {
      'ad': ad,
      'gunlukMaas': gunlukMaas,
      'isciTuru': isciTuru,
      if (linkedUserId != null) 'linkedUserId': linkedUserId,
    };
  }

  factory Isci.fromMap(Map<String, dynamic> map, String documentId) {
    return Isci(
      id: documentId,
      ad: map['ad'] ?? '',
      gunlukMaas: (map['gunlukMaas'] ?? 0).toDouble(),
      linkedUserId: map['linkedUserId'] as String?,
      isciTuru: map['isciTuru'] ?? "Çekirdek Ekip",
    );
  }

  Map<String, dynamic> toJson() => toMap();
}

double parseDurumCarpani(String durum) {
  if (durum == 'Yok') return 0.0;
  if (durum.contains('Yarım') || durum.contains('yar')) return 0.5;
  if (durum.contains('Mesai') || durum.contains('mesai')) {
    final match = RegExp(r'(\d+([.,]\d+)?)').firstMatch(durum);
    if (match != null) {
      final val = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (val != null && val > 0) return val;
    }
    return 1.5;
  }
  return 1.0;
}

class GunlukCalisma {
  final Isci isci;
  final String durum;

  GunlukCalisma({required this.isci, required this.durum});

  double get yevmiyeCarpani => parseDurumCarpani(durum);

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
  String? benzinGideriIsciId;
  String? benzinGideriIsciAdi;
  String? yemekGideriIsciId;
  String? yemekGideriIsciAdi;
  String? ekMasraflarIsciId;
  String? ekMasraflarIsciAdi;
  String aciklama;
  List<GunlukCalisma> calisanlar;
  DateTime tarih;

  GunlukSantiyeRaporu({
    this.id,
    required this.santiyeAdi,
    required this.tarih,
    this.benzinGideri = 0,
    this.yemekGideri = 0,
    this.ekMasraflar = 0,
    this.benzinGideriIsciId,
    this.benzinGideriIsciAdi,
    this.yemekGideriIsciId,
    this.yemekGideriIsciAdi,
    this.ekMasraflarIsciId,
    this.ekMasraflarIsciAdi,
    this.aciklama = '',
    List<GunlukCalisma>? calisanlar,
  }) : calisanlar = calisanlar ?? [];

  Map<String, dynamic> toMap() {
    return {
      'santiyeAdi': santiyeAdi,
      'tarih': Timestamp.fromDate(tarih),
      'benzinGideri': benzinGideri,
      'yemekGideri': yemekGideri,
      'ekMasraflar': ekMasraflar,
      'benzinGideriIsciId': benzinGideriIsciId,
      'benzinGideriIsciAdi': benzinGideriIsciAdi,
      'yemekGideriIsciId': yemekGideriIsciId,
      'yemekGideriIsciAdi': yemekGideriIsciAdi,
      'ekMasraflarIsciId': ekMasraflarIsciId,
      'ekMasraflarIsciAdi': ekMasraflarIsciAdi,
      'aciklama': aciklama,
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
      benzinGideriIsciId: map['benzinGideriIsciId'],
      benzinGideriIsciAdi: map['benzinGideriIsciAdi'],
      yemekGideriIsciId: map['yemekGideriIsciId'],
      yemekGideriIsciAdi: map['yemekGideriIsciAdi'],
      ekMasraflarIsciId: map['ekMasraflarIsciId'],
      ekMasraflarIsciAdi: map['ekMasraflarIsciAdi'],
      aciklama: map['aciklama'] ?? '',
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
