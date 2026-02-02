import 'dart:ui'; // Blur efekti için GEREKLİ
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'auth_servisi.dart';

class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  final _usernameController = TextEditingController();
  final _authServisi = AuthServisi();
  bool _degisiklikYapildi = false;

  // --- 1. PAROLA DEĞİŞTİRME DİYALOĞU (MODERN & BLUR & GÖZ İKONLU) ---
  void _kisiselParolaDegistirDialog() {
    final mevcutParolaCtrl = TextEditingController();
    final yeniParolaCtrl = TextEditingController();
    final yeniParolaTekrarCtrl = TextEditingController();
    String hataMesaji = "";
    bool loading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.8), // Arka planı karart
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Stack(
            children: [
              // ARKA PLAN BLUR
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
              // PENCERE
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95), // Şeffaf Siyah
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_reset, color: Colors.white, size: 40),
                          const SizedBox(height: 16),
                          const Text(
                            "Parolamı Değiştir", 
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                          ),
                          const SizedBox(height: 24),
                          
                          // GÖZ İKONLU INPUTLAR (Aşağıdaki yardımcı widget kullanılıyor)
                          _BlurryPasswordInput(controller: mevcutParolaCtrl, hint: "Mevcut Parola", icon: Icons.lock_outline),
                          const SizedBox(height: 12),
                          _BlurryPasswordInput(controller: yeniParolaCtrl, hint: "Yeni Parola", icon: Icons.lock),
                          const SizedBox(height: 12),
                          _BlurryPasswordInput(controller: yeniParolaTekrarCtrl, hint: "Yeni Parola (Tekrar)", icon: Icons.lock_reset),
                          
                          if (hataMesaji.isNotEmpty) 
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0), 
                              child: Text(hataMesaji, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))
                            ),
                          
                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx), 
                                  child: const Text("İptal", style: TextStyle(color: Colors.grey))
                                )
                              ),
                              Expanded(
                                child: loading 
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : ElevatedButton(
                                  onPressed: () async {
                                    // Validasyonlar
                                    if (mevcutParolaCtrl.text.isEmpty || yeniParolaCtrl.text.isEmpty) { setDialogState(() => hataMesaji = "Tüm alanları doldurun."); return; }
                                    if (yeniParolaCtrl.text.length < 6) { setDialogState(() => hataMesaji = "Yeni parola en az 6 karakter olmalı."); return; }
                                    if (yeniParolaCtrl.text != yeniParolaTekrarCtrl.text) { setDialogState(() => hataMesaji = "Yeni parolalar uyuşmuyor!"); return; }

                                    setDialogState(() { loading = true; hataMesaji = ""; });

                                    try {
                                      await _authServisi.kullaniciParolasiniGuncelle(mevcutParolaCtrl.text, yeniParolaCtrl.text);
                                      if (mounted) { 
                                        Navigator.pop(ctx); 
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parolanız başarıyla güncellendi."), backgroundColor: Colors.green)); 
                                      }
                                    } catch (e) {
                                      setDialogState(() { loading = false; hataMesaji = e.toString().replaceFirst("Exception: ", ""); });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent, 
                                    padding: const EdgeInsets.symmetric(vertical: 14), 
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  child: const Text("Güncelle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 2. KULLANICI ADI İÇİN ODAK MODU (FOCUS MODE) ---
  Widget _buildFocusInput(BuildContext context, TextEditingController controller, String label, IconData icon) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        // Tıklayınca açılan özel diyalog
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "Kapat",
          barrierColor: Colors.black.withOpacity(0.8),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (ctx, anim1, anim2) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(color: Colors.transparent),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(icon, color: Colors.black87),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () { 
                              setState(() => _degisiklikYapildi = true); 
                              Navigator.pop(ctx); 
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                            ),
                            child: const Text("TAMAM", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100, 
                borderRadius: BorderRadius.circular(8)
              ), 
              child: Icon(icon, color: Colors.grey)
            ),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              controller.text, 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. BİLGİ KARTI (Sadece Gösterim) ---
  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(8)
            ), 
            child: Icon(icon, color: Colors.blue)
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final firestoreServisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    
    return Scaffold(
      appBar: AppBar(title: const Text("Profilim")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestoreServisi.getKullaniciVeriStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String mevcutKullaniciAdi = userData['username'] ?? '';
          final String adSoyad = userData['adSoyad'] ?? 'İsimsiz Kullanıcı';
          final String email = userData['email'] ?? 'E-posta yok';
          
          // Controller'ı sadece değişiklik yoksa güncelle
          if (!_degisiklikYapildi) _usernameController.text = mevcutKullaniciAdi;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // PROFİL İKONU
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green.shade800,
                  child: Text(
                    adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(adSoyad, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                
                const SizedBox(height: 32),

                // 1. AD SOYAD (Sadece Bilgi)
                _buildInfoCard(context, "Ad Soyad", adSoyad, Icons.badge_outlined),
                
                const SizedBox(height: 16),

                // 2. KULLANICI ADI (Düzenlenebilir - Odak Modlu)
                _buildFocusInput(context, _usernameController, "Kullanıcı Adı", Icons.alternate_email),
                
                const SizedBox(height: 16),

                // KAYDET BUTONU (Sadece değişiklik varsa görünür)
                if (_degisiklikYapildi)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text("Değişiklikleri Kaydet"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      onPressed: () async {
                        if (_usernameController.text.trim().isNotEmpty) {
                          await firestoreServisi.kullaniciAdiniGuncelle(_usernameController.text.trim());
                          setState(() => _degisiklikYapildi = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kullanıcı adı güncellendi."), backgroundColor: Colors.green));
                        }
                      },
                    ),
                  ),

                if (_degisiklikYapildi) const SizedBox(height: 24) else const SizedBox(height: 16),

                // 3. PAROLA DEĞİŞTİR (Buton)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_reset),
                    label: const Text("Giriş Parolasını Değiştir"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: BorderSide(color: Colors.red.shade300),
                      foregroundColor: Colors.red.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _kisiselParolaDegistirDialog,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- YARDIMCI WIDGET: BLUR & GÖZ İKONLU PAROLA GİRİŞİ ---
// Bu widget şifrelerin görünürlüğünü kendi içinde (local state) yönetir.
class _BlurryPasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _BlurryPasswordInput({required this.controller, required this.hint, required this.icon});

  @override
  State<_BlurryPasswordInput> createState() => _BlurryPasswordInputState();
}

class _BlurryPasswordInputState extends State<_BlurryPasswordInput> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _isObscured,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.hint,
        labelStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(widget.icon, color: Colors.grey),
        // GÖZ İKONU
        suffixIcon: IconButton(
          icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () {
            setState(() {
              _isObscured = !_isObscured;
            });
          },
        ),
      ),
    );
  }
}