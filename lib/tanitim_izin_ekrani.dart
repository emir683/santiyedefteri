import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class TanitimIzinEkrani extends StatefulWidget {
  final VoidCallback onTamamlandi;

  const TanitimIzinEkrani({super.key, required this.onTamamlandi});

  @override
  State<TanitimIzinEkrani> createState() => _TanitimIzinEkraniState();
}

class _TanitimIzinEkraniState extends State<TanitimIzinEkrani>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _aktifSayfa = 0;

  bool _mikrofonIzinli = false;
  bool _bildirimIzinli = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _izinDurumlariniKontrolEt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _izinDurumlariniKontrolEt();
    }
  }

  Future<void> _izinDurumlariniKontrolEt() async {
    final micStatus = await Permission.microphone.status;
    final notifStatus = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _mikrofonIzinli = micStatus.isGranted;
        _bildirimIzinli = notifStatus.isGranted;
      });
    }
  }

  Future<void> _mikrofonIzinIste() async {
    HapticFeedback.lightImpact();
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _mikrofonIzinli = status.isGranted;
      });
      if (!status.isGranted && status.isPermanentlyDenied) {
        _ayarlaraYonlendirDialog(
          baslik: 'Mikrofon İzni Gerekli',
          aciklama:
              'Sesli asistan ile puantaj ve not alabilmek için ayarlardan mikrofon iznini etkinleştirebilirsiniz.',
        );
      }
    }
  }

  Future<void> _bildirimIzinIste() async {
    HapticFeedback.lightImpact();
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() {
        _bildirimIzinli = status.isGranted;
      });
      if (!status.isGranted && status.isPermanentlyDenied) {
        _ayarlaraYonlendirDialog(
          baslik: 'Bildirim İzni Gerekli',
          aciklama:
              'Günlük rapor hatırlatmaları ve şantiye uyarılarını alabilmek için ayarlardan bildirim iznini açabilirsiniz.',
        );
      }
    }
  }

  void _ayarlaraYonlendirDialog({
    required String baslik,
    required String aciklama,
  }) {
    showDialog(
      context: context,
      builder:
          (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              baslik,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(aciklama),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  openAppSettings();
                },
                child: const Text('Ayarları Aç'),
              ),
            ],
          ),
    );
  }

  void _sonrakiSayfa() {
    HapticFeedback.selectionClick();
    if (_aktifSayfa < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onTamamlandi();
    }
  }

  void _oncekiSayfa() {
    HapticFeedback.selectionClick();
    if (_aktifSayfa > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF030712) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Arka Plan Degrade ve Işıma Katmanları
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.65, 1.0],
                  colors:
                      isDark
                          ? const [
                            Color(0xFF020408),
                            Color(0xFF080D1A),
                            Color(0xFF0D1526),
                            Color(0xFF050811),
                          ]
                          : const [
                            Color(0xFFF8FAFC),
                            Color(0xFFF1F5F9),
                            Color(0xFFE2E8F0),
                            Color(0xFFCBD5E1),
                          ],
                ),
              ),
            ),
          ),

          // Üst ve Alt Teal / Cyan Ortam Işıması
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF14B8A6,
                    ).withValues(alpha: isDark ? 0.16 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: isDark ? 0.14 : 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Ana İçerik ve SafeArea
          SafeArea(
            child: Column(
              children: [
                // ÜST BAR: Başlık & "Atla" Butonu
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sol: Logo & Marka Rozeti
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF14B8A6,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Şantiye Defteri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),

                      // Sağ: Atla Butonu (Kullanıcı dilediği an geçebilsin)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onTamamlandi();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Atla',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF475569),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. SLIDER: PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _aktifSayfa = index;
                      });
                    },
                    children: [
                      // Sayfa 1: Şantiye & Puantaj Yönetimi
                      _buildSayfa1(isDark),

                      // Sayfa 2: Sesli Saha Asistanı (Mikrofon İzni)
                      _buildSayfa2SesliAsistan(isDark),

                      // Sayfa 3: Akıllı Bildirimler (Bildirim İzni)
                      _buildSayfa3Bildirimler(isDark),

                      // Sayfa 4: CAD Proje & Çizim Görüntüleyici
                      _buildSayfa4Cad(isDark),

                      // Sayfa 5: Hazırsanız Başlayalım!
                      _buildSayfa5Baslayalim(isDark),
                    ],
                  ),
                ),

                // 4. ALT BAR: Sayfa Göstergeleri ve Butonlar
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    bottomPadding > 0 ? bottomPadding : 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF070B14).withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.70),
                    border: Border(
                      top: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Geri Butonu (Sadece 1. sayfadan sonra)
                      if (_aktifSayfa > 0)
                        IconButton(
                          onPressed: _oncekiSayfa,
                          style: IconButton.styleFrom(
                            backgroundColor: (isDark
                                    ? Colors.white
                                    : Colors.black)
                                .withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                          ),
                        )
                      else
                        const SizedBox(width: 48),

                      // Sayfa Nokta Göstergeleri (Dots)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (idx) {
                          final secili = idx == _aktifSayfa;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: secili ? 26 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color:
                                  secili
                                      ? const Color(0xFF14B8A6)
                                      : (isDark
                                          ? Colors.white24
                                          : Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      // İleri / Başlayalım Butonu
                      ElevatedButton(
                        onPressed: _sonrakiSayfa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: const Color(
                            0xFF14B8A6,
                          ).withValues(alpha: 0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _aktifSayfa == 4 ? 'Başlayalım' : 'İleri',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _aktifSayfa == 4
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SAYFA 1: Şantiye & Puantaj Yönetimi
  // ==========================================
  Widget _buildSayfa1(bool isDark) {
    return _buildKartGovdesi(
      isDark: isDark,
      rozetMetin: 'ŞANTİYE & PUANTAJ YÖNETİMİ',
      rozetRenk: const Color(0xFF14B8A6),
      ikon: Icons.assignment_turned_in_rounded,
      ikonRenk: const Color(0xFF14B8A6),
      baslik: 'Tüm Şantiyeleriniz\nTek Ekranda',
      aciklama:
          'Projelerinizi, usta ve işçi kadronuzu, günlük mesai yoklamalarını ve saha harcamalarını deftere gerek kalmadan saniyeler içinde kaydedin.',
      altIcerik: Column(
        children: [
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.touch_app_rounded,
            baslik: 'Tek Dokunuşla Yoklama',
            altMetin:
                'Tam gün, yarım gün veya izinleri kart üzerinden hızlıca verin.',
          ),
          const SizedBox(height: 10),
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.copy_all_rounded,
            baslik: 'Dünü Kopyala Özelliği',
            altMetin:
                'Bir önceki günün çalışan kadrosunu tek tıkla bugüne aktarın.',
          ),
          const SizedBox(height: 10),
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.cloud_off_rounded,
            baslik: 'Çevrimdışı Çalışma',
            altMetin:
                'Sahada internet kesilse bile kayıt yapın, bağlanınca otomatik eşitlensin.',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SAYFA 2: Sesli Saha Asistanı & Mikrofon İzni
  // ==========================================
  Widget _buildSayfa2SesliAsistan(bool isDark) {
    return _buildKartGovdesi(
      isDark: isDark,
      rozetMetin: 'YAPAY ZEKA & SESLİ ASİSTAN',
      rozetRenk: const Color(0xFF06B6D4),
      ikon: Icons.mic_rounded,
      ikonRenk: const Color(0xFF06B6D4),
      baslik: 'Elleriniz Doluyken\nSesinizle Raporlayın',
      aciklama:
          'Şantiyede çalışırken elle yazmakla uğraşmayın. Akıllı sesli asistanımıza konuşun; o puantajı, yapılan işleri ve harcamaları otomatik olarak doldursun.',
      altIcerik: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(
            alpha: 0.85,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _mikrofonIzinli
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 18,
                  color:
                      _mikrofonIzinli
                          ? const Color(0xFF10B981)
                          : const Color(0xFF06B6D4),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mikrofon İzni Güvencesi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color:
                        _mikrofonIzinli
                            ? const Color(0xFF10B981)
                            : const Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mikrofon sadece siz sesli asistan butonuna bastığınız anda sesinizi komuta dönüştürmek için kullanılır. Arka planda asla dinleme yapılmaz.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 14),
            // İzin Butonu / Durum Rozeti
            SizedBox(
              width: double.infinity,
              child:
                  _mikrofonIzinli
                      ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Mikrofon İzni Verildi',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ElevatedButton.icon(
                        onPressed: _mikrofonIzinIste,
                        icon: const Icon(Icons.mic_rounded, size: 18),
                        label: const Text(
                          'Mikrofon İznini Etkinleştir',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SAYFA 3: Akıllı Bildirimler & Hatırlatıcı İzni
  // ==========================================
  Widget _buildSayfa3Bildirimler(bool isDark) {
    return _buildKartGovdesi(
      isDark: isDark,
      rozetMetin: 'AKILLI BİLDİRİMLER & TAKİP',
      rozetRenk: const Color(0xFFF59E0B),
      ikon: Icons.notifications_active_rounded,
      ikonRenk: const Color(0xFFF59E0B),
      baslik: 'Kritik Rapor ve\nGörevleri Kaçırmayın',
      aciklama:
          'Günün sonunda rapor girme hatırlatmaları, ekibinizin girdiği masraflar, yaklaşan hakediş günleri ve saha hava durumu alarmları anında cebinize gelsin.',
      altIcerik: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(
            alpha: 0.85,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _bildirimIzinli
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color:
                      _bildirimIzinli
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bildirim Kullanım Politikası',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color:
                        _bildirimIzinli
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bildirimler sadece belirlediğiniz günlük rapor saatinde ve saha operasyonlarınızla ilgili kritik durumlarda gönderilir. Reklam veya gereksiz bildirim asla gönderilmez.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 14),
            // İzin Butonu / Durum Rozeti
            SizedBox(
              width: double.infinity,
              child:
                  _bildirimIzinli
                      ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bildirim İzni Verildi',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ElevatedButton.icon(
                        onPressed: _bildirimIzinIste,
                        icon: const Icon(
                          Icons.notifications_active_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Bildirimlere İzin Ver',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SAYFA 4: CAD Proje & Çizim Görüntüleyici
  // ==========================================
  Widget _buildSayfa4Cad(bool isDark) {
    return _buildKartGovdesi(
      isDark: isDark,
      rozetMetin: 'CAD & DWG PROJE GÖRÜNTÜLEYİCİ',
      rozetRenk: const Color(0xFF8B5CF6),
      ikon: Icons.architecture_rounded,
      ikonRenk: const Color(0xFF8B5CF6),
      baslik: 'Projeler ve Çizimler\nDoğrudan Sahada',
      aciklama:
          'Büyük ölçekli DWG ve DXF mimari veya statik projelerinizi doğrudan sahada açın, kat planlarında gezin ve milimetrik ölçümler yapın.',
      altIcerik: Column(
        children: [
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.straighten_rounded,
            baslik: 'Hassas Mesafe ve Alan Ölçümü',
            altMetin:
                'Çizim üzerindeki kiriş, kolon ve oda ölçülerini anında hesaplayın.',
          ),
          const SizedBox(height: 10),
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.layers_rounded,
            baslik: 'Katman (Layer) Yönetimi',
            altMetin:
                'Elektrik, tesisat ve mimari katmanları tek dokunuşla açıp kapatın.',
          ),
          const SizedBox(height: 10),
          _buildOzellikSatiri(
            isDark: isDark,
            ikon: Icons.share_rounded,
            baslik: 'Kolay Paylaşım & İçe Aktarma',
            altMetin:
                'WhatsApp veya cihazınızdaki CAD dosyalarını doğrudan açın.',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SAYFA 5: Hazırsanız Başlayalım!
  // ==========================================
  Widget _buildSayfa5Baslayalim(bool isDark) {
    return _buildKartGovdesi(
      isDark: isDark,
      rozetMetin: 'PROFESYONEL SAHA YÖNETİMİ',
      rozetRenk: const Color(0xFF10B981),
      ikon: Icons.rocket_launch_rounded,
      ikonRenk: const Color(0xFF10B981),
      baslik: 'Şantiye Defteri ile\nGüvenle Başlayın',
      aciklama:
          'Artık karmaşık evraklar ve dağınık notlarla vakit kaybetmeyeceksiniz. Şantiyenizi dijitalleştirip zamandan ve maliyetten tasarruf edin.',
      altIcerik: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.22 : 0.12),
              const Color(0xFF0D9488).withValues(alpha: isDark ? 0.10 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.40),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 40,
              color: Color(0xFF14B8A6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tüm Verileriniz Güvende',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bulut senkronizasyonu ve gelişmiş şifreleme sayesinde verileriniz asla kaybolmaz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onTamamlandi();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                  shadowColor: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hemen Başlayalım',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ORTAK KART ŞABLONU
  // ==========================================
  Widget _buildKartGovdesi({
    required bool isDark,
    required String rozetMetin,
    required Color rozetRenk,
    required IconData ikon,
    required Color ikonRenk,
    required String baslik,
    required String aciklama,
    required Widget altIcerik,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Üst İkon Rozeti
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ikonRenk.withValues(alpha: isDark ? 0.28 : 0.18),
                  ikonRenk.withValues(alpha: isDark ? 0.08 : 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: ikonRenk.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ikonRenk.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(ikon, size: 44, color: ikonRenk),
          ),
          const SizedBox(height: 18),

          // Küçük Kategori Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: rozetRenk.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rozetRenk.withValues(alpha: 0.35)),
            ),
            child: Text(
              rozetMetin,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: rozetRenk,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Ana Başlık
          Text(
            baslik,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.25,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // Açıklama Paragrafı
          Text(
            aciklama,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),

          // Özellik veya İzin Kartı
          altIcerik,
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // ÖZELLİK SATIRI ŞABLONU
  // ==========================================
  Widget _buildOzellikSatiri({
    required bool isDark,
    required IconData ikon,
    required String baslik,
    required String altMetin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(
          alpha: 0.8,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, size: 20, color: const Color(0xFF14B8A6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  altMetin,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
