import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama içi tanıtım turlarının gösterilip gösterilmediğini takip eder.
class TurServisi {
  static const String _anaMenuTurKey = 'tur_ana_menu_gosterildi';
  static const String _raporTurKey = 'tur_rapor_gosterildi';
  static const String _isciTurKey = 'tur_isci_gosterildi';
  static const String _santiyeTurKey = 'tur_santiye_gosterildi';
  static const String _aySonuTurKey = 'tur_ay_sonu_gosterildi';

  static Future<bool> anaMenuTurGosterildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_anaMenuTurKey) ?? false;
  }

  static Future<void> anaMenuTurGosterildiOlarakIsaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_anaMenuTurKey, true);
  }

  static Future<bool> raporTurGosterildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_raporTurKey) ?? false;
  }

  static Future<void> raporTurGosterildiOlarakIsaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_raporTurKey, true);
  }

  static Future<bool> isciTurGosterildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isciTurKey) ?? false;
  }

  static Future<void> isciTurGosterildiOlarakIsaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isciTurKey, true);
  }

  static Future<bool> santiyeTurGosterildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_santiyeTurKey) ?? false;
  }

  static Future<void> santiyeTurGosterildiOlarakIsaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_santiyeTurKey, true);
  }

  static Future<bool> aySonuTurGosterildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aySonuTurKey) ?? false;
  }

  static Future<void> aySonuTurGosterildiOlarakIsaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aySonuTurKey, true);
  }

  // ——————————————————————————————————————————
  // 3 ADIMLI BAŞLANGIÇ REHBERİ (ilk kullanım)
  // ——————————————————————————————————————————
  static const String _adim1Key = 'rehber_santiye_eklendi';
  static const String _adim2Key = 'rehber_isci_eklendi';
  static const String _adim3Key = 'rehber_rapor_girildi';
  static const String _rehberKapatildiKey = 'rehber_kapatildi';

  static Future<bool> adim1Tamamlandi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adim1Key) ?? false;
  }

  static Future<void> adim1Isaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adim1Key, true);
  }

  static Future<bool> adim2Tamamlandi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adim2Key) ?? false;
  }

  static Future<void> adim2Isaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adim2Key, true);
  }

  static Future<bool> adim3Tamamlandi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adim3Key) ?? false;
  }

  static Future<bool> adim3TamamlandiMi() async {
    return adim3Tamamlandi();
  }

  static Future<void> adim3Isaretle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adim3Key, true);
  }

  static Future<bool> rehberGosterilmeli() async {
    final prefs = await SharedPreferences.getInstance();
    final kapatildi = prefs.getBool(_rehberKapatildiKey) ?? false;
    if (kapatildi) return false;
    final a1 = prefs.getBool(_adim1Key) ?? false;
    final a2 = prefs.getBool(_adim2Key) ?? false;
    final a3 = prefs.getBool(_adim3Key) ?? false;
    return !(a1 && a2 && a3);
  }

  static Future<void> rehberKapat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rehberKapatildiKey, true);
  }

  /// Tüm turları sıfırlar (tekrar göstermek için)
  static Future<void> turlariSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_anaMenuTurKey);
    await prefs.remove(_raporTurKey);
    await prefs.remove(_isciTurKey);
    await prefs.remove(_santiyeTurKey);
    await prefs.remove(_aySonuTurKey);
    await prefs.remove(_adim1Key);
    await prefs.remove(_adim2Key);
    await prefs.remove(_adim3Key);
    await prefs.remove(_rehberKapatildiKey);
  }
}
