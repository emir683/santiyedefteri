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

  // V2 İlerleme & Yükleme Durumu
  int _loadingStep = 1;
  String _loadingTitle = 'CAD Dosyası Hazırlanıyor...';
  String _loadingSubtitle = 'Dosya inceleniyor ve belleğe alınıyor...';
  String _loadingFileSize = '';
  Timer? _stageTimer;

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
    _stageTimer?.cancel();
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

  void _closeDrawingView() {
    _stageTimer?.cancel();
    setState(() {
      _isViewingDrawing = false;
      _isParsing = false;
      _activeDrawingName = '';
    });
    _webViewController?.loadRequest(Uri.parse('about:blank'));
  }

  Future<void> _openLocalFile(String filePath,
      [String? displayName, String? cachedWebglUrl]) async {
    final file = File(filePath);
    final fileName = displayName ?? file.uri.pathSegments.last;

    // 1. Eğer daha önce dönüştürülmüş ve webglUrl varsa doğrudan yükle
    if (cachedWebglUrl != null && cachedWebglUrl.isNotEmpty) {
      _stageTimer?.cancel();
      setState(() {
        _isViewingDrawing = true;
        _isParsing = true;
        _activeDrawingName = fileName;
        _loadingStep = 4;
        _loadingTitle = 'Önbellekten Yükleniyor...';
        _loadingSubtitle =
            'Daha önce dönüştürülen V2 WebGL çizim verisi GPU donanımına aktarılıyor.';
        _loadingFileSize =
            file.existsSync() ? _formatFileSize(file.lengthSync()) : '';
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
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    _stageTimer?.cancel();

    setState(() {
      _isViewingDrawing = true;
      _isParsing = true;
      _activeDrawingName = fileName;
      _loadingStep = 1;
      _loadingTitle = 'CAD Dosyası Hazırlanıyor...';
      _loadingSubtitle = 'Çizim dosyası ($fileName) inceleniyor ve paketleniyor...';
      _loadingFileSize = _formatFileSize(fileSize);
    });

    _stageTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isParsing) {
        setState(() {
          _loadingStep = 2;
          _loadingTitle = 'V2 Sunucusuna Aktarılıyor...';
          _loadingSubtitle =
              'Cloudflare yüksek hızlı tüneli ile Oracle Cloud V2 motoruna iletiliyor...';
        });
      }
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

      Timer(const Duration(milliseconds: 3000), () {
        if (mounted && _isParsing && _loadingStep < 3) {
          setState(() {
            _loadingStep = 3;
            _loadingTitle = 'V2 Motoru Çizimi Çözümlüyor...';
            _loadingSubtitle =
                'Direct DXF motoru ile ACI renkler, dolgular ve sıfır-kopya binary paket üretiliyor...';
          });
        }
      });

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
          dosyaBoyutu: fileSize,
          acilmaTarihi: DateTime.now(),
          webglUrl: resolvedWebglUrl,
        ));

        if (mounted) {
          setState(() {
            _loadingStep = 4;
            _loadingTitle = 'GPU Donanım Motoru Başlatılıyor...';
            _loadingSubtitle =
                'Sıfır-kopya ikili (binary) geometri verisi WebGL tuvaline yükleniyor...';
          });
        }

        await _webViewController?.loadRequest(Uri.parse(resolvedWebglUrl));
      } else {
        throw Exception(
            'Dönüştürme sunucusu yanıt vermedi (${streamedResponse.statusCode})');
      }
    } catch (e) {
      _stageTimer?.cancel();
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
    _stageTimer?.cancel();
    setState(() {
      _isViewingDrawing = true;
      _isParsing = true;
      _activeDrawingName = 'HASAN AKTAŞ STATİK (V2)';
      _loadingStep = 4;
      _loadingTitle = 'Örnek Statik Proje Yükleniyor...';
      _loadingSubtitle =
          'V2 motoru ile önbelleklenen 757.000+ çizgi ve dolgu GPU donanımına aktarılıyor...';
      _loadingFileSize = '7.4 MB DWG (28.9 MB GPU)';
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
          _closeDrawingView();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 19),
              onPressed: _closeDrawingView,
              tooltip: 'Dosyalara Dön',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _activeDrawingName.isNotEmpty
                      ? _activeDrawingName
                      : 'V2 CAD Motoru',
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
                      'Donanım Hızlandırmalı GPU Motoru (V2)',
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
                Positioned.fill(
                  child: _buildLoadingOverlay(),
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF161F2E),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: const Color(0xFF0F7C86).withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animasyonlu / Parlayan CAD İkonu
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F7C86).withValues(alpha: 0.25),
                          const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Başlık (Mevcut Aşama)
                  Text(
                    _loadingTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Açıklama Detayı
                  Text(
                    _loadingSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dosya Adı & Boyut Rozeti
                  if (_activeDrawingName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 16, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _activeDrawingName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_loadingFileSize.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($_loadingFileSize)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 22),

                  // 4 Aşamalı İlerleme Göstergesi (Stepper)
                  Row(
                    children: [
                      _buildStepIndicator(1, 'Hazırlık'),
                      _buildStepConnector(1),
                      _buildStepIndicator(2, 'Aktarım'),
                      _buildStepConnector(2),
                      _buildStepIndicator(3, 'V2 Motor'),
                      _buildStepConnector(3),
                      _buildStepIndicator(4, 'GPU Çizim'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // İptal Et Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _closeDrawingView,
                      child: const Text(
                        'İptal Et / Geri Dön',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, String label) {
    final isDone = _loadingStep > stepNumber;
    final isActive = _loadingStep == stepNumber;
    final color = isDone
        ? const Color(0xFF10B981)
        : (isActive ? const Color(0xFF38BDF8) : Colors.white24);

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF10B981)
                  : (isActive
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                      : Colors.transparent),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive || isDone ? Colors.white : Colors.white38,
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int stepNumber) {
    final isDone = _loadingStep > stepNumber;
    return Container(
      width: 12,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDone ? const Color(0xFF10B981) : Colors.white12,
    );
  }
}
