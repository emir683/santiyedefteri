import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data_models.dart';
import '../../firestore_servisi.dart';
import '../../models/ai_action_model.dart';
import '../../models/ai_intent.dart';
import '../../akilli_ses_ayristirici.dart';
import 'ai_rate_limiter.dart';
import 'insaat_metraj_hesaplayici.dart';

/// Hibrit AI Servisi:
/// - Komutlar (onay kartları, özetler, puantaj): Kural tabanlı NLP — anlık, ücretsiz, hata yok
/// - Genel sorular (inşaat, teknik, serbest chat): Gemini API — gerçek yapay zeka
///   → Gemini çağrıları Firestore rate limiter ile korunur (kullanıcı başına günlük 10 istek)
class AIService {
  // Google AI Studio'dan ücretsiz alınan Gemini API key
  // https://aistudio.google.com/apikey → ücretsiz, kredi kartı gerekmez
  static String _apiKey = 'AIzaSyC992EgeKcQQLCJkGCsB_m5HHDEn2q9twI';

  static bool get _geminiEnabled =>
      _apiKey.startsWith('AIzaSy') && _apiKey.length > 20;

  // Rate limit checker injection (widget'tan set edilir)
  static Future<RateLimitResult> Function()? _rateLimitChecker;

  static void setRateLimitChecker(Future<RateLimitResult> Function() checker) {
    _rateLimitChecker = checker;
  }

  static void setApiKey(String key) {
    _apiKey = key;
  }

  static Future<void> initialize(String modelPath) async {
    // Kural tabanlı NLP - model yüklemesi gerekmez
  }

  static bool get isReady => true;

  static Future<AIIntent> processPrompt(
    String userPrompt, {
    List<String> workerNames = const [],
    List<String> siteNames = const [],
  }) async {
    final text = userPrompt.toLowerCase().trim();

    // ── ÖNCE: Akıllı İnşaat Metraj & Malzeme Hesaplayıcı (Rate limit yok, anlık, çevrimdışı) ──
    final metrajResult = InsaatMetrajHesaplayici.hesapla(userPrompt);
    if (metrajResult != null) {
      return AIIntent(
        action: 'chat_response',
        message: metrajResult,
        params: {},
      );
    }

    // ── Kural tabanlı komut tespiti (rate limit yok, her zaman ücretsiz) ──
    final commandIntent = _detectCommand(
      text,
      userPrompt,
      workerNames,
      siteNames,
    );
    if (commandIntent != null) return commandIntent;

    // ── SONRA: Genel soru → Rate limit kontrolü → Gemini API ──
    if (_geminiEnabled) {
      final checker = _rateLimitChecker ?? (() => AiRateLimiter.checkAndIncrement());
      final limitResult = await checker();
      if (!limitResult.allowed) {
        if (limitResult.reason == 'login_required') {
          return AIIntent(
            action: 'chat_response',
            message: '🔒 AI sohbet özelliği için giriş yapmanız gereklidir.',
            params: {},
          );
        }
        return AIIntent(
          action: 'chat_response',
          message:
              '⏳ Günlük AI soru limitinize ulaştınız (${limitResult.limit}/${limitResult.limit}).\n\nYarın tekrar kullanabilirsiniz. Komutlar (rapor, yönlendirme, metraj) her zaman ücretsiz çalışır! 😊',
          params: {},
        );
      }

      try {
        final intent = await _askGemini(userPrompt, workerNames, siteNames);
        // Kalan hak sayısını mesaja ekle
        if (limitResult.remaining <= 3 && limitResult.remaining >= 0) {
          final msg =
              '${intent.message}\n\n_💡 Günlük AI hakkınız: ${limitResult.remaining} kaldı_';
          return AIIntent(
            action: intent.action,
            message: msg,
            params: intent.params,
          );
        }
        return intent;
      } catch (e) {
        return _localFallback(userPrompt, isError: true);
      }
    }

    // ── API yoksa: akıllı yerel yanıt ──
    return _localFallback(userPrompt);
  }

  /// Sohbet akışında mesajları ve aksiyon kartlarını üreten metod
  static Future<AIChatMessage> processChatMessage(
    String userPrompt, {
    List<String> workerNames = const [],
    List<String> siteNames = const [],
    List<Isci> isciler = const [],
    List<Santiye> santiyeler = const [],
    String teamId = '',
    FirestoreServisi? servisi,
  }) async {
    final text = userPrompt.toLowerCase().trim();
    final norm = AkilliSesAyristirici.normalize(text);

    // 0. Akıllı İnşaat Metraj ve Malzeme Hesaplayıcı (Gemini'ye gitmez, 100% deterministik & limitsiz)
    final metrajModel = InsaatMetrajHesaplayici.hesaplaModel(userPrompt);
    if (metrajModel != null) {
      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.materialCalculation,
        title: metrajModel.title,
        description: metrajModel.ozetBilgi,
        status: AIActionStatus.confirmed,
        data: metrajModel.toMap(),
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '🧱 **${metrajModel.title}** hesaplandı. Ölçüleri ve birim fiyatı aşağıdaki karttan dilediğiniz gibi değiştirip anında yeniden hesaplayabilirsiniz:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    final metrajMesaj = InsaatMetrajHesaplayici.hesapla(userPrompt);
    if (metrajMesaj != null) {
      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: metrajMesaj,
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // 1. İşçi Ekleme Kontrolü (addWorker)
    final addWorkerKeywords = [
      'isci ekle',
      'isciyi ekle',
      'iscisi ekle',
      'personel ekle',
      'calisan ekle',
      'eleman ekle',
      'yeni isci',
      'yeni personel',
      'ekibime ekle'
    ];
    final bool isWorkerAdd = addWorkerKeywords
            .any((k) => norm.contains(AkilliSesAyristirici.normalize(k))) ||
        (norm.contains('ekle') &&
            (norm.contains('usta') ||
                norm.contains('yevmiye') ||
                norm.contains('maas')));

    if (isWorkerAdd) {
      String name = '';
      double wage = 0.0;

      final wageMatch =
          RegExp(r'(\d+[\.,]?\d*)\s*(tl|lira|₺|yevmiye)', caseSensitive: false)
              .firstMatch(text);
      if (wageMatch != null) {
        wage =
            double.tryParse(wageMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      final isciTuru = (norm.contains('misafir') ||
              norm.contains('taseron') ||
              norm.contains('gunlukcu'))
          ? 'Misafir'
          : 'Çekirdek Ekip';

      final cleaned = userPrompt
          .replaceAll(
              RegExp(
                  r'(yeni|işçi|isci|personel|eleman|olarak|ekle|usta|ustası|kalfa|çırak|yevmiye|maaş|tl|lira|₺|\d+)',
                  caseSensitive: false),
              ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        name = cleaned.split(' ').first;
        if (name.isNotEmpty) {
          name = name[0].toUpperCase() +
              (name.length > 1 ? name.substring(1) : '');
        }
      }
      if (name.isEmpty) name = 'Yeni Personel';

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.addWorker,
        title: 'Yeni Personel Ekle',
        description: 'Personel bilgileri doğrulandı.',
        data: {
          'ad': name,
          'name': name,
          'isciTuru': isciTuru,
          'gunlukMaas': wage > 0 ? wage : 1500.0,
          'wage': wage > 0 ? wage : 1500.0,
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '👷 **$name** isimli personeli ($isciTuru) ekibine eklemek için onay kartı hazırlandı:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 2. Avans Kontrolü (addPayment - VerilenAvans)
    final bool isPayment = (norm.contains('avans') &&
            (norm.contains('ver') ||
                norm.contains('yaz') ||
                norm.contains('ekle') ||
                norm.contains('yaptim') ||
                norm.contains('verdim') ||
                norm.contains('girdim'))) ||
        norm.contains('para ver') ||
        norm.contains('yevmiye ver');
    if (isPayment) {
      double amount = 0.0;
      final amountMatch = RegExp(r'(\d+[\.,]?\d*)').firstMatch(text);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      Isci? matchedWorker;
      for (final isci in isciler) {
        if (norm.contains(AkilliSesAyristirici.normalize(isci.ad))) {
          matchedWorker = isci;
          break;
        }
      }

      if (matchedWorker == null && isciler.isNotEmpty) {
        matchedWorker = isciler.first;
      }

      final workerName = matchedWorker?.ad ?? 'Personel Seçiniz';
      final workerId = matchedWorker?.id ?? '';

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.addPayment,
        title: 'Avans Kaydı Onayı',
        description: 'Personele verilen avans kaydı hazırlandı.',
        data: {
          'worker_id': workerId,
          'worker': workerName,
          'amount': amount > 0 ? amount : 500.0,
          'miktar': amount > 0 ? amount : 500.0,
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '💰 **$workerName** için avans kaydı hazırlandı. Listeden personeli değiştirebilir veya onaylayabilirsiniz:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 3. Şantiye Ekleme Kontrolü (addSite)
    final bool isSiteAdd =
        (norm.contains('santiye') || norm.contains('proje')) &&
            norm.contains('ekle');
    if (isSiteAdd) {
      String siteName = userPrompt
          .replaceAll(
              RegExp(r'(yeni|şantiye|santiye|proje|ekle)',
                  caseSensitive: false),
              ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (siteName.isEmpty) siteName = 'Yeni Şantiye';

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.addSite,
        title: 'Yeni Şantiye Ekle',
        description: 'Şantiye kaydı hazırlandı.',
        data: {
          'ad': siteName,
          'name': siteName,
          'il': 'İstanbul',
          'city': 'İstanbul',
          'ilce': '',
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '🏗️ **$siteName** projesini eklemek için hazır. Lütfen onaylayın:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 4. İşçi Aylık Özeti Kontrolü (workerMonthlySummary)
    final workerTargetMatch = isciler.any((w) => norm.contains(AkilliSesAyristirici.normalize(w.ad)));
    final bool isWorkerWord = norm.contains('isci') ||
        norm.contains('işçi') ||
        norm.contains('personel') ||
        norm.contains('calisan') ||
        norm.contains('çalışan') ||
        norm.contains('usta') ||
        norm.contains('kalfa') ||
        norm.contains('cirak') ||
        norm.contains('çırak') ||
        norm.contains('eleman') ||
        norm.contains('yevmiyeci') ||
        workerTargetMatch;

    final bool isWorkerSummaryKeywords = norm.contains('ozet') ||
        norm.contains('özet') ||
        norm.contains('aylik') ||
        norm.contains('aylık') ||
        norm.contains('hakedis') ||
        norm.contains('hakediş') ||
        norm.contains('ne kadar') ||
        norm.contains('kac gun') ||
        norm.contains('kaç gün') ||
        norm.contains('alacak') ||
        norm.contains('bakiye') ||
        norm.contains('maas') ||
        norm.contains('maaş') ||
        norm.contains('durum') ||
        norm.contains('kac para') ||
        norm.contains('kaç para') ||
        norm.contains('ne alacak') ||
        norm.contains('hesabi') ||
        norm.contains('hesabı') ||
        norm.contains('hesap dokumu') ||
        norm.contains('hesap dökümü') ||
        norm.contains('kac yevmiye') ||
        norm.contains('kaç yevmiye') ||
        norm.contains('kalan para') ||
        norm.contains('avansi ne kadar') ||
        norm.contains('avansı ne kadar') ||
        (norm.contains('avans') && !norm.contains('verdim') && !norm.contains('ver') && !norm.contains('yaz')) ||
        (norm.contains('puantaj') && (norm.contains('goster') || norm.contains('nasil') || norm.contains('durum') || norm.contains('bu ay') || norm.contains('ne') || norm.contains('ay'))) ||
        (norm.contains('calisti') && (norm.contains('kac') || norm.contains('kaç') || norm.contains('bu ay') || norm.contains('ne kadar')));

    final bool isWorkerSummary = isWorkerWord && isWorkerSummaryKeywords;

    if (isWorkerSummary && isciler.isNotEmpty) {
      Isci targetWorker = isciler.first;
      for (final i in isciler) {
        if (norm.contains(AkilliSesAyristirici.normalize(i.ad))) {
          targetWorker = i;
          break;
        }
      }

      final now = DateTime.now();
      const aylar = [
        '',
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık'
      ];
      final donem = '${aylar[now.month]} ${now.year}';

      List<GunlukSantiyeRaporu> allReports = [];
      List<VerilenAvans> allAdvances = [];
      if (servisi != null && teamId.isNotEmpty) {
        allReports = await servisi.getAylikRaporlarOnce(teamId, now);
        allAdvances = await servisi.getAylikAvanslarOnce(teamId, now);
      }

      int tamGun = 0;
      int yarimGun = 0;
      for (final r in allReports) {
        for (final c in r.calisanlar) {
          if (c.isci.ad.trim().toLowerCase() == targetWorker.ad.trim().toLowerCase() ||
              (targetWorker.id != null && c.isci.id == targetWorker.id)) {
            if (c.durum == 'Tam Gün') {
              tamGun++;
            } else if (c.durum == 'Yarım Gün') {
              yarimGun++;
            }
          }
        }
      }

      final toplamGun = tamGun + (yarimGun * 0.5);
      final toplamHakedis = toplamGun * targetWorker.gunlukMaas;

      double toplamAvans = 0.0;
      for (final a in allAdvances) {
        if (a.isci.ad.trim().toLowerCase() == targetWorker.ad.trim().toLowerCase() ||
            (targetWorker.id != null && a.isci.id == targetWorker.id)) {
          toplamAvans += a.miktar;
        }
      }

      final kalanAlacak = toplamHakedis - toplamAvans;

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.workerMonthlySummary,
        title: '${targetWorker.ad} - Aylık Puantaj & Hakediş',
        description: '$donem Çalışma ve Bakiye Durumu',
        status: AIActionStatus.confirmed,
        data: {
          'worker_name': targetWorker.ad,
          'worker_role': targetWorker.isciTuru,
          'period': donem,
          'daily_wage': targetWorker.gunlukMaas,
          'full_days': tamGun,
          'half_days': yarimGun,
          'total_days': toplamGun,
          'total_earned': toplamHakedis,
          'total_advance': toplamAvans,
          'net_balance': kalanAlacak,
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '👤 **${targetWorker.ad}** için $donem dönemi puantaj, hak ediş ve avans dökümü hazırlandı:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 5. Şantiye Aylık Özeti Kontrolü (siteMonthlySummary)
    final siteTargetMatch = santiyeler.any((s) => norm.contains(AkilliSesAyristirici.normalize(s.ad)));
    final bool isSiteWord = norm.contains('santiye') ||
        norm.contains('şantiye') ||
        norm.contains('proje') ||
        norm.contains('santiyeler') ||
        norm.contains('şantiyeler') ||
        siteTargetMatch;

    final bool isSiteSummaryKeywords = norm.contains('ozet') ||
        norm.contains('özet') ||
        norm.contains('aylik') ||
        norm.contains('aylık') ||
        norm.contains('durum') ||
        norm.contains('harca') ||
        norm.contains('masraf') ||
        norm.contains('maliyet') ||
        norm.contains('gider') ||
        norm.contains('hakedis') ||
        norm.contains('hakediş') ||
        norm.contains('ne kadar') ||
        norm.contains('gelir') ||
        norm.contains('kasa') ||
        norm.contains('bakiye') ||
        norm.contains('hesabi') ||
        norm.contains('hesabı') ||
        norm.contains('rapor') ||
        norm.contains('kac para') ||
        norm.contains('kaç para') ||
        norm.contains('ne harcandi') ||
        norm.contains('ne harcandı') ||
        norm.contains('bilanco') ||
        norm.contains('bilanço') ||
        norm.contains('kac yevmiye') ||
        norm.contains('kaç yevmiye') ||
        norm.contains('calisma suresi') ||
        norm.contains('çalışma süresi');

    final bool isSiteSummary = isSiteWord && isSiteSummaryKeywords;

    if (isSiteSummary && santiyeler.isNotEmpty) {
      Santiye targetSite = santiyeler.first;
      for (final s in santiyeler) {
        if (norm.contains(AkilliSesAyristirici.normalize(s.ad))) {
          targetSite = s;
          break;
        }
      }

      final now = DateTime.now();
      const aylar = [
        '',
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık'
      ];
      final donem = '${aylar[now.month]} ${now.year}';

      List<GunlukSantiyeRaporu> allReports = [];
      List<AlinanOdeme> allPayments = [];
      if (servisi != null && teamId.isNotEmpty) {
        allReports = await servisi.getAylikRaporlarOnce(teamId, now);
        allPayments = await servisi.getAylikOdemelerOnce(teamId, now);
      }

      final siteReports = allReports
          .where((r) =>
              r.santiyeAdi.trim().toLowerCase() ==
              targetSite.ad.trim().toLowerCase())
          .toList();
      final sitePayments = allPayments
          .where((p) =>
              p.santiyeAdi.trim().toLowerCase() ==
              targetSite.ad.trim().toLowerCase())
          .toList();

      double toplamYemek = 0.0;
      double toplamBenzin = 0.0;
      double toplamEkMasraf = 0.0;
      double toplamYevmiyeCount = 0.0;
      double toplamIscilikMaliyeti = 0.0;

      for (final r in siteReports) {
        toplamYemek += r.yemekGideri;
        toplamBenzin += r.benzinGideri;
        toplamEkMasraf += r.ekMasraflar;
        for (final c in r.calisanlar) {
          if (c.durum == 'Tam Gün') {
            toplamYevmiyeCount += 1.0;
            toplamIscilikMaliyeti += c.isci.gunlukMaas;
          } else if (c.durum == 'Yarım Gün') {
            toplamYevmiyeCount += 0.5;
            toplamIscilikMaliyeti += (c.isci.gunlukMaas * 0.5);
          }
        }
      }

      double toplamGelir = 0.0;
      for (final p in sitePayments) {
        toplamGelir += p.miktar;
      }
      final double toplamGider =
          toplamYemek + toplamBenzin + toplamEkMasraf + toplamIscilikMaliyeti;

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.siteMonthlySummary,
        title: '${targetSite.ad} - Aylık Özet',
        description: '$donem Harcama ve İş Gücü Durumu',
        status: AIActionStatus.confirmed,
        data: {
          'site_name': targetSite.ad,
          'period': donem,
          'total_work_days': toplamYevmiyeCount,
          'labor_cost': toplamIscilikMaliyeti,
          'fuel_cost': toplamBenzin,
          'food_cost': toplamYemek,
          'extra_cost': toplamEkMasraf,
          'total_expense': toplamGider,
          'total_income': toplamGelir,
          'net_balance': toplamGelir - toplamGider,
          'report_count': siteReports.length,
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '🏗️ **${targetSite.ad}** şantiyesinin $donem dönemi harcama ve puantaj özeti hazırlandı:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 6. Günlük Rapor / Puantaj Kontrolü (submitDailyLog)
    final bool isDailyLog = norm.contains('puantaj') ||
        norm.contains('rapor') ||
        norm.contains('calisti') ||
        norm.contains('gelmedi') ||
        norm.contains('yarim gun') ||
        (norm.contains('ekip') && norm.contains('tam'));

    if (isDailyLog) {
      Santiye targetSite = santiyeler.isNotEmpty ? santiyeler.first : Santiye(ad: 'Merkez Şantiye');
      for (final s in santiyeler) {
        if (norm.contains(AkilliSesAyristirici.normalize(s.ad))) {
          targetSite = s;
          break;
        }
      }

      final ayristirilan = AkilliSesAyristirici.ayristirIsciler(
        metin: userPrompt,
        isciler: isciler,
      );

      final Map<String, String> isciDurumlari = {};
      for (var i in isciler) {
        final key = i.id ?? i.ad;
        if (ayristirilan.containsKey(i.ad)) {
          isciDurumlari[key] = ayristirilan[i.ad]!;
        } else {
          isciDurumlari[key] = 'Tam Gün';
        }
      }

      double yemek = 0;
      double benzin = 0;
      double ekMasraf = 0;

      final yemekMatch = RegExp(r'(\d+[\.,]?\d*)\s*(tl|lira|₺)?\s*(yemek)',
                  caseSensitive: false)
              .firstMatch(text) ??
          RegExp(r'(yemek)\s*(\d+[\.,]?\d*)', caseSensitive: false)
              .firstMatch(text);
      if (yemekMatch != null) {
        yemek = double.tryParse(
                (yemekMatch.group(1) == 'yemek'
                        ? yemekMatch.group(2)
                        : yemekMatch.group(1))!
                    .replaceAll(',', '.')) ??
            0;
      }

      final benzinMatch = RegExp(
                  r'(\d+[\.,]?\d*)\s*(tl|lira|₺)?\s*(benzin|yakıt|mazot)',
                  caseSensitive: false)
              .firstMatch(text) ??
          RegExp(r'(benzin|yakıt|mazot)\s*(\d+[\.,]?\d*)',
                  caseSensitive: false)
              .firstMatch(text);
      if (benzinMatch != null) {
        benzin = double.tryParse(
                (['benzin', 'yakıt', 'mazot'].contains(benzinMatch.group(1))
                        ? benzinMatch.group(2)
                        : benzinMatch.group(1))!
                    .replaceAll(',', '.')) ??
            0;
      }

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.submitDailyLog,
        title: 'Günlük Şantiye Raporu',
        description: 'Puantaj ve masraflar hazırlandı.',
        data: {
          'santiye_id': targetSite.id ?? '',
          'site': targetSite.ad,
          'santiyeAdi': targetSite.ad,
          'isci_durumlari': isciDurumlari,
          'workers_summary': '${isciDurumlari.length} personel puantajda',
          'expenses_summary': [
            if (yemek > 0) 'Yemek: $yemek ₺',
            if (benzin > 0) 'Benzin: $benzin ₺',
            if (ekMasraf > 0) 'Ek Masraf: $ekMasraf ₺',
          ].join(', '),
          'yemek': yemek,
          'benzin': benzin,
          'ek_masraf': ekMasraf,
          'yemekGideri': yemek,
          'benzinGideri': benzin,
          'ekMasraflar': ekMasraf,
          'aciklama': 'ŞPD AI ile oluşturuldu.',
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '📋 **${targetSite.ad}** için günlük rapor ve puantaj kartı oluşturuldu:',
        isUser: false,
        timestamp: DateTime.now(),
        actionCard: card,
      );
    }

    // 7. Standart AI Sohbet / Gemini / Intent
    final intent = await processPrompt(
      userPrompt,
      workerNames: workerNames,
      siteNames: siteNames,
    );

    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: intent.message,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // KURAL TABANLI KOMUT TESPİTİ
  // ═══════════════════════════════════════════════════════
  static AIIntent? _detectCommand(
    String text,
    String original,
    List<String> workerNames,
    List<String> siteNames,
  ) {
    // 0. Özel: Emir & Beyza
    if (text.contains('emir') && text.contains('beyza')) {
      final beyzaFirst = text.indexOf('beyza') < text.indexOf('emir');
      if (beyzaFirst) {
        return AIIntent(
          action: 'chat_response',
          message: 'Emir kadar olamaz tabii ki de! 😉🦩',
          params: {},
        );
      } else {
        return AIIntent(
          action: 'chat_response',
          message: 'Emir Beyza\'yı çoook seviyor, ona çok aşık! 🦩❤️',
          params: {},
        );
      }
    }

    // 1. Sohbet: Adın ne / Sen kimsin
    if (_m(text, [
      'adın ne',
      'adin ne',
      'ismin ne',
      'sen kimsin',
      'sen nesin',
      'sana ne diyeyim',
      'sana nasıl hitap',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '🤖 Benim adım **ŞPD AI**! Şantiye Puantaj Defteri\'nin akıllı sesli asistanıyım. Puantaj tutma, işçi/şantiye yönetimi ve raporlama işlemlerinizde her zaman yanınızdayım.',
        params: {},
      );
    }

    // 2. Sohbet: Geliştiricin kim
    if (_m(text, [
      'geliştiricin kim',
      'gelistiricin kim',
      'seni kim yaptı',
      'seni kim yapti',
      'seni kim geliştirdi',
      'seni kim gelistirdi',
      'yapımcın kim',
      'yapimcin kim',
      'kim üretti',
      'sahibin kim',
      'geliştirici kim',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '👷‍♂️ Ben Emir Çiftci tarafından, şantiyelerdeki puantaj ve yönetim süreçlerinizi en hızlı, pratik ve hatasız şekilde yürütmeniz için özel olarak geliştirildim!',
        params: {},
      );
    }

    // 3. Sohbet: Nasılsın
    if (_m(text, [
      'nasılsın',
      'nasilsin',
      'nasıl gidiyor',
      'nasil gidiyor',
      'ne haber',
      'naber',
      'iyi misin',
      'iyi misiniz',
      'keyifler nasıl',
      'ne var ne yok',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '😊 Harikayım, teşekkürler! Şantiyenizde işlerin yolunda gitmesi için her zaman göreve hazırım. Bugün size nasıl yardımcı olabilirim?',
        params: {},
      );
    }

    // 4. Sohbet: Kaç yaşındasın
    if (_m(text, [
      'kaç yaşındasın',
      'kac yasindasin',
      'yaşın kaç',
      'yasin kac',
      'ne zaman doğdun',
      'dogum tarihin',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '⚡ Dijital bir yapay zeka asistanı olduğum için bir yaşım yok, ancak sürekli öğreniyor ve şantiyenize en güncel teknolojilerle yardımcı olmaya devam ediyorum!',
        params: {},
      );
    }

    // 5. Sohbet: Selamlaşma
    if (_m(text, [
      'günaydın',
      'gunaydin',
      'iyi günler',
      'iyi gunler',
      'tünaydın',
      'iyi akşamlar',
      'iyi aksamlar',
      'merhaba',
      'selam',
      'selamlar',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '☀️ Merhaba! Şantiyenizde bereketli, kazasız ve verimli bir gün dilerim. Rapor girmek veya işlem yapmak için hazırım!',
        params: {},
      );
    }

    // 6. Sohbet: Teşekkür & Övgü
    if (_m(text, [
      'teşekkür',
      'tesekkur',
      'sağol',
      'sagol',
      'eline sağlık',
      'eline saglik',
      'harikasın',
      'harikasin',
      'süpersin',
      'adamsın',
      'helal',
      'tesekkur ederim',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            'Rica ederim, ne demek! 😊 Şantiyenizdeki işlerinizin her zaman rast gitmesi dileğiyle, yardıma ihtiyacınız olursa buradayım.',
        params: {},
      );
    }

    // 7. Sohbet: Kolay gelsin
    if (_m(text, [
      'kolay gelsin',
      'iyi çalışmalar',
      'iyi calismalar',
      'bereketli olsun',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '🏗️ Çok teşekkür ederim! Size ve sahadaki tüm ustalarımıza, işçi arkadaşlarımıza kolaylıklar ve güvenli çalışmalar dilerim.',
        params: {},
      );
    }

    // 8. Sohbet: Vedalaşma
    if (_m(text, [
      'görüşürüz',
      'gorusuruz',
      'hoşça kal',
      'hosca kal',
      'güle güle',
      'gule gule',
      'kapat',
      'bay bay',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '👋 Görüşmek üzere! İhtiyacınız olduğunda butona basarak bana her zaman seslenebilirsiniz. İyi çalışmalar!',
        params: {},
      );
    }

    // 9. Yardım & Neler Yapabilirsin
    if (_m(text, [
      'neler yapabilir',
      'ne yapabilir',
      'yardım',
      'yardim',
      'komutlar',
      'özellikler',
      'ozellikler',
      'help',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message: '''🤖 **ŞPD AI ile Neler Yapabilirsiniz?**

📊 **Aylık Özetler & Raporlama**
• "Şantiyenin bu ayki harcama ve puantaj özeti" *(Canlı maliyet ve bakiye dökümü)*
• "Ali ustanın bu ayki hakediş ve avans durumu" *(Net hakediş ve kalan alacak kartı)*

📋 **Günlük Rapor & Puantaj**
• "Bugünkü puantajı işle" *(Onay kartı hazırlar)*
• "Ali tam gün, Veli yarım gün çalıştı, 500 ₺ mazot" *(Otomatik ayrıştırır ve karta doldurur)*

👷 **Yeni İşçi Ekleme**
• "Ali ustayı 1.500 ₺ yevmiye ile ekle" *(Personel onay kartı açar)*

🏗️ **Yeni Şantiye Ekleme**
• "Kadıköy Konakları şantiyesini ekle" *(Proje kartı oluşturur)*

💰 **Avans & Ödemeler**
• "Ahmet ustaya 2.000 ₺ avans verdim" *(Avans onay kartı sunar)*

💬 **Teknik Danışmanlık & Sohbet**
• "Beton dökümü öncesi nelere dikkat edilmeli?" veya dilediğiniz inşaat sorusu!''',
        params: {},
      );
    }

    // 2. Günlük rapor / Puantaj
    if (_m(text, [
      'günlük rapor',
      'gunluk rapor',
      'puantaj',
      'rapor gir',
      'rapor ekle',
      'rapor oluştur',
      'mesai gir',
      'çalışma gir',
      'işçi gir',
      'isci gir',
    ])) {
      return AIIntent(
        action: 'submit_daily_log',
        message: '📋 Günlük puantaj ve rapor kartınız hazırlandı.',
        params: {},
      );
    }

    if (_m(text, ['yeni işçi', 'işçi ekle', 'yeni isci', 'isci ekle', 'personel ekle'])) {
      return AIIntent(
        action: 'add_worker',
        message: '👷 Yeni işçi ekleme onay kartınız hazırlandı.',
        params: {},
      );
    }

    if (_m(text, [
      'yeni şantiye',
      'şantiye ekle',
      'yeni santiye',
      'santiye ekle',
      'proje ekle',
    ])) {
      return AIIntent(
        action: 'add_site',
        message: '🏗️ Yeni şantiye ekleme onay kartınız hazırlandı.',
        params: {},
      );
    }

    if (_m(text, [
      'avans gir',
      'avans ekle',
      'avans ver',
      'ödeme ekle',
      'ödeme gir',
      'odeme gir',
    ])) {
      return AIIntent(
        action: 'add_payment',
        message: '💰 Avans ve ödeme onay kartınız hazırlandı.',
        params: {},
      );
    }
    // Komut bulunamadı
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // GEMİNİ API
  // ═══════════════════════════════════════════════════════
  static Future<AIIntent> _askGemini(
    String userPrompt,
    List<String> workerNames,
    List<String> siteNames,
  ) async {
    const systemInstruction =
        'Sen ŞPD (Şantiye Puantaj Defteri) uygulamasının uzman yapay zeka asistanı ve tecrübeli bir inşaat mühendisisin. '
        'Şantiye yönetimi, inşaat tekniği, statik, malzeme özellikleri (beton, demir, harç, tuğla, yalıtım vb.), '
        'iş güvenliği ve şantiye organizasyonu konularında profesyonel, doğru ve net cevaplar verirsin. '
        'Türkçe, samimi, anlaşılır ve yapıcı bir dille yanıt ver. Gerekirse maddeler ve emojiler kullan.';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        {
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1200},
    });

    final models = [
      'gemini-3.5-flash-lite',
      'gemini-3.5-flash',
      'gemini-3.8-flash',
      'gemini-3.6-flash',
      'gemini-flash-latest',
    ];

    for (final m in models) {
      try {
        final response = await http
            .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$_apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final text =
              json['candidates']?[0]?['content']?['parts']?[0]?['text']
                  as String? ??
              '';
          if (text.isNotEmpty) {
            return AIIntent(
              action: 'chat_response',
              message: text,
              params: {},
            );
          }
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('Gemini yanıt veremedi');
  }

  // ═══════════════════════════════════════════════════════
  // LOCAL FALLBACK
  // ═══════════════════════════════════════════════════════
  static AIIntent _localFallback(String original, {bool isError = false}) {
    final text = original.toLowerCase();
    if (_m(text, ['merhaba', 'selam', 'günaydın', 'iyi günler', 'kolay gelsin'])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '👋 Merhaba! Sizi dinliyorum. İnşaat teknik soruları, malzeme metrajı veya puantaj/avans işlemleri için bana danışabilirsiniz.',
        params: {},
      );
    }
    if (_m(text, ['isg', 'iş güvenliği', 'kask', 'önlem', 'kaza', 'risk'])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '⛑️ İSG için 6331 sayılı İş Sağlığı ve Güvenliği Kanunu geçerlidir. Şantiyede baret, yelek ve emniyet kemeri kullanımı zorunludur.',
        params: {},
      );
    }
    if (isError) {
      return AIIntent(
        action: 'chat_response',
        message:
            '⚠️ Yapay zeka servisine bağlanırken geçici bir gecikme oluştu. Lütfen internet bağlantınızı kontrol edip sorunuzu tekrar gönderin.',
        params: {},
      );
    }
    return AIIntent(
      action: 'chat_response',
      message:
          '🤔 Sorunuzu tam anlayamadım.\n\n💡 Kullanabileceğiniz örnekler:\n• "C30 beton özellikleri nelerdir?"\n• "350 m2 tabliyeye kaç mikser beton gider?"\n• "Ali\'ye 500 TL avans ver"\n• "Yeni işçi ekle: Ahmet 1500 TL"\n• "Kadıköy şantiyesine puantaj gir"',
      params: {},
    );
  }

  static bool _m(String text, List<String> kws) =>
      kws.any((k) => text.contains(k));

  static void dispose() {}
}
