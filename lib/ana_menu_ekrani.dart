import 'dart:ui'; // Blur efekti için GEREKLİ
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'user_model.dart';
import 'auth_servisi.dart';
import 'firestore_servisi.dart';
import 'tema_ayarlari.dart';
import 'santiye_ekrani.dart';
import 'isci_ekrani.dart';
import 'gunluk_rapor_ekrani.dart';
import 'ay_sonu_rapor_ekrani.dart';
import 'odemeler_ekrani.dart';
import 'hatirlatmalar_ekrani.dart';
import 'islem_gecmisi_ekrani.dart';
import 'ekip_yonetimi_ekrani.dart';
import 'profil_ekrani.dart';
import 'privacy_provider.dart';
import 'hakkinda_ekrani.dart';
import 'klavuz_ekrani.dart';
import 'dart:typed_data';

class AnaMenuEkrani extends StatefulWidget {
  final String teamId;
  const AnaMenuEkrani({super.key, required this.teamId});

  @override
  State<AnaMenuEkrani> createState() => _AnaMenuEkraniState();
}

class _AnaMenuEkraniState extends State<AnaMenuEkrani> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _klavuzKontrol();
    });
  }

  Future<void> _klavuzKontrol() async {
    final prefs = await SharedPreferences.getInstance();
    final bool goruldu = prefs.getBool('klavuzGoruldu') ?? false;

    if (!goruldu && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const KlavuzEkrani(isFromMenu: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authServisi = AuthServisi();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('teams')
              .doc(widget.teamId)
              .snapshots(),
      builder: (context, snapshot) {
        String ekipAdi = "Yükleniyor...";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          ekipAdi = data['ad'] ?? "Şantiye";
        }

        final String tamBaslik = "$ekipAdi Ekibi";

        return Scaffold(
          appBar: AppBar(
            title: Text(tamBaslik),
            centerTitle: true,
            actions: [
              Consumer<PrivacyProvider>(
                builder: (context, privacy, child) {
                  return IconButton(
                    icon: Icon(
                      privacy.isHidden
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    tooltip: "Tutarları Gizle/Göster",
                    onPressed: () => privacy.togglePrivacy(),
                  );
                },
              ),
            ],
          ),
          drawer: _buildBlurryDrawer(
            context,
            authServisi,
            widget.teamId,
            tamBaslik,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                child: Text(
                  "YÖNETİM",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              _buildDashboardCard(
                context: context,
                icon: Icons.edit_calendar_outlined,
                title: 'Günlük Rapor',
                subtitle: 'Veri Girişi',
                color: AppColors.greenDark,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GunlukRaporEkrani(teamId: widget.teamId),
                      ),
                    ),
              ),
              _buildDashboardCard(
                context: context,
                icon: Icons.home_work_outlined,
                title: 'Şantiyeler',
                subtitle: 'Şantiye Listesi',
                color: AppColors.tealDark,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SantiyeEkrani(teamId: widget.teamId),
                      ),
                    ),
              ),
              _buildDashboardCard(
                context: context,
                icon: Icons.groups_outlined,
                title: 'İşçiler',
                subtitle: 'Personel Yönetimi',
                color: AppColors.blueDark,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IsciEkrani(teamId: widget.teamId),
                      ),
                    ),
              ),

              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                child: Text(
                  "FİNANS",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              _buildDashboardCard(
                context: context,
                icon: Icons.receipt_long_outlined,
                title: 'Ödemeler',
                subtitle: 'Gelir & Gider',
                color: AppColors.purpleDark,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OdemelerEkrani(teamId: widget.teamId),
                      ),
                    ),
              ),
              _buildDashboardCard(
                context: context,
                icon: Icons.pie_chart_outline,
                title: 'Ay Sonu Raporu',
                subtitle: 'Detaylı Analiz',
                color: AppColors.orangeDark,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AySonuRaporEkrani(teamId: widget.teamId),
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DRAWER ---
  Widget _buildBlurryDrawer(
    BuildContext context,
    AuthServisi authServisi,
    String teamId,
    String ekipBaslik,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.80,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? const Color(0xFF1E1E1E).withOpacity(0.85)
                      : Colors.white.withOpacity(0.85),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // BAŞLIK
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.business,
                        color:
                            isDarkMode
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ekipBaslik,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Yönetim Paneli",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // MENÜ
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.person_outline,
                        title: 'Profilim',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilEkrani(),
                            ),
                          );
                        },
                      ),
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Ekip Yönetimi',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EkipYonetimiEkrani(teamId: teamId),
                            ),
                          );
                        },
                      ),
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.history_edu_outlined,
                        title: 'İşlem Geçmişi',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => IslemGecmisiEkrani(teamId: teamId),
                            ),
                          );
                        },
                      ),
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.notifications_active_outlined,
                        title: 'Hatırlatmalar',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HatirlatmalarEkrani(),
                            ),
                          );
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),

                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.help_outline,
                        title: 'Kullanım Kılavuzu',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => const KlavuzEkrani(isFromMenu: true),
                            ),
                          );
                        },
                      ),
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.info_outline,
                        title: 'Hakkında',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HakkindaEkrani(),
                            ),
                          );
                        },
                      ),

                      // -----------------------
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            "Karanlık Mod",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: isDarkMode,
                          secondary: Icon(
                            isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: Colors.grey,
                          ),
                          onChanged: (val) => themeProvider.toggleTheme(val),
                        ),
                      ),

                      // DEMO BUTONU (Geliştirme Amaçlı - İstersen kaldırabilirsin)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.dataset,
                        title: 'Demo Verileri Yükle',
                        color: Colors.orangeAccent,
                        onTap: () async {
                          Navigator.pop(context);
                          final onayla = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text("Demo Verileri?"),
                                  content: const Text(
                                    "Mevcut ekibine rastgele şantiyeler, işçiler ve raporlar eklenecek. Onaylıyor musun?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: const Text("İptal"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text("YÜKLE"),
                                    ),
                                  ],
                                ),
                          );
                          if (onayla == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Veriler oluşturuluyor, lütfen bekleyin...",
                                ),
                              ),
                            );
                            await FirestoreServisi(
                              kullaniciId: "temp",
                            ).demoVerileriYukle(teamId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "✅ Demo verileri başarıyla yüklendi!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),

                      // SIFIRLAMA BUTONU
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.delete_forever_outlined,
                        title: 'Tüm Verileri Sıfırla',
                        color: Colors.redAccent,
                        onTap: () async {
                          Navigator.pop(context);
                          final onayla = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text("DİKKAT: Veri Sıfırlama"),
                                  content: const Text(
                                    "TÜM Şantiyeler, İşçiler, Raporlar ve Finansal veriler KALICI OLARAK silinecektir.\n\nBu işlem geri alınamaz. Onaylıyor musunuz?",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: const Text("İptal"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text("EVET, SİL"),
                                    ),
                                  ],
                                ),
                          );
                          if (onayla == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Tüm veriler siliniyor..."),
                              ),
                            );
                            await FirestoreServisi(
                              kullaniciId: "temp",
                            ).tumVerileriSil(widget.teamId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ Tüm veriler başarıyla sıfırlandı.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildGlassDrawerItem(
                    context,
                    icon: Icons.logout,
                    title: 'Çıkış Yap',
                    color: Colors.redAccent,
                    isTransparent: false,
                    onTap: () async {
                      Navigator.pop(context);
                      final onayla = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text("Çıkış Yap"),
                              content: const Text(
                                "Oturumu kapatmak istiyor musunuz?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("İptal"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    "Çıkış Yap",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                      if (onayla == true) {
                        await authServisi.signOut();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MyApp()),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    bool isTransparent = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isTransparent
                ? (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03))
                : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? (isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
