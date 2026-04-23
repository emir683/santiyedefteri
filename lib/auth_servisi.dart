import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class AuthServisi {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userFromFirebaseUser(User? user) {
    return user != null ? UserModel(uid: user.uid) : null;
  }

  Stream<UserModel?> get userStream {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }

  String? get currentUserEmail => _auth.currentUser?.email;

  // GÜNCELLENDİ: E-posta VEYA Kullanıcı Adı ile Giriş
  Future<UserModel?> signInWithEmailOrUsername(
    String emailOrUsername,
    String password,
  ) async {
    try {
      String email = emailOrUsername.trim();
      // Girdi bir e-posta değilse, kullanıcı adı olduğunu varsayarak Firestore'dan e-postayı bul
      if (!email.contains('@')) {
        final userQuery =
            await _firestore
                .collection('users')
                .where('username_lowercase', isEqualTo: email.toLowerCase())
                .limit(1)
                .get();

        if (userQuery.docs.isEmpty) {
          throw Exception("Kullanıcı adı bulunamadı.");
        }
        email = userQuery.docs.first.data()['email'];
      }

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _userFromFirebaseUser(result.user);
    } catch (e) {
      rethrow;
    }
  }

  // GÜNCELLENDİ: Kayıt olurken ek bilgileri de kaydeder
  Future<UserModel?> createUserWithEmailAndPassword(
    String email,
    String password,
    String adSoyad,
    String username,
  ) async {
    // Kullanıcı adının benzersiz olup olmadığını kontrol et
    final usernameQuery =
        await _firestore
            .collection('users')
            .where('username_lowercase', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();

    if (usernameQuery.docs.isNotEmpty) {
      throw Exception("Bu kullanıcı adı zaten alınmış.");
    }

    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Kullanıcıyı 'users' koleksiyonuna ek bilgilerle kaydet
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'username_lowercase':
              username.toLowerCase(), // Arama için küçük harfli versiyon
          'adSoyad': adSoyad,
          'email': email,
        });
      }
      return _userFromFirebaseUser(user);
    } catch (e) {
      rethrow;
    }
  }

  // GÜNCELLENDİ: Google ile giriş yapıldığında profilin tam olup olmadığını kontrol eder
  Future<UserModel?> signInWithGoogle() async {
    try {
      late final UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        // Bu kullanıcı 'users' koleksiyonunda var mı diye kontrol et.
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          // Eğer yoksa (yani Google ile ilk girişi ise), geçici bir UserModel döndür.
          // Bu, Wrapper'ın onu Profil Tamamlama ekranına yönlendirmesini sağlayacak.
          // Gerçek 'users' dokümanı, Profil Tamamlama ekranında oluşturulacak.
          return UserModel(
            uid: user.uid,
            isProfileComplete: false,
            googleDisplayName: user.displayName,
            email: user.email,
          );
        }
      }

      return _userFromFirebaseUser(user);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      print("Çıkış yaparken hata: ${e.toString()}");
    }
  }

  /// Şifre sıfırlama e-postası gönderir
  Future<void> sifreSifirlamaEmailiGonder(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.");
      } else if (e.code == 'invalid-email') {
        throw Exception("Geçersiz e-posta adresi.");
      } else {
        throw Exception("E-posta gönderilemedi: ${e.message}");
      }
    } catch (e) {
      throw Exception("Bir hata oluştu. Lütfen tekrar deneyin.");
    }
  }

  Future<void> kullaniciParolasiniGuncelle(
    String mevcutParola,
    String yeniParola,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı oturumu bulunamadı.");

    // Google ile giriş yapanlar parola değiştiremez (Hata vermemesi için kontrol)
    if (user.providerData.any(
      (userInfo) => userInfo.providerId == 'google.com',
    )) {
      throw Exception(
        "Google ile giriş yaptığınız için parolanızı Google hesabınızdan değiştirmelisiniz.",
      );
    }

    try {
      // 1. Önce kullanıcının mevcut parolasını doğruluyoruz (Re-Auth)
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: mevcutParola,
      );
      await user.reauthenticateWithCredential(cred);

      // 2. Doğrulama başarılıysa yeni parolayı set ediyoruz
      await user.updatePassword(yeniParola);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception("Mevcut parolanızı yanlış girdiniz.");
      } else if (e.code == 'weak-password') {
        throw Exception("Yeni parola çok zayıf.");
      } else {
        throw Exception("Parola değiştirilemedi: ${e.message}");
      }
    } catch (e) {
      rethrow;
    }
  }
}
