import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'user_model.dart';
import 'auth_servisi.dart';
import 'firestore_servisi.dart';
import 'team_gate.dart';

class EkipYonetimiEkrani extends StatefulWidget {
  final String teamId;
  const EkipYonetimiEkrani({super.key, required this.teamId});

  @override
  State<EkipYonetimiEkrani> createState() => _EkipYonetimiEkraniState();
}

class _EkipYonetimiEkraniState extends State<EkipYonetimiEkrani> {
  // --- 1. EKİP ADI DEĞİŞTİRME ---
  void _isimDegistirDialog(FirestoreServisi servisi, String mevcutAd) {
    final controller = TextEditingController(text: mevcutAd);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
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
                  color: const Color(0xFF1E1E1E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Ekip Adını Değiştir",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Standart Input (Şifre olmadığı için direkt TextField kullanıyoruz ama modern stil)
                      TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Yeni Ekip Adı",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(
                            Icons.groups,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "İptal",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (controller.text.trim().isNotEmpty) {
                                  await servisi.ekipAdiniGuncelle(
                                    widget.teamId,
                                    controller.text.trim(),
                                  );
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Ekip adı güncellendi."),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Kaydet",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        );
      },
    );
  }

  // --- 2. EKİP PAROLASI DEĞİŞTİRME (GÖZ İKONLU) ---
  void _parolaDegistirDialog(
    FirestoreServisi servisi,
    String gercekMevcutParola,
  ) {
    final eskiParolaCtrl = TextEditingController();
    final yeniParolaCtrl = TextEditingController();
    final yeniParolaTekrarCtrl = TextEditingController();
    String hataMesaji = "";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) => Stack(
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
                        color: const Color(0xFF1E1E1E).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Parolayı Değiştir",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // YENİ WIDGET KULLANIMI: GÖZ İKONLU INPUTLAR
                              _BlurryPasswordInput(
                                controller: eskiParolaCtrl,
                                hint: "Mevcut Parola",
                                icon: Icons.lock_outline,
                              ),
                              const SizedBox(height: 12),
                              _BlurryPasswordInput(
                                controller: yeniParolaCtrl,
                                hint: "Yeni Parola",
                                icon: Icons.lock,
                              ),
                              const SizedBox(height: 12),
                              _BlurryPasswordInput(
                                controller: yeniParolaTekrarCtrl,
                                hint: "Yeni Parola (Tekrar)",
                                icon: Icons.lock_reset,
                              ),

                              if (hataMesaji.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    hataMesaji,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text(
                                        "İptal",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (eskiParolaCtrl.text !=
                                            gercekMevcutParola) {
                                          setDialogState(
                                            () =>
                                                hataMesaji =
                                                    "Mevcut parola yanlış!",
                                          );
                                          return;
                                        }
                                        if (yeniParolaCtrl.text.length < 6) {
                                          setDialogState(
                                            () =>
                                                hataMesaji =
                                                    "Yeni parola en az 6 karakter olmalı.",
                                          );
                                          return;
                                        }
                                        if (yeniParolaCtrl.text !=
                                            yeniParolaTekrarCtrl.text) {
                                          setDialogState(
                                            () =>
                                                hataMesaji =
                                                    "Yeni parolalar uyuşmuyor!",
                                          );
                                          return;
                                        }

                                        await servisi.ekipParolasiniGuncelle(
                                          widget.teamId,
                                          yeniParolaCtrl.text.trim(),
                                        );
                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Ekip parolası başarıyla değiştirildi.",
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Güncelle",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
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

  // --- BAĞLANTI PAYLAŞMA ---
  void _baglantiPaylas(String ekipAdi, String ekipSifresi) {
    final String deepLink = "santiyeapp://katil?ad=$ekipAdi&sifre=$ekipSifresi";
    const String storeLink =
        "https://play.google.com/store/apps/details?id=com.seninad.santiyeyonetim";
    final String mesaj =
        "🏗️ *Şantiye Defteri Ekibine Katıl!*\n\nBirlikte çalışmak için seni '$ekipAdi' ekibine davet ediyorum.\n\n🚀 *Uygulama Yüklüyse Tıkla:*\n$deepLink\n\n📲 *İndir:*\n$storeLink\n\n🔐 *Manuel Giriş:*\nEkip Adı: $ekipAdi\nParola: $ekipSifresi";
    Share.share(mesaj);
  }

  // --- ANA EKRAN YAPISI ---
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final firestoreServisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Ekip Yönetimi")),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('teams')
                .doc(widget.teamId)
                .snapshots(),
        builder: (context, teamSnapshot) {
          if (teamSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!teamSnapshot.hasData || !teamSnapshot.data!.exists)
            return const Center(child: Text("Ekip bilgileri bulunamadı."));

          final teamData = teamSnapshot.data!.data() as Map<String, dynamic>;
          final String ekipAdi = teamData['ad'] ?? 'İsimsiz Ekip';
          final String ekipParolasi = teamData['sifre'] ?? 'Yok';
          final String kurucuUid = teamData['kurucu'] ?? '';
          final bool isKurucu = user?.uid == kurucuUid;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. EKİP BİLGİLERİ KARTI
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ekip Bilgileriniz",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _buildEditableRow(
                        context,
                        label: "Ekip Adı:",
                        value: ekipAdi,
                        icon: Icons.groups,
                        canEdit: isKurucu,
                        onEdit:
                            () =>
                                _isimDegistirDialog(firestoreServisi, ekipAdi),
                        onCopy: () => _copyToClipboard(ekipAdi),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildEditableRow(
                        context,
                        label: "Ekip Parolası:",
                        value: ekipParolasi,
                        icon: Icons.lock,
                        canEdit: isKurucu,
                        isPassword: true,
                        onEdit:
                            () => _parolaDegistirDialog(
                              firestoreServisi,
                              ekipParolasi,
                            ),
                        onCopy: () => _copyToClipboard(ekipParolasi),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 2. PAYLAŞIM KARTI
              Card(
                color: Colors.indigoAccent.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _baglantiPaylas(ekipAdi, ekipParolasi),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ekip Bağlantısını Paylaş",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Çalışanları davet et",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 3. ÜYELER KARTI
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ekip Üyeleri",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: firestoreServisi.getEkipUyeleriStream(
                          widget.teamId,
                        ),
                        builder: (context, uyeSnapshot) {
                          if (!uyeSnapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          final uyeler = uyeSnapshot.data!;
                          return Column(
                            children:
                                uyeler.map((uye) {
                                  final bool isCurrentUser =
                                      user?.uid == uye['uid'];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? Colors.black26
                                              : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.1),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green.shade700,
                                        child: Text(
                                          uye['username'].isNotEmpty
                                              ? uye['username'][0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      title: Text(
                                        "${uye['username']} ${uye['uid'] == kurucuUid ? '(Kurucu)' : ''}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        uye['email'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing:
                                          (isKurucu && !isCurrentUser)
                                              ? IconButton(
                                                icon: const Icon(
                                                  Icons.person_remove_outlined,
                                                  color: Colors.redAccent,
                                                ),
                                                onPressed:
                                                    () => firestoreServisi
                                                        .uyeyiEkiptenSil(
                                                          widget.teamId,
                                                          uye['uid'],
                                                        ),
                                              )
                                              : null,
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Başka Ekibe Geç Butonu
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text("Başka Ekibe Geç"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.blue),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamGate()),
                  );
                },
              ),
              const SizedBox(height: 12),

              if (!isKurucu)
                ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text("Ekipten Ayrıl"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await firestoreServisi.ekiptenAyril(
                      widget.teamId,
                      user!.uid,
                    );
                    if (mounted)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const TeamGate()),
                      );
                  },
                ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditableRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required bool canEdit,
    VoidCallback? onEdit,
    VoidCallback? onCopy,
    bool isPassword = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (canEdit)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            onPressed: onEdit,
          ),
        IconButton(
          icon: const Icon(Icons.copy, color: Colors.grey),
          onPressed: onCopy,
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("'$text' kopyalandı.")));
  }
}

// --- YARDIMCI WIDGET: BLUR & GÖZ İKONLU PAROLA GİRİŞİ ---
class _BlurryPasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _BlurryPasswordInput({
    required this.controller,
    required this.hint,
    required this.icon,
  });

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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(widget.icon, color: Colors.grey),
        // GÖZ İKONU BURADA
        suffixIcon: IconButton(
          icon: Icon(
            _isObscured ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
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
