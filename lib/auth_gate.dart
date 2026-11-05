import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_update_service.dart';
import 'deep_link_service.dart';
import 'cad_intent_service.dart';
import 'fcm_servisi.dart';
import 'login_or_register.dart';
import 'tanitim_izin_ekrani.dart';
import 'widgets/acilis_animasyon_ekrani.dart';
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
  bool _tanitimKontrolEdildi = false;
  bool _tanitimGoruldu = false;

  @override
  void initState() {
    super.initState();
    _updateFuture = AppUpdateService().checkStatus();
    _tanitimDurumunuYukle();
  }

  Future<void> _tanitimDurumunuYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final goruldu = prefs.getBool('tanitim_ve_izin_goruldu') ?? false;
    if (mounted) {
      setState(() {
        _tanitimGoruldu = goruldu;
        _tanitimKontrolEdildi = true;
      });
    }
  }

  Future<void> _tanitimiTamamla() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tanitim_ve_izin_goruldu', true);
    if (mounted) {
      setState(() {
        _tanitimGoruldu = true;
      });
    }
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
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snapshot) {
            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

            if (user != null) {
              if (_lastInviteHandledUserId != user.uid) {
                _lastInviteHandledUserId = user.uid;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  DeepLinkService.instance.tryPresentPendingInvite();
                  CadIntentService.instance.tryPresentPendingCadFile();
                  FcmServisi().kullaniciBagla();
                });
              }
              return Wrapper(
                key: ValueKey('wrapper_${user.uid}'),
                userId: user.uid,
              );
            }

            // Auth henüz ilk durumunu belirliyorsa ve cache'de kullanıcı yoksa
            if (snapshot.connectionState == ConnectionState.waiting &&
                FirebaseAuth.instance.currentUser == null) {
              return _buildSplash();
            }

            // Tanıtım & İzin ekranı kontrolü bekleniyorsa splash göster
            if (!_tanitimKontrolEdildi) {
              return _buildSplash();
            }

            _lastInviteHandledUserId = null;

            // Tanıtım henüz görülmediyse tanıtım ve izin slider'ı, görüldüyse şık animasyonla login ekranı
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 550),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  !_tanitimGoruldu
                      ? TanitimIzinEkrani(
                        key: const ValueKey('tanitim_izin_ekrani'),
                        onTamamlandi: _tanitimiTamamla,
                      )
                      : const LoginOrRegister(
                        key: ValueKey('login_or_register'),
                      ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplash() {
    return const AcilisYuklemeEkrani(
      mesaj: 'Veriler hazırlanıyor...',
    );
  }
}
