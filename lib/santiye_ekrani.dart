import 'package:flutter/material.dart';
import 'animasyon_yardimcisi.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'santiye_detay_ekrani.dart';
import 'data_models.dart';
import 'dart:ui';
import 'tur_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';

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

class _SantiyeEkraniState extends State<SantiyeEkrani>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _ilController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Rehber Tur Anahtarları
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _santiyeKartKey = GlobalKey();
  final GlobalKey _santiyeMenuKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // İnteraktif Tur & Örnek Demo Veri Durumu
  bool _isTourActive = false;
  late AnimationController _demoAnimController;
  late Animation<double> _demoFadeAnimation;
  late Animation<Offset> _demoSlideAnimation;

  final List<Santiye> _demoSantiyeler = [
    Santiye(
      id: 'demo_santiye_1',
      ad: 'Koru Konutları Rezidans',
      il: 'İstanbul / Kadıköy',
    ),
    Santiye(
      id: 'demo_santiye_2',
      ad: 'Vadi Panorama İş Merkezi',
      il: 'Ankara / Çankaya',
    ),
  ];

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
    _demoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _demoFadeAnimation = CurvedAnimation(
      parent: _demoAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _demoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _demoAnimController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    if (widget.otomatikTurAktif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _turKontrol();
      });
    }
  }

  @override
  void dispose() {
    _demoAnimController.dispose();
    _controller.dispose();
    _ilController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _turKontrol() async {
    final gosterildi = await TurServisi.santiyeTurGosterildiMi();
    if (!gosterildi && mounted) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) _turBaslat();
    }
  }

  void _turBaslat({bool manual = false}) async {
    if (_isTourActive) return;
    setState(() {
      _isTourActive = true;
    });

    await _demoAnimController.forward();
  }

  Future<void> _turSonlandir() async {
    await _demoAnimController.reverse();
    if (mounted) {
      setState(() {
        _isTourActive = false;
      });
    }
    await TurServisi.santiyeTurGosterildiOlarakIsaretle();
  }

  List<TourStep> _buildTourSteps() {
    return [
      TourStep(
        id: 'santiye_genel_tanitim',
        title: 'Şantiye & Proje Yönetimi',
        description:
            'Tüm şantiye, proje ve sahalarınızı bu ekrandan kolayca yönetin. Günlük puantaj, işçilik takibi ve malzeme harcamaları bu projelere bağlanır.',
        icon: Icons.location_city_rounded,
        targetKey: null,
      ),
      TourStep(
        id: 'santiye_arama',
        title: 'Hızlı Arama & Filtreleme',
        description:
            'Şantiye adına veya şehir bilgisine göre anında arama yapın. Onlarca projeniz olsa bile saniyeler içinde istediğinize ulaşın.',
        icon: Icons.search_rounded,
        targetKey: _searchKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 14.0,
      ),
      TourStep(
        id: 'santiye_karti',
        title: 'Şantiye Kartı ve Detaylar',
        description:
            'Şantiye kartına dokunarak projenin detay sayfasına gidebilir; oradan puantaj geçmişi, hakedişler, malzeme kayıtları ve şantiye özel raporlarına erişebilirsiniz.',
        icon: Icons.domain_rounded,
        targetKey: _santiyeKartKey,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        targetBorderRadius: 18.0,
      ),
      TourStep(
        id: 'santiye_menu',
        title: '3 Nokta Hızlı İşlemler',
        description:
            'Bu menüyü kullanarak şantiyenizin adını veya konumunu düzenleyebilir ya da projeyi silebilirsiniz.',
        icon: Icons.more_vert_rounded,
        targetKey: _santiyeMenuKey,
        targetPadding: const EdgeInsets.all(4),
        targetBorderRadius: 20.0,
      ),
      TourStep(
        id: 'santiye_ekle_fab',
        title: 'Yeni Şantiye Ekle',
        description:
            'Buraya dokunarak firmanızın veya taşeron ekibinizin yeni şantiyesini ve projesini saniyeler içinde ekleyin.',
        icon: Icons.add_business_rounded,
        targetKey: _fabKey,
        targetPadding: const EdgeInsets.all(6),
        targetBorderRadius: 20.0,
      ),
    ];
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Şantiye Adı",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.location_city, color: _kBrandTeal),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBrandTeal)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ilController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "İl / Konum (Opsiyonel)",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.map, color: _kBrandTeal),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kBrandTeal)),
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
                                final ad = _controller.text.trim();
                                final il = _ilController.text.trim();
                                if (ad.isNotEmpty) {
                                  Navigator.pop(ctx);
                                  if (mevcutSantiye != null) {
                                    await servisi.santiyeGuncelle(
                                      widget.teamId,
                                      Santiye(
                                        id: mevcutSantiye.id,
                                        ad: ad,
                                        il: il.isNotEmpty ? il : null,
                                      ),
                                    );
                                  } else {
                                    await servisi.santiyeEkle(
                                      widget.teamId,
                                      Santiye(
                                        ad: ad,
                                        il: il.isNotEmpty ? il : null,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBrandTeal,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(mevcutSantiye != null ? "Kaydet" : "Ekle", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _silmeOnayi(FirestoreServisi servisi, String santiyeId, String santiyeAdi) {
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
    return KeyedSubtree(
      key: _searchKey,
      child: TextField(
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
      ),
    );
  }

  Widget _buildSantiyeKarti({
    required Santiye santiye,
    required bool isDark,
    required FirestoreServisi servisi,
    Key? cardKey,
    Key? menuKey,
    bool isDemo = false,
  }) {
    return AnimasyonluButon(
      onPressed: () {
        if (isDemo) return;
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
        key: cardKey,
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFD8EAF0),
            width: 1,
          ),
        ),
        color: isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildGlassIconBadge(
                isDark: isDark,
                icon: Icons.domain_rounded,
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
                        color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    elevation: 6,
                  ),
                ),
                child: PopupMenuButton<String>(
                  key: menuKey,
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
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
                    if (isDemo) return;
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
  }

  Widget _buildDemoList(bool isDark, FirestoreServisi servisi) {
    return AnimatedBuilder(
      animation: _demoAnimController,
      builder: (context, child) {
        if (_demoAnimController.value <= 0.001) {
          return const SizedBox.shrink();
        }
        return FadeTransition(
          opacity: _demoFadeAnimation,
          child: SlideTransition(
            position: _demoSlideAnimation,
            child: Column(
              children: [
                _buildSantiyeKarti(
                  santiye: _demoSantiyeler[0],
                  isDark: isDark,
                  servisi: servisi,
                  cardKey: _santiyeKartKey,
                  menuKey: _santiyeMenuKey,
                  isDemo: true,
                ),
                _buildSantiyeKarti(
                  santiye: _demoSantiyeler[1],
                  isDark: isDark,
                  servisi: servisi,
                  isDemo: true,
                ),
              ],
            ),
          ),
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
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: 'Şantiyeler',
        showPrivacyButton: true,
        showTourButton: true,
        onTourPressed: () => _turBaslat(manual: true),
      ),
      body: Stack(
        children: [
          GlassPageSurface(
            preferSoftLightBackground: true,
            child: StreamBuilder<List<Santiye>>(
              stream: servisi.getSantiyelerStream(widget.teamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isTourActive) {
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

                final tumSantiyeler = snapshot.data ?? [];
                final santiyeler = tumSantiyeler.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  final adUygun = _turkceKucukHarf(s.ad).contains(_searchQuery);
                  final ilUygun = s.il != null && _turkceKucukHarf(s.il!).contains(_searchQuery);
                  return adUygun || ilUygun;
                }).toList();

                final bool veriBos = santiyeler.isEmpty;

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

                    // Demo Veriler (Tur esnasında animasyonla belirir/kaybolur)
                    _buildDemoList(isDark, servisi),

                    // Gerçek veriler listelenir
                    if (!veriBos) ...[
                      for (final santiye in santiyeler)
                        _buildSantiyeKarti(
                          santiye: santiye,
                          isDark: isDark,
                          servisi: servisi,
                        ),
                    ] else if (!_isTourActive) ...[
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
                  ],
                );
              },
            ),
          ),

          // İnteraktif Rehber Tur Katmanı
          if (_isTourActive)
            InteractiveTourOverlay(
              steps: _buildTourSteps(),
              onFinish: _turSonlandir,
              onSkip: _turSonlandir,
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _shellDockFabPadding),
        child: FloatingActionButton.extended(
          key: _fabKey,
          heroTag: 'santiye_fab',
          onPressed: () => _santiyeEkleVeyaDuzenleDialog(servisi),
          icon: const Icon(Icons.add_business_rounded),
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
