import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class IzinKontrolEkrani extends StatefulWidget {
  final Widget child;
  const IzinKontrolEkrani({super.key, required this.child});

  @override
  State<IzinKontrolEkrani> createState() => _IzinKontrolEkraniState();
}

class _IzinKontrolEkraniState extends State<IzinKontrolEkrani> {
  bool _kontrolTamamlandi = false;

  @override
  void initState() {
    super.initState();
    _izinleriKontrolEt();
  }

  Future<void> _izinleriKontrolEt() async {
    try {
      await Permission.notification.request();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _kontrolTamamlandi = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_kontrolTamamlandi) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Apple App Store kuralları gereği bildirim izni reddedilse bile uygulama kilitlenmez.
    return widget.child;
  }
}