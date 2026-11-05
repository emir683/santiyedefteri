import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profesyonel Şantiye & Saha Yönetimi Renk Paletleri
class AppThemePalette {
  final String id;
  final String name;
  final String categorySubtitle;
  final String description;
  final IconData icon;

  /// Temel Vurgu Renkleri
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradient;
  final Color seedColor;

  /// Arka Plan ve Kart Renkleri
  final Color lightScaffoldBg;
  final Color darkScaffoldBg;
  final Color lightCardBg;
  final Color darkCardBg;

  /// İkincil Vurgular ve Efekt Renkleri
  final Color chipBgColor;
  final Color glowColor;
  final bool isDefault;

  /// Yüksek Kontrast İkon ve Metin Renkleri (Göz Yormayan, Net Renkler)
  final Color lightContrastIcon;
  final Color darkContrastIcon;

  const AppThemePalette({
    required this.id,
    required this.name,
    required this.categorySubtitle,
    required this.description,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
    required this.seedColor,
    required this.lightScaffoldBg,
    required this.darkScaffoldBg,
    required this.lightCardBg,
    required this.darkCardBg,
    required this.chipBgColor,
    required this.glowColor,
    required this.lightContrastIcon,
    required this.darkContrastIcon,
    this.isDefault = false,
  });

  /// Aydınlık veya karanlık moda göre maksimum kontrastlı ikon rengi
  Color contrastIcon(bool isDark) =>
      isDark ? darkContrastIcon : lightContrastIcon;

  /// Aydınlıkta asla silikleşmeyen koyu başlık/metin rengi, karanlıkta parlak beyaz
  Color contrastText(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF0F172A);

  /// Rozet ve buton arkaplanı için kontrastlı saydam ton
  Color contrastBadgeBg(bool isDark) =>
      isDark
          ? primary.withValues(alpha: 0.22)
          : lightContrastIcon.withValues(alpha: 0.12);

  // 1. Orijinal Canlı Neon (Varsayılan - Değişiklik yok)
  static const AppThemePalette varsayilan = AppThemePalette(
    id: 'varsayilan',
    name: 'Varsayılan (Canlı Neon)',
    categorySubtitle: 'Klasik Zümrüt & Camgöbeği',
    description: 'Orijinal canlı zümrüt yeşili ve parlak camgöbeği vurguları.',
    icon: Icons.auto_awesome_rounded,
    primary: Color(0xFF10B981),
    secondary: Color(0xFF06B6D4),
    accent: Color(0xFF0F7C86),
    gradient: [Color(0xFF10B981), Color(0xFF06B6D4)],
    seedColor: Color(0xFF10B981),
    lightScaffoldBg: Color(0xFFF0F2F5),
    darkScaffoldBg: Color(0xFF000000),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF1C1C1E),
    chipBgColor: Color(0x2610B981),
    glowColor: Color(0xFF5EEAD4),
    lightContrastIcon: Color(0xFF0F7C86),
    darkContrastIcon: Color(0xFF5EEAD4),
    isDefault: true,
  );

  // 2. Endüstriyel Şantiye (CAT Kehribarı / Baret Sarısı - Sıfır Neon)
  static const AppThemePalette endustriyel = AppThemePalette(
    id: 'endustriyel',
    name: 'Endüstriyel Şantiye (CAT)',
    categorySubtitle: 'İş Makinesi & Baret Kehribarı',
    description:
        'Sıfır neon parlama; yüksek kontrastlı emniyet sarısı, sıcak kehribar ve koyu antrasit.',
    icon: Icons.construction_rounded,
    primary: Color(0xFFD97706),
    secondary: Color(0xFFF59E0B),
    accent: Color(0xFFB45309),
    gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    seedColor: Color(0xFFD97706),
    lightScaffoldBg: Color(0xFFF8FAFC),
    darkScaffoldBg: Color(0xFF000000),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF18181B),
    chipBgColor: Color(0x26D97706),
    glowColor: Color(0xFFF59E0B),
    lightContrastIcon: Color(0xFFB45309),
    darkContrastIcon: Color(0xFFFBBF24),
  );

  // 3. Mühendislik & Blueprint (Çelik & Donanma Mavisi)
  static const AppThemePalette muhendislik = AppThemePalette(
    id: 'muhendislik',
    name: 'Mühendislik & Blueprint',
    categorySubtitle: 'Teknik Çizim & Çelik Mavisi',
    description:
        'Kurumsal CAD ve teknik ofis standardı; derin ve sakin donanma/çelik tonları.',
    icon: Icons.architecture_rounded,
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF0284C7),
    accent: Color(0xFF1D4ED8),
    gradient: [Color(0xFF2563EB), Color(0xFF0284C7)],
    seedColor: Color(0xFF2563EB),
    lightScaffoldBg: Color(0xFFF1F5F9),
    darkScaffoldBg: Color(0xFF000000),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF0F172A),
    chipBgColor: Color(0x262563EB),
    glowColor: Color(0xFF38BDF8),
    lightContrastIcon: Color(0xFF1D4ED8),
    darkContrastIcon: Color(0xFF60A5FA),
  );

  // 4. Doğal Yapı (Tuğla, Ahşap & Adaçayı)
  static const AppThemePalette dogal = AppThemePalette(
    id: 'dogal',
    name: 'Doğal Yapı (Tuğla & Ahşap)',
    categorySubtitle: 'Pişmiş Kiremit, Ahşap & Adaçayı',
    description:
        'Doğal yapı malzemeleri; fırınlanmış klinker kırmızısı, ahşap sıcaklığı ve mat adaçayı.',
    icon: Icons.foundation_rounded,
    primary: Color(0xFFB91C1C),
    secondary: Color(0xFF15803D),
    accent: Color(0xFFC2410C),
    gradient: [Color(0xFFB91C1C), Color(0xFFC2410C)],
    seedColor: Color(0xFFB91C1C),
    lightScaffoldBg: Color(0xFFFAF8F5),
    darkScaffoldBg: Color(0xFF000000),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF1C1917),
    chipBgColor: Color(0x26B91C1C),
    glowColor: Color(0xFFEA580C),
    lightContrastIcon: Color(0xFF991B1B),
    darkContrastIcon: Color(0xFFF87171),
  );

  // 5. Monokrom Titanyum (Mat Minimalist)
  static const AppThemePalette monokrom = AppThemePalette(
    id: 'monokrom',
    name: 'Monokrom Titanyum',
    categorySubtitle: 'Fırçalanmış Titanyum & Saf Sade',
    description:
        'Renk fazlalıklarından arındırılmış; göz yormayan mat gri, platin ve kömür siyahı.',
    icon: Icons.contrast_rounded,
    primary: Color(0xFF475569),
    secondary: Color(0xFF334155),
    accent: Color(0xFF64748B),
    gradient: [Color(0xFF475569), Color(0xFF334155)],
    seedColor: Color(0xFF475569),
    lightScaffoldBg: Color(0xFFF8FAFC),
    darkScaffoldBg: Color(0xFF000000),
    lightCardBg: Colors.white,
    darkCardBg: Color(0xFF121212),
    chipBgColor: Color(0x26475569),
    glowColor: Color(0xFF64748B),
    lightContrastIcon: Color(0xFF1E293B),
    darkContrastIcon: Color(0xFF475569),
  );

  static const List<AppThemePalette> all = [
    varsayilan,
    endustriyel,
    muhendislik,
    dogal,
    monokrom,
  ];

  static AppThemePalette fromId(String? id) {
    if (id == null || id.isEmpty) return varsayilan;
    for (final palette in all) {
      if (palette.id == id) return palette;
    }
    return varsayilan;
  }
}

/// Tema ve Palet Yönetim Servisi
class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemePalette _currentPalette = AppThemePalette.varsayilan;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get isSystemMode => _themeMode == ThemeMode.system;
  AppThemePalette get currentPalette => _currentPalette;

  // Hızlı Renk Erişim Kolaylıkları
  Color get primaryColor => _currentPalette.primary;
  Color get secondaryColor => _currentPalette.secondary;
  Color get accentColor => _currentPalette.accent;
  List<Color> get primaryGradient => _currentPalette.gradient;
  Color get glowColor => _currentPalette.glowColor;
  Color get seedColor => _currentPalette.seedColor;

  Color contrastIcon(bool isDark) => _currentPalette.contrastIcon(isDark);
  Color contrastText(bool isDark) => _currentPalette.contrastText(isDark);

  Color scaffoldBackground(bool isDark) =>
      isDark ? _currentPalette.darkScaffoldBg : _currentPalette.lightScaffoldBg;

  Color cardBackground(bool isDark) =>
      isDark ? _currentPalette.darkCardBg : _currentPalette.lightCardBg;

  ThemeProvider(bool? savedIsDarkMode, {String? initialPaletteId}) {
    WidgetsBinding.instance.addObserver(this);
    if (savedIsDarkMode == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = savedIsDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
    if (initialPaletteId != null && initialPaletteId.isNotEmpty) {
      _currentPalette = AppThemePalette.fromId(initialPaletteId);
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  Future<void> useSystemTheme() async {
    _themeMode = ThemeMode.system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isDarkMode');
    notifyListeners();
  }

  Future<void> setPalette(AppThemePalette palette) async {
    _currentPalette = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themePaletteId', palette.id);
    notifyListeners();
  }

  static ThemeProvider of(BuildContext context, {bool listen = false}) {
    return Provider.of<ThemeProvider>(context, listen: listen);
  }
}

/// Tüm ekranlarda tek satırda tema ve kontrast renklerine erişim sağlayan yardımcı
class AppTheme {
  static ThemeProvider provider(BuildContext context, {bool listen = false}) =>
      ThemeProvider.of(context, listen: listen);

  static AppThemePalette palette(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).currentPalette;

  static Color primary(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).primaryColor;

  static Color secondary(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).secondaryColor;

  static Color accent(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).accentColor;

  static List<Color> gradient(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).primaryGradient;

  static Color glow(BuildContext context, {bool listen = false}) =>
      provider(context, listen: listen).glowColor;

  static Color contrastIcon(
    BuildContext context, {
    bool? isDark,
    bool listen = false,
  }) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return palette(context, listen: listen).contrastIcon(dark);
  }

  static Color contrastText(
    BuildContext context, {
    bool? isDark,
    bool listen = false,
  }) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return palette(context, listen: listen).contrastText(dark);
  }

  // =========================================================================
  // 🎛️ MERKEZİ KART RENK VE ŞEFFAFLIK AYARLARI (TEK NOKTADAN YÖNETİM)
  // Tüm ekranlardaki kartların rengi, koyuluğu ve şeffaflığı buradan ayarlanır.
  // =========================================================================

  /// 🎴 TÜM KARTLARIN ARKA PLAN GEÇİŞİ (GRADIENT):
  /// Karanlık modda: Derin koyu siyaha yakın ve ekstra şeffaf füme cam efekti.
  static List<Color> cardGradient(bool isDark) {
    if (isDark) {
      return [
        // Üst-Sol: Koyu siyaha yakın, belirgin şeffaf füme cam (%50 opak / %50 şeffaf)
        const Color(0xFF0A0C10).withValues(alpha: 0.50),
        // Alt-Sağ: Derin simsiyah cam taban (%62 opak / %38 şeffaf)
        const Color(0xFF020305).withValues(alpha: 0.62),
      ];
    } else {
      return [
        const Color(0xFFEBF1F4).withValues(alpha: 0.68),
        const Color(0xFFD6E2E7).withValues(alpha: 0.76),
      ];
    }
  }

  /// 🎴 KARTLARIN İÇİNDEKİ GİRİNTİLİ ALANLAR (INSET):
  static List<Color> cardInsetGradient(bool isDark) {
    if (isDark) {
      return [
        const Color(0xFF0D0F14).withValues(alpha: 0.38),
        const Color(0xFF040507).withValues(alpha: 0.50),
      ];
    } else {
      return [
        const Color(0xFFE2ECF0).withValues(alpha: 0.62),
        const Color(0xFFCCD9DF).withValues(alpha: 0.70),
      ];
    }
  }

  /// 🎴 KART ÇERÇEVE (BORDER) RENGİ:
  static Color cardBorder(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFBFD0D6).withValues(alpha: 0.90);
  }

  /// 🎴 GİRİNTİLİ ALAN ÇERÇEVE (BORDER) RENGİ:
  static Color cardInsetBorder(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFBFD0D6).withValues(alpha: 0.80);
  }
}

// --- ESKİ RENK PALETİ (Geriye Uyumluluk İçin Korundu) ---
class AppColors {
  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color darkBackground = Color(0xFF23272A);
  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF36393F);

  static const Color greenLight = Color(0xFFD4F4D6);
  static const Color greenDark = Color(0xFF43A047);

  static const Color tealLight = Color(0xFFC4E4E2);
  static const Color tealDark = Color(0xFF26A69A);

  static const Color blueLight = Color(0xFFBBDEFB);
  static const Color blueDark = Color(0xFF42A5F5);

  static const Color purpleLight = Color(0xFFDCD6EA);
  static const Color purpleDark = Color(0xFF7E57C2);

  static const Color orangeLight = Color(0xFFFFE9CC);
  static const Color orangeDark = Color(0xFFFFB74D);

  // Dinamik Tema Bağlantıları (listen: false ile güvenli erişim)
  static Color primary(BuildContext context, {bool listen = false}) =>
      AppTheme.primary(context, listen: listen);
  static Color secondary(BuildContext context, {bool listen = false}) =>
      AppTheme.secondary(context, listen: listen);
  static Color accent(BuildContext context, {bool listen = false}) =>
      AppTheme.accent(context, listen: listen);
  static List<Color> gradient(BuildContext context, {bool listen = false}) =>
      AppTheme.gradient(context, listen: listen);
  static Color contrastIcon(BuildContext context, {bool? isDark, bool listen = false}) =>
      AppTheme.contrastIcon(context, isDark: isDark, listen: listen);
}
