import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Kullanıcı başına günlük AI istek limiti.
/// Firestore'da users/{uid}/ai_usage/{tarih} dokümanı tutulur.
/// Tamamen ücretsiz tier kapsamında çalışır.
class AiRateLimiter {
  static const int _dailyLimit = 10; // Kullanıcı başına günlük max AI sorusu
  static final _db = FirebaseFirestore.instance;

  /// İstek yapılabilir mi kontrol et ve sayacı artır.
  /// [true] döndürürse devam et, [false] döndürürse limit aşıldı.
  static Future<RateLimitResult> checkAndIncrement() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        // Oturum açılmamışsa dahi misafir olarak geçici izin ver (kullanıcıyı engelleme)
        return const RateLimitResult(
          allowed: true,
          remaining: 5,
          reason: 'guest',
        );
      }

      final today = _todayKey();
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('ai_usage')
          .doc(today);

      // Transaction ile atomik okuma/yazma
      return await _db.runTransaction<RateLimitResult>((tx) async {
        final snap = await tx.get(docRef);

        int count = 0;
        if (snap.exists) {
          count = (snap.data()?['count'] as int?) ?? 0;
        }

        if (count >= _dailyLimit) {
          return RateLimitResult(
            allowed: false,
            remaining: 0,
            reason: 'limit_exceeded',
          );
        }

        // Sayacı artır
        tx.set(docRef, {
          'count': count + 1,
          'date': today,
          'lastUsed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return RateLimitResult(
          allowed: true,
          remaining: _dailyLimit - count - 1,
          reason: 'ok',
        );
      });
    } catch (e) {
      // Firestore hatası durumunda izin ver (kullanıcıyı engelleme)
      return RateLimitResult(
        allowed: true,
        remaining: _dailyLimit,
        reason: 'error_bypass',
      );
    }
  }

  /// Bugünün kullanım durumunu getir (ekranda göstermek için)
  static Future<int> getRemainingToday() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;
      final snap =
          await _db
              .collection('users')
              .doc(uid)
              .collection('ai_usage')
              .doc(_todayKey())
              .get();
      final used = (snap.data()?['count'] as int?) ?? 0;
      return (_dailyLimit - used).clamp(0, _dailyLimit);
    } catch (_) {
      return _dailyLimit;
    }
  }

  static int get dailyLimit => _dailyLimit;

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future getStatus() async {}
}

class RateLimitResult {
  final bool allowed;
  final int remaining;
  final String reason;
  final int limit;

  const RateLimitResult({
    required this.allowed,
    required this.remaining,
    required this.reason,
    this.limit = AiRateLimiter._dailyLimit,
  });
}
