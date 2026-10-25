import 'package:flutter/material.dart';
import 'animasyon_yardimcisi.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'isci_detay_ekrani.dart';
import 'rol_provider.dart';
import 'dart:ui';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';
import 'tur_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_empty_state.dart';
import 'puanlama_servisi.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

const double _shellDockBodyPadding = 132;
const double _shellDockFabPadding = 96;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

class IsciEkrani extends StatefulWidget {
  final String teamId;
  final bool otomatikTurAktif;
  const IsciEkrani({
    super.key,
    required this.teamId,
    this.otomatikTurAktif = true,
  });

  @override
  State<IsciEkrani> createState() => _IsciEkraniState();
}

class _IsciEkraniState extends State<IsciEkrani>
    with SingleTickerProviderStateMixin {
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _maasController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _demoAnimController;
  late Animation<double> _demoFadeAnimation;
  late Animation<Offset> _demoSlideAnimation;
  bool _turAktif = false;

  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _demoCardBadgeKey = GlobalKey();
  final GlobalKey _demoCardMoreKey = GlobalKey();

  static final List<Isci> _demoIsciler = [
    Isci(
      id: 'demo_1',
      ad: 'Ahmet Yılmaz',
      gunlukMaas: 2400,
      isciTuru: 'Çekirdek Ekip',
    ),
    Isci(
      id: 'demo_2',
      ad: 'Mehmet Demir',
      gunlukMaas: 1950,
      isciTuru: 'Misafir',
    ),
  ];

  static const String _turkceAlfabe = 'abcçdefgğhıijklmnoöprsştuüvyz';
  static final Map<String, int> _turkceHarfSirasi = {
    for (int i = 0; i < _turkceAlfabe.length; i++) _turkceAlfabe[i]: i,
  };

  String _turkceKucukHarf(String metin) {
    return metin
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .toLowerCase();
  }

  int _turkceMetinKarsilastir(String a, String b) {
    final aa = _turkceKucukHarf(a).trim();
    final bb = _turkceKucukHarf(b).trim();
    final minUzunluk = aa.length < bb.length ? aa.length : bb.length;

    for (int i = 0; i < minUzunluk; i++) {
      final ca = aa[i];
      final cb = bb[i];
      if (ca == cb) continue;

      final sa = _turkceHarfSirasi[ca];
      final sb = _turkceHarfSirasi[cb];

      if (sa != null && sb != null) {
        return sa.compareTo(sb);
      }
      if (sa != null) return -1;
      if (sb != null) return 1;
      return ca.codeUnitAt(0).compareTo(cb.codeUnitAt(0));
    }

    return aa.length.compareTo(bb.length);
  }
  @override
  void initState() {
    super.initState();
    _demoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _demoFadeAnimation = CurvedAnimation(
      parent: _demoAnimController,
      curve: Curves.easeOutCubic,
    );

    _demoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _demoAnimController,
      curve: Curves.easeOutBack,
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
    _adController.dispose();
    _maasController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _turKontrol() async {
    final gosterildi = await TurServisi.isciTurGosterildiMi();
    if (!gosterildi && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _turBaslat();
    }
  }

  Future<void> _turBaslat({bool zorla = false}) async {
    if (_turAktif && !zorla) return;

    setState(() {
      _turAktif = true;
    });

    // Örnek işçi kartları yumuşakça içeri akar
    await _demoAnimController.forward();
  }

  Future<void> _turBitir() async {
    // Tur tamamlandığında veya atlandığında örnek işçiler pürüzsüzce kaybolur
    await _demoAnimController.reverse();
    if (mounted) {
      setState(() {
        _turAktif = false;
      });
    }
    await TurServisi.isciTurGosterildiOlarakIsaretle();
  }

  List<TourStep> _buildTourSteps() {
    return [
      const TourStep(
        id: 'isci_giris',
        title: 'İşçi Yönetim Merkezi',
        description:
            'Şantiyelerinizde çalışan tüm usta, kalfa ve taşeron personellerinizi buradan listeleyebilir, arayabilir ve yönetebilirsiniz.',
        icon: Icons.groups_rounded,
      ),
      TourStep(
        id: 'isci_rozet',
        targetKey: _demoCardBadgeKey,
        title: 'İşçi Kimliği & Rozeti',
        description:
            'Ad ve soyadın ilk harfleriyle oluşturulan özel cam rozet sayesinde işçilerinizi anında tanırsınız. Karta dokunarak geçmiş puantajlarına ve hakedişlerine ulaşabilirsiniz.',
        icon: Icons.badge_outlined,
        targetBorderRadius: 16,
      ),
      TourStep(
        id: 'isci_menu',
        targetKey: _demoCardMoreKey,
        title: '3 Nokta İşlem Menüsü',
        description:
            'Üç noktaya dokunarak işçinin günlük yevmiyesini güncelleyebilir, şantiye ekibinden silebilir veya mobil hesabına bağlayabilirsiniz.',
        icon: Icons.more_vert_rounded,
        targetBorderRadius: 14,
      ),
      TourStep(
        id: 'isci_arama',
        targetKey: _searchKey,
        title: 'Akıllı Arama Çubuğu',
        description:
            'Yüzlerce çalışanınız olsa dahi, arama kutusuna isim yazarak dilediğiniz işçiyi saniyeler içinde anında filtreleyin.',
        icon: Icons.search_rounded,
        targetBorderRadius: 14,
      ),
      TourStep(
        id: 'isci_ekle',
        targetKey: _fabKey,
        title: 'Yeni İşçi Tanımlama',
        description:
            'Ekibinize yeni bir usta veya işçi katıldığında bu butona dokunarak adını, günlük ücretini ve ekip türünü girip hemen ekleyebilirsiniz.',
        icon: Icons.person_add_rounded,
        targetBorderRadius: 18,
      ),
    ];
  }


  // İşçi Ekleme veya Düzenleme Diyaloğu
  Future<void> _isciEkleVeyaDuzenleDialog(
    FirestoreServisi servisi, {
    Isci? mevcutIsci,
  }) async {
    if (mevcutIsci != null) {
      _adController.text = mevcutIsci.ad;
      _maasController.text = mevcutIsci.gunlukMaas.toString();
    } else {
      _adController.clear();
      _maasController.clear();
    }
    
    String seciliTur = mevcutIsci?.isciTuru ?? "Çekirdek Ekip";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Stack(
              children: [
                // BLUR EFEKTİ
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
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mevcutIsci != null
                                ? 'İşçiyi Düzenle'
                                : 'Yeni İşçi Ekle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // TÜR SEÇİMİ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: const Text("Çekirdek Ekip"),
                                selected: seciliTur == "Çekirdek Ekip",
                                onSelected: (val) {
                                  if (val) setStateDialog(() => seciliTur = "Çekirdek Ekip");
                                },
                                selectedColor: _kBrandTeal.withValues(alpha: 0.3),
                                labelStyle: TextStyle(
                                  color: seciliTur == "Çekirdek Ekip" ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Text("Misafir"),
                                selected: seciliTur == "Misafir",
                                onSelected: (val) {
                                  if (val) setStateDialog(() => seciliTur = "Misafir");
                                },
                                selectedColor: _kBrandTeal.withValues(alpha: 0.3),
                                labelStyle: TextStyle(
                                  color: seciliTur == "Misafir" ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // AD SOYAD INPUT
                          TextField(
                            controller: _adController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Ad Soyad",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // MAAŞ INPUT
                          TextField(
                            controller: _maasController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Günlük Maaş (TL)",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.attach_money,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // BUTONLAR
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_adController.text.isNotEmpty &&
                                        _maasController.text.isNotEmpty) {
                                      final isci = Isci(
                                        id: mevcutIsci?.id,
                                        ad: _adController.text.trim(),
                                        gunlukMaas:
                                            double.tryParse(_maasController.text) ??
                                            0,
                                        isciTuru: seciliTur,
                                        linkedUserId: mevcutIsci?.linkedUserId,
                                      );

                                      if (mevcutIsci != null) {
                                        await servisi.isciGuncelle(
                                          widget.teamId,
                                          isci,
                                        );
                                      } else {
                                        await servisi.isciEkle(widget.teamId, isci);
                                      }
                                      if (mounted && ctx.mounted) {
                                        Navigator.pop(ctx);
                                        PuanlamaServisi.islemSonrasiKontrolEtVeGoster(context);
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
      },
    );
  }

  Future<void> _silmeOnayi(
    FirestoreServisi servisi,
    String isciId,
    String isciAdi,
  ) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.8),
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
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
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
                        Icons.person_remove,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "İşçiyi Sil",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "'$isciAdi' adlı işçiyi silmek istediğinize emin misiniz?",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[300], fontSize: 15),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await servisi.isciSil(widget.teamId, isciId, isciAdi);
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Sil",
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

  Future<void> _hesapBaglaDialog(FirestoreServisi servisi, Isci isci, List<Isci> tumIsciler) async {
    Map<String, dynamic>? seciliUye;

    showDialog(
      context: context,
      builder: (ctx) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    color: const Color(0xFF3B82F6),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Hesabı Bağla',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu işçiye bağlamak istediğiniz ekip üyesini seçin. Her üyeye yalnızca bir işçi hesabı bağlanabilir.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: servisi.getEkipUyeleriStream(widget.teamId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            'Hata: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          );
                        }
                        
                        final tumUyeler = snapshot.data ?? [];
                        
                        // Zaten eşleşmiş Uid'leri bul
                        final bagliUidler = tumIsciler
                            .where((i) => i.id != isci.id && i.linkedUserId != null)
                            .map((i) => i.linkedUserId!)
                            .toSet();

                        // Eşleşmemiş üyeleri filtrele
                        final uyeler = tumUyeler.where((uye) => !bagliUidler.contains(uye['uid'])).toList();

                        if (uyeler.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group_off_rounded,
                                    size: 44,
                                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Bağlanabilecek uygun üye kalmadı.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '(Tüm ekip üyeleri zaten eşleştirilmiş)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Theme(
                          data: Theme.of(context).copyWith(
                            scrollbarTheme: ScrollbarThemeData(
                              thumbColor: WidgetStateProperty.all(
                                isDark ? Colors.white24 : Colors.black12,
                              ),
                            ),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: uyeler.length,
                              padding: const EdgeInsets.only(right: 8),
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final uye = uyeler[index];
                                final String username = uye['username'] ?? 'İsimsiz';
                                final String email = uye['email'] ?? '';
                                final bool isSelected = seciliUye?['uid'] == uye['uid'];
                                final String ilkHarf = username.isNotEmpty ? username[0].toUpperCase() : '?';

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      seciliUye = uye;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08)
                                          : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50]),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[200]!),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Profil Avatarı
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: isSelected
                                              ? const Color(0xFF3B82F6)
                                              : (isDark ? Colors.grey[800] : Colors.grey[300]),
                                          child: Text(
                                            ilkHarf,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark ? Colors.grey[200] : Colors.grey[700]),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Üye Bilgileri
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                username,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                email,
                                                style: TextStyle(
                                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Seçim İndikatörü (Radyo Buton)
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF3B82F6)
                                                  : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
                                              width: isSelected ? 5.5 : 1.5,
                                            ),
                                            color: isSelected ? Colors.transparent : Colors.transparent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: seciliUye == null
                      ? null
                      : () async {
                          try {
                            await servisi.isciyiUidIleHesabaBagla(
                              widget.teamId,
                              isci.id!,
                              seciliUye!['uid'],
                              seciliUye!['email'],
                            );
                            if (mounted && ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted && context.mounted) {
                              showDialog(
                                context: context,
                                builder: (errCtx) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  title: Text(
                                    'Hata',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[350] : Colors.black87,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(errCtx),
                                      child: const Text('Tamam'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                  child: const Text(
                    'Bağla',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _baglantiKaldir(FirestoreServisi servisi, Isci isci) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantıyı Kaldır'),
        content: const Text('Bu işçinin hesap bağlantısını kaldırmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (onay == true) {
      try {
        await servisi.isciBaglantisiniKaldir(widget.teamId, isci.id!);
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (errCtx) => AlertDialog(
              title: const Text('Hata'),
              content: Text(e.toString().replaceAll('Exception: ', '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(errCtx),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      key: _searchKey,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = _turkceKucukHarf(value);
          });
        },
        decoration: InputDecoration(
          hintText: 'İşçi Ara...',
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
          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Future<void> _iscileriMetinOlarakPaylas(BuildContext context, bool isFinans, String teamId) async {
    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
      final isciler = await servisi.getIscilerStream(teamId).first;
      if (isciler.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paylaşılacak işçi kaydı bulunamadı.')),
          );
        }
        return;
      }
      isciler.sort((a, b) => _turkceMetinKarsilastir(a.ad, b.ad));
      final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());
      final sb = StringBuffer();
      sb.writeln('👷 İŞÇİ LİSTESİ');
      sb.writeln('📅 Tarih: $dateStr');
      sb.writeln('👥 Toplam: ${isciler.length} İşçi');
      sb.writeln('──────────────────────────────');
      for (int i = 0; i < isciler.length; i++) {
        final isci = isciler[i];
        final maasText = isFinans ? ' | Günlük: ${isci.gunlukMaas.toStringAsFixed(0)} ₺' : '';
        sb.writeln('${i + 1}. ${isci.ad} (${isci.isciTuru})$maasText');
      }
      sb.writeln('──────────────────────────────');
      sb.writeln('Şantiye Puantaj Defteri');

      final size = MediaQuery.of(context).size;
      final origin = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 10,
        height: 10,
      );

      await Share.share(sb.toString(), sharePositionOrigin: origin);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final rolProvider = Provider.of<RolProvider>(context);
    final bool isFinans = rolProvider.isFinansalErisim;

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor:
              isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
          appBar: FloatingLiquidAppBar(
            title: 'İşçiler',
            showPrivacyButton: true,
            showTourButton: true,
            onTourPressed: () => _turBaslat(zorla: true),
            actions: [
              Builder(
                builder: (btnCtx) => IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'İşçi Listesini Paylaş',
                  onPressed: () => _iscileriMetinOlarakPaylas(btnCtx, isFinans, widget.teamId),
                ),
              ),
            ],
          ),
          body: GlassPageSurface(
            preferSoftLightBackground: true,
            child: StreamBuilder<List<Isci>>(
              stream: servisi.getIscilerStream(widget.teamId),
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
                      const ShimmerYukleniyor(satirSayisi: 6, shrinkWrap: true),
                    ],
                  );
                }

                final gercekIsciler = snapshot.hasData
                    ? [...snapshot.data!]
                    : <Isci>[];
                gercekIsciler.sort((a, b) => _turkceMetinKarsilastir(a.ad, b.ad));

                // Arama filtresi
                final searchFiltreli = gercekIsciler.where((i) {
                  if (_searchQuery.isEmpty) return true;
                  return _turkceKucukHarf(i.ad).contains(_searchQuery);
                }).toList();

                // Üye rolunde: sadece kendi bağlı işçisini göster
                final filtrelenmisIsciler = isFinans
                    ? searchFiltreli
                    : searchFiltreli
                        .where((i) => i.linkedUserId == user?.uid)
                        .toList();

                return AnimatedBuilder(
                  animation: _demoAnimController,
                  builder: (context, child) {
                    final bool demoAktif =
                        _turAktif || _demoAnimController.value > 0.01;

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        FloatingLiquidAppBar.topPadding(context, extra: 4),
                        16,
                        _shellDockBodyPadding,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildSearchField(isDark),
                        ),

                        // Örnek / Demo Veriler (Tur esnasında animasyonla içeri akar, bitince süzülerek kaybolur)
                        if (demoAktif)
                          FadeTransition(
                            opacity: _demoFadeAnimation,
                            child: SlideTransition(
                              position: _demoSlideAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < _demoIsciler.length; i++)
                                    _buildIsciKarti(
                                      isci: _demoIsciler[i],
                                      isDark: isDark,
                                      isFinans: isFinans,
                                      servisi: servisi,
                                      tumIsciler: filtrelenmisIsciler,
                                      badgeKey: i == 0 ? _demoCardBadgeKey : null,
                                      moreKey: i == 0 ? _demoCardMoreKey : null,
                                      isDemo: true,
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // Gerçek İşçi Listesi
                        for (final isci in filtrelenmisIsciler)
                          _buildIsciKarti(
                            isci: isci,
                            isDark: isDark,
                            isFinans: isFinans,
                            servisi: servisi,
                            tumIsciler: filtrelenmisIsciler,
                          ),

                        // Veri Yok Uyarısı (Sadece demo aktif değilken ve liste boşken gösterilir)
                        if (!demoAktif && filtrelenmisIsciler.isEmpty)
                          GlassEmptyState(
                            icon: isFinans ? Icons.badge_outlined : Icons.link_off_rounded,
                            title: isFinans ? "Kayıtlı Çalışan Bulunmuyor" : "Bağlı Çalışan Bulunamadı",
                            description: isFinans
                                ? "Ekibinizdeki ustaları ve personeli ekleyerek puantaj ve hakediş takiplerini gerçekleştirebilirsiniz."
                                : "Hesabınız henüz bir çalışan profili ile eşleştirilmemiş. Lütfen yöneticiniz ile iletişime geçiniz.",
                            actionLabel: isFinans ? "Yeni Çalışan Ekle" : null,
                            actionIcon: isFinans ? Icons.person_add_alt_1_rounded : null,
                            onAction: isFinans ? () => _isciEkleVeyaDuzenleDialog(servisi) : null,
                          ),
                      ],
                    );
                  },
                );

              },
            ),
          ),
          floatingActionButton: isFinans
              ? Padding(
                  padding: const EdgeInsets.only(bottom: _shellDockFabPadding),
                  child: FloatingActionButton.extended(
                    key: _fabKey,
                    heroTag: 'isci_fab',
                    onPressed: () => _isciEkleVeyaDuzenleDialog(servisi),
                    icon: const Icon(Icons.person_add),
                    label: const Text("İşçi Ekle"),
                    backgroundColor: _kBrandTeal,
                    foregroundColor: Colors.white,
                  ),
                )
              : null,
        ),
        if (_turAktif)
          InteractiveTourOverlay(
            steps: _buildTourSteps(),
            onFinish: _turBitir,
            onSkip: _turBitir,
          ),
      ],
    );
  }

  Widget _buildIsciKarti({
    required Isci isci,
    required bool isDark,
    required bool isFinans,
    required FirestoreServisi servisi,
    required List<Isci> tumIsciler,
    Key? badgeKey,
    Key? moreKey,
    bool isDemo = false,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
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
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (isDemo) return;
                  Navigator.push(
                    context,
                    SayfaGecisi(
                      sayfa: IsciDetayEkrani(
                        isci: isci,
                        teamId: widget.teamId,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    // Sol İkon Kutusu - Ad & Soyad Baş Harfleri Rozeti
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildGlassInitialsBadge(
                          key: badgeKey,
                          isDark: isDark,
                          adSoyad: isci.ad,
                          color: _kBrandTealDark,
                        ),
                        // Bağlı hesap işareti
                        if (isci.linkedUserId != null)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF101317)
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.link_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Orta Bilgi Alanı
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isci.ad,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isFinans)
                            Text(
                              '${isci.gunlukMaas.toStringAsFixed(2)} TL / Gün',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                              ),
                            )
                          else
                            Text(
                              'Yevmiye gizli',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

                                // Sağ Aksiyonlar - Üç Nokta Menüsü (sadece yetkili kullanıcılar görür)
                                if (isFinans)
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      popupMenuTheme: PopupMenuThemeData(
                                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.12)
                                                : const Color(0xFFE2E8F0),
                                            width: 1,
                                          ),
                                        ),
                                        elevation: 6,
                                      ),
                                    ),
                                    child: PopupMenuButton<String>(
                                      key: moreKey,
                                      icon: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
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
                                        if (isDemo) return;
                                        switch (value) {
                                          case 'duzenle':
                                            _isciEkleVeyaDuzenleDialog(
                                              servisi,
                                              mevcutIsci: isci,
                                            );
                                            break;
                                          case 'bagla':
                                            if (isci.linkedUserId != null) {
                                              _baglantiKaldir(servisi, isci);
                                            } else {
                                              _hesapBaglaDialog(
                                                servisi,
                                                isci,
                                                tumIsciler,
                                              );
                                            }
                                            break;
                                          case 'sil':
                                            _silmeOnayi(servisi, isci.id!, isci.ad);
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
                                        PopupMenuItem<String>(
                                          value: 'bagla',
                                          height: 42,
                                          child: Row(
                                            children: [
                                              Icon(
                                                isci.linkedUserId != null
                                                    ? Icons.link_off_rounded
                                                    : Icons.link_rounded,
                                                size: 18,
                                                color: isci.linkedUserId != null
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF3B82F6),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                isci.linkedUserId != null
                                                    ? 'Bağlantıyı Kaldır'
                                                    : 'Hesaba Bağla',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isci.linkedUserId != null
                                                      ? const Color(0xFFEF4444)
                                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
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
                                                'İşçiyi Sil',
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

                                // Her zaman gösterilen ok işareti
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        );
  }



  String _adSoyadBasHarfleri(String adSoyad) {
    final trimli = adSoyad.trim();
    if (trimli.isEmpty) return '?';
    final parcalar = trimli.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parcalar.isEmpty) return '?';
    if (parcalar.length == 1) {
      return parcalar[0][0].toUpperCase();
    }
    final ilk = parcalar.first[0].toUpperCase();
    final son = parcalar.last[0].toUpperCase();
    return '$ilk$son';
  }

  Widget _buildGlassInitialsBadge({
    Key? key,
    required bool isDark,
    required String adSoyad,
    required Color color,
  }) {
    final harfler = _adSoyadBasHarfleri(adSoyad);
    return Container(
      key: key,
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.28 : 0.20),
            (isDark ? const Color(0xFF171B20) : Colors.white).withValues(alpha: 
              isDark ? 0.85 : 0.95,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        harfler,
        style: TextStyle(
          fontSize: harfler.length > 1 ? 16 : 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
