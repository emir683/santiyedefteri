// lib/rol_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum UserRole { kurucu, yonetici, uye }

class RolProvider with ChangeNotifier {
  UserRole _rol = UserRole.uye;
  String _teamId = '';
  String _kullaniciId = '';
  bool _isPersonal = false;

  UserRole get rol => _rol;
  bool get isPersonal => _isPersonal;

  bool get isFinansalErisim =>
      _rol == UserRole.kurucu || _rol == UserRole.yonetici;

  bool get isKurucu => _rol == UserRole.kurucu;

  bool get isYonetici => _rol == UserRole.yonetici || _rol == UserRole.kurucu;

  String get rolAdi {
    switch (_rol) {
      case UserRole.kurucu:
        return 'Kurucu';
      case UserRole.yonetici:
        return 'Yönetici';
      case UserRole.uye:
        return 'Üye';
    }
  }

  void baslat(String teamId, String kullaniciId) {
    if (_teamId == teamId && _kullaniciId == kullaniciId) return;
    _teamId = teamId;
    _kullaniciId = kullaniciId;
    _dinle();
  }

  void _dinle() {
    FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;
          final data = snap.data() as Map<String, dynamic>;

          // Eski ekipler için otomatik migration: yoneticiler alanı yoksa ekle
          if (!data.containsKey('yoneticiler')) {
            FirebaseFirestore.instance.collection('teams').doc(_teamId).update({
              'yoneticiler': [],
            });
            return; // Snapshot tekrar gelecek, kurucu olarak işlenecek
          }

          final String kurucuUid = data['kurucu'] ?? '';
          final List<String> yoneticiler = List<String>.from(
            data['yoneticiler'] ?? [],
          );
          final bool personal = data['isPersonal'] ?? false;

          UserRole yeniRol;
          if (_kullaniciId == kurucuUid) {
            yeniRol = UserRole.kurucu;
          } else if (yoneticiler.contains(_kullaniciId)) {
            yeniRol = UserRole.yonetici;
          } else {
            yeniRol = UserRole.uye;
          }

          if (yeniRol != _rol || personal != _isPersonal) {
            _rol = yeniRol;
            _isPersonal = personal;
            notifyListeners();
          }
        });
  }

  void sifirla() {
    _rol = UserRole.uye;
    _teamId = '';
    _kullaniciId = '';
    _isPersonal = false;
    notifyListeners();
  }
}
