import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_servisi.dart';

class RegisterEkrani extends StatefulWidget {
  final VoidCallback onLoginTap;
  const RegisterEkrani({super.key, required this.onLoginTap});

  @override
  State<RegisterEkrani> createState() => _RegisterEkraniState();
}

class _RegisterEkraniState extends State<RegisterEkrani> {
  final _adSoyadController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthServisi _authServisi = AuthServisi();
  
  String _error = '';
  bool _loading = false;

  // Şifre Gizleme Durumları (İkisi için ayrı kontrol)
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  @override
  void dispose() {
    _adSoyadController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_adSoyadController.text.isEmpty || _usernameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = "Lütfen tüm alanları doldurun.");
      return;
    }
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      setState(() => _error = "Şifreler uyuşmuyor!");
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      await _authServisi.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _adSoyadController.text.trim(),
        _usernameController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _error = e.message ?? "Bir hata oluştu."; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tema ve Renk Ayarları
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    final Color iconColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LOGO ALANI ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1, size: 50, color: Colors.green),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                "Yeni Hesap Oluştur", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)
              ),
              const SizedBox(height: 8),
              Text(
                "Hemen aramıza katılın ve işleri yönetmeye başlayın",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 40),
              
              // --- AD SOYAD ---
              _buildModernInput(controller: _adSoyadController, label: 'Ad Soyad', icon: Icons.badge_outlined, inputFillColor: inputFillColor, iconColor: iconColor, textColor: textColor),
              const SizedBox(height: 16),
              
              // --- KULLANICI ADI ---
              _buildModernInput(controller: _usernameController, label: 'Kullanıcı Adı', icon: Icons.person_outline, inputFillColor: inputFillColor, iconColor: iconColor, textColor: textColor),
              const SizedBox(height: 16),
              
              // --- E-POSTA ---
              _buildModernInput(controller: _emailController, label: 'E-posta', icon: Icons.email_outlined, inputType: TextInputType.emailAddress, inputFillColor: inputFillColor, iconColor: iconColor, textColor: textColor),
              const SizedBox(height: 16),
              
              // --- ŞİFRE (GÖZ İKONLU) ---
              TextField(
                controller: _passwordController,
                obscureText: _isPasswordObscured,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.lock_outline, color: iconColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: iconColor),
                    onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- ŞİFRE TEKRAR (GÖZ İKONLU) ---
              TextField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmObscured,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Şifreyi Onayla',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.lock_reset_outlined, color: iconColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmObscured ? Icons.visibility_off : Icons.visibility, color: iconColor),
                    onPressed: () => setState(() => _isConfirmObscured = !_isConfirmObscured),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // HATA MESAJI
              if (_error.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),
              
              // KAYIT OL BUTONU
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: const Text('KAYIT OL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
              
              const SizedBox(height: 30),
              
              // GİRİŞ YAP LİNKİ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Zaten bir hesabınız var mı?", style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: widget.onLoginTap, 
                    child: const Text('Giriş Yapın', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı Widget: Standart Inputlar İçin
  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color inputFillColor,
    required Color iconColor,
    required Color textColor,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: iconColor),
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.green, width: 1.5)),
      ),
    );
  }
}