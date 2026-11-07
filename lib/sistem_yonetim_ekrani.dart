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
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      setState(() {
        _pingYukleniyor = false;
        _cadServerPingMs = stopwatch.elapsedMilliseconds;
        if (res.statusCode == 200 || res.statusCode == 404) {
          _cadServerOnline = true;
          _cadServerDurum = 'Aktif (${res.statusCode})';
        } else {
          _cadServerOnline = false;
          _cadServerDurum = 'Uyarı (${res.statusCode})';
        }
      });
    } catch (e) {
      stopwatch.stop();
      // Alternatif root ping
      try {
        final rootRes = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        setState(() {
          _pingYukleniyor = false;
          _cadServerPingMs = stopwatch.elapsedMilliseconds;
          _cadServerOnline = true;
          _cadServerDurum = 'Aktif (${rootRes.statusCode})';
        });
      } catch (rootErr) {
        setState(() {
          _pingYukleniyor = false;
          _cadServerPingMs = stopwatch.elapsedMilliseconds;
          _cadServerOnline = false;
          _cadServerDurum = 'Bağlantı Hatası / Çevrimdışı';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0F7C86);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B131E) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131F2E) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistem Kokpiti & Yönetim',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Canlı İstatistikler & Moderasyon Masası',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Verileri ve Sunucu Durumunu Yenile',
            onPressed: () {
              _sunucuPingTestiYap();
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Genel Bakış'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Hesaplar'),
            Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Şikayet & İhbarlar'),
            Tab(icon: Icon(Icons.dns_rounded, size: 18), text: 'Sunucu & CAD'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenelBakisSekmesi(isDark, primaryColor),
          _buildHesaplarSekmesi(isDark, primaryColor),
          _buildSikayetlerSekmesi(isDark),
          _buildSunucuCadSekmesi(isDark, primaryColor),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. GENEL BAKIŞ VE CANLI METRİKLER SEKME
  // ---------------------------------------------------------------------------
  Widget _buildGenelBakisSekmesi(bool isDark, Color primary) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('teams').snapshots(),
          builder: (context, teamSnap) {
            final userDocs = userSnap.data?.docs ?? [];
            final teamDocs = teamSnap.data?.docs ?? [];

            // İlan Sayısını Hesapla
            int toplamIlanSayisi = 0;
            int aktifKullaniciSon24Saat = 0;
            final son24Saat = DateTime.now().subtract(const Duration(hours: 24));

            for (final doc in userDocs) {
              final data = doc.data();
              final ilanlar = data['pazarIlanlari'] as List? ?? [];
              toplamIlanSayisi += ilanlar.length;

              final lastActive = (data['sonGirisTarihi'] as Timestamp?)?.toDate();
              if (lastActive != null && lastActive.isAfter(son24Saat)) {
                aktifKullaniciSon24Saat++;
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_bildirimler')
                  .where('durum', isEqualTo: 'incelenecek')
                  .snapshots(),
              builder: (context, bildirimSnap) {
                final acikSikayetSayisi = bildirimSnap.data?.docs.length ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sunucu Canlı Nabız Bandı
                      _buildSunucuNabizKarti(isDark),
                      const SizedBox(height: 16),

                      // 4 Ana KPI Kartı
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetrikKarti(
                              baslik: 'Kayıtlı Hesaplar',
                              deger: userDocs.length.toString(),
                              altBilgi: '$aktifKullaniciSon24Saat son 24s aktif',
                              icon: Icons.people_outline_rounded,
                              renk: const Color(0xFF3B82F6),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetrikKarti(
                              baslik: 'Kayıtlı Ekipler',
                              deger: teamDocs.length.toString(),
                              altBilgi: 'Aktif Şantiye Ekipleri',
                              icon: Icons.groups_rounded,
                              renk: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetrikKarti(
                              baslik: 'Pazar İlanları',
                              deger: toplamIlanSayisi.toString(),
                              altBilgi: 'İş & Usta Vitrinleri',
                              icon: Icons.storefront_rounded,
                              renk: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetrikKarti(
                              baslik: 'Bekleyen Şikayet',
                              deger: acikSikayetSayisi.toString(),
                              altBilgi: acikSikayetSayisi > 0 ? 'İnceleme Bekliyor' : 'Sorun Yok',
                              icon: Icons.report_problem_rounded,
                              renk: acikSikayetSayisi > 0 ? Colors.redAccent : const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Son Kayıt Olan Kullanıcılar Başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Son Katılan Kullanıcılar',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _tabController.animateTo(1),
                            child: const Text('Tümünü Gör'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (userDocs.isEmpty)
                        const Center(child: Text('Henüz kullanıcı bulunmuyor.'))
                      else
                        ...userDocs.take(5).map((doc) {
                          final data = doc.data();
                          return _buildKullaniciKisaSatir(data, isDark);
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
  }

  Widget _buildSunucuNabizKarti(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cadServerOnline
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _cadServerOnline ? Icons.check_circle_rounded : Icons.error_rounded,
              color: _cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CAD & Cloudflare Sunucusu',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _cadServerOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Gecikme: ${_cadServerPingMs}ms • Durum: $_cadServerDurum',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
            tooltip: 'Hızlı Ping Testi',
            onPressed: _sunucuPingTestiYap,
          ),
        ],
      ),
    );
  }

  Widget _buildMetrikKarti({
    required String baslik,
    required String deger,
    required String altBilgi,
    required IconData icon,
    required Color renk,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                baslik,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: renk, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            deger,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            altBilgi,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKullaniciKisaSatir(Map<String, dynamic> data, bool isDark) {
    final adSoyad = (data['adSoyad'] ?? data['username'] ?? 'Kullanıcı').toString();
    final email = (data['email'] ?? 'E-posta yok').toString();
    final role = (data['role'] ?? 'üye').toString();
    final isAdmin = data['isAdmin'] == true || role == 'super_admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF0F7C86),
            child: Text(
              adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YÖNETİCİ',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
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
  // 2. HESAPLAR VE KULLANICILAR SEKME
  // ---------------------------------------------------------------------------
  Widget _buildHesaplarSekmesi(bool isDark, Color primary) {
    return Column(
      children: [
        // Arama Kutusu
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _aramaController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ad, kullanıcı adı veya e-posta ile ara...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _kullaniciArama.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _aramaController.clear();
                        setState(() => _kullaniciArama = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF131F2E) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            onChanged: (val) => setState(() => _kullaniciArama = val.trim().toLowerCase()),
          ),
        ),

        // Kullanıcı Listesi Akışı
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                  child: Text('Eşleşen kullanıcı bulunamadı.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtrelenmis.length,
                itemBuilder: (context, index) {
                  final doc = filtrelenmis[index];
                  final data = doc.data();
                  final uid = doc.id;
                  final adSoyad = (data['adSoyad'] ?? data['username'] ?? 'Kullanıcı').toString();
                  final email = (data['email'] ?? 'E-posta yok').toString();
                  final role = (data['role'] ?? 'üye').toString();
                  final isAdmin = data['isAdmin'] == true || role == 'super_admin';
                  final isBanned = data['banli'] == true;
                  final ilanSayisi = (data['pazarIlanlari'] as List? ?? []).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131F2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isBanned
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : (isAdmin
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                : (isDark ? Colors.white10 : Colors.black12)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isBanned
                              ? Colors.redAccent
                              : (isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF0F7C86)),
                          child: Text(
                            adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                        fontSize: 13.5,
                                        decoration: isBanned ? TextDecoration.lineThrough : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 6),
                                    const Text('👑', style: TextStyle(fontSize: 12)),
                                  ],
                                  if (isBanned) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'BANLI',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$email • $ilanSayisi İlan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (action) async {
                            if (action == 'ban') {
                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
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
                                  ),
                                );
                              }
                            } else if (action == 'admin') {
                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'isAdmin': !isAdmin,
                                'role': !isAdmin ? 'super_admin' : 'kullanici',
                              }, SetOptions(merge: true));
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'ban',
                              child: Row(
                                children: [
                                  Icon(
                                    isBanned ? Icons.check_circle_outline : Icons.block_rounded,
                                    color: isBanned ? Colors.green : Colors.redAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isBanned ? 'Engeli Kaldır' : 'Kullanıcıyı Banla'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Icon(
                                    isAdmin ? Icons.remove_moderator : Icons.add_moderator,
                                    color: const Color(0xFFF59E0B),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isAdmin ? 'Admin Yetkisini Al' : 'Yönetici (Admin) Yap'),
                                ],
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
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ŞİKAYETLER VE İHBARLAR MASASI (Apple Guideline 1.2 Masası)
  // ---------------------------------------------------------------------------
  Widget _buildSikayetlerSekmesi(bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_bildirimler')
          .orderBy('tarih', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bildirimDocs = snapshot.data?.docs ?? [];

        if (bildirimDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 48,
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aktif Şikayet veya İhbar Yok',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Topluluk kurallarına aykırı bir bildirim bulunmuyor.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
            final sikayetEdilenUid = (data['sikayetEdilenUid'] ?? data['kullaniciUid'] ?? '').toString();
            final sikayetEdenAd = (data['sikayetEdenAd'] ?? 'Bir Kullanıcı').toString();
            final sebep = (data['sebep'] ?? data['kaynak'] ?? 'Uygunsuz İçerik').toString();
            final aciklama = (data['aciklama'] ?? data['orijinalMetin'] ?? '').toString();
            final durum = (data['durum'] ?? 'incelenecek').toString();
            final cozulduMu = durum == 'cozuldu';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131F2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cozulduMu
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (cozulduMu ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cozulduMu ? 'ÇÖZÜLDÜ' : 'İNCELEME BEKLİYOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cozulduMu ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sebep,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlan / Konu: $ilanBaslik',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if (aciklama.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Bildiren Notu: "$aciklama"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Bildiren: $sikayetEdenAd • Şüpheli UID: $sikayetEdilenUid',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  // Yönetici Aksiyon Butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (ilanId.isNotEmpty && !cozulduMu)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('İlanı Sil', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await _kullaniciIlaniSil(sikayetEdilenUid, ilanId);
                            await doc.reference.update({'durum': 'cozuldu'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('İlan sistemden tamamen kaldırıldı.')),
                              );
                            }
                          },
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cozulduMu ? Colors.grey : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () async {
                          final yeniDurum = cozulduMu ? 'incelenecek' : 'cozuldu';
                          await doc.reference.update({'durum': yeniDurum});
                        },
                        child: Text(
                          cozulduMu ? 'Yeniden Aç' : 'Çözüldü Olarak İşaretle',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
      final userRef = FirebaseFirestore.instance.collection('users').doc(hedefUid);
      final doc = await userRef.get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final mevcutList = List<Map<String, dynamic>>.from(
        (data['pazarIlanlari'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      mevcutList.removeWhere((item) => item['id'] == ilanId);
      await userRef.set({'pazarIlanlari': mevcutList}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('İlan silme hatası: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 4. SUNUCU & CAD MOTORU SEKME
  // ---------------------------------------------------------------------------
  Widget _buildSunucuCadSekmesi(bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sunucu Terminal Kutusu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded, color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CAD Rendering Sunucu Terminali',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                const Text(
                  'Sunucu Adresi (Cloudflare Tunnel):',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  CadArkaplanServisi.cadServerUrl,
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Durum Kodu: ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(
                      _cadServerDurum,
                      style: TextStyle(
                        color: _cadServerOnline ? const Color(0xFF10B981) : Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('Ping Gecikmesi: ', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(
                      '$_cadServerPingMs ms',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7C86),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  icon: const Icon(Icons.speed_rounded, size: 18),
                  label: const Text('Sunucuyu Yeniden Ping Yap'),
                  onPressed: _sunucuPingTestiYap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // CAD Dosya Sayacı Bilgisi
          const Text(
            'İşlenen CAD Dosyaları & İşlemler',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131F2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                _buildAyarSatir(
                  icon: Icons.architecture_rounded,
                  baslik: 'DWG / DXF Motoru',
                  deger: 'Three.js & WebGL 2.0',
                  renk: const Color(0xFF3B82F6),
                ),
                const Divider(height: 16),
                _buildAyarSatir(
                  icon: Icons.cloud_done_rounded,
                  baslik: 'Arka Plan İşleme Servisi',
                  deger: 'CadArkaplanServisi (Aktif)',
                  renk: const Color(0xFF10B981),
                ),
                const Divider(height: 16),
                _buildAyarSatir(
                  icon: Icons.security_rounded,
                  baslik: 'Yönetici Hesabı',
                  deger: 'emiryonetici1 (Super Admin)',
                  renk: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAyarSatir({
    required IconData icon,
    required String baslik,
    required String deger,
    required Color renk,
  }) {
    return Row(
      children: [
        Icon(icon, color: renk, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Text(
          deger,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
