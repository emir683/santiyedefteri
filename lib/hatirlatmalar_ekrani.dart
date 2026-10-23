import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bildirim_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class HatirlatmalarEkrani extends StatefulWidget {
  const HatirlatmalarEkrani({super.key});

  @override
  State<HatirlatmalarEkrani> createState() => _HatirlatmalarEkraniState();
}

class _HatirlatmalarEkraniState extends State<HatirlatmalarEkrani> {
  // Kategori bazlı tercihler
  bool _puantajHatirlaticiAktif = true;
  bool _cadBildirimleriAktif = true;
  bool _odemeBildirimleriAktif = true;
  bool _ekipBildirimleriAktif = true;
  bool _havaDurumuBildirimleriAktif = true;

  late TimeOfDay _geciciSeciliSaat;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
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

    if (_puantajHatirlaticiAktif) {
      await BildirimServisi().gunlukHatirlatmaAyarlaSimple(_geciciSeciliSaat);
    } else {
      await BildirimServisi().tumBildirimleriIptalEt();
    }

    // Firestore'a kaydet (Cloud Function bildirim gönderirken bakar)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'puantajHatirlaticiAktif': _puantajHatirlaticiAktif,
          'cadBildirimleriAktif': _cadBildirimleriAktif,
          'odemeBildirimleriAktif': _odemeBildirimleriAktif,
          'ekipBildirimleriAktif': _ekipBildirimleriAktif,
          'islemBildirimleriAktif': _ekipBildirimleriAktif,
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
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

                      // 2. CAD Çizim Bildirimleri
                      _buildSectionHeader('CAD ve Çizimler', isDark),
                      const SizedBox(height: 8),
                      GlassSectionCard(
                        padding: EdgeInsets.zero,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          title: const Text(
                            'CAD Çizim Çözümleme Bildirimleri',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Büyük DWG/DXF dosyaları arka planda hazır olduğunda anında açma bildirimi gönderir.',
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
                                    ? const Color(0xFF00F0FF)
                                    : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Ödeme ve Avans Bildirimleri
                      _buildSectionHeader('Finans ve Ödemeler', isDark),
                      const SizedBox(height: 8),
                      GlassSectionCard(
                        padding: EdgeInsets.zero,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          title: const Text(
                            'Ödeme ve Avans Bildirimleri',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'İşçilere avans verildiğinde veya ödeme kaydedildiğinde bildirim alırsınız.',
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
                                    ? _kBrandTeal
                                    : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4. Ekip ve Rol Değişiklikleri
                      _buildSectionHeader('Ekip ve Yetkiler', isDark),
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
