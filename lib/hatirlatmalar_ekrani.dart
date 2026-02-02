import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bildirim_servisi.dart';
import 'tema_ayarlari.dart';

class HatirlatmalarEkrani extends StatefulWidget {
  const HatirlatmalarEkrani({super.key});

  @override
  State<HatirlatmalarEkrani> createState() => _HatirlatmalarEkraniState();
}

class _HatirlatmalarEkraniState extends State<HatirlatmalarEkrani> {
  late bool _geciciHatirlatmalarAktif;
  late TimeOfDay _geciciSeciliSaat;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _geciciHatirlatmalarAktif = prefs.getBool('hatirlatmalarAktif') ?? false;
        final int saat = prefs.getInt('hatirlatmaSaati') ?? 20;
        final int dakika = prefs.getInt('hatirlatmaDakikasi') ?? 0;
        _geciciSeciliSaat = TimeOfDay(hour: saat, minute: dakika);
        _isLoading = false;
      });
    }
  }

  Future<void> _ayarlariKaydetVeUygula() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hatirlatmalarAktif', _geciciHatirlatmalarAktif);
    await prefs.setInt('hatirlatmaSaati', _geciciSeciliSaat.hour);
    await prefs.setInt('hatirlatmaDakikasi', _geciciSeciliSaat.minute);

    if (_geciciHatirlatmalarAktif) {
      await BildirimServisi().gunlukHatirlatmaAyarlaSimple(_geciciSeciliSaat);
    } else {
      await BildirimServisi().tumBildirimleriIptalEt();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hatırlatma ayarları kaydedildi ve uygulandı."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _saatSec() async {
    final TimeOfDay? yeniSaat = await showTimePicker(
      context: context,
      initialTime: _geciciSeciliSaat,
    );
    if (yeniSaat != null) {
      setState(() {
        _geciciSeciliSaat = yeniSaat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hatırlatmalar"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      title: const Text("Günlük Rapor Hatırlatıcısı", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Her gün belirlenen saatte bildirim gönderir."),
                      value: _geciciHatirlatmalarAktif,
                      onChanged: (bool value) {
                        setState(() => _geciciHatirlatmalarAktif = value);
                      },
                      secondary: Icon(
                        _geciciHatirlatmalarAktif ? Icons.notifications_active : Icons.notifications_off_outlined,
                        color: _geciciHatirlatmalarAktif ? Theme.of(context).colorScheme.primary : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: Icon(
                        Icons.access_time_filled,
                        color: _geciciHatirlatmalarAktif ? Theme.of(context).colorScheme.secondary : Colors.grey,
                      ),
                      title: const Text("Hatırlatma Saati", style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(
                        _geciciSeciliSaat.format(context),
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600,
                          color: _geciciHatirlatmalarAktif ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      ),
                      onTap: _geciciHatirlatmalarAktif ? _saatSec : null,
                      enabled: _geciciHatirlatmalarAktif,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Hatırlatmayı Ayarla"),
                    onPressed: _ayarlariKaydetVeUygula,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}