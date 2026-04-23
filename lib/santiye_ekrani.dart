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
  final GlobalKey _fabKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

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
    super.dispose();
  }

  void _santiyeEkleVeyaDuzenleDialog(FirestoreServisi servisi, {Santiye? mevcutSantiye}) {
    if (mevcutSantiye != null) {
      _controller.text = mevcutSantiye.ad;
    } else {
      _controller.clear();
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
                                  final yeniSantiye = Santiye(id: mevcutSantiye?.id, ad: _controller.text.trim());
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
                                await servisi.santiyeSil(widget.teamId, santiyeId, santiyeAdi);
                                if (mounted) Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Şantiyeler'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark
                    ? const [
                      Color(0xFF06090D),
                      Color(0xFF0C1219),
                      Color(0xFF111827),
                    ]
                    : const [
                      Color(0xFFF6FBFD),
                      Color(0xFFECF5F9),
                      Color(0xFFE4EEF4),
                    ],
          ),
        ),
        child: StreamBuilder<List<Santiye>>(
        stream: servisi.getSantiyelerStream(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerYukleniyor(satirSayisi: 5);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
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
            );
          }

          final santiyeler = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              _shellDockBodyPadding,
            ),
            itemCount: santiyeler.length,
            itemBuilder: (context, index) {
              final santiye = santiyeler[index];

              return AnimasyonluButon(
                onPressed: () {
                  Navigator.push(
                    context,
                    SayfaGecisi(
                      sayfa: SantiyeDetayEkrani(
                        santiyeAdi: santiye.ad,
                        teamId: widget.teamId,
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
                          child: Text(
                            santiye.ad,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: _kBrandTealDark),
                          onPressed: () => _santiyeEkleVeyaDuzenleDialog(servisi, mevcutSantiye: santiye),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _silmeOnayi(servisi, santiye.id!, santiye.ad),
                        ),
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
