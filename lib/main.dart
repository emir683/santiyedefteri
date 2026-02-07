import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'auth_servisi.dart';
import 'user_model.dart';
import 'tema_ayarlari.dart';
import 'bildirim_servisi.dart';
import 'privacy_provider.dart';
// Native test

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

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase başarıyla başlatıldı.");
  } catch (e) {
    debugPrint("🔥 Firebase başlatılırken KRİTİK HATA: $e");
  }

  await BildirimServisi().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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

        // MultiProvider, birden fazla Provider'ı bir araya getirir.
        return MultiProvider(
          providers: [
            // Tema durumu için
            ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
            ChangeNotifierProvider(create: (_) => PrivacyProvider()),
            // Kullanıcı oturum durumu için
            StreamProvider<UserModel?>.value(
              value: AuthServisi().userStream,
              initialData: null,
            ),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final textTheme = Theme.of(context).textTheme;
              return MaterialApp(
                debugShowCheckedModeBanner: false,
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
