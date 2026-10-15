import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'widgets/glass_surface.dart';

/// Son açılan yerel CAD projeleri modeli
class YerelCadDosya {
  final String dosyaAdi;
  final String dosyaYolu;
  final int dosyaBoyutu;
  final DateTime acilmaTarihi;

  YerelCadDosya({
    required this.dosyaAdi,
    required this.dosyaYolu,
    required this.dosyaBoyutu,
    required this.acilmaTarihi,
  });

  Map<String, dynamic> toJson() => {
        'dosyaAdi': dosyaAdi,
        'dosyaYolu': dosyaYolu,
        'dosyaBoyutu': dosyaBoyutu,
        'acilmaTarihi': acilmaTarihi.toIso8601String(),
      };

  factory YerelCadDosya.fromJson(Map<String, dynamic> json) => YerelCadDosya(
        dosyaAdi: json['dosyaAdi'] as String? ?? 'CAD Çizimi',
        dosyaYolu: json['dosyaYolu'] as String? ?? '',
        dosyaBoyutu: json['dosyaBoyutu'] as int? ?? 0,
        acilmaTarihi:
            DateTime.tryParse(json['acilmaTarihi'] as String? ?? '') ??
                DateTime.now(),
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

  WebViewController? _webViewController;
  bool _isWebViewReady = false;
  bool _isViewingDrawing = false;
  bool _isParsing = false;
  String _activeDrawingName = '';
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
      _recentFiles.removeWhere((item) => item.dosyaYolu == file.dosyaYolu);
      _recentFiles.insert(0, file);
      if (_recentFiles.length > 15) {
        _recentFiles = _recentFiles.sublist(0, 15);
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
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isWebViewReady = true;
              });
            }
          },
        ),
      );

    controller.loadFlutterAsset('assets/yerel_cad/index.html');
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

  Future<void> _openLocalFile(String filePath, [String? displayName]) async {
    final file = File(filePath);
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

    final fileName = displayName ?? file.uri.pathSegments.last;
    final extension = fileName.toLowerCase().split('.').last;

    setState(() {
      _isViewingDrawing = true;
      _isParsing = true;
      _activeDrawingName = fileName;
    });

    final bytes = await file.readAsBytes();
    await _saveRecentFile(YerelCadDosya(
      dosyaAdi: fileName,
      dosyaYolu: filePath,
      dosyaBoyutu: bytes.length,
      acilmaTarihi: DateTime.now(),
    ));

    // Webview hazır değilse kısa bekle
    if (!_isWebViewReady) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // DWG kontrolü
    if (extension == 'dwg') {
      final isBinaryDwg = bytes.length >= 6 &&
          bytes[0] == 0x41 && // 'A'
          bytes[1] == 0x43 && // 'C'
          bytes[2] == 0x31; // '1'

      if (isBinaryDwg) {
        // İkili AutoCAD DWG dosyası - Kullanıcıya bilgi ver ve varsa metin/DXF akışını dene
        String? extractedDxf;
        try {
          final content = utf8.decode(bytes, allowMalformed: true);
          if (content.contains('SECTION') && content.contains('ENTITIES')) {
            extractedDxf = content;
          }
        } catch (_) {}

        if (extractedDxf != null) {
          final escapedJson = jsonEncode(extractedDxf);
          final titleJson = jsonEncode(fileName);
          await _webViewController?.runJavaScript(
              'window.loadDxfString($escapedJson, $titleJson);');
        } else {
          setState(() {
            _isParsing = false;
          });

          if (mounted) {
            _showDwgNoticeDialog(fileName);
          }
          return;
        }
      } else {
        // Metin tabanlı format
        final content = utf8.decode(bytes, allowMalformed: true);
        final escapedJson = jsonEncode(content);
        final titleJson = jsonEncode(fileName);
        await _webViewController?.runJavaScript(
            'window.loadDxfString($escapedJson, $titleJson);');
      }
    } else {
      // Standart DXF dosyası
      final content = utf8.decode(bytes, allowMalformed: true);
      final escapedJson = jsonEncode(content);
      final titleJson = jsonEncode(fileName);
      await _webViewController
          ?.runJavaScript('window.loadDxfString($escapedJson, $titleJson);');
    }
  }

  void _showDwgNoticeDialog(String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'AutoCAD DWG Dosyası',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$fileName dosyası ikili (binary) AutoCAD formatındadır.',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 %100 Çevrimdışı Açma İpucu:',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'AutoCAD, Netcad veya IdeCAD içinde:\n'
                    'Dosya > Farklı Kaydet > ".DXF" seçeneğini kullanarak kaydettiğinizde, projeniz telefonunuzda internetsiz ve saniyede sıfır bekleme ile doğrudan GPU donanımında açılır.',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ayrıca ana menüdeki "DWG / CAD Proje Aç" ekranından sunucu destekli otomatik DWG dönüştürücüyü de dilediğiniz zaman kullanabilirsiniz.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isViewingDrawing = false;
              });
            },
            child: const Text('Anladım', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openDemoPlan();
            },
            child: const Text('Örnek Planı Gör'),
          ),
        ],
      ),
    );
  }

  void _openDemoPlan() {
    setState(() {
      _isViewingDrawing = true;
      _activeDrawingName = 'HASAN AKTAŞ STATİK (DEMO)';
    });
    _webViewController?.runJavaScript('window.loadDemoPlan();');
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
      return Scaffold(
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
                    'İnternetsiz Yerel GPU Motoru',
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
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF38BDF8)),
                      SizedBox(height: 14),
                      Text(
                        'Vektörler çözümleniyor...',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
              'Çevrimdışı CAD Motoru',
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
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Cihaz İçi Sıfır-Sunucu WebGL',
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
                      'Sıfır Sunucu, %100 Çevrimdışı',
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
                      'Çizimleriniz internete veya sunucuya gönderilmez. '
                      'Tamamen telefonunuzun kendi GPU çipinde donanım hızlandırmasıyla çalışır.',
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
                          'Cihazdan CAD Dosyası Aç (.dwg / .dxf)',
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
                          'Örnek Statik Projeyi Canlı Test Et',
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
                          'Henüz yerel bir çizim açılmadı',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cihazınızdaki .dxf çizimlerini açtığınızda burada hızlı erişim için listelenecektir.',
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildPanelGlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: () => _openLocalFile(f.dosyaYolu, f.dosyaAdi),
                      child: Row(
                        children: [
                          _buildPanelGlassIconBadge(
                            icon: Icons.architecture_rounded,
                            accentColor: const Color(0xFF0F7C86),
                            size: 42,
                            iconSize: 22,
                            borderRadius: 12,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.dosyaAdi,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
