import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data_models.dart';

class RaporCakismaGrubu {
  final DateTime gun;
  final String santiyeAdi;
  final List<GunlukSantiyeRaporu> raporlar;

  const RaporCakismaGrubu({
    required this.gun,
    required this.santiyeAdi,
    required this.raporlar,
  });
}

class FirestoreServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String kullaniciId;

  FirestoreServisi({required this.kullaniciId});

  DocumentReference get _kullaniciRef =>
      _db.collection('users').doc(kullaniciId);
  DocumentReference _ekipRef(String ekipId) =>
      _db.collection('teams').doc(ekipId);

  // --- EKİP İŞLEMLERİ ---
  Future<String?> yeniEkipOlustur(String ekipAdi, String sifre) async {
    try {
      final query =
          await _db.collection('teams').where('ad', isEqualTo: ekipAdi).get();
      if (query.docs.isNotEmpty)
        throw Exception("Bu ekip adı zaten kullanılıyor.");

      DocumentReference teamRef = await _db.collection('teams').add({
        'ad': ekipAdi,
        'sifre': sifre,
        'kurucu': kullaniciId,
        'uyeler': [kullaniciId],
        'yoneticiler': [],
        'santiyeListesi': [],
        'isPersonal': false,
      });

      await _kullaniciRef.update({'teamId': teamRef.id});
      return teamRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> ekibeKatil(String ekipAdi, String sifre) async {
    try {
      final query =
          await _db
              .collection('teams')
              .where('ad', isEqualTo: ekipAdi)
              .where('sifre', isEqualTo: sifre)
              .where(
                'isPersonal',
                isEqualTo: false,
              ) // Kişisel ekipleri hariç tut
              .limit(1)
              .get();
      if (query.docs.isEmpty)
        throw Exception("Ekip bulunamadı veya şifre yanlış.");

      final teamDoc = query.docs.first;
      await _kullaniciRef.update({'teamId': teamDoc.id});
      await teamDoc.reference.update({
        'uyeler': FieldValue.arrayUnion([kullaniciId]),
      });
      return teamDoc.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Kullanıcı için otomatik kişisel ekip oluşturur.
  /// Bu ekip başkaları tarafından bulunamaz ve sadece kullanıcıya özeldir.
  Future<String?> ekibeKatilDavetLinki(
    String ekipId, {
    String? beklenenEkipAdi,
  }) async {
    try {
      final teamDoc = await _db.collection('teams').doc(ekipId).get();
      if (!teamDoc.exists) {
        throw Exception("Davet bağlantısı geçersiz veya ekip bulunamadı.");
      }

      final data = teamDoc.data() as Map<String, dynamic>;
      if ((data['isPersonal'] ?? false) == true) {
        throw Exception("Bu davet bağlantısı kullanılamaz.");
      }

      final String ekipAdi = (data['ad'] ?? '').toString().trim();
      if (beklenenEkipAdi != null &&
          beklenenEkipAdi.isNotEmpty &&
          ekipAdi != beklenenEkipAdi) {
        throw Exception("Davet bağlantısı ekip bilgisiyle eşleşmiyor.");
      }

      await _kullaniciRef.update({'teamId': teamDoc.id});
      await teamDoc.reference.update({
        'uyeler': FieldValue.arrayUnion([kullaniciId]),
      });
      return teamDoc.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> kisiselEkipOlustur() async {
    try {
      // Kullanıcının zaten kişisel ekibi var mı kontrol et
      final existingQuery =
          await _db
              .collection('teams')
              .where('isPersonal', isEqualTo: true)
              .where('kurucu', isEqualTo: kullaniciId)
              .limit(1)
              .get();

      if (existingQuery.docs.isNotEmpty) {
        // Zaten kişisel ekibi var, onu kullan
        final existingTeamId = existingQuery.docs.first.id;
        await _kullaniciRef.update({'teamId': existingTeamId});
        return existingTeamId;
      }

      // Yeni kişisel ekip oluştur
      final personalTeamId = 'personal_$kullaniciId';

      await _db.collection('teams').doc(personalTeamId).set({
        'ad': 'Kişisel Defterim',
        'sifre': '',
        'kurucu': kullaniciId,
        'uyeler': [kullaniciId],
        'yoneticiler': [],
        'santiyeListesi': [],
        'isPersonal': true,
      });

      await _kullaniciRef.update({'teamId': personalTeamId});
      return personalTeamId;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getKullaniciEkipId() async {
    final doc = await _kullaniciRef.get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>?)?['teamId'];
  }

  // --- ŞANTİYELER ---
  Stream<List<Santiye>> getSantiyelerStream(String ekipId) {
    return _ekipRef(ekipId).collection('santiyeler').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => Santiye.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> santiyeEkle(String ekipId, Santiye santiye) async {
    await _ekipRef(ekipId).collection('santiyeler').add(santiye.toMap());
    await logIslem(ekipId, 'SANTIYE_EKLEME', {'santiyeAdi': santiye.ad});
  }

  Future<void> santiyeGuncelle(String ekipId, Santiye santiye) async {
    if (santiye.id == null) return;
    await _ekipRef(ekipId).collection('santiyeler').doc(santiye.id).update(santiye.toMap());
    await logIslem(ekipId, 'SANTIYE_GUNCELLEME', {'santiyeAdi': santiye.ad});
  }

  Future<void> santiyeSil(String ekipId, String santiyeId, String santiyeAdi) async {
    await _ekipRef(ekipId).collection('santiyeler').doc(santiyeId).delete();
    await logIslem(ekipId, 'SANTIYE_SILME', {'santiyeAdi': santiyeAdi});
  }

  // --- İŞÇİLER ---
  Stream<List<Isci>> getIscilerStream(String ekipId) {
    return _ekipRef(ekipId).collection('workers').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Isci.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> isciEkle(String ekipId, Isci isci) async {
    await _ekipRef(ekipId).collection('workers').add(isci.toMap());
    await logIslem(ekipId, 'ISCI_EKLEME', {'isciAdi': isci.ad});
  }

  Future<void> isciGuncelle(String ekipId, Isci isci) async {
    if (isci.id == null) return;
    await _ekipRef(
      ekipId,
    ).collection('workers').doc(isci.id).update(isci.toMap());

    // YENİ EKLENEN SATIR: Log tut
    await logIslem(ekipId, 'ISCI_GUNCELLEME', {
      'isciAdi': isci.ad,
      'yeniMaas': isci.gunlukMaas,
    });
  }

  Future<void> isciSil(String ekipId, String isciId) async {
    await _ekipRef(ekipId).collection('workers').doc(isciId).delete();
  }

  Future<void> isciyiUidIleHesabaBagla(String ekipId, String isciId, String targetUserId, String email) async {
    final ayniUyeSorgusu = await _ekipRef(ekipId)
        .collection('workers')
        .where('linkedUserId', isEqualTo: targetUserId)
        .get();

    if (ayniUyeSorgusu.docs.isNotEmpty) {
      throw Exception("Bu ekip üyesi zaten başka bir işçiye bağlanmış.");
    }

    final doc = await _ekipRef(ekipId).collection('workers').doc(isciId).get();
    final isciAdi = doc.data()?['ad'] ?? '';
    await _ekipRef(ekipId).collection('workers').doc(isciId).update({'linkedUserId': targetUserId});
    await logIslem(ekipId, 'ISCI_GUNCELLEME', {
      'isciAdi': isciAdi,
      'detay': 'Hesap bağlandı: $email',
    });
  }

  Future<void> isciBaglantisiniKaldir(String ekipId, String isciId) async {
    final doc = await _ekipRef(ekipId).collection('workers').doc(isciId).get();
    final isciAdi = doc.data()?['ad'] ?? '';
    await _ekipRef(ekipId).collection('workers').doc(isciId).update({'linkedUserId': FieldValue.delete()});
    await logIslem(ekipId, 'ISCI_GUNCELLEME', {
      'isciAdi': isciAdi,
      'detay': 'Hesap bağlantısı kaldırıldı',
    });
  }


  // --- RAPORLAR ---
  Stream<List<GunlukSantiyeRaporu>> getRaporlarStream(
    String ekipId,
    DateTime baslangic,
    DateTime bitis,
  ) {
    return _ekipRef(ekipId)
        .collection('reports')
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
        .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(bitis))
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GunlukSantiyeRaporu.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  Future<void> raporKaydet(String ekipId, GunlukSantiyeRaporu rapor) async {
    final reportsRef = _ekipRef(ekipId).collection('reports');

    if (rapor.id != null) {
      await reportsRef.doc(rapor.id).update(rapor.toMap());
      await logIslem(ekipId, 'GUNLUK_RAPOR_GUNCELLEME', {
        'santiyeAdi': rapor.santiyeAdi,
        'tarih': rapor.tarih.toIso8601String(),
      });
      return;
    }

    final gunBaslangici = DateTime(
      rapor.tarih.year,
      rapor.tarih.month,
      rapor.tarih.day,
    );
    final ertesiGun = gunBaslangici.add(const Duration(days: 1));
    final santiyeAdiKarsilastirma = rapor.santiyeAdi.trim().toLowerCase();

    final ayniGunSnapshot =
        await reportsRef
            .where(
              'tarih',
              isGreaterThanOrEqualTo: Timestamp.fromDate(gunBaslangici),
            )
            .where('tarih', isLessThan: Timestamp.fromDate(ertesiGun))
            .get();

    final ayniSantiyeKayitlari =
        ayniGunSnapshot.docs.where((doc) {
          final docSantiyeAdi =
              (doc.data()['santiyeAdi'] ?? '').toString().trim().toLowerCase();
          return docSantiyeAdi == santiyeAdiKarsilastirma;
        }).toList();

    if (ayniSantiyeKayitlari.isNotEmpty) {
      final hedefDoc = ayniSantiyeKayitlari.first;
      rapor.id = hedefDoc.id;
      await reportsRef.doc(hedefDoc.id).set(rapor.toMap(), SetOptions(merge: true));

      if (ayniSantiyeKayitlari.length > 1) {
        final batch = _db.batch();
        for (final tekrarDoc in ayniSantiyeKayitlari.skip(1)) {
          batch.delete(tekrarDoc.reference);
        }
        await batch.commit();
      }

      await logIslem(ekipId, 'GUNLUK_RAPOR_GUNCELLEME', {
        'santiyeAdi': rapor.santiyeAdi,
        'tarih': rapor.tarih.toIso8601String(),
      });
      return;
    }

    final yeniDoc = await reportsRef.add(rapor.toMap());
    rapor.id = yeniDoc.id;
    await logIslem(ekipId, 'GUNLUK_RAPOR_EKLEME', {
      'santiyeAdi': rapor.santiyeAdi,
      'tarih': rapor.tarih.toIso8601String(),
    });
  }

  // --- ÖDEMELER VE AVANSLAR ---
  String _raporGruplamaKey(GunlukSantiyeRaporu rapor) {
    final gun = DateTime(rapor.tarih.year, rapor.tarih.month, rapor.tarih.day);
    final santiye = rapor.santiyeAdi.trim().toLowerCase();
    return '${gun.toIso8601String()}|$santiye';
  }

  int _raporDolulukPuani(GunlukSantiyeRaporu rapor) {
    int puan = 0;
    if (rapor.calisanlar.isNotEmpty) puan += 5;
    if (rapor.benzinGideri > 0) puan += 2;
    if (rapor.yemekGideri > 0) puan += 2;
    if (rapor.ekMasraflar > 0) puan += 2;
    if (rapor.aciklama.trim().isNotEmpty) puan += 1;
    return puan;
  }

  GunlukSantiyeRaporu _raporlariBirlastir(List<GunlukSantiyeRaporu> raporlar) {
    final sirali = [...raporlar]..sort((a, b) => b.tarih.compareTo(a.tarih));
    final birlesik = GunlukSantiyeRaporu.fromMap(
      sirali.first.toMap(),
      sirali.first.id ?? '',
    );

    final isciAnahtarSeti = <String>{};
    for (final calisma in birlesik.calisanlar) {
      final id = calisma.isci.id?.trim();
      final anahtar = (id != null && id.isNotEmpty)
          ? 'id:$id'
          : 'ad:${calisma.isci.ad.trim().toLowerCase()}';
      isciAnahtarSeti.add(anahtar);
    }

    for (final rapor in sirali.skip(1)) {
      if (birlesik.benzinGideri == 0 && rapor.benzinGideri > 0) {
        birlesik.benzinGideri = rapor.benzinGideri;
        birlesik.benzinGideriIsciId = rapor.benzinGideriIsciId;
        birlesik.benzinGideriIsciAdi = rapor.benzinGideriIsciAdi;
      }
      if (birlesik.yemekGideri == 0 && rapor.yemekGideri > 0) {
        birlesik.yemekGideri = rapor.yemekGideri;
        birlesik.yemekGideriIsciId = rapor.yemekGideriIsciId;
        birlesik.yemekGideriIsciAdi = rapor.yemekGideriIsciAdi;
      }
      if (birlesik.ekMasraflar == 0 && rapor.ekMasraflar > 0) {
        birlesik.ekMasraflar = rapor.ekMasraflar;
        birlesik.ekMasraflarIsciId = rapor.ekMasraflarIsciId;
        birlesik.ekMasraflarIsciAdi = rapor.ekMasraflarIsciAdi;
      }
      if (birlesik.aciklama.trim().isEmpty && rapor.aciklama.trim().isNotEmpty) {
        birlesik.aciklama = rapor.aciklama;
      }

      for (final calisma in rapor.calisanlar) {
        final id = calisma.isci.id?.trim();
        final anahtar = (id != null && id.isNotEmpty)
            ? 'id:$id'
            : 'ad:${calisma.isci.ad.trim().toLowerCase()}';
        if (isciAnahtarSeti.contains(anahtar)) continue;
        isciAnahtarSeti.add(anahtar);
        birlesik.calisanlar.add(calisma);
      }
    }

    return birlesik;
  }

  Future<List<RaporCakismaGrubu>> cakisanRaporlariBul(
    String ekipId, {
    int limit = 700,
  }) async {
    final snapshot =
        await _ekipRef(ekipId)
            .collection('reports')
            .orderBy('tarih', descending: true)
            .limit(limit)
            .get();

    final raporlar = snapshot.docs
        .map((doc) => GunlukSantiyeRaporu.fromMap(doc.data(), doc.id))
        .toList();

    final gruplar = <String, List<GunlukSantiyeRaporu>>{};
    for (final rapor in raporlar) {
      final key = _raporGruplamaKey(rapor);
      gruplar.putIfAbsent(key, () => []).add(rapor);
    }

    final sonuc = <RaporCakismaGrubu>[];
    for (final entry in gruplar.entries) {
      if (entry.value.length <= 1) continue;
      final ilk = entry.value.first;
      final gun = DateTime(ilk.tarih.year, ilk.tarih.month, ilk.tarih.day);
      sonuc.add(
        RaporCakismaGrubu(
          gun: gun,
          santiyeAdi: ilk.santiyeAdi,
          raporlar: [...entry.value]..sort((a, b) => b.tarih.compareTo(a.tarih)),
        ),
      );
    }

    sonuc.sort((a, b) => b.gun.compareTo(a.gun));
    return sonuc;
  }

  Future<void> cakisanRaporlariBirlastir(
    String ekipId,
    RaporCakismaGrubu grup,
  ) async {
    if (grup.raporlar.length <= 1) return;
    final reportsRef = _ekipRef(ekipId).collection('reports');
    final birlesik = _raporlariBirlastir(grup.raporlar);

    final siraliDoluluk = [...grup.raporlar]
      ..sort((a, b) => _raporDolulukPuani(b).compareTo(_raporDolulukPuani(a)));
    final anaKayit = siraliDoluluk.firstWhere(
      (r) => r.id != null,
      orElse: () => grup.raporlar.first,
    );
    final anaId = anaKayit.id;
    if (anaId == null) return;

    final batch = _db.batch();
    birlesik.id = anaId;
    batch.set(reportsRef.doc(anaId), birlesik.toMap(), SetOptions(merge: true));

    for (final rapor in grup.raporlar) {
      if (rapor.id == null || rapor.id == anaId) continue;
      batch.delete(reportsRef.doc(rapor.id));
    }
    await batch.commit();

    await logIslem(ekipId, 'GUNLUK_RAPOR_GUNCELLEME', {
      'santiyeAdi': grup.santiyeAdi,
      'tarih': grup.gun.toIso8601String(),
      'not': 'Çakışan günlük raporlar birleştirildi',
    });
  }

  Future<void> cakisanRaporlardaFazlalariSil(
    String ekipId,
    RaporCakismaGrubu grup,
  ) async {
    if (grup.raporlar.length <= 1) return;
    final reportsRef = _ekipRef(ekipId).collection('reports');

    final siraliDoluluk = [...grup.raporlar]
      ..sort((a, b) => _raporDolulukPuani(b).compareTo(_raporDolulukPuani(a)));
    final anaKayit = siraliDoluluk.firstWhere(
      (r) => r.id != null,
      orElse: () => grup.raporlar.first,
    );
    final anaId = anaKayit.id;
    if (anaId == null) return;

    final batch = _db.batch();
    for (final rapor in grup.raporlar) {
      if (rapor.id == null || rapor.id == anaId) continue;
      batch.delete(reportsRef.doc(rapor.id));
    }
    await batch.commit();

    await logIslem(ekipId, 'GUNLUK_RAPOR_GUNCELLEME', {
      'santiyeAdi': grup.santiyeAdi,
      'tarih': grup.gun.toIso8601String(),
      'not': 'Çakışan günlük raporlarda fazlalık kayıtlar silindi',
    });
  }

  Stream<List<AlinanOdeme>> getOdemelerStream(String ekipId) {
    return _ekipRef(ekipId)
        .collection('payments')
        .orderBy('tarih', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => AlinanOdeme.fromMap(d.data(), d.id)).toList(),
        );
  }

  // --- AYLIK FİNANS (EK GELİR/GİDER) ---
  Stream<AylikFinans?> getAylikFinansStream(String ekipId, int yil, int ay) {
    String docId = '${yil}_$ay';
    return _ekipRef(
      ekipId,
    ).collection('aylik_finans').doc(docId).snapshots().map((doc) {
      if (doc.exists) {
        return AylikFinans.fromMap(doc.data()!, doc.id);
      }
      return AylikFinans(yil: yil, ay: ay); // Yoksa boş döndür
    });
  }

  Stream<List<AylikFinans>> getTumAylikFinanslarStream(String ekipId) {
    return _ekipRef(
      ekipId,
    ).collection('aylik_finans').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AylikFinans.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> aylikFinansGuncelle(String ekipId, AylikFinans finans) async {
    String docId = '${finans.yil}_${finans.ay}';
    await _ekipRef(
      ekipId,
    ).collection('aylik_finans').doc(docId).set(finans.toMap());
  }

  Stream<List<VerilenAvans>> getAvanslarStream(String ekipId) {
    return _ekipRef(ekipId)
        .collection('advances')
        .orderBy('tarih', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => VerilenAvans.fromMap(d.data(), d.id)).toList(),
        );
  }

  Future<void> odemeEkle(String ekipId, AlinanOdeme odeme) async {
    await _ekipRef(ekipId).collection('payments').add(odeme.toMap());
    // Loglama yaparken hata olursa işlem durmasın diye try-catch içinde
    try {
      await logIslem(ekipId, 'ODEME_EKLEME', {'miktar': odeme.miktar});
    } catch (_) {}
  }

  Future<void> odemeSil(String ekipId, String odemeId) async {
    await _ekipRef(ekipId).collection('payments').doc(odemeId).delete();
  }

  Future<void> avansEkle(String ekipId, VerilenAvans avans) async {
    await _ekipRef(ekipId).collection('advances').add(avans.toMap());
    try {
      await logIslem(ekipId, 'AVANS_EKLEME', {
        'miktar': avans.miktar,
        'isci': avans.isci.ad,
      });
    } catch (_) {}
  }

  Future<void> avansSil(String ekipId, String avansId) async {
    await _ekipRef(ekipId).collection('advances').doc(avansId).delete();
  }

  // --- LOGLAMA (DÜZELTİLEN KISIM) ---
  Future<void> logIslem(
    String ekipId,
    String islemTipi,
    Map<String, dynamic> detaylar,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String kullaniciUsername = user.email ?? 'Bilinmeyen';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data['username'] != null) {
          kullaniciUsername = data['username'];
        }
      }
    } catch (e) {
      // Kullanıcı adı çekilemezse mail adresi ile devam et, çökme yapma.
    }

    await _ekipRef(ekipId).collection('history').add({
      'kullaniciUid': user.uid,
      'kullaniciUsername': kullaniciUsername,
      'islemTipi': islemTipi,
      'detaylar': detaylar,
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  // --- DİĞERLERİ ---
  Stream<List<Map<String, dynamic>>> getEkipUyeleriStream(String ekipId) {
    return _ekipRef(ekipId).snapshots().asyncMap((teamDoc) async {
      if (!teamDoc.exists || teamDoc.data() == null) return [];
      final teamData = teamDoc.data() as Map<String, dynamic>;
      final List<String> uyeUidList = List<String>.from(
        teamData['uyeler'] ?? [],
      );
      final List<Map<String, dynamic>> uyeDetaylari = [];
      for (String uid in uyeUidList) {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          uyeDetaylari.add({
            'uid': uid,
            'username': userData['username'] ?? 'İsimsiz',
            'email': userData['email'] ?? '...',
          });
        }
      }
      return uyeDetaylari;
    });
  }

  Future<void> uyeyiEkiptenSil(String ekipId, String uyeUid) async {
    await _ekipRef(ekipId).update({
      'uyeler': FieldValue.arrayRemove([uyeUid]),
      'yoneticiler': FieldValue.arrayRemove([uyeUid]),
    });
    await _db.collection('users').doc(uyeUid).update({'teamId': null});
  }

  Future<void> yoneticiYap(String ekipId, String uyeUid) async {
    await _ekipRef(ekipId).update({
      'yoneticiler': FieldValue.arrayUnion([uyeUid]),
    });
    await logIslem(ekipId, 'ROL_DEGISIMI', {
      'uyeUid': uyeUid,
      'yeniRol': 'yonetici',
    });
  }

  Future<void> yoneticiliktenCikar(String ekipId, String uyeUid) async {
    await _ekipRef(ekipId).update({
      'yoneticiler': FieldValue.arrayRemove([uyeUid]),
    });
    await logIslem(ekipId, 'ROL_DEGISIMI', {
      'uyeUid': uyeUid,
      'yeniRol': 'uye',
    });
  }

  Future<void> ekiptenAyril(String ekipId, String kullaniciUid) async {
    await uyeyiEkiptenSil(ekipId, kullaniciUid);
  }

  Stream<DocumentSnapshot> getKullaniciVeriStream() =>
      _kullaniciRef.snapshots();

  Future<void> kullaniciAdiniGuncelle(String yeniKullaniciAdi) async {
    await _kullaniciRef.update({'username': yeniKullaniciAdi});
  }

  Future<void> completeGoogleUserProfile(
    String userId,
    String adSoyad,
    String username,
  ) async {
    await _db.collection('users').doc(userId).set({
      'username': username,
      'username_lowercase': username.toLowerCase(),
      'adSoyad': adSoyad,
      'email': FirebaseAuth.instance.currentUser?.email,
    }, SetOptions(merge: true));
  }

  Future<void> ekipAdiniGuncelle(String ekipId, String yeniAd) async {
    await _ekipRef(ekipId).update({'ad': yeniAd});
    await logIslem(ekipId, 'EKIP_ADI_DEGISTIRME', {'yeniAd': yeniAd});
  }

  Future<void> ekipParolasiniGuncelle(String ekipId, String yeniParola) async {
    await _ekipRef(ekipId).update({'sifre': yeniParola});
    // Güvenlik için logda parolayı göstermiyoruz
    await logIslem(ekipId, 'EKIP_PAROLA_DEGISTIRME', {});
  }

  Future<void> demoVerileriYukle(String teamId) async {
    final now = DateTime.now();

    // ─── 1. ŞANTİYELER ──────────────────────────────────────────────
    final santiyeAdlari = [
      'Vadi Konutları A Blok',
      'Merkez Plaza Ofis',
      'Sahil Rezidans',
      'Atatürk Bulvarı Yol',
      'Yeşiltepe Altyapı',
    ];
    for (var sAdi in santiyeAdlari) {
      await santiyeEkle(teamId, Santiye(ad: sAdi));
    }

    // ─── 2. İŞÇİLER ─────────────────────────────────────────────────
    final isciVerileri = [
      {'ad': 'Ahmet Yılmaz', 'maas': 1500.0},
      {'ad': 'Mehmet Demir', 'maas': 1200.0},
      {'ad': 'Ali Kaya', 'maas': 1100.0},
      {'ad': 'Hüseyin Çelik', 'maas': 1300.0},
      {'ad': 'Mustafa Şahin', 'maas': 1000.0},
      {'ad': 'İbrahim Arslan', 'maas': 1400.0},
    ];

    List<Isci> isciler = [];
    for (var i in isciVerileri) {
      final docRef = await _ekipRef(
        teamId,
      ).collection('workers').add({'ad': i['ad'], 'gunlukMaas': i['maas']});
      isciler.add(
        Isci(
          id: docRef.id,
          ad: i['ad'] as String,
          gunlukMaas: i['maas'] as double,
        ),
      );
    }

    // ─── 3. GÜNLÜK RAPORLAR (Son 45 gün) ────────────────────────────
    // Her şantiyede farklı günlerde, farklı işçi kombinasyonları
    final raporVerisi = [
      // [gün_önce, santiye_idx, [isci_idx_listesi], benzin, yemek, ekMasraf, aciklama]
      [
        0,
        0,
        [0, 1, 2, 3],
        250.0,
        450.0,
        0.0,
        'Temel beton dökümü tamamlandı',
      ],
      [
        0,
        1,
        [4, 5],
        150.0,
        200.0,
        0.0,
        'Çatı kaplama devam ediyor',
      ],
      [
        1,
        0,
        [0, 1, 2, 3],
        200.0,
        450.0,
        300.0,
        'Kalıp söküldü, temizlik yapıldı',
      ],
      [
        1,
        2,
        [3, 4, 5],
        180.0,
        300.0,
        0.0,
        'İskele kurulumu yapıldı',
      ],
      [
        2,
        0,
        [0, 1, 3],
        220.0,
        350.0,
        0.0,
        'Zemin hazırlığı tamamlandı',
      ],
      [
        2,
        1,
        [2, 4, 5],
        160.0,
        300.0,
        500.0,
        'Elektrik tesisatı için kazı',
      ],
      [
        3,
        2,
        [0, 1, 2],
        190.0,
        300.0,
        0.0,
        'Duvar örme çalışması',
      ],
      [
        3,
        3,
        [3, 4, 5],
        350.0,
        300.0,
        200.0,
        'Asfalt serimi başladı',
      ],
      [
        4,
        0,
        [0, 1, 2, 3],
        240.0,
        450.0,
        0.0,
        'Kolonlar döküldü',
      ],
      [
        4,
        4,
        [4, 5],
        280.0,
        200.0,
        0.0,
        'Boru döşeme çalışması',
      ],
      [
        5,
        1,
        [0, 2, 4],
        170.0,
        300.0,
        0.0,
        'Sıva uygulaması yapıldı',
      ],
      [
        5,
        3,
        [1, 3, 5],
        400.0,
        300.0,
        600.0,
        'Bordür taşı döşeme',
      ],
      [
        7,
        0,
        [0, 1, 2, 3],
        230.0,
        450.0,
        0.0,
        'Döşeme betonu atıldı',
      ],
      [
        7,
        2,
        [3, 4],
        150.0,
        200.0,
        350.0,
        'Pencere kasaları takıldı',
      ],
      [
        8,
        1,
        [0, 2, 5],
        180.0,
        300.0,
        0.0,
        'İç sıva devam ediyor',
      ],
      [
        8,
        4,
        [1, 3, 4],
        310.0,
        300.0,
        0.0,
        'Kanalizasyon hattı döşendi',
      ],
      [
        9,
        0,
        [0, 1, 2],
        200.0,
        300.0,
        0.0,
        'Kolon demiri bağlandı',
      ],
      [
        9,
        3,
        [3, 4, 5],
        380.0,
        300.0,
        450.0,
        'Refüj düzenleme çalışması',
      ],
      [
        10,
        0,
        [0, 1, 3, 4],
        260.0,
        450.0,
        0.0,
        'Bodrum kat betonu döküldü',
      ],
      [
        10,
        2,
        [2, 5],
        140.0,
        200.0,
        0.0,
        'Çatı izolasyonu yapıldı',
      ],
      [
        12,
        1,
        [0, 2, 4],
        190.0,
        300.0,
        280.0,
        'Badana ve boya işlemleri',
      ],
      [
        12,
        4,
        [1, 3, 5],
        290.0,
        300.0,
        0.0,
        'Su deposu montajı',
      ],
      [
        14,
        0,
        [0, 1, 2, 3],
        270.0,
        450.0,
        0.0,
        '1. kat döşemesi tamamlandı',
      ],
      [
        14,
        3,
        [4, 5],
        420.0,
        200.0,
        700.0,
        'Kavşak düzenlemesi',
      ],
      [
        15,
        1,
        [0, 3, 5],
        160.0,
        300.0,
        0.0,
        'Alçı sıva uygulaması',
      ],
      [
        16,
        2,
        [1, 2, 4],
        175.0,
        300.0,
        0.0,
        'Kapı kasaları takıldı',
      ],
      [
        17,
        0,
        [0, 1, 2, 4],
        245.0,
        450.0,
        380.0,
        '2. kat kalıpları hazırlandı',
      ],
      [
        18,
        3,
        [3, 5],
        390.0,
        200.0,
        0.0,
        'Üst geçit betonu döküldü',
      ],
      [
        19,
        1,
        [0, 2, 3],
        170.0,
        300.0,
        250.0,
        'Fayans döşeme başladı',
      ],
      [
        20,
        4,
        [1, 4, 5],
        300.0,
        300.0,
        0.0,
        'Yangın hattı döşendi',
      ],
      [
        21,
        0,
        [0, 1, 2, 3],
        255.0,
        450.0,
        0.0,
        '2. kat betonu döküldü',
      ],
      [
        22,
        2,
        [4, 5],
        145.0,
        200.0,
        320.0,
        'Teras su yalıtımı',
      ],
      [
        23,
        1,
        [0, 3, 4],
        185.0,
        300.0,
        0.0,
        'Seramik döşeme tamamlandı',
      ],
      [
        24,
        3,
        [1, 2, 5],
        410.0,
        300.0,
        550.0,
        'Yol çizgi boyası yapıldı',
      ],
      [
        25,
        0,
        [0, 1, 3, 5],
        280.0,
        450.0,
        0.0,
        'Demir sökümü ve stok',
      ],
      [
        26,
        4,
        [2, 4],
        270.0,
        200.0,
        0.0,
        'Trafo merkezi kablo döşeme',
      ],
      [
        28,
        0,
        [0, 1, 2, 3],
        240.0,
        450.0,
        430.0,
        '3. kat kalıpları hazır',
      ],
      [
        29,
        2,
        [3, 4, 5],
        155.0,
        300.0,
        0.0,
        'Çatı oluk montajı',
      ],
      [
        30,
        1,
        [0, 2, 5],
        175.0,
        300.0,
        0.0,
        'Son kat boyası tamamlandı',
      ],
      [
        31,
        3,
        [1, 3, 4],
        395.0,
        300.0,
        0.0,
        'Köprü küpeştesi kaynaklandı',
      ],
      [
        32,
        0,
        [0, 1, 2, 4],
        265.0,
        450.0,
        0.0,
        'Teras döşemesi yapıldı',
      ],
      [
        33,
        4,
        [3, 5],
        285.0,
        200.0,
        480.0,
        'Trafo bağlantısı yapıldı',
      ],
      [
        35,
        0,
        [0, 1, 3],
        230.0,
        350.0,
        0.0,
        'Asansör boşluğu açıldı',
      ],
      [
        36,
        2,
        [2, 4, 5],
        160.0,
        300.0,
        340.0,
        'Güneş paneli çatı işleri',
      ],
      [
        38,
        1,
        [0, 3, 4],
        190.0,
        300.0,
        0.0,
        'Mutfak dolapları montajı',
      ],
      [
        40,
        3,
        [1, 2, 5],
        430.0,
        300.0,
        0.0,
        'Yaya yolu taş döşeme',
      ],
      [
        42,
        0,
        [0, 1, 2, 3],
        275.0,
        450.0,
        0.0,
        '4. kat perde beton',
      ],
      [
        44,
        4,
        [4, 5],
        295.0,
        200.0,
        510.0,
        'Aydınlatma direği montajı',
      ],
    ];

    // Çalışma durumlarını çeşitlendir
    final durumlar = ['Tam Gün', 'Tam Gün', 'Tam Gün', 'Yarım Gün'];

    for (int r = 0; r < raporVerisi.length; r++) {
      final veri = raporVerisi[r];
      final gunOnce = veri[0] as int;
      final santiyeIdx = veri[1] as int;
      final isciIdxler = veri[2] as List<int>;
      final benzin = veri[3] as double;
      final yemek = veri[4] as double;
      final ekMasraf = veri[5] as double;
      final aciklama = veri[6] as String;

      final tarih = now.subtract(Duration(days: gunOnce));

      final calisanlar =
          isciIdxler
              .map(
                (idx) => GunlukCalisma(
                  isci: isciler[idx],
                  durum: durumlar[(idx + r) % durumlar.length],
                ),
              )
              .toList();

      final rapor = GunlukSantiyeRaporu(
        santiyeAdi: santiyeAdlari[santiyeIdx],
        tarih: tarih,
        benzinGideri: benzin,
        yemekGideri: yemek,
        ekMasraflar: ekMasraf,
        aciklama: aciklama,
        calisanlar: calisanlar,
      );

      await _ekipRef(teamId).collection('reports').add(rapor.toMap());
    }

    // ─── 4. ÖDEMELER (Alınan) ────────────────────────────────────────
    final odemeler = [
      AlinanOdeme(
        miktar: 45000,
        santiyeAdi: santiyeAdlari[0],
        alanKisi: 'Vadi İnşaat A.Ş.',
        tarih: now.subtract(const Duration(days: 3)),
      ),
      AlinanOdeme(
        miktar: 28000,
        santiyeAdi: santiyeAdlari[1],
        alanKisi: 'Merkez Yapı Ltd.',
        tarih: now.subtract(const Duration(days: 8)),
      ),
      AlinanOdeme(
        miktar: 32000,
        santiyeAdi: santiyeAdlari[2],
        alanKisi: 'Sahil Rezidans A.Ş.',
        tarih: now.subtract(const Duration(days: 15)),
      ),
      AlinanOdeme(
        miktar: 18500,
        santiyeAdi: santiyeAdlari[3],
        alanKisi: 'Belediye Sözleşmesi',
        tarih: now.subtract(const Duration(days: 22)),
      ),
      AlinanOdeme(
        miktar: 55000,
        santiyeAdi: santiyeAdlari[0],
        alanKisi: 'Vadi İnşaat A.Ş.',
        tarih: now.subtract(const Duration(days: 31)),
      ),
      AlinanOdeme(
        miktar: 21000,
        santiyeAdi: santiyeAdlari[4],
        alanKisi: 'Yeşiltepe Belediye',
        tarih: now.subtract(const Duration(days: 40)),
      ),
    ];
    for (var o in odemeler) {
      await odemeEkle(teamId, o);
    }

    // ─── 5. AVANSLAR ─────────────────────────────────────────────────
    final avanslar = [
      VerilenAvans(
        miktar: 2000,
        isci: isciler[0],
        tarih: now.subtract(const Duration(days: 2)),
      ),
      VerilenAvans(
        miktar: 1500,
        isci: isciler[1],
        tarih: now.subtract(const Duration(days: 6)),
      ),
      VerilenAvans(
        miktar: 1000,
        isci: isciler[3],
        tarih: now.subtract(const Duration(days: 10)),
      ),
      VerilenAvans(
        miktar: 2500,
        isci: isciler[0],
        tarih: now.subtract(const Duration(days: 18)),
      ),
      VerilenAvans(
        miktar: 1200,
        isci: isciler[4],
        tarih: now.subtract(const Duration(days: 25)),
      ),
      VerilenAvans(
        miktar: 1800,
        isci: isciler[2],
        tarih: now.subtract(const Duration(days: 33)),
      ),
    ];
    for (var a in avanslar) {
      await avansEkle(teamId, a);
    }

    // ─── 6. AYLIK FİNANS (Ekstra Gelir/Gider) ───────────────────────
    final aylarVerisi = [
      // [yil, ay, ekstraGelirler, ekstraGiderler]
      {
        'yil': now.year,
        'ay': now.month,
        'gelirler': [
          {'ad': 'Malzeme Satışı (Hurda Demir)', 'miktar': 3200.0},
          {'ad': 'Alt Yüklenici Cirosu', 'miktar': 8500.0},
        ],
        'giderler': [
          {'ad': 'Vinç Kiralama', 'miktar': 4500.0},
          {'ad': 'Beton Malzeme Alımı', 'miktar': 12000.0},
          {'ad': 'Alet Tamiri', 'miktar': 850.0},
          {'ad': 'SGK Primleri', 'miktar': 6200.0},
        ],
      },
      {
        'yil': now.month == 1 ? now.year - 1 : now.year,
        'ay': now.month == 1 ? 12 : now.month - 1,
        'gelirler': [
          {'ad': 'Hakediş Ödemesi', 'miktar': 22000.0},
          {'ad': 'Ekipman Kira Geliri', 'miktar': 5000.0},
        ],
        'giderler': [
          {'ad': 'İskele Kiralama', 'miktar': 3800.0},
          {'ad': 'Sıva Malzemesi', 'miktar': 7500.0},
          {'ad': 'Elektrik Faturası', 'miktar': 1200.0},
          {'ad': 'SGK Primleri', 'miktar': 6200.0},
          {'ad': 'Araç Yakıt', 'miktar': 2900.0},
        ],
      },
    ];

    for (var ay in aylarVerisi) {
      final gelirler =
          (ay['gelirler'] as List<Map<String, dynamic>>)
              .map(
                (e) => FinansalKalem(
                  ad: e['ad'] as String,
                  miktar: e['miktar'] as double,
                ),
              )
              .toList();
      final giderler =
          (ay['giderler'] as List<Map<String, dynamic>>)
              .map(
                (e) => FinansalKalem(
                  ad: e['ad'] as String,
                  miktar: e['miktar'] as double,
                ),
              )
              .toList();

      final aylikFinans = AylikFinans(
        yil: ay['yil'] as int,
        ay: ay['ay'] as int,
        ekstraGelirler: gelirler,
        ekstraGiderler: giderler,
      );

      await _ekipRef(
        teamId,
      ).collection('aylik_finans').add(aylikFinans.toMap());
    }

    // ─── 7. İŞLEM GEÇMİŞİ LOGLARI ───────────────────────────────────
    final loglar = [
      {
        'tip': 'SANTIYE_EKLEME',
        'data': {'santiyeAdi': santiyeAdlari[0]},
        'gun': 44,
      },
      {
        'tip': 'ISCI_EKLEME',
        'data': {'isciAdi': isciler[0].ad},
        'gun': 43,
      },
      {
        'tip': 'ISCI_EKLEME',
        'data': {'isciAdi': isciler[1].ad},
        'gun': 43,
      },
      {
        'tip': 'ODEME_EKLEME',
        'data': {'miktar': 55000, 'alan': 'Vadi İnşaat'},
        'gun': 31,
      },
      {
        'tip': 'AVANS_VERME',
        'data': {'isciAdi': isciler[0].ad, 'miktar': 2500},
        'gun': 18,
      },
      {
        'tip': 'SANTIYE_EKLEME',
        'data': {'santiyeAdi': santiyeAdlari[1]},
        'gun': 15,
      },
      {
        'tip': 'ODEME_EKLEME',
        'data': {'miktar': 32000, 'alan': 'Sahil Rezidans'},
        'gun': 15,
      },
      {
        'tip': 'ISCI_GUNCELLEME',
        'data': {'isciAdi': isciler[2].ad},
        'gun': 12,
      },
      {
        'tip': 'AVANS_VERME',
        'data': {'isciAdi': isciler[1].ad, 'miktar': 1500},
        'gun': 6,
      },
      {
        'tip': 'ODEME_EKLEME',
        'data': {'miktar': 28000, 'alan': 'Merkez Yapı'},
        'gun': 8,
      },
      {
        'tip': 'AVANS_VERME',
        'data': {'isciAdi': isciler[0].ad, 'miktar': 2000},
        'gun': 2,
      },
      {
        'tip': 'ODEME_EKLEME',
        'data': {'miktar': 45000, 'alan': 'Vadi İnşaat'},
        'gun': 3,
      },
      {
        'tip': 'DEMO_VERI_YUKLEME',
        'data': {'aciklama': 'Demo verileri yüklendi'},
        'gun': 0,
      },
    ];

    for (var log in loglar) {
      final tarih = now.subtract(Duration(days: log['gun'] as int));
      await _ekipRef(teamId).collection('history').add({
        'tip': log['tip'],
        'veri': log['data'],
        'tarih': Timestamp.fromDate(tarih),
      });
    }
  }

  Future<void> tumVerileriSil(String teamId) async {
    // Silinecek koleksiyonlar
    final collections = [
      'santiyeler',
      'workers',
      'reports',
      'payments',
      'advances',
      'aylik_finans',
      'history', // İşlem geçmişini de siler
    ];

    for (var collection in collections) {
      final snapshot = await _ekipRef(teamId).collection(collection).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    // Ekip dokümanını sıfırlama (İsteğe bağlı, şimdilik sadece alt koleksiyonları siliyoruz)
    // await logIslem(teamId, 'VERI_SIFIRLAMA', {'aciklama': 'Tüm veriler silindi.'}); // History silindiği için bu log da silinecek ama en sona eklersek yeni history başlar.

    // Temiz bir başlangıç için log atalım
    await _ekipRef(teamId).collection('history').add({
      'kullaniciUid': FirebaseAuth.instance.currentUser?.uid ?? 'system',
      'kullaniciUsername': FirebaseAuth.instance.currentUser?.email ?? 'System',
      'islemTipi': 'VERI_SIFIRLAMA',
      'detaylar': {'aciklama': 'Kullanıcı tüm verileri sıfırladı.'},
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  // --- BİLDİRİM İŞLEMLERİ ---
  String _buildNotificationMessageText(String islemTipi, Map<String, dynamic> detaylar, String username) {
    switch (islemTipi) {
      case 'ISCI_EKLEME':
        return "$username, ${detaylar['isciAdi'] ?? 'bir işçiyi'} ekibe ekledi.";
      case 'ISCI_GUNCELLEME':
        return "$username, ${detaylar['isciAdi'] ?? 'bir işçinin'} bilgilerini güncelledi.";
      case 'ISCI_SILME':
        return "$username bir işçiyi ekipten çıkardı.";
      case 'SANTIYE_EKLEME':
        return "$username, ${detaylar['santiyeAdi'] ?? 'yeni bir'} şantiyesi ekledi.";
      case 'SANTIYE_SILME':
        return "$username, ${detaylar['santiyeAdi'] ?? 'bir'} şantiyesini sildi.";
      case 'GUNLUK_RAPOR_EKLEME':
        return "$username, ${detaylar['santiyeAdi'] ?? ''} şantiyesine rapor girdi.";
      case 'GUNLUK_RAPOR_GUNCELLEME':
        return "$username, ${detaylar['santiyeAdi'] ?? ''} raporunu güncelledi.";
      case 'ODEME_EKLEME':
        return "$username, ${detaylar['miktar']} TL ödeme kaydetti.";
      case 'AVANS_EKLEME':
        return "$username, ${detaylar['isci'] ?? 'bir işçiye'} ${detaylar['miktar']} TL avans verdi.";
      case 'ROL_DEGISIMI':
        return "$username ekipte rol değişikliği yaptı.";
      default:
        return "$username bir işlem gerçekleştirdi.";
    }
  }

  Stream<List<Map<String, dynamic>>> getKullaniciBildirimleri(String teamId, String uid) {
    return _ekipRef(teamId)
        .collection('history')
        .orderBy('tarih', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final String islemYapanUid = data['kullaniciUid'] ?? '';
            if (islemYapanUid == uid) return null; // Kendi işlemini bildirim olarak gösterme

            final List<dynamic> okuyanlar = data['okuyanlar'] ?? [];
            final String islemTipi = data['islemTipi'] ?? '';
            final Map<String, dynamic> detaylar = data['detaylar'] != null 
                ? Map<String, dynamic>.from(data['detaylar']) 
                : {};
            final String username = data['kullaniciUsername'] ?? 'Biri';

            final String mesaj = _buildNotificationMessageText(islemTipi, detaylar, username);

            return {
              'id': doc.id,
              ...data,
              'mesaj': mesaj,
              'okundu': okuyanlar.contains(uid),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    });
  }

  Future<void> bildirimiOkunduIsaretle(String teamId, String bildirimId) async {
    await _ekipRef(teamId)
        .collection('history')
        .doc(bildirimId)
        .update({
      'okuyanlar': FieldValue.arrayUnion([kullaniciId]),
    });
  }

  Future<void> tumBildirimleriOkunduYap(String teamId, String uid) async {
    final query = await _ekipRef(teamId)
        .collection('history')
        .orderBy('tarih', descending: true)
        .limit(100)
        .get();

    final batch = _db.batch();
    bool hasUpdates = false;
    for (var doc in query.docs) {
      final List<dynamic> okuyanlar = doc.data()['okuyanlar'] ?? [];
      final String islemYapanUid = doc.data()['kullaniciUid'] ?? '';
      if (islemYapanUid != uid && !okuyanlar.contains(uid)) {
        batch.update(doc.reference, {
          'okuyanlar': FieldValue.arrayUnion([uid]),
        });
        hasUpdates = true;
      }
    }
    if (hasUpdates) {
      await batch.commit();
    }
  }
}
