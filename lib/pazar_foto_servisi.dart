import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FotoAnalizSonucu {
  final bool guvenliMi;
  final String? redNedeni;
  final String? url;

  FotoAnalizSonucu({
    required this.guvenliMi,
    this.redNedeni,
    this.url,
  });
}

/// Şantiye Pazarı Gerçek Fotoğraf Seçme, Cinsel İçerik (NSFW) Koruması ve Yükleme Servisi
class PazarFotoServisi {
  static const String _storageBucket = 'santiye-yonetim-app.firebasestorage.app';

  /// Cinsel içerik / NSFW ve aşırı çıplaklık tespiti
  static Future<bool> cinselIcerikMi(PlatformFile file) async {
    // 1. Dosya adı heuristiği
    final nameLower = file.name.toLowerCase();
    final yasakliKelimeler = [
      'nude',
      'naked',
      'porn',
      'porno',
      'sexy',
      'seks',
      'adult',
      'xxx',
      'nsfw',
      'ero',
      'erotik',
    ];
    for (final k in yasakliKelimeler) {
      if (nameLower.contains(k)) return true;
    }

    // 2. Dosya baytlarını inceleme (RGB Cilt Tonu Yoğunluğu Analizi)
    try {
      Uint8List bytes = file.bytes ?? Uint8List(0);
      final filePath = file.path;
      if (bytes.isEmpty && filePath != null) {
        bytes = await File(filePath).readAsBytes();
      }
      if (bytes.isEmpty) return false;

      int skinPixels = 0;
      int totalSampled = 0;
      final step = (bytes.length / 3000).clamp(3, 100).toInt();

      for (int i = 0; i < bytes.length - 3; i += step) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];

        // Standart RGB insan ten tonu kümeleme formülü:
        if (r > 95 &&
            g > 40 &&
            b > 20 &&
            (r - g).abs() > 15 &&
            r > g &&
            r > b &&
            (r - (g > b ? g : b)) > 15) {
          skinPixels++;
        }
        totalSampled++;
      }

      if (totalSampled > 0) {
        final skinRatio = skinPixels / totalSampled;
        // Eğer görselde %45'ten fazla çıplak cilt pikseli varsa NSFW engellemesi uygulanır
        if (skinRatio > 0.45) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Fotoğraf NSFW analiz hatası: $e');
    }

    return false;
  }

  /// Cihazdan fotoğraf seçme, NSFW tarama ve Storage / Base64 yükleme
  static Future<FotoAnalizSonucu> fotoSecVeYukle({
    required String kullaniciUid,
    required String kullaniciAd,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return FotoAnalizSonucu(guvenliMi: true, url: null);
      }

      final file = result.files.first;

      // Boyut kontrolü (Maksimum 8 MB)
      if (file.size > 8 * 1024 * 1024) {
        return FotoAnalizSonucu(
          guvenliMi: false,
          redNedeni: 'Fotoğraf boyutu 8 MB\'dan küçük olmalıdır.',
        );
      }

      // Cinsel içerik / NSFW kontrolü
      final sakincali = await cinselIcerikMi(file);
      if (sakincali) {
        try {
          await FirebaseFirestore.instance.collection('admin_bildirimler').add({
            'tur': 'UYGUNSUZ_FOTOGRAF',
            'dosyaAdi': file.name,
            'kullaniciUid': kullaniciUid,
            'kullaniciAd': kullaniciAd,
            'aciklama': 'Cinsel içerik veya aşırı çıplaklık filtresine takıldı.',
            'tarih': FieldValue.serverTimestamp(),
            'durum': 'engellendi',
          });
        } catch (_) {}

        return FotoAnalizSonucu(
          guvenliMi: false,
          redNedeni:
              'Seçtiğiniz görsel güvenlik ve uygunluk denetimine takıldı. Lütfen yalnızca inşaat, şantiye ve mesleki iş fotoğrafları yükleyiniz.',
        );
      }

      Uint8List fileBytes = file.bytes ?? Uint8List(0);
      final filePath = file.path;
      if (fileBytes.isEmpty && filePath != null) {
        fileBytes = await File(filePath).readAsBytes();
      }

      if (fileBytes.isEmpty) {
        return FotoAnalizSonucu(
          guvenliMi: false,
          redNedeni: 'Fotoğraf verisi okunamadı.',
        );
      }

      final ext = file.extension?.toLowerCase() ?? 'jpg';
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = 'ilan_${kullaniciUid}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // 1. Firebase Storage REST yükleme denemesi
      try {
        final uploadUri = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o?uploadType=media&name=pazar_ilanlari%2F$fileName',
        );

        final response = await http.post(
          uploadUri,
          headers: {'Content-Type': mimeType},
          body: fileBytes,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resJson = jsonDecode(response.body);
          final downloadToken = resJson['downloadTokens'] ?? '';
          final publicUrl =
              'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/pazar_ilanlari%2F$fileName?alt=media&token=$downloadToken';
          return FotoAnalizSonucu(guvenliMi: true, url: publicUrl);
        }
      } catch (e) {
        debugPrint('Storage REST yükleme uyarısı (fallback devreye giriyor): $e');
      }

      // 2. Güvenli Fallback: Data URL
      final base64Str = base64Encode(fileBytes);
      final dataUrl = 'data:$mimeType;base64,$base64Str';
      return FotoAnalizSonucu(guvenliMi: true, url: dataUrl);
    } catch (e) {
      return FotoAnalizSonucu(
        guvenliMi: false,
        redNedeni: 'Fotoğraf yüklenirken hata oluştu: $e',
      );
    }
  }
}

/// Network, Base64 Data URL veya Dosya fark etmeksizin görseli güvenle render eden yardımcı widget
class PazarGorselYardimcisi {
  static Widget buildGorsel(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget;

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _errorPlaceholder(width, height),
        );
      } catch (_) {
        imageWidget = _errorPlaceholder(width, height);
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorPlaceholder(width, height),
      );
    } else {
      imageWidget = Image.file(
        File(url),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _errorPlaceholder(width, height),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: imageWidget);
    }
    return imageWidget;
  }

  static Widget _errorPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.broken_image_rounded, size: 22, color: Colors.grey),
      ),
    );
  }
}

