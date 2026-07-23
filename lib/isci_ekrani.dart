import 'package:flutter/material.dart';
import 'animasyon_yardimcisi.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'isci_detay_ekrani.dart';
import 'rol_provider.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'tur_servisi.dart';

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

class _IsciEkraniState extends State<IsciEkrani> {
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _maasController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    final gosterildi = await TurServisi.isciTurGosterildiMi();
    if (!gosterildi && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _turBaslat();
    }
  }

  void _turBaslat() {
    // FAB sadece finans yetkisi olanlarda görünüyor. Yoksa turu iptal et.
    if (_fabKey.currentContext == null) {
      TurServisi.isciTurGosterildiOlarakIsaretle();
      return;
    }

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'isci_ekle_fab',
        keyTarget: _fabKey,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder:
                (context, controller) => _buildTooltip(
                  icon: Icons.person_add,
                  baslik: 'Yeni İşçi Ekle',
                  aciklama:
                      'Ekibinize yeni işçileri buradan katabilirsiniz.\nMaaşını belirleyip hemen yevmiyelerini yazmaya başlayın.',
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
      onFinish: () => TurServisi.isciTurGosterildiOlarakIsaretle(),
      onSkip: () {
        TurServisi.isciTurGosterildiOlarakIsaretle();
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
    _adController.dispose();
    _maasController.dispose();
    _searchController.dispose();
    super.dispose();
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
      barrierColor: Colors.black.withOpacity(0.8),
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
                                selectedColor: _kBrandTeal.withOpacity(0.3),
                                labelStyle: TextStyle(
                                  color: seciliTur == "Çekirdek Ekip" ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: Colors.white.withOpacity(0.05),
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
                                selectedColor: _kBrandTeal.withOpacity(0.3),
                                labelStyle: TextStyle(
                                  color: seciliTur == "Misafir" ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: Colors.white.withOpacity(0.05),
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
                              fillColor: Colors.white.withOpacity(0.05),
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
                              fillColor: Colors.white.withOpacity(0.05),
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
                                      if (mounted) Navigator.pop(ctx);
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
                                await servisi.isciSil(widget.teamId, isciId);
                                if (mounted) Navigator.pop(ctx);
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
                              thumbColor: MaterialStateProperty.all(
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
                                          ? const Color(0xFF3B82F6).withOpacity(isDark ? 0.15 : 0.08)
                                          : (isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50]),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!),
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
                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final rolProvider = Provider.of<RolProvider>(context);
    final bool isFinans = rolProvider.isFinansalErisim;

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
        title: const Text('İşçiler'),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Isci>>(
                stream: servisi.getIscilerStream(widget.teamId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const ShimmerYukleniyor(satirSayisi: 6);
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Henüz işçi eklenmemiş.",
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  final isciler = [...snapshot.data!]
                    ..sort((a, b) => _turkceMetinKarsilastir(a.ad, b.ad));

                  // Arama filtresi
                  final searchFiltreli = isciler.where((i) {
                    if (_searchQuery.isEmpty) return true;
                    return _turkceKucukHarf(i.ad).contains(_searchQuery);
                  }).toList();

                  // Üye rolunde: sadece kendi bağlı işçisini göster
                  final filtrelenmisIsciler = isFinans
                      ? searchFiltreli
                      : searchFiltreli
                            .where((i) => i.linkedUserId == user?.uid)
                            .toList();

                  if (filtrelenmisIsciler.isEmpty && !isFinans) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link_off_rounded,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hesabınıza bağlı işçi yok.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yöneticinizden hesabınızı bir\nişçiye bağlamasini isteyin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _shellDockBodyPadding,
                    ),
                    itemCount: filtrelenmisIsciler.length,
                    itemBuilder: (context, index) {
                      final isci = filtrelenmisIsciler[index];

                      return AnimasyonluButon(
                        onPressed: () {
                          // Detay sayfasına git
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
                                // Sol İkon Kutusu
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildGlassIconBadge(
                                      isDark: isDark,
                                      icon: Icons.engineering,
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

                                // Sağ Butonlar - sadece yetkili kullanıcılar görür
                                if (isFinans)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Hesap Bağla Butonu
                                      IconButton(
                                        icon: Icon(
                                          isci.linkedUserId != null
                                              ? Icons.link_off_rounded
                                              : Icons.link_rounded,
                                          color: isci.linkedUserId != null
                                              ? const Color(0xFF3B82F6)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        tooltip: isci.linkedUserId != null
                                            ? 'Bağlantıyı Kaldır'
                                            : 'Hesaba Bağla',
                                        onPressed: () => isci.linkedUserId != null
                                            ? _baglantiKaldir(servisi, isci)
                                            : _hesapBaglaDialog(servisi, isci, isciler),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: _kBrandTealDark,
                                        ),
                                        onPressed: () => _isciEkleVeyaDuzenleDialog(
                                          servisi,
                                          mevcutIsci: isci,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _silmeOnayi(servisi, isci.id!, isci.ad),
                                      ),
                                    ],
                                  ),

                                // Her zaman gösterilen ok işareti
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
          ],
        ),
      ),
      floatingActionButton:
          isFinans
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
