import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum SyncStatus {
  online,
  offline,
  syncing,
}

/// Şantiye sahasında kesintisiz çevrimdışı çalışma ve otomatik
/// arka plan senkronizasyonunu yöneten merkezi servis.
class ConnectivitySyncService with ChangeNotifier {
  static final ConnectivitySyncService instance =
      ConnectivitySyncService._internal();

  ConnectivitySyncService._internal();

  SyncStatus _status = SyncStatus.online;
  SyncStatus get status => _status;

  bool get isOffline => _status == SyncStatus.offline;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get isOnline => _status == SyncStatus.online;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _initialized = false;
  bool _isSyncingProcess = false;

  /// Firestore çevrimdışı kalıcılığını (offline persistence) başlatır
  /// ve ağ durumu dinleyicisini kurar.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Firestore kalıcılık ve sınırsız önbellek ayarları
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint(
        "✅ [OfflineSync] Firestore çevrimdışı kalıcılık (offline persistence) aktifleştirildi (CACHE_SIZE_UNLIMITED).",
      );
    } catch (e) {
      debugPrint(
        "ℹ️ [OfflineSync] Firestore ayarları daha önce yapılandırılmış veya desteklenmiyor: $e",
      );
    }

    // 2. İlk ağ kontrolü
    try {
      final initial = await Connectivity().checkConnectivity();
      await _handleConnectivityChange(initial);
    } catch (e) {
      debugPrint("⚠️ [OfflineSync] İlk ağ kontrolü hatası: $e");
    }

    // 3. Ağ değişimlerini sürekli dinle
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _handleConnectivityChange(results);
    });
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final hasInterface =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (!hasInterface) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    // Arayüz var (WiFi veya Hücresel), gerçek internet erişimini doğrula
    final hasRealInternet = await _checkRealInternetAccess();

    if (!hasRealInternet) {
      _updateStatus(SyncStatus.offline);
    } else {
      // Çevrimdışından çevrimiçine geçiş -> Otomatik senkronizasyonu tetikle!
      final wasOffline = _status == SyncStatus.offline;
      if (wasOffline) {
        _triggerAutoSync();
      } else if (_status != SyncStatus.syncing) {
        _updateStatus(SyncStatus.online);
      }
    }
  }

  /// Cihazın sadece modeme bağlı olmayıp gerçekten internete çıkabildiğini test eder.
  Future<bool> _checkRealInternetAccess() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Bekleyen tüm yerel Firestore yazmalarını arka planda buluta aktarır
  Future<void> _triggerAutoSync() async {
    if (_isSyncingProcess) return;
    _isSyncingProcess = true;

    _updateStatus(SyncStatus.syncing);

    try {
      // Olası askıya alınmış ağ bağlantısını aç
      await FirebaseFirestore.instance.enableNetwork();

      // Yerel kuyrukta biriken tüm yazma işlemlerinin sunucuya iletilmesini bekle
      await FirebaseFirestore.instance
          .waitForPendingWrites()
          .timeout(const Duration(seconds: 15));

      _lastSyncTime = DateTime.now();
      _updateStatus(SyncStatus.online);
      debugPrint(
        "✅ [OfflineSync] Tüm yerel rapor ve puantajlar Firestore ile eşitlendi. Saat: $_lastSyncTime",
      );
    } catch (e) {
      debugPrint("ℹ️ [OfflineSync] Eşitleme arka planda devam ediyor: $e");
      _lastSyncTime = DateTime.now();
      _updateStatus(SyncStatus.online);
    } finally {
      _isSyncingProcess = false;
    }
  }

  /// Kullanıcı "Şimdi Eşitle" butonuna bastığında çağrılır
  Future<bool> syncNow() async {
    final hasNet = await _checkRealInternetAccess();
    if (!hasNet) {
      _updateStatus(SyncStatus.offline);
      return false;
    }
    await _triggerAutoSync();
    return true;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
