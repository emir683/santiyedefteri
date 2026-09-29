import 'package:flutter/material.dart';
import 'animasyon_yardimcisi.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'santiye_detay_ekrani.dart';
import 'data_models.dart';
import 'dart:ui';
import 'tur_servisi.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

const double _shellDockBodyPadding = 132;
const double _shellDockFabPadding = 96;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

class SantiyeEkrani extends StatefulWidget {
  final String teamId;
  final bool otomatikTurAktif;
  const SantiyeEkrani({
    super.key,
    required this.teamId,
    this.otomatikTurAktif = true,
  });

  @override
  State<SantiyeEkrani> createState() => _SantiyeEkraniState();
}

class _SantiyeEkraniState extends State<SantiyeEkrani> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _ilController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _fabKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  String _turkceKucukHarf(String metin) {
    return metin
        .toLowerCase()
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç');
  }

  @override
  void initState() {
    super.initState();
    if (widget.otomatikTurAktif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _turKontrol();
      });
    }
  }

  Future<void> _turKontrol() async {
    final gosterildi = await TurServisi.santiyeTurGosterildiMi();
    if (!gosterildi && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _turBaslat();
    }
  }

  void _turBaslat() {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'santiye_ekle_fab',
        keyTarget: _fabKey,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder:
                (context, controller) => _buildTooltip(
                  icon: Icons.add_business,
                  baslik: 'Yeni Şantiye Ekle',
                  aciklama:
                      'Buraya tıklayarak yeni bir şantiye veya proje ekleyebilirsiniz.\nŞantiyeleri ekledikten sonra işçilerinizi buralara atayabilirsiniz.',
                  controller: controller,
                ),
          ),
        ],
      ),
    ];

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      textSkip: 'TURU ATLA',
      paddingFocus: 12,
      onFinish: () => TurServisi.santiyeTurGosterildiOlarakIsaretle(),
      onSkip: () {
        TurServisi.santiyeTurGosterildiOlarakIsaretle();
        return true;
      },
    )..show(context: context);
  }

  Widget _buildTooltip({
    required IconData icon,
    required String baslik,
    required String aciklama,
    required TutorialCoachMarkController controller,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kBrandTeal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _kBrandTealDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  baslik,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aciklama,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => controller.next(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Anladım',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _ilController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _santiyeEkleVeyaDuzenleDialog(FirestoreServisi servisi, {Santiye? mevcutSantiye}) {
    if (mevcutSantiye != null) {
      _controller.text = mevcutSantiye.ad;
      _ilController.text = mevcutSantiye.il ?? '';
    } else {
      _controller.clear();
      _ilController.clear();
    }

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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mevcutSantiye != null ? "Şantiyeyi Düzenle" : "Yeni Şantiye",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Şantiye Adı",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.business, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ilController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "İl (Hava durumu için)",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.location_city, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_controller.text.isNotEmpty) {
                                  final yeniSantiye = Santiye(
                                    id: mevcutSantiye?.id,
                                    ad: _controller.text.trim(),
                                    il: _ilController.text.trim().isEmpty ? null : _ilController.text.trim(),
                                  );
                                  if (mevcutSantiye != null) {
                                    await servisi.santiyeGuncelle(widget.teamId, yeniSantiye);
                                  } else {
                                    await servisi.santiyeEkle(widget.teamId, yeniSantiye);
                                  }
                                  if (mounted) Navigator.pop(ctx);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBrandTeal,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                mevcutSantiye != null ? "Güncelle" : "Ekle",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Future<void> _silmeOnayi(FirestoreServisi servisi, String santiyeId, String santiyeAdi) async {
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Şantiyeyi Sil",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "'$santiyeAdi' şantiyesini ve ona bağlı tüm kayıtları silmek istediğinize emin misiniz?",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[300], fontSize: 15),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await servisi.santiyeSil(widget.teamId, santiyeId, santiyeAdi);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Silme hatası: $e')),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Sil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildSearchField(bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = _turkceKucukHarf(value);
        });
      },
      decoration: InputDecoration(
        hintText: 'Şantiye Ara...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'Şantiyeler',
        showPrivacyButton: true,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<List<Santiye>>(
          stream: servisi.getSantiyelerStream(widget.teamId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  FloatingLiquidAppBar.topPadding(context, extra: 4),
                  16,
                  _shellDockBodyPadding,
                ),
                children: [
                  _buildSearchField(isDark),
                  const SizedBox(height: 16),
                  const ShimmerYukleniyor(satirSayisi: 5, shrinkWrap: true),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  FloatingLiquidAppBar.topPadding(context, extra: 4),
                  16,
                  _shellDockBodyPadding,
                ),
                children: [
                  _buildSearchField(isDark),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_city, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz şantiye eklenmemiş.",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            final tumSantiyeler = snapshot.data!;
            final santiyeler = tumSantiyeler.where((s) {
              if (_searchQuery.isEmpty) return true;
              final adUygun = _turkceKucukHarf(s.ad).contains(_searchQuery);
              final ilUygun = s.il != null && _turkceKucukHarf(s.il!).contains(_searchQuery);
              return adUygun || ilUygun;
            }).toList();

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                FloatingLiquidAppBar.topPadding(context, extra: 4),
                16,
                _shellDockBodyPadding,
              ),
              itemCount: santiyeler.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildSearchField(isDark),
                  );
                }
                final santiye = santiyeler[index - 1];

                return AnimasyonluButon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      SayfaGecisi(
                        sayfa: SantiyeDetayEkrani(
                          santiyeAdi: santiye.ad,
                          teamId: widget.teamId,
                          il: santiye.il,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color:
                            isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFD8EAF0),
                        width: 1,
                      ),
                    ),
                    color:
                        isDark
                            ? const Color(0xFF101317)
                            : const Color(0xFFF7FBFD),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          _buildGlassIconBadge(
                            isDark: isDark,
                            icon: Icons.domain,
                            color: _kBrandTealDark,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  santiye.ad,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (santiye.il != null && santiye.il!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        santiye.il!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Sağ Aksiyonlar - Üç Nokta Menüsü
                          Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                elevation: 6,
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              icon: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  size: 19,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                              tooltip: 'İşlemler',
                              elevation: 6,
                              padding: EdgeInsets.zero,
                              splashRadius: 20,
                              position: PopupMenuPosition.under,
                              onSelected: (value) {
                                switch (value) {
                                  case 'duzenle':
                                    _santiyeEkleVeyaDuzenleDialog(servisi, mevcutSantiye: santiye);
                                    break;
                                  case 'sil':
                                    _silmeOnayi(servisi, santiye.id!, santiye.ad);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'duzenle',
                                  height: 42,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, size: 18, color: _kBrandTealDark),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Düzenle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(height: 1),
                                const PopupMenuItem<String>(
                                  value: 'sil',
                                  height: 42,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      SizedBox(width: 12),
                                      Text(
                                        'Şantiyeyi Sil',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _shellDockFabPadding),
        child: FloatingActionButton.extended(
        key: _fabKey,
        heroTag: 'santiye_fab',
        onPressed: () => _santiyeEkleVeyaDuzenleDialog(servisi),
        icon: const Icon(Icons.add_business),
        label: const Text("Şantiye Ekle"),
        backgroundColor: _kBrandTeal,
        foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGlassIconBadge({
    required bool isDark,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.18 : 0.14),
            (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
              isDark ? 0.82 : 0.92,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.16 : 0.12)),
      ),
      child: Icon(
        icon,
        size: 30,
        color: isDark ? Colors.white70 : color,
      ),
    );
  }
}
