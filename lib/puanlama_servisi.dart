import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PuanlamaServisi {
  static const String _packageName = 'com.emircf.santiyepuantaj';
  static const String _successfulActionCountKey =
      'puanlama_basarili_islem_sayisi';
  static const String _lastPromptAtKey = 'puanlama_son_gosterim_zamani';
  static const String _remindAfterKey = 'puanlama_tekrar_sorma_zamani';
  static const String _ratedKey = 'puanlama_verildi';

  static const int _firstPromptActionCount = 5;  // 1'den 5'e (daha az agresif)
  static const Duration _promptCooldown = Duration(days: 30);  // 21'den 30 güne
  static const Duration _remindLaterDelay = Duration(days: 7); // 1'den 7 güne

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

  static Future<void> openStore() async {
    final marketUri = Uri.parse('market://details?id=$_packageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_packageName',
    );

    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
