import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show navigatorKey;
import 'cad_webgl_ekrani.dart';
import 'bildirim_servisi.dart';

/// Arka planda işlenen CAD çizim görevi modeli
class CadArkaplanGorevi {
  final String fileId;
  final String projeAdi;
  final String webglUrl;
  final DateTime baslangicZamani;
  int gecenSaniye;
  int tahminYuzde;
  bool tamamlandi;
  bool hataVar;

  CadArkaplanGorevi({
    required this.fileId,
    required this.projeAdi,
    required this.webglUrl,
    required this.baslangicZamani,
    this.gecenSaniye = 0,
    this.tahminYuzde = 15,
    this.tamamlandi = false,
    this.hataVar = false,
  });
}

/// CAD Arka Plan Çözümleme ve Bildirim Yöneticisi
/// Büyük projelerin arka planda işlenmesini takip eder ve bittiğinde bildirim gönderir.
class CadArkaplanServisi {
  static final CadArkaplanServisi _instance = CadArkaplanServisi._internal();
  factory CadArkaplanServisi() => _instance;
  CadArkaplanServisi._internal();

  static const String _kCadServerUrl = 'https://urge-beliefs-number-unless.trycloudflare.com';

  final Map<String, CadArkaplanGorevi> _gorevler = {};
  final ValueNotifier<List<CadArkaplanGorevi>> aktifGorevlerNotifier =
      ValueNotifier<List<CadArkaplanGorevi>>([]);

  final Map<String, Timer> _pollingTimers = {};

  /// Yeni bir CAD projesini arka planda takip etmeye başla
  void projeyiArkaPlanaAl({
    required String fileId,
    required String projeAdi,
    required String webglUrl,
  }) {
    if (_gorevler.containsKey(fileId) && !_gorevler[fileId]!.tamamlandi) {
      return;
    }

    final gorev = CadArkaplanGorevi(
      fileId: fileId,
      projeAdi: projeAdi,
      webglUrl: webglUrl,
      baslangicZamani: DateTime.now(),
      gecenSaniye: 1,
      tahminYuzde: 20,
    );

    _gorevler[fileId] = gorev;
    _bildirGuncelleme();

    // Kullanıcıya ekranın altında şık bir bilgi göster
    _gosterBaslangicSnack(projeAdi);

    // Sunucuyu her 3 saniyede bir yokla
    _pollingTimers[fileId]?.cancel();
    _pollingTimers[fileId] = Timer.periodic(const Duration(seconds: 3), (timer) {
      _kontrolEt(fileId);
    });
  }

  Future<void> _kontrolEt(String fileId) async {
    final gorev = _gorevler[fileId];
    if (gorev == null || gorev.tamamlandi) {
      _pollingTimers[fileId]?.cancel();
      return;
    }

    gorev.gecenSaniye = DateTime.now().difference(gorev.baslangicZamani).inSeconds;
    // Tahmini ilerleme (0-92 arası artar)
    gorev.tahminYuzde = (20 + (gorev.gecenSaniye * 2.5)).clamp(20, 92).toInt();
    _bildirGuncelleme();

    // 10 dakika (600 sn) zaman aşımı kontrolü
    if (gorev.gecenSaniye > 600) {
      _pollingTimers[fileId]?.cancel();
      gorev.hataVar = true;
      _bildirGuncelleme();
      return;
    }

    try {
      final metaUrl = '$_kCadServerUrl/files/${fileId}_cad_meta.json';
      final res = await http.head(Uri.parse(metaUrl)).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        // Çözümleme başarıyla bitti!
        _pollingTimers[fileId]?.cancel();
        gorev.tamamlandi = true;
        gorev.tahminYuzde = 100;
        _bildirGuncelleme();

        // 1. Sistem Push Bildirimi Gönder
        await BildirimServisi().cadCizimiHazirBildirimiGonder(
          projeAdi: gorev.projeAdi,
          webglUrl: gorev.webglUrl,
          fileId: fileId,
        );

        // 2. Uygulama içi Üst Bildirim / Banner Göster
        _gosterTamamlandiBanner(gorev);
      }
    } catch (_) {
      // Ağ geçişi veya geçici gecikmelerde yoklamaya devam et
    }
  }

  void _bildirGuncelleme() {
    aktifGorevlerNotifier.value = _gorevler.values.toList();
  }

  void _gosterBaslangicSnack(String projeAdi) {
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CAD Çizimi Arka Plana Alındı',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '$projeAdi hazırlanıyor. Tamamlandığında bildirim alacaksınız.',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F7C86),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _gosterTamamlandiBanner(CadArkaplanGorevi gorev) {
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CAD Çizimi Hazır! 🏗️',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                    ),
                    Text(
                      '${gorev.projeAdi} görüntülenebilir.',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(navContext).hideCurrentSnackBar();
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => CadWebglEkrani(
                        webglUrl: gorev.webglUrl,
                        projeAdi: gorev.projeAdi,
                      ),
                    ),
                  );
                },
                child: const Text('Çizimi Aç', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }
  }
}
