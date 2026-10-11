import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateStatus {
  final bool requiresUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final int minimumBuildNumber;
  final String latestVersionLabel;
  final String title;
  final String message;
  final String storeUrl;

  const AppUpdateStatus({
    required this.requiresUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.minimumBuildNumber,
    required this.latestVersionLabel,
    required this.title,
    required this.message,
    required this.storeUrl,
  });
}

class AppUpdateService {
  AppUpdateService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String defaultStoreUrl =
      'https://play.google.com/store/apps/details?id=com.emircf.santiyepuantaj';

  Future<AppUpdateStatus> checkStatus() async {
    final info = await PackageInfo.fromPlatform();
    final currentBuildNumber = int.tryParse(info.buildNumber) ?? 0;
    final currentVersion = info.version;

    try {
      final doc = await _db
          .collection('app_config')
          .doc('version_control')
          .get()
          .timeout(const Duration(seconds: 2));
      final data = doc.data();

      if (data == null) {
        return AppUpdateStatus(
          requiresUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          minimumBuildNumber: currentBuildNumber,
          latestVersionLabel: currentVersion,
          title: 'Guncel',
          message: '',
          storeUrl: defaultStoreUrl,
        );
      }

      final minimumBuildNumber =
          _readInt(data['minBuildNumber']) ??
          _readInt(data['minimumBuildNumber']) ??
          _readInt(data['minimumBuild']) ??
          0;
      final latestVersionLabel =
          (data['latestVersion'] ?? data['latestVersionLabel'] ?? currentVersion)
              .toString();
      final title =
          (data['title'] ?? 'Yeni Surum Gerekli').toString();
      final message =
          (data['message'] ??
                  'Devam etmek icin uygulamayi guncellemeniz gerekiyor.')
              .toString();
      final storeUrl = (data['storeUrl'] ?? defaultStoreUrl).toString();
      final requiresUpdate = minimumBuildNumber > currentBuildNumber;

      return AppUpdateStatus(
        requiresUpdate: requiresUpdate,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        minimumBuildNumber: minimumBuildNumber,
        latestVersionLabel: latestVersionLabel,
        title: title,
        message: message,
        storeUrl: storeUrl,
      );
    } catch (_) {
      return AppUpdateStatus(
        requiresUpdate: false,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        minimumBuildNumber: currentBuildNumber,
        latestVersionLabel: currentVersion,
        title: 'Guncel',
        message: '',
        storeUrl: defaultStoreUrl,
      );
    }
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
