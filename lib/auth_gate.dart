import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_update_service.dart';
import 'deep_link_service.dart';
import 'login_or_register.dart';
import 'wrapper.dart';
import 'widgets/glass_surface.dart';
import 'zorunlu_guncelleme_ekrani.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AppUpdateStatus> _updateFuture;

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
        if (updateSnapshot.connectionState == ConnectionState.waiting) {
          return _buildSplash();
        }

        if (updateSnapshot.data?.requiresUpdate == true) {
          return ZorunluGuncellemeEkrani(
            status: updateSnapshot.data!,
            onRetry: _refreshUpdateCheck,
          );
        }

        return Scaffold(
          body: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.idTokenChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSplash();
              }

              if (snapshot.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  DeepLinkService.instance.tryPresentPendingInvite();
                });
                return const Wrapper();
              }

              return const LoginOrRegister();
            },
          ),
        );
      },
    );
  }

  Widget _buildSplash() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Center(
          child: GlassSectionCard(
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconBadge(
                  icon: Icons.construction_rounded,
                  color: const Color(0xFF14B8A6),
                  size: 88,
                  iconSize: 38,
                ),
                const SizedBox(height: 18),
                Text(
                  'Şantiye Puantaj Defteri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Veriler hazırlanıyor...',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark
                            ? Colors.white70
                            : const Color(0xFF516772),
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF14B8A6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
