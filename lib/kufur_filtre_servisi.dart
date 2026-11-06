import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Şantiye Pazarı ve Uygulama İçi Küfür, Argo ve Hakaret Sansür & İhbar Servisi
class KufurFiltreServisi {
  static final List<String> _kufurKelimeleri = [
    'amk',
    'aq',
    'amq',
    'sik',
    'sikerim',
    'sikeyim',
    'sikik',
    'siktir',
    'siktirgit',
    'orospu',
    'piç',
    'pic',
    'yarak',
    'yarrak',
    'yarram',
    'göt',
    'got',
    'göte',
    'götü',
    'ibne',
    'pezevenk',
    'kahpe',
    'oç',
    'oc',
    'sürtük',
    'surtuk',
    'daşşak',
    'dassak',
    'taşak',
    'tasak',
    'ananı',
    'anani',
    'bacını',
    'bacini',
    'ebeni',
    'amına',
    'amina',
    'amcık',
    'amcik',
    'koyim',
    'koyayım',
    'puşt',
    'pust',
    'götveren',
    'gotveren',
    'yarramı',
    'yarrami',
    'yarrağımı',
    'yarragimi',
    'sikiş',
    'sikis',
    'porno',
    'amguard',
    'yavşak',
    'yavsak',
    'gavat',
    'kavat',
    'orospuçocuğu',
    'orospucocugu',
    'ananıavradını',
    'ananisikeyim',
    'ananısikeyim',
    'kahpenin',
    'picin',
    'piçin',
  ];

  /// Verilen metinde küfür veya hakaret olup olmadığını denetler
  static bool kufurIceriyorMu(String metin) {
    if (metin.trim().isEmpty) return false;
    final normalize = _normalizeEt(metin);
    for (final kelime in _kufurKelimeleri) {
      if (normalize.contains(kelime)) return true;
      final reg = RegExp(r'\b' + RegExp.escape(kelime) + r'\b', caseSensitive: false);
      if (reg.hasMatch(normalize)) return true;
    }
    return false;
  }

  /// Metindeki küfür ve argo ifadeleri '***' ile maskeler
  static String sansurle(String metin) {
    if (metin.trim().isEmpty) return metin;
    String sonuc = metin;

    for (final kelime in _kufurKelimeleri) {
      // Kelime bazlı eşleşme
      final reg = RegExp(
        r'(?<![a-zA-ZçğıöşüÇĞİÖŞÜ])' + RegExp.escape(kelime) + r'(?![a-zA-ZçğıöşüÇĞİÖŞÜ])',
        caseSensitive: false,
      );
      sonuc = sonuc.replaceAllMapped(reg, (match) {
        final original = match.group(0)!;
        if (original.length <= 2) return '**';
        return original[0] + ('*' * (original.length - 2)) + original[original.length - 1];
      });

      // Bitişik ve uzun küfürler için
      if (kelime.length >= 3) {
        final reg2 = RegExp(RegExp.escape(kelime), caseSensitive: false);
        sonuc = sonuc.replaceAllMapped(reg2, (match) {
          final original = match.group(0)!;
          return original[0] + ('*' * (original.length - 1));
        });
      }
    }
    return sonuc;
  }

  /// Küfürlü içerik tespit edilirse sansürler ve Firebase'deki 'admin_bildirimler'
  /// koleksiyonuna sistem yöneticisi için anında ihbar kaydı oluşturur
  static Future<String> sansurleVeBildir({
    required String metin,
    required String kaynak, // 'İlan Başlığı', 'İlan Açıklaması', 'Pazar Mesajlaşması'
    required String kullaniciUid,
    required String kullaniciAd,
  }) async {
    final temiz = metin.trim();
    if (!kufurIceriyorMu(temiz)) return temiz;

    final sansurlu = sansurle(temiz);

    try {
      await FirebaseFirestore.instance.collection('admin_bildirimler').add({
        'tur': 'KUFURLU_ICERIK',
        'kaynak': kaynak,
        'kullaniciUid': kullaniciUid,
        'kullaniciAd': kullaniciAd,
        'orijinalMetin': temiz,
        'sansurluMetin': sansurlu,
        'tarih': FieldValue.serverTimestamp(),
        'durum': 'incelenecek',
      });
    } catch (e) {
      debugPrint('Admin bildirimi gönderme hatası: $e');
    }

    return sansurlu;
  }

  static String _normalizeEt(String text) {
    return text
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('!', 'i')
        .replaceAll('\$', 's')
        .replaceAll('.', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('*', '')
        .replaceAll(' ', '');
  }
}

