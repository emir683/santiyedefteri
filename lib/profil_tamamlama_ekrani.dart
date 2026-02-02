// lib/profil_tamamlama_ekrani.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:santiyeyonetim2/firestore_servisi.dart';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Google ile giriş yapan kullanıcının adını otomatik doldur
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _adSoyadController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _adSoyadController.dispose();
    super.dispose();
  }

  Future<void> _profiliKaydet() async {
    // Klavyeyi kapat
    FocusScope.of(context).unfocus();
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
      final adSoyad = _adSoyadController.text.trim();
      final username = _usernameController.text.trim();

      try {
        // Firestore servisindeki mevcut fonksiyonunuzu kullanıyoruz
        await firestoreServisi.completeGoogleUserProfile(user.uid, adSoyad, username);
        
        // Başarılı olduğunda, Wrapper'daki StreamBuilder değişikliği
        // otomatik olarak algılayacak ve kullanıcıyı doğru ekrana yönlendirecek.
        // Bu yüzden burada bir `Navigator.push` işlemi yapmıyoruz.
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil başarıyla oluşturuldu!"), backgroundColor: Colors.green),
        );

      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", ""); // "Exception: " metnini kaldır
          _isLoading = false;
        });
      }
      // `isLoading` state'ini burada false yapmıyoruz çünkü başarılı olursa
      // zaten ekran değişecek. Sadece hata durumunda false'a çekiyoruz.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilini Tamamla"),
        automaticallyImplyLeading: false, // Geri butonu olmasın
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
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
                  "Devam etmeden önce lütfen profil bilgilerinizi tamamlayın.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _adSoyadController,
                  decoration: const InputDecoration(
                    labelText: "Ad Soyad",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
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
                    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(value)) {
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
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    );
  }
}