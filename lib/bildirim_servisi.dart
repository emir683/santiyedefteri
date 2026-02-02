// lib/bildirim_servisi.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// NOT: 'veri_yardimcisi.dart' importunu SİLİN.

class BildirimServisi {
  static final BildirimServisi _instance = BildirimServisi._internal();
  factory BildirimServisi() => _instance;
  BildirimServisi._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher'); // İkon adını düzelttik
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (e) {
      debugPrint("Saat dilimi yüklenemedi: $e");
    }
    
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    await _izinleriIste();
  }
  
  Future<void> _izinleriIste() async {
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await Permission.notification.request();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> _zamanlanmisBildirimOlustur(TimeOfDay saat) async {
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;

    if(!canSchedule) return;

    await flutterLocalNotificationsPlugin.cancelAll();
    final tzTime = _sonrakiBildirimZamani(saat);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, 'Şantiye Yönetim', 'Bugünkü günlük raporu girdiniz mi?',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gunluk_rapor_kanali', 'Günlük Rapor Hatırlatıcı',
          importance: Importance.max, priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
      tz.local, simdi.year, simdi.month, simdi.day,
      saat.hour, saat.minute,
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