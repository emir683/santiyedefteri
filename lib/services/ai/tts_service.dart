import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Şantiye Takip - Akıllı Metin Seslendirme Servisi (TTS) 🎙️
/// Gemini ve AI asistanından gelen yanıtları temiz Türkçe telaffuzla seslendirir.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentlySpeakingId;

  VoidCallback? onStateChanged;

  bool get isPlaying => _isPlaying;
  String? get currentlySpeakingId => _currentlySpeakingId;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Türkçe dil ayarı
      await _tts.setLanguage('tr-TR');

      // Konuşma hızı, ses tonu ve volüm
      // Android ve iOS'ta 0.45 - 0.50 arası son derece akıcı ve anlaşılır bir Türkçe konuşma hızıdır.
      if (!kIsWeb && Platform.isIOS) {
        await _tts.setSpeechRate(0.48);
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambientSolo,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
        );
      } else {
        await _tts.setSpeechRate(0.50);
      }

      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isPlaying = true;
        onStateChanged?.call();
      });

      _tts.setCompletionHandler(() {
        _isPlaying = false;
        _currentlySpeakingId = null;
        onStateChanged?.call();
      });

      _tts.setCancelHandler(() {
        _isPlaying = false;
        _currentlySpeakingId = null;
        onStateChanged?.call();
      });

      _tts.setErrorHandler((dynamic msg) {
        debugPrint('TtsService error: $msg');
        _isPlaying = false;
        _currentlySpeakingId = null;
        onStateChanged?.call();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TtsService init exception: $e');
    }
  }

  /// Metni seslendirir. Zaten bu mesaj çalıyorsa durdurur.
  Future<void> toggleSpeak(String messageId, String text) async {
    if (_isPlaying && _currentlySpeakingId == messageId) {
      await stop();
      return;
    }

    await stop();
    await speak(messageId, text);
  }

  /// Verilen metni temizleyip seslendirir
  Future<void> speak(String messageId, String text) async {
    if (!_isInitialized) {
      await init();
    }

    final cleanText = cleanMarkdownForSpeech(text);
    if (cleanText.trim().isEmpty) return;

    _currentlySpeakingId = messageId;
    _isPlaying = true;
    onStateChanged?.call();

    try {
      await _tts.speak(cleanText);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _isPlaying = false;
      _currentlySpeakingId = null;
      onStateChanged?.call();
    }
  }

  /// Seslendirmeyi anında durdurur
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentlySpeakingId = null;
    onStateChanged?.call();
  }

  /// Markdown işaretlerini, emojileri, linkleri ve teknik sembolleri temizler;
  /// robotik telaffuzu engelleyip doğal akıcı bir Türkçe konuşma metni üretir.
  static String cleanMarkdownForSpeech(String input) {
    var text = input;

    // 1. Kod bloklarını ve linkleri kaldır
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'`.*?`'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'https?:\/\/\S+'), '');

    // 2. Başlık ve ayraçları temizle (#, ###, ---, ───)
    text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'[-─=]{3,}'), ' ');

    // 3. Kalınlık, eğiklik, liste işaretleri (*, **, _, •)
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    text = text.replaceAll(RegExp(r'^[•\-\*]\s*', multiLine: true), '');

    // 4. Sembol dönüşümleri (örneğin m² -> metrekare, m³ -> metreküp, TL -> Türk lirası)
    text = text.replaceAll('m²', ' metrekare ');
    text = text.replaceAll('m2', ' metrekare ');
    text = text.replaceAll('m³', ' metreküp ');
    text = text.replaceAll('m3', ' metreküp ');
    text = text.replaceAll('₺', ' Türk lirası ');
    text = text.replaceAll('TL', ' Türk lirası ');
    text = text.replaceAll('~', ' yaklaşık ');
    text = text.replaceAll('%', ' yüzde ');

    // 5. Emojileri temizle (TTS emojileri İngilizce veya garip kodlarla okumasın)
    text = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F270}\u{2388}\u{2B05}\u{2B06}\u{2B07}\u{2B1B}\u{2B1C}\u{2B50}\u{2B55}\u{1F004}\u{1F0CF}]',
        unicode: true,
      ),
      '',
    );

    // 6. Fazla boşlukları toparla
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  void dispose() {
    stop();
  }
}
