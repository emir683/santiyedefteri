import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


class IzinKontrolEkrani extends StatefulWidget {
  // YENİ: İzinler tamsa gösterilecek olan widget.
  final Widget child; 
  const IzinKontrolEkrani({super.key, required this.child});

  @override
  State<IzinKontrolEkrani> createState() => _IzinKontrolEkraniState();
}

class _IzinKontrolEkraniState extends State<IzinKontrolEkrani> {
  PermissionStatus? _bildirimDurumu;
  PermissionStatus? _alarmDurumu;

  @override
  void initState() {
    super.initState();
    _izinleriKontrolEt();
  }

  Future<void> _izinleriKontrolEt() async {
    final statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm,
    ].request();
    
    if (mounted) {
      setState(() {
        _bildirimDurumu = statuses[Permission.notification];
        _alarmDurumu = statuses[Permission.scheduleExactAlarm];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // İzin durumu hala kontrol ediliyorsa, bekleme ekranı göster.
    if (_bildirimDurumu == null || _alarmDurumu == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Gerekli izinler verilmişse, 'child' widget'ı (AnaMenuEkrani) göster.
    if (_bildirimDurumu!.isGranted && _alarmDurumu!.isGranted) {
  return widget.child;
}
    
    // İzinler verilmemişse, izin isteme ekranını göster.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80),
              const SizedBox(height: 24),
              const Text('Uygulama İzinleri Gerekli', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Hatırlatmaların ve bildirimlerin düzgün çalışabilmesi için bu izinlere ihtiyacımız var.', textAlign: TextAlign.center),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  // Ayarlar sayfasını açarak kullanıcının manuel izin vermesini sağla.
                  await openAppSettings();
                },
                child: const Text('Ayarları Aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}