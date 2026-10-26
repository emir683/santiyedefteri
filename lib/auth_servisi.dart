import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Kullanıcının parola sağlayıcısı olup olmadığını döndürür (Sosyal giriş kontrolü)
  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  // E-posta VEYA Kullanıcı Adı ile Giriş
  Future<UserModel?> signInWithEmailOrUsername(
    String emailOrUsername,
    String password,
  ) async {
    try {
      String email = emailOrUsername.trim();
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

  // Kayıt olurken ek bilgileri de kaydeder
  Future<UserModel?> createUserWithEmailAndPassword(
    String email,
    String password,
    String adSoyad,
    String username,
  ) async {
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
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'username_lowercase': username.toLowerCase(),
          'adSoyad': adSoyad,
          'email': email,
        });
      }
      return _userFromFirebaseUser(user);
    } catch (e) {
      rethrow;
    }
  }

  // Google ile giriş yapıldığında profilin tam olup olmadığını kontrol eder ve ilk bilgileri kalıcı saklar
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
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          final String displayName = (user.displayName ?? '').trim();
          await _firestore.collection('users').doc(user.uid).set({
            if (displayName.isNotEmpty) 'adSoyad': displayName,
            if (user.email != null) 'email': user.email,
            'authProvider': 'google.com',
          }, SetOptions(merge: true));

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

  /// Apple ile Giriş Yap (App Store Guideline 4.0 ve 4.8 tam uyumlu)
  /// Apple yalnızca İLK girişte ad-soyad bilgisini paylaşır. Bu bilgi anında Firestore'a
  /// kaydedilir ve sonraki girişlerde kaybolması önlenir.
  Future<UserModel?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Apple'dan gelen isim bilgisini yakala (user.displayName veya additionalUserInfo veya credential)
        String resolvedName = (user.displayName ?? '').trim();
        if (resolvedName.isEmpty && appleCredential.givenName != null) {
          resolvedName =
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim();
        }
        if (resolvedName.isEmpty) {
          final profile = userCredential.additionalUserInfo?.profile;
          if (profile != null) {
            final given =
                (profile['given_name'] ??
                        profile['firstName'] ??
                        (profile['name'] is Map
                            ? profile['name']['firstName']
                            : null) ??
                        '')
                    .toString()
                    .trim();
            final family =
                (profile['family_name'] ??
                        profile['lastName'] ??
                        (profile['name'] is Map
                            ? profile['name']['lastName']
                            : null) ??
                        '')
                    .toString()
                    .trim();
            resolvedName = '$given $family'.trim();
          }
        }

        if (resolvedName.isNotEmpty &&
            (user.displayName == null || user.displayName!.trim().isEmpty)) {
          try {
            await user.updateDisplayName(resolvedName);
          } catch (_) {}
        }

        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final existingData = userDoc.data();
        final existingAdSoyad =
            (existingData?['adSoyad'] as String?)?.trim() ?? '';
        final existingUsername =
            (existingData?['username'] as String?)?.trim() ?? '';

        // Apple ilk girişte gelen adSoyad ve e-posta bilgisini hemen Firestore'a kaydet
        final String finalAdSoyad =
            existingAdSoyad.isNotEmpty
                ? existingAdSoyad
                : (resolvedName.isNotEmpty ? resolvedName : 'Apple Kullanıcısı');

        await _firestore.collection('users').doc(user.uid).set({
          'adSoyad': finalAdSoyad,
          if (user.email != null && user.email!.isNotEmpty) 'email': user.email,
          'authProvider': 'apple.com',
        }, SetOptions(merge: true));

        if (!userDoc.exists || existingUsername.isEmpty) {
          return UserModel(
            uid: user.uid,
            isProfileComplete: false,
            googleDisplayName: finalAdSoyad,
            email: user.email,
          );
        }
      }

      return _userFromFirebaseUser(user);
    } catch (e) {
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

    if (user.providerData.any(
      (userInfo) => userInfo.providerId == 'google.com',
    )) {
      throw Exception(
        "Google ile giriş yaptığınız için parolanızı Google hesabınızdan değiştirmelisiniz.",
      );
    }

    if (user.providerData.any(
      (userInfo) => userInfo.providerId == 'apple.com',
    )) {
      throw Exception(
        "Apple ile giriş yaptığınız için parolanızı Apple ID ayarlarınızdan yönetmelisiniz.",
      );
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: mevcutParola,
      );
      await user.reauthenticateWithCredential(cred);
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

  /// Kullanıcının hesabını, ekip üyeliğini ve Firestore kullanıcı kaydını kalıcı olarak siler.
  /// Apple App Store Guideline 5.1.1(v) gereği Apple ile giriş yapan kullanıcılar için
  /// yeniden kimlik doğrulama ve Apple token iptali (revokeTokenWithAuthorizationCode) gerçekleştirir.
  Future<void> hesabiVeVerileriSil({String? parola}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Kullanıcı oturumu bulunamadı.");

    final uid = user.uid;
    final isAppleUser = user.providerData.any(
      (p) => p.providerId == 'apple.com',
    );
    final isGoogleUser = user.providerData.any(
      (p) => p.providerId == 'google.com',
    );

    // 1. Sağlayıcıya göre Re-Auth ve Apple Token İptali
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
    } else if (isAppleUser) {
      try {
        final appleProvider = AppleAuthProvider();
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final reauthResult = await user.reauthenticateWithProvider(
          appleProvider,
        );
        final oauthCred = reauthResult.credential;
        if (oauthCred is OAuthCredential) {
          final authCode = oauthCred.accessToken ?? oauthCred.serverAuthCode;
          if (authCode != null && authCode.isNotEmpty) {
            try {
              await _auth.revokeTokenWithAuthorizationCode(authCode);
            } catch (revokeErr) {
              debugPrint("Apple token iptal uyarısı: $revokeErr");
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        final msgLower = (e.message ?? '').toLowerCase();
        if (e.code == 'canceled' ||
            e.code == 'cancelled' ||
            msgLower.contains('cancel') ||
            msgLower.contains('1001')) {
          throw Exception("Apple kimlik doğrulaması iptal edildi.");
        }
        debugPrint("Apple reauth uyarısı: $e");
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('cancel') || errStr.contains('1001')) {
          throw Exception("Apple kimlik doğrulaması iptal edildi.");
        }
      }
    } else if (isGoogleUser && !kIsWeb) {
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

    // 2. Kullanıcı verisini yedekle (Auth silme başarısız olursa geri yüklemek için)
    Map<String, dynamic>? backupData;
    String? activeTeamId;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        backupData = userDoc.data();
        activeTeamId = backupData?['teamId'] as String?;
      }
    } catch (_) {}

    // 3. Ekipten, FCM Token'dan ve Firestore kullanıcı profil kaydından temizle
    try {
      await FcmServisi().kullaniciAyril();
      if (activeTeamId != null && activeTeamId.isNotEmpty) {
        try {
          await _firestore.collection('teams').doc(activeTeamId).update({
            'uyeler': FieldValue.arrayRemove([uid]),
            'yoneticiler': FieldValue.arrayRemove([uid]),
          });
        } catch (_) {}
      }
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint("Firestore kullanıcı verisi silme uyarısı: $e");
    }

    // 4. Firebase Authentication'dan kullanıcıyı kalıcı olarak sil
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
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
