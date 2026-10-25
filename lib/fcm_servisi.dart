// lib/fcm_servisi.dart
//
// FCM (Firebase Cloud Messaging) token yönetimi ve mesaj işleme.
// - Kullanıcı giriş yaptığında token'ı Firestore'a kaydeder
// - Uygulama arka planda/kapalıyken gelen bildirimler için handler sağlar
// - Uygulama açılınca bildirime tıklanma durumunu işler ve ilgili ekrana yönlendirir

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';
import 'main.dart' show navigatorKey;
import 'cad_webgl_ekrani.dart' show CadWebglEkrani;
import 'haftalik_ozet_ekrani.dart' show HaftalikOzetEkrani;
import 'gunluk_rapor_ekrani.dart' show GunlukRaporEkrani;
import 'isci_ekrani.dart' show IsciEkrani;
import 'odemeler_ekrani.dart' show OdemelerEkrani;
import 'ekip_yonetimi_ekrani.dart' show EkipYonetimiEkrani;
import 'bildirim_servisi.dart' show BildirimServisi;

// Uygulama KAPALI iken gelen FCM mesajlarını işleyen top-level handler.
// Bu fonksiyon main() dışında, global scope'ta olmalı.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [FCM Arka Plan] Mesaj geldi: ${message.messageId}');
}

class FcmServisi {
  static final FcmServisi _instance = FcmServisi._internal();
  factory FcmServisi() => _instance;
  FcmServisi._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Yerel bildirim için kanal (FCM payload'ından yerel bildirim göstermek için)
  static const AndroidNotificationChannel _kanal = AndroidNotificationChannel(
    'santiye_bildirim_kanali',
    'Şantiye Bildirimleri',
    description: 'Admin işlemleri ve ekip güncellemeleri için bildirimler.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Uygulamayı ilk başlatınca çağrılır.
  /// İzinleri ister, token'ı kaydeder, handler'ları ayarlar.
  Future<void> init() async {
    if (kIsWeb) return;

    // 1. Yerel bildirim kanalını Android'e kaydet
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_kanal);

    // 2. Yerel bildirim plugin'ini başlat
    const androidSettings = AndroidInitializationSettings(
      '@drawable/notification_icon',
    );
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        BildirimServisi.handleNotificationPayload(response.payload);
      },
    );

    // iOS ön plan bildirimlerini etkinleştir
    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // 3. FCM izin durumu kontrolü
    final settings = await _fcm.getNotificationSettings();
    debugPrint('🔔 FCM izin durumu: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await _tokenKaydet();

      _fcm.onTokenRefresh.listen((yeniToken) {
        _tokenFirestoreGuncelle(yeniToken);
      });
    }

    // 4. Uygulama AÇIK/ÖN PLANDA iken gelen FCM mesajını göster
    FirebaseMessaging.onMessage.listen(_onMesajGeldi);

    // 5. Uygulama ARKA PLANDA iken bildirime tıklanınca
    FirebaseMessaging.onMessageOpenedApp.listen(_onBildirimTiklandi);

    // 6. Uygulama KAPALI iken bildirime tıklanınca başlatma
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _onBildirimTiklandi(initialMessage);
    }
  }

  /// Kullanıcı giriş yaptıktan sonra token'ını Firestore'a kaydet.
  Future<void> kullaniciBagla() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _tokenKaydet();
  }

  /// Kullanıcı çıkış yaptığında token'ı temizle
  Future<void> kullaniciAyril() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .update({
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.delete(),
          })
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  // --- ÖZEL METODLAR ---

  Future<void> _tokenKaydet() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final currentSettings = await _fcm.getNotificationSettings();
        if (currentSettings.authorizationStatus ==
            AuthorizationStatus.notDetermined) {
          await _fcm.requestPermission(alert: true, badge: true, sound: true);
        }
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _fcm.getAPNSToken();
        }
      }

      final token = await _fcm.getToken();
      if (token == null) return;
      await _tokenFirestoreGuncelle(token);
    } catch (e) {
      debugPrint('FCM token kaydedilemedi: $e');
    }
  }

  Future<void> _tokenFirestoreGuncelle(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token kaydedildi.');
    } catch (e) {
      debugPrint('FCM token Firestore güncellenemedi: $e');
    }
  }

  /// Uygulama ön planda iken gelen mesajı yerel bildirim olarak göster.
  Future<void> _onMesajGeldi(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint('🔔 FCM ön plan mesaj: ${notification.title}');

    String? payload;
    final action = message.data['action'] ?? message.data['islemTipi'];
    final teamId = message.data['teamId']?.toString() ?? '';

    if (action == 'cad_project') {
      final webglUrl = message.data['webgl_url']?.toString() ?? '';
      final projectName =
          message.data['project_name']?.toString() ?? 'CAD Çizimi';
      payload = 'cad_project:$webglUrl|$projectName';
    } else if (action == 'HAFTALIK_OZET' || action == 'weekly_summary') {
      payload = 'weekly_summary:$teamId';
    } else if (action == 'daily_report' || action == 'GUNLUK_RAPOR_EKLEME') {
      payload = 'daily_report:$teamId';
    }

    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kanal.id,
          _kanal.name,
          channelDescription: _kanal.description,
          icon: '@drawable/notification_icon',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF14B8A6),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Bildirime tıklanınca ne yapılacağı (Deep Navigation).
  void _onBildirimTiklandi(RemoteMessage message) {
    debugPrint('🔔 Bildirime tıklandı: ${message.data}');
    final action = message.data['action'] ?? message.data['islemTipi'];
    final teamId = message.data['teamId']?.toString() ?? '';

    void navigate(Widget page) {
      Future.delayed(const Duration(milliseconds: 350), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => page),
        );
      });
    }

    if (action == 'cad_project') {
      final webglUrl = message.data['webgl_url']?.toString();
      final projectName =
          message.data['project_name']?.toString() ?? 'CAD Çizimi';
      if (webglUrl != null && webglUrl.isNotEmpty) {
        navigate(CadWebglEkrani(webglUrl: webglUrl, projeAdi: projectName));
      }
    } else if (action == 'HAFTALIK_OZET' || action == 'weekly_summary') {
      if (teamId.isNotEmpty) {
        navigate(HaftalikOzetEkrani(teamId: teamId));
      }
    } else if (action == 'daily_report' ||
        action == 'GUNLUK_RAPOR_EKLEME' ||
        action == 'GUNLUK_RAPOR_GUNCELLEME') {
      if (teamId.isNotEmpty) {
        navigate(GunlukRaporEkrani(teamId: teamId));
      }
    } else if (action == 'ISCI_EKLEME' ||
        action == 'ISCI_GUNCELLEME' ||
        action == 'ISCI_KART_ESLESMESI') {
      if (teamId.isNotEmpty) {
        navigate(IsciEkrani(teamId: teamId));
      }
    } else if (action == 'ODEME_EKLEME' || action == 'AVANS_EKLEME') {
      if (teamId.isNotEmpty) {
        navigate(OdemelerEkrani(teamId: teamId));
      }
    } else if (action == 'ROL_DEGISIMI' || action == 'EKIBE_KATILIM') {
      if (teamId.isNotEmpty) {
        navigate(EkipYonetimiEkrani(teamId: teamId));
      }
    }
  }
}
