import 'dart:ui'; // Blur efekti için GEREKLİ
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'auth_servisi.dart';
import 'animasyon_yardimcisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'tema_ayarlari.dart';
import 'models/kullanici_saha_profili.dart';
import 'widgets/saha_rol_secici_formu.dart';

class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  Color get _themePrimary {
    try {
      if (!mounted) return const Color(0xFF10B981);
      return AppTheme.primary(context, listen: false);
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Color get _themeAccent {
    try {
      if (!mounted) return const Color(0xFF06B6D4);
      return AppTheme.accent(context, listen: false);
    } catch (_) {
      return const Color(0xFF06B6D4);
    }
  }

  Color get _themeContrastIcon {
    try {
      if (!mounted) return const Color(0xFF5EEAD4);
      return AppTheme.contrastIcon(context, listen: false);
    } catch (_) {
      return const Color(0xFF5EEAD4);
    }
  }

  int _aktifSekme = 0; // 0: Hesap Bilgileri, 1: Mesleki Kimlik & Saha

  final _adSoyadController = TextEditingController();
  final _usernameController = TextEditingController();
  final _sirketAdiController = TextEditingController();
  final _telefonController = TextEditingController();
  final _hakkindaController = TextEditingController();
  final _yevmiyeBeklentisiController = TextEditingController();
  final _webSitesiController = TextEditingController();
  List<String> _fotograflar = [];

  String _seciliRol = '';
  String _seciliBrans = '';
  String _seciliSeviye = '';
  String _seciliKapasite = '';
  String _seciliSehir = 'İstanbul';
  bool _isAriyorum = false;
  bool _ustaAriyorum = false;
  bool _vitrindeGoster = true;
  bool _meslekiVeriYuklendi = false;
  bool _meslekiKaydediliyor = false;
  bool _meslekiDuzenlemeModu = false;

  final _authServisi = AuthServisi();
  bool _degisiklikYapildi = false;

  @override
  void dispose() {
    _adSoyadController.dispose();
    _usernameController.dispose();
    _sirketAdiController.dispose();
    _telefonController.dispose();
    _hakkindaController.dispose();
    _yevmiyeBeklentisiController.dispose();
    _webSitesiController.dispose();
    super.dispose();
  }

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
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: AnimasyonluDialog.gecisYapici,
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
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
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          _BlurryPasswordInput(controller: mevcutParolaCtrl, hint: "Mevcut Parola", icon: Icons.lock_outline),
                          const SizedBox(height: 12),
                          _BlurryPasswordInput(controller: yeniParolaCtrl, hint: "Yeni Parola", icon: Icons.lock),
                          const SizedBox(height: 12),
                          _BlurryPasswordInput(controller: yeniParolaTekrarCtrl, hint: "Yeni Parola (Tekrar)", icon: Icons.lock_reset),
                          if (hataMesaji.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(hataMesaji, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("İptal", style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              Expanded(
                                child: loading
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                    : ElevatedButton(
                                        onPressed: () async {
                                          if (mevcutParolaCtrl.text.isEmpty || yeniParolaCtrl.text.isEmpty) {
                                            setDialogState(() => hataMesaji = "Tüm alanları doldurun.");
                                            return;
                                          }
                                          if (yeniParolaCtrl.text.length < 6) {
                                            setDialogState(() => hataMesaji = "Yeni parola en az 6 karakter olmalı.");
                                            return;
                                          }
                                          if (yeniParolaCtrl.text != yeniParolaTekrarCtrl.text) {
                                            setDialogState(() => hataMesaji = "Yeni parolalar uyuşmuyor!");
                                            return;
                                          }

                                          setDialogState(() {
                                            loading = true;
                                            hataMesaji = "";
                                          });

                                          try {
                                            await _authServisi.kullaniciParolasiniGuncelle(mevcutParolaCtrl.text, yeniParolaCtrl.text);
                                            if (mounted && ctx.mounted) {
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text("Parolanız başarıyla güncellendi."),
                                                  backgroundColor: _themePrimary,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setDialogState(() {
                                              loading = false;
                                              hataMesaji = e.toString().replaceFirst("Exception: ", "");
                                            });
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text("Güncelle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                              ),
                            ],
                          ),
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

  // --- HESAP SİLME DİYALOĞU (APPLE GUIDELINE 5.1.1(v) UYUMLU) ---
  void _hesabiSilDialog() {
    bool loading = false;
    String hataMesaji = "";
    final bool hasPassword = _authServisi.hasPasswordProvider;
    bool sifreGerekiyor = hasPassword;
    final parolaController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: AnimasyonluDialog.gecisYapici,
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Hesabımı ve Verilerimi Sil",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Hesabınızı sildiğinizde profil bilgileriniz, giriş yetkileriniz ve kullanıcı hesabınız KALICI OLARAK silinecektir.\n\nBu işlem geri alınamaz. Onaylıyor musunuz?",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (sifreGerekiyor && hasPassword) ...[
                            const SizedBox(height: 16),
                            const Text(
                              "Güvenlik nedeniyle silme işlemini onaylamak için lütfen mevcut şifrenizi girin:",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: parolaController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Mevcut Şifreniz",
                                hintStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          if (hataMesaji.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              hataMesaji,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    parolaController.dispose();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    "Vazgeç",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: loading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final girilenSifre =
                                              parolaController.text.trim();
                                          if (hasPassword &&
                                              girilenSifre.isEmpty) {
                                            setDialogState(() {
                                              sifreGerekiyor = true;
                                              hataMesaji =
                                                  "Lütfen mevcut şifrenizi girin.";
                                            });
                                            return;
                                          }
                                          setDialogState(() {
                                            loading = true;
                                            hataMesaji = "";
                                          });
                                          try {
                                            await _authServisi.hesabiVeVerileriSil(
                                              parola: girilenSifre.isNotEmpty
                                                  ? girilenSifre
                                                  : null,
                                            );
                                            parolaController.dispose();
                                            if (!ctx.mounted) return;
                                            Navigator.pop(ctx);
                                            if (!mounted || !context.mounted) return;
                                            Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).popUntil((route) => route.isFirst);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Hesabınız ve verileriniz başarıyla silindi.",
                                                ),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          } catch (e) {
                                            final err = e.toString();
                                            setDialogState(() {
                                              loading = false;
                                              if (err.contains("requires-recent-login")) {
                                                if (hasPassword) {
                                                  sifreGerekiyor = true;
                                                  hataMesaji =
                                                      "Güvenlik nedeniyle lütfen şifrenizi girerek onaylayın.";
                                                } else {
                                                  hataMesaji =
                                                      "Güvenlik doğrulaması gerekiyor. Lütfen tekrar 'EVET, SİL' butonuna dokunup hesabınızı doğrulayın.";
                                                }
                                              } else {
                                                hataMesaji = err
                                                    .replaceAll("Exception: ", "")
                                                    .replaceAll("requires-recent-login", "");
                                              }
                                            });
                                          }
                                        },
                                        child: Text(
                                          (sifreGerekiyor && hasPassword)
                                              ? "ŞİFREYİ DOĞRULA VE SİL"
                                              : "EVET, SİL",
                                        ),
                                      ),
                              ),
                            ],
                          ),
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
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "Kapat",
          barrierColor: Colors.black.withValues(alpha: 0.8),
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
                              backgroundColor: _themePrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text("TAMAM", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.grey),
            ),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 18, color: _themeContrastIcon),
          ],
        ),
      ),
    );
  }

  Widget _buildKayitliBilgiSatiri({
    required BuildContext context,
    required String baslik,
    required String deger,
    required IconData ikon,
    Color? badgeColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.cardGradient(isDark),
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.cardBorder(isDark),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (badgeColor ?? _themePrimary).withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, size: 20, color: badgeColor ?? _themeContrastIcon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  deger,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKayitliMeslekiBilgilerGorunumu({
    required BuildContext context,
    required KullaniciSahaProfili sahaProfili,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ÜST KART
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.cardGradient(isDark),
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _themePrimary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _themePrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  KullaniciRolu.rolIkonu(sahaProfili.kullaniciTipi),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      KullaniciRolu.rolBasligi(sahaProfili.kullaniciTipi),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sahaProfili.brans} • ${sahaProfili.sehir}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _themeContrastIcon,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: _themeContrastIcon),
                tooltip: 'Düzenle',
                onPressed: () {
                  setState(() => _meslekiDuzenlemeModu = true);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Faaliyet / Ustalık Alanı',
          deger: sahaProfili.brans,
          ikon: Icons.construction_rounded,
        ),
        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Pozisyon / Seviye',
          deger: sahaProfili.seviye,
          ikon: Icons.workspace_premium_rounded,
        ),
        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Kapasite / Proje Ölçeği',
          deger: sahaProfili.calismaKapasitesi,
          ikon: Icons.groups_2_rounded,
        ),
        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Bulunduğu Şehir (İl)',
          deger: sahaProfili.sehir,
          ikon: Icons.location_on_rounded,
        ),
        if (sahaProfili.sirketAdi.trim().isNotEmpty)
          _buildKayitliBilgiSatiri(
            context: context,
            baslik: 'Şirket / Ekip Adı',
            deger: sahaProfili.sirketAdi,
            ikon: Icons.business_rounded,
          ),
        if (sahaProfili.telefon.trim().isNotEmpty)
          _buildKayitliBilgiSatiri(
            context: context,
            baslik: 'İletişim Telefonu',
            deger: sahaProfili.telefon,
            ikon: Icons.phone_rounded,
          ),
        if (sahaProfili.gunlukYevmiyeBeklentisi > 0)
          _buildKayitliBilgiSatiri(
            context: context,
            baslik: 'Günlük Yevmiye Beklentisi',
            deger: '${sahaProfili.gunlukYevmiyeBeklentisi.toStringAsFixed(0)} TL / Gün',
            ikon: Icons.payments_rounded,
          ),
        if (sahaProfili.hakkinda.trim().isNotEmpty)
          _buildKayitliBilgiSatiri(
            context: context,
            baslik: 'Tanıtım & Referans Notu',
            deger: sahaProfili.hakkinda,
            ikon: Icons.notes_rounded,
          ),
        if (sahaProfili.webSitesi.trim().isNotEmpty)
          _buildKayitliBilgiSatiri(
            context: context,
            baslik: 'Web Sitesi',
            deger: sahaProfili.webSitesi,
            ikon: Icons.language_rounded,
          ),
        if (sahaProfili.fotograflar.isNotEmpty) ...[
          const SizedBox(height: 8),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 16,
                      color: _themeContrastIcon,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kayıtlı Portföy & Proje Fotoğrafları (${sahaProfili.fotograflar.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _themeContrastIcon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 65,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sahaProfili.fotograflar.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          sahaProfili.fotograflar[i],
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                width: 65,
                                height: 65,
                                color: Colors.black12,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Pazar & Çalışma Durumu',
          deger: sahaProfili.isAriyorum
              ? 'İş Arıyor (Müsait)'
              : (sahaProfili.ustaAriyorum ? 'Usta / Ekip Arıyor' : 'Aktif Projede'),
          ikon: Icons.verified_user_rounded,
          badgeColor: sahaProfili.isAriyorum || sahaProfili.ustaAriyorum ? Colors.green : null,
        ),
        _buildKayitliBilgiSatiri(
          context: context,
          baslik: 'Şantiye Pazarı Vitrini',
          deger: sahaProfili.vitrindeGoster ? 'Vitrinde Gösteriliyor' : 'Gizli',
          ikon: Icons.storefront_rounded,
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text("Mesleki Bilgileri Düzenle"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              setState(() => _meslekiDuzenlemeModu = true);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final firestoreServisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasPassword = _authServisi.hasPasswordProvider;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: "Profilim & Mesleki Kimlik",
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<DocumentSnapshot>(
          stream: firestoreServisi.getKullaniciVeriStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final String mevcutKullaniciAdi = userData['username'] ?? '';
            final String adSoyad = userData['adSoyad'] ?? 'İsimsiz Kullanıcı';
            final String rawEmail =
                (userData['email'] as String?)?.trim() ??
                (_authServisi.currentUserEmail ?? '').trim();
            final String email =
                rawEmail.isNotEmpty
                    ? (rawEmail.endsWith('@privaterelay.appleid.com')
                        ? 'Apple Gizli E-posta ($rawEmail)'
                        : rawEmail)
                    : 'Apple ID ile Giriş Yapıldı';

            if (!_degisiklikYapildi) {
              _adSoyadController.text = adSoyad;
              _usernameController.text = mevcutKullaniciAdi;
            }

            final sahaProfili = KullaniciSahaProfili.fromUserDoc(userData);
            if (!_meslekiVeriYuklendi) {
              _seciliRol = sahaProfili.kullaniciTipi.isNotEmpty
                  ? sahaProfili.kullaniciTipi
                  : KullaniciRolu.muteahhit;
              final branslar = KullaniciRolu.bransSecenekleri(_seciliRol);
              final seviyeler = KullaniciRolu.seviyeSecenekleri(_seciliRol);
              final kapasiteler =
                  KullaniciRolu.kapasiteVeyaCalismaSekliSecenekleri(_seciliRol);
              _seciliBrans = branslar.contains(sahaProfili.brans)
                  ? sahaProfili.brans
                  : branslar.first;
              _seciliSeviye = seviyeler.contains(sahaProfili.seviye)
                  ? sahaProfili.seviye
                  : seviyeler.first;
              _seciliKapasite = kapasiteler.contains(sahaProfili.calismaKapasitesi)
                  ? sahaProfili.calismaKapasitesi
                  : kapasiteler.first;
              _seciliSehir = sahaProfili.sehir.isNotEmpty
                  ? sahaProfili.sehir
                  : 'İstanbul';
              _sirketAdiController.text = sahaProfili.sirketAdi;
              _telefonController.text = sahaProfili.telefon;
              _hakkindaController.text = sahaProfili.hakkinda;
              _webSitesiController.text = sahaProfili.webSitesi;
              _fotograflar = List<String>.from(sahaProfili.fotograflar);
              _yevmiyeBeklentisiController.text =
                  sahaProfili.gunlukYevmiyeBeklentisi > 0
                      ? sahaProfili.gunlukYevmiyeBeklentisi.toStringAsFixed(0)
                      : '';
              _isAriyorum = sahaProfili.isAriyorum;
              _ustaAriyorum = sahaProfili.ustaAriyorum;
              _vitrindeGoster = sahaProfili.vitrindeGoster;
              _meslekiDuzenlemeModu = !sahaProfili.tamamlandiMi;
              _meslekiVeriYuklendi = true;
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20.0,
                FloatingLiquidAppBar.topPadding(context, extra: 4),
                20.0,
                32.0,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: _themePrimary,
                    child: Text(
                      adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    adSoyad,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // MESLEKİ ROZET KARTI
                  if (sahaProfili.tamamlandiMi)
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _themePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _themePrimary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            KullaniciRolu.rolIkonu(sahaProfili.kullaniciTipi),
                            size: 16,
                            color: _themeContrastIcon,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${KullaniciRolu.rolBasligi(sahaProfili.kullaniciTipi)} • ${sahaProfili.brans}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _themeContrastIcon,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => setState(() => _aktifSekme = 1),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 40,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.40)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Meslek Bilgisi Eksik (Tamamlamak İçin Dokunun)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // SEKME SEÇİCİ (HESAP BİLGİLERİ & MESLEKİ KİMLİK)
                  PanelGlassWidgets.buildCard(
                    context: context,
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _aktifSekme = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _aktifSekme == 0 ? _themePrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 18,
                                    color: _aktifSekme == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Hesap Bilgileri",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _aktifSekme == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _aktifSekme = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _aktifSekme == 1 ? _themePrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 18,
                                    color: _aktifSekme == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Mesleki Kimlik",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _aktifSekme == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  if (!sahaProfili.tamamlandiMi) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. SEKME: HESAP BİLGİLERİ & GÜVENLİK
                  if (_aktifSekme == 0) ...[
                    _buildFocusInput(context, _adSoyadController, "Ad Soyad", Icons.badge_outlined),
                    const SizedBox(height: 16),

                    _buildFocusInput(context, _usernameController, "Kullanıcı Adı", Icons.alternate_email),
                    const SizedBox(height: 16),

                    if (_degisiklikYapildi) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text("Hesap Bilgilerini Kaydet"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final safePrimary = _themePrimary;
                            final yeniAdSoyad = _adSoyadController.text.trim();
                            final yeniUsername = _usernameController.text.trim();
                            if (yeniAdSoyad.isNotEmpty && yeniAdSoyad != adSoyad) {
                              await firestoreServisi.adSoyadGuncelle(yeniAdSoyad);
                            }
                            if (yeniUsername.isNotEmpty && yeniUsername != mevcutKullaniciAdi) {
                              await firestoreServisi.kullaniciAdiniGuncelle(yeniUsername);
                            }
                            if (!mounted || !context.mounted) return;
                            setState(() => _degisiklikYapildi = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Profil bilgileriniz güncellendi."),
                                backgroundColor: safePrimary,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 16),

                    // PAROLA DEĞİŞTİR
                    if (hasPassword) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_reset),
                          label: const Text("Giriş Parolasını Değiştir"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: BorderSide(color: _themePrimary.withValues(alpha: 0.6)),
                            foregroundColor: _themeContrastIcon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _kisiselParolaDegistirDialog,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // HESABIMI VE VERİLERİMİ SİL
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text("Hesabımı ve Verilerimi Sil"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(color: Colors.red.shade400),
                          foregroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _hesabiSilDialog,
                      ),
                    ),
                  ],

                  // 2. SEKME: MESLEKİ KİMLİK & SAHA BİLGİLERİ
                  if (_aktifSekme == 1) ...[
                    if (!_meslekiDuzenlemeModu && sahaProfili.tamamlandiMi) ...[
                      _buildKayitliMeslekiBilgilerGorunumu(
                        context: context,
                        sahaProfili: sahaProfili,
                        isDark: isDark,
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Mesleki Bilgileri Düzenle",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF102A43),
                            ),
                          ),
                          if (sahaProfili.tamamlandiMi)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _meslekiDuzenlemeModu = false);
                              },
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text("Vazgeç"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SahaRolSeciciFormu(
                        seciliRol: _seciliRol,
                        seciliBrans: _seciliBrans,
                        seciliSeviye: _seciliSeviye,
                        seciliKapasite: _seciliKapasite,
                        seciliSehir: _seciliSehir,
                        sirketAdiController: _sirketAdiController,
                        telefonController: _telefonController,
                        hakkindaController: _hakkindaController,
                        webSitesiController: _webSitesiController,
                        yevmiyeBeklentisiController: _yevmiyeBeklentisiController,
                        isAriyorum: _isAriyorum,
                        ustaAriyorum: _ustaAriyorum,
                        vitrindeGoster: _vitrindeGoster,
                        detayliMod: true,
                        onRolChanged: (rol) {
                          setState(() {
                            _seciliRol = rol;
                            final branslar = KullaniciRolu.bransSecenekleri(rol);
                            final seviyeler = KullaniciRolu.seviyeSecenekleri(rol);
                            final kapasiteler =
                                KullaniciRolu.kapasiteVeyaCalismaSekliSecenekleri(
                                  rol,
                                );
                            _seciliBrans = branslar.first;
                            _seciliSeviye = seviyeler.first;
                            _seciliKapasite = kapasiteler.first;
                          });
                        },
                        onBransChanged: (b) => setState(() => _seciliBrans = b),
                        onSeviyeChanged: (s) => setState(() => _seciliSeviye = s),
                        onKapasiteChanged: (k) => setState(() => _seciliKapasite = k),
                        onSehirChanged: (seh) => setState(() => _seciliSehir = seh),
                        onIsAriyorumChanged: (val) => setState(() => _isAriyorum = val),
                        onUstaAriyorumChanged: (val) => setState(() => _ustaAriyorum = val),
                        onVitrindeGosterChanged: (val) => setState(() => _vitrindeGoster = val),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _meslekiKaydediliyor
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(_meslekiKaydediliyor ? "Kaydediliyor..." : "Mesleki Bilgileri Kaydet"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _meslekiKaydediliyor
                              ? null
                              : () async {
                                  final safePrimary = _themePrimary;
                                  setState(() => _meslekiKaydediliyor = true);
                                  try {
                                    final rolToSave = _seciliRol.isNotEmpty
                                        ? _seciliRol
                                        : (sahaProfili.kullaniciTipi.isNotEmpty
                                            ? sahaProfili.kullaniciTipi
                                            : KullaniciRolu.muteahhit);
                                    final branslar = KullaniciRolu.bransSecenekleri(rolToSave);
                                    final seviyeler = KullaniciRolu.seviyeSecenekleri(rolToSave);
                                    final bransToSave = _seciliBrans.isNotEmpty && branslar.contains(_seciliBrans)
                                        ? _seciliBrans
                                        : branslar.first;
                                    final seviyeToSave = _seciliSeviye.isNotEmpty && seviyeler.contains(_seciliSeviye)
                                        ? _seciliSeviye
                                        : seviyeler.first;

                                    final yeniProfil = KullaniciSahaProfili(
                                      kullaniciTipi: rolToSave,
                                      brans: bransToSave,
                                      seviye: seviyeToSave,
                                      calismaKapasitesi: _seciliKapasite,
                                      sirketAdi: _sirketAdiController.text.trim(),
                                      sehir: _seciliSehir,
                                      telefon: _telefonController.text.trim(),
                                      hakkinda: _hakkindaController.text.trim(),
                                      webSitesi: _webSitesiController.text.trim(),
                                      fotograflar: _fotograflar,
                                      gunlukYevmiyeBeklentisi:
                                          double.tryParse(
                                            _yevmiyeBeklentisiController.text
                                                .replaceAll(',', '.')
                                                .trim(),
                                          ) ??
                                          0,
                                      isAriyorum: _isAriyorum,
                                      ustaAriyorum: _ustaAriyorum,
                                      vitrindeGoster: _vitrindeGoster,
                                    );
                                    await firestoreServisi.sahaProfiliniGuncelle(
                                      yeniProfil.toMap(),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _meslekiDuzenlemeModu = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          "Mesleki kimlik ve saha bilgileriniz güncellendi.",
                                        ),
                                        backgroundColor: safePrimary,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hata oluştu: $e"),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _meslekiKaydediliyor = false);
                                  }
                                },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

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
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(widget.icon, color: Colors.grey),
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
