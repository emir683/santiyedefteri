import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'auth_servisi.dart';
import 'deep_link_service.dart';
import 'user_model.dart';
import 'tema_ayarlari.dart';
import 'bildirim_servisi.dart';
import 'fcm_servisi.dart';
import 'privacy_provider.dart';
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

  // Uygulama KAPALI iken FCM mesajı geldiğinde çalışacak top-level handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await LiquidGlassWidgets.initialize();
  } catch (e) {
    _bootstrapError = e.toString();
    debugPrint("Liquid glass baslatilamadi: $e");
  }
  debugPrint("--- UYGULAMA BAŞLATILIYOR ---");

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    _firebaseReady = true;
    debugPrint("✅ Firebase başarıyla başlatıldı.");

    // Çevrimdışı kalıcılık ve arka plan senkronizasyonunu başlat
    try {
      await ConnectivitySyncService.instance.initialize();
    } catch (e) {
      debugPrint("Offline sync servisi baslatilamadi: $e");
    }

    // Gemini API anahtarını Remote Config'den güvenle yükle
    await _loadGeminiApiKey();
  } catch (e) {
    debugPrint("🔥 Firebase başlatılırken KRİTİK HATA: $e");
  }

  if (!kIsWeb) {
    try {
      await BildirimServisi().init();
    } catch (e) {
      debugPrint("Bildirim servisi baslatilamadi: $e");
    }

    // FCM servisi başlat (uygulama kapalıyken bildirim için)
    try {
      await FcmServisi().init();
    } catch (e) {
      debugPrint("FCM servisi baslatilamadi: $e");
    }

    try {
      await DeepLinkService.instance.initialize(navigatorKey: navigatorKey);
    } catch (e) {
      debugPrint("Deep link servisi baslatilamadi: $e");
    }
  }
  runApp(const MyApp());
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
    await rc.setDefaults({'gemini_api_key': ''});
    await rc.fetchAndActivate();
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Santiye Puantaj Defteri',
        home: _BootstrapErrorScreen(message: _bootstrapError),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final prefs = snapshot.data!;
        final isDarkMode = prefs.getBool('isDarkMode') ?? false;
        final authServisi = AuthServisi();

        // MultiProvider, birden fazla Provider'ı bir araya getirir.
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: ConnectivitySyncService.instance,
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
            ChangeNotifierProvider(create: (_) => PrivacyProvider()),
            ChangeNotifierProvider(create: (_) => RolProvider()),
            StreamProvider<UserModel?>.value(
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
      },
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
