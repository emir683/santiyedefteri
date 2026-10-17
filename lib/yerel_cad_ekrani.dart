import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'widgets/glass_surface.dart';

/// Son açılan yerel CAD projeleri modeli
class YerelCadDosya {
  final String dosyaAdi;
  final String dosyaYolu;
  final int dosyaBoyutu;
  final DateTime acilmaTarihi;
  final String? webglUrl;

  YerelCadDosya({
    required this.dosyaAdi,
    required this.dosyaYolu,
    required this.dosyaBoyutu,
    required this.acilmaTarihi,
    this.webglUrl,
  });

  Map<String, dynamic> toJson() => {
        'dosyaAdi': dosyaAdi,
        'dosyaYolu': dosyaYolu,
        'dosyaBoyutu': dosyaBoyutu,
        'acilmaTarihi': acilmaTarihi.toIso8601String(),
        'webglUrl': webglUrl,
      };

  factory YerelCadDosya.fromJson(Map<String, dynamic> json) => YerelCadDosya(
        dosyaAdi: json['dosyaAdi'] as String? ?? 'CAD Çizimi',
        dosyaYolu: json['dosyaYolu'] as String? ?? '',
        dosyaBoyutu: json['dosyaBoyutu'] as int? ?? 0,
        acilmaTarihi:
            DateTime.tryParse(json['acilmaTarihi'] as String? ?? '') ??
                DateTime.now(),
        webglUrl: json['webglUrl'] as String?,
      );
}

/// Çevrimdışı, Sıfır-Sunucu, Tamamen Cihaz İçi Yerel WebGL CAD Görüntüleyici
class YerelCadEkrani extends StatefulWidget {
  final String? initialFilePath;
  final String? initialFileName;

  const YerelCadEkrani({
    super.key,
    this.initialFilePath,
    this.initialFileName,
  });

  @override
  State<YerelCadEkrani> createState() => _YerelCadEkraniState();
}

class _YerelCadEkraniState extends State<YerelCadEkrani> {
  static const Color _kBrandTeal = Color(0xFF0F7C86);
  static const Color _kTitleDark = Color(0xFF102A43);
  static const String _kCadServerUrl =
      'https://junior-employers-gay-tommy.trycloudflare.com';

  WebViewController? _webViewController;
  HttpServer? _localCadServer;
  int? _localCadServerPort;
  bool _isViewingDrawing = false;
  bool _isParsing = false;
  String _activeDrawingName = '';
  String? _activeLocalFilePath;
  List<YerelCadDosya> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _initWebViewController();

    if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openLocalFile(widget.initialFilePath!, widget.initialFileName);
      });
    }
  }

  @override
  void dispose() {
    _localCadServer?.close(force: true);
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList('yerel_cad_recent_files') ?? [];
      final files = listJson
          .map((item) {
            try {
              return YerelCadDosya.fromJson(
                  jsonDecode(item) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<YerelCadDosya>()
          .toList();

      if (mounted) {
        setState(() {
          _recentFiles = files;
        });
      }
    } catch (e) {
      debugPrint('[Yerel CAD] Son dosyalar okunamadı: $e');
    }
  }

  Future<void> _saveRecentFile(YerelCadDosya file) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentFiles.removeWhere((item) =>
          (item.dosyaYolu.isNotEmpty && item.dosyaYolu == file.dosyaYolu) ||
          item.dosyaAdi == file.dosyaAdi);
      _recentFiles.insert(0, file);
      if (_recentFiles.length > 20) {
        _recentFiles = _recentFiles.sublist(0, 20);
      }

      final listJson =
          _recentFiles.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList('yerel_cad_recent_files', listJson);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Yerel CAD] Son dosya kaydedilemedi: $e');
    }
  }

  Future<void> _deleteRecentFile(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentFiles.removeAt(index);
      final listJson =
          _recentFiles.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList('yerel_cad_recent_files', listJson);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _startLocalCadServer() async {
    if (_localCadServer != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _localCadServer = server;
      _localCadServerPort = server.port;

      server.listen((HttpRequest request) async {
        try {
          var path = request.uri.path;
          if (path == '/active-cad-file' && _activeLocalFilePath != null) {
            final cadFile = File(_activeLocalFilePath!);
            if (await cadFile.exists()) {
              request.response.headers.set('Content-Type', 'application/octet-stream');
              request.response.headers.set('Access-Control-Allow-Origin', '*');
              request.response.headers.set('Cache-Control', 'no-store');
              request.response.statusCode = HttpStatus.ok;
              await request.response.addStream(cadFile.openRead());
              await request.response.close();
              return;
            }
          }
          if (path == '/' || path.isEmpty) {
            path = 'index.html';
          } else if (path.startsWith('/')) {
            path = path.substring(1);
          }

          String mime = 'text/plain';
          if (path.endsWith('.html')) {
            mime = 'text/html; charset=utf-8';
          } else if (path.endsWith('.js')) {
            mime = 'application/javascript; charset=utf-8';
          } else if (path.endsWith('.wasm')) {
            mime = 'application/wasm';
          } else if (path.endsWith('.css')) {
            mime = 'text/css; charset=utf-8';
          } else if (path.endsWith('.json')) {
            mime = 'application/json; charset=utf-8';
          }

          final assetKey = 'assets/yerel_cad/$path';
          final byteData = await rootBundle.load(assetKey);
          final bytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );

          request.response.headers.set('Content-Type', mime);
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          request.response.headers.set('Cache-Control', 'no-cache');
          request.response.statusCode = HttpStatus.ok;
          request.response.add(bytes);
          await request.response.close();
        } catch (e) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('404: $e');
          await request.response.close();
        }
      });
      debugPrint('[Yerel CAD] Localhost sunucu aktif: http://127.0.0.1:$_localCadServerPort');
    } catch (e) {
      debugPrint('[Yerel CAD] Localhost sunucu başlatılamadı: $e');
    }
  }

  Future<void> _loadCadHtml() async {
    await _startLocalCadServer();
    if (_localCadServerPort != null) {
      await _webViewController?.loadRequest(
        Uri.parse('http://127.0.0.1:$_localCadServerPort/index.html'),
      );
    } else {
      await _webViewController?.loadFlutterAsset('assets/yerel_cad/index.html');
    }
  }

  void _initWebViewController() {
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'YerelCadBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = jsonDecode(msg.message) as Map<String, dynamic>;
            if (data['type'] == 'loaded') {
              if (mounted) {
                setState(() {
                  _isParsing = false;
                });
              }
            } else if (data['type'] == 'dwg_wasm_failed') {
              final errStr = data['error'] as String? ?? 'Bilinmeyen hata';
              debugPrint('[Yerel CAD] Yerel DWG çözümlenemedi (Ana sunucuya gönderilmiyor): $errStr');
              if (mounted) {
                setState(() {
                  _isParsing = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Yerel DWG Çözümleme Hatası: $errStr',
                    ),
                    backgroundColor: Colors.redAccent.shade700,
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: 'Hata Ayıkla',
                      textColor: Colors.white,
                      onPressed: () {
                        _webViewController?.runJavaScript(
                            'window.openDebugger ? window.openDebugger() : CADDebugger.open();');
                      },
                    ),
                  ),
                );
              }
            } else if (data['type'] == 'copy_clipboard') {
              final text = data['text'] as String? ?? '';
              if (text.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hata ayıklama raporu panoya kopyalandı.'),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isParsing = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('[Yerel CAD Webview Error] ${error.description}');
          },
        ),
      );

    _webViewController = controller;
    _loadCadHtml();
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dxf', 'dwg', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) return;

      await _openLocalFile(path, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçilemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static String _normalizeUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;
    try {
      final uri = Uri.parse(rawUrl);
      final currentHost = Uri.parse(_kCadServerUrl).host;
      if (uri.host.endsWith('.trycloudflare.com') && uri.host != currentHost) {
        return uri.replace(host: currentHost).toString();
      }
    } catch (_) {}
    return rawUrl;
  }

  Future<void> _openLocalFile(String filePath,
      [String? displayName, String? cachedWebglUrl]) async {
    final file = File(filePath);
    final fileName = displayName ?? file.uri.pathSegments.last;

    // 1. Eğer daha önce dönüştürülmüş ve webglUrl varsa doğrudan yükle
    if (cachedWebglUrl != null && cachedWebglUrl.isNotEmpty) {
      setState(() {
        _isViewingDrawing = true;
        _isParsing = true;
        _activeDrawingName = fileName;
      });
      final isDark = Theme.of(context).brightness == Brightness.dark;
      String url = _normalizeUrl(cachedWebglUrl);
      if (!url.contains('theme=')) {
        url += '&theme=${isDark ? 'dark' : 'light'}';
      }
      await _webViewController?.loadRequest(Uri.parse(url));
      return;
    }

    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seçilen dosya cihazda bulunamadı.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // V2 Motoruna Yönlendir
    await _convertAndOpenDwg(file, fileName);
  }

  Future<void> _convertAndOpenDwg(File file, String fileName) async {
    setState(() {
      _isViewingDrawing = true;
      _isParsing = true;
      _activeDrawingName = fileName;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_kCadServerUrl/api/convert-v2'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path,
            filename: fileName),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 120));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final String? webglUrl = data['webglUrl'] as String?;
        final String? fileId = data['id'] as String?;

        String resolvedWebglUrl;
        if (webglUrl != null && webglUrl.isNotEmpty) {
          resolvedWebglUrl =
              webglUrl.startsWith('/') ? '$_kCadServerUrl$webglUrl' : webglUrl;
          if (!resolvedWebglUrl.contains('title=')) {
            resolvedWebglUrl += '&title=${Uri.encodeComponent(fileName)}';
          }
        } else if (fileId != null && fileId.isNotEmpty) {
          resolvedWebglUrl =
              '$_kCadServerUrl/webgl-cad-v2.html?id=$fileId&title=${Uri.encodeComponent(fileName)}';
        } else {
          throw Exception('Geçerli bir CAD bağlantısı alınamadı.');
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (!resolvedWebglUrl.contains('theme=')) {
          resolvedWebglUrl += '&theme=${isDark ? 'dark' : 'light'}';
        }

        resolvedWebglUrl = _normalizeUrl(resolvedWebglUrl);

        // Son dosyalara webglUrl ile kaydet
        await _saveRecentFile(YerelCadDosya(
          dosyaAdi: fileName,
          dosyaYolu: file.path,
          dosyaBoyutu: file.existsSync() ? file.lengthSync() : 0,
          acilmaTarihi: DateTime.now(),
          webglUrl: resolvedWebglUrl,
        ));

        await _webViewController?.loadRequest(Uri.parse(resolvedWebglUrl));
        if (mounted) {
          setState(() {
            _isParsing = false;
          });
        }
      } else {
        throw Exception(
            'Dönüştürme sunucusu yanıt vermedi (${streamedResponse.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _isViewingDrawing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'DWG/DXF dosyası (V2) açılamadı: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _openLocalFile(file.path, fileName),
            ),
          ),
        );
      }
    }
  }

  void _openDemoPlan() {
    setState(() {
      _isViewingDrawing = true;
      _activeDrawingName = 'HASAN AKTAŞ STATİK (V2)';
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demoUrl =
        '$_kCadServerUrl/webgl-cad-v2.html?id=bc00f9c7-d593-49d7-9f4e-ceefb57f27b8&title=${Uri.encodeComponent('HASAN AKTAŞ STATİK (V2)')}&theme=${isDark ? 'dark' : 'light'}';
    _webViewController?.loadRequest(Uri.parse(demoUrl));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Widget _buildPanelGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    VoidCallback? onTap,
    double borderRadius = 22,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isDark ? const Color(0xFF15181D) : const Color(0xFFE7EEF1))
                .withValues(alpha: isDark ? 0.96 : 0.90),
            (isDark ? const Color(0xFF090B0F) : const Color(0xFFD6E1E6))
                .withValues(alpha: isDark ? 0.98 : 0.94),
          ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFBFD0D6).withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: isDark ? 18 : 12,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:
                const Color(0xFF79E9D7).withValues(alpha: isDark ? 0.03 : 0.08),
            blurRadius: isDark ? 12 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildPanelGlassIconBadge({
    required IconData icon,
    Color accentColor = _kBrandTeal,
    double size = 48,
    double iconSize = 24,
    double borderRadius = 14,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: isDark ? 0.20 : 0.18),
            (isDark ? const Color(0xFF15313A) : const Color(0xFFE9F8FA))
                .withValues(alpha: isDark ? 0.72 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.14),
        ),
      ),
      child: Icon(icon, color: accentColor, size: iconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : _kTitleDark;
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    // Eğer çizim görüntüleniyorsa tam ekran WebGL CAD motorunu göster
    if (_isViewingDrawing) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() {
            _isViewingDrawing = false;
          });
          _loadCadHtml();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 19),
              onPressed: () {
                setState(() {
                  _isViewingDrawing = false;
                });
                _loadCadHtml();
              },
              tooltip: 'Dosyalara Dön',
            ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _activeDrawingName.isNotEmpty
                    ? _activeDrawingName
                    : 'Çevrimdışı CAD Motoru',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Donanım Hızlandırmalı GPU Motoru',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report_outlined,
                  color: Color(0xFFF87171), size: 21),
              tooltip: 'Hata Ayıklayıcı (Debugger)',
              onPressed: () {
                _webViewController?.runJavaScript(
                    'window.openDebugger ? window.openDebugger() : CADDebugger.open();');
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_open_outlined,
                  color: Color(0xFF38BDF8), size: 21),
              tooltip: 'Farklı Çizim Seç',
              onPressed: _pickAndOpenFile,
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_webViewController != null)
              WebViewWidget(controller: _webViewController!),
            if (_isParsing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

    // Ana Dosya Seçim & Çevrimdışı Bilgi Ekranı
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 19,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri Dön',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yeni Nesil V2 CAD Motoru',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Doğrudan DXF & Donanım Hızlandırma (V2)',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: GlassPageSurface(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Hero Kartı - Cihazdan Dosya Seç
              _buildPanelGlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _buildPanelGlassIconBadge(
                      icon: Icons.offline_bolt_rounded,
                      accentColor: const Color(0xFF0F7C86),
                      size: 64,
                      iconSize: 32,
                      borderRadius: 20,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'V2 Motoru ile CAD Çizimi Aç',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '.dwg veya .dxf projelerinizi doğrudan seçin. '
                      'Yeni V2 mimarisi (Direct DXF + Sıfır-Kopya Binary Stream) ile ultra yüksek hızda görüntülenir.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBrandTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _pickAndOpenFile,
                        icon: const Icon(Icons.file_open_rounded, size: 20),
                        label: const Text(
                          'V2 Motoru ile CAD Aç (.dwg / .dxf)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F7C86),
                          side: BorderSide(
                            color: _kBrandTeal.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openDemoPlan,
                        icon: const Icon(Icons.remove_red_eye_outlined,
                            size: 18),
                        label: const Text(
                          'Örnek Statik Projeyi V2 ile Test Et',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Kapsanan Varlıklar Özeti (%100 Çizim Türü)
              _buildPanelGlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Desteklenen CAD Varlıkları (%100)',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeaturePill('LINE (Çizgi)', isDark),
                        _buildFeaturePill('LWPOLYLINE (Yay/Bulge)', isDark),
                        _buildFeaturePill('ARC & CIRCLE', isDark),
                        _buildFeaturePill('SOLID & HATCH (Dolgu)', isDark),
                        _buildFeaturePill('INSERT (Blok Matrisleri)', isDark),
                        _buildFeaturePill('TEXT / MTEXT', isDark),
                        _buildFeaturePill('256 AutoCAD ACI Renk', isDark),
                        _buildFeaturePill('OSNAP Akıllı Mıknatıs', isDark),
                        _buildFeaturePill('Büyüteç Loupe (Hassas)', isDark),
                        _buildFeaturePill('Mesafe & Alan Ölçümü', isDark),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Son Açılan Yerel Çizimler Başlığı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Son Açılan Çizimler',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (_recentFiles.isNotEmpty)
                      Text(
                        '${_recentFiles.length} Dosya',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (_recentFiles.isEmpty)
                _buildPanelGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                      vertical: 28, horizontal: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 38,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Henüz bir çizim açılmadı',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cihazınızdaki .dwg veya .dxf çizimlerini açtığınızda burada hızlı erişim için listelenecektir.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_recentFiles.length, (index) {
                  final f = _recentFiles[index];
                  final isReady = f.webglUrl != null && f.webglUrl!.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPanelGlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: () => _openLocalFile(
                          f.dosyaYolu, f.dosyaAdi, f.webglUrl),
                      child: Row(
                        children: [
                          _buildPanelGlassIconBadge(
                            icon: Icons.architecture_rounded,
                            accentColor: isReady
                                ? const Color(0xFF10B981)
                                : const Color(0xFF0F7C86),
                            size: 42,
                            iconSize: 22,
                            borderRadius: 12,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        f.dosyaAdi,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isReady)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'GPU Hazır',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      _formatFileSize(f.dosyaBoyutu),
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(f.acilmaTarihi),
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: Colors.redAccent.withValues(alpha: 0.7),
                            ),
                            tooltip: 'Listeden Kaldır',
                            onPressed: () => _deleteRecentFile(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black)
            .withValues(alpha: isDark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.08 : 0.06),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
