import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data_models.dart';

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
        'santiyeListesi': [],
        'isPersonal': false, // Normal ekip, başkaları katılabilir
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
        'sifre': '', // Boş şifre, kimse katılamaz
        'kurucu': kullaniciId,
        'uyeler': [kullaniciId],
        'santiyeListesi': [],
        'isPersonal': true, // Bu bayrak kişisel ekip olduğunu belirtir
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
      return snapshot.docs.map((doc) => Santiye.fromMap(doc.data())).toList();
    });
  }

  Future<void> santiyeEkle(String ekipId, Santiye santiye) async {
    await _ekipRef(
      ekipId,
    ).collection('santiyeler').doc(santiye.ad).set(santiye.toMap());
    await logIslem(ekipId, 'SANTIYE_EKLEME', {'santiyeAdi': santiye.ad});
  }

  Future<void> santiyeSil(String ekipId, String santiyeAdi) async {
    await _ekipRef(ekipId).collection('santiyeler').doc(santiyeAdi).delete();
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
    if (rapor.id != null) {
      await _ekipRef(
        ekipId,
      ).collection('reports').doc(rapor.id).update(rapor.toMap());
      // YENİ EKLENEN SATIR: Güncelleme logu
      await logIslem(ekipId, 'GUNLUK_RAPOR_GUNCELLEME', {
        'santiyeAdi': rapor.santiyeAdi,
        'tarih': rapor.tarih.toIso8601String(),
      });
    } else {
      await _ekipRef(ekipId).collection('reports').add(rapor.toMap());
      // YENİ EKLENEN SATIR: Yeni ekleme logu
      await logIslem(ekipId, 'GUNLUK_RAPOR_EKLEME', {
        'santiyeAdi': rapor.santiyeAdi,
        'tarih': rapor.tarih.toIso8601String(),
      });
    }
  }

  // --- ÖDEMELER VE AVANSLAR ---
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
    });
    await _db.collection('users').doc(uyeUid).update({'teamId': null});
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
    // 1. Şantiyeleri Ekle
    final santiyeler = ['Vadi Konutları', 'Merkez Plaza', 'Sahil Parkı Peyzaj'];
    for (var sAdi in santiyeler) {
      await santiyeEkle(teamId, Santiye(ad: sAdi));
    }

    // 2. İşçileri Ekle
    final isciListesi = [
      {'ad': 'Ahmet Yılmaz (Usta)', 'maas': 2500.0},
      {'ad': 'Mehmet Demir (Kalfa)', 'maas': 2000.0},
      {'ad': 'Ali Çelik (Çırak)', 'maas': 1500.0},
      {'ad': 'Veli Güneş (Düz İşçi)', 'maas': 1200.0},
    ];

    // İşçileri kaydet ve objelerini sakla (Raporlarda kullanmak için)
    List<Isci> kaydedilenIsciler = [];
    for (var i in isciListesi) {
      final docRef = await _ekipRef(
        teamId,
      ).collection('workers').add({'ad': i['ad'], 'gunlukMaas': i['maas']});
      kaydedilenIsciler.add(
        Isci(
          id: docRef.id,
          ad: i['ad'] as String,
          gunlukMaas: i['maas'] as double,
        ),
      );
    }

    // 3. Geçmiş 3 Güne Rapor Gir
    for (int i = 0; i < 3; i++) {
      final tarih = DateTime.now().subtract(
        Duration(days: i),
      ); // Bugün, Dün, Önceki Gün

      for (var santiye in santiyeler) {
        // Rastgele işçi seçimi
        final calisanlar = [
          GunlukCalisma(isci: kaydedilenIsciler[0], durum: "Tam Gün"),
          GunlukCalisma(isci: kaydedilenIsciler[1], durum: "Tam Gün"),
          if (i % 2 == 0)
            GunlukCalisma(
              isci: kaydedilenIsciler[2],
              durum: "Yarım Gün",
            ), // Bazen yarım gün
        ];

        final rapor = GunlukSantiyeRaporu(
          santiyeAdi: santiye,
          tarih: tarih,
          benzinGideri: (i + 1) * 200.0, // Rastgele tutarlar
          yemekGideri: (calisanlar.length * 150.0),
          ekMasraflar: (i % 2 == 0) ? 500.0 : 0.0,
          aciklama: "Otomatik oluşturulan demo raporu (Gün -$i)",
          calisanlar: calisanlar,
        );

        await _ekipRef(teamId).collection('reports').add(rapor.toMap());
      }
    }

    // 4. Ödeme ve Avans Ekle
    await odemeEkle(
      teamId,
      AlinanOdeme(
        miktar: 15000,
        santiyeAdi: santiyeler[0],
        alanKisi: "Müteahhit",
        tarih: DateTime.now().subtract(const Duration(days: 5)),
      ),
    );
    await avansEkle(
      teamId,
      VerilenAvans(
        miktar: 1000,
        isci: kaydedilenIsciler[0],
        tarih: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );

    // 5. İşlem Logu
    await logIslem(teamId, 'DEMO_VERI_YUKLEME', {
      'aciklama': 'Test verileri başarıyla yüklendi.',
    });
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
}
