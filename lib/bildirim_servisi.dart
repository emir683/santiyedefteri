// lib/bildirim_servisi.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'main.dart' show navigatorKey;
import 'cad_webgl_ekrani.dart';

// NOT: 'veri_yardimcisi.dart' importunu SİLİN.

class BildirimServisi {
  static const String _androidNotificationIcon = '@drawable/notification_icon';

  static final BildirimServisi _instance = BildirimServisi._internal();
  factory BildirimServisi() => _instance;
  BildirimServisi._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings(
      _androidNotificationIcon,
    ); // İkon adını düzelttik
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (e) {
      debugPrint("Saat dilimi yüklenemedi: $e");
    }

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('cad_project:')) {
          final data = payload.substring('cad_project:'.length).split('|');
          if (data.isNotEmpty) {
            final url = data[0];
            final title = data.length > 1 ? data[1] : 'CAD Çizimi';
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => CadWebglEkrani(
                  webglUrl: url,
                  projeAdi: title,
                ),
              ),
            );
          }
        }
      },
    );
    await _izinleriIste();
  }

  /// CAD Çizimi hazır olduğunda anında yerel bildirim gönderir
  Future<void> cadCizimiHazirBildirimiGonder({
    required String projeAdi,
    required String webglUrl,
    String? fileId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'cad_islem_kanali',
      'CAD Çizim Bildirimleri',
      channelDescription: 'CAD çizim çözümleme tamamlanma bildirimleri',
      icon: _androidNotificationIcon,
      color: Color(0xFF0F7C86),
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'CAD Çizimi Hazır! 🏗️',
      '$projeAdi başarıyla çözümlendi. Görüntülemek için dokunun.',
      details,
      payload: 'cad_project:$webglUrl|$projeAdi',
    );
  }

  Future<void> _izinleriIste() async {
    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await Permission.notification.request();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> _zamanlanmisBildirimOlustur(TimeOfDay saat) async {
    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final canSchedule =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    if (!canSchedule) return;

    await flutterLocalNotificationsPlugin.cancelAll();
    final tzTime = _sonrakiBildirimZamani(saat);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Şantiye Puantaj Defteri',
      'Bugünkü günlük raporu girdiniz mi?',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gunluk_rapor_kanali',
          'Günlük Rapor Hatırlatıcı',
          icon: _androidNotificationIcon,
          color: Color(0xFF14B8A6),
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // --- DÜZELTİLEN KISIM ---
  // Artık UygulamaVerisi parametresi almıyor.
  Future<void> gunlukHatirlatmaAyarlaAkilli(TimeOfDay saat) async {
    // Şimdilik akıllı kontrolü kapattık, direkt bildirimi kuruyoruz.
    // İleride Firestore'dan kontrol eklenebilir.
    await _zamanlanmisBildirimOlustur(saat);
  }

  Future<void> gunlukHatirlatmaAyarlaSimple(TimeOfDay saat) async {
    await _zamanlanmisBildirimOlustur(saat);
  }

  tz.TZDateTime _sonrakiBildirimZamani(TimeOfDay saat) {
    final simdi = tz.TZDateTime.now(tz.local);
    var zaman = tz.TZDateTime(
      tz.local,
      simdi.year,
      simdi.month,
      simdi.day,
      saat.hour,
      saat.minute,
    );
    if (zaman.isBefore(simdi)) {
      zaman = zaman.add(const Duration(days: 1));
    }
    return zaman;
  }

  Future<void> tumBildirimleriIptalEt() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
