import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data_models.dart';
import '../akilli_ses_ayristirici.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/ai_rate_limiter.dart';

// ─────────────────────────────────────────────────────────────
// STATE MACHINE
// ─────────────────────────────────────────────────────────────
enum SpdAiState {
  idle,
  listening, // ilk dinleme
  processing, // veriyi işliyor
  askingFollowUp, // "başka bir şey var mı?" bekliyor
  listeningFollowUp, // follow-up için dinliyor
  wizardAsking, // Sihirbaz soru soruyor
  wizardListening, // Sihirbaz cevap dinliyor
  completed, // tamamlandı
}

// ─────────────────────────────────────────────────────────────
// CHAT MESSAGE MODEL
// ─────────────────────────────────────────────────────────────
enum ChatRole { ai, user }

enum ChatMsgType {
  greeting,
  liveText,
  processing,
  processStep,
  result,
  followUpQuestion,
  followUpListening,
  completed,
  error,
}

class ChatMessage {
  final ChatRole role;
  String text; // mutable — live text güncellemek için
  final ChatMsgType type;

  ChatMessage({required this.role, required this.text, required this.type});
}

// ─────────────────────────────────────────────────────────────
// TÜRKÇE CEVAP NLP
// ─────────────────────────────────────────────────────────────
class _TurkishNlp {
  static bool isEvet(String t) {
    const words = [
      'evet',
      'var',
      'ekle',
      'bir de',
      'başka',
      'olur',
      'tabii',
      'tabi',
      'elbette',
      'kesinlikle',
      'aynen',
      'tamam ekle',
      'devam',
      'sürdür',
      'daha var',
      'daha',
      'birşey daha',
      'bir şey daha',
      'söyleyeceğim',
      'söylerim',
      'söyleyeyim',
      'ekleyeyim',
      'ekleyelim',
      'evet var',
    ];
    return words.any((w) => t.contains(w));
  }

  static bool isHayir(String t) {
    const words = [
      'hayır',
      'yok',
      'bitti',
      'tamam',
      'yeter',
      'gerek yok',
      'olmaz',
      'kalsın',
      'hepsi bu',
      'hepsi bu kadar',
      'başka yok',
      'başka bir şey yok',
      'bu kadar',
      'yeterli',
      'yeterli teşekkürler',
      'teşekkürler',
      'sağol',
      'şimdilik bu kadar',
      'şimdilik tamam',
      'kapatabilirsin',
      'kapat',
      'çık',
      'çıkabilirsin',
    ];
    return words.any((w) => t.contains(w));
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────
class AkilliSesliMicWidget extends StatefulWidget {
  final List<Santiye> santiyeler;
  final List<Isci> isciler;
  final Santiye? mevcutSantiye;
  final Function(SesliPuantajSonucu sonuc) onSonuc;
  final Function(String screen)? onNavigate;
  final VoidCallback? onReportRequest;
  final Function(String wizardType, Map<String, dynamic> data)?
  onWizardComplete;

  const AkilliSesliMicWidget({
    super.key,
    required this.santiyeler,
    required this.isciler,
    this.mevcutSantiye,
    required this.onSonuc,
    this.onNavigate,
    this.onReportRequest,
    this.onWizardComplete,
  });

  @override
  State<AkilliSesliMicWidget> createState() => _AkilliSesliMicWidgetState();
}

class _AkilliSesliMicWidgetState extends State<AkilliSesliMicWidget>
    with TickerProviderStateMixin {
  // ── Speech & Audio ──
  late stt.SpeechToText _speech;
  late AudioPlayer _audioPlayer;
  bool _speechInitialized = false;
  Timer? _silenceTimer; // Hızlı ve dinamik konuşma bitişi algılayıcı

  // ── State ──
  SpdAiState _aiState = SpdAiState.idle;
  String _liveText = '';
  double _soundLevel = 0.0;
  bool _bubbleVisible = false;
  bool _isTerminating = false; // Tüm speech callback'leri bloklar
  final List<ChatMessage> _messages = [];

  // ── Wizard State ──
  String? _activeWizardType; // e.g. 'daily_report', 'add_worker', 'add_site'
  int _wizardStepIndex = 0;
  final Map<String, dynamic> _wizardData = {}; // toplanan verileri tutar

  final Map<String, List<Map<String, dynamic>>> _wizards = {
    'daily_report': [
      {
        'key': 'site',
        'question': 'Hangi şantiyenin günlük raporunu girmek istiyorsunuz?',
        'retry': 'Şantiyeyi anlayamadım, tekrar söyler misiniz?',
      },
      {
        'key': 'workers',
        'question':
            'Harika! 👍 Peki kimler çalıştı? (Ad soyad veya takma ad söyleyin)',
        'retry': 'Kimlerin çalıştığını duyamadım, tekrar söyler misiniz?',
      },
      {
        'key': 'expenses',
        'question':
            'Tamamdır! 💸 Gider veya not oldu mu? ("yok" diyebilirsiniz)',
        'retry': 'Bunu duyamadım, tekrar söyler misiniz?',
      },
    ],
    'add_worker': [
      {
        'key': 'name',
        'question': 'Yeni işçinin adı ve soyadı nedir?',
        'retry': 'İsmi duyamadım, tekrar söyler misiniz?',
      },
      {
        'key': 'role',
        'question': 'Görevi nedir? (Örn: Usta, Kalfa, Düz İşçi)',
        'retry': 'Görevi anlayamadım, tekrar eder misiniz?',
      },
      {
        'key': 'wage',
        'question': 'Günlük yevmiyesi ne kadar?',
        'retry': 'Yevmiyeyi duyamadım, sadece miktar söyler misiniz?',
      },
    ],
    'add_site': [
      {
        'key': 'name',
        'question': 'Yeni şantiyenin adı nedir?',
        'retry': 'Şantiye adını anlayamadım, tekrar eder misiniz?',
      },
      {
        'key': 'city',
        'question': 'Şantiye hangi ilde bulunuyor?',
        'retry': 'İli duyamadım, tekrar eder misiniz?',
      },
    ],
    'add_payment': [
      {
        'key': 'worker',
        'question': 'Hangi işçiye avans verilecek?',
        'retry': 'İşçinin adını anlayamadım, tekrar eder misiniz?',
      },
      {
        'key': 'amount',
        'question': 'Ne kadar avans verilecek?',
        'retry': 'Miktarı duyamadım, tekrar eder misiniz?',
      },
    ],
  };

  // ── Animation Controllers ──
  late AnimationController _pulseCtrl;
  late AnimationController _bubbleCtrl;
  late AnimationController _typingCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _followUpCtrl;
  late AnimationController _rgbRotationCtrl;
  late AnimationController _sparkleCtrl;

  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleOpacity;
  late Animation<Offset> _bubbleSlide;

  // ── Native Channel ──
  static const _nativeCh = MethodChannel(
    'com.emircf.santiyeyonetim/audio_control',
  );

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    _initAnimations();
    _initSpeech();
    // Rate limiter'ı bağla (Gemini API çağrıları için)
    AIService.setRateLimitChecker(() => AiRateLimiter.checkAndIncrement());
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _rgbRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _bubbleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bubbleCtrl,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _bubbleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut));
    _bubbleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOutCubic));

    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _followUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || _isTerminating) return;
          if (status == 'notListening' || status == 'done') {
            if (_liveText.trim().isNotEmpty) {
              _onFinalResult();
            } else if (_aiState == SpdAiState.listeningFollowUp) {
              setState(() => _aiState = SpdAiState.askingFollowUp);
            } else if (_aiState == SpdAiState.listening && !_bubbleVisible) {
              setState(() => _aiState = SpdAiState.idle);
            }
          }
        },
        onError: (_) {
          if (!mounted || _isTerminating) return;
          if (!_bubbleVisible) {
            setState(() => _aiState = SpdAiState.idle);
          }
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseCtrl.dispose();
    _rgbRotationCtrl.dispose();
    _sparkleCtrl.dispose();
    _bubbleCtrl.dispose();
    _typingCtrl.dispose();
    _waveCtrl.dispose();
    _checkCtrl.dispose();
    _followUpCtrl.dispose();
    _audioPlayer.dispose();
    _speech.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  Future<void> _mute(bool on) async {
    try {
      await _nativeCh.invokeMethod(
        on ? 'muteSystemStream' : 'unmuteSystemStream',
      );
    } catch (_) {}
  }

  Future<void> _playSound(bool isStart) async {
    try {
      await _audioPlayer.stop();
      final assets =
          isStart
              ? [
                'audio/voice_input.mp3',
                'audio/voice_input.mpeg',
                'audio/mic_start.mp3',
              ]
              : [
                'audio/vioce_output.mp3',
                'audio/vioce_output.mpeg',
                'audio/mic_stop.mp3',
              ];
      for (final a in assets) {
        try {
          await _audioPlayer.play(AssetSource(a));
          break;
        } catch (_) {}
      }
      if (isStart) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  void _addMsg(ChatRole role, String text, ChatMsgType type) {
    if (!mounted) return;
    setState(() {
      // live text → güncelle
      if (type == ChatMsgType.liveText &&
          _messages.isNotEmpty &&
          _messages.last.type == ChatMsgType.liveText) {
        _messages.last.text = text;
        return;
      }
      // downloading / loading → sadece son mesaja yazar
      if ((type == ChatMsgType.processing) &&
          _messages.isNotEmpty &&
          _messages.last.type == ChatMsgType.processing) {
        _messages.last.text = text;
        return;
      }
      if (_messages.length >= 6) _messages.removeAt(0);
      _messages.add(ChatMessage(role: role, text: text, type: type));
    });
  }

  void _openBubble() {
    if (!_bubbleVisible) {
      setState(() => _bubbleVisible = true);
      _bubbleCtrl.forward();
    }
  }

  Future<void> _closeBubble() async {
    _silenceTimer?.cancel();
    _isTerminating = true;
    _speech.stop();
    _followUpCtrl.reverse();
    await _bubbleCtrl.reverse();
    if (mounted) {
      setState(() {
        _bubbleVisible = false;
        _aiState = SpdAiState.idle;
        _messages.clear();
        _liveText = '';
        _soundLevel = 0.0;
      });
      _checkCtrl.reset();
      _followUpCtrl.reset();
      _isTerminating = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SPEECH FLOW
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  // AI MODEL LOAD & LISTEN FLOW
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkAndLoadModelAndListen() async {
    _openBubble();
    await _startListen(followUp: false);
  }

  Future<void> _toggleListen() async {
    if (!_bubbleVisible) {
      await _checkAndLoadModelAndListen();
      return;
    }

    switch (_aiState) {
      case SpdAiState.idle:
        await _checkAndLoadModelAndListen();
        break;
      case SpdAiState.processing:
        break; // Ignore touches during heavy processes
      case SpdAiState.listening:
      case SpdAiState.listeningFollowUp:
      case SpdAiState.wizardListening:
        await _stopAndProcess();
        break;
      case SpdAiState.askingFollowUp:
      case SpdAiState.wizardAsking:
        await _startListen(
          followUp: false,
          skipGreeting: true,
          listenState: SpdAiState.wizardListening,
        );
        break;
      case SpdAiState.completed:
        _resetAndStart();
        break;
    }
  }

  Future<void> _startListen({
    required bool followUp,
    bool skipGreeting = false,
    SpdAiState? listenState, // Wizard aşamaları için özel durum
  }) async {
    _silenceTimer?.cancel();
    // İzin kontrolü
    var status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mikrofon izni verilmedi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Speech engine yeniden başlat
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize();
    }
    if (!_speechInitialized) return;

    if (!mounted) return;
    setState(() {
      _aiState =
          listenState ??
          (followUp ? SpdAiState.listeningFollowUp : SpdAiState.listening);
      _liveText = '';
      _soundLevel = 0.0;
    });

    _openBubble();

    if (!skipGreeting) {
      final greeting =
          followUp
              ? '🎤 Sizi dinliyorum, eklemek istediğinizi söyleyin...'
              : '👋 Merhaba! Sizi dinliyorum.\n• Rapor girmek için: "Günlük rapor gir"\n• Ekran açmak için: "Şantiyeler ekranı"\n• Yardım için: "Neler yapabilirsin"';
      _addMsg(ChatRole.ai, greeting, ChatMsgType.greeting);
    }

    await _mute(true);
    await _playSound(true);

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(milliseconds: 3400),
      ),
      onResult: (val) {
        if (!mounted || _isTerminating) return;
        final recognized = val.recognizedWords;
        setState(() => _liveText = recognized);
        if (_liveText.isNotEmpty) {
          _addMsg(ChatRole.user, _liveText, ChatMsgType.liveText);
        }

        _silenceTimer?.cancel();

        // Android'de final result geldiğinde anında işle
        if (val.finalResult && !_isTerminating) {
          _onFinalResult();
          return;
        }

        // Akıllı Dinamik Sessizlik Algılayıcı: Kullanıcı duraksayınca bekletmeden seri şekilde işle
        if (recognized.trim().isNotEmpty && !_isTerminating) {
          final words = recognized.trim().split(RegExp(r'\s+'));
          final isShort = words.length <= 3;
          final waitMs = isShort ? 650 : 950;
          _silenceTimer = Timer(Duration(milliseconds: waitMs), () {
            if (!mounted || _isTerminating) return;
            if (_aiState == SpdAiState.listening ||
                _aiState == SpdAiState.listeningFollowUp ||
                _aiState == SpdAiState.wizardListening) {
              _stopAndProcess();
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted || _isTerminating) return;
        setState(() {
          final target = level.clamp(0.0, 10.0);
          _soundLevel = _soundLevel * 0.7 + target * 0.3;
        });
      },
    );

    Future.delayed(const Duration(milliseconds: 200), () => _mute(false));
  }

  Future<void> _stopAndProcess() async {
    _silenceTimer?.cancel();
    await _mute(true);
    await _playSound(false);
    _speech.stop();
    _mute(false);

    if (_liveText.trim().isEmpty) {
      if (_aiState == SpdAiState.listeningFollowUp) {
        if (mounted) setState(() => _aiState = SpdAiState.askingFollowUp);
        return;
      }
      if (mounted) setState(() => _aiState = SpdAiState.idle);
      return;
    }

    _onFinalResult();
  }

  void _onFinalResult() {
    _silenceTimer?.cancel();
    if (_isTerminating) return;
    if (_aiState == SpdAiState.idle || _aiState == SpdAiState.completed) return;

    final metin = _liveText.trim().toLowerCase();
    if (metin.isEmpty) return;

    if (_aiState == SpdAiState.listeningFollowUp) {
      _handleFollowUpAnswer(metin);
    } else if (_aiState == SpdAiState.wizardListening) {
      _handleWizardInput(metin);
    } else {
      _processMainInput(metin);
    }
  }

  // ── GENERIC WIZARD HANDLER ──
  void _handleWizardInput(String metin) {
    if (_activeWizardType == null || !_wizards.containsKey(_activeWizardType)) {
      return;
    }
    final wizardDef = _wizards[_activeWizardType]!;
    final stepConfig = wizardDef[_wizardStepIndex];

    if (metin.isEmpty) {
      _addMsg(ChatRole.ai, stepConfig['retry'], ChatMsgType.greeting);
      Future.delayed(
        const Duration(milliseconds: 600),
        () => _startListen(
          followUp: false,
          skipGreeting: true,
          listenState: SpdAiState.wizardListening,
        ),
      );
      return;
    }

    _wizardData[stepConfig['key']] = metin;
    _wizardStepIndex++;

    if (_wizardStepIndex < wizardDef.length) {
      setState(() => _aiState = SpdAiState.wizardAsking);
      final nextStep = wizardDef[_wizardStepIndex];
      _addMsg(ChatRole.ai, nextStep['question'], ChatMsgType.greeting);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startListen(
            followUp: false,
            skipGreeting: true,
            listenState: SpdAiState.wizardListening,
          );
        }
      });
    } else {
      _addMsg(ChatRole.ai, 'İşleminiz tamamlanıyor...', ChatMsgType.processing);

      if (_activeWizardType == 'daily_report') {
        final sonuc = AkilliSesAyristirici.ayristirSihirbaz(
          wizardData: _wizardData,
          santiyeler: widget.santiyeler,
          isciler: widget.isciler,
        );
        widget.onSonuc(sonuc);
      } else {
        if (widget.onWizardComplete != null) {
          widget.onWizardComplete!(_activeWizardType!, _wizardData);
        }
      }
      _completeSession(customMessage: 'Günlük raporunuz başarıyla kaydedildi.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FOLLOW-UP ANSWER
  // ─────────────────────────────────────────────────────────────
  void _handleFollowUpAnswer(String metin) {
    if (metin.isEmpty) {
      if (mounted) setState(() => _aiState = SpdAiState.askingFollowUp);
      return;
    }

    if (_TurkishNlp.isEvet(metin)) {
      _addMsg(ChatRole.user, metin, ChatMsgType.liveText);
      _addMsg(
        ChatRole.ai,
        '👌 Anlıyorum, yeni bilgiyi söyleyin...',
        ChatMsgType.greeting,
      );
      Future.delayed(
        const Duration(milliseconds: 250),
        () => _startListen(followUp: false),
      );
    } else if (_TurkishNlp.isHayir(metin)) {
      _completeSession(
        customMessage: 'Yardıma ihtiyacınız olursa buradayım! İyi çalışmalar.',
      );
    } else {
      // Yeni puantaj verisi olabilir — direkt işle
      _processMainInput(metin);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN INPUT PROCESSING
  // ─────────────────────────────────────────────────────────────
  void _processMainInput(String metin) async {
    if (metin.isEmpty) {
      if (mounted) setState(() => _aiState = SpdAiState.askingFollowUp);
      _askFollowUp();
      return;
    }

    if (!mounted) return;
    setState(() {
      _aiState = SpdAiState.processing;
      _soundLevel = 0.0;
    });

    _typingCtrl.repeat();

    _addMsg(ChatRole.ai, '⏳ Analiz ediliyor...', ChatMsgType.processing);

    try {
      final workerNames = widget.isciler.map((i) => i.ad).toList();
      final siteNames = widget.santiyeler.map((s) => s.ad).toList();

      // Sadece genel soru (chat_response) gönderilecekse rate limit kontrol et
      // Bu sayede nav/wizard komutları her zaman ücretsiz çalışır
      final intent = await AIService.processPrompt(
        metin,
        workerNames: workerNames,
        siteNames: siteNames,
      );

      _typingCtrl.stop();

      if (intent.action == 'navigate' ||
          intent.action == 'navigate_worker' ||
          intent.action == 'navigate_site') {
        _addMsg(ChatRole.ai, intent.message, ChatMsgType.result);
        return;
      } else if (intent.action == 'start_wizard') {
        _addMsg(ChatRole.ai, intent.message, ChatMsgType.result);
        return;
      } else if (intent.action == 'submit_daily_log') {
        _addMsg(ChatRole.ai, intent.message, ChatMsgType.result);

        final sonuc = AkilliSesAyristirici.ayristir(
          sesMetni: metin,
          santiyeler: widget.santiyeler,
          isciler: widget.isciler,
        );
        widget.onSonuc(sonuc);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) _closeForNavigation();
        return;
      } else if (intent.action == 'create_report') {
        _addMsg(ChatRole.ai, intent.message, ChatMsgType.result);
        if (widget.onReportRequest != null) widget.onReportRequest!();
      } else {
        // chat_response veya unknown
        _addMsg(
          ChatRole.ai,
          intent.message.isNotEmpty
              ? intent.message
              : 'Anlamakta güçlük çektim.',
          ChatMsgType.result,
        );
      }

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _askFollowUp();
    } catch (e) {
      _typingCtrl.stop();
      _addMsg(ChatRole.ai, 'İşlem sırasında hata: $e', ChatMsgType.error);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _askFollowUp();
    }
  }

  void _askFollowUp() {
    if (!mounted) return;
    _speech.stop();
    setState(() {
      _aiState = SpdAiState.askingFollowUp;
      _liveText = '';
      _soundLevel = 0.0;
    });
    _followUpCtrl.forward(from: 0.0);
    _addMsg(
      ChatRole.ai,
      '💬 Eklemek istediğiniz başka bir şey var mı?',
      ChatMsgType.followUpQuestion,
    );
    // Otomatik olarak tekrar dinlemeye başla, kullanıcı cevap verebilsin
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _aiState == SpdAiState.askingFollowUp) {
        _startListen(followUp: true, skipGreeting: true);
      }
    });
  }

  void _closeForNavigation() {
    if (!mounted) return;
    _silenceTimer?.cancel();
    _isTerminating = true;
    _speech.stop();
    _followUpCtrl.reverse();
    setState(() {
      _aiState = SpdAiState.completed;
      _liveText = '';
      _soundLevel = 0.0;
    });
    // Kapatma işlemi daha hızlı ve mesajsız olsun
    _closeBubble().then((_) {
      if (mounted) {
        setState(() => _aiState = SpdAiState.idle);
        _checkCtrl.reset();
        _followUpCtrl.reset();
        _messages.clear();
        _isTerminating = false;
      }
    });
  }

  void _completeSession({String? customMessage}) {
    if (!mounted) return;
    _silenceTimer?.cancel();
    _isTerminating = true;
    _speech.stop();
    _followUpCtrl.reverse();
    setState(() {
      _aiState = SpdAiState.completed;
      _liveText = '';
      _soundLevel = 0.0;
    });
    final msg =
        customMessage ??
        'Yardıma ihtiyacınız olursa buradayım! İyi çalışmalar.';
    _addMsg(ChatRole.ai, msg, ChatMsgType.completed);
    _checkCtrl.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _closeBubble().then((_) {
          if (mounted) {
            setState(() => _aiState = SpdAiState.idle);
            _checkCtrl.reset();
            _followUpCtrl.reset();
            _isTerminating = false;
          }
        });
      }
    });
  }

  void _resetAndStart() {
    _checkCtrl.reset();
    _followUpCtrl.reset();
    _messages.clear();
    if (mounted) {
      setState(() {
        _aiState = SpdAiState.idle;
        _bubbleVisible = false;
      });
    }
    Future.delayed(
      const Duration(milliseconds: 100),
      () => _checkAndLoadModelAndListen(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        if (_bubbleVisible)
          Padding(
            padding: const EdgeInsets.only(bottom: 84, right: 0),
            child: _buildBubble(context),
          ),
        _buildButton(context),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHAT BUBBLE (ŞPD AI ADAPTIVE GLASS INTERFACE)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _bubbleSlide,
      child: FadeTransition(
        opacity: _bubbleOpacity,
        child: ScaleTransition(
          scale: _bubbleScale,
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.86,
                      minWidth: 260,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            isDark
                                ? [
                                  const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.96),
                                  const Color(
                                    0xFF0B1B1E,
                                  ).withValues(alpha: 0.94),
                                  const Color(
                                    0xFF061412,
                                  ).withValues(alpha: 0.96),
                                ]
                                : [
                                  Colors.white.withValues(alpha: 0.97),
                                  const Color(
                                    0xFFF0FDF4,
                                  ).withValues(alpha: 0.95),
                                  const Color(
                                    0xFFE6F4EA,
                                  ).withValues(alpha: 0.97),
                                ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.28),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: isDark ? 0.16 : 0.12),
                          blurRadius: 32,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFF06B6D4,
                          ).withValues(alpha: isDark ? 0.12 : 0.08),
                          blurRadius: 36,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.5 : 0.10,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Top App Brand Green-Teal-Cyan Accent Line
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedBuilder(
                            animation: _rgbRotationCtrl,
                            builder:
                                (_, __) => Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: const [
                                        Color(0xFF10B981),
                                        Color(0xFF14B8A6),
                                        Color(0xFF06B6D4),
                                        Color(0xFF059669),
                                        Color(0xFFF59E0B),
                                        Color(0xFF10B981),
                                      ],
                                      transform: GradientRotation(
                                        _rgbRotationCtrl.value * 2 * math.pi,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            _buildHeader(isDark),
                            if (_messages.isNotEmpty) _buildMessages(isDark),
                            // Fixed height bottom action slot to completely eliminate vertical text jumping
                            _buildBottomSlot(isDark),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ŞPD AI Brand Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(
                        0xFF10B981,
                      ).withValues(alpha: isDark ? 0.25 : 0.15),
                      const Color(
                        0xFF14B8A6,
                      ).withValues(alpha: isDark ? 0.22 : 0.12),
                      const Color(
                        0xFF06B6D4,
                      ).withValues(alpha: isDark ? 0.18 : 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _sparkleCtrl,
                      builder:
                          (_, __) => Transform.rotate(
                            angle: _sparkleCtrl.value * 0.4,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color:
                                  isDark
                                      ? const Color(0xFF5EEAD4)
                                      : const Color(0xFF059669),
                              size: 13,
                            ),
                          ),
                    ),
                    const SizedBox(width: 5),
                    ShaderMask(
                      shaderCallback:
                          (bounds) => LinearGradient(
                            colors:
                                isDark
                                    ? const [
                                      Color(0xFF34D399),
                                      Color(0xFF2DD4BF),
                                      Color(0xFF38BDF8),
                                    ]
                                    : const [
                                      Color(0xFF059669),
                                      Color(0xFF0D9488),
                                      Color(0xFF0284C7),
                                    ],
                          ).createShader(bounds),
                      child: Text(
                        'ŞPD AI',
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStateChip(isDark),
            ],
          ),
          // Close button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _closeBubble();
            },
            child: Container(
              padding: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip(bool isDark) {
    switch (_aiState) {
      case SpdAiState.listening:
      case SpdAiState.listeningFollowUp:
      case SpdAiState.wizardListening:
        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder:
              (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF10B981),
                        const Color(0xFF06B6D4),
                        _pulseCtrl.value,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
                          blurRadius: 7,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Dinliyor...',
                    style: TextStyle(
                      color:
                          isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
        );
      case SpdAiState.processing:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDots(isDark),
            const SizedBox(width: 5),
            Text(
              'İşleniyor...',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case SpdAiState.askingFollowUp:
      case SpdAiState.wizardAsking:
        return Text(
          'Bekliyor',
          style: TextStyle(
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        );
      case SpdAiState.completed:
        return Text(
          'Tamamlandı ✓',
          style: TextStyle(
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        );
      case SpdAiState.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDots(bool isDark) {
    return AnimatedBuilder(
      animation: _typingCtrl,
      builder:
          (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_typingCtrl.value + i * 0.25) % 1.0;
              final y = -3.5 * math.sin(t * math.pi);
              final colors = [
                const Color(0xFF10B981),
                const Color(0xFF14B8A6),
                const Color(0xFF06B6D4),
              ];
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length].withValues(
                      alpha: 0.4 + 0.6 * math.sin(t * math.pi).abs(),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
    );
  }

  // ── Messages ──
  Widget _buildMessages(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _messages.map((m) => _buildMsgBubble(m, isDark)).toList(),
      ),
    );
  }

  Widget _buildMsgBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.role == ChatRole.user;
    final isLive = msg.type == ChatMsgType.liveText;
    final isResult = msg.type == ChatMsgType.result;
    final isCompleted = msg.type == ChatMsgType.completed;
    final isProcessStep =
        msg.type == ChatMsgType.processStep ||
        msg.type == ChatMsgType.processing;
    final isFollowUpQ = msg.type == ChatMsgType.followUpQuestion;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isDark) {
      if (isUser) {
        bgColor = const Color(0xFF0284C7).withValues(alpha: 0.30);
        borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.45);
        textColor = Colors.white;
      } else if (isResult) {
        bgColor = const Color(0xFF0D9488).withValues(alpha: 0.22);
        borderColor = const Color(0xFF2DD4BF).withValues(alpha: 0.40);
        textColor = const Color(0xFFCCFBF1);
      } else if (isCompleted) {
        bgColor = const Color(0xFF059669).withValues(alpha: 0.25);
        borderColor = const Color(0xFF34D399).withValues(alpha: 0.50);
        textColor = const Color(0xFFA7F3D0);
      } else if (isProcessStep) {
        bgColor = const Color(0xFF0F766E).withValues(alpha: 0.25);
        borderColor = const Color(0xFF14B8A6).withValues(alpha: 0.40);
        textColor = const Color(0xFF99F6E4);
      } else if (isFollowUpQ) {
        bgColor = const Color(0xFF78350F).withValues(alpha: 0.25);
        borderColor = const Color(0xFFFBBF24).withValues(alpha: 0.45);
        textColor = const Color(0xFFFEF3C7);
      } else {
        bgColor = Colors.white.withValues(alpha: 0.06);
        borderColor = Colors.white.withValues(alpha: 0.12);
        textColor = const Color(0xFFE2E8F0);
      }
    } else {
      // Light Mode
      if (isUser) {
        bgColor = const Color(0xFFE0F2FE);
        borderColor = const Color(0xFF7DD3FC);
        textColor = const Color(0xFF0369A1);
      } else if (isResult) {
        bgColor = const Color(0xFFECFDF5);
        borderColor = const Color(0xFF6EE7B7);
        textColor = const Color(0xFF047857);
      } else if (isCompleted) {
        bgColor = const Color(0xFFD1FAE5);
        borderColor = const Color(0xFF34D399);
        textColor = const Color(0xFF065F46);
      } else if (isProcessStep) {
        bgColor = const Color(0xFFF0FDFA);
        borderColor = const Color(0xFF99F6E4);
        textColor = const Color(0xFF0F766E);
      } else if (isFollowUpQ) {
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFCD34D);
        textColor = const Color(0xFF92400E);
      } else {
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF1E293B);
      }
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder:
            (_, v, child) => Transform.translate(
              offset: Offset(isUser ? 16 * (1 - v) : -14 * (1 - v), 0),
              child: Opacity(opacity: v, child: child),
            ),
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left: isUser ? 36 : 0,
            right: isUser ? 0 : 36,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 3),
              bottomRight: Radius.circular(isUser ? 3 : 14),
            ),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Text(
            isLive ? '"${msg.text}"' : msg.text,
            style: TextStyle(
              color: textColor,
              fontSize: isLive ? 13 : 12.5,
              fontWeight: isLive ? FontWeight.w600 : FontWeight.w500,
              fontStyle: isLive ? FontStyle.italic : FontStyle.normal,
              height: 1.38,
            ),
          ),
        ),
      ),
    );
  }

  // ── Stable Bottom Slot (Eliminates Jitter/Shake) ──
  Widget _buildBottomSlot(bool isDark) {
    final isListening =
        _aiState == SpdAiState.listening ||
        _aiState == SpdAiState.listeningFollowUp ||
        _aiState == SpdAiState.wizardListening;
    final isFollowUp = _aiState == SpdAiState.askingFollowUp;

    return SizedBox(
      height: 42,
      child: Center(
        child:
            isListening
                ? _buildMiniWave(isDark)
                : (isFollowUp
                    ? _buildFollowUpButtons(isDark)
                    : const SizedBox.shrink()),
      ),
    );
  }

  // ── Mini Waveform (App Emerald-Teal Sine-Wave Visualizer with Fixed Height) ──
  Widget _buildMiniWave(bool isDark) {
    final level = (_soundLevel / 10.0).clamp(0.0, 1.0);
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveCtrl, _rgbRotationCtrl]),
        builder: (_, __) {
          final rot = _rgbRotationCtrl.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(13, (i) {
              final phase = i * 0.12 + _waveCtrl.value + rot * 0.5;
              final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
              final h = 3.0 + (level > 0.04 ? level * 18 * wave : wave * 7);

              final barColors = [
                const Color(0xFF10B981),
                const Color(0xFF14B8A6),
                const Color(0xFF06B6D4),
                const Color(0xFF0D9488),
                const Color(0xFF059669),
                const Color(0xFF2DD4BF),
                const Color(0xFF34D399),
                const Color(0xFF38BDF8),
                const Color(0xFF10B981),
                const Color(0xFF14B8A6),
                const Color(0xFF06B6D4),
                const Color(0xFF0D9488),
                const Color(0xFF10B981),
              ];
              final barColor = barColors[i % barColors.length];

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 2.8,
                height: h.clamp(3.0, 22.0),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: isDark ? 0.5 : 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ── Follow-Up Buttons ──
  Widget _buildFollowUpButtons(bool isDark) {
    return AnimatedBuilder(
      animation: _followUpCtrl,
      builder:
          (_, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - _followUpCtrl.value)),
            child: Opacity(
              opacity: _followUpCtrl.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: _followUpBtn(
                icon: Icons.mic_rounded,
                label: '🎤  Evet, ekle',
                primary: true,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_aiState == SpdAiState.listeningFollowUp) {
                    _speech.stop();
                  }
                  _followUpCtrl.reverse();
                  _addMsg(
                    ChatRole.user,
                    'Evet, eklemek istiyorum.',
                    ChatMsgType.liveText,
                  );
                  _addMsg(
                    ChatRole.ai,
                    '👌 Dinliyorum, söyleyin...',
                    ChatMsgType.greeting,
                  );
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    () => _startListen(followUp: false),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _followUpBtn(
                icon: Icons.check_circle_outline_rounded,
                label: '✅  Hayır, tamam',
                primary: false,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_aiState == SpdAiState.listeningFollowUp) {
                    _speech.stop();
                  }
                  _addMsg(
                    ChatRole.user,
                    'Hayır, tamamdır.',
                    ChatMsgType.liveText,
                  );
                  _completeSession(
                    customMessage:
                        'Yardıma ihtiyacınız olursa buradayım! İyi çalışmalar.',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _followUpBtn({
    required IconData icon,
    required String label,
    required bool primary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient:
              primary
                  ? const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  )
                  : null,
          color:
              primary
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                primary
                    ? const Color(0xFF34D399).withValues(alpha: 0.6)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12)),
          ),
          boxShadow:
              primary
                  ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  primary
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ŞPD AI FLOATING ORB (APP THEMED BUTTON)
  // ─────────────────────────────────────────────────────────────
  Widget _buildButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActiveListening =
        _bubbleVisible &&
        (_aiState == SpdAiState.listening ||
            _aiState == SpdAiState.listeningFollowUp ||
            _aiState == SpdAiState.wizardListening);
    final level = (_soundLevel / 10.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _toggleListen,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseCtrl,
          _waveCtrl,
          _rgbRotationCtrl,
          _sparkleCtrl,
        ]),
        builder: (_, __) {
          final breathe = _pulseCtrl.value;
          final rot = _rgbRotationCtrl.value;

          return SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Dynamic Outer Emerald-Teal Ripple Aura
                if (isActiveListening) ...[
                  // Outermost pulsing ripple
                  Container(
                    width: 88 + level * 24 + breathe * 8,
                    height: 88 + level * 24 + breathe * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        transform: GradientRotation(rot * 2 * math.pi),
                        colors: const [
                          Color(0x2210B981),
                          Color(0x3314B8A6),
                          Color(0x3306B6D4),
                          Color(0x22059669),
                          Color(0x2210B981),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFF10B981,
                        ).withValues(alpha: 0.2 + level * 0.25),
                        width: 1.0,
                      ),
                    ),
                  ),
                  // Inner reactive ripple
                  Container(
                    width: 76 + level * 16 + breathe * 5,
                    height: 76 + level * 16 + breathe * 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF14B8A6,
                      ).withValues(alpha: 0.15 + level * 0.18),
                      border: Border.all(
                        color: const Color(
                          0xFF06B6D4,
                        ).withValues(alpha: 0.35 + level * 0.25),
                        width: 1.2,
                      ),
                    ),
                  ),
                ] else ...[
                  // Idle Ambient Emerald-Teal Glow Ring
                  Container(
                    width: 74 + breathe * 6,
                    height: 74 + breathe * 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(
                            alpha:
                                isDark
                                    ? 0.28 + breathe * 0.12
                                    : 0.20 + breathe * 0.10,
                          ),
                          blurRadius: 18 + breathe * 8,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withValues(
                            alpha:
                                isDark
                                    ? 0.25 + breathe * 0.10
                                    : 0.18 + breathe * 0.08,
                          ),
                          blurRadius: 24 + breathe * 10,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withValues(
                            alpha:
                                isDark
                                    ? 0.20 + breathe * 0.08
                                    : 0.15 + breathe * 0.06,
                          ),
                          blurRadius: 28 + breathe * 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. Rotating App Brand Multi-color Border Ring
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(2.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      transform: GradientRotation(rot * 2 * math.pi),
                      colors: const [
                        Color(0xFF10B981),
                        Color(0xFF14B8A6),
                        Color(0xFF06B6D4),
                        Color(0xFF059669),
                        Color(0xFFF59E0B),
                        Color(0xFF10B981),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.2,
                            colors: _getOrbColors(isActiveListening, isDark),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.6 : 0.15,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildButtonContent(isActiveListening, isDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Color> _getOrbColors(bool listening, bool isDark) {
    if (isDark) {
      if (listening) {
        return [const Color(0xFF0D2821), const Color(0xFF061511)];
      }
      if (_aiState == SpdAiState.askingFollowUp) {
        return [const Color(0xFF2A1B0E), const Color(0xFF130B05)];
      }
      if (_aiState == SpdAiState.completed) {
        return [const Color(0xFF062A1F), const Color(0xFF03120E)];
      }
      return [const Color(0xFF0A221C), const Color(0xFF061411)];
    } else {
      // Light Mode
      if (listening) {
        return [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)];
      }
      if (_aiState == SpdAiState.askingFollowUp) {
        return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)];
      }
      if (_aiState == SpdAiState.completed) {
        return [const Color(0xFFD1FAE5), const Color(0xFF6EE7B7)];
      }
      return [Colors.white, const Color(0xFFE6F4EA)];
    }
  }

  Widget _buildButtonContent(bool listening, bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveCtrl, _sparkleCtrl, _rgbRotationCtrl]),
      builder: (_, __) {
        if (listening) {
          // Dynamic 5-bar App Emerald/Teal Equalizer
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final level = (_soundLevel / 10.0).clamp(0.0, 1.0);
              final phase = i * 0.18 + _waveCtrl.value;
              final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
              final hm = level > 0.04 ? level : _pulseCtrl.value * 0.35;
              final h = (6.0 + 20.0 * (hm + wave * 0.5)).clamp(5.0, 28.0);
              final colors = [
                const Color(0xFF10B981),
                const Color(0xFF14B8A6),
                const Color(0xFF06B6D4),
                const Color(0xFF059669),
                const Color(0xFF2DD4BF),
              ];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.8),
                width: 3.2,
                height: h,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i % colors.length].withValues(alpha: 0.6),
                      blurRadius: 5,
                    ),
                  ],
                ),
              );
            }),
          );
        }
        if (_aiState == SpdAiState.processing) {
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(
                    const Color(0xFF10B981),
                    const Color(0xFF06B6D4),
                    _waveCtrl.value,
                  )!,
                ),
              ),
            ),
          );
        }
        if (_aiState == SpdAiState.completed) {
          return AnimatedBuilder(
            animation: _checkCtrl,
            builder:
                (_, __) => Transform.scale(
                  scale: _checkCtrl.value,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF10B981),
                    size: 30,
                  ),
                ),
          );
        }
        if (_aiState == SpdAiState.askingFollowUp) {
          return AnimatedBuilder(
            animation: _pulseCtrl,
            builder:
                (_, __) => Icon(
                  Icons.mic_none_rounded,
                  color: Color.lerp(
                    const Color(0xFFFBBF24),
                    const Color(0xFFF59E0B),
                    _pulseCtrl.value,
                  ),
                  size: 26,
                ),
          );
        }
        // Idle ŞPD AI 4-Point Sparkle Icon
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDark
                            ? const [
                              Color(0xFF34D399),
                              Color(0xFF2DD4BF),
                              Color(0xFF38BDF8),
                            ]
                            : const [
                              Color(0xFF059669),
                              Color(0xFF0D9488),
                              Color(0xFF0284C7),
                            ],
                  ).createShader(bounds),
              child: Transform.rotate(
                angle: _sparkleCtrl.value * 0.25,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: isDark ? Colors.white : const Color(0xFF059669),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 1),
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors:
                        isDark
                            ? const [Color(0xFF34D399), Color(0xFF38BDF8)]
                            : const [Color(0xFF059669), Color(0xFF0284C7)],
                  ).createShader(bounds),
              child: Text(
                'ŞPD AI',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF059669),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
