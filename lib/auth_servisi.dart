import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_servisi.dart';
import 'firebase_options.dart';
import 'user_model.dart';

class AuthServisi {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        kIsWeb
            ? null
            : (defaultTargetPlatform == TargetPlatform.iOS
                ? DefaultFirebaseOptions.ios.iosClientId
                : null),
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userFromFirebaseUser(User? user) {
    return user != null ? UserModel(uid: user.uid) : null;
  }

  Stream<UserModel?> get userStream {
    return _auth.userChanges().map(_userFromFirebaseUser);
  }

  UserModel? get currentUser => _userFromFirebaseUser(_auth.currentUser);

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

  /// Apple ile Giriş Yap (Yalnızca iOS cihazlarda kullanılır)
  Future<UserModel?> signInWithApple() async {
    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      final UserCredential userCredential = await _auth.signInWithProvider(
        appleProvider,
      );
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
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
    // 1. FCM token temizliğini arka planda çalıştır (UI'ı asla bekletmez)
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FcmServisi().kullaniciAyril().timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => null,
        );
      }
    } catch (e) {
      debugPrint("FCM token temizleme hatası: $e");
    }

    // 2. Google oturumu: Yalnızca kullanıcı gerçekten Google sağlayıcısı ile giriş yaptıysa kapat
    if (!kIsWeb) {
      try {
        final currentUser = _auth.currentUser;
        final isGoogleUser =
            currentUser?.providerData.any(
              (p) => p.providerId == 'google.com',
            ) ??
            false;

        if (isGoogleUser) {
          final isGSignedIn = await _googleSignIn.isSignedIn().timeout(
            const Duration(milliseconds: 500),
            onTimeout: () => false,
          );
          if (isGSignedIn) {
            await _googleSignIn.signOut().timeout(
              const Duration(seconds: 1),
              onTimeout: () => null,
            );
          }
        }
      } catch (e) {
        debugPrint("GoogleSignIn signOut hatası (güvenle yoksayıldı): $e");
      }
    }

    // 3. Firebase Auth oturumunu her koşulda mutlaka kapat (asla donmaz)
    try {
      await _auth.signOut().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint("FirebaseAuth signOut kritik hata: $e");
      rethrow;
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

  /// Kullanıcının hesabını ve Firestore kullanıcı kaydını kalıcı olarak siler (Apple App Store 5.1.1(v) uyumlu)
  Future<void> hesabiVeVerileriSil({String? parola}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı oturumu bulunamadı.");

    final uid = user.uid;

    // 1. Gerekirse şifre ile Re-Auth yap
    if (parola != null && parola.isNotEmpty && user.email != null) {
      try {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: parola,
        );
        await user.reauthenticateWithCredential(cred);
      } catch (e) {
        throw Exception("Mevcut şifrenizi yanlış girdiniz.");
      }
    } else {
      final isGoogleUser = user.providerData.any(
        (p) => p.providerId == 'google.com',
      );
      if (isGoogleUser) {
        try {
          final googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final cred = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(cred);
          }
        } catch (_) {}
      }
    }

    // 2. Kullanıcı verisini yedekle (Auth silme başarısız olursa geri yüklemek için)
    Map<String, dynamic>? backupData;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        backupData = userDoc.data();
      }
    } catch (_) {}

    // 3. FCM Token ve Firestore kullanıcı profil kaydını temizle
    try {
      await FcmServisi().kullaniciAyril();
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint("Firestore kullanıcı verisi silme uyarısı: $e");
    }

    // 4. Firebase Authentication'dan kullanıcıyı kalıcı olarak sil
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Auth silme başarısız olduysa Firestore dokümanını hemen geri yükle!
      if (backupData != null) {
        try {
          await _firestore.collection('users').doc(uid).set(backupData);
        } catch (_) {}
      }
      if (e.code == 'requires-recent-login') {
        throw Exception("requires-recent-login");
      }
      throw Exception("Hesap silinemedi: ${e.message}");
    } catch (e) {
      if (backupData != null) {
        try {
          await _firestore.collection('users').doc(uid).set(backupData);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
