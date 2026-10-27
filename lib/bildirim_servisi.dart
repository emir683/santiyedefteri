import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_plus/flutter_local_notifications_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'main.dart' show navigatorKey;
import 'cad_webgl_ekrani.dart';
import 'haftalik_ozet_ekrani.dart';
import 'gunluk_rapor_ekrani.dart';

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
    );
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
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
        handleNotificationPayload(response.payload);
      },
    );

    // Soğuk başlatma: Uygulama tamamen kapalıyken bildirime tıklanarak açıldıysa
    try {
      final launchDetails =
          await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          handleNotificationPayload(payload);
        }
      }
    } catch (e) {
      debugPrint("Bildirim soğuk başlatma kontrolü hatası: $e");
    }
  }

  static void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('🔔 Bildirim payload alındı: $payload');

    if (payload.startsWith('cad_project:')) {
      final data = payload.substring('cad_project:'.length).split('|');
      if (data.isNotEmpty) {
        final url = data[0];
        final title = data.length > 1 ? data[1] : 'CAD Çizimi';
        _navigateToCadViewer(url, title);
      }
    } else if (payload.startsWith('weekly_summary:')) {
      final teamId = payload.substring('weekly_summary:'.length).trim();
      if (teamId.isNotEmpty) {
        _navigateToWeeklySummary(teamId);
      }
    } else if (payload.startsWith('daily_report:')) {
      final teamId = payload.substring('daily_report:'.length).trim();
      if (teamId.isNotEmpty) {
        _navigateToDailyReport(teamId);
      }
    }
  }

  static void _navigateToCadViewer(String url, String title) {
    void doNavigate() {
      final navState = navigatorKey.currentState;
      if (navState == null) {
        Future.delayed(const Duration(milliseconds: 200), doNavigate);
        return;
      }
      navState.push(
        MaterialPageRoute(
          builder: (_) => CadWebglEkrani(
            webglUrl: url,
            projeAdi: title,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static void _navigateToWeeklySummary(String teamId) {
    void doNavigate() {
      final navState = navigatorKey.currentState;
      if (navState == null) {
        Future.delayed(const Duration(milliseconds: 200), doNavigate);
        return;
      }
      navState.push(
        MaterialPageRoute(
          builder: (_) => HaftalikOzetEkrani(teamId: teamId),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static void _navigateToDailyReport(String teamId) {
    void doNavigate() {
      final navState = navigatorKey.currentState;
      if (navState == null) {
        Future.delayed(const Duration(milliseconds: 200), doNavigate);
        return;
      }
      navState.push(
        MaterialPageRoute(
          builder: (_) => GunlukRaporEkrani(teamId: teamId),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static int _notifIdFromFileId(String fileId) {
    if (fileId.isEmpty) return 77777;
    return (fileId.hashCode.abs() % 80000) + 10000;
  }

  /// Arka planda işlenen CAD çizimi için canlı progress bar bildirimini gösterir/günceller
  Future<void> cadIlerlemeBildirimiGuncelle({
    required String fileId,
    required String projeAdi,
    required String webglUrl,
    required int progressPercent,
    String? durumAciklamasi,
  }) async {
    // iOS bildirim merkezinde Android tarzı sessiz progress-bar kanalı olmadığı için
    // her 3 saniyede bir bildirim düşmesini engelle (iOS'ta yalnızca tamamlandığında bildirim gösterilir).
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    final int notifId = _notifIdFromFileId(fileId);
    final int clampedProgress = progressPercent.clamp(0, 100);

    final androidDetails = AndroidNotificationDetails(
      'cad_progress_kanali',
      'CAD Çizim İlerlemesi',
      channelDescription: 'CAD çizimleri arka planda hazırlanırken canlı ilerleme durumu',
      icon: _androidNotificationIcon,
      color: const Color(0xFF0F7C86),
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: clampedProgress,
      subText: '%$clampedProgress',
    );

    final details = NotificationDetails(android: androidDetails);
    final String body = durumAciklamasi ?? '$projeAdi (%$clampedProgress tamamlandı)';

    await flutterLocalNotificationsPlugin.show(
      notifId,
      'CAD Çizimi Hazırlanıyor... 🏗️',
      body,
      details,
      payload: 'cad_project:$webglUrl|$projeAdi',
    );
  }

  /// Arka plan işlemi bittiğinde veya iptal edildiğinde progress bar bildirimini kapatır
  Future<void> cadIlerlemeBildiriminiKapat(String fileId) async {
    final int notifId = _notifIdFromFileId(fileId);
    try {
      await flutterLocalNotificationsPlugin.cancel(notifId);
    } catch (_) {}
  }

  /// CAD Çizimi hazır olduğunda anında yerel bildirim gönderir
  Future<void> cadCizimiHazirBildirimiGonder({
    required String projeAdi,
    required String webglUrl,
    String? fileId,
  }) async {
    final int notifId = _notifIdFromFileId(fileId ?? '');
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
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      notifId,
      'CAD Çizimi Hazır! 🏗️',
      '$projeAdi başarıyla çözümlendi. Görüntülemek için dokunun.',
      details,
      payload: 'cad_project:$webglUrl|$projeAdi',
    );
  }

  /// Hava durumu saha uyarısı gönderir (Yağmur, don veya fırtına durumunda)
  Future<void> havaDurumuSahaUyarisiGonder({
    required String sehir,
    required String aciklama,
    required String tavsiye,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'saha_hava_kanali',
      'Saha Hava Durumu Uyarıları',
      channelDescription: 'Şantiyede yağış, fırtına veya don riski uyarıları',
      icon: _androidNotificationIcon,
      color: Color(0xFF0284C7),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      9001,
      '🌧️ Saha Hava Uyarısı: $sehir',
      '$aciklama. $tavsiye',
      details,
    );
  }

  /// Akıllı kontrol: Bugün puantaj veya rapor girilmiş mi kontrol eder, girilmediyse uyarır
  Future<void> akilliPuantajKontrolVeUyar({
    required String teamId,
  }) async {
    try {
      final now = DateTime.now();
      final bugunBaslangic = DateTime(now.year, now.month, now.day);
      final bugunBitis = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('reports')
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(bugunBaslangic))
          .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(bugunBitis))
          .limit(1)
          .get();

      // Bugün en az 1 rapor girilmişse kullanıcıyı rahatsız etme!
      if (snap.docs.isNotEmpty) {
        debugPrint('✅ Bugün rapor zaten girilmiş, akıllı hatırlatıcı atlandı.');
        return;
      }

      // Bugün hiç rapor girilmemiş, bildirimi göster!
      const androidDetails = AndroidNotificationDetails(
        'gunluk_rapor_kanali',
        'Günlük Rapor Hatırlatıcı',
        icon: _androidNotificationIcon,
        color: Color(0xFF14B8A6),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        '⚠️ Eksik Puantaj & Rapor Uyarısı',
        'Bugün henüz hiçbir şantiye raporu veya puantaj girilmedi. Gününüzü kaydetmek için dokunun.',
        details,
        payload: 'daily_report:$teamId',
      );
    } catch (e) {
      debugPrint("Akıllı puantaj kontrolü hatası: $e");
    }
  }

  Future<void> _zamanlanmisGenericBildirim({
    required int id,
    required String title,
    required String body,
    required TimeOfDay saat,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final canSchedule =
          await androidPlugin?.canScheduleExactNotifications() ?? false;

      if (!canSchedule) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    await flutterLocalNotificationsPlugin.cancel(id);
    final tzTime = _sonrakiBildirimZamani(saat);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: _androidNotificationIcon,
          color: const Color(0xFF14B8A6),
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> gunlukHatirlatmaAyarlaSimple(TimeOfDay saat) async {
    await planlaPuantajHatirlatici(saat: saat.hour, dakika: saat.minute);
  }

  Future<void> planlaPuantajHatirlatici({
    required int saat,
    required int dakika,
  }) async {
    await _zamanlanmisGenericBildirim(
      id: 0,
      title: 'Şantiye Puantaj Defteri',
      body: 'Bugünkü günlük raporu ve puantajları girdiniz mi?',
      saat: TimeOfDay(hour: saat, minute: dakika),
      channelId: 'gunluk_rapor_kanali',
      channelName: 'Günlük Rapor Hatırlatıcı',
    );
  }

  Future<void> iptalEtPuantajHatirlatici() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> planlaHavaDurumuHatirlatici({int saat = 8, int dakika = 0}) async {
    await _zamanlanmisGenericBildirim(
      id: 9001,
      title: '🌤️ Saha Koşulları & Hava Durumu',
      body: 'Güne başlamadan önce şantiye hava durumunu ve saha koşullarını kontrol etmeyi unutmayın.',
      saat: TimeOfDay(hour: saat, minute: dakika),
      channelId: 'hava_durumu_kanali',
      channelName: 'Saha Koşulları & Hava Durumu Hatırlatıcı',
    );
  }

  Future<void> iptalEtHavaDurumuHatirlatici() async {
    await flutterLocalNotificationsPlugin.cancel(9001);
  }

  Future<void> planlaOdemeHatirlatici({int saat = 10, int dakika = 0}) async {
    await _zamanlanmisGenericBildirim(
      id: 9002,
      title: '💰 Finans & Hakediş Hatırlatıcısı',
      body: 'Vadesi yaklaşan ödemeleri, işçi hakedişlerini ve bekleyen avansları gözden geçirin.',
      saat: TimeOfDay(hour: saat, minute: dakika),
      channelId: 'odeme_kanali',
      channelName: 'Ödeme ve Hakediş Hatırlatıcı',
    );
  }

  Future<void> iptalEtOdemeHatirlatici() async {
    await flutterLocalNotificationsPlugin.cancel(9002);
  }

  Future<void> planlaCadHatirlatici({int saat = 14, int dakika = 0}) async {
    await _zamanlanmisGenericBildirim(
      id: 9003,
      title: '📐 Proje & Çizim Güncellemeleri',
      body: 'Şantiyenizdeki güncel dwg çizimlerini ve yeni mimari revizyonları kontrol edin.',
      saat: TimeOfDay(hour: saat, minute: dakika),
      channelId: 'cad_kanali',
      channelName: 'Projeler ve CAD Çizimleri',
    );
  }

  Future<void> iptalEtCadHatirlatici() async {
    await flutterLocalNotificationsPlugin.cancel(9003);
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
