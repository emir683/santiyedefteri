import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceProvider with ChangeNotifier {
  bool _isPerformanceMode = false;
  bool _isAutoDetected = false;
  String _detectionReason = '';

  bool get isPerformanceMode => _isPerformanceMode;
  bool get isAutoDetected => _isAutoDetected;
  String get detectionReason => _detectionReason;

  PerformanceProvider({
    required bool isPerformanceMode,
    bool isAutoDetected = false,
    String detectionReason = '',
  }) {
    _isPerformanceMode = isPerformanceMode;
    _isAutoDetected = isAutoDetected;
    _detectionReason = detectionReason;
  }

  /// Herhangi bir widget'tan hızlıca performans modunu sorgulamak için statik yardımcı
  static bool of(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<PerformanceProvider>(
        context,
        listen: listen,
      ).isPerformanceMode;
    } catch (_) {
      return false;
    }
  }

  /// SharedPreferences'tan anında senkron şekilde yükler (UI'ı asla bekletmez)
  static PerformanceProvider createSync(SharedPreferences prefs) {
    const String key = 'isPerformanceMode';
    const String autoKey = 'isPerformanceModeAutoDetected';
    const String reasonKey = 'performanceModeReason';

    final savedVal = prefs.getBool(key) ?? false;
    return PerformanceProvider(
      isPerformanceMode: savedVal,
      isAutoDetected: prefs.getBool(autoKey) ?? false,
      detectionReason: prefs.getString(reasonKey) ?? 'Standart',
    );
  }

  /// Uygulama başlarken tercihi yükler veya ilk defa açılıyorsa cihaz donanımını analiz eder
  static Future<PerformanceProvider> initialize(SharedPreferences prefs) async {
    const String key = 'isPerformanceMode';
    const String autoKey = 'isPerformanceModeAutoDetected';
    const String reasonKey = 'performanceModeReason';

    final savedVal = prefs.getBool(key);
    if (savedVal != null) {
      return PerformanceProvider(
        isPerformanceMode: savedVal,
        isAutoDetected: prefs.getBool(autoKey) ?? false,
        detectionReason: prefs.getString(reasonKey) ?? '',
      );
    }

    // İlk kurulum / ilk açılış: Cihaz özelliklerini incele
    bool autoEnable = false;
    String reason = 'Standart Donanım';

    try {
      if (!kIsWeb) {
        final cpuCount = Platform.numberOfProcessors;
        if (cpuCount <= 4) {
          autoEnable = true;
          reason = 'Giriş Seviye İşlemci ($cpuCount Çekirdek)';
        }
      }
    } catch (e) {
      debugPrint('Performans modu otomatik tespiti hatası: $e');
    }

    await prefs.setBool(key, autoEnable);
    await prefs.setBool(autoKey, autoEnable);
    await prefs.setString(reasonKey, reason);

    if (autoEnable) {
      debugPrint(
        '⚡ Düşük donanımlı cihaz algılandı: $reason. Performans modu otomatik aktifleştirildi.',
      );
    }

    return PerformanceProvider(
      isPerformanceMode: autoEnable,
      isAutoDetected: autoEnable,
      detectionReason: reason,
    );
  }

  Future<void> togglePerformanceMode(bool value) async {
    _isPerformanceMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPerformanceMode', value);
  }
}
