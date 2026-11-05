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
  // GÜVENLIK: API anahtarı kaynak kodda saklanmaz.
  // Yeni anahtar oluşturduktan sonra Firebase Remote Config veya
  // setApiKey() metodu aracılığıyla runtime'da inject edilmelidir.
  // https://aistudio.google.com/apikey
  static String _apiKey = '';

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
    List<AIChatMessage> history = const [],
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
      final checker =
          _rateLimitChecker ?? (() => AiRateLimiter.checkAndIncrement());
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
        final intent = await _askGemini(
          userPrompt,
          workerNames,
          siteNames,
          history: history,
        );
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
    List<AIChatMessage> history = const [],
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
      'ekibime ekle',
    ];
    final bool isWorkerAdd =
        addWorkerKeywords.any(
          (k) => norm.contains(AkilliSesAyristirici.normalize(k)),
        ) ||
        (norm.contains('ekle') &&
            (norm.contains('usta') ||
                norm.contains('yevmiye') ||
                norm.contains('maas')));

    if (isWorkerAdd) {
      String name = '';
      double wage = 0.0;

      final wageMatch = RegExp(
        r'(\d+[\.,]?\d*)\s*(tl|lira|₺|yevmiye)',
        caseSensitive: false,
      ).firstMatch(text);
      if (wageMatch != null) {
        wage = double.tryParse(wageMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      final isciTuru =
          (norm.contains('misafir') ||
                  norm.contains('taseron') ||
                  norm.contains('gunlukcu'))
              ? 'Misafir'
              : 'Çekirdek Ekip';

      final cleaned =
          userPrompt
              .replaceAll(
                RegExp(
                  r'\b(yeni|işçi|isci|işçiyi|isciyi|personel|personeli|eleman|elemanı|çalışan|calisan|olarak|ekibime|ekibe|ekle|ekler\s*misin|ustayı|ustayi|usta|ustası|kalfayı|kalfayi|kalfa|çırak|cirak|yevmiyeli|yevmiyesi|yevmiye|günlük|gunluk|maaşı|maasi|maaş|maas|tl|lira|₺|ile|adında|adinda|isimli|adı|adi|misafir|taşeron|taseron|günlükçü|gunlukcu)\b',
                  caseSensitive: false,
                  unicode: true,
                ),
                ' ',
              )
              .replaceAll(RegExp(r'(\d+[\.,]?\d*)'), ' ')
              .replaceAll(RegExp(r'''['’`][a-zA-ZçğıöşüÇĞİÖŞÜ]+'''), '')
              .replaceAll(RegExp(r'[:,\-\.]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      if (cleaned.isNotEmpty) {
        final tokens =
            cleaned
                .split(' ')
                .map((w) => w.trim())
                .where((w) => w.length >= 2)
                .take(3)
                .map((w) {
                  final stripped = w.replaceAll(
                    RegExp(
                      r'(yı|yi|yu|yü|ya|ye|dan|den)$',
                      caseSensitive: false,
                    ),
                    '',
                  );
                  final base = stripped.length >= 2 ? stripped : w;
                  return base[0].toUpperCase() +
                      (base.length > 1 ? base.substring(1).toLowerCase() : '');
                })
                .toList();
        name = tokens.join(' ');
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
    final bool isPayment =
        (norm.contains('avans') &&
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

    // 2.5 Alınan Ödeme / Hakediş Tahsilatı Kontrolü (addReceivedPayment - AlinanOdeme)
    final bool isReceivedPayment =
        ((norm.contains('odeme') ||
                norm.contains('ödeme') ||
                norm.contains('hakedis') ||
                norm.contains('hakediş') ||
                norm.contains('tahsilat') ||
                norm.contains('kasa girisi') ||
                norm.contains('para')) &&
            (norm.contains('aldim') ||
                norm.contains('aldik') ||
                norm.contains('tahsil') ||
                norm.contains('geldi') ||
                norm.contains('yatti') ||
                norm.contains('alindi'))) ||
        (norm.contains('santiyeden') &&
            (norm.contains('odeme') ||
                norm.contains('hakedis') ||
                norm.contains('tahsilat')));

    if (isReceivedPayment) {
      final cleanNumText = text.replaceAllMapped(
        RegExp(r'(\d)\.(\d{3})\b'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
      double amount = 0.0;
      final amountMatch = RegExp(r'(\d+[\.,]?\d*)').firstMatch(cleanNumText);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      Santiye? matchedSite;
      for (final s in santiyeler) {
        if (norm.contains(AkilliSesAyristirici.normalize(s.ad))) {
          matchedSite = s;
          break;
        }
      }
      matchedSite ??= (santiyeler.isNotEmpty ? santiyeler.first : null);

      final siteName = matchedSite?.ad ?? 'Merkez Şantiye';
      final siteId = matchedSite?.id ?? '';

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.addReceivedPayment,
        title: 'Alınan Ödeme / Hakediş Onayı',
        description: 'Şantiyeden alınan ödeme kaydı hazırlandı.',
        data: {
          'santiye_id': siteId,
          'santiyeAdi': siteName,
          'site': siteName,
          'odemeYapan': 'İşveren / Hakediş Tahsilatı',
          'amount': amount > 0 ? amount : 25000.0,
          'miktar': amount > 0 ? amount : 25000.0,
        },
      );

      return AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text:
            '💵 **$siteName** için alınan hakediş / ödeme kaydı hazırlandı. Bilgileri düzenleyebilir veya onaylayabilirsiniz:',
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
      String siteName =
          userPrompt
              .replaceAll(
                RegExp(
                  r'(yeni|şantiye|santiye|proje|ekle)',
                  caseSensitive: false,
                ),
                ' ',
              )
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
    final workerTargetMatch = isciler.any(
      (w) => norm.contains(AkilliSesAyristirici.normalize(w.ad)),
    );
    final bool isWorkerWord =
        norm.contains('isci') ||
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

    final bool isWorkerSummaryKeywords =
        norm.contains('ozet') ||
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
        (norm.contains('avans') &&
            !norm.contains('verdim') &&
            !norm.contains('ver') &&
            !norm.contains('yaz')) ||
        (norm.contains('puantaj') &&
            (norm.contains('goster') ||
                norm.contains('nasil') ||
                norm.contains('durum') ||
                norm.contains('bu ay') ||
                norm.contains('ne') ||
                norm.contains('ay'))) ||
        (norm.contains('calisti') &&
            (norm.contains('kac') ||
                norm.contains('kaç') ||
                norm.contains('bu ay') ||
                norm.contains('ne kadar')));

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
        'Aralık',
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
      double toplamGun = 0.0;
      for (final r in allReports) {
        for (final c in r.calisanlar) {
          if (c.isci.ad.trim().toLowerCase() ==
                  targetWorker.ad.trim().toLowerCase() ||
              (targetWorker.id != null && c.isci.id == targetWorker.id)) {
            final carpan = parseDurumCarpani(c.durum);
            toplamGun += carpan;
            if (c.durum.contains('Tam') || c.durum.contains('Mesai')) {
              tamGun++;
            } else if (c.durum.contains('Yar')) {
              yarimGun++;
            }
          }
        }
      }
      final toplamHakedis = toplamGun * targetWorker.gunlukMaas;

      double toplamAvans = 0.0;
      for (final a in allAdvances) {
        if (a.isci.ad.trim().toLowerCase() ==
                targetWorker.ad.trim().toLowerCase() ||
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
    final siteTargetMatch = santiyeler.any(
      (s) => norm.contains(AkilliSesAyristirici.normalize(s.ad)),
    );
    final bool isSiteWord =
        norm.contains('santiye') ||
        norm.contains('şantiye') ||
        norm.contains('proje') ||
        norm.contains('santiyeler') ||
        norm.contains('şantiyeler') ||
        siteTargetMatch;

    final bool isSiteSummaryKeywords =
        norm.contains('ozet') ||
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
        'Aralık',
      ];
      final donem = '${aylar[now.month]} ${now.year}';

      List<GunlukSantiyeRaporu> allReports = [];
      List<AlinanOdeme> allPayments = [];
      if (servisi != null && teamId.isNotEmpty) {
        allReports = await servisi.getAylikRaporlarOnce(teamId, now);
        allPayments = await servisi.getAylikOdemelerOnce(teamId, now);
      }

      final siteReports =
          allReports
              .where(
                (r) =>
                    r.santiyeAdi.trim().toLowerCase() ==
                    targetSite.ad.trim().toLowerCase(),
              )
              .toList();
      final sitePayments =
          allPayments
              .where(
                (p) =>
                    p.santiyeAdi.trim().toLowerCase() ==
                    targetSite.ad.trim().toLowerCase(),
              )
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
          final carpan = parseDurumCarpani(c.durum);
          toplamYevmiyeCount += carpan;
          toplamIscilikMaliyeti += (c.isci.gunlukMaas * carpan);
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
    final bool isDailyLog =
        norm.contains('puantaj') ||
        norm.contains('rapor') ||
        norm.contains('calisti') ||
        norm.contains('gelmedi') ||
        norm.contains('yarim gun') ||
        (norm.contains('ekip') && norm.contains('tam'));

    if (isDailyLog) {
      Santiye targetSite =
          santiyeler.isNotEmpty
              ? santiyeler.first
              : Santiye(ad: 'Merkez Şantiye');
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

      final yemekMatch =
          RegExp(
            r'(\d+[\.,]?\d*)\s*(tl|lira|₺)?\s*(yemek)',
            caseSensitive: false,
          ).firstMatch(text) ??
          RegExp(
            r'(yemek)\s*(\d+[\.,]?\d*)',
            caseSensitive: false,
          ).firstMatch(text);
      if (yemekMatch != null) {
        yemek =
            double.tryParse(
              (yemekMatch.group(1) == 'yemek'
                      ? yemekMatch.group(2)
                      : yemekMatch.group(1))!
                  .replaceAll(',', '.'),
            ) ??
            0;
      }

      final benzinMatch =
          RegExp(
            r'(\d+[\.,]?\d*)\s*(tl|lira|₺)?\s*(benzin|yakıt|mazot)',
            caseSensitive: false,
          ).firstMatch(text) ??
          RegExp(
            r'(benzin|yakıt|mazot)\s*(\d+[\.,]?\d*)',
            caseSensitive: false,
          ).firstMatch(text);
      if (benzinMatch != null) {
        benzin =
            double.tryParse(
              (['benzin', 'yakıt', 'mazot'].contains(benzinMatch.group(1))
                      ? benzinMatch.group(2)
                      : benzinMatch.group(1))!
                  .replaceAll(',', '.'),
            ) ??
            0;
      }

      final ekMasrafMatch =
          RegExp(
            r'(\d+[\.,]?\d*)\s*(tl|lira|₺)?\s*(ek\s*masraf|malzeme|nalbur|hırdavat|hirdavat|diğer|diger)',
            caseSensitive: false,
          ).firstMatch(text) ??
          RegExp(
            r'(ek\s*masraf|malzeme|nalbur|hırdavat|hirdavat|diğer|diger)\s*(\d+[\.,]?\d*)',
            caseSensitive: false,
          ).firstMatch(text);
      if (ekMasrafMatch != null) {
        final rawEk =
            RegExp(r'^\d').hasMatch(ekMasrafMatch.group(1) ?? '')
                ? ekMasrafMatch.group(1)!
                : (ekMasrafMatch.group(2) ?? '0');
        ekMasraf = double.tryParse(rawEk.replaceAll(',', '.')) ?? 0;
      }

      final bool isYesterday =
          norm.contains('dun ') ||
          norm.contains('dunku') ||
          norm.endsWith('dun');
      final now = DateTime.now();
      final reportDate =
          isYesterday
              ? DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 1))
              : DateTime(now.year, now.month, now.day);

      final card = AIActionCardData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AIActionType.submitDailyLog,
        title:
            isYesterday
                ? 'Dünkü Şantiye Raporu (${reportDate.day}.${reportDate.month}.${reportDate.year})'
                : 'Günlük Şantiye Raporu',
        description: 'Puantaj ve masraflar hazırlandı.',
        data: {
          'santiye_id': targetSite.id ?? '',
          'site': targetSite.ad,
          'santiyeAdi': targetSite.ad,
          'tarih': reportDate.toIso8601String(),
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
            '📋 **${targetSite.ad}** için ${isYesterday ? 'dünkü' : 'günlük'} rapor ve puantaj kartı oluşturuldu:',
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
      history: history,
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

    if (_m(text, [
      'yeni işçi',
      'işçi ekle',
      'yeni isci',
      'isci ekle',
      'personel ekle',
    ])) {
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
    List<String> siteNames, {
    List<AIChatMessage> history = const [],
  }) async {
    final santiyeContext =
        siteNames.isNotEmpty
            ? 'Aktif şantiyeler: ${siteNames.join(', ')}. '
            : '';
    final isciContext =
        workerNames.isNotEmpty
            ? 'Kayıtlı ekip personelleri: ${workerNames.join(', ')}. '
            : '';

    final systemInstruction =
        'Sen ŞPD (Şantiye Puantaj Defteri) uygulamasının uzman yapay zeka asistanı ve tecrübeli bir inşaat mühendisisin. '
        '$santiyeContext$isciContext'
        'Şantiye yönetimi, inşaat tekniği, TS 500 / TBDY 2018 standartları, statik, malzeme özellikleri (beton, demir, harç, tuğla, yalıtım vb.), '
        'iş güvenliği ve şantiye organizasyonu konularında profesyonel, doğru ve net cevaplar verirsin. '
        'Türkçe, samimi, anlaşılır ve yapıcı bir dille yanıt ver. Gerekirse maddeler ve emojiler kullan.';

    final recentHistory =
        history.length > 6 ? history.sublist(history.length - 6) : history;
    final contents = <Map<String, dynamic>>[
      for (final msg in recentHistory)
        if (msg.text.trim().isNotEmpty)
          {
            'role': msg.isUser ? 'user' : 'model',
            'parts': [
              {'text': msg.text},
            ],
          },
      {
        'role': 'user',
        'parts': [
          {'text': userPrompt},
        ],
      },
    ];

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1200},
    });

    final models = [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-flash-latest',
    ];

    for (final m in models) {
      try {
        final response = await http
            .post(
              Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$_apiKey',
              ),
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
            return AIIntent(action: 'chat_response', message: text, params: {});
          }
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('Gemini yanıt veremedi');
  }

  // ═══════════════════════════════════════════════════════
  // LOCAL FALLBACK & ÇEVRİMDIŞI İNŞAAT BİLGİ BANKASI
  // ═══════════════════════════════════════════════════════
  static AIIntent _localFallback(String original, {bool isError = false}) {
    final text = original.toLowerCase();
    final norm = AkilliSesAyristirici.normalize(text);

    if (_m(text, [
      'merhaba',
      'selam',
      'günaydın',
      'iyi günler',
      'kolay gelsin',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message:
            '👋 Merhaba! Sizi dinliyorum. İnşaat teknik soruları, malzeme metrajı veya puantaj/avans işlemleri için bana danışabilirsiniz.',
        params: {},
      );
    }

    // 1. Beton dökümü öncesi kontrol listesi
    if ((norm.contains('beton') &&
            (norm.contains('dokum') ||
                norm.contains('oncesi') ||
                norm.contains('dikkat') ||
                norm.contains('kontrol'))) &&
        !norm.contains('priz') &&
        !norm.contains('dayanim')) {
      return AIIntent(
        action: 'chat_response',
        message: '''🏗️ **Beton Dökümü Öncesi Kritik Saha Kontrol Listesi**

1. **Kalıp & İskele Kontrolü**
• Kalıp dikmeleri, payandalar ve kama bağlantıları sağlam mı?
• Kalıp içi talaş, toz ve yabancı maddelerden temizlenip kalıp yağı sürüldü mü?
• Kalıp sızdırmazlığı ve şakul/terazi kotları kontrol edildi mi?

2. **Donatı (Demir) & Paspayı Kontrolü**
• Projeye uygun donatı çapı, adedi, etriye sıklaştırması ve kanca açıları (135°) tamam mı?
• **Paspayı takozları** (temelde ~5 cm, kolon/kirişte 2.5–3 cm, döşemede 2 cm) eksiksiz yerleştirildi mi?
• Tesisat geçişleri ve rezervasyon boşlukları bırakıldı mı?

3. **Lojistik & Ekipman Hazırlığı**
• **En az 2 adet vibratör** (1 asıl + 1 yedek) çalışır durumda hazır mı?
• Hava durumuna göre naylon örtü, antifriz veya kürleme suyu hazırlandı mı?

4. **Taze Beton Kabulü**
• İrsaliyedeki beton sınıfı (örn. C30/37), kıvam sınıfı (S3/S4) ve santral çıkış saati kontrol edilmeli.
• Numune küpleri ve **Slump (Çökme) deneyleri** yapı denetim eşliğinde alınmalıdır. *(Kesinlikle miksere sahada su eklenmemelidir!)*''',
        params: {},
      );
    }

    // 2. C25 / C30 / C35 Beton Dayanımı, Priz Alma ve Kürleme Süreleri
    if (norm.contains('c25') ||
        norm.contains('c30') ||
        norm.contains('c35') ||
        norm.contains('priz') ||
        (norm.contains('beton') &&
            (norm.contains('dayanim') ||
                norm.contains('kurleme') ||
                norm.contains('sulama') ||
                norm.contains('ozellik')))) {
      return AIIntent(
        action: 'chat_response',
        message: '''🧪 **C30/37 Beton Dayanımı, Priz Alma ve Kürleme Rehberi**

• **Karakteristik Basınç Dayanımı (TS EN 206):**
  - **15×30 cm Silindir Dayanımı:** minimum **30 MPa** (30 N/mm²)
  - **15×15×15 cm Küp Dayanımı:** minimum **37 MPa** (37 N/mm²)

• **Priz Alma ve Dayanım Kazanma Süreleri:**
  - **Priz Başlangıcı:** Dökümden sonra yaklaşık **1.5 – 3 saat** (sıcaklığa bağlı)
  - **Priz Sonu (Üzerinde yürünebilme):** **6 – 10 saat**
  - **7 Günlük Dayanım:** Nihai dayanımın yaklaşık **%65 – %70**'ine ulaşır (~25–27 MPa küp)
  - **28 Günlük Standart Dayanım:** Tasarım dayanımının **%100**'üne ulaşır (≥37 MPa küp)

• **Kürleme (Sulama) Kuralları:**
  - İlk sulama priz tamamlandıktan sonra (yazın 3–4 saat sonra) göllendirme veya yağmurlama ile başlamalıdır.
  - **En az 7 gün** boyunca sabah ve akşam düzenli kürleme yapılmalı, beton yüzeyi nemli tutulmalıdır.''',
        params: {},
      );
    }

    // 3. Demir Donatı Bindirme Boyu, Etriye ve Paspayı Kuralları
    if (norm.contains('paspayi') ||
        norm.contains('pas payi') ||
        norm.contains('bindirme') ||
        norm.contains('etriye') ||
        (norm.contains('demir') && norm.contains('donati'))) {
      return AIIntent(
        action: 'chat_response',
        message:
            '''📏 **Demir Donatı Bindirme Boyu & Paspayı Kuralları (TS 500 / TBDY 2018)**

1. **Minimum Net Beton Örtüsü (Paspayı):**
• **Temeller (Toprakla temaslı):** 5.0 cm (50 mm)
• **Kolon, Kiriş ve Perdeler:** 2.5 – 3.0 cm (Dış cephede 3.5 cm)
• **Döşemeler ve İç Duvarlar:** 1.5 – 2.0 cm

2. **Bindirme (Ek) Boyu (l₀):**
• B420C nervürlü demir ve C30 beton için pratik saha kuralı olarak bindirme boyu ortalama **45Ø – 55Ø** (çapın 50 katı) alınır:
  - **Ø12 demir:** ~60 cm
  - **Ø14 demir:** ~70 cm
  - **Ø16 demir:** ~80 cm
  - **Ø20 demir:** ~100 cm
• Kolon boyuna donatı bindirmeleri kolonun **orta üçte birlik (L/3) bölgesinde** yapılmalı ve bindirme boyunca etriyeler sıklaştırılmalıdır.

3. **Etriye & Çiroz Kuralları:**
• Tüm etriye ve çiroz kancaları **135° deprem kancası** olmalı, kanca uç boyu en az **10Ø (veya ≥7.5 cm)** çekirdek içine dönmelidir.''',
        params: {},
      );
    }

    // 4. Kalıp Söküm Süreleri
    if (norm.contains('kalip') &&
        (norm.contains('sokum') ||
            norm.contains('ne zaman') ||
            norm.contains('kac gun'))) {
      return AIIntent(
        action: 'chat_response',
        message:
            '''🪵 **Standart Kalıp Söküm Süreleri (TS 500 - Normal Portland Çimentosu)**

*(Ortalama ortam sıcaklığı +5°C üzerinde olduğunda)*
• **Kiriş Yanları, Kolon ve Perde Yan Kalıpları:** **2 – 3 Gün**
• **Döşeme Alt Kalıpları (Dikmeler hariç):** **7 – 10 Gün**
• **Kiriş Alt Kalıpları (Dikmeler hariç):** **14 Gün**
• **Döşeme ve Kiriş Altı Taşıyıcı Dikmeler (Payandalar):** **21 – 28 Gün**

⚠️ **Önemli:** Don olaylarının yaşandığı günlerde (+5°C altı) geçen süreler kalıp söküm süresine **eklenmelidir**.''',
        params: {},
      );
    }

    // 5. İSG / İş Güvenliği ve Risk Kontrol Listesi
    if (_m(text, [
      'isg',
      'iş güvenliği',
      'is guvenligi',
      'kask',
      'önlem',
      'kaza',
      'risk',
      'baret',
    ])) {
      return AIIntent(
        action: 'chat_response',
        message: '''⛑️ **Şantiye İş Güvenliği (İSG) ve Risk Kontrol Listesi**

1. **Kişisel Koruyucu Donanım (KKD)**
• Sahadaki tüm personelde **EN 397 baret**, **reflektörlü yelek**, **çelik burunlu/tabanlı iş ayakkabısı** ve işe uygun eldiven zorunludur.
• Yüksekte çalışmalarda **çift lanyardlı paraşüt tipi emniyet kemeri** yaşam hattına bağlı olmalıdır.

2. **Yüksekte Çalışma & Kenar Koruma**
• Kat boşlukları, asansör kuyuları, merdiven kovaları ve dış cephe kenarları **110 cm yüksekliğinde korkuluk + 15 cm topuk levhası** ve güvenlik ağı ile kapatılmalıdır.
• İskeleler TSE belgeli olmalı, her katta tam yürüme platformu ve bina ankrajı bulunmalıdır.

3. **Elektrik & Makine Güvenliği**
• Tüm şantiye panolarında **30 mA Kaçak Akım Rölesi** aktif olmalı, kablolar yerden/sudan yüksekte askıya alınmalıdır.
• Kule vinç, mikser ve pompa operasyonlarında işaretçi (bayrakçı) bulundurulmalı, bom altında personel durmamalıdır.

4. **Kazı & Hafriyat Güvenliği**
• 1.50 m'yi aşan kazılarda **iksa / kademeli şev** uygulanmalı ve kazı kenarına güvenli mesafede bariyer çekilmelidir.''',
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
          '🤔 Sorunuzu tam anlayamadım.\n\n💡 Kullanabileceğiniz örnekler:\n• "C30 beton dayanımı ve priz alma süreleri"\n• "350 m2 tabliyeye 15 cm kaç mikser beton gider?"\n• "Ali\'ye 2000 TL avans verdim"\n• "Kadıköy şantiyesinden 50000 TL ödeme aldık"\n• "Yeni işçi ekle: Ahmet Kaya 2000 TL"\n• "Bugün bütün ekip tam gün çalıştı"',
      params: {},
    );
  }

  static bool _m(String text, List<String> kws) =>
      kws.any((k) => text.contains(k));

  static void dispose() {}
}
