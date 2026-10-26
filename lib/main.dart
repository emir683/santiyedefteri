import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'auth_servisi.dart';
import 'deep_link_service.dart';
import 'cad_intent_service.dart';
import 'cad_arkaplan_servisi.dart';
import 'user_model.dart';
import 'tema_ayarlari.dart';
import 'bildirim_servisi.dart';
import 'fcm_servisi.dart';
import 'privacy_provider.dart';
import 'performance_provider.dart';
import 'rol_provider.dart';
import 'services/ai/ai_service.dart';
import 'services/connectivity_sync_service.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_remote_config/firebase_remote_config.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _firebaseReady = false;
String? _bootstrapError;

// Tema yönetimi sınıfı
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider(bool isDarkMode) {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("--- UYGULAMA BAŞLATILIYOR ---");

  final prefs = await SharedPreferences.getInstance();
  final perfProvider = await PerformanceProvider.initialize(prefs);

  // Firebase başlatma (Tüm platformlar için DefaultFirebaseOptions kullanılır)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 6));
    _firebaseReady = true;
    debugPrint("✅ Firebase başarıyla başlatıldı.");

    // FCM arka plan mesaj dinleyicisi Firebase BAŞLATILDIKTAN SONRA kaydedilir
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint("FCM onBackgroundMessage kaydedilemedi: $e");
    }
  } catch (e) {
    debugPrint("🔥 Firebase başlatılırken hata veya zaman aşımı: $e");
    _bootstrapError = e.toString();
    _firebaseReady = true; // Uygulamanın açılışını engelleme
  }

  // UI'ı hemen başlat (kullanıcı açılış ekranında takılı kalmasın)
  runApp(MyApp(prefs: prefs, perfProvider: perfProvider));

  // Arka plan servislerini ve shaderları UI açıldıktan hemen sonra güvenle başlat
  _baslatArkaPlanServisleri();
}

/// Arka plan servislerini UI akışını engellemeden (non-blocking) başlatır
void _baslatArkaPlanServisleri() async {
  // 1. Çevrimdışı kalıcılık ve arka plan senkronizasyonu
  try {
    await ConnectivitySyncService.instance.initialize();
  } catch (e) {
    debugPrint("Offline sync servisi başlatılamadı: $e");
  }

  // 3. Gemini API anahtarını yükle
  try {
    await _loadGeminiApiKey();
  } catch (e) {
    debugPrint("Gemini api key yüklenemedi: $e");
  }

  if (!kIsWeb) {
    // 4. Bildirim servisi
    try {
      await BildirimServisi().init();
    } catch (e) {
      debugPrint("Bildirim servisi başlatılamadı: $e");
    }

    // 5. FCM servisi
    try {
      await FcmServisi().init();
    } catch (e) {
      debugPrint("FCM servisi başlatılamadı: $e");
    }

    // 6. Deep Link servisi
    try {
      await DeepLinkService.instance.initialize(navigatorKey: navigatorKey);
    } catch (e) {
      debugPrint("Deep link servisi başlatılamadı: $e");
    }

    // 7. WhatsApp / Harici CAD Dosya Açma Servisi
    try {
      await CadIntentService.instance.initialize(navigatorKey: navigatorKey);
    } catch (e) {
      debugPrint("CAD intent servisi başlatılamadı: $e");
    }
  }
}

/// Firebase Remote Config üzerinden Gemini API anahtarını güvenle yükler.
/// Anahtar kaynak kodda veya build çıktısında yer almaz.
Future<void> _loadGeminiApiKey() async {
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await rc.setDefaults({
      'gemini_api_key': '',
      'cad_server_url': CadArkaplanServisi.defaultCadServerUrl,
    });
    await rc.fetchAndActivate();
    final cadUrl = rc.getString('cad_server_url').trim();
    if (cadUrl.isNotEmpty) {
      CadArkaplanServisi.setCadServerUrl(cadUrl);
    }
    final key = rc.getString('gemini_api_key');
    if (key.isNotEmpty) {
      AIService.setApiKey(key);
      debugPrint('✅ Gemini API anahtarı Remote Config üzerinden yüklendi.');
    } else {
      debugPrint(
        '⚠️ Remote Config: gemini_api_key boş — AI özellikleri devre dışı.',
      );
    }
  } catch (e) {
    debugPrint('⚠️ Remote Config yüklenemedi: $e — AI özellikleri devre dışı.');
  }
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final PerformanceProvider perfProvider;

  const MyApp({
    super.key,
    required this.prefs,
    required this.perfProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Santiye Puantaj Defteri',
        home: _BootstrapErrorScreen(message: _bootstrapError),
      );
    }

    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    final authServisi = AuthServisi();

    // MultiProvider, birden fazla Provider'ı bir araya getirir.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: ConnectivitySyncService.instance,
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
        ChangeNotifierProvider.value(value: perfProvider),
        ChangeNotifierProvider(create: (_) => PrivacyProvider()),
        ChangeNotifierProvider(create: (_) => RolProvider()),
        StreamProvider<UserModel?>.value(
          lazy: false,
          value: authServisi.userStream,
          initialData: authServisi.currentUser,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final textTheme = Theme.of(context).textTheme;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            title: 'Şantiye Puantaj Defteri',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.lightBackground,
              textTheme: GoogleFonts.poppinsTextTheme(textTheme),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: ZoomPageTransitionsBuilder(),
                },
              ),
              colorSchemeSeed: Colors.green,
              appBarTheme: AppBarTheme(
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.black87),
                titleTextStyle: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              textTheme: GoogleFonts.poppinsTextTheme(
                Theme.of(context).primaryTextTheme,
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: ZoomPageTransitionsBuilder(),
                },
              ),
              colorSchemeSeed: Colors.green,
              appBarTheme: AppBarTheme(
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: const Color(0xFF1C1C1E),
              ),
              listTileTheme: const ListTileThemeData(
                iconColor: Colors.white70,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.grey.shade800),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                labelStyle: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('tr', 'TR')],
            locale: const Locale('tr', 'TR'),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final isWebSetupIssue =
        kIsWeb && (message?.contains('configured for web') ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF0F7C86).withValues(alpha: 0.12),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F7C86).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFF0F7C86),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isWebSetupIssue
                        ? 'Web surumu henuz tamamlanmadi'
                        : 'Uygulama baslatilamadi',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWebSetupIssue
                        ? 'Firebase web yapilandirmasi eklenmedigi icin giris ekrani acilamiyor. Firebase projesine bir web uygulamasi ekleyip yeni ayarlari bu projeye baglamamiz gerekiyor.'
                        : 'Baslangicta bir yapilandirma hatasi olustu. Ayrinti teknik mesajda gorunuyor.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if ((message ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SelectableText(
                        message!,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12.5,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
