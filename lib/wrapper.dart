// lib/wrapper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:santiyeyonetim2/ana_menu_ekrani.dart';
import 'package:santiyeyonetim2/firestore_servisi.dart';
import 'package:santiyeyonetim2/profil_tamamlama_ekrani.dart';
import 'package:santiyeyonetim2/team_gate.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "Wrapper: User mevcut (UID: $userId). Firestore profili dinleniyor...",
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreServisi(kullaniciId: userId).getKullaniciVeriStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint("Wrapper: Firestore stream HATA: ${snapshot.error}");
          return const Scaffold(
            body: Center(child: Text("Bir hata olustu! Lutfen tekrar deneyin.")),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint(
            "Wrapper: Kullanici Firestore'da bulunamadi. Profil tamamlamaya yonlendiriliyor.",
          );
          return const ProfilTamamlamaEkrani();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String? username = userData['username'];

        if (username == null || username.isEmpty) {
          debugPrint(
            "Wrapper: Kullanici profili eksik. Profil tamamlamaya yonlendiriliyor.",
          );
          return const ProfilTamamlamaEkrani();
        }

        final String? teamId = userData['teamId'];

        if (teamId != null && teamId.isNotEmpty) {
          debugPrint(
            "Wrapper: Profil tamam, ekip bulundu ($teamId). Ana menu aciliyor.",
          );
          return AnaMenuEkrani(teamId: teamId);
        }

        debugPrint("Wrapper: Profil tamam, ekip bulunamadi. TeamGate aciliyor.");
        return const TeamGate();
      },
    );
  }
}
