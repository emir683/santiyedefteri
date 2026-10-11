import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_update_service.dart';
import 'deep_link_service.dart';
import 'fcm_servisi.dart';
import 'login_or_register.dart';
import 'wrapper.dart';
import 'zorunlu_guncelleme_ekrani.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AppUpdateStatus> _updateFuture;
  String? _lastInviteHandledUserId;

  @override
  void initState() {
    super.initState();
    _updateFuture = AppUpdateService().checkStatus();
  }

  void _refreshUpdateCheck() {
    setState(() {
      _updateFuture = AppUpdateService().checkStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUpdateStatus>(
      future: _updateFuture,
      builder: (context, updateSnapshot) {
        // Zorunlu güncelleme kontrolü tamamlandıysa ve güncelleme gerekiyorsa hemen göster
        if (updateSnapshot.hasData && updateSnapshot.data!.requiresUpdate) {
          return ZorunluGuncellemeEkrani(
            status: updateSnapshot.data!,
            onRetry: _refreshUpdateCheck,
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

            if (user != null) {
              if (_lastInviteHandledUserId != user.uid) {
                _lastInviteHandledUserId = user.uid;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  DeepLinkService.instance.tryPresentPendingInvite();
                  FcmServisi().kullaniciBagla();
                });
              }
              return Wrapper(userId: user.uid);
            }

            // Auth henüz ilk durumunu belirliyorsa ve cache'de kullanıcı yoksa
            if (snapshot.connectionState == ConnectionState.waiting &&
                FirebaseAuth.instance.currentUser == null) {
              return _buildSplash();
            }

            _lastInviteHandledUserId = null;
            return const LoginOrRegister();
          },
        );
      },
    );
  }

  Widget _buildSplash() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D14) : const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161C24) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: Color(0xFF14B8A6),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Şantiye Puantaj Defteri',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Veriler hazırlanıyor...',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF14B8A6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
