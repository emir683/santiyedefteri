import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dwg_goruntuleyici_ekrani.dart';

class CadFilePayload {
  final String filePath;
  final String fileName;

  const CadFilePayload({
    required this.filePath,
    required this.fileName,
  });

  @override
  String toString() => 'CadFilePayload(fileName: $fileName, filePath: $filePath)';
}

/// WhatsApp, Telegram veya Dosya Yöneticisi üzerinden gelen DWG/DXF dosyalarını dinler ve yönlendirir.
class CadIntentService {
  CadIntentService._();

  static final CadIntentService instance = CadIntentService._();

  static const MethodChannel _channel =
      MethodChannel('com.emircf.santiyeyonetim/cad_intent');

  final StreamController<CadFilePayload> _fileStreamController =
      StreamController<CadFilePayload>.broadcast();

  Stream<CadFilePayload> get fileStream => _fileStreamController.stream;

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  CadFilePayload? _pendingPayload;
  bool _isPresenting = false;

  CadFilePayload? get pendingPayload => _pendingPayload;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    debugPrint('[CAD_INTENT] CadIntentService baslatiliyor...');

    _channel.setMethodCallHandler((call) async {
      debugPrint('[CAD_INTENT] MethodChannel call: ${call.method}');
      if (call.method == 'onCadFileReceived') {
        final args = call.arguments;
        if (args is Map) {
          final filePath = args['filePath'] as String?;
          final fileName = args['fileName'] as String?;
          if (filePath != null && filePath.isNotEmpty) {
            final payload = CadFilePayload(
              filePath: filePath,
              fileName: fileName ?? 'Proje_Cizimi.dwg',
            );
            debugPrint('[CAD_INTENT] Gelen dosya yakalandi: $payload');
            _handleIncomingCadFile(payload);
          }
        }
      }
    });

    try {
      final initialData =
          await _channel.invokeMethod<dynamic>('getInitialCadFile');
      debugPrint('[CAD_INTENT] getInitialCadFile yaniti: $initialData');
      if (initialData is Map) {
        final filePath = initialData['filePath'] as String?;
        final fileName = initialData['fileName'] as String?;
        if (filePath != null && filePath.isNotEmpty) {
          _pendingPayload = CadFilePayload(
            filePath: filePath,
            fileName: fileName ?? 'Proje_Cizimi.dwg',
          );
          debugPrint('[CAD_INTENT] Soguk acilis CAD dosyasi mevcut: $_pendingPayload');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            tryPresentPendingCadFile();
          });
        }
      }
    } catch (e) {
      debugPrint('[CAD_INTENT] CAD baslangic dosyasi kontrol hatasi: $e');
    }
  }

  void _handleIncomingCadFile(CadFilePayload payload) {
    _pendingPayload = payload;
    _fileStreamController.add(payload);
    tryPresentPendingCadFile();
  }

  /// Bekleyen CAD dosyasini guvenle ekrana tasir
  void tryPresentPendingCadFile() {
    final payload = _pendingPayload;
    if (payload == null) return;
    if (_isPresenting) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('[CAD_INTENT] Navigator henuz hazir degil, 500ms sonra tekrar denenecek...');
      Future.delayed(
        const Duration(milliseconds: 500),
        () => tryPresentPendingCadFile(),
      );
      return;
    }

    _isPresenting = true;
    _pendingPayload = null;

    debugPrint('[CAD_INTENT] CAD Ekrani aciliyor: ${payload.fileName}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => DwgGoruntuleyiciEkrani(
            initialLocalFilePath: payload.filePath,
            initialFileName: payload.fileName,
          ),
        ),
      ).whenComplete(() {
        _isPresenting = false;
        debugPrint('[CAD_INTENT] CAD ekranindan donuldu.');
      });
    });
  }
}
