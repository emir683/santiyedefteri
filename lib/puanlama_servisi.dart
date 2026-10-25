import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/puanlama_diyalogu.dart';

class PuanlamaServisi {
  static const String _packageName = 'com.emircf.santiyepuantaj';
  static const String _successfulActionCountKey =
      'puanlama_basarili_islem_sayisi';
  static const String _lastPromptAtKey = 'puanlama_son_gosterim_zamani';
  static const String _remindAfterKey = 'puanlama_tekrar_sorma_zamani';
  static const String _ratedKey = 'puanlama_verildi';

  static const int _firstPromptActionCount = 3; // 3 başarılı işlemden sonra
  static const Duration _promptCooldown = Duration(days: 30); // 30 gün aralık
  static const Duration _remindLaterDelay = Duration(days: 7); // 7 gün sonra tekrar

  /// Başarılı bir işlem sonrası kontrol eder ve uygunsa diyaloğu açar
  static Future<void> islemSonrasiKontrolEtVeGoster(BuildContext context) async {
    try {
      final shouldShow = await shouldShowAfterSuccessfulAction();
      if (shouldShow && context.mounted) {
        await markPromptShown();
        await diyalogGoster(context);
      }
    } catch (e) {
      debugPrint('Puanlama kontrolü hatası: $e');
    }
  }

  /// Menüden veya ayarlardan kullanıcı istediği zaman direkt açar
  static Future<void> diyalogGoster(BuildContext context) async {
    await PuanlamaDiyalogu.goster(context);
  }

  static Future<bool> shouldShowAfterSuccessfulAction() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_ratedKey) ?? false) return false;

    final now = DateTime.now();
    final remindAfterMs = prefs.getInt(_remindAfterKey);
    if (remindAfterMs != null &&
        now.isBefore(DateTime.fromMillisecondsSinceEpoch(remindAfterMs))) {
      return false;
    }

    final actionCount = (prefs.getInt(_successfulActionCountKey) ?? 0) + 1;
    await prefs.setInt(_successfulActionCountKey, actionCount);
    if (actionCount < _firstPromptActionCount) return false;

    final lastPromptMs = prefs.getInt(_lastPromptAtKey);
    if (lastPromptMs != null) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      if (now.difference(lastPrompt) < _promptCooldown) return false;
    }

    return true;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastPromptAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> remindLater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _remindAfterKey,
      DateTime.now().add(_remindLaterDelay).millisecondsSinceEpoch,
    );
  }

  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ratedKey, true);
  }

  /// Geri bildirim mesajını ve puanını Firestore'a kaydeder
  static Future<void> geriBildirimKaydet({
    required int puan,
    String? mesaj,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String version = 'bilinmiyor';
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      await FirebaseFirestore.instance.collection('feedbacks').add({
        'puan': puan,
        'mesaj': mesaj ?? '',
        'kullaniciId': user?.uid,
        'email': user?.email,
        'appVersion': version,
        'tarih': FieldValue.serverTimestamp(),
        'durum': 'yeni',
      });
    } catch (e) {
      debugPrint('Geri bildirim Firestore kayıt hatası: $e');
    }
  }

  static Future<void> openStore() async {
    if (!kIsWeb && Platform.isIOS) {
      final appStoreUri = Uri.parse('itms-apps://itunes.apple.com/app/id6741753947?action=write-review');
      final webAppStoreUri = Uri.parse('https://apps.apple.com/app/santiye-puantaj-defteri/id6741753947');
      final testflightUri = Uri.parse('itms-beta://');
      try {
        if (await canLaunchUrl(appStoreUri)) {
          await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
          return;
        }
        if (await canLaunchUrl(webAppStoreUri)) {
          await launchUrl(webAppStoreUri, mode: LaunchMode.externalApplication);
          return;
        }
        if (await canLaunchUrl(testflightUri)) {
          await launchUrl(testflightUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('iOS mağaza açma hatası: $e');
      }
      return;
    }

    final marketUri = Uri.parse('market://details?id=$_packageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_packageName',
    );

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Mağaza açma hatası: $e');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
