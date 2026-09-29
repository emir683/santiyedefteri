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
  late bool _geciciHatirlatmalarAktif;
  late bool _geciciIslemBildirimleriAktif;
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
      _geciciHatirlatmalarAktif = prefs.getBool('hatirlatmalarAktif') ?? false;
      _geciciIslemBildirimleriAktif = prefs.getBool('islemBildirimleriAktif') ?? true;
      final saat = prefs.getInt('hatirlatmaSaati') ?? 20;
      final dakika = prefs.getInt('hatirlatmaDakikasi') ?? 0;
      _geciciSeciliSaat = TimeOfDay(hour: saat, minute: dakika);
      _isLoading = false;
    });

    // Firestore'dan güncel durumu çekip senkronize et
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data();
          if (data != null && data.containsKey('islemBildirimleriAktif')) {
            final aktif = data['islemBildirimleriAktif'] as bool;
            setState(() {
              _geciciIslemBildirimleriAktif = aktif;
            });
            await prefs.setBool('islemBildirimleriAktif', aktif);
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
    await prefs.setBool('hatirlatmalarAktif', _geciciHatirlatmalarAktif);
    await prefs.setBool('islemBildirimleriAktif', _geciciIslemBildirimleriAktif);
    await prefs.setInt('hatirlatmaSaati', _geciciSeciliSaat.hour);
    await prefs.setInt('hatirlatmaDakikasi', _geciciSeciliSaat.minute);

    if (_geciciHatirlatmalarAktif) {
      await BildirimServisi().gunlukHatirlatmaAyarlaSimple(_geciciSeciliSaat);
    } else {
      await BildirimServisi().tumBildirimleriIptalEt();
    }

    // Firestore'a kaydet
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'islemBildirimleriAktif': _geciciIslemBildirimleriAktif,
        });
      } catch (e) {
        debugPrint("İşlem bildirim ayarı kaydedilemedi: $e");
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildirim ayarları kaydedildi ve uygulandı.'),
        backgroundColor: _kBrandTeal,
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
              surface: isDark
                  ? const Color(0xFF101317)
                  : const Color(0xFFF7FBFD),
              onSurface: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDark
                  ? const Color(0xFF101317)
                  : const Color(0xFFF7FBFD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFD8EAF0),
                ),
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark
                  ? const Color(0xFF101317)
                  : const Color(0xFFF7FBFD),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFD8EAF0),
                ),
              ),
              hourMinuteColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return isDark
                      ? const Color(0xFF134E4A)
                      : const Color(0xFFD6F4EF);
                }
                return isDark
                    ? const Color(0xFF1A2027)
                    : const Color(0xFFEFF5F7);
              }),
              hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return isDark ? const Color(0xFFB9FFF4) : _kBrandTeal;
                }
                return isDark ? Colors.white : const Color(0xFF0F172A);
              }),
              dayPeriodColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return isDark
                      ? const Color(0xFF123E3B)
                      : const Color(0xFFD8F4EF);
                }
                return Colors.transparent;
              }),
              dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return isDark ? const Color(0xFFB9FFF4) : _kBrandTeal;
                }
                return isDark ? Colors.white70 : const Color(0xFF64748B);
              }),
              dayPeriodBorderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : const Color(0xFFD8EAF0),
              ),
              dialHandColor: _kBrandTeal,
              dialBackgroundColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFEAF5F7),
              dialTextColor: MaterialStateColor.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white : const Color(0xFF0F172A);
              }),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFD8EAF0),
                ),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFD8EAF0),
                ),
              ),
              entryModeIconColor: _kBrandTeal,
              helpTextStyle: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF516772),
                fontWeight: FontWeight.w700,
              ),
              hourMinuteTextStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
              dayPeriodTextStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: _kBrandTeal,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (yeniSaat != null) {
      setState(() => _geciciSeciliSaat = yeniSaat);
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
        title: 'Hatırlatmalar',
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
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      FloatingLiquidAppBar.topPadding(context, extra: 4),
                      16,
                      16,
                    ),
                    child: Column(
                    children: [
                      GlassSectionCard(
                        padding: EdgeInsets.zero,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          title: const Text(
                            'Günlük Rapor Hatırlatıcısı',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Her gün belirlenen saatte bildirim gönderir.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _geciciHatirlatmalarAktif,
                          onChanged:
                              (value) => setState(
                                () => _geciciHatirlatmalarAktif = value,
                              ),
                          activeColor: _kBrandTeal,
                          secondary: Icon(
                            _geciciHatirlatmalarAktif
                                ? Icons.notifications_active
                                : Icons.notifications_off_outlined,
                            color:
                                _geciciHatirlatmalarAktif
                                    ? _kBrandTeal
                                    : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassSectionCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Icon(
                            Icons.access_time_filled,
                            color:
                                _geciciHatirlatmalarAktif
                                    ? _kBrandTeal
                                    : Colors.grey,
                          ),
                          title: const Text(
                            'Hatırlatma Saati',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: GlassInsetSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            borderRadius: 12,
                            child: Text(
                              _geciciSeciliSaat.format(context),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    _geciciHatirlatmalarAktif
                                        ? _kBrandTeal
                                        : Colors.grey,
                              ),
                            ),
                          ),
                          onTap: _geciciHatirlatmalarAktif ? _saatSec : null,
                          enabled: _geciciHatirlatmalarAktif,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassSectionCard(
                        padding: EdgeInsets.zero,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          title: const Text(
                            'Ekip İşlemleri Bildirimi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Ekip yöneticileri bir işlem yaptığında anlık bildirim alırsınız.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _geciciIslemBildirimleriAktif,
                          onChanged: (value) => setState(
                            () => _geciciIslemBildirimleriAktif = value,
                          ),
                          activeColor: _kBrandTeal,
                          secondary: Icon(
                            _geciciIslemBildirimleriAktif
                                ? Icons.group_work
                                : Icons.group_work_outlined,
                            color: _geciciIslemBildirimleriAktif
                                ? _kBrandTeal
                                : Colors.grey,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Ayarları Kaydet'),
                          onPressed: _ayarlariKaydetVeUygula,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBrandTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
