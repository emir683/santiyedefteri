// lib/profil_tamamlama_ekrani.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:santiyeyonetim2/firestore_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

class ProfilTamamlamaEkrani extends StatefulWidget {
  const ProfilTamamlamaEkrani({super.key});

  @override
  State<ProfilTamamlamaEkrani> createState() => _ProfilTamamlamaEkraniState();
}

class _ProfilTamamlamaEkraniState extends State<ProfilTamamlamaEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _adSoyadController = TextEditingController();
  bool _isLoading = false;
  bool _isAppleUser = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mevcutBilgileriHazirla();
  }

  Future<void> _mevcutBilgileriHazirla() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isAppleUser = user.providerData.any((p) => p.providerId == 'apple.com');

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      _adSoyadController.text = user.displayName!.trim();
    }

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      final savedName = (data?['adSoyad'] as String?)?.trim() ?? '';
      if (_adSoyadController.text.trim().isEmpty && savedName.isNotEmpty) {
        _adSoyadController.text = savedName;
      }
    } catch (_) {}

    // Kullanıcıya kolaylık olması için otomatik geçerli bir kullanıcı adı öner
    if (_usernameController.text.trim().isEmpty) {
      final rawSeed =
          _adSoyadController.text.trim().isNotEmpty
              ? _adSoyadController.text.trim()
              : (user.email?.split('@').first ?? 'kullanici');
      final cleanSeed = rawSeed
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final suffix = user.uid.substring(0, 4).toLowerCase();
      final suggested =
          '${cleanSeed.isNotEmpty ? cleanSeed : 'uye'}_$suffix';
      if (mounted) {
        setState(() {
          _usernameController.text = suggested;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _adSoyadController.dispose();
    super.dispose();
  }

  Future<void> _profiliKaydet() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
      final rawAdSoyad = _adSoyadController.text.trim();
      final adSoyad =
          rawAdSoyad.isNotEmpty
              ? rawAdSoyad
              : (_isAppleUser ? 'Apple Kullanıcısı' : 'Kullanıcı');
      final username = _usernameController.text.trim().toLowerCase();

      try {
        // Kullanıcı adı başka bir kullanıcı tarafından alınmış mı kontrol et
        final usernameQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .where('username_lowercase', isEqualTo: username)
                .limit(1)
                .get();

        if (usernameQuery.docs.isNotEmpty &&
            usernameQuery.docs.first.id != user.uid) {
          setState(() {
            _errorMessage = "Bu kullanıcı adı zaten alınmış. Lütfen farklı bir kullanıcı adı seçin.";
            _isLoading = false;
          });
          return;
        }

        await firestoreServisi.completeGoogleUserProfile(
          user.uid,
          adSoyad,
          username,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil başarıyla oluşturuldu!"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingLiquidAppBar(
        title: "Profilini Tamamla",
        showPrivacyButton: false,
        showHamburger: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24.0,
              FloatingLiquidAppBar.topPadding(context, extra: 4),
              24.0,
              24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Son bir adım kaldı!",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Devam etmeden önce kullanıcı adınızı onaylayın veya düzenleyin.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _adSoyadController,
                    decoration: InputDecoration(
                      labelText:
                          _isAppleUser
                              ? "Ad Soyad (İsteğe Bağlı)"
                              : "Ad Soyad",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (_isAppleUser) {
                        // Apple Guideline 4.0 gereği Apple ile giriş yapan kullanıcılar ad soyad girmeye zorlanamaz
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return "Lütfen adınızı ve soyadınızı girin.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Kullanıcı Adı",
                      hintText: "ornek_kullanici",
                      prefixText: "@",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return "Kullanıcı adı en az 3 karakter olmalıdır.";
                      }
                      if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(value.trim().toLowerCase())) {
                        return "Sadece küçük harf, rakam, '_' ve '.' kullanabilirsiniz.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _profiliKaydet,
                        child: const Text("Kaydet ve Devam Et"),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}