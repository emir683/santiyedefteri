import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';

import 'animasyon_yardimcisi.dart';
import 'package:flutter/material.dart';
import 'widgets/weather_dashboard_card.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';
import 'tema_ayarlari.dart';
import 'user_model.dart';
import 'auth_servisi.dart';
import 'firestore_servisi.dart';
import 'gunluk_rapor_ekrani.dart';
import 'hatirlatmalar_ekrani.dart';
import 'bildirim_ekrani.dart';
import 'islem_gecmisi_ekrani.dart';
import 'ekip_yonetimi_ekrani.dart';
import 'profil_ekrani.dart';
import 'privacy_provider.dart';
import 'hakkinda_ekrani.dart';
import 'klavuz_ekrani.dart';
import 'destek_ekrani.dart';
import 'puanlama_servisi.dart';
import 'performance_provider.dart';
import 'dwg_goruntuleyici_ekrani.dart';
import 'rol_provider.dart';
import 'tur_servisi.dart';
import 'format_yardimcisi.dart';
import 'data_models.dart';
import 'home_widget_service.dart';
import 'widgets/floating_liquid_bottom_bar.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';
import 'widgets/offline_sync_banner.dart';
import 'ai_chat_screen.dart';
import 'widgets/bildirim_onboarding_dialog.dart';
import 'data/turkiye_il_ilce.dart';
import 'bildirim_servisi.dart';
import 'models/kullanici_saha_profili.dart';
import 'santiye_pazari_ekrani.dart';
import 'saha_operasyon_merkezi_ekrani.dart';
import 'santiye_ve_isci_merkezi_ekrani.dart';
import 'finans_merkezi_ekrani.dart';
import 'package:intl/intl.dart';

class AnaMenuEkrani extends StatefulWidget {
  final String teamId;
  const AnaMenuEkrani({super.key, required this.teamId});

  @override
  State<AnaMenuEkrani> createState() => _AnaMenuEkraniState();
}

class _AnaMenuEkraniState extends State<AnaMenuEkrani> {
  Color get _themePrimary => AppTheme.primary(context);
  Color get _themeAccent => AppTheme.accent(context);
  Color get _themeContrastIcon => AppTheme.contrastIcon(context);

  // GlobalKeys - her karti spotlight icin hedefler
  final _raporKey = GlobalKey();
  final _menuButtonKey = GlobalKey();
  final _privacyButtonKey = GlobalKey();
  final _hizliErisimBarKey = GlobalKey();
  final _panelVeriKey = GlobalKey();
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int _sahaAltSekme = 0;
  int _pazarAltSekme = 0;
  int _pazarProfilAltSekme = 0;
  int _operasyonAltSekme = 0;
  int _finansAltSekme = 0;
  StreamController<_AnaPanelVerisi>? _panelController;
  Stream<_AnaPanelVerisi>? _panelStream;
  StreamSubscription<List<Santiye>>? _panelSantiyeSub;
  StreamSubscription<List<Isci>>? _panelIsciSub;
  StreamSubscription<List<GunlukSantiyeRaporu>>? _panelRaporSub;
  StreamSubscription<List<AlinanOdeme>>? _panelOdemeSub;
  List<Santiye>? _panelSantiyeler;
  List<Isci>? _panelIsciler;
  List<GunlukSantiyeRaporu>? _panelRaporlar;
  List<AlinanOdeme> _panelOdemeler = const [];
  _AnaPanelVerisi? _lastPanelVerisi;
  Timer? _panelRetryTimer;
  String? _panelStreamToken;
  String? _lastHomeWidgetSignature;
  bool _klavuzAciliyor = false;
  bool _turAktif = false;
  bool _turDenendiBuAcilis = false;
  bool _cikisYapiliyor = false;

  void _hizliErisimAc(int index, bool finansalErisim) {
    final finansSekmesi = index == 4;
    if (finansSekmesi && !finansalErisim) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu bölüm için finansal erişim gerekiyor.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _anaEkranWidgetiniGuncelle({
    required String ekipAdi,
    required _AnaPanelVerisi panel,
    required bool finansalErisim,
    required bool privacyHidden,
  }) {
    final yeniImza = [
      ekipAdi,
      panel.tarih.year,
      panel.tarih.month,
      panel.ayRaporGirilenGun,
      panel.ayCalisanSayisi,
      panel.aySantiyeSayisi,
      panel.ayOdemeToplami,
      panel.ayToplamMasraf,
      finansalErisim,
      privacyHidden,
    ].join('|');

    if (_lastHomeWidgetSignature == yeniImza) return;
    _lastHomeWidgetSignature = yeniImza;

    HomeWidgetService.syncMonthSummary(
      ekipAdi: ekipAdi,
      tarih: panel.tarih,
      raporGirilenGun: panel.ayRaporGirilenGun,
      calisanSayisi: panel.ayCalisanSayisi,
      santiyeSayisi: panel.aySantiyeSayisi,
      odemeToplami: panel.ayOdemeToplami,
      toplamMasraf: panel.ayToplamMasraf,
      finansalErisim: finansalErisim,
      privacyHidden: privacyHidden,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _turuGuvenliSekildeBaslat();
      BildirimOnboardingDialog.kontrolEtVeGoster(context);
      _proaktifSahaVeHavaDurumuKontrolu();
    });
  }

  Future<void> _proaktifSahaVeHavaDurumuKontrolu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('havaDurumuBildirimleriAktif') == false) return;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (prefs.getString('son_hava_uyarisi_gunu') == todayStr) return;

      final santiyeler = _panelSantiyeler ?? [];
      final il =
          santiyeler.isNotEmpty
              ? (santiyeler.first.il ?? 'İstanbul')
              : 'İstanbul';
      final ilce = santiyeler.isNotEmpty ? santiyeler.first.ilce : null;
      final w = await TurkiyeIlIlce.fetchWeather(il: il, ilce: ilce);
      if (w != null) {
        final code = w['weathercode'] as int? ?? 0;
        final temp = (w['temperature'] as num?)?.toDouble() ?? 15.0;
        final isRainy =
            (code >= 51 && code <= 67) ||
            (code >= 80 && code <= 82) ||
            (code >= 95);
        final isFreezing = temp <= 3.0;

        if (isRainy || isFreezing) {
          await prefs.setString('son_hava_uyarisi_gunu', todayStr);
          final desc = w['description'] ?? 'Hava uyarısı';
          final tavsiye =
              isFreezing
                  ? 'Hava sıcaklığı $temp°C. Beton dökümünde donma riskine karşı antifriz ve priz hızlandırıcı tedbirlerini alın.'
                  : 'Yoğun yağış bekleniyor. Açık saha kazı, beton döküm ve dış cephe çalışmalarında emniyet tedbirlerini gözden geçirin.';
          await BildirimServisi().havaDurumuSahaUyarisiGonder(
            sehir: il,
            aciklama: '$desc ($temp°C)',
            tavsiye: tavsiye,
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposePanelStream();
    super.dispose();
  }

  void _disposePanelStream() {
    _panelRetryTimer?.cancel();
    _panelRetryTimer = null;
    _panelSantiyeSub?.cancel();
    _panelIsciSub?.cancel();
    _panelRaporSub?.cancel();
    _panelOdemeSub?.cancel();
    _panelController?.close();
    _panelSantiyeSub = null;
    _panelIsciSub = null;
    _panelRaporSub = null;
    _panelOdemeSub = null;
    _panelController = null;
    _panelStream = null;
    _panelStreamToken = null;
    _panelSantiyeler = null;
    _panelIsciler = null;
    _panelRaporlar = null;
    _panelOdemeler = const [];
    _lastPanelVerisi = null;
  }

  Stream<_AnaPanelVerisi> _ensurePanelStream(
    FirestoreServisi servisi,
    bool finansalErisim,
  ) {
    if (_cikisYapiliyor) {
      return const Stream.empty();
    }
    final now = DateTime.now();
    final ayBaslangic = DateTime(now.year, now.month, 1);
    final ayBitis = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final coreToken =
        '${widget.teamId}_${servisi.kullaniciId}_${now.year}_${now.month}_${now.day}';

    if (_panelStream != null && _panelStreamToken == coreToken) {
      // Eğer finansal erişim sonradan aktif olduysa ve ödeme dinleyicisi henüz yoksa ekle
      if (finansalErisim && _panelOdemeSub == null) {
        _panelOdemeSub = servisi.getOdemelerStream(widget.teamId).listen((data) {
          _panelOdemeler = data;
          if (_panelSantiyeler != null &&
              _panelIsciler != null &&
              _panelRaporlar != null) {
            final veri = _AnaPanelVerisi.olustur(
              santiyeler: _panelSantiyeler!,
              isciler: _panelIsciler!,
              raporlar: _panelRaporlar!,
              odemeler: _panelOdemeler,
              finansalErisim: true,
            );
            _lastPanelVerisi = veri;
            _panelController?.add(veri);
          }
        }, onError: (e) => debugPrint("⚠️ Ödeme stream hatası: $e"));
      }
      return _panelStream!;
    }

    _disposePanelStream();

    final controller = StreamController<_AnaPanelVerisi>.broadcast();

    void emitIfReady() {
      if (controller.isClosed ||
          _panelSantiyeler == null ||
          _panelIsciler == null ||
          _panelRaporlar == null) {
        return;
      }

      final veri = _AnaPanelVerisi.olustur(
        santiyeler: _panelSantiyeler!,
        isciler: _panelIsciler!,
        raporlar: _panelRaporlar!,
        odemeler: _panelOdemeler,
        finansalErisim: finansalErisim,
      );
      _lastPanelVerisi = veri;
      controller.add(veri);
    }

    void handleStreamError(Object error) {
      debugPrint("⚠️ AnaPanel stream geçici hatası (yeniden denenecek): $error");
      if (_cikisYapiliyor || !mounted) return;
      _panelRetryTimer?.cancel();
      _panelRetryTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted || _cikisYapiliyor) return;
        setState(() {
          _panelStreamToken = null;
        });
      });
    }

    _panelSantiyeSub = servisi.getSantiyelerStream(widget.teamId).listen((
      data,
    ) {
      _panelSantiyeler = data;
      emitIfReady();
    }, onError: handleStreamError);

    _panelIsciSub = servisi.getIscilerStream(widget.teamId).listen((data) {
      _panelIsciler = data;
      emitIfReady();
    }, onError: handleStreamError);

    _panelRaporSub = servisi
        .getRaporlarStream(widget.teamId, ayBaslangic, ayBitis)
        .listen((data) {
          _panelRaporlar = data;
          emitIfReady();
        }, onError: handleStreamError);

    if (finansalErisim) {
      _panelOdemeSub = servisi.getOdemelerStream(widget.teamId).listen((data) {
        _panelOdemeler = data;
        emitIfReady();
      }, onError: handleStreamError);
    } else {
      _panelOdemeler = const [];
    }

    _panelController = controller;
    _panelStream = controller.stream;
    _panelStreamToken = coreToken;
    return _panelStream!;
  }

  Future<void> _klavuzKontrol() async {
    if (_klavuzAciliyor) return;
    _klavuzAciliyor = true;

    final prefs = await SharedPreferences.getInstance();
    final bool goruldu = prefs.getBool('klavuzGoruldu') ?? false;

    try {
      if (!goruldu && mounted) {
        await Navigator.push(
          context,
          SayfaGecisi(sayfa: const KlavuzEkrani(isFromMenu: false)),
        );
      }
    } finally {
      _klavuzAciliyor = false;
    }

    if (mounted) {
      await _turuGuvenliSekildeBaslat();
    }
  }

  Future<void> _turuGuvenliSekildeBaslat() async {
    if (!mounted || _turAktif || _turDenendiBuAcilis || _klavuzAciliyor) {
      return;
    }

    final turGosterildi = await TurServisi.anaMenuTurGosterildiMi();
    if (turGosterildi) return;

    _turDenendiBuAcilis = true;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    _turBaslat();
  }

  void _turBaslat() {
    if (_turAktif) return;
    setState(() {
      _turAktif = true;
    });
  }

  void _turBitti() async {
    if (mounted) {
      setState(() {
        _turAktif = false;
      });
    }
    await TurServisi.anaMenuTurGosterildiOlarakIsaretle();
  }

  void _turAtlandi() async {
    if (mounted) {
      setState(() {
        _turAktif = false;
      });
    }
    await TurServisi.anaMenuTurGosterildiOlarakIsaretle();
  }

  List<TourStep> _buildTourSteps() {
    return [
      TourStep(
        id: 'ana_menu_genel',
        title: 'Şantiye Defterim Paneli',
        description:
            'Tüm şantiye projelerinizi, çalışanlarınızı, günlük puantaj ve aylık raporlarınızı tek bir ekrandan kolayca yönetin.',
        icon: Icons.space_dashboard_rounded,
        targetKey: null,
      ),
      if (_panelVeriKey.currentContext != null)
        TourStep(
          id: 'panel_veri',
          title: 'Panel Özeti & Saha Verileri',
          description:
              'Aktif şantiye ve personel istatistiklerini, günlük durumları ve şantiye hava durumunu buradan hızlıca takip edin.',
          icon: Icons.dashboard_rounded,
          targetKey: _panelVeriKey,
          targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          targetBorderRadius: 18.0,
        ),
      if (_hizliErisimBarKey.currentContext != null)
        TourStep(
          id: 'hizli_erisim',
          title: 'Hızlı Erişim Çubuğu',
          description:
              'Şantiye, İşçi, Günlük Rapor, Ay Sonu ve Ödeme ekranlarına tek dokunuşla buradan geçiş yapın.',
          icon: Icons.navigation_rounded,
          targetKey: _hizliErisimBarKey,
          targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          targetBorderRadius: 24.0,
        ),
      if (_raporKey.currentContext != null)
        TourStep(
          id: 'hizli_rapor',
          title: 'Hızlı Rapor & Puantaj Girişi',
          description:
              'Günün yoklamasını almak veya şantiyedeki günlük masrafları kaydetmek için doğrudan bu kısayola dokunun.',
          icon: Icons.edit_calendar_rounded,
          targetKey: _raporKey,
          targetPadding: const EdgeInsets.all(4),
          targetBorderRadius: 18.0,
        ),
      if (_privacyButtonKey.currentContext != null)
        TourStep(
          id: 'gizlilik_modu',
          title: 'Gizlilik Modu',
          description:
              'Saha ortamındayken hassas parasal tutarları ve maaşları gizlemek veya açmak için bu göz butonuna dokunun.',
          icon: Icons.visibility_rounded,
          targetKey: _privacyButtonKey,
          targetPadding: const EdgeInsets.all(4),
          targetBorderRadius: 18.0,
        ),
      if (_menuButtonKey.currentContext != null)
        TourStep(
          id: 'ana_menu_cekmecesi',
          title: 'Yan Menü & Ayarlar',
          description:
              'Ekip yönetimi, AI asistanı, veri yedekleme, hatırlatmalar ve profil ayarlarınıza buradan ulaşın.',
          icon: Icons.menu_rounded,
          targetKey: _menuButtonKey,
          targetPadding: const EdgeInsets.all(4),
          targetBorderRadius: 18.0,
        ),
    ];
  }

  Widget _buildTourButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.only(top: 8, right: 68),
      child: Align(
        alignment: Alignment.topRight,
        child: Tooltip(
          message: 'Ekran Rehberi',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Material(
                color:
                    isDark
                        ? Colors.black.withValues(alpha: 0.26)
                        : Colors.white.withValues(alpha: 0.56),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _turBaslat();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 46,
                      minHeight: 46,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid =
        FirebaseAuth.instance.currentUser?.uid ??
        Provider.of<UserModel?>(context, listen: false)?.uid ??
        '';
    final servisi = FirestoreServisi(kullaniciId: uid);

    return SafeArea(
      minimum: const EdgeInsets.only(top: 8, right: 122),
      child: Align(
        alignment: Alignment.topRight,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              uid.isNotEmpty
                  ? servisi.getKullaniciBildirimleri(widget.teamId, uid)
                  : const Stream.empty(),
          builder: (context, snapshot) {
            final bildirimler = snapshot.data ?? const [];
            final okunmamisSayisi =
                bildirimler.where((b) => b['okundu'] != true).length;

            return Tooltip(
              message: 'Bildirim Kutusu',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.26)
                            : Colors.white.withValues(alpha: 0.56),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          SayfaGecisi(
                            sayfa: BildirimEkrani(teamId: widget.teamId),
                          ),
                        );
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 46,
                          minHeight: 46,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                okunmamisSayisi > 0
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                color:
                                    okunmamisSayisi > 0
                                        ? const Color(0xFF14B8A6)
                                        : (isDark ? Colors.white : Colors.black87),
                                size: 22,
                              ),
                              if (okunmamisSayisi > 0)
                                Positioned(
                                  right: -5,
                                  top: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? const Color(0xFF0C1219)
                                                : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      okunmamisSayisi > 9
                                          ? '9+'
                                          : '$okunmamisSayisi',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.only(left: 14, top: 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: Tooltip(
          message: 'Menü',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Material(
                color:
                    isDark
                        ? Colors.black.withValues(alpha: 0.26)
                        : Colors.white.withValues(alpha: 0.56),
                child: InkWell(
                  key: _menuButtonKey,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _shellScaffoldKey.currentState?.openDrawer();
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 46,
                      minHeight: 46,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.menu_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.only(top: 8, right: 14),
      child: Align(
        alignment: Alignment.topRight,
        child: Consumer<PrivacyProvider>(
          builder: (context, privacy, _) {
            return Tooltip(
              message:
                  privacy.isHidden ? 'Tutarları Göster' : 'Tutarları Gizle',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Material(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.26)
                            : Colors.white.withValues(alpha: 0.56),
                    child: InkWell(
                      key: _privacyButtonKey,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        privacy.togglePrivacy();
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 46,
                          minHeight: 46,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            privacy.isHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiFloatingButton(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            SayfaGecisi(
              sayfa: AIChatScreen(
                teamId: widget.teamId,
                isciler: _panelIsciler ?? const [],
                santiyeler: _panelSantiyeler ?? const [],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: themeProvider.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: themeProvider.primaryColor.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryShell(bool finansalErisim, String ekipAdi) {
    final pages = <Widget>[
      _buildAnaPanel(ekipAdi: ekipAdi, finansalErisim: finansalErisim),
      SantiyeVeIsciMerkeziEkrani(
        teamId: widget.teamId,
        baslangicAltSekme: _sahaAltSekme,
        onAltSekmeDegisti: (i) => _sahaAltSekme = i,
      ),
      SantiyePazariEkrani(
        teamId: widget.teamId,
        baslangicSekmesi: _pazarAltSekme,
        baslangicProfilAltSekmesi: _pazarProfilAltSekme,
        gomuluMod: true,
        onEkibeAktarildi: () {
          setState(() {
            _sahaAltSekme = 1;
            _selectedIndex = 1;
          });
        },
      ),
      SahaOperasyonMerkeziEkrani(
        teamId: widget.teamId,
        baslangicSekmesi: _operasyonAltSekme,
        gomuluMod: true,
      ),
      finansalErisim
          ? FinansMerkeziEkrani(
            teamId: widget.teamId,
            baslangicAltSekme: _finansAltSekme,
            onAltSekmeDegisti: (i) => _finansAltSekme = i,
          )
          : _buildFinansKilidi(
            baslik: 'Finans & Ödemeler',
            aciklama:
                'Ay sonu analizleri, hakedişler ve ödemeler yalnızca finansal erişimi olan kullanıcılara açık.',
          ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        if (_selectedIndex == 0) ...[
          _buildMenuButton(context),
          _buildPrivacyButton(context),
          _buildTourButton(context),
          _buildNotificationButton(context),
        ],
        Align(
          alignment: Alignment.bottomCenter,
          child: KeyedSubtree(
            key: _hizliErisimBarKey,
            child: FloatingLiquidBottomBar(
              selectedIndex: _selectedIndex,
              finansalErisim: finansalErisim,
              onSelected: (index) => _hizliErisimAc(index, finansalErisim),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          right: 16,
          bottom:
              (_selectedIndex == 0 &&
                      MediaQuery.viewInsetsOf(context).bottom == 0)
                  ? 105
                  : -120,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            opacity:
                (_selectedIndex == 0 &&
                        MediaQuery.viewInsetsOf(context).bottom == 0)
                    ? 1.0
                    : 0.0,
            child: IgnorePointer(
              ignoring:
                  _selectedIndex != 0 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0,
              child: _buildAiFloatingButton(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnaPanel({
    required String ekipAdi,
    required bool finansalErisim,
  }) {
    final providerUser = Provider.of<UserModel?>(context);
    final uid = providerUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (uid == null || uid.isEmpty || _cikisYapiliyor) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF10B981)),
            if (_cikisYapiliyor) ...[
              const SizedBox(height: 16),
              Text(
                "Oturum kapatılıyor...",
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final servisi = FirestoreServisi(kullaniciId: uid);
    final privacy = context.watch<PrivacyProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final stream = _ensurePanelStream(servisi, finansalErisim);
    return StreamBuilder<_AnaPanelVerisi>(
      stream: stream,
      initialData: _lastPanelVerisi,
      builder: (context, snapshot) {
        final panel = snapshot.data ?? _lastPanelVerisi;
        if (panel == null) {
          return Center(
            child: CircularProgressIndicator(color: themeProvider.primaryColor),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _anaEkranWidgetiniGuncelle(
            ekipAdi: ekipAdi,
            panel: panel,
            finansalErisim: finansalErisim,
            privacyHidden: privacy.isHidden,
          );
        });

        return GlassPageSurface(
          child: RepaintBoundary(
            child: StreamBuilder<DocumentSnapshot>(
              stream: servisi.getKullaniciVeriStream(),
                  builder: (context, userSnap) {
                    final userData =
                        userSnap.hasData && userSnap.data!.exists
                            ? (userSnap.data!.data() as Map<String, dynamic>?)
                            : null;
                    final sahaProfili =
                        KullaniciSahaProfili.fromUserDoc(userData);
                    final bool isPersonalTeam =
                        widget.teamId.startsWith('personal_') ||
                        ekipAdi == 'Kişisel Defterim';
                    final bool isciVeyaUsta = sahaProfili.isciVeyaUstaMi;

                    if (userData != null && !sahaProfili.tamamlandiMi) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        BildirimServisi().meslekProfilTamamlamaBildirimiGonder(
                          uid: uid,
                        );
                      });
                    }

                    final String anaBaslik =
                        isciVeyaUsta ? 'Yevmiye & Mesai' : 'Şantiye Merkezi';

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              96,
                              16,
                              132,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sahaProfili.tamamlandiMi
                                      ? '$ekipAdi • ${KullaniciRolu.rolBasligi(sahaProfili.kullaniciTipi)}'
                                      : ekipAdi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  anaBaslik,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (isciVeyaUsta)
                                  _buildUstaYevmiyeVeMesaiKarti(
                                    finansalErisim: finansalErisim,
                                  )
                                else
                                  _buildQuickReportCardMinimal(
                                    isPersonalTeam: isPersonalTeam,
                                  ),
                                const SizedBox(height: 14),
                                // AKTIF SAHA GOREVI & ANLASMA KARTI (ISCI & EKIP PARANTEZI GOSTERIMI)
                                StreamBuilder<List<PazarAnlasmaTeklifi>>(
                                  stream: servisi.getPazarAnlasmalariStream(),
                                  builder: (context, anlasmaSnap) {
                                    final anlasmalar =
                                        anlasmaSnap.data ??
                                        const <PazarAnlasmaTeklifi>[];
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid ??
                                        '';
                                    final aktifAnlasmalar =
                                        anlasmalar.where((a) {
                                          final benIlgiliMiyim =
                                              (a.aliciUid == uid ||
                                                  a.gonderenUid == uid);
                                          return benIlgiliMiyim &&
                                              a.durum == 'ekibe_aktarildi';
                                        }).toList();

                                    if (aktifAnlasmalar.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      children: [
                                        for (final anlasma in aktifAnlasmalar)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 14.0,
                                            ),
                                            child: _buildAktifGorevKarti(
                                              anlasma: anlasma,
                                              benimUid: uid,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                // 1. SEKME ÖZETİ: ŞANTİYELER, İŞÇİLER & EKİPLER
                                _buildSahaVeIsciSekmeOzetiKarti(
                                  servisi: servisi,
                                  panel: panel,
                                ),
                                const SizedBox(height: 14),
                                // 2. SEKME ÖZETİ: ŞANTİYE PAZARI
                                _buildSantiyePazariSekmeOzetiKarti(
                                  sahaProfili: sahaProfili,
                                  userData: userData,
                                ),
                                const SizedBox(height: 14),
                                // 3. SEKME ÖZETİ: SAHA OPERASYON
                                _buildSahaOperasyonSekmeOzetiKarti(),
                                const SizedBox(height: 14),
                                // 4. SEKME ÖZETİ: FİNANS
                                _buildFinansSekmeOzetiKarti(
                                  panel: panel,
                                  finansalErisim: finansalErisim,
                                  privacyHidden: privacy.isHidden,
                                ),
                                const SizedBox(height: 14),
                                const WeatherDashboardCard(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        );
      },
    );
  }

  Widget _buildFinansKilidi({
    String baslik = '\u00D6demeler',
    String aciklama =
        'Bu b\u00F6l\u00FCm yaln\u0131zca finansal eri\u015Fimi olan kullan\u0131c\u0131lara a\u00E7\u0131k.',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingLiquidAppBar(
        title: baslik,
        showHamburger: true,
        showPrivacyButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 34,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$baslik Yetkisi Gerekli',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  aciklama,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUstaYevmiyeVeMesaiKarti({required bool finansalErisim}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return KeyedSubtree(
      key: _raporKey,
      child: _buildPanelGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPanelGlassIconBadge(
                  icon: Icons.handyman_rounded,
                  accentColor: themeProvider.accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yevmiye & Mesai',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Günlük puantaj ve ödeme kaydı',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap:
                        () => Navigator.push(
                          context,
                          SayfaGecisi(
                            sayfa: GunlukRaporEkrani(teamId: widget.teamId),
                          ),
                        ),
                    child: _buildPanelGlassInset(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: 18,
                            color: themeProvider.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Puantaj Gir',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() => _finansAltSekme = 1);
                      _hizliErisimAc(4, finansalErisim);
                    },
                    child: _buildPanelGlassInset(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: themeProvider.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ödemeler',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 1. ALT SEKME ÖZET KARTI: ŞANTİYELER, İŞÇİLER & EKİPLER
  Widget _buildAktifGorevKarti({
    required PazarAnlasmaTeklifi anlasma,
    required String benimUid,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final karsiAd =
        anlasma.aliciUid == benimUid ? anlasma.gonderenAd : anlasma.aliciAd;
    final isCrew = anlasma.ekipKisiSayisi > 1;

    return _buildPanelGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPanelGlassIconBadge(
                icon: Icons.verified_rounded,
                accentColor: const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'AKTİF SAHA GÖREVİ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      anlasma.santiyeAdi.isNotEmpty
                          ? anlasma.santiyeAdi
                          : 'Ana Şantiye',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'İşveren: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        karsiAd,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isCrew ? Icons.groups_rounded : Icons.person_rounded,
                      size: 14,
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCrew ? 'Ekip Parantezi: ' : 'Göreviniz: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        isCrew
                            ? '[${anlasma.ekipAdi}] (${anlasma.ekipKisiSayisi} Kişi)'
                            : '${anlasma.brans} Ustası',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: Color(0xFF0F7C86),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Anlaşma: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      '${anlasma.birimUcret.toStringAsFixed(0)} ₺ (${anlasma.ucretTipi})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F7C86),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 1; // Profilim / Mesajlarım
                      _selectedIndex = 2; // Şantiye Pazarı
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(
                        alpha: isDark ? 0.20 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 15,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'İşveren İle İletişim',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: themeProvider.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedIndex = 1; // Saha & İşçiler sekmesi
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF10B981,
                      ).withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 15,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Şantiye Detayı',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSahaVeIsciSekmeOzetiKarti({
    required FirestoreServisi servisi,
    required _AnaPanelVerisi panel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final santiyeSayisi = (_panelSantiyeler ?? const []).length;
    final isciSayisi = (_panelIsciler ?? const []).length;

    return KeyedSubtree(
      key: _panelVeriKey,
      child: StreamBuilder<List<SantiyeOzelEkibi>>(
        stream: servisi.getSantiyeOzelEkipleriStream(widget.teamId),
        builder: (context, ekipSnap) {
          final ozelEkipler = ekipSnap.data ?? const [];

          return _buildPanelGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildPanelGlassIconBadge(
                      icon: Icons.home_work_rounded,
                      accentColor: themeProvider.accentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saha & İşçiler',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? Colors.white : const Color(0xFF102A43),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$santiyeSayisi Şantiye • $isciSayisi İşçi • ${ozelEkipler.length} Ekip',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _sahaAltSekme = 0;
                            _selectedIndex = 1;
                          });
                        },
                        child: _buildPanelGlassInset(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                size: 17,
                                color: themeProvider.accentColor,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Şantiyeler ($santiyeSayisi)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _sahaAltSekme = 1;
                            _selectedIndex = 1;
                          });
                        },
                        child: _buildPanelGlassInset(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.groups_rounded,
                                size: 17,
                                color: themeProvider.accentColor,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'İşçiler & Ekipler ($isciSayisi)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 2. ALT SEKME ÖZET KARTI: ŞANTİYE PAZARI (Mevcut 2 Sekmeli Pazar ve Profil Mimarisi)
  Widget _buildSantiyePazariSekmeOzetiKarti({
    required KullaniciSahaProfili sahaProfili,
    required Map<String, dynamic>? userData,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ilanSayisi = (userData?['pazarIlanlari'] as List? ?? const []).length;
    final favoriSayisi = (userData?['pazarFavoriIlanlari'] as List? ?? const []).length;
    final mesajSayisi = (userData?['pazarAnlasmalari'] as List? ?? const []).length;

    return _buildPanelGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPanelGlassIconBadge(
                icon: Icons.storefront_rounded,
                accentColor: themeProvider.accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Şantiye Pazarı',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sahaProfili.tamamlandiMi
                          ? '${sahaProfili.brans} • ${sahaProfili.sehir}'
                          : 'İş & Usta İlanları, Ekip Vitrini',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _pazarAltSekme = 0;
                    _selectedIndex = 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pazara Git',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? themeProvider.secondaryColor : themeProvider.accentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: isDark ? themeProvider.secondaryColor : themeProvider.accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 🌟 2 ANA SEKME BUTONU: Pazar İlanları • Profilim & İlanlar
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 0;
                      _selectedIndex = 2;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pazar İlanları',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 1;
                      _pazarProfilAltSekme = 0;
                      _selectedIndex = 2;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_pin_rounded,
                          size: 18,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Profilim & İlanlar',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 🌟 HIZLI İSTATİSTİK ŞERİDİ (İlanlarım, Favorilerim, Mesajlarım)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 1;
                      _pazarProfilAltSekme = 0;
                      _selectedIndex = 2;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 13, color: themeProvider.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          '$ilanSayisi İlanım',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF334E68),
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
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 1;
                      _pazarProfilAltSekme = 1;
                      _selectedIndex = 2;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_rounded, size: 13, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$favoriSayisi Favori',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF334E68),
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
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _pazarAltSekme = 1;
                      _pazarProfilAltSekme = 2;
                      _selectedIndex = 2;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          '$mesajSayisi Mesaj',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF334E68),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. ALT SEKME ÖZET KARTI: SAHA OPERASYON
  Widget _buildSahaOperasyonSekmeOzetiKarti() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _buildPanelGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPanelGlassIconBadge(
                icon: Icons.precision_manufacturing_rounded,
                accentColor: themeProvider.accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saha Operasyon',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Malzeme • Zimmet • İSG • CAD',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _operasyonAltSekme = 0;
                      _selectedIndex = 3;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Malzeme',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _operasyonAltSekme = 1;
                      _selectedIndex = 3;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 16,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Zimmet',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _operasyonAltSekme = 2;
                      _selectedIndex = 3;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.health_and_safety_outlined,
                          size: 16,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'İSG',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _operasyonAltSekme = 3;
                      _selectedIndex = 3;
                    });
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.architecture_rounded,
                          size: 16,
                          color: themeProvider.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'CAD & Metraj',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. ALT SEKME ÖZET KARTI: FİNANS
  Widget _buildFinansSekmeOzetiKarti({
    required _AnaPanelVerisi panel,
    required bool finansalErisim,
    required bool privacyHidden,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final odemeText =
        !finansalErisim
            ? 'Kilitli'
            : (privacyHidden
                ? '•••• ₺'
                : FormatYardimcisi.paraFormatla(panel.ayOdemeToplami));
    final masrafText =
        !finansalErisim
            ? 'Kilitli'
            : (privacyHidden
                ? '•••• ₺'
                : FormatYardimcisi.paraFormatla(panel.ayToplamMasraf));

    return _buildPanelGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPanelGlassIconBadge(
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFFD97706),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finans',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ödeme: $odemeText • Masraf: $masrafText',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => _finansAltSekme = 0);
                    _hizliErisimAc(4, finansalErisim);
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.assessment_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ay Sonu',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => _finansAltSekme = 1);
                    _hizliErisimAc(4, finansalErisim);
                  },
                  child: _buildPanelGlassInset(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ödemeler',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReportCardMinimal({bool isPersonalTeam = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimasyonluButon(
      key: _raporKey,
      onPressed:
          () => Navigator.push(
            context,
            SayfaGecisi(sayfa: GunlukRaporEkrani(teamId: widget.teamId)),
          ),
      child: _buildPanelGlassCard(
        child: Row(
          children: [
            _buildPanelGlassIconBadge(
              icon: Icons.edit_note_rounded,
              accentColor: _themeContrastIcon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Puantaj & Rapor',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yoklama, mesai ve gider gir',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white54 : Colors.black45,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.cardGradient(isDark),
        ),
        border: Border.all(
          color: AppTheme.cardBorder(isDark),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.glow(context).withValues(alpha: isDark ? 0.04 : 0.08),
            blurRadius: isDark ? 12 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildPanelGlassInset({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.cardInsetGradient(isDark),
        ),
        border: Border.all(
          color: AppTheme.cardInsetBorder(isDark),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildPanelGlassIconBadge({
    required IconData icon,
    required Color accentColor,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = compact ? 38.0 : 48.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: isDark ? 0.20 : 0.18),
            (isDark
                    ? accentColor.withValues(alpha: 0.14)
                    : accentColor.withValues(alpha: 0.08))
                .withValues(alpha: isDark ? 0.72 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.14),
        ),
      ),
      child: Icon(icon, color: accentColor, size: compact ? 18 : 24),
    );
  }

  LiquidGlassSettings _panelGlassLayerSettings(bool isDark) {
    return LiquidGlassSettings(
      thickness: isDark ? 28 : 24,
      blur: isDark ? 10 : 8,
      refractiveIndex: 1.12,
      lightIntensity: isDark ? 1.2 : 1.0,
      ambientStrength: isDark ? 0.34 : 0.28,
      saturation: 1.0,
      chromaticAberration: 0.0,
      glassColor:
          isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.14),
    );
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

        // RolProvider'Ä± baÅŸlat
        final currentUid = FirebaseAuth.instance.currentUser?.uid ??
            Provider.of<UserModel?>(context, listen: false)?.uid;
        if (currentUid != null && currentUid.isNotEmpty && !_cikisYapiliyor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _cikisYapiliyor) return;
            Provider.of<RolProvider>(
              context,
              listen: false,
            ).baslat(widget.teamId, currentUid);
          });
        }

        final String tamBaslik = "$ekipAdi Ekibi";

        return Scaffold(
          key: _shellScaffoldKey,
          drawer: _buildBlurryDrawer(
            context,
            authServisi,
            widget.teamId,
            tamBaslik,
          ),
          body: Stack(
            children: [
              Consumer<RolProvider>(
                builder: (context, rolProvider, _) {
                  return Column(
                    children: [
                      const OfflineSyncBanner(),
                      Expanded(
                        child: _buildPrimaryShell(
                          rolProvider.isFinansalErisim,
                          ekipAdi,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_turAktif)
                InteractiveTourOverlay(
                  steps: _buildTourSteps(),
                  onFinish: _turBitti,
                  onSkip: _turAtlandi,
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.isDarkMode;
    final perfProvider = Provider.of<PerformanceProvider>(context);
    final bool isPerfMode = perfProvider.isPerformanceMode;

    Widget drawerBody = Container(
      decoration: BoxDecoration(
        color:
            isPerfMode
                ? (isDarkMode ? const Color(0xFF13171F) : Colors.white)
                : (isDarkMode
                    ? const Color(0xFF1E1E1E).withValues(alpha: 0.15)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.25)),
        border: Border(
          right: BorderSide(
            color:
                isDarkMode
                    ? Colors.white.withValues(alpha: isPerfMode ? 0.08 : 0.5)
                    : Colors.black.withValues(alpha: isPerfMode ? 0.06 : 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // BAÅLIK
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFFEAF2F8).withValues(alpha: 0.15),
              border: Border(
                bottom: BorderSide(
                  color:
                      isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFFD4E2EC).withValues(alpha: 0.52),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.business,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E6F78),
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
                    color: isDarkMode ? Colors.white70 : const Color(0xFF334E68),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // MENÃœ
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // 1. KATEGORİ: AKILLI SAHA ARAÇLARI
                _buildDrawerCategoryHeader(
                  context,
                  title: 'AKILLI SAHA ARAÇLARI',
                  icon: Icons.auto_awesome_rounded,
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  title: 'ŞPD AI Asistanı',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(
                        sayfa: AIChatScreen(
                          teamId: teamId,
                          isciler: _panelIsciler ?? const [],
                          santiyeler: _panelSantiyeler ?? const [],
                        ),
                      ),
                    );
                  },
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.architecture_rounded,
                  title: 'DWG / CAD Proje Aç',
                  color: const Color(0xFF5EEAD4),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(sayfa: const DwgGoruntuleyiciEkrani()),
                    );
                  },
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.cloud_sync_rounded,
                  title: 'Çevrimdışı & Eşitleme Durumu',
                  color: _themeContrastIcon,
                  onTap: () {
                    Navigator.pop(context);
                    OfflineSyncBanner.showSyncDetailSheet(context);
                  },
                ),

                // 2. KATEGORİ: HESAP & EKİP YÖNETİMİ
                _buildDrawerCategoryHeader(
                  context,
                  title: 'HESAP & EKİP YÖNETİMİ',
                  icon: Icons.manage_accounts_rounded,
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Profilim & Mesleki Kimlik',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(sayfa: const ProfilEkrani()),
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
                      SayfaGecisi(sayfa: EkipYonetimiEkrani(teamId: teamId)),
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
                      SayfaGecisi(sayfa: IslemGecmisiEkrani(teamId: teamId)),
                    );
                  },
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.notifications_none_rounded,
                  title: 'Bildirim Kutusu',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(sayfa: BildirimEkrani(teamId: teamId)),
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
                      SayfaGecisi(sayfa: const HatirlatmalarEkrani()),
                    );
                  },
                ),

                // 3. KATEGORİ: YARDIM & DESTEK
                _buildDrawerCategoryHeader(
                  context,
                  title: 'YARDIM & DESTEK',
                  icon: Icons.help_outline_rounded,
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Kullanım Kılavuzu',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(sayfa: const KlavuzEkrani(isFromMenu: true)),
                    );
                  },
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.support_agent_outlined,
                  title: 'Destek',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      SayfaGecisi(sayfa: const DestekEkrani()),
                    );
                  },
                ),
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.star_rate_rounded,
                  title: 'Uygulamayı Puanla',
                  color: const Color(0xFFFFB300),
                  onTap: () {
                    Navigator.pop(context);
                    PuanlamaServisi.diyalogGoster(context);
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
                      SayfaGecisi(sayfa: const HakkindaEkrani()),
                    );
                  },
                ),

                // 4. KATEGORİ: TEMA AYARLARI
                _buildDrawerCategoryHeader(
                  context,
                  title: 'TEMA AYARLARI',
                  icon: Icons.palette_outlined,
                ),

                // RENK PALETİ SEÇİCİ KARTI
                _buildDrawerPaletteSelector(
                  context,
                  themeProvider: themeProvider,
                  isDarkMode: isDarkMode,
                ),

                // AYDINLIK / KARANLIK MOD ŞALTERİ
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                    border: Border.all(
                      color:
                          isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    title: Text(
                      isDarkMode ? "Karanlık Mod" : "Aydınlık Mod",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color:
                            isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      isDarkMode
                          ? "Derin siyah arayüz aktif"
                          : "Açık renk arayüz aktif",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color:
                            isDarkMode
                                ? Colors.white70
                                : const Color(0xFF475569),
                      ),
                    ),
                    value: isDarkMode,
                    activeThumbColor: Colors.white,
                    activeTrackColor: themeProvider.primaryColor,
                    inactiveThumbColor:
                        isDarkMode
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF64748B),
                    inactiveTrackColor:
                        isDarkMode ? Colors.white12 : const Color(0xFFD7E3EC),
                    secondary: Icon(
                      isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color:
                          isDarkMode
                              ? themeProvider.primaryColor
                              : Colors.black87,
                    ),
                    onChanged: (val) => themeProvider.toggleTheme(val),
                  ),
                ),

                // PERFORMANS MODU ŞALTERİ
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                    border: Border.all(
                      color:
                          isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    title: Text(
                      "Performans Modu",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color:
                            isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      perfProvider.isPerformanceMode
                          ? (perfProvider.isAutoDetected
                              ? "Cihaza göre otomatik aktif (${perfProvider.detectionReason})"
                              : "Açık - Cam ve gölge efektleri kapalı")
                          : "Kapalı - Zayıf telefonlarda açınız",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color:
                            isDarkMode
                                ? Colors.white70
                                : const Color(0xFF475569),
                      ),
                    ),
                    value: isPerfMode,
                    activeThumbColor: Colors.white,
                    activeTrackColor: themeProvider.primaryColor,
                    inactiveThumbColor:
                        isDarkMode
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF64748B),
                    inactiveTrackColor:
                        isDarkMode ? Colors.white12 : const Color(0xFFD7E3EC),
                    secondary: Icon(
                      Icons.bolt_rounded,
                      color: themeProvider.primaryColor,
                    ),
                    onChanged: (val) => perfProvider.togglePerformanceMode(val),
                  ),
                ),

                // 5. KATEGORİ: SİSTEM & VERİ YÖNETİMİ
                _buildDrawerCategoryHeader(
                  context,
                  title: 'SİSTEM & VERİ YÖNETİMİ',
                  icon: Icons.settings_suggest_rounded,
                ),

                // SIFIRLAMA BUTONU
                _buildGlassDrawerItem(
                  context,
                  icon: Icons.delete_forever_outlined,
                  title: 'Tüm Verileri Sıfırla',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final onayla = await AnimasyonluDialog.goster<bool>(
                      context: context,
                      builder:
                          (ctx) => _buildDrawerConfirmDialog(
                            title: const Text("DİKKAT: Veri Sıfırlama"),
                            content: const Text(
                              "TÜM Şantiyeler, İşler, Raporlar ve Finansal veriler KALICI OLARAK silinecektir.\n\nBu işlem geri alınamaz. Onaylıyor musunuz?",
                              style: TextStyle(color: Colors.red),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
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
                    if (onayla == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tüm veriler siliniyor..."),
                        ),
                      );
                      await FirestoreServisi(
                        kullaniciId: "temp",
                      ).tumVerileriSil(widget.teamId);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(" Tüm veriler başarıyla sıfırlandı."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildGlassDrawerItem(
              context,
              icon: Icons.logout,
              title: 'Çıkış Yap',
              color: Colors.redAccent,
              isTransparent: false,
              onTap: () async {
                Navigator.pop(context);
                await Future<void>.delayed(const Duration(milliseconds: 180));
                if (!mounted || !context.mounted) return;
                final onayla = await AnimasyonluDialog.goster<bool>(
                  context: context,
                  builder:
                      (ctx) => _buildDrawerConfirmDialog(
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
                if (onayla == true && mounted) {
                  setState(() {
                    _cikisYapiliyor = true;
                  });

                  // Aktif panel veri dinleyicilerini durdur
                  _disposePanelStream();

                  // RolProvider'ın Firestore dinleyicisini iptal et ve sıfırla
                  if (context.mounted) {
                    Provider.of<RolProvider>(context, listen: false).sifirla();
                  }

                  // Hesaptan güvenle çıkış yap
                  try {
                    await authServisi.signOut();
                  } catch (e) {
                    debugPrint("Çıkış hatası: $e");
                  }
                }
              },
            ),
          ),
        ],
      ),
    );

    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.80,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child:
            isPerfMode
                ? drawerBody
                : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: drawerBody,
                ),
      ),
    );
  }

  Widget _buildDrawerCategoryHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final iconColor = isDark ? themeProvider.primaryColor : Colors.black;
    final iconBg = isDark
        ? themeProvider.primaryColor.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor =
        isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: titleColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1.0,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerPaletteSelector(
    BuildContext context, {
    required ThemeProvider themeProvider,
    required bool isDarkMode,
  }) {
    final activePalette = themeProvider.currentPalette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
        border: Border.all(
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              () => _temaPaletSeciciModaliniAc(
                context,
                themeProvider,
                isDarkMode,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: activePalette.primary.withValues(
                      alpha: isDarkMode ? 0.22 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activePalette.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    activePalette.icon,
                    color:
                        isDarkMode
                            ? activePalette.secondary
                            : activePalette.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Renk Paleti",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color:
                              isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activePalette.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color:
                              isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black45 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activePalette.primary.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: activePalette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: activePalette.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _temaPaletSeciciModaliniAc(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDarkMode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeId = themeProvider.currentPalette.id;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode
                                      ? Colors.white24
                                      : Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.palette_rounded,
                                color: themeProvider.primaryColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Tema & Renk Paleti",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    "Şantiye ve ofis tercihinize uygun paleti seçin",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isDarkMode
                                              ? Colors.white60
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ...AppThemePalette.all.map((palette) {
                          final bool isSelected = palette.id == activeId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? palette.primary.withValues(
                                        alpha: isDarkMode ? 0.16 : 0.08,
                                      )
                                      : (isDarkMode
                                          ? const Color(0xFF111111)
                                          : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? palette.primary
                                        : (isDarkMode
                                            ? Colors.white.withValues(
                                              alpha: 0.08,
                                            )
                                            : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 0.8,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await themeProvider.setPalette(palette);
                                  HapticFeedback.lightImpact();
                                  setModalState(() {});
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor:
                                            isDarkMode
                                                ? const Color(0xFF1E1E1E)
                                                : const Color(0xFF0F172A),
                                        content: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: palette.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Tema güncellendi: ${palette.name}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1800,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: palette.gradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: palette.primary.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          palette.icon,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    palette.name,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          isDarkMode
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF0F172A,
                                                              ),
                                                    ),
                                                  ),
                                                ),
                                                if (palette.isDefault)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                    decoration:
                                                        BoxDecoration(
                                                          color:
                                                              isDarkMode
                                                                  ? Colors.white12
                                                                  : Colors.black12,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                    child: Text(
                                                      "VARSAYILAN",
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            isDarkMode
                                                                ? Colors.white70
                                                                : Colors.black87,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              palette.description,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1.35,
                                                color:
                                                    isDarkMode
                                                        ? Colors.white70
                                                        : const Color(
                                                          0xFF475569,
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                _buildColorChip(
                                                  palette.primary,
                                                  "Ana Vurgu",
                                                ),
                                                const SizedBox(width: 6),
                                                _buildColorChip(
                                                  palette.secondary,
                                                  "İkincil Renk",
                                                ),
                                                const SizedBox(width: 6),
                                                _buildColorChip(
                                                  palette.accent,
                                                  "Detay Vurgusu",
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              isSelected
                                                  ? palette.primary
                                                  : Colors.transparent,
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? palette.primary
                                                    : (isDarkMode
                                                        ? Colors.white30
                                                        : Colors.black26),
                                            width: isSelected ? 0 : 2,
                                          ),
                                        ),
                                        child:
                                            isSelected
                                                ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                                : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorChip(Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
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

    // Aydınlık modda yazıların daima net ve okunabilir olması (siyah/koyu):
    final Color textColor;
    if (isDark) {
      textColor = color ?? Colors.white;
    } else {
      if (color == Colors.redAccent || color == Colors.red) {
        textColor = const Color(0xFFDC2626);
      } else {
        textColor = const Color(0xFF102A43);
      }
    }

    // İkon rengi: Aydınlık modda açık renkleri (neon camgöbeği, sarı vb.) yüksek kontrastlı zengin tonlara eşle
    final Color iconColor;
    if (isDark) {
      iconColor = color ?? Colors.white70;
    } else {
      if (color == const Color(0xFF5EEAD4)) {
        iconColor = _themeContrastIcon;
      } else if (color == const Color(0xFFFFB300)) {
        iconColor = const Color(0xFFD97706);
      } else if (color == const Color(0xFF10B981)) {
        iconColor = const Color(0xFF059669);
      } else {
        iconColor = color ?? const Color(0xFF102A43);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isTransparent
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.35))
                : (isDark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.70),
          width: 0.9,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: textColor,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildDrawerConfirmDialog({
    Widget? title,
    Widget? content,
    List<Widget>? actions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AdaptiveLiquidGlassLayer(
        settings: _panelGlassLayerSettings(isDark),
        child: GlassCard(
          padding: EdgeInsets.zero,
          quality: GlassQuality.premium,
          clipBehavior: Clip.antiAlias,
          shape: const LiquidRoundedSuperellipse(borderRadius: 26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isDark ? const Color(0xFF15181D) : const Color(0xFF15181D))
                      .withValues(alpha: isDark ? 0.96 : 0.92),
                  (isDark ? const Color(0xFF090B0F) : const Color(0xFF0B0E12))
                      .withValues(alpha: isDark ? 0.98 : 0.96),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.06),
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFF79E9D7).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    child: title ?? const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    child: content ?? const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions ?? const <Widget>[],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnaPanelVerisi {
  const _AnaPanelVerisi({
    required this.tarih,
    required this.bugun,
    required this.bugunCalisanSayisi,
    required this.bugunSantiyeSayisi,
    required this.bugunYevmiye,
    required this.bugunMasraf,
    required this.bugunOdemeToplami,
    required this.bugunCalisanlari,
    required this.ayCalisanSayisi,
    required this.aySantiyeSayisi,
    required this.ayRaporGirilenGun,
    required this.ayToplamYevmiye,
    required this.ayToplamMasraf,
    required this.ayOdemeToplami,
    required this.ayCalisanlari,
    required this.aySantiyeleri,
    required this.ayRaporGunleri,
    required this.bugunSantiyeleri,
  });

  final DateTime tarih;
  final DateTime bugun;
  final int bugunCalisanSayisi;
  final int bugunSantiyeSayisi;
  final double bugunYevmiye;
  final double bugunMasraf;
  final double bugunOdemeToplami;
  final List<String> bugunCalisanlari;
  final int ayCalisanSayisi;
  final int aySantiyeSayisi;
  final int ayRaporGirilenGun;
  final double ayToplamYevmiye;
  final double ayToplamMasraf;
  final double ayOdemeToplami;
  final List<String> ayCalisanlari;
  final List<String> aySantiyeleri;
  final List<DateTime> ayRaporGunleri;
  final List<String> bugunSantiyeleri;

  factory _AnaPanelVerisi.olustur({
    required List<Santiye> santiyeler,
    required List<Isci> isciler,
    required List<GunlukSantiyeRaporu> raporlar,
    required List<AlinanOdeme> odemeler,
    required bool finansalErisim,
  }) {
    final now = DateTime.now();
    final bugun = DateTime(now.year, now.month, now.day);

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    double gunDegeri(String durum) {
      return parseDurumCarpani(durum);
    }

    final bugunRaporlari =
        raporlar.where((rapor) => isSameDay(rapor.tarih, bugun)).toList();

    final bugunCalisanlari = <String>{};
    final bugunSantiyeleri = <String>{};
    double bugunYevmiye = 0;
    double bugunMasraf = 0;

    for (final rapor in bugunRaporlari) {
      bugunSantiyeleri.add(rapor.santiyeAdi);
      bugunMasraf += rapor.benzinGideri + rapor.yemekGideri + rapor.ekMasraflar;
      for (final calisma in rapor.calisanlar) {
        bugunCalisanlari.add(calisma.isci.ad);
        bugunYevmiye += gunDegeri(calisma.durum);
      }
    }

    final aySantiyeleri = <String>{};
    final ayCalisanlari = <String>{};
    final ayRaporGunleri = <DateTime>{};
    double ayToplamYevmiye = 0;
    double ayToplamMasraf = 0;
    final ayRaporlari =
        raporlar
            .where(
              (rapor) =>
                  rapor.tarih.year == now.year &&
                  rapor.tarih.month == now.month,
            )
            .toList();

    for (final rapor in ayRaporlari) {
      aySantiyeleri.add(rapor.santiyeAdi);
      ayRaporGunleri.add(
        DateTime(rapor.tarih.year, rapor.tarih.month, rapor.tarih.day),
      );
      ayToplamMasraf +=
          rapor.benzinGideri + rapor.yemekGideri + rapor.ekMasraflar;
      for (final calisma in rapor.calisanlar) {
        ayCalisanlari.add(calisma.isci.ad);
        ayToplamYevmiye += gunDegeri(calisma.durum);
      }
    }

    final bugunOdemeToplami =
        finansalErisim
            ? odemeler
                .where((odeme) => isSameDay(odeme.tarih, bugun))
                .fold<double>(0, (toplam, odeme) => toplam + odeme.miktar)
            : 0.0;

    final ayOdemeToplami =
        finansalErisim
            ? odemeler
                .where(
                  (odeme) =>
                      odeme.tarih.year == now.year &&
                      odeme.tarih.month == now.month,
                )
                .fold<double>(0, (toplam, odeme) => toplam + odeme.miktar)
            : 0.0;

    return _AnaPanelVerisi(
      tarih: now,
      bugun: bugun,
      bugunCalisanSayisi: bugunCalisanlari.length,
      bugunSantiyeSayisi: bugunSantiyeleri.length,
      bugunYevmiye: bugunYevmiye,
      bugunMasraf: bugunMasraf,
      bugunOdemeToplami: bugunOdemeToplami,
      bugunCalisanlari: bugunCalisanlari.toList(),
      ayCalisanSayisi:
          ayCalisanlari.isEmpty ? isciler.length : ayCalisanlari.length,
      aySantiyeSayisi:
          aySantiyeleri.isEmpty ? santiyeler.length : aySantiyeleri.length,
      ayRaporGirilenGun: ayRaporGunleri.length,
      ayToplamYevmiye: ayToplamYevmiye,
      ayToplamMasraf: ayToplamMasraf,
      ayOdemeToplami: ayOdemeToplami,
      ayCalisanlari: ayCalisanlari.toList(),
      aySantiyeleri: aySantiyeleri.toList(),
      ayRaporGunleri: ayRaporGunleri.toList(),
      bugunSantiyeleri: bugunSantiyeleri.toList(),
    );
  }
}
