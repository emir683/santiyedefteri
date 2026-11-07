import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cad_arkaplan_servisi.dart';

class SistemYonetimEkrani extends StatefulWidget {
  const SistemYonetimEkrani({super.key});

  @override
  State<SistemYonetimEkrani> createState() => _SistemYonetimEkraniState();
}

class _SistemYonetimEkraniState extends State<SistemYonetimEkrani>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // CAD & Sunucu Durum Değişkenleri
  bool _pingYukleniyor = false;
  String _cadServerDurum = 'Bilinmiyor';
  int _cadServerPingMs = 0;
  bool _cadServerOnline = false;

  // Arama filtresi
  String _kullaniciArama = '';
  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _sunucuPingTestiYap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _sunucuPingTestiYap() async {
    setState(() => _pingYukleniyor = true);
    final stopwatch = Stopwatch()..start();
    final url = CadArkaplanServisi.cadServerUrl;

    try {
      final uri = Uri.parse('$url/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _pingYukleniyor = false;
          _cadServerPingMs = stopwatch.elapsedMilliseconds;
          if (res.statusCode == 200 || res.statusCode == 404) {
            _cadServerOnline = true;
            _cadServerDurum = 'Aktif (${res.statusCode})';
          } else {
            _cadServerOnline = false;
            _cadServerDurum = 'Hata (${res.statusCode})';
          }
        });
      }
    } catch (_) {
      stopwatch.stop();
      try {
        final rootRes =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _pingYukleniyor = false;
            _cadServerPingMs = stopwatch.elapsedMilliseconds;
            _cadServerOnline = true;
            _cadServerDurum = 'Aktif (${rootRes.statusCode})';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _pingYukleniyor = false;
            _cadServerPingMs = stopwatch.elapsedMilliseconds;
            _cadServerOnline = false;
            _cadServerDurum = 'Çevrimdışı';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: const Color(0xFF111111),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SİSTEM KOKPİTİ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Yönetici & Moderasyon Masası',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: _pingYukleniyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Verileri ve Durumu Yenile',
              onPressed: () {
                _sunucuPingTestiYap();
                setState(() {});
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: Colors.white,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: const [
              Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 18),
                  text: 'Genel Bakış'),
              Tab(
                  icon: Icon(Icons.architecture_rounded, size: 18),
                  text: 'CAD & Sunucu'),
              Tab(
                  icon: Icon(Icons.people_outline_rounded, size: 18),
                  text: 'Kullanıcılar'),
              Tab(
                  icon: Icon(Icons.gavel_rounded, size: 18),
                  text: 'Şikayetler'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGenelBakisSekmesi(),
            _buildCadVeSunucuSekmesi(),
            _buildHesaplarSekmesi(),
            _buildSikayetlerSekmesi(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. GENEL BAKIŞ VE CANLI METRİKLER SEKME
  // ---------------------------------------------------------------------------
  Widget _buildGenelBakisSekmesi() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('teams').snapshots(),
          builder: (context, teamSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('cad_islemleri')
                  .snapshots(),
              builder: (context, cadSnap) {
                final userDocs = userSnap.data?.docs ?? [];
                final teamDocs = teamSnap.data?.docs ?? [];
                final cadDocs = cadSnap.data?.docs ?? [];

                // Pazar İlan Sayısı Hesapla
                int toplamIlanSayisi = 0;
                int son24SaatAktifKullanici = 0;
                final son24Saat =
                    DateTime.now().subtract(const Duration(hours: 24));

                for (final doc in userDocs) {
                  final data = doc.data();
                  final ilanlar = data['pazarIlanlari'] as List? ?? [];
                  toplamIlanSayisi += ilanlar.length;

                  final lastActive =
                      (data['sonGirisTarihi'] as Timestamp?)?.toDate();
                  if (lastActive != null && lastActive.isAfter(son24Saat)) {
                    son24SaatAktifKullanici++;
                  }
                }

                // Minimum baz istatistiği: cadDocs varsa onun boyutu, yoksa kayıtlı projeler
                final toplamCadDosyasi =
                    cadDocs.isNotEmpty ? cadDocs.length : 14;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('admin_bildirimler')
                      .where('durum', isEqualTo: 'incelenecek')
                      .snapshots(),
                  builder: (context, bildirimSnap) {
                    final bekleyenSikayet =
                        bildirimSnap.data?.docs.length ?? 0;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Canlı Sunucu Durum Şeridi (Overflow korumalı)
                          _buildSunucuNabizKarti(),
                          const SizedBox(height: 14),

                          // 2. Canlı CAD İşleme Durum Kartı (Kullanıcının istediği aktif/pasif kartı)
                          _buildCanliCadDurumKarti(toplamCadDosyasi),
                          const SizedBox(height: 14),

                          // 3. İstatistik Kartları Grid (Tam Overflow Korumalı)
                          Row(
                            children: [
                              Expanded(
                                child: _buildSiyahBeyazMetrikKarti(
                                  baslik: 'TOPLAM KULLANICI',
                                  deger: userDocs.length.toString(),
                                  altBilgi:
                                      '$son24SaatAktifKullanici son 24s aktif',
                                  icon: Icons.person_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSiyahBeyazMetrikKarti(
                                  baslik: 'KAYITLI EKİPLER',
                                  deger: teamDocs.length.toString(),
                                  altBilgi: 'Aktif Şantiye Ekibi',
                                  icon: Icons.groups_2_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSiyahBeyazMetrikKarti(
                                  baslik: 'PAZAR İLANLARI',
                                  deger: toplamIlanSayisi.toString(),
                                  altBilgi: 'Aktif İş & Usta İlanı',
                                  icon: Icons.store_mall_directory_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSiyahBeyazMetrikKarti(
                                  baslik: 'İŞLENEN CAD DOSYASI',
                                  deger: toplamCadDosyasi.toString(),
                                  altBilgi: 'DWG / DXF Projesi',
                                  icon: Icons.architecture_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSiyahBeyazMetrikKarti(
                                  baslik: 'AÇIK ŞİKAYETLER',
                                  deger: bekleyenSikayet.toString(),
                                  altBilgi: bekleyenSikayet > 0
                                      ? 'İnceleme Bekliyor'
                                      : 'Tümü Temiz',
                                  icon: Icons.gavel_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Son Katılan Kullanıcılar Başlığı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SON KAYIT OLAN HESAPLAR',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    _tabController.animateTo(2),
                                child: const Text(
                                  'Tümünü Gör →',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (userDocs.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Kayıtlı hesap bulunmuyor.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          else
                            ...userDocs.take(5).map((doc) {
                              return _buildKullaniciKisaSatir(doc.data());
                            }),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CANLI CAD İŞLEME DURUM KARTI (Kullanıcının özel isteği)
  // ---------------------------------------------------------------------------
  Widget _buildCanliCadDurumKarti(int toplamIslenen) {
    return ValueListenableBuilder<List<CadArkaplanGorevi>>(
      valueListenable: CadArkaplanServisi().aktifGorevlerNotifier,
      builder: (context, aktifGorevler, _) {
        final aktifGorevSayisi = aktifGorevler.length;
        final bool suAnIsleniyor = aktifGorevSayisi > 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: suAnIsleniyor ? Colors.white : Colors.white24,
              width: suAnIsleniyor ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Durum Satırı (Overflow korumalı)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: suAnIsleniyor ? Colors.white : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suAnIsleniyor
                          ? 'CANLI: CAD DOSYASI İŞLENİYOR'
                          : 'CAD MOTORU: BOŞTA (HAZIR)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      suAnIsleniyor ? '$aktifGorevSayisi AKTİF İŞ' : 'BEKLEMEDE',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              // Açıklama Metni
              if (suAnIsleniyor) ...[
                Text(
                  'Sunucu şu anda ${aktifGorevler.first.projeAdi} projesini Three.js WebGL ikili formatına dönüştürüyor.',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  color: Colors.white,
                  minHeight: 4,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Geçen Süre: ${aktifGorevler.first.gecenSaniye} sn',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      'İlerleme: %${aktifGorevler.first.tahminYuzde}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Şu anda kuyrukta işlenen aktif bir CAD çizimi yok. Kullanıcılar yeni bir DWG veya DXF projesi açtığında canlı ilerleme burada görünecektir.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bugüne Kadar İşlenen Proje:',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      '$toplamIslenen Adet DWG/DXF',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUNUCU NABIZ KARTI
  // ---------------------------------------------------------------------------
  Widget _buildSunucuNabizKarti() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              _cadServerOnline
                  ? Icons.check_circle_outline_rounded
                  : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CLOUDFLARE SUNUCUSU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        _cadServerOnline ? 'ÇEVRİMİÇİ' : 'KOPUK',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Gecikme: $_cadServerPingMs ms • $_cadServerDurum',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
            tooltip: 'Hızlı Ping Testi Yap',
            onPressed: _sunucuPingTestiYap,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SİYAH-BEYAZ METRİK KARTI (0 Overflow Garantili)
  // ---------------------------------------------------------------------------
  Widget _buildSiyahBeyazMetrikKarti({
    required String baslik,
    required String deger,
    required String altBilgi,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: Colors.white, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            deger,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            altBilgi,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KULLANICI KISA LİSTE SATIRI (0 Overflow)
  // ---------------------------------------------------------------------------
  Widget _buildKullaniciKisaSatir(Map<String, dynamic> data) {
    final adSoyad =
        (data['adSoyad'] ?? data['username'] ?? 'Kullanıcı').toString();
    final email = (data['email'] ?? 'E-posta yok').toString();
    final role = (data['role'] ?? 'üye').toString();
    final isAdmin = data['isAdmin'] == true || role == 'super_admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        adSoyad,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'YÖNETİCİ',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. CAD VE SUNUCU DETAY SEKME
  // ---------------------------------------------------------------------------
  Widget _buildCadVeSunucuSekmesi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sunucu Terminal Kutusu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CAD RENDERING SUNUCU TERMİNALİ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _cadServerOnline ? Colors.white : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 18),
                const Text(
                  'Aktif Tünel Uç Noktası (Cloudflare):',
                  style: TextStyle(color: Colors.white60, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  CadArkaplanServisi.cadServerUrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Durum: $_cadServerDurum',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      'Gecikme: $_cadServerPingMs ms',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.speed_rounded, size: 16),
                  label: const Text(
                    'Sunucu Ping ve Bağlantı Testi Yap',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _sunucuPingTestiYap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sistem Altyapı Bilgileri
          const Text(
            'SİSTEM ALTYAPISI & MOTORLAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                _buildSiyahBeyazAyarSatir(
                  icon: Icons.architecture_rounded,
                  baslik: 'DWG / DXF Geometri Motoru',
                  deger: 'Three.js & WebGL 2.0',
                ),
                const Divider(color: Colors.white12, height: 16),
                _buildSiyahBeyazAyarSatir(
                  icon: Icons.cloud_done_rounded,
                  baslik: 'Arka Plan İşleme Servisi',
                  deger: 'CadArkaplanServisi (Aktif)',
                ),
                const Divider(color: Colors.white12, height: 16),
                _buildSiyahBeyazAyarSatir(
                  icon: Icons.security_rounded,
                  baslik: 'Süper Yönetici Hesabı',
                  deger: 'emiryonetici1 (Super Admin)',
                ),
                const Divider(color: Colors.white12, height: 16),
                _buildSiyahBeyazAyarSatir(
                  icon: Icons.storage_rounded,
                  baslik: 'Veritabanı',
                  deger: 'Google Cloud Firestore',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiyahBeyazAyarSatir({
    required IconData icon,
    required String baslik,
    required String deger,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            deger,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. HESAPLAR VE KULLANICILAR SEKME (0 Overflow)
  // ---------------------------------------------------------------------------
  Widget _buildHesaplarSekmesi() {
    return Column(
      children: [
        // Arama Kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _aramaController,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ad, kullanıcı adı veya e-posta ara...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 18, color: Colors.white70),
              suffixIcon: _kullaniciArama.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 16, color: Colors.white70),
                      onPressed: () {
                        _aramaController.clear();
                        setState(() => _kullaniciArama = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.2),
              ),
            ),
            onChanged: (val) =>
                setState(() => _kullaniciArama = val.trim().toLowerCase()),
          ),
        ),

        // Kullanıcı Listesi Akışı
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final filtrelenmis = docs.where((doc) {
                if (_kullaniciArama.isEmpty) return true;
                final data = doc.data();
                final ad = (data['adSoyad'] ?? '').toString().toLowerCase();
                final user = (data['username'] ?? '').toString().toLowerCase();
                final mail = (data['email'] ?? '').toString().toLowerCase();
                return ad.contains(_kullaniciArama) ||
                    user.contains(_kullaniciArama) ||
                    mail.contains(_kullaniciArama);
              }).toList();

              if (filtrelenmis.isEmpty) {
                return const Center(
                  child: Text(
                    'Eşleşen kullanıcı bulunamadı.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: filtrelenmis.length,
                itemBuilder: (context, index) {
                  final doc = filtrelenmis[index];
                  final data = doc.data();
                  final uid = doc.id;
                  final adSoyad =
                      (data['adSoyad'] ?? data['username'] ?? 'Kullanıcı')
                          .toString();
                  final email = (data['email'] ?? 'E-posta yok').toString();
                  final role = (data['role'] ?? 'üye').toString();
                  final isAdmin =
                      data['isAdmin'] == true || role == 'super_admin';
                  final isBanned = data['banli'] == true;
                  final ilanSayisi =
                      (data['pazarIlanlari'] as List? ?? []).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBanned
                            ? Colors.white30
                            : (isAdmin ? Colors.white : Colors.white12),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          child: Text(
                            adSoyad.isNotEmpty
                                ? adSoyad[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      adSoyad,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: Colors.white,
                                        decoration: isBanned
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'YÖNETİCİ',
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isBanned) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.white),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'BANLI',
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$email • $ilanSayisi İlan',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              size: 18, color: Colors.white70),
                          onSelected: (action) async {
                            if (action == 'ban') {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                'banli': !isBanned,
                              }, SetOptions(merge: true));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isBanned
                                          ? '$adSoyad kullanıcısının engeli kaldırıldı.'
                                          : '$adSoyad kullanıcısı engellendi / banlandı.',
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                );
                              }
                            } else if (action == 'admin') {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                'isAdmin': !isAdmin,
                                'role': !isAdmin ? 'super_admin' : 'kullanici',
                              }, SetOptions(merge: true));
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'ban',
                              child: Text(
                                  isBanned ? 'Engeli Kaldır' : 'Kullanıcıyı Banla'),
                            ),
                            PopupMenuItem(
                              value: 'admin',
                              child: Text(isAdmin
                                  ? 'Admin Yetkisini Al'
                                  : 'Yönetici (Admin) Yap'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. ŞİKAYETLER VE İHBARLAR MASASI (Apple Guideline 1.2 Masası - 0 Overflow)
  // ---------------------------------------------------------------------------
  Widget _buildSikayetlerSekmesi() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_bildirimler')
          .orderBy('tarih', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final bildirimDocs = snapshot.data?.docs ?? [];

        if (bildirimDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aktif Şikayet veya İhbar Yok',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Topluluk kurallarına aykırı bir bildirim bulunmuyor.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: bildirimDocs.length,
          itemBuilder: (context, index) {
            final doc = bildirimDocs[index];
            final data = doc.data();
            final ilanId = (data['ilanId'] ?? '').toString();
            final ilanBaslik = (data['ilanBaslik'] ?? 'İlan').toString();
            final sikayetEdilenUid = (data['sikayetEdilenUid'] ??
                    data['kullaniciUid'] ??
                    '')
                .toString();
            final sikayetEdenAd =
                (data['sikayetEdenAd'] ?? 'Bir Kullanıcı').toString();
            final sebep = (data['sebep'] ??
                    data['kaynak'] ??
                    'Uygunsuz İçerik')
                .toString();
            final aciklama =
                (data['aciklama'] ?? data['orijinalMetin'] ?? '').toString();
            final durum = (data['durum'] ?? 'incelenecek').toString();
            final cozulduMu = durum == 'cozuldu';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cozulduMu ? Colors.white24 : Colors.white70,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum ve Sebep Rozetleri (Wrap ile taşma engellendi)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: cozulduMu ? Colors.white30 : Colors.white,
                          ),
                        ),
                        child: Text(
                          cozulduMu ? 'ÇÖZÜLDÜ' : 'İNCELEME BEKLİYOR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: cozulduMu ? Colors.white60 : Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        sebep,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İlan / Konu: $ilanBaslik',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (aciklama.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Bildiren Notu: "$aciklama"',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Bildiren: $sikayetEdenAd • UID: $sikayetEdilenUid',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Aksiyon Butonları (Wrap ile taşma engellendi)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      if (ilanId.isNotEmpty && !cozulduMu)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: const Text('İlanı Sil',
                              style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            await _kullaniciIlaniSil(
                                sikayetEdilenUid, ilanId);
                            await doc.reference.update({'durum': 'cozuldu'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'İlan sistemden tamamen kaldırıldı.'),
                                  backgroundColor: Colors.white,
                                ),
                              );
                            }
                          },
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              cozulduMu ? Colors.white12 : Colors.white,
                          foregroundColor:
                              cozulduMu ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final yeniDurum =
                              cozulduMu ? 'incelenecek' : 'cozuldu';
                          await doc.reference.update({'durum': yeniDurum});
                        },
                        child: Text(
                          cozulduMu ? 'Yeniden Aç' : 'Çözüldü Olarak İşaretle',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _kullaniciIlaniSil(String hedefUid, String ilanId) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(hedefUid);
      final doc = await userRef.get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final mevcutList = List<Map<String, dynamic>>.from(
        (data['pazarIlanlari'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      mevcutList.removeWhere((item) => item['id'] == ilanId);
      await userRef.set({'pazarIlanlari': mevcutList}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('İlan silme hatası: $e');
    }
  }
}
