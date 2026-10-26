import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fcm_servisi.dart';
import 'bildirim_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class HatirlatmalarEkrani extends StatefulWidget {
  const HatirlatmalarEkrani({super.key});

  @override
  State<HatirlatmalarEkrani> createState() => _HatirlatmalarEkraniState();
}

class _HatirlatmalarEkraniState extends State<HatirlatmalarEkrani>
    with WidgetsBindingObserver {
  // Kategori bazlı tercihler
  bool _puantajHatirlaticiAktif = true;
  bool _cadBildirimleriAktif = true;
  bool _odemeBildirimleriAktif = true;
  bool _ekipBildirimleriAktif = true;
  bool _havaDurumuBildirimleriAktif = true;

  late TimeOfDay _geciciSeciliSaat;
  bool _isLoading = true;
  bool _bildirimIzniVar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ayarlariYukle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _izinDurumunuKontrolEt();
    }
  }

  Future<void> _izinDurumunuKontrolEt() async {
    bool izinli = false;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited || status.isProvisional) {
        izinli = true;
      }
    } catch (_) {}

    if (!izinli) {
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          izinli = true;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _bildirimIzniVar = izinli;
      });
    }
  }

  Future<void> _bildirimIzniniAktiflestir() async {
    bool izinAlindi = false;
    try {
      final status = await Permission.notification.request();
      if (status.isGranted || status.isLimited || status.isProvisional) {
        izinAlindi = true;
      }
    } catch (_) {}

    if (!izinAlindi) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          izinAlindi = true;
        }
      } catch (_) {}
    }

    if (izinAlindi) {
      if (mounted) {
        setState(() {
          _bildirimIzniVar = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim izinleri başarıyla aktifleştirildi!'),
            backgroundColor: _kBrandTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await FcmServisi().kullaniciBagla();
    } else {
      PermissionStatus? status;
      try {
        status = await Permission.notification.status;
      } catch (_) {}

      if (status != null && status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Bildirim İzni Gerekli'),
              content: const Text(
                'Bildirim izinleri cihaz ayarlarından kapatılmış. Hatırlatıcıların çalabilmesi için lütfen ayarlardan bildirim iznini açın.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrandTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Ayarları Aç'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim izni verilmedi. Hatırlatıcılar sessiz kalabilir.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _ayarlariYukle() async {
    await _izinDurumunuKontrolEt();

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _puantajHatirlaticiAktif =
          prefs.getBool('puantajHatirlaticiAktif') ??
          prefs.getBool('hatirlatmalarAktif') ??
          true;
      _cadBildirimleriAktif = prefs.getBool('cadBildirimleriAktif') ?? true;
      _odemeBildirimleriAktif = prefs.getBool('odemeBildirimleriAktif') ?? true;
      _ekipBildirimleriAktif =
          prefs.getBool('ekipBildirimleriAktif') ??
          prefs.getBool('islemBildirimleriAktif') ??
          true;
      _havaDurumuBildirimleriAktif =
          prefs.getBool('havaDurumuBildirimleriAktif') ?? true;

      final saat = prefs.getInt('hatirlatmaSaati') ?? 20;
      final dakika = prefs.getInt('hatirlatmaDakikasi') ?? 0;
      _geciciSeciliSaat = TimeOfDay(hour: saat, minute: dakika);
      _isLoading = false;
    });

    // Firestore'dan güncel durumu çekip senkronize et
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data();
          if (data != null) {
            setState(() {
              if (data.containsKey('puantajHatirlaticiAktif')) {
                _puantajHatirlaticiAktif = data['puantajHatirlaticiAktif'] as bool;
              }
              if (data.containsKey('cadBildirimleriAktif')) {
                _cadBildirimleriAktif = data['cadBildirimleriAktif'] as bool;
              }
              if (data.containsKey('odemeBildirimleriAktif')) {
                _odemeBildirimleriAktif = data['odemeBildirimleriAktif'] as bool;
              }
              if (data.containsKey('ekipBildirimleriAktif')) {
                _ekipBildirimleriAktif = data['ekipBildirimleriAktif'] as bool;
              }
              if (data.containsKey('havaDurumuBildirimleriAktif')) {
                _havaDurumuBildirimleriAktif =
                    data['havaDurumuBildirimleriAktif'] as bool;
              }
            });
          }
        }
      } catch (e) {
        debugPrint("İşlem bildirim ayarı yüklenemedi: $e");
      }
    }
  }

  Future<void> _ayarlariKaydetVeUygula() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('puantajHatirlaticiAktif', _puantajHatirlaticiAktif);
    await prefs.setBool('hatirlatmalarAktif', _puantajHatirlaticiAktif);
    await prefs.setBool('cadBildirimleriAktif', _cadBildirimleriAktif);
    await prefs.setBool('odemeBildirimleriAktif', _odemeBildirimleriAktif);
    await prefs.setBool('ekipBildirimleriAktif', _ekipBildirimleriAktif);
    await prefs.setBool('islemBildirimleriAktif', _ekipBildirimleriAktif);
    await prefs.setBool(
      'havaDurumuBildirimleriAktif',
      _havaDurumuBildirimleriAktif,
    );

    await prefs.setInt('hatirlatmaSaati', _geciciSeciliSaat.hour);
    await prefs.setInt('hatirlatmaDakikasi', _geciciSeciliSaat.minute);

    // 1. Puantaj & Rapor hatırlatıcısı
    if (_puantajHatirlaticiAktif) {
      await BildirimServisi().planlaPuantajHatirlatici(
        saat: _geciciSeciliSaat.hour,
        dakika: _geciciSeciliSaat.minute,
      );
    } else {
      await BildirimServisi().iptalEtPuantajHatirlatici();
    }

    // 2. Hava durumu ve saha koşulları hatırlatıcısı (Sabah 08:00)
    if (_havaDurumuBildirimleriAktif) {
      await BildirimServisi().planlaHavaDurumuHatirlatici(saat: 8, dakika: 0);
    } else {
      await BildirimServisi().iptalEtHavaDurumuHatirlatici();
    }

    // 3. Finans ve ödeme hatırlatıcısı (Sabah 10:00)
    if (_odemeBildirimleriAktif) {
      await BildirimServisi().planlaOdemeHatirlatici(saat: 10, dakika: 0);
    } else {
      await BildirimServisi().iptalEtOdemeHatirlatici();
    }

    // 4. CAD & Çizim güncellemeleri hatırlatıcısı (Öğleden sonra 14:00)
    if (_cadBildirimleriAktif) {
      await BildirimServisi().planlaCadHatirlatici(saat: 14, dakika: 0);
    } else {
      await BildirimServisi().iptalEtCadHatirlatici();
    }

    // Firestore'a da kaydet
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'puantajHatirlaticiAktif': _puantajHatirlaticiAktif,
          'cadBildirimleriAktif': _cadBildirimleriAktif,
          'odemeBildirimleriAktif': _odemeBildirimleriAktif,
          'ekipBildirimleriAktif': _ekipBildirimleriAktif,
          'havaDurumuBildirimleriAktif': _havaDurumuBildirimleriAktif,
          'hatirlatmaSaati': _geciciSeciliSaat.hour,
          'hatirlatmaDakikasi': _geciciSeciliSaat.minute,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("İşlem bildirim ayarı kaydedilemedi: $e");
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirim tercihleri başarıyla kaydedildi.'),
        backgroundColor: _kBrandTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saatSec() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yeniSaat = await showTimePicker(
      context: context,
      initialTime: _geciciSeciliSaat,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _kBrandTeal,
              onPrimary: Colors.white,
              surface:
                  isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
              onSurface: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (yeniSaat != null) {
      setState(() => _geciciSeciliSaat = yeniSaat);
      _ayarlariKaydetVeUygula();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'Bildirim Tercihleri',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: _kBrandTeal),
                )
                : SafeArea(
                  top: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      FloatingLiquidAppBar.topPadding(context, extra: 4),
                      16,
                      32,
                    ),
                    children: [
                      // Bildirim İzni Kartı / Uyarısı
                      if (!_bildirimIzniVar) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.40 : 0.30),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_off_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bildirim İzni Devre Dışı',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Hatırlatıcıların ve puantaj alarmlarının çalışabilmesi için bildirim izni vermeniz gerekir.',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.notifications_active_rounded, size: 20),
                                label: Text(
                                  'Bildirim İzinlerini Aktifleştir',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: _bildirimIzniniAktiflestir,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Cihaz bildirim izinleri aktif',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Bilgilendirme Bannerı
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kBrandTeal.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _kBrandTeal.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: _kBrandTeal,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Hangi bildirimleri almak istediğinizi kategori bazlı özelleştirin.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : const Color(0xFF102A43),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Ayarlar alanı (İzin yoksa devre dışı bırakılır)
                      IgnorePointer(
                        ignoring: !_bildirimIzniVar,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _bildirimIzniVar ? 1.0 : 0.40,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Akıllı Puantaj ve Rapor Hatırlatıcısı
                              _buildSectionHeader('Puantaj ve Raporlar', isDark),
                              const SizedBox(height: 8),
                              GlassSectionCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 8,
                                      ),
                                      title: const Text(
                                        'Akıllı "Eksik Puantaj" Uyarısı',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'O gün herhangi bir puantaj veya rapor girilmediyse akşam saatinde nazikçe hatırlatır.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      value: _puantajHatirlaticiAktif,
                                      onChanged: (val) {
                                        setState(() => _puantajHatirlaticiAktif = val);
                                        _ayarlariKaydetVeUygula();
                                      },
                                      activeThumbColor: _kBrandTeal,
                                      secondary: Icon(
                                        _puantajHatirlaticiAktif
                                            ? Icons.notification_important_rounded
                                            : Icons.notifications_off_outlined,
                                        color:
                                            _puantajHatirlaticiAktif
                                                ? _kBrandTeal
                                                : Colors.grey,
                                      ),
                                    ),
                                    if (_puantajHatirlaticiAktif) ...[
                                      const Divider(height: 1),
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 4,
                                        ),
                                        leading: const Icon(
                                          Icons.access_time_filled,
                                          color: _kBrandTeal,
                                        ),
                                        title: const Text(
                                          'Hatırlatma Saati',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        trailing: GlassInsetSurface(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          borderRadius: 10,
                                          child: Text(
                                            _geciciSeciliSaat.format(context),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: _kBrandTeal,
                                            ),
                                          ),
                                        ),
                                        onTap: _saatSec,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // 2. CAD / Proje Güncelleme Bildirimleri
                              _buildSectionHeader('Projeler & Çizimler', isDark),
                              const SizedBox(height: 8),
                              GlassSectionCard(
                                padding: EdgeInsets.zero,
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  title: const Text(
                                    'CAD & Proje Güncellemeleri',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Yeni bir dwg/dxf mimari çizim veya revize yüklendiğinde anında haber verir.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  value: _cadBildirimleriAktif,
                                  onChanged: (val) {
                                    setState(() => _cadBildirimleriAktif = val);
                                    _ayarlariKaydetVeUygula();
                                  },
                                  activeThumbColor: _kBrandTeal,
                                  secondary: Icon(
                                    Icons.architecture_rounded,
                                    color:
                                        _cadBildirimleriAktif
                                            ? const Color(0xFF0EA5E9)
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // 3. Finans ve Ödeme Hatırlatıcıları
                              _buildSectionHeader('Finans & Ödemeler', isDark),
                              const SizedBox(height: 8),
                              GlassSectionCard(
                                padding: EdgeInsets.zero,
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  title: const Text(
                                    'Ödeme ve Hakediş Bildirimleri',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Bekleyen ödemeler, vadesi gelen çekler ve avans taleplerinde bildirim gönderir.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  value: _odemeBildirimleriAktif,
                                  onChanged: (val) {
                                    setState(() => _odemeBildirimleriAktif = val);
                                    _ayarlariKaydetVeUygula();
                                  },
                                  activeThumbColor: _kBrandTeal,
                                  secondary: Icon(
                                    Icons.payments_rounded,
                                    color:
                                        _odemeBildirimleriAktif
                                            ? const Color(0xFF10B981)
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // 4. Ekip ve İşlem Bildirimleri
                              _buildSectionHeader('Ekip & Yetkilendirme', isDark),
                              const SizedBox(height: 8),
                              GlassSectionCard(
                                padding: EdgeInsets.zero,
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  title: const Text(
                                    'Ekip & Rol Bildirimleri',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Yeni üye katılımı, rol atamaları ve işçi kartı eşleşmelerinde anlık haberdar olun.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  value: _ekipBildirimleriAktif,
                                  onChanged: (val) {
                                    setState(() => _ekipBildirimleriAktif = val);
                                    _ayarlariKaydetVeUygula();
                                  },
                                  activeThumbColor: _kBrandTeal,
                                  secondary: Icon(
                                    Icons.groups_rounded,
                                    color:
                                        _ekipBildirimleriAktif
                                            ? const Color(0xFF6366F1)
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // 5. Hava Durumu & Saha Uyarıları
                              _buildSectionHeader('Saha Koşulları', isDark),
                              const SizedBox(height: 8),
                              GlassSectionCard(
                                padding: EdgeInsets.zero,
                                child: SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  title: const Text(
                                    'Hava Durumu & Beton Döküm Uyarısı',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Şantiyenizde yağış, fırtına veya don riski olduğunda sabahları proaktif saha uyarısı alırsınız.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  value: _havaDurumuBildirimleriAktif,
                                  onChanged: (val) {
                                    setState(() => _havaDurumuBildirimleriAktif = val);
                                    _ayarlariKaydetVeUygula();
                                  },
                                  activeThumbColor: _kBrandTeal,
                                  secondary: Icon(
                                    Icons.cloudy_snowing,
                                    color:
                                        _havaDurumuBildirimleriAktif
                                            ? const Color(0xFF38BDF8)
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : const Color(0xFF486581),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
