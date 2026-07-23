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
import 'widgets/glass_surface.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class EkipYonetimiEkrani extends StatefulWidget {
  final String teamId;
  const EkipYonetimiEkrani({super.key, required this.teamId});

  @override
  State<EkipYonetimiEkrani> createState() => _EkipYonetimiEkraniState();
}

class _EkipYonetimiEkraniState extends State<EkipYonetimiEkrani> {
  bool _uyelerListesiAcik = false;
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
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await servisi.ekipAdiniGuncelle(
                                    widget.teamId,
                                    controller.text.trim(),
                                  );
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text("Ekip adı güncellendi."),
                                        backgroundColor: _kBrandTeal,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBrandTeal,
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

                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        await servisi.ekipParolasiniGuncelle(
                                          widget.teamId,
                                          yeniParolaCtrl.text.trim(),
                                        );
                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Ekip parolası başarıyla değiştirildi.",
                                              ),
                                              backgroundColor: _kBrandTeal,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kBrandTeal,
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
  void _baglantiPaylas(
    String ekipAdi,
    String ekipSifresi,
    String ekipId,
  ) {
    final String deepLink = Uri(
      scheme: 'https',
      host: 'emrcore.com',
      path: '/katil',
      queryParameters: {
        'ad': ekipAdi,
        'id': ekipId,
      },
    ).toString();
    const String storeLink =
        "https://play.google.com/store/apps/details?id=com.emircf.santiyepuantaj";
    final String mesaj =
        "🏗️ Şantiye Puantaj Defteri\n\n“$ekipAdi” ekibine katılmak için bağlantıya dokun:\n$deepLink\n\nUygulama yüklü değilse:\n$storeLink";
    Share.share(mesaj);
  }

  Future<bool> _onayDialoguGoster({
    required String baslik,
    required String mesaj,
    required String onayMetni,
    Color onayRengi = _kBrandTeal,
  }) async {
    final sonuc = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mesaj,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'İptal',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: onayRengi,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                onayMetni,
                                style: const TextStyle(
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

    return sonuc ?? false;
  }

  // --- ANA EKRAN YAPISI ---
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final firestoreServisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD);
    final Color cardBorderColor =
        isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFD8EAF0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isDark
                ? const Color(0xFF101317).withOpacity(0.92)
                : Colors.white.withOpacity(0.88),
        surfaceTintColor: Colors.transparent,
        title: const Text("Ekip Yönetimi"),
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<DocumentSnapshot>(
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
          final List<String> yoneticiUidleri = List<String>.from(
            teamData['yoneticiler'] ?? const <String>[],
          );
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
                    color: cardBorderColor,
                    width: 2,
                  ),
                ),
                color: cardColor,
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
                color:
                    isDark
                        ? const Color(0xFF12202A)
                        : const Color(0xFF0F7C86),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap:
                      () => _baglantiPaylas(
                        ekipAdi,
                        ekipParolasi,
                        widget.teamId,
                      ),
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
                    color: cardBorderColor,
                    width: 2,
                  ),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: firestoreServisi.getEkipUyeleriStream(
                          widget.teamId,
                        ),
                        builder: (context, uyeSnapshot) {
                          final bool yukleniyor = !uyeSnapshot.hasData;
                          final List<Map<String, dynamic>> uyeler =
                              uyeSnapshot.data ?? const <Map<String, dynamic>>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _uyelerListesiAcik = !_uyelerListesiAcik;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Ekip Üyeleri",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            yukleniyor
                                                ? "Üyeler yükleniyor..."
                                                : "${uyeler.length} kişi",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  isDark
                                                      ? Colors.white60
                                                      : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _uyelerListesiAcik
                                                ? "Gizle"
                                                : "Göster",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _kBrandTeal,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          AnimatedRotation(
                                            turns:
                                                _uyelerListesiAcik ? 0.5 : 0.0,
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            child: const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: _kBrandTeal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child:
                                    _uyelerListesiAcik
                                        ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child:
                                              yukleniyor
                                                  ? const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  )
                                                  : Column(
                                                    children:
                                                        uyeler.map((uye) {
                                  final bool isCurrentUser =
                                      user?.uid == uye['uid'];
                                  final bool isMemberKurucu =
                                      uye['uid'] == kurucuUid;
                                  final bool isMemberYonetici =
                                      yoneticiUidleri.contains(uye['uid']);
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
                                        backgroundColor: _kBrandTeal,
                                        child: Text(
                                          uye['username'].isNotEmpty
                                              ? uye['username'][0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      title: Text(
                                        uye['username'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            uye['email'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildRoleChip(
                                            isDark: isDark,
                                            label:
                                                isMemberKurucu
                                                    ? 'Kurucu'
                                                    : (isMemberYonetici
                                                        ? 'Yönetici'
                                                        : 'Üye'),
                                            color:
                                                isMemberKurucu
                                                    ? const Color(0xFFF59E0B)
                                                    : (isMemberYonetici
                                                        ? _kBrandTeal
                                                        : Colors.grey),
                                          ),
                                        ],
                                      ),
                                      trailing:
                                          (isKurucu && !isCurrentUser)
                                              ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!isMemberKurucu)
                                                    IconButton(
                                                      tooltip:
                                                          isMemberYonetici
                                                              ? 'Yöneticilikten çıkar'
                                                              : 'Yönetici yap',
                                                      icon: Icon(
                                                        isMemberYonetici
                                                            ? Icons
                                                                .shield_outlined
                                                            : Icons
                                                                .shield_moon_outlined,
                                                        color:
                                                            isMemberYonetici
                                                                ? const Color(
                                                                  0xFFF59E0B,
                                                                )
                                                                : _kBrandTeal,
                                                      ),
                                                      onPressed: () async {
                                                        final bool onaylandi =
                                                            await _onayDialoguGoster(
                                                              baslik:
                                                                  isMemberYonetici
                                                                      ? 'Yöneticilik kaldırılsın mı?'
                                                                      : 'Yönetici yapılsın mı?',
                                                              mesaj:
                                                                  isMemberYonetici
                                                                      ? "${uye['username']} artık finansal verilere erişemeyen normal üye rolüne dönecek."
                                                                      : "${uye['username']} ekipte yönetici olacak ve finansal verilere erişebilecek.",
                                                              onayMetni:
                                                                  isMemberYonetici
                                                                      ? 'Kaldır'
                                                                      : 'Yap',
                                                              onayRengi:
                                                                  isMemberYonetici
                                                                      ? const Color(
                                                                        0xFFF59E0B,
                                                                      )
                                                                      : _kBrandTeal,
                                                            );
                                                        if (!onaylandi) {
                                                          return;
                                                        }
                                                        if (isMemberYonetici) {
                                                          await firestoreServisi
                                                              .yoneticiliktenCikar(
                                                                widget.teamId,
                                                                uye['uid'],
                                                              );
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "${uye['username']} artık üye rolünde.",
                                                                ),
                                                                backgroundColor:
                                                                    _kBrandTeal,
                                                              ),
                                                            );
                                                          }
                                                        } else {
                                                          await firestoreServisi
                                                              .yoneticiYap(
                                                                widget.teamId,
                                                                uye['uid'],
                                                              );
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "${uye['username']} yönetici yapıldı.",
                                                                ),
                                                                backgroundColor:
                                                                    _kBrandTeal,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  if (!isMemberKurucu)
                                                    IconButton(
                                                      tooltip:
                                                          'Üyeyi ekipten çıkar',
                                                      icon: const Icon(
                                                        Icons
                                                            .person_remove_outlined,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () async {
                                                        final bool onaylandi =
                                                            await _onayDialoguGoster(
                                                              baslik:
                                                                  'Üye ekipten çıkarılsın mı?',
                                                              mesaj:
                                                                  "${uye['username']} ekipten kaldırılacak. Bu işlemden sonra ekip verilerine erişemeyecek.",
                                                              onayMetni:
                                                                  'Çıkar',
                                                              onayRengi:
                                                                  Colors.redAccent,
                                                            );
                                                        if (!onaylandi) {
                                                          return;
                                                        }
                                                        await firestoreServisi
                                                            .uyeyiEkiptenSil(
                                                              widget.teamId,
                                                              uye['uid'],
                                                            );
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                "${uye['username']} ekipten çıkarıldı.",
                                                              ),
                                                              backgroundColor:
                                                                  Colors
                                                                      .redAccent,
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                ],
                                              )
                                              : null,
                                    ),
                                  );
                                }).toList(),
                                                  ),
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        },
                      ),
                ),
              ),
              const SizedBox(height: 32),

              // Başka Ekibe Geç Butonu
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text("Başka Ekibe Geç"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBrandTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: _kBrandTeal),
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
      ),
    );
  }

  Widget _buildRoleChip({
    required bool isDark,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.26 : 0.16),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
        Icon(icon, color: _kBrandTeal, size: 28),
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
            icon: const Icon(Icons.edit, color: _kBrandTeal),
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
