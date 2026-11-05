// lib/wrapper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:santiyeyonetim2/ana_menu_ekrani.dart';
import 'package:santiyeyonetim2/firestore_servisi.dart';
import 'package:santiyeyonetim2/profil_tamamlama_ekrani.dart';
import 'package:santiyeyonetim2/team_gate.dart';
import 'package:santiyeyonetim2/widgets/acilis_animasyon_ekrani.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key, required this.userId});

  final String userId;

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  late Stream<DocumentSnapshot> _userDocStream;
  DocumentSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant Wrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _lastSnapshot = null;
      _initStream();
    }
  }

  void _initStream() {
    _userDocStream =
        FirestoreServisi(kullaniciId: widget.userId).getKullaniciVeriStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userDocStream,
      initialData: _lastSnapshot,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          _lastSnapshot = snapshot.data;
        }

        // Eğer henüz hiçbir veri gelmediyse ve önbellek de yoksa
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastSnapshot == null) {
          return const AcilisYuklemeEkrani();
        }

        if (snapshot.hasError && _lastSnapshot == null) {
          debugPrint("Wrapper: Firestore stream HATA: ${snapshot.error}");
          return const Scaffold(
            body: Center(child: Text("Bir hata oluştu! Lütfen tekrar deneyin.")),
          );
        }

        final currentSnap = snapshot.data ?? _lastSnapshot;
        if (currentSnap == null || !currentSnap.exists) {
          return const ProfilTamamlamaEkrani();
        }

        final userData = currentSnap.data() as Map<String, dynamic>;
        final String? username = userData['username'];

        if (username == null || username.isEmpty) {
          return const ProfilTamamlamaEkrani();
        }

        final String? teamId = userData['teamId'];

        if (teamId != null && teamId.isNotEmpty) {
          return AnaMenuEkrani(
            key: ValueKey('ana_menu_$teamId'),
            teamId: teamId,
          );
        }

        return const TeamGate();
      },
    );
  }
}
