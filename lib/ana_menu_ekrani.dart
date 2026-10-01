import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';

import 'animasyon_yardimcisi.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'widgets/weather_dashboard_card.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/interactive_tour/interactive_tour_model.dart';
import 'widgets/interactive_tour/interactive_tour_overlay.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'destek_ekrani.dart';
import 'rol_provider.dart';
import 'tur_servisi.dart';
import 'format_yardimcisi.dart';
import 'data_models.dart';
import 'home_widget_service.dart';
import 'widgets/floating_liquid_bottom_bar.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'ai_chat_screen.dart';

class AnaMenuEkrani extends StatefulWidget {
  final String teamId;
  const AnaMenuEkrani({super.key, required this.teamId});

  @override
  State<AnaMenuEkrani> createState() => _AnaMenuEkraniState();
}

class _AnaMenuEkraniState extends State<AnaMenuEkrani> {
  // GlobalKeys - her karti spotlight icin hedefler
  final _raporKey = GlobalKey();
  final _santiyeKey = GlobalKey();
  final _isciKey = GlobalKey();
  final _odemeKey = GlobalKey();
  final _menuButtonKey = GlobalKey();
  final _privacyButtonKey = GlobalKey();
  final _hizliErisimBarKey = GlobalKey();
  final _panelVeriKey = GlobalKey();
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
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
  String? _panelStreamToken;
  String? _lastHomeWidgetSignature;
  bool _klavuzAciliyor = false;
  bool _turAktif = false;
  bool _turDenendiBuAcilis = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  void _hizliErisimAc(int index, bool finansalErisim) {
    final finansSekmesi = index == 3 || index == 4;
    if (finansSekmesi && !finansalErisim) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu b\u00F6l\u00FCm i\u00E7in finansal eri\u015Fim gerekiyor.',
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
      _klavuzKontrol();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOffline =
          results.contains(ConnectivityResult.none) || results.isEmpty;
      if (mounted && _isOffline != isOffline) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    });

    Connectivity().checkConnectivity().then((results) {
      final isOffline =
          results.contains(ConnectivityResult.none) || results.isEmpty;
      if (mounted && _isOffline != isOffline) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _disposePanelStream();
    super.dispose();
  }

  void _disposePanelStream() {
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
  }

  Stream<_AnaPanelVerisi> _ensurePanelStream(
    FirestoreServisi servisi,
    bool finansalErisim,
  ) {
    final now = DateTime.now();
    final ayBaslangic = DateTime(now.year, now.month, 1);
    final ayBitis = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final token =
        '${widget.teamId}_${servisi.kullaniciId}_${finansalErisim}_${now.year}_${now.month}_${now.day}';

    if (_panelStream != null && _panelStreamToken == token) {
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

      controller.add(
        _AnaPanelVerisi.olustur(
          santiyeler: _panelSantiyeler!,
          isciler: _panelIsciler!,
          raporlar: _panelRaporlar!,
          odemeler: _panelOdemeler,
          finansalErisim: finansalErisim,
        ),
      );
    }

    _panelSantiyeSub = servisi.getSantiyelerStream(widget.teamId).listen((
      data,
    ) {
      _panelSantiyeler = data;
      emitIfReady();
    }, onError: controller.addError);

    _panelIsciSub = servisi.getIscilerStream(widget.teamId).listen((data) {
      _panelIsciler = data;
      emitIfReady();
    }, onError: controller.addError);

    _panelRaporSub = servisi
        .getRaporlarStream(widget.teamId, ayBaslangic, ayBitis)
        .listen((data) {
          _panelRaporlar = data;
          emitIfReady();
        }, onError: controller.addError);

    if (finansalErisim) {
      _panelOdemeSub = servisi.getOdemelerStream(widget.teamId).listen((data) {
        _panelOdemeler = data;
        emitIfReady();
      }, onError: controller.addError);
    } else {
      _panelOdemeler = const [];
    }

    _panelController = controller;
    _panelStream = controller.stream;
    _panelStreamToken = token;
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
                onTap: () => _turBaslat(),
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
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.only(left: 14, top: 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.26)
                      : Colors.white.withOpacity(0.56),
              child: InkWell(
                key: _menuButtonKey,
                onTap: () => _shellScaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
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
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color:
                      isDark
                          ? Colors.black.withOpacity(0.26)
                          : Colors.white.withOpacity(0.56),
                  child: InkWell(
                    key: _privacyButtonKey,
                    onTap: () => privacy.togglePrivacy(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiFloatingButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => AIChatScreen(
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
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
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
      SantiyeEkrani(teamId: widget.teamId, otomatikTurAktif: false),
      IsciEkrani(teamId: widget.teamId, otomatikTurAktif: false),
      finansalErisim
          ? AySonuRaporEkrani(teamId: widget.teamId)
          : _buildFinansKilidi(
            baslik: 'Ay Sonu Raporu',
            aciklama:
                'Ay sonu analizleri yaln\u0131zca finansal eri\u015Fimi olan kullan\u0131c\u0131lara a\u00E7\u0131k.',
          ),
      finansalErisim
          ? OdemelerEkrani(teamId: widget.teamId)
          : _buildFinansKilidi(),
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
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final servisi = FirestoreServisi(kullaniciId: user.uid);
    final privacy = context.watch<PrivacyProvider>();
    return StreamBuilder<_AnaPanelVerisi>(
      stream: _ensurePanelStream(servisi, finansalErisim),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final panel = snapshot.data!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _anaEkranWidgetiniGuncelle(
            ekipAdi: ekipAdi,
            panel: panel,
            finansalErisim: finansalErisim,
            privacyHidden: privacy.isHidden,
          );
        });

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B5D68).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              right: -40,
              bottom: -28,
              child: IgnorePointer(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 0.92,
                      colors: [
                        const Color(0xFF5EEAD4).withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.14
                              : 0.18,
                        ),
                        const Color(0xFFB6F5ED).withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.08
                              : 0.10,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 96, 16, 132),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ekipAdi,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Kontrol Merkezi',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildQuickReportCardMinimal(),
                            const SizedBox(height: 18),
                            _buildTodayOverviewCardMinimal(
                              bugun: panel.bugun,
                              bugunCalisanSayisi: panel.bugunCalisanSayisi,
                              bugunSantiyeSayisi: panel.bugunSantiyeSayisi,
                              bugunMasraf: panel.bugunMasraf,
                              bugunOdemeToplami: panel.bugunOdemeToplami,
                              privacyHidden: privacy.isHidden,
                              finansalErisim: finansalErisim,
                              bugunCalisanlari: panel.bugunCalisanlari,
                              bugunSantiyeleri: panel.bugunSantiyeleri,
                            ),
                            const SizedBox(height: 18),
                            const WeatherDashboardCard(),
                            const SizedBox(height: 18),
                            _buildMonthSummaryCardMinimal(
                              tarih: panel.tarih,
                              raporGirilenGun: panel.ayRaporGirilenGun,
                              calisanSayisi: panel.ayCalisanSayisi,
                              santiyeSayisi: panel.aySantiyeSayisi,
                              odemeToplami: panel.ayOdemeToplami,
                              toplamMasraf: panel.ayToplamMasraf,
                              privacyHidden: privacy.isHidden,
                              finansalErisim: finansalErisim,
                              ayCalisanlari: panel.ayCalisanlari,
                              aySantiyeleri: panel.aySantiyeleri,
                              ayRaporGunleri: panel.ayRaporGunleri,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.24 : 0.08),
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
                    color: Colors.grey.withOpacity(0.12),
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

  Widget _buildQuickReportCardMinimal() {
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
              accentColor: const Color(0xFF0F7C86),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'H\u0131zl\u0131 Rapor Giri\u015Fi',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Puantaj ve gider kayd\u0131n\u0131 a\u00E7.',
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

  Widget _buildTodayOverviewCardMinimal({
    required DateTime bugun,
    required int bugunCalisanSayisi,
    required int bugunSantiyeSayisi,
    required double bugunMasraf,
    required double bugunOdemeToplami,
    required bool privacyHidden,
    required bool finansalErisim,
    required List<String> bugunCalisanlari,
    required List<String> bugunSantiyeleri,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyedSubtree(
      key: _panelVeriKey,
      child: _buildPanelGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bug\u00FCn',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _turkceTamTarih(bugun),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMiniCardMinimal(
                    heroTag: 'today_summary_calisan',
                    onTap:
                        () => _showExpandedMiniCard(
                          'today_summary_calisan',
                          Icons.groups_rounded,
                          '\u00C7al\u0131\u015Fan',
                          '$bugunCalisanSayisi Ki\u015Fi',
                          'Bug\u00FCn \u00E7al\u0131\u015Fan personel listesi:',
                          detailsWidget: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                bugunCalisanlari
                                    .map((ad) => _buildWorkerChipMinimal(ad))
                                    .toList(),
                          ),
                        ),
                    icon: Icons.groups_rounded,
                    value: '$bugunCalisanSayisi Ki\u015Fi',
                    label: '\u00C7al\u0131\u015Fan',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOverviewMiniCardMinimal(
                    heroTag: 'today_summary_santiye',
                    onTap:
                        () => _showExpandedMiniCard(
                          'today_summary_santiye',
                          Icons.apartment_rounded,
                          'Aktif \u015Eantiye',
                          '$bugunSantiyeSayisi Proje',
                          'Bug\u00FCn aktif olan \u015Fantiyeler:',
                          detailsWidget: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                bugunSantiyeleri
                                    .map((ad) => _buildWorkerChipMinimal(ad))
                                    .toList(),
                          ),
                        ),
                    icon: Icons.apartment_rounded,
                    value: '$bugunSantiyeSayisi Proje',
                    label: 'Aktif \u015Eantiye',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMiniCardMinimal(
                    icon: Icons.receipt_long_rounded,
                    value: _formatAmount(
                      bugunMasraf,
                      privacyHidden: privacyHidden,
                    ),
                    label: 'Toplam Masraf',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOverviewMiniCardMinimal(
                    icon:
                        finansalErisim
                            ? Icons.payments_rounded
                            : Icons.lock_outline,
                    value:
                        finansalErisim
                            ? (bugunOdemeToplami == 0
                                ? '\u00D6deme yok'
                                : _formatAmount(
                                  bugunOdemeToplami,
                                  privacyHidden: privacyHidden,
                                ))
                            : 'Kilitli',
                    label: finansalErisim ? 'Al\u0131nan \u00D6deme' : 'Finans',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSummaryCardMinimal({
    required DateTime tarih,
    required int raporGirilenGun,
    required int calisanSayisi,
    required int santiyeSayisi,
    required double odemeToplami,
    required double toplamMasraf,
    required bool privacyHidden,
    required bool finansalErisim,
    required List<String> ayCalisanlari,
    required List<String> aySantiyeleri,
    required List<DateTime> ayRaporGunleri,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildPanelGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_ayAdi(tarih.month)} ${tarih.year} \u00D6zeti',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              _buildPanelGlassInset(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Text(
                  'Bu Ay',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF0F7C86),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCardMinimal(
                  heroTag: 'month_summary_rapor_gun',
                  onTap:
                      () => _showExpandedMiniCard(
                        'month_summary_rapor_gun',
                        Icons.event_note_rounded,
                        'Rapor Girilen G\u00FCn',
                        '$raporGirilenGun G\u00FCn',
                        'Bu ay rapor girilen g\u00FCnler takvim \u00FCzerinde i\u015Faretlenmi\u015Ftir:',
                        detailsWidget: SizedBox(
                          width: 320,
                          child: _buildPanelGlassInset(
                            padding: const EdgeInsets.all(8),
                            child: TableCalendar(
                              locale: 'tr_TR',
                              firstDay: DateTime(tarih.year, tarih.month, 1),
                              lastDay: DateTime(tarih.year, tarih.month + 1, 0),
                              focusedDay: tarih,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                leftChevronVisible: false,
                                rightChevronVisible: false,
                              ),
                              availableGestures: AvailableGestures.none,
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  bool hasReport = ayRaporGunleri.any(
                                    (d) =>
                                        d.year == day.year &&
                                        d.month == day.month &&
                                        d.day == day.day,
                                  );
                                  return Center(
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            hasReport
                                                ? const Color(0xFF0F7C86)
                                                : Colors.transparent,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            color:
                                                hasReport
                                                    ? Colors.white
                                                    : (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black87),
                                            fontWeight:
                                                hasReport
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) {
                                  bool hasReport = ayRaporGunleri.any(
                                    (d) =>
                                        d.year == day.year &&
                                        d.month == day.month &&
                                        d.day == day.day,
                                  );
                                  return Center(
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            hasReport
                                                ? const Color(0xFF0F7C86)
                                                : Colors.transparent,
                                        border: Border.all(
                                          color: const Color(0xFF0F7C86),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            color:
                                                hasReport
                                                    ? Colors.white
                                                    : (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  icon: Icons.event_note_rounded,
                  value: '$raporGirilenGun G\u00FCn',
                  label: 'Rapor Girilen G\u00FCn',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOverviewMiniCardMinimal(
                  heroTag: 'month_summary_personel',
                  onTap:
                      () => _showExpandedMiniCard(
                        'month_summary_personel',
                        Icons.groups_rounded,
                        'Personel',
                        '$calisanSayisi Ki\u015Fi',
                        'Bu ay projelerinizde g\u00F6rev alan personel listesi:',
                        detailsWidget: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ayCalisanlari
                                  .map((ad) => _buildWorkerChipMinimal(ad))
                                  .toList(),
                        ),
                      ),
                  icon: Icons.groups_rounded,
                  value: '$calisanSayisi Ki\u015Fi',
                  label: 'Personel',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCardMinimal(
                  heroTag: 'month_summary_santiye',
                  onTap:
                      () => _showExpandedMiniCard(
                        'month_summary_santiye',
                        Icons.apartment_rounded,
                        'Aktif \u015Eantiye',
                        '$santiyeSayisi Proje',
                        'Bu ay aktif olarak i\u015Flem yap\u0131lan \u015Fantiyeler:',
                        detailsWidget: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              aySantiyeleri
                                  .map((ad) => _buildWorkerChipMinimal(ad))
                                  .toList(),
                        ),
                      ),
                  icon: Icons.apartment_rounded,
                  value: '$santiyeSayisi Proje',
                  label: 'Aktif \u015Eantiye',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOverviewMiniCardMinimal(
                  heroTag: 'month_summary_finans',
                  onTap: () {
                    if (finansalErisim) {
                      _showExpandedMiniCard(
                        'month_summary_finans',
                        Icons.wallet_rounded,
                        'Al\u0131nan \u00D6deme',
                        _formatAmount(
                          odemeToplami,
                          privacyHidden: privacyHidden,
                        ),
                        'Bu ay i\u00E7erisinde toplam al\u0131nan \u00F6deme (gelir) miktar\u0131d\u0131r. Daha detayl\u0131 b\u00FCt\u00E7e analizine ula\u015Fmak i\u00E7in rapor k\u0131sm\u0131n\u0131 inceleyebilirsiniz.',
                      );
                    }
                  },
                  icon:
                      finansalErisim
                          ? Icons.wallet_rounded
                          : Icons.lock_outline,
                  value:
                      finansalErisim
                          ? _formatAmount(
                            odemeToplami,
                            privacyHidden: privacyHidden,
                          )
                          : 'Kilitli',
                  label: finansalErisim ? 'Al\u0131nan \u00D6deme' : 'Finans',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildOverviewWideCardMinimal(
            icon: Icons.analytics_rounded,
            title: 'Ay sonu raporu',
            value:
                finansalErisim
                    ? 'Analizi g\u00F6r\u00FCnt\u00FCle'
                    : 'Yetki gerekiyor',
            helper:
                finansalErisim
                    ? 'Toplam masraf: ${_formatAmount(toplamMasraf, privacyHidden: privacyHidden)}'
                    : 'Finansal eri\u015Fim ile a\u00E7\u0131l\u0131r',
            onTap: () => _hizliErisimAc(3, finansalErisim),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMiniCardMinimal({
    required IconData icon,
    required String value,
    required String label,
    VoidCallback? onTap,
    String? heroTag,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = _buildPanelGlassInset(
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF0F7C86),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (heroTag != null) {
      content = Hero(
        tag: heroTag,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return Material(
            type: MaterialType.transparency,
            child: toHeroContext.widget,
          );
        },
        child: Material(type: MaterialType.transparency, child: content),
      );
    }

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }

  void _showExpandedMiniCard(
    String heroTag,
    IconData icon,
    String label,
    String value,
    String details, {
    Widget? detailsWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: (
                      flightContext,
                      animation,
                      flightDirection,
                      fromHeroContext,
                      toHeroContext,
                    ) {
                      return Material(
                        type: MaterialType.transparency,
                        child: toHeroContext.widget,
                      );
                    },
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildPanelGlassCard(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 24,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : const Color(0xFF0F7C86),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : Colors.black87,
                                    ),
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                details,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                  height: 1.5,
                                  fontSize: 15,
                                ),
                              ),
                              if (detailsWidget != null) ...[
                                const SizedBox(height: 16),
                                detailsWidget,
                              ],
                            ],
                          ),
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
    );
  }

  Widget _buildOverviewWideCardMinimal({
    required IconData icon,
    required String title,
    required String value,
    required String helper,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _buildPanelGlassInset(
        child: Row(
          children: [
            _buildPanelGlassIconBadge(
              icon: icon,
              accentColor: const Color(0xFF0F7C86),
              compact: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white54 : Colors.black45,
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
          colors: [
            (isDark ? const Color(0xFF15181D) : const Color(0xFFE7EEF1))
                .withOpacity(isDark ? 0.96 : 0.90),
            (isDark ? const Color(0xFF090B0F) : const Color(0xFFD6E1E6))
                .withOpacity(isDark ? 0.98 : 0.94),
          ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.07)
                  : const Color(0xFFBFD0D6).withOpacity(0.92),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF79E9D7).withOpacity(isDark ? 0.03 : 0.08),
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
          colors: [
            (isDark ? const Color(0xFF171A1F) : const Color(0xFFE0EAEE))
                .withOpacity(isDark ? 0.88 : 0.82),
            (isDark ? const Color(0xFF0D0F13) : const Color(0xFFCCD9DE))
                .withOpacity(isDark ? 0.96 : 0.90),
          ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFBFD0D6).withOpacity(0.88),
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
            accentColor.withOpacity(isDark ? 0.20 : 0.18),
            (isDark ? const Color(0xFF15313A) : const Color(0xFFE9F8FA))
                .withOpacity(isDark ? 0.72 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.20 : 0.14),
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
      chromaticAberration: 0.015,
      glassColor:
          isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.14),
    );
  }

  Widget _buildWorkerChipMinimal(String ad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '\u2022 $ad',
        style: const TextStyle(
          color: Color(0xFF166534),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildQuickAccessDockMinimal(
    BuildContext context,
    bool finansalErisim,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.36)
                      : Colors.white.withOpacity(0.76),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.24 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDockItemCompact(
                          context,
                          itemKey: _santiyeKey,
                          icon: Icons.home_work_outlined,
                          label: '\u015Eantiye',
                          color: AppColors.tealDark,
                          isSelected: _selectedIndex == 1,
                          onTap: () => _hizliErisimAc(1, finansalErisim),
                        ),
                      ),
                      Expanded(
                        child: _buildDockItemCompact(
                          context,
                          itemKey: _isciKey,
                          icon: Icons.groups_outlined,
                          label: '\u0130\u015F\u00E7i',
                          color: AppColors.blueDark,
                          isSelected: _selectedIndex == 2,
                          onTap: () => _hizliErisimAc(2, finansalErisim),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildCenterDockItem(
                    context,
                    isSelected: _selectedIndex == 0,
                    onTap: () => _hizliErisimAc(0, finansalErisim),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDockItemCompact(
                          context,
                          icon:
                              finansalErisim
                                  ? Icons.assessment_rounded
                                  : Icons.lock_outline_rounded,
                          label: 'Ay Sonu',
                          color:
                              finansalErisim
                                  ? AppColors.orangeDark
                                  : Colors.grey.shade500,
                          isSelected: _selectedIndex == 3,
                          onTap: () => _hizliErisimAc(3, finansalErisim),
                        ),
                      ),
                      Expanded(
                        child: _buildDockItemCompact(
                          context,
                          itemKey: _odemeKey,
                          icon:
                              finansalErisim
                                  ? Icons.receipt_long_outlined
                                  : Icons.lock_outline_rounded,
                          label: '\u00D6deme',
                          color:
                              finansalErisim
                                  ? AppColors.purpleDark
                                  : Colors.grey.shade500,
                          isSelected: _selectedIndex == 4,
                          onTap: () => _hizliErisimAc(4, finansalErisim),
                        ),
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

  Widget _buildDockItemCompact(
    BuildContext context, {
    Key? itemKey,
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      key: itemKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : color.withOpacity(0.82),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color:
                    isSelected
                        ? color
                        : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterDockItem(
    BuildContext context, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF14B8A6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? color
                      : (isDark
                          ? const Color(0xFF183238)
                          : const Color(0xFFE8F7F8)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isSelected ? 0.28 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color:
                    isSelected
                        ? color.withOpacity(0.50)
                        : Colors.white.withOpacity(0.20),
              ),
            ),
            child: Icon(
              Icons.home_rounded,
              color:
                  isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF8EE2E8) : color),
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Panel',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color:
                  isSelected
                      ? color
                      : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReportCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimasyonluButon(
      key: _raporKey,
      onPressed:
          () => Navigator.push(
            context,
            SayfaGecisi(sayfa: GunlukRaporEkrani(teamId: widget.teamId)),
          ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0AA7B4), Color(0xFF0E525D)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E525D).withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 62,
              width: 62,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isDark ? 0.16 : 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HÄ±zlÄ± Rapor GiriÅŸi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'GÃ¼nlÃ¼k puantaj, gider ve ekip takibini buradan aÃ§.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard({
    required DateTime bugun,
    required int bugunCalisanSayisi,
    required double bugunYevmiye,
    required int bugunSantiyeSayisi,
    required double bugunMasraf,
    required double bugunOdemeToplami,
    required bool privacyHidden,
    required bool finansalErisim,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15AABF), Color(0xFF2877C9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2877C9).withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BugÃ¼n',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _turkceTamTarih(bugun),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCard(
                  icon: Icons.groups_rounded,
                  value: '$bugunCalisanSayisi KiÅŸi',
                  label: 'Ã‡alÄ±ÅŸan',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewMiniCard(
                  icon: Icons.calendar_month_rounded,
                  value: bugunYevmiye.toStringAsFixed(
                    bugunYevmiye.truncateToDouble() == bugunYevmiye ? 0 : 1,
                  ),
                  label: 'Toplam GÃ¼n',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOverviewWideCard(
            icon: finansalErisim ? Icons.payments_rounded : Icons.lock_outline,
            title:
                finansalErisim
                    ? 'BugÃ¼n alÄ±nan Ã¶deme'
                    : 'Finans bÃ¶lÃ¼mÃ¼ kilitli',
            value:
                finansalErisim
                    ? (bugunOdemeToplami == 0
                        ? 'Ã–deme yok'
                        : _formatAmount(
                          bugunOdemeToplami,
                          privacyHidden: privacyHidden,
                        ))
                    : 'Yetki gerekiyor',
            helper:
                bugunMasraf == 0
                    ? '$bugunSantiyeSayisi ÅŸantiye iÃ§in giriÅŸ var'
                    : '$bugunSantiyeSayisi ÅŸantiye â€¢ Masraf: ${_formatAmount(bugunMasraf, privacyHidden: privacyHidden)}',
          ),
        ],
      ),
    );
  }

  Widget _buildTodayWorkersCard({required List<String> bugunCalisanlari}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15181C) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color:
              isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFDAE6F2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Color(0xFF0F9B8E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'BugÃ¼n Ã‡alÄ±ÅŸanlar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${bugunCalisanlari.length} KiÅŸi',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (bugunCalisanlari.isEmpty)
            Text(
              'BugÃ¼n iÃ§in henÃ¼z Ã§alÄ±ÅŸan kaydÄ± gÃ¶rÃ¼nmÃ¼yor.',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  bugunCalisanlari
                      .take(8)
                      .map((ad) => _buildWorkerChip(ad))
                      .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSummaryCard({
    required DateTime tarih,
    required double toplamYevmiye,
    required int calisanSayisi,
    required int santiyeSayisi,
    required double odemeToplami,
    required double toplamMasraf,
    required bool privacyHidden,
    required bool finansalErisim,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0AA7B4), Color(0xFF13B0A5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13B0A5).withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_ayAdi(tarih.month)} ${tarih.year} Ã–zeti',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Bu Ay',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCard(
                  icon: Icons.event_note_rounded,
                  value: toplamYevmiye.toStringAsFixed(
                    toplamYevmiye.truncateToDouble() == toplamYevmiye ? 0 : 1,
                  ),
                  label: 'Toplam GÃ¼n',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewMiniCard(
                  icon: Icons.groups_rounded,
                  value: '$calisanSayisi KiÅŸi',
                  label: 'Personel',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCard(
                  icon: Icons.apartment_rounded,
                  value: '$santiyeSayisi Proje',
                  label: 'Aktif Åantiye',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewMiniCard(
                  icon:
                      finansalErisim
                          ? Icons.wallet_rounded
                          : Icons.lock_outline,
                  value:
                      finansalErisim
                          ? _formatAmount(
                            odemeToplami,
                            privacyHidden: privacyHidden,
                          )
                          : 'Kilitli',
                  label: finansalErisim ? 'AlÄ±nan Ã–deme' : 'Finans',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOverviewWideCard(
            icon: Icons.analytics_rounded,
            title: 'Ay sonu raporunu aÃ§',
            value: finansalErisim ? 'Analizi gÃ¶rÃ¼ntÃ¼le' : 'Yetki gerekiyor',
            helper:
                finansalErisim
                    ? 'Toplam masraf: ${_formatAmount(toplamMasraf, privacyHidden: privacyHidden)}'
                    : 'Bu alan finansal eriÅŸim ile aÃ§Ä±lÄ±r',
            onTap: () => _hizliErisimAc(3, finansalErisim),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMiniCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewWideCard({
    required IconData icon,
    required String title,
    required String value,
    required String helper,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.82),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.70),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerChip(String ad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE2FBEA),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'â€¢ $ad',
        style: const TextStyle(
          color: Color(0xFF166534),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _turkceTamTarih(DateTime tarih) {
    return '${tarih.day} ${_ayAdi(tarih.month)} ${_gunAdi(tarih.weekday)}';
  }

  String _ayAdi(int ay) {
    const aylar = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return aylar[ay - 1];
  }

  String _gunAdi(int gun) {
    const gunler = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return gunler[gun - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  double _gunDegeri(String durum) {
    return durum.toLowerCase().contains('yar') ? 0.5 : 1;
  }

  String _formatAmount(double tutar, {required bool privacyHidden}) {
    if (privacyHidden) return '**** TL';
    return Formatlayici.yap(tutar);
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
        final user = Provider.of<UserModel?>(context, listen: false);
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<RolProvider>(
              context,
              listen: false,
            ).baslat(widget.teamId, user.uid);
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
                      if (_isOffline)
                        Container(
                          width: double.infinity,
                          color: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: const Text(
                            'İnternet bağlantısı yok (Çevrimdışı Çalışıyorsunuz)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                      ? const Color(0xFF1E1E1E).withOpacity(0.15)
                      : const Color.fromARGB(
                        255,
                        255,
                        255,
                        255,
                      ).withOpacity(0.25),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.5),
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
                            ? Colors.black.withOpacity(0.3)
                            : const Color(0xFFEAF2F8).withOpacity(0.15),
                    border: Border(
                      bottom: BorderSide(
                        color:
                            isDarkMode
                                ? Colors.white.withOpacity(0.5)
                                : const Color(0xFFD4E2EC).withOpacity(0.52),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.business,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF1E6F78),
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

                // MENÃœ
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildGlassDrawerItem(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: 'ŞPD AI Asistanı',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => AIChatScreen(
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
                        icon: Icons.person_outline,
                        title: 'Profilim',
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
                            SayfaGecisi(
                              sayfa: EkipYonetimiEkrani(teamId: teamId),
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
                            SayfaGecisi(
                              sayfa: IslemGecmisiEkrani(teamId: teamId),
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
                            SayfaGecisi(sayfa: const HatirlatmalarEkrani()),
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
                            SayfaGecisi(
                              sayfa: const KlavuzEkrani(isFromMenu: true),
                            ),
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
                                  : Colors.black.withOpacity(0.03),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          title: Text(
                            isDarkMode ? "Aydınlık Mod" : "Karanlık Mod",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          value: isDarkMode,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF14B8A6),
                          inactiveThumbColor:
                              isDarkMode
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF64748B),
                          inactiveTrackColor:
                              isDarkMode
                                  ? Colors.white12
                                  : const Color(0xFFD7E3EC),
                          secondary: Icon(
                            isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                          onChanged: (val) => themeProvider.toggleTheme(val),
                        ),
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
                                  " Tüm veriler başarıyla sıfırlandı.",
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
                      await Future<void>.delayed(
                        const Duration(milliseconds: 180),
                      );
                      if (!mounted) return;
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
                        // Çekmeceyi kapat ve navigation stack'i kök sayfaya getir
                        Navigator.of(
                          context,
                          rootNavigator: true,
                        ).popUntil((route) => route.isFirst);

                        // Aktif panel veri dinleyicilerini durdur
                        _disposePanelStream();

                        // RolProvider'ın Firestore dinleyicisini iptal et ve sıfırla
                        if (mounted) {
                          Provider.of<RolProvider>(
                            context,
                            listen: false,
                          ).sifirla();
                        }

                        // Hesaptan güvenle çıkış yap
                        await authServisi.signOut();
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

  Widget _buildQuickAccessDock(BuildContext context, bool finansalErisim) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.40)
                      : Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.28 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDockItem(
                    context,
                    icon: Icons.home_rounded,
                    label: 'Panel',
                    color: const Color(0xFF14B8A6),
                    isSelected: _selectedIndex == 0,
                    onTap: () => _hizliErisimAc(0, finansalErisim),
                  ),
                ),
                Expanded(
                  child: _buildDockItem(
                    context,
                    itemKey: _santiyeKey,
                    icon: Icons.home_work_outlined,
                    label: '\u015Eantiye',
                    color: AppColors.tealDark,
                    isSelected: _selectedIndex == 1,
                    onTap: () => _hizliErisimAc(1, finansalErisim),
                  ),
                ),
                Expanded(
                  child: _buildDockItem(
                    context,
                    itemKey: _isciKey,
                    icon: Icons.groups_outlined,
                    label: '\u0130\u015F\u00E7i',
                    color: AppColors.blueDark,
                    isSelected: _selectedIndex == 2,
                    onTap: () => _hizliErisimAc(2, finansalErisim),
                  ),
                ),
                Expanded(
                  child: _buildDockItem(
                    context,
                    icon:
                        finansalErisim
                            ? Icons.assessment_rounded
                            : Icons.lock_outline_rounded,
                    label: 'Ay Sonu',
                    color:
                        finansalErisim
                            ? AppColors.orangeDark
                            : Colors.grey.shade500,
                    isSelected: _selectedIndex == 3,
                    onTap: () => _hizliErisimAc(3, finansalErisim),
                  ),
                ),
                Expanded(
                  child: _buildDockItem(
                    context,
                    itemKey: _odemeKey,
                    icon:
                        finansalErisim
                            ? Icons.receipt_long_outlined
                            : Icons.lock_outline_rounded,
                    label: '\u00D6deme',
                    color:
                        finansalErisim
                            ? AppColors.purpleDark
                            : Colors.grey.shade500,
                    isSelected: _selectedIndex == 4,
                    onTap: () => _hizliErisimAc(4, finansalErisim),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem(
    BuildContext context, {
    Key? itemKey,
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      key: itemKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? color.withOpacity(isDark ? 0.28 : 0.20)
                        : color.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isSelected ? color.withOpacity(0.34) : Colors.transparent,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    isSelected
                        ? color
                        : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
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
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.4),
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
    Key? key,
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimasyonluButon(
      key: key,
      onPressed: onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

  Widget _buildLockedCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
          ],
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
                      .withOpacity(isDark ? 0.96 : 0.92),
                  (isDark ? const Color(0xFF090B0F) : const Color(0xFF0B0E12))
                      .withOpacity(isDark ? 0.98 : 0.96),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.07 : 0.06),
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFF79E9D7).withOpacity(0.04),
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
                      color: Colors.white.withOpacity(0.78),
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
      switch (durum) {
        case 'Tam':
          return 1.0;
        case 'Yar\u0131m':
          return 0.5;
        case 'Mesai':
          return 1.5;
        default:
          return 0.0;
      }
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
