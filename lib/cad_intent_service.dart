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

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
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
            _handleIncomingCadFile(payload);
          }
        }
      }
    });

    try {
      final initialData =
          await _channel.invokeMethod<dynamic>('getInitialCadFile');
      if (initialData is Map) {
        final filePath = initialData['filePath'] as String?;
        final fileName = initialData['fileName'] as String?;
        if (filePath != null && filePath.isNotEmpty) {
          _pendingPayload = CadFilePayload(
            filePath: filePath,
            fileName: fileName ?? 'Proje_Cizimi.dwg',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndOpenPending();
          });
        }
      }
    } catch (e) {
      debugPrint('CAD başlangıç dosyası kontrolü: $e');
    }
  }

  void _handleIncomingCadFile(CadFilePayload payload) {
    _fileStreamController.add(payload);
    _openCadScreen(payload);
  }

  void _checkAndOpenPending() {
    if (_pendingPayload != null) {
      final payload = _pendingPayload!;
      _pendingPayload = null;
      _openCadScreen(payload);
    }
  }

  void _openCadScreen(CadFilePayload payload) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      Future.delayed(
        const Duration(milliseconds: 600),
        () => _openCadScreen(payload),
      );
      return;
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => DwgGoruntuleyiciEkrani(
          initialLocalFilePath: payload.filePath,
          initialFileName: payload.fileName,
        ),
      ),
    );
  }
}
