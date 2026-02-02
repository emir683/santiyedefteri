import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'wrapper.dart';
import 'login_or_register.dart';

// auth_gate.dart içinde

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("AuthGate build edildi. Oturum durumu dinleniyor...");
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint("AuthGate: Oturum durumu bekleniyor...");
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            debugPrint("🔥 AuthGate: Oturum dinlenirken HATA: ${snapshot.error}");
          }
          
          if (snapshot.hasData) {
            debugPrint("✅ AuthGate: Kullanıcı giriş yapmış (UID: ${snapshot.data!.uid}). Wrapper'a yönlendiriliyor.");
            return const Wrapper();
          } else {
            debugPrint("AuthGate: Kullanıcı giriş yapmamış. Login/Register ekranına yönlendiriliyor.");
            return const LoginOrRegister();
          }
        },
      ),
    );
  }
}
