// lib/wrapper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:santiyeyonetim2/user_model.dart';
import 'package:santiyeyonetim2/ana_menu_ekrani.dart';
import 'package:santiyeyonetim2/team_gate.dart';
import 'package:santiyeyonetim2/login_or_register.dart';
import 'package:santiyeyonetim2/firestore_servisi.dart';
import 'package:santiyeyonetim2/izin_kontrol_ekrani.dart';
import 'package:santiyeyonetim2/profil_tamamlama_ekrani.dart'; // Yeni ekranımızı import ettik

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    // 1. Durum: Kullanıcı giriş yapmamış (Auth state null).
    if (user == null) {
      debugPrint("Wrapper: User null, Login/Register'a yönlendiriliyor.");
      return const LoginOrRegister();
    } 
    
    // 2. Durum: Kullanıcı giriş yapmış (Auth state mevcut).
    // Firestore'dan profil durumunu anlık olarak dinle.
    else {
      debugPrint("Wrapper: User mevcut (UID: ${user.uid}). Firestore profili dinleniyor...");
      
      return StreamBuilder<DocumentSnapshot>(
        // Firestore servisindeki mevcut stream fonksiyonunu kullanıyoruz.
        stream: FirestoreServisi(kullaniciId: user.uid).getKullaniciVeriStream(),
        builder: (context, snapshot) {
          
          // Veri beklenirken yükleniyor animasyonu göster.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // Bir hata oluşursa göster.
          if (snapshot.hasError) {
            debugPrint("🔥 Wrapper: Firestore stream HATA: ${snapshot.error}");
            return const Scaffold(body: Center(child: Text("Bir hata oluştu! Lütfen tekrar deneyin.")));
          }

          // Auth işlemi olmuş ama Firestore'da kullanıcı belgesi henüz oluşturulmamışsa
          // (örneğin kayıt işleminde bir hata sonrası), profili tamamlamaya yönlendir.
          if (!snapshot.hasData || !snapshot.data!.exists) {
            debugPrint("Wrapper: Kullanıcı Firestore'da bulunamadı! ProfilTamamlamaEkrani'na yönlendiriliyor.");
            return const ProfilTamamlamaEkrani();
          }

          // Veri geldiyse, Map formatına çevir.
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          
          // 'username' alanı var mı ve dolu mu diye kontrol et.
          final String? username = userData['username'];

          // 3. Durum: Profil bilgisi eksikse, tamamlama ekranına yönlendir.
          if (username == null || username.isEmpty) {
            debugPrint("Wrapper: Kullanıcı profili eksik ('username' alanı yok/boş). ProfilTamamlamaEkrani'na yönlendiriliyor.");
            return const ProfilTamamlamaEkrani();
          }
          
          // 4. Durum: Profil tamamlanmışsa, ekip ID'sini kontrol et.
          else {
            final String? teamId = userData['teamId'];

            if (teamId != null && teamId.isNotEmpty) {
              debugPrint("✅ Wrapper: Profil tamamlanmış, Ekip ID'si bulundu ($teamId). AnaMenuEkrani'na yönlendiriliyor.");
              // IzinKontrolEkrani'nı kaldırdım çünkü ana menüye giden zaten izinlidir diye varsaydım.
              // Eğer hala lazımsa, `return IzinKontrolEkrani(child: AnaMenuEkrani(...));` şeklinde kullanabilirsiniz.
              return AnaMenuEkrani(teamId: teamId);
            } else {
              debugPrint("Wrapper: Profil tamamlanmış, Ekip ID'si bulunamadı. TeamGate'e yönlendiriliyor.");
              return const TeamGate();
            }
          }
        },
      );
    }
  }
}