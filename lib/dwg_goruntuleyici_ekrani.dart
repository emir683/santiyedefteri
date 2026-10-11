import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cad_intent_service.dart';

/// CAD Ölçüm Modları
enum CadMeasureMode {
  none,
  distance,
  area,
  calibrate,
}

/// CAD Tuval Etkileşim Modu (Nokta koyma veya Çizimi kaydırma/zoom)
enum CadInteractionMode {
  measure,
  pan,
}

/// CAD Pafta Ölçek Tanımı
class CadScalePreset {
  final String label;
  final double ratio;
  final double metersPerDocUnit;

  const CadScalePreset(this.label, this.ratio, this.metersPerDocUnit);
}

/// Tamamlanmış veya aktif CAD Ölçüm Kaydı
class CadMeasurement {
  final String id;
  final CadMeasureMode type;
  final List<Offset> docPoints;
  final double metersPerDocUnit;
  final Color color;
  final String label;

  CadMeasurement({
    required this.id,
    required this.type,
    required this.docPoints,
    required this.metersPerDocUnit,
    this.color = const Color(0xFF38BDF8),
    this.label = '',
  });
}

/// Önbelleğe kaydedilen ve dönüştürülmüş CAD projeleri
class SavedCadProject {
  final String id;
  final String fileName;
  final String pdfPath;
  final String? originalFilePath;
  final int fileSize;
  final DateTime savedAt;
  final int? detectedScale;
  final String? detectedScaleSource;

  SavedCadProject({
    required this.id,
    required this.fileName,
    required this.pdfPath,
    this.originalFilePath,
    required this.fileSize,
    required this.savedAt,
    this.detectedScale,
    this.detectedScaleSource,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'pdfPath': pdfPath,
        'originalFilePath': originalFilePath,
        'fileSize': fileSize,
        'savedAt': savedAt.toIso8601String(),
        'detectedScale': detectedScale,
        'detectedScaleSource': detectedScaleSource,
      };

  factory SavedCadProject.fromJson(Map<String, dynamic> json) =>
      SavedCadProject(
        id: json['id'] as String? ?? '',
        fileName: json['fileName'] as String? ?? 'Çizim',
        pdfPath: json['pdfPath'] as String? ?? '',
        originalFilePath: json['originalFilePath'] as String?,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
        detectedScale: (json['detectedScale'] as num?)?.toInt(),
        detectedScaleSource: json['detectedScaleSource'] as String?,
      );
}

class DwgGoruntuleyiciEkrani extends StatefulWidget {
  static bool isScreenActive = false;
  final String? initialDwgUrl;
  final String? initialProjeAdi;
  final String? initialLocalFilePath;
  final String? initialFileName;

  const DwgGoruntuleyiciEkrani({
    super.key,
    this.initialDwgUrl,
    this.initialProjeAdi,
    this.initialLocalFilePath,
    this.initialFileName,
  });

  @override
  State<DwgGoruntuleyiciEkrani> createState() => _DwgGoruntuleyiciEkraniState();
}

class _DwgGoruntuleyiciEkraniState extends State<DwgGoruntuleyiciEkrani>
    with SingleTickerProviderStateMixin {
  // Oracle Cloud üzerinde çalışan özel CAD Vektör sunucumuz
  static const String _kCadServerUrl =
      'https://durham-recommended-processing-seconds.trycloudflare.com';

  bool _isLoading = false;
  int _loadingStep = 1;
  String? _errorMessage;
  late String _currentTitle;
  Uint8List? _pdfBytes;
  String? _localPdfPath;
  bool _isPaperMode = false;
  File? _lastSelectedFile;
  PDFViewController? _pdfViewController;
  double _currentXOffset = 0.0;
  double _currentYOffset = 0.0;
  final ValueNotifier<double> _currentScaleNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<Map<String, double>> _minimapNotifier =
      ValueNotifier<Map<String, double>>({
    'xOffset': 0.0,
    'yOffset': 0.0,
    'scale': 1.0,
    'docW': 1000.0,
    'docH': 1000.0,
  });
  Size _docPageSize = const Size(1000, 1000);
  bool _isMinimapExpanded = true;

  // CAD Ölçüm Araçları Durumları
  CadMeasureMode _measureMode = CadMeasureMode.none;
  final List<CadMeasurement> _completedMeasurements = [];
  List<Offset> _activeDocPoints = [];
  double _metersPerDocUnit = 0.0352778; // 1:100 Varsayılan ölçek (1 pt = 0.0352778 m)
  String _currentScaleLabel = '1:100';
  int? _autoDetectedScale;
  String? _autoDetectedSource;
  int? _draggingPointIndex;
  final ValueNotifier<int> _measureRepaintNotifier = ValueNotifier<int>(0);

  // Basılı Tutma, Sol Üst Büyüteç & Mıknatıslı OSNAP Hedefleme Durumları
  bool _isAiming = false;
  Offset? _aimScreenPos;
  Offset? _aimDocPos;
  bool _isSnapped = false;
  String _snapLabel = '';
  Offset? _snapGuideStartScreen;
  Offset? _snapGuideEndScreen;
  Timer? _holdTimer;
  Offset? _pointerDownScreenPos;
  Offset? _lastPanScreenPos;
  bool _hasMovedFar = false;
  ui.Image? _cachedLoupeImage;
  bool _isGeneratingLoupeImage = false;
  ui.Image? _cachedScreenshotImage;
  bool _isCapturingScreenshot = false;
  Size _capturedScreenSize = Size.zero;

  double get _effectiveScale =>
      _currentScaleNotifier.value > 0 ? _currentScaleNotifier.value : 1.0;

  String _loadingStatusText = 'Proje Yükleniyor...';
  String _loadingSubText = 'Çizim dosyası hazırlanıyor';

  late AnimationController _animController;

  // Sunucumuzdaki hazır örnek CAD çizimleri
  static const List<Map<String, String>> _hazirOrnekler = [
    {
      'ad': 'Gerçek Şantiye DWG Projesi',
      'url': '$_kCadServerUrl/files/gercek-dwg-projesi.pdf',
      'aciklama': 'Kapsamlı kalıp ve mimari uygulama paftası',
      'boyut': '25 Pafta • 15.2 MB',
    },
    {
      'ad': 'Mimari Kat Planı',
      'url': '$_kCadServerUrl/files/sample-plan.pdf',
      'aciklama': 'Mimari salon, oda, kapı, pencere ve kot ölçüleri',
      'boyut': 'Kat Planı • 2.1 MB',
    },
    {
      'ad': 'Statik Taşıyıcı Planı',
      'url': '$_kCadServerUrl/files/sample-statik.pdf',
      'aciklama': 'Akslar, kolon aplikasyon, kirişler ve kalıp detayları',
      'boyut': 'Statik • 1.8 MB',
    },
  ];

  List<SavedCadProject> _savedProjects = [];
  StreamSubscription<CadFilePayload>? _cadStreamSub;

  @override
  void initState() {
    super.initState();
    DwgGoruntuleyiciEkrani.isScreenActive = true;
    _currentTitle = widget.initialProjeAdi ?? 'DWG / DXF Görüntüleyici';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _loadSavedProjects();

    // WhatsApp veya dosya yöneticisinden ekran açıkken gelen yeni dosyaları dinle
    _cadStreamSub = CadIntentService.instance.fileStream.listen((payload) {
      _hariciDosyayiAcVeYukle(payload.filePath, payload.fileName);
    });

    // Harici dosya yolu verilmişse doğrudan aç ve işle
    if (widget.initialLocalFilePath != null &&
        widget.initialLocalFilePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hariciDosyayiAcVeYukle(
          widget.initialLocalFilePath!,
          widget.initialFileName ?? 'Proje Çizimi.dwg',
        );
      });
    } else if (widget.initialDwgUrl != null &&
        widget.initialDwgUrl!.isNotEmpty) {
      _dwgUrlDonusturVeYukle(widget.initialDwgUrl!);
    }
    // Varsayılan proje otomatik açılmaz; kullanıcı doğrudan modern CAD çalışma alanını görür.
  }

  @override
  void dispose() {
    DwgGoruntuleyiciEkrani.isScreenActive = false;
    _cadStreamSub?.cancel();
    _holdTimer?.cancel();
    _animController.dispose();
    _currentScaleNotifier.dispose();
    _minimapNotifier.dispose();
    _measureRepaintNotifier.dispose();
    super.dispose();
  }

  /// Yerel hafızaya kaydedilmiş önbellek projelerini yükler
  Future<void> _loadSavedProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_cad_projects_list') ?? [];
      final List<SavedCadProject> loaded = [];
      for (final raw in list) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final proj = SavedCadProject.fromJson(map);
          if (File(proj.pdfPath).existsSync()) {
            loaded.add(proj);
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _savedProjects = loaded;
        });
      }
    } catch (e) {
      debugPrint('Kayıtlı CAD projeleri yüklenemedi: $e');
    }
  }

  /// Yerel PDF içerisindeki vektör metinlerinden Antet ve Mimari Ölçeği tespit eder
  int? _detectScaleFromPdf(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      final text = latin1.decode(bytes, allowInvalid: true);

      // 1. Antet ibaresi taraması: "ÖLÇEK: 1/50", "ÖLÇEK 1:100", "SCALE: 1/200"
      final explicitRegex = RegExp(
        r'(?:OLCEK|ÖLÇEK|SCALE|ölçek|Ölçek)\s*[:=]?\s*1\s*[\/:\s]\s*(\d+)',
        caseSensitive: false,
      );
      final matches = explicitRegex.allMatches(text);
      final Map<int, int> counts = {};
      for (final m in matches) {
        final ratio = int.tryParse(m.group(1) ?? '');
        if (ratio != null && [20, 50, 100, 200, 500, 1000].contains(ratio)) {
          counts[ratio] = (counts[ratio] ?? 0) + 5;
        }
      }

      // 2. Genel ölçek kalıpları: "1/50", "1/100", "1/200", "1/20"
      final genericRegex = RegExp(r'\b1\s*[\/:]\s*(20|50|100|200|500|1000)\b');
      final genMatches = genericRegex.allMatches(text);
      for (final m in genMatches) {
        final ratio = int.tryParse(m.group(1) ?? '');
        if (ratio != null) {
          counts[ratio] = (counts[ratio] ?? 0) + 1;
        }
      }

      if (counts.isNotEmpty) {
        int best = 100;
        int maxCount = 0;
        counts.forEach((ratio, c) {
          if (c > maxCount) {
            maxCount = c;
            best = ratio;
          }
        });
        return best;
      }
    } catch (_) {}
    return null;
  }

  /// Başarıyla dönüştürülen çizimi cihazda kalıcı önbelleğe kaydeder
  Future<void> _saveProjectToHistory({
    required String fileName,
    required String pdfPath,
    String? originalFilePath,
    required int fileSize,
    int? detectedScale,
    String? detectedScaleSource,
  }) async {
    try {
      final newProj = SavedCadProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        pdfPath: pdfPath,
        originalFilePath: originalFilePath,
        fileSize: fileSize,
        savedAt: DateTime.now(),
        detectedScale: detectedScale,
        detectedScaleSource: detectedScaleSource,
      );

      _savedProjects.removeWhere(
          (p) => p.fileName.toLowerCase() == fileName.toLowerCase());
      _savedProjects.insert(0, newProj);

      final prefs = await SharedPreferences.getInstance();
      final stringList =
          _savedProjects.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('saved_cad_projects_list', stringList);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Proje geçmişe kaydedilemedi: $e');
    }
  }

  /// Kaydedilen bir projeyi önbellekten ve listeden siler
  Future<void> _kayitliProjeyiSil(SavedCadProject project) async {
    try {
      final f = File(project.pdfPath);
      if (await f.exists()) {
        await f.delete();
      }
      _savedProjects.removeWhere((p) => p.id == project.id);
      final prefs = await SharedPreferences.getInstance();
      final stringList =
          _savedProjects.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('saved_cad_projects_list', stringList);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${project.fileName} önbellekten kaldırıldı.'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Proje silinirken hata: $e');
    }
  }

  /// Daha önceden işlenmiş projeyi ANINDA (sunucuya gitmeden) açar
  void _kayitliProjeyiAc(SavedCadProject project, {bool isInstant = false}) {
    if (!File(project.pdfPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıtlı çizim dosyası bulunamadı, yeniden işlenecek.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      _kayitliProjeyiSil(project);
      return;
    }

    final autoRatio = project.detectedScale ?? _detectScaleFromPdf(project.pdfPath);
    if (autoRatio != null) {
      _metersPerDocUnit = 0.000352778 * autoRatio;
      _currentScaleLabel = '1:$autoRatio';
      _autoDetectedScale = autoRatio;
      _autoDetectedSource = project.detectedScaleSource ?? 'Antet / Çizim Metinleri';
    } else {
      _metersPerDocUnit = 0.0352778;
      _currentScaleLabel = '1:100';
      _autoDetectedScale = null;
      _autoDetectedSource = null;
    }

    setState(() {
      _currentTitle = project.fileName;
      _localPdfPath = project.pdfPath;
      _pdfBytes = null;
      _lastSelectedFile = project.originalFilePath != null
          ? File(project.originalFilePath!)
          : null;
      _isLoading = false;
      _errorMessage = null;
      _currentScaleNotifier.value = 1.0;
    });

    _prepareLoupeImage();

    if (isInstant && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${project.fileName} yerel önbellekten anında açıldı ⚡',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );
    }
  }

  /// Dosyanın önbellekte olup olmadığını kontrol edip varsa anında açar
  Future<bool> _checkAndOpenFromCache(String fileName, {int? fileSize}) async {
    for (final proj in _savedProjects) {
      if (proj.fileName.toLowerCase() == fileName.toLowerCase()) {
        final f = File(proj.pdfPath);
        if (await f.exists()) {
          _kayitliProjeyiAc(proj, isInstant: true);
          return true;
        }
      }
    }
    return false;
  }

  /// Harici (WhatsApp vb.) gelen dosyayı işleme
  Future<void> _hariciDosyayiAcVeYukle(String filePath, String fileName) async {
    final file = File(filePath);
    if (!await file.exists()) {
      setState(() {
        _errorMessage = 'Paylaşılan dosya bulunamadı: $fileName';
        _isLoading = false;
      });
      return;
    }

    _lastSelectedFile = file;

    final isCached =
        await _checkAndOpenFromCache(fileName, fileSize: await file.length());
    if (isCached) return;

    await _sunucuyaGonderVeDonustur(file, fileName);
  }

  /// Açık olan projeyi kapatıp CAD çalışma alanına döner
  void _dosyayiKapat() {
    setState(() {
      _localPdfPath = null;
      _pdfBytes = null;
      _lastSelectedFile = null;
      _errorMessage = null;
      _isLoading = false;
      _loadingStep = 1;
      _currentTitle = 'DWG / DXF Görüntüleyici';
      _currentScaleNotifier.value = 1.0;
      _measureMode = CadMeasureMode.none;
      _autoDetectedScale = null;
      _autoDetectedSource = null;
      _activeDocPoints.clear();
      _completedMeasurements.clear();
      _draggingPointIndex = null;
      _isAiming = false;
      _aimScreenPos = null;
      _aimDocPos = null;
      _isSnapped = false;
      _snapLabel = '';
      _snapGuideStartScreen = null;
      _snapGuideEndScreen = null;
      _cachedLoupeImage = null;
      _cachedScreenshotImage = null;
      _holdTimer?.cancel();
    });
  }

  /// Uzak DWG URL'sini indirip sunucuya aktarır
  Future<void> _dwgUrlDonusturVeYukle(String url) async {
    setState(() {
      _isLoading = true;
      _loadingStep = 1;
      _errorMessage = null;
      _loadingStatusText = 'Proje Dosyası Yükleniyor...';
      _loadingSubText = 'Çizim dosyası güvenli şekilde aktarılıyor';
    });

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        final tempFile = File(
            '${tempDir.path}/proje_${DateTime.now().millisecondsSinceEpoch}.dwg');
        await tempFile.writeAsBytes(res.bodyBytes);
        _lastSelectedFile = tempFile;

        await _sunucuyaGonderVeDonustur(tempFile, 'Proje Çizimi.dwg');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Çizim dosyası indirilemedi (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bağlantı hatası: $e';
      });
    }
  }

  /// Vektörel PDF dosyasını sunucudan indirip kalıcı önbelleğe kaydeder ve tuvalde açar
  Future<void> _ornekYukle(
    String url,
    String ad, {
    String? originalFilePath,
    int? fileSize,
    int? detectedScale,
    String? detectedScaleSource,
  }) async {
    setState(() {
      _isLoading = true;
      _loadingStep = 2;
      _errorMessage = null;
      _currentTitle = ad;
      _loadingStatusText = 'Proje Yükleniyor...';
      _loadingSubText = 'Sunucularımızda işleniyor ve tuvale aktarılıyor';
    });

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final appDocs = await getApplicationDocumentsDirectory();
        final cadCacheDir = Directory('${appDocs.path}/cad_cache');
        if (!await cadCacheDir.exists()) {
          await cadCacheDir.create(recursive: true);
        }

        final safeName = ad.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final permanentPdf = File(
            '${cadCacheDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName.pdf');
        await permanentPdf.writeAsBytes(res.bodyBytes);

        final actualSize = fileSize ?? res.bodyBytes.length;

        // Otomatik ölçek belirleme (Sunucu dönüşü veya yerel PDF taraması)
        final autoRatio = detectedScale ?? _detectScaleFromPdf(permanentPdf.path);
        if (autoRatio != null) {
          _metersPerDocUnit = 0.000352778 * autoRatio;
          _currentScaleLabel = '1:$autoRatio';
          _autoDetectedScale = autoRatio;
          _autoDetectedSource = detectedScaleSource ?? 'Antet / Çizim Metinleri';
        } else {
          _metersPerDocUnit = 0.0352778;
          _currentScaleLabel = '1:100';
          _autoDetectedScale = null;
          _autoDetectedSource = null;
        }

        await _saveProjectToHistory(
          fileName: ad,
          pdfPath: permanentPdf.path,
          originalFilePath: originalFilePath,
          fileSize: actualSize,
          detectedScale: _autoDetectedScale,
          detectedScaleSource: _autoDetectedSource,
        );

        setState(() {
          _loadingStep = 3;
          _loadingStatusText = 'Çizim Hazırlanıyor...';
          _loadingSubText = 'Yüksek çözünürlüklü CAD tuvali oluşturuluyor';
        });

        await Future.delayed(const Duration(milliseconds: 300));

        setState(() {
          _pdfBytes = res.bodyBytes;
          _localPdfPath = permanentPdf.path;
          _isLoading = false;
        });

        _prepareLoupeImage();

        if (_autoDetectedScale != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.architecture_rounded,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paftadan otomatik ölçek algılandı: 1:$_autoDetectedScale ($_autoDetectedSource) ✓',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Örnek çizim sunucudan alınamadı (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bağlantı hatası: $e';
      });
    }
  }

  /// Ekranın tam ortasına doğru odaklı akıllı büyütme (Center Zoom In - Sınırsız Zoom)
  Future<void> _zoomIn() async {
    if (_pdfViewController == null) return;
    final scale = _currentScaleNotifier.value;
    final newScale = (scale * 1.6).clamp(0.1, 100000.0);
    if ((newScale - scale).abs() < 0.01) return;

    final media = MediaQuery.of(context).size;
    final screenW = media.width;
    final screenH = media.height - kToolbarHeight;
    final ratio = newScale / (scale == 0 ? 1 : scale);

    final targetX = screenW / 2 - (screenW / 2 - _currentXOffset) * ratio;
    final targetY = screenH / 2 - (screenH / 2 - _currentYOffset) * ratio;

    await _pdfViewController!.setScale(newScale);
    await _pdfViewController!.setPosition(Offset(targetX, targetY));
    _currentScaleNotifier.value = newScale;
  }

  /// Ekranın tam ortasına doğru odaklı akıllı küçültme (Center Zoom Out)
  Future<void> _zoomOut() async {
    if (_pdfViewController == null) return;
    final scale = _currentScaleNotifier.value;
    final newScale = (scale / 1.6).clamp(0.1, 100000.0);
    if ((newScale - scale).abs() < 0.01) return;

    final media = MediaQuery.of(context).size;
    final screenW = media.width;
    final screenH = media.height - kToolbarHeight;
    final ratio = newScale / (scale == 0 ? 1 : scale);

    final targetX = screenW / 2 - (screenW / 2 - _currentXOffset) * ratio;
    final targetY = screenH / 2 - (screenH / 2 - _currentYOffset) * ratio;

    await _pdfViewController!.setScale(newScale);
    await _pdfViewController!.setPosition(Offset(targetX, targetY));
    _currentScaleNotifier.value = newScale;
  }

  /// Belirlenen kesin zoom seviyesine git (Sınırsız)
  Future<void> _setZoomLevel(double targetScale) async {
    if (_pdfViewController == null) return;
    final scale = _currentScaleNotifier.value;
    final clamped = targetScale.clamp(0.1, 100000.0);
    final media = MediaQuery.of(context).size;
    final screenW = media.width;
    final screenH = media.height - kToolbarHeight;
    final ratio = clamped / (scale == 0 ? 1 : scale);

    final targetX = screenW / 2 - (screenW / 2 - _currentXOffset) * ratio;
    final targetY = screenH / 2 - (screenH / 2 - _currentYOffset) * ratio;

    await _pdfViewController!.setScale(clamped);
    await _pdfViewController!.setPosition(Offset(targetX, targetY));
    _currentScaleNotifier.value = clamped;
  }

  Future<void> _zoomReset() async {
    if (_pdfViewController == null) return;
    await _pdfViewController!.setScale(1.0);
    await _pdfViewController!.setPosition(Offset.zero);
    _currentScaleNotifier.value = 1.0;
  }

  /// Cihazdan DWG/DXF dosyasını seçip Oracle Cloud sunucusunda Vektörel PDF'e dönüştürür
  Future<void> _cihazdanDwgSecVeYukle() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      _lastSelectedFile = file;

      // Önce daha önce kaydedilmiş/dönüştürülmüş mü kontrol et
      final isCached =
          await _checkAndOpenFromCache(fileName, fileSize: await file.length());
      if (isCached) return;

      await _sunucuyaGonderVeDonustur(file, fileName);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Dosya seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _sunucuyaGonderVeDonustur(File file, String fileName) async {
    setState(() {
      _isLoading = true;
      _loadingStep = 1;
      _errorMessage = null;
      _currentTitle = fileName;
      _loadingStatusText = 'Proje Yükleniyor...';
      _loadingSubText = 'Çizim dosyası sunucumuza aktarılıyor';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_kCadServerUrl/api/convert'),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      setState(() {
        _loadingStep = 2;
        _loadingStatusText = 'Sunucularda İşleniyor...';
        _loadingSubText = 'Vektörel katmanlar ve paftalar optimize ediliyor';
      });

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        String? pdfUrl = data['pdfUrl'] as String?;
        int? detectedScale = (data['detectedScale'] as num?)?.toInt();
        String? detectedScaleSource = data['detectedScaleSource'] as String?;

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          if (pdfUrl.startsWith('/')) {
            pdfUrl = '$_kCadServerUrl$pdfUrl';
          } else if (pdfUrl.contains('localhost')) {
            pdfUrl = pdfUrl.replaceFirst(
                RegExp(r'https?://localhost(:\d+)?'), _kCadServerUrl);
          }

          setState(() {
            _loadingStep = 3;
            _loadingStatusText = 'Çizim Hazırlanıyor...';
            _loadingSubText = 'Yüksek çözünürlüklü CAD tuvali oluşturuluyor';
          });
          await _ornekYukle(
            pdfUrl,
            fileName,
            originalFilePath: file.path,
            fileSize: await file.length(),
            detectedScale: detectedScale,
            detectedScaleSource: detectedScaleSource,
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Sunucu işlemi tamamladı ancak çizim çıktısı üretilemedi. Lütfen dosyanın bozuk olmadığından emin olun.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sunucu hatası (${streamedResponse.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Dosya işlenirken hata oluştu: $e';
      });
    }
  }

  /// Harici DWG FastView / AutoCAD uygulamasıyla aç
  Future<void> _hariciUygulamadaAc() async {
    if (_lastSelectedFile != null && await _lastSelectedFile!.exists()) {
      await Share.shareXFiles(
        [XFile(_lastSelectedFile!.path)],
        text: '$_currentTitle CAD Çizimi',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Harici uygulamayla paylaşmak için lütfen cihazınızdan bir DWG/DXF dosyası seçin.',
          ),
          backgroundColor: const Color(0xFF0F172A),
          action: SnackBarAction(
            label: 'Dosya Seç',
            textColor: const Color(0xFF10B981),
            onPressed: _cihazdanDwgSecVeYukle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLoadedProject = _localPdfPath != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: hasLoadedProject
          ? const Color(0xFF090D14)
          : (isDark ? const Color(0xFF0C1017) : const Color(0xFFF1F5F8)),
      appBar: _buildAppBar(hasLoadedProject),
      body: Stack(
        children: [
          // 1. ANA ÇALIŞMA ALANI (PROJE AÇIK DEĞİLSE MODERN CAD ÇALIŞMA ALANI, AÇIKSA VEKTÖR ÇİZİM)
          if (!hasLoadedProject && !_isLoading)
            _buildEmptyWorkspaceHub()
          else if (hasLoadedProject)
            _buildCadCanvas(),

          // 1.5 ÖLÇÜM KATMANI (VEKTÖREL ÇİZİMİN ÜZERİNE OTURAN AKILLI ÇİZİM & ETKİLEŞİM TABAKASI)
          if (hasLoadedProject && !_isLoading && _errorMessage == null)
            _buildMeasureInteractiveLayer(),

          // 2. PROJE RADARI / MİNİMAP (Yalnızca proje açıkken)
          if (hasLoadedProject && !_isLoading && _errorMessage == null)
            Positioned(
              top: _measureMode != CadMeasureMode.none ? 94 : 14,
              right: 14,
              child: _buildCadMinimap(),
            ),

          // 3. ZOOM KONTROL PANELİ (+, -, Hızlı Presetler: 1x, 25x, 150x, 500x, 2000x)
          if (hasLoadedProject && !_isLoading && _errorMessage == null)
            Positioned(
              left: 16,
              bottom: 24,
              child: _buildZoomControlPanel(),
            ),

          // 3.5 CAD ÖLÇÜM TOOLBARI (Mesafe / Alan / Ölçek / Geri Al / Temizle)
          // 3.5 CAD ÖLÇÜM TOOLBARI (Mesafe / Alan / Ölçek / Geri Al / Temizle)
          if (hasLoadedProject &&
              !_isLoading &&
              _errorMessage == null &&
              _measureMode != CadMeasureMode.none) ...[
            if (!_isAiming)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _buildMeasureFloatingToolbar(),
              ),
            if (_isAiming)
              _buildQuickMeasureControls(),
          ],

          // 3.6 HASSAS BÜYÜTEÇ (LOUPE) - Ekran görüntüsündeki gibi beyaz çerçeveli gerçek CAD büyüteci
          if (hasLoadedProject &&
              _measureMode != CadMeasureMode.none &&
              _isAiming &&
              _aimScreenPos != null)
            _buildTopLeftLoupeWidget(),

          // 4. PREMİUM CAD YÜKLEME EKRANI (Kullanıcı dostu, animasyonlu)
          if (_isLoading)
            _buildLoadingOverlay(),

          // 5. HATA EKRANI
          if (_errorMessage != null && !_isLoading)
            _buildErrorOverlay(),
        ],
      ),
    );
  }

  /// Uygulama Temasıyla Uyumlu Üst Bar
  PreferredSizeWidget _buildAppBar(bool hasLoadedProject) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = hasLoadedProject
        ? const Color(0xFF0D131F)
        : (isDark ? const Color(0xFF0F172A) : Colors.white);

    final titleColor = hasLoadedProject
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    final iconColor = hasLoadedProject
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF1E293B));

    return AppBar(
      backgroundColor: bgColor,
      elevation: hasLoadedProject ? 0 : 0.5,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 20),
        onPressed: () {
          if (hasLoadedProject) {
            _dosyayiKapat();
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasLoadedProject
                      ? const Color(0xFF10B981)
                      : const Color(0xFF26A69A),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  hasLoadedProject
                      ? 'Vektörel Çizim Aktif • Sınırsız Zoom'
                      : 'CAD Çizim Görüntüleyici',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasLoadedProject
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (hasLoadedProject) ...[
          // YENİ DOSYA SEÇ BUTONU
          IconButton(
            icon: const Icon(Icons.folder_open_rounded,
                color: Color(0xFF38BDF8), size: 22),
            tooltip: 'Yeni Dosya Aç',
            onPressed: _cihazdanDwgSecVeYukle,
          ),
          // CETVEL & ALAN ÖLÇÜM ARACI
          IconButton(
            icon: Icon(
              Icons.square_foot_rounded,
              color: _measureMode != CadMeasureMode.none
                  ? const Color(0xFF10B981)
                  : Colors.white70,
              size: 22,
            ),
            tooltip: _measureMode != CadMeasureMode.none
                ? 'Ölçüm Modunu Kapat'
                : 'Mesafe & Alan Ölçümü',
            onPressed: _toggleMeasurementMode,
          ),
          // KAĞIT / KARANLIK MOD
          IconButton(
            icon: Icon(
              _isPaperMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: _isPaperMode ? const Color(0xFFF59E0B) : Colors.white70,
              size: 21,
            ),
            tooltip: _isPaperMode ? 'Karanlık CAD Modu' : 'Beyaz Pafta Modu',
            onPressed: () {
              setState(() {
                _isPaperMode = !_isPaperMode;
              });
            },
          ),
          // HARİCİ PAYLAŞIM
          IconButton(
            icon: const Icon(Icons.share_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'AutoCAD / FastView ile Aç',
            onPressed: _hariciUygulamadaAc,
          ),
          // PROJEYİ KAPAT
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white70, size: 22),
            tooltip: 'Projeyi Kapat',
            onPressed: _dosyayiKapat,
          ),
        ] else ...[
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 21),
            tooltip: 'Nasıl Kullanılır?',
            onPressed: _showHelpDialog,
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  /// Uygulama tasarım diliyle uyumlu modern CAD Çalışma Alanı Hub'ı
  Widget _buildEmptyWorkspaceHub() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131B2A) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HERO KART: DOĞRUDAN CİHAZDAN PROJE AÇ
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                    : const [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF26A69A).withValues(alpha: 0.35)
                    : const Color(0xFF26A69A).withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF26A69A).withValues(alpha: 0.2),
                        const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF26A69A),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.architecture_rounded,
                    color: Color(0xFF26A69A),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'CAD Çizim Görüntüleyici',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Şantiye projelerinizi, mimari ve statik paftalarınızı sınırsız yakınlaştırmayla, hiçbir detayı kaçırmadan inceleyin.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: subtitleColor,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cihazdanDwgSecVeYukle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26A69A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 22),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'DWG / DXF Dosyası Seç & Aç',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFormatBadge('AutoCAD .DWG', isDark),
                    _buildFormatBadge('Vektör .DXF', isDark),
                    _buildFormatBadge('Sınırsız Zoom', isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. SON AÇILAN VE DÖNÜŞTÜRÜLMÜŞ PROJELER BÖLÜMÜ (ÖNBELLEK)
          if (_savedProjects.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Son Açılan Çizimler',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_savedProjects.length} Çizim • Anında Açılır ⚡',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._savedProjects.map((proj) {
              final String boyutStr = _formatBytes(proj.fileSize);
              final String tarihStr = _formatTarih(proj.savedAt);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    proj.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tarihStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: subtitleColor,
                          ),
                        ),
                        Text('•',
                            style: TextStyle(
                                color: subtitleColor, fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '$boyutStr • Hazır ⚡',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: Color(0xFFEF4444)),
                        tooltip: 'Önbellekten Sil',
                        onPressed: () => _kayitliProjeyiSil(proj),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: subtitleColor,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _kayitliProjeyiAc(proj, isInstant: true),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // 3. HAZIR ÖRNEK PROJELER BÖLÜMÜ
          Row(
            children: [
              const Icon(Icons.folder_special_rounded,
                  color: Color(0xFF26A69A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Örnek CAD Projeleri',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_hazirOrnekler.length} Örnek',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ..._hazirOrnekler.map((ornek) {
            final String ad = ornek['ad']!;
            final String aciklama = ornek['aciklama']!;
            final String boyut = ornek['boyut']!;

            IconData ornekIcon = Icons.architecture_rounded;
            Color iconColor = const Color(0xFF26A69A);

            if (ad.contains('Gerçek')) {
              ornekIcon = Icons.apartment_rounded;
              iconColor = const Color(0xFF38BDF8);
            } else if (ad.contains('Mimari')) {
              ornekIcon = Icons.meeting_room_rounded;
              iconColor = const Color(0xFF10B981);
            } else if (ad.contains('Statik')) {
              ornekIcon = Icons.grid_4x4_rounded;
              iconColor = const Color(0xFFFFB74D);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    ornekIcon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aciklama,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          boyut,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF1F5F9),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: subtitleColor,
                    size: 14,
                  ),
                ),
                onTap: () => _ornekYukle(ornek['url']!, ad),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ÖZELLİK VİTRİNİ
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  Icons.zoom_in_rounded,
                  'Sınırsız Odaklı Yakınlaştırma',
                  'En ufak donatı çapı (Ø), kot ve kesit yazılarını kayıpsız okuyun.',
                  isDark,
                ),
                Divider(color: cardBorder, height: 22),
                _buildFeatureRow(
                  Icons.radar_rounded,
                  'Kuşbakışı Radar (Minimap)',
                  'Dev paftalarda projenin neresinde olduğunuzu anlık görün.',
                  isDark,
                ),
                Divider(color: cardBorder, height: 22),
                _buildFeatureRow(
                  Icons.layers_rounded,
                  'Kayıpsız Vektörel Çizim',
                  'Model ve pafta alanındaki tüm çizgiler AutoCAD hassasiyetiyle görüntülenir.',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTarih(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Az önce' : '${diff.inMinutes} dk önce';
    }
    if (diff.inHours < 24 && dt.day == now.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Bugün $hour:$min';
    }
    const aylar = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];
    final gun = dt.day;
    final ay = dt.month <= 12 ? aylar[dt.month] : '';
    final saat = dt.hour.toString().padLeft(2, '0');
    final dakika = dt.minute.toString().padLeft(2, '0');
    return '$gun $ay, $saat:$dakika';
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF26A69A).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF26A69A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Native Vektörel CAD Çizim Alanı
  Widget _buildCadCanvas() {
    if (Platform.isAndroid || Platform.isIOS) {
      return Container(
        color: _isPaperMode ? Colors.white : const Color(0xFF090D14),
        child: PDFView(
          key: ValueKey('$_localPdfPath-$_isPaperMode'),
          filePath: _localPdfPath!,
          minZoom: 0.1,
          maxZoom: 100000.0,
          enableAntialiasing: true,
          useBestQuality: true,
          enableRenderDuringScale: true,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageFling: false,
          pageSnap: false,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: true,
          backgroundColor:
              _isPaperMode ? Colors.white : const Color(0xFF090D14),
          onRender: (pages) async {
            if (_pdfViewController != null) {
              try {
                await _pdfViewController!.setZoomLimits(0.1, 50.0, 100000.0);
                final size = await _pdfViewController!.getCurrentPageSize();
                if (size.width > 0 && size.height > 0) {
                  _docPageSize = size;
                }
              } catch (_) {}
            }
            _prepareLoupeImage();
          },
          onLoadComplete: (pages) async {
            try {
              await _pdfViewController?.setZoomLimits(0.1, 50.0, 100000.0);
            } catch (_) {}
            _prepareLoupeImage();
          },
          onViewCreated: (controller) async {
            _pdfViewController = controller;
            try {
              const MethodChannel('com.emircf.santiyeyonetim/audio_control')
                  .invokeMethod('setPdfMaxZoom', {'maxZoom': 100000.0, 'minZoom': 0.1});
            } catch (_) {}
            await controller.setZoomLimits(0.1, 50.0, 100000.0);
          },
          onDraw: (xOffset, yOffset, scale) {
            _currentXOffset = xOffset;
            _currentYOffset = yOffset;
            _currentScaleNotifier.value = scale;
            _minimapNotifier.value = {
              'xOffset': xOffset,
              'yOffset': yOffset,
              'scale': scale,
              'docW': _docPageSize.width,
              'docH': _docPageSize.height,
            };
            _measureRepaintNotifier.value =
                (_measureRepaintNotifier.value + 1) % 1000000;
          },
        ),
      );
    } else {
      // Web / Masaüstü fallback
      return Container(
        color: _isPaperMode ? Colors.white : const Color(0xFF090D14),
        child: PdfPreview(
          build: (format) => _pdfBytes!,
          useActions: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: 24000,
          dpi: 400,
          scrollViewDecoration: BoxDecoration(
            color: _isPaperMode ? Colors.white : const Color(0xFF090D14),
          ),
          pdfFileName: '$_currentTitle.pdf',
          loadingWidget: const SizedBox.shrink(),
        ),
      );
    }
  }

  /// CAD Zoom Kontrol Paneli (Sınırsız Zoom)
  Widget _buildZoomControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ZOOM IN (+)
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            tooltip: 'Merkeze Yakınlaştır',
            onPressed: _zoomIn,
          ),

          // ANLIK ZOOM DEĞERİ (TIKLANINCA PRESET MENÜSÜ AÇILIR)
          GestureDetector(
            onTap: _showZoomPresetSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: _currentScaleNotifier,
                builder: (context, scale, _) {
                  return Text(
                    '${scale.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),

          // ZOOM OUT (-)
          IconButton(
            icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 24),
            tooltip: 'Merkezden Uzaklaştır',
            onPressed: _zoomOut,
          ),

          Container(
            width: 28,
            height: 1,
            color: Colors.white24,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),

          // FIT / RESET
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded, color: Colors.white70, size: 20),
            tooltip: 'Tam Ekrana Sığdır',
            onPressed: _zoomReset,
          ),
        ],
      ),
    );
  }

  /// Hızlı Zoom Seçim Menüsü
  void _showZoomPresetSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔍 Hızlı Zoom Seviyeleri',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Projeyi istediğiniz netlik seviyesine doğrudan ayarlayın:',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildZoomPresetChip('1x (Tam)', 1.0, ctx),
                  _buildZoomPresetChip('25x', 25.0, ctx),
                  _buildZoomPresetChip('150x', 150.0, ctx),
                  _buildZoomPresetChip('500x', 500.0, ctx),
                  _buildZoomPresetChip('2000x', 2000.0, ctx),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomPresetChip(String label, double scale, BuildContext ctx) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: const Color(0xFF38BDF8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      onPressed: () {
        Navigator.pop(ctx);
        _setZoomLevel(scale);
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  /// CAD Kuşbakışı Radar Minimap Widget'ı
  Widget _buildCadMinimap() {
    const double mapW = 124.0;
    const double mapH = 68.0;

    return Container(
      width: mapW,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, size: 13, color: Color(0xFF38BDF8)),
                const SizedBox(width: 5),
                const Text(
                  'RADAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMinimapExpanded = !_isMinimapExpanded;
                    });
                  },
                  child: Icon(
                    _isMinimapExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (_isMinimapExpanded)
            GestureDetector(
              onTapDown: (details) async {
                if (_pdfViewController == null) return;
                final tapX = details.localPosition.dx;
                final tapY = details.localPosition.dy;
                final media = MediaQuery.of(context).size;
                final screenW = media.width;
                final screenH = media.height - kToolbarHeight;

                final data = _minimapNotifier.value;
                final scale = data['scale'] ?? 1.0;
                final docW = data['docW'] ?? 24000.0;
                final docH = data['docH'] ?? 4895.0;

                final totalW = docW * scale;
                final totalH = docH * scale;

                final fracX = (tapX / mapW).clamp(0.0, 1.0);
                final fracY = (tapY / mapH).clamp(0.0, 1.0);

                final targetX = -(fracX * totalW - screenW / 2);
                final targetY = -(fracY * totalH - screenH / 2);

                await _pdfViewController!.setPosition(Offset(targetX, targetY));
              },
              child: SizedBox(
                height: mapH,
                child: ValueListenableBuilder<Map<String, double>>(
                  valueListenable: _minimapNotifier,
                  builder: (context, data, _) {
                    final media = MediaQuery.of(context).size;
                    final screenW = media.width;
                    final screenH = media.height - kToolbarHeight;

                    final xOffset = data['xOffset'] ?? 0.0;
                    final yOffset = data['yOffset'] ?? 0.0;
                    final scale = (data['scale'] ?? 1.0).clamp(0.1, 100000.0);
                    final docW = data['docW'] ?? 24000.0;
                    final docH = data['docH'] ?? 4895.0;

                    final totalW = docW * scale;
                    final totalH = docH * scale;

                    final leftFrac = (-xOffset / totalW).clamp(0.0, 1.0);
                    final topFrac = (-yOffset / totalH).clamp(0.0, 1.0);
                    final widthFrac = (screenW / totalW).clamp(0.03, 1.0);
                    final heightFrac = (screenH / totalH).clamp(0.03, 1.0);

                    final boxX = leftFrac * mapW;
                    final boxY = topFrac * mapH;
                    final boxW = (widthFrac * mapW).clamp(6.0, mapW);
                    final boxH = (heightFrac * mapH).clamp(6.0, mapH);

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BlueprintMinimapPainter(),
                          ),
                        ),
                        Positioned(
                          left: boxX.clamp(0.0, mapW - boxW),
                          top: boxY.clamp(0.0, mapH - boxH),
                          width: boxW,
                          height: boxH,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.28),
                              border: Border.all(
                                color: const Color(0xFFEF4444),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Kullanıcı Dostu, Animasyonlu ve Aşamalı Yükleme Ekranı
  Widget _buildLoadingOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Container(
        color: (isDark ? const Color(0xFF090D14) : const Color(0xFFF8FAFC))
            .withValues(alpha: 0.94),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF26A69A).withValues(alpha: 0.3)
                      : const Color(0xFF26A69A).withValues(alpha: 0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animasyonlu Blueprint / CAD Pergel & Radar
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final pulseScale = 1.0 + (_animController.value * 0.14);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Dış Nabız Halkası
                          Transform.scale(
                            scale: pulseScale,
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF26A69A).withValues(
                                    alpha: (1.0 - _animController.value)
                                        .clamp(0.0, 0.4),
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Dönen Çizim Halkası
                          Transform.rotate(
                            angle: _animController.value * 2 * 3.14159,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF38BDF8),
                                  width: 2.2,
                                ),
                              ),
                            ),
                          ),
                          // Merkez Mimari İkon
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF26A69A)
                                  .withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.architecture_rounded,
                              color: Color(0xFF26A69A),
                              size: 28,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Başlık & Açıklama
                  Text(
                    _loadingStatusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loadingSubText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Yumuşak İlerleme Çubuğu
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 220,
                      height: 5,
                      child: LinearProgressIndicator(
                        backgroundColor: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF26A69A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // 3 Aşamalı Süreç Göstergesi
                  Row(
                    children: [
                      Expanded(
                        child: _buildStepChip('1. Aktarım', _loadingStep >= 1, isDark),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12,
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      ),
                      Expanded(
                        child: _buildStepChip('2. İşleme', _loadingStep >= 2, isDark),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12,
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      ),
                      Expanded(
                        child: _buildStepChip('3. Çizim', _loadingStep >= 3, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepChip(String label, bool isCompletedOrActive, bool isDark) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isCompletedOrActive
            ? const Color(0xFF26A69A).withValues(alpha: 0.15)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompletedOrActive
              ? const Color(0xFF26A69A)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCompletedOrActive
              ? const Color(0xFF26A69A)
              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          fontSize: 11,
          fontWeight: isCompletedOrActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  /// Hata Ekranı Overlay'i
  Widget _buildErrorOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Container(
        color: (isDark ? const Color(0xFF090D14) : const Color(0xFFF8FAFC))
            .withValues(alpha: 0.95),
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2A) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Çizim Yüklenemedi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white70 : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _dosyayiKapat,
                      child: const Text('Geri Dön'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Dosya Seç'),
                      onPressed: _cihazdanDwgSecVeYukle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'CAD Görüntüleyici Rehberi',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          '• DWG ve DXF formatlarındaki mimari ve statik paftalarınızı cihazınızdan seçerek açabilirsiniz.\n\n'
          '• İki parmağınızla yakınlaştırıp uzaklaştırabilir veya sol alttaki panelden sınırsız seviyede büyütebilirsiniz.\n\n'
          '• Sağ üstteki Radar haritasına dokunarak projenin istediğiniz bölgesine anında atlayabilirsiniz.\n\n'
          '• Beyaz pafta modu ile kağıt çıktısı görünümüne geçebilirsiniz.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CAD ÖLÇÜM & KALİBRASYON ENGINE METODLARI
  // ==========================================

  Offset _docToScreen(Offset docPoint) {
    final scale = _effectiveScale;
    return Offset(
      _currentXOffset + docPoint.dx * scale,
      _currentYOffset + docPoint.dy * scale,
    );
  }

  Offset _screenToDoc(Offset screenPoint) {
    final scale = _effectiveScale;
    return Offset(
      (screenPoint.dx - _currentXOffset) / scale,
      (screenPoint.dy - _currentYOffset) / scale,
    );
  }

  /// Büyüteç için ekrandaki gerçek CAD çizimini anlık olarak piksel piksel yakalar (100% garantili ve anlık)
  Future<void> _captureLoupeScreenshot() async {
    if (_pdfViewController == null || _isCapturingScreenshot) return;
    _isCapturingScreenshot = true;
    try {
      final tempDir = await getTemporaryDirectory();
      final shotPath = '${tempDir.path}/cad_loupe_${DateTime.now().millisecondsSinceEpoch}.png';
      final path = await _pdfViewController!.getScreenshot(shotPath);
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          try {
            await file.delete();
          } catch (_) {}

          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          if (mounted) {
            final mediaQuery = MediaQuery.maybeOf(context);
            final screenSize = mediaQuery != null && mediaQuery.size.width > 0
                ? mediaQuery.size
                : Size(frame.image.width.toDouble(), frame.image.height.toDouble());
            setState(() {
              _cachedScreenshotImage = frame.image;
              _capturedScreenSize = screenSize;
            });
            _measureRepaintNotifier.value = (_measureRepaintNotifier.value + 1) % 1000000;
          }
        }
      }
    } catch (e) {
      debugPrint('Loupe screenshot capture hatası: $e');
    } finally {
      _isCapturingScreenshot = false;
    }
  }

  /// Büyüteç için arka planda gerçek vektörel CAD çizimini yüksek çözünürlüklü raster haline getirir
  Future<void> _prepareLoupeImage() async {
    if (_localPdfPath == null || _isGeneratingLoupeImage || _cachedLoupeImage != null) return;
    _isGeneratingLoupeImage = true;
    try {
      final bytes = _pdfBytes ?? await File(_localPdfPath!).readAsBytes();
      _pdfBytes = bytes;

      await for (final page in Printing.raster(bytes, pages: [0], dpi: 150.0)) {
        final ui.Image img = await page.toImage();
        if (mounted) {
          final double ptsW = page.width / (150.0 / 72.0);
          final double ptsH = page.height / (150.0 / 72.0);
          setState(() {
            _cachedLoupeImage = img;
            if (ptsW > 0 && ptsH > 0) {
              _docPageSize = Size(ptsW, ptsH);
            }
          });
          _measureRepaintNotifier.value = (_measureRepaintNotifier.value + 1) % 1000000;
        }
        break;
      }
    } catch (e) {
      debugPrint('Büyüteç raster hazırlama hatası: $e');
    } finally {
      _isGeneratingLoupeImage = false;
    }
  }

  Future<void> _toggleMeasurementMode() async {
    if (_measureMode != CadMeasureMode.none) {
      setState(() {
        _measureMode = CadMeasureMode.none;
        _activeDocPoints.clear();
        _isAiming = false;
        _aimScreenPos = null;
        _aimDocPos = null;
        _isSnapped = false;
        _snapLabel = '';
        _snapGuideStartScreen = null;
        _snapGuideEndScreen = null;
        _holdTimer?.cancel();
      });
      return;
    }

    _captureLoupeScreenshot();
    if (_cachedLoupeImage == null) {
      _prepareLoupeImage();
    }

    final prefs = await SharedPreferences.getInstance();
    final bool tutorialSeen = prefs.getBool('cad_measure_tutorial_seen') ?? false;

    if (!tutorialSeen && mounted) {
      await _showMeasurementTutorialDialog();
    }

    if (mounted) {
      setState(() {
        _measureMode = CadMeasureMode.distance;
        _activeDocPoints.clear();
        _isAiming = false;
        _aimScreenPos = null;
        _aimDocPos = null;
        _isSnapped = false;
        _snapLabel = '';
        _snapGuideStartScreen = null;
        _snapGuideEndScreen = null;
      });
    }
  }

  Future<void> _showMeasurementTutorialDialog({bool force = false}) async {
    bool dontShowAgain = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hassas CAD Ölçümü',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildTutorialStep(
                      '1',
                      'Nokta Belirlemek İçin Basılı Tutun',
                      'Parmağınızı ekranda istediğiniz noktaya basılı tutun.',
                      const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 10),
                    _buildTutorialStep(
                      '2',
                      'Sol Üst Büyüteç & Mıknatıs',
                      'Sol üstteki büyüteç parmağınızın altını gösterir ve çizgi/köşelere mıknatıs gibi yapışır.',
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    _buildTutorialStep(
                      '3',
                      'Parmağınızı Kaldırın (Nokta Koyulur)',
                      'Hedef tam oturduğunda parmağınızı kaldırın. Nokta milimetrik hassasiyetle belirlenir.',
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 10),
                    _buildTutorialStep(
                      '4',
                      'Serbest Kaydırma ile 2. Noktayı Seçin',
                      'Çizimi tek parmakla serbestçe kaydırabilir, 2. noktaya aynı şekilde basılı tutabilirsiniz.',
                      const Color(0xFFA855F7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  setDialogState(() {
                    dontShowAgain = !dontShowAgain;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: dontShowAgain,
                          activeColor: const Color(0xFF38BDF8),
                          checkColor: Colors.black,
                          side: const BorderSide(color: Colors.white54, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setDialogState(() {
                              dontShowAgain = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Tekrar gösterme',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (dontShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('cad_measure_tutorial_seen', true);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialStep(String num, String title, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            num,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _panDrawing(Offset delta) async {
    if (_pdfViewController == null) return;
    final newX = _currentXOffset + delta.dx;
    final newY = _currentYOffset + delta.dy;
    _currentXOffset = newX;
    _currentYOffset = newY;
    try {
      await _pdfViewController!.setPosition(Offset(newX, newY));
    } catch (_) {}
    _minimapNotifier.value = {
      'xOffset': newX,
      'yOffset': newY,
      'scale': _effectiveScale,
      'docW': _docPageSize.width,
      'docH': _docPageSize.height,
    };
    _measureRepaintNotifier.value =
        (_measureRepaintNotifier.value + 1) % 1000000;
  }

  Widget _buildMeasureInteractiveLayer() {
    final bool isMeasuring = _measureMode != CadMeasureMode.none;

    final customPaintWidget = AnimatedBuilder(
      animation: Listenable.merge([
        _measureRepaintNotifier,
        _currentScaleNotifier,
      ]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CadMeasurePainter(
            completedMeasurements: _completedMeasurements,
            activeDocPoints: _activeDocPoints,
            activeMode: _measureMode,
            metersPerDocUnit: _metersPerDocUnit,
            docToScreen: _docToScreen,
            screenToDoc: _screenToDoc,
            draggingIndex: _draggingPointIndex,
            scale: _effectiveScale,
            isMeasuring: isMeasuring,
            paperMode: _isPaperMode,
            isAiming: _isAiming,
            aimScreenPos: _aimScreenPos,
            isSnapped: _isSnapped,
            snapLabel: _snapLabel,
            snapGuideStartScreen: _snapGuideStartScreen,
            snapGuideEndScreen: _snapGuideEndScreen,
          ),
        );
      },
    );

    if (!isMeasuring) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: customPaintWidget,
        ),
      );
    }

    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: customPaintWidget,
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_measureMode == CadMeasureMode.none) return;

    _captureLoupeScreenshot();
    if (_cachedLoupeImage == null) {
      _prepareLoupeImage();
    }

    _holdTimer?.cancel();
    _pointerDownScreenPos = event.localPosition;
    _lastPanScreenPos = event.localPosition;
    _hasMovedFar = false;

    // Basılı tutma süresi: 280ms sabit tutulursa büyüteç ve nişan alma açılır
    _holdTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _hasMovedFar) return;
      HapticFeedback.selectionClick();
      setState(() {
        _isAiming = true;
        _aimScreenPos = _pointerDownScreenPos;
        _calculateSnap(_pointerDownScreenPos!);
      });
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_measureMode == CadMeasureMode.none) return;

    final currentPos = event.localPosition;

    if (_isAiming) {
      // Hedefleme ve büyüteç aktif: hedefi güncelle
      _aimScreenPos = currentPos;
      _calculateSnap(currentPos);
      _measureRepaintNotifier.value =
          (_measureRepaintNotifier.value + 1) % 1000000;
    } else {
      // Henüz basılı tutulmadı - hareket mesafesini kontrol et
      final dist = (currentPos - (_pointerDownScreenPos ?? currentPos)).distance;
      if (dist > 8.0) {
        _hasMovedFar = true;
        _holdTimer?.cancel();

        // Serbest çizim kaydırma (Free Pan)
        final delta = currentPos - (_lastPanScreenPos ?? currentPos);
        _lastPanScreenPos = currentPos;
        _panDrawing(delta);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _holdTimer?.cancel();

    if (_isAiming) {
      HapticFeedback.mediumImpact();
      _commitAimPoint();
    }

    setState(() {
      _isAiming = false;
      _aimScreenPos = null;
      _aimDocPos = null;
      _isSnapped = false;
      _snapLabel = '';
      _snapGuideStartScreen = null;
      _snapGuideEndScreen = null;
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    setState(() {
      _isAiming = false;
      _aimScreenPos = null;
      _aimDocPos = null;
      _isSnapped = false;
      _snapLabel = '';
      _snapGuideStartScreen = null;
      _snapGuideEndScreen = null;
    });
  }

  void _calculateSnap(Offset screenPos) {
    const double vertexSnapThreshold = 28.0;
    Offset? snappedScreen;
    Offset? snappedDoc;
    String label = '';

    // 1. Köşe / Nokta Mıknatısı
    // Alan modunda ilk köşe
    if (_measureMode == CadMeasureMode.area && _activeDocPoints.length >= 3) {
      final firstScreen = _docToScreen(_activeDocPoints.first);
      if ((screenPos - firstScreen).distance <= vertexSnapThreshold) {
        snappedScreen = firstScreen;
        snappedDoc = _activeDocPoints.first;
        label = '⌖ İLK KÖŞE (ALANI KAPAT)';
      }
    }

    // Aktif noktalar
    if (snappedDoc == null) {
      for (int i = 0; i < _activeDocPoints.length; i++) {
        final ptScreen = _docToScreen(_activeDocPoints[i]);
        if ((screenPos - ptScreen).distance <= vertexSnapThreshold) {
          snappedScreen = ptScreen;
          snappedDoc = _activeDocPoints[i];
          label = '⌖ KÖŞE NOKTASI';
          break;
        }
      }
    }

    // Tamamlanmış ölçümlerin noktaları
    if (snappedDoc == null) {
      for (final m in _completedMeasurements) {
        for (final docPt in m.docPoints) {
          final ptScreen = _docToScreen(docPt);
          if ((screenPos - ptScreen).distance <= vertexSnapThreshold) {
            snappedScreen = ptScreen;
            snappedDoc = docPt;
            label = '⌖ ÇİZİM KÖŞESİ';
            break;
          }
        }
        if (snappedDoc != null) break;
      }
    }

    // 2. Çizgi Hattı Mıknatısı (Line / Edge Snap)
    if (snappedDoc == null) {
      const double lineSnapThreshold = 18.0;
      for (final m in _completedMeasurements) {
        final pts = m.docPoints;
        final count = m.type == CadMeasureMode.area ? pts.length : pts.length - 1;
        for (int i = 0; i < count; i++) {
          final sA = _docToScreen(pts[i]);
          final sB = _docToScreen(pts[(i + 1) % pts.length]);
          final v = sB - sA;
          final lenSq = v.dx * v.dx + v.dy * v.dy;
          if (lenSq > 0.001) {
            final t = (((screenPos.dx - sA.dx) * v.dx + (screenPos.dy - sA.dy) * v.dy) / lenSq).clamp(0.0, 1.0);
            final proj = Offset(sA.dx + t * v.dx, sA.dy + t * v.dy);
            if ((screenPos - proj).distance <= lineSnapThreshold) {
              snappedScreen = proj;
              snappedDoc = _screenToDoc(proj);
              label = '⌖ ÇİZGİ HATTI';
              break;
            }
          }
        }
        if (snappedDoc != null) break;
      }
    }

    // 3. Ortogonal Aks Mıknatısı (0° Yatay / 90° Dikey - AutoCAD ORTHO)
    Offset? guideStart;
    Offset? guideEnd;
    if (snappedDoc == null && _activeDocPoints.isNotEmpty) {
      final lastScreen = _docToScreen(_activeDocPoints.last);
      final dx = (screenPos.dx - lastScreen.dx).abs();
      final dy = (screenPos.dy - lastScreen.dy).abs();
      const double orthoThreshold = 18.0;

      if (dy <= orthoThreshold) {
        snappedScreen = Offset(screenPos.dx, lastScreen.dy);
        snappedDoc = _screenToDoc(snappedScreen);
        label = '⌖ YATAY AKS (0°)';
        guideStart = Offset(_currentXOffset, lastScreen.dy);
        guideEnd = Offset(_currentXOffset + _docPageSize.width * _effectiveScale, lastScreen.dy);
      } else if (dx <= orthoThreshold) {
        snappedScreen = Offset(lastScreen.dx, screenPos.dy);
        snappedDoc = _screenToDoc(snappedScreen);
        label = '⌖ DİKEY AKS (90°)';
        guideStart = Offset(lastScreen.dx, _currentYOffset);
        guideEnd = Offset(lastScreen.dx, _currentYOffset + _docPageSize.height * _effectiveScale);
      }
    }

    final bool newlySnapped = snappedDoc != null;
    if (newlySnapped && !_isSnapped) {
      HapticFeedback.selectionClick();
    }

    _isSnapped = newlySnapped;
    _snapLabel = label.isNotEmpty ? label : 'HEDEF';
    _aimScreenPos = snappedScreen ?? screenPos;
    _aimDocPos = snappedDoc ?? _screenToDoc(screenPos);
    _snapGuideStartScreen = guideStart;
    _snapGuideEndScreen = guideEnd;
  }

  void _commitAimPoint() {
    if (_aimDocPos == null) return;
    final docPos = _aimDocPos!;

    if (_measureMode == CadMeasureMode.distance) {
      setState(() {
        if (_activeDocPoints.isEmpty) {
          _activeDocPoints.add(docPos);
        } else if (_activeDocPoints.length == 1) {
          _activeDocPoints.add(docPos);
          _completeActiveMeasurement();
        } else {
          _activeDocPoints = [docPos];
        }
      });
    } else if (_measureMode == CadMeasureMode.area) {
      setState(() {
        if (_activeDocPoints.length >= 3) {
          final firstPtDoc = _activeDocPoints.first;
          final distToFirst = (firstPtDoc - docPos).distance * _metersPerDocUnit;
          if (distToFirst < 0.2 || (_isSnapped && _snapLabel.contains('İLK KÖŞE'))) {
            _completeActiveMeasurement();
            return;
          }
        }
        _activeDocPoints.add(docPos);
      });
    } else if (_measureMode == CadMeasureMode.calibrate) {
      setState(() {
        if (_activeDocPoints.length < 2) {
          _activeDocPoints.add(docPos);
        }
        if (_activeDocPoints.length == 2) {
          _showCalibrationDialog();
        }
      });
    }
  }

  void _completeActiveMeasurement() {
    if (_activeDocPoints.isEmpty) return;

    if (_measureMode == CadMeasureMode.distance &&
        _activeDocPoints.length >= 2) {
      _completedMeasurements.add(
        CadMeasurement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: CadMeasureMode.distance,
          docPoints: List.from(_activeDocPoints),
          metersPerDocUnit: _metersPerDocUnit,
          color: const Color(0xFF38BDF8),
        ),
      );
      _activeDocPoints.clear();
    } else if (_measureMode == CadMeasureMode.area &&
        _activeDocPoints.length >= 3) {
      _completedMeasurements.add(
        CadMeasurement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: CadMeasureMode.area,
          docPoints: List.from(_activeDocPoints),
          metersPerDocUnit: _metersPerDocUnit,
          color: const Color(0xFF10B981),
        ),
      );
      _activeDocPoints.clear();
    }
  }

  void _undoLastMeasurementPoint() {
    setState(() {
      if (_activeDocPoints.isNotEmpty) {
        _activeDocPoints.removeLast();
      } else if (_completedMeasurements.isNotEmpty) {
        _completedMeasurements.removeLast();
      }
    });
  }

  void _clearAllMeasurements() {
    setState(() {
      _activeDocPoints.clear();
      _completedMeasurements.clear();
      _draggingPointIndex = null;
      _isAiming = false;
      _aimScreenPos = null;
      _aimDocPos = null;
      _isSnapped = false;
      _snapLabel = '';
      _snapGuideStartScreen = null;
      _snapGuideEndScreen = null;
      _holdTimer?.cancel();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tüm ölçümler temizlendi.'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF0F172A),
      ),
    );
  }

  void _showScaleSelectionSheet() {
    final presets = [
      const CadScalePreset('1:20 (Detay)', 20, 0.000352778 * 20),
      const CadScalePreset('1:50 (Mimari / Uygulama)', 50, 0.000352778 * 50),
      const CadScalePreset('1:100 (Mimari / Statik - Standart)', 100, 0.000352778 * 100),
      const CadScalePreset('1:200 (Kat & Vaziyet Planı)', 200, 0.000352778 * 200),
      const CadScalePreset('1:500 (Vaziyet Planı)', 500, 0.000352778 * 500),
      const CadScalePreset('1:1000 (İmar / Harita Planı)', 1000, 0.000352778 * 1000),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.architecture_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'CAD Çizim Ölçeği & Kalibrasyon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Paftanın çizim ölçeğini seçin veya bilinen bir ölçüyle (kapı, aks vb.) kalibre edin.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ...presets.map((p) {
                final isSelected = _currentScaleLabel == p.label.split(' ').first;
                final isAuto = _autoDetectedScale == p.ratio.round();
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Row(
                    children: [
                      Text(
                        p.label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      if (isAuto) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                          ),
                          child: const Text(
                            'OTOMATİK ALGILANDI',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF38BDF8), size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _metersPerDocUnit = p.metersPerDocUnit;
                      _currentScaleLabel = p.label.split(' ').first;
                      _recalculateCompletedMeasurements();
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
              const Divider(color: Colors.white12, height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                  ),
                ),
                icon: const Icon(Icons.adjust_rounded, size: 20),
                label: const Text(
                  '🎯 2 Nokta İle Referans Kalibre Et (%100 Hassasiyet)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _measureMode = CadMeasureMode.calibrate;
                    _activeDocPoints.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Çizim üzerinde gerçek ölçüsünü bildiğiniz iki noktaya dokunun (Örn: 90 cm kapı açıklığı).',
                      ),
                      backgroundColor: Color(0xFF0F172A),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recalculateCompletedMeasurements() {
    for (int i = 0; i < _completedMeasurements.length; i++) {
      final old = _completedMeasurements[i];
      _completedMeasurements[i] = CadMeasurement(
        id: old.id,
        type: old.type,
        docPoints: old.docPoints,
        metersPerDocUnit: _metersPerDocUnit,
        color: old.color,
        label: old.label,
      );
    }
  }

  void _showCalibrationDialog() {
    if (_activeDocPoints.length < 2) return;
    final p1 = _activeDocPoints[0];
    final p2 = _activeDocPoints[1];
    final docDist = (p2 - p1).distance;
    final controller = TextEditingController(text: '1.00');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        scrollable: true,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text(
              'Referans Kalibrasyon',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seçtiğiniz bu iki nokta arasındaki gerçek şantiye / mimari mesafeyi girin:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  suffixText: 'Metre',
                  suffixStyle: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['0.90', '1.00', '2.50', '4.00', '6.00'].map((val) {
                  return InkWell(
                    onTap: () => controller.text = val,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '$val m',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _measureMode = CadMeasureMode.distance;
                _activeDocPoints.clear();
              });
            },
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final realMeters = double.tryParse(controller.text.replaceAll(',', '.')) ?? 1.0;
              if (docDist > 0 && realMeters > 0) {
                setState(() {
                  _metersPerDocUnit = realMeters / docDist;
                  final estimatedRatio = (_metersPerDocUnit / 0.000352778).round();
                  _currentScaleLabel = '1:$estimatedRatio (Özel)';
                  _recalculateCompletedMeasurements();
                  _measureMode = CadMeasureMode.distance;
                  _activeDocPoints.clear();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ölçek kalibre edildi: $_currentScaleLabel. Çizim artık milimetrik hassasiyette!'),
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                );
              }
            },
            child: const Text('Kalibre Et', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLeftLoupeWidget() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedBuilder(
          animation: _measureRepaintNotifier,
          builder: (context, _) {
            if (!_isAiming || _aimScreenPos == null) {
              return const SizedBox.shrink();
            }

            final screenPos = _aimScreenPos!;
            final bool isNearTopLeft = screenPos.dx < 170 && screenPos.dy < 240;

            double? liveDistanceMeters;
            if (_activeDocPoints.isNotEmpty && _aimDocPos != null) {
              liveDistanceMeters =
                  (_aimDocPos! - _activeDocPoints.last).distance *
                      _metersPerDocUnit;
            }

            return Align(
              alignment:
                  isNearTopLeft ? Alignment.topRight : Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isNearTopLeft
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // BEYAZ ÇERÇEVELİ GERÇEK CAD BÜYÜTECİ (Ekran görüntüsüyle birebir)
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: _isPaperMode ? Colors.white : Colors.black,
                      border: Border.all(
                        color: Colors.white,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 14,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: CustomPaint(
                        size: const Size(133, 133),
                        painter: _LoupeDrawingPainter(
                          repaint: _measureRepaintNotifier,
                          screenshotImage: _cachedScreenshotImage,
                          aimScreenPos: _aimScreenPos,
                          capturedScreenSize: _capturedScreenSize,
                          loupeImage: _cachedLoupeImage,
                          aimDocPos: _aimDocPos,
                          docPageSize: _docPageSize,
                          effectiveScale: _effectiveScale,
                          isSnapped: _isSnapped,
                          snapLabel: _snapLabel,
                          paperMode: _isPaperMode,
                          activeDocPoints: _activeDocPoints,
                          metersPerDocUnit: _metersPerDocUnit,
                          docToScreen: _docToScreen,
                        ),
                      ),
                    ),
                  ),

                  // Mıknatıslı kenetlenme etiketi veya canlı mesafe bilgisi
                  if (_isSnapped && _snapLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        _snapLabel,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ] else if (liveDistanceMeters != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _formatDistance(liveDistanceMeters),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ekran görüntüsündeki gibi sağ üstteki hızlı [ Geri Al | Kapat ] kontrol butonu
  Widget _buildQuickMeasureControls() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _measureRepaintNotifier,
        builder: (context, _) {
          final screenPos = _aimScreenPos ?? Offset.zero;
          final bool isLoupeOnRight = screenPos.dx < 170 && screenPos.dy < 240;

          return Align(
            alignment: isLoupeOnRight ? Alignment.topLeft : Alignment.topRight,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 20, color: Colors.white),
                    tooltip: 'Geri Al',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                    onPressed: (_activeDocPoints.isNotEmpty || _completedMeasurements.isNotEmpty)
                        ? _undoLastMeasurementPoint
                        : null,
                  ),
                  Container(width: 1, height: 20, color: Colors.white24),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                    tooltip: 'Kapat',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                    onPressed: _toggleMeasurementMode,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMeasureFloatingToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMeasureModeChip(
                    icon: Icons.straighten_rounded,
                    label: 'Mesafe',
                    isActive: _measureMode == CadMeasureMode.distance,
                    activeColor: const Color(0xFF38BDF8),
                    onTap: () {
                      setState(() {
                        _measureMode = CadMeasureMode.distance;
                        _activeDocPoints.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildMeasureModeChip(
                    icon: Icons.crop_square_rounded,
                    label: 'Alan',
                    isActive: _measureMode == CadMeasureMode.area,
                    activeColor: const Color(0xFF10B981),
                    onTap: () {
                      setState(() {
                        _measureMode = CadMeasureMode.area;
                        _activeDocPoints.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showMeasurementTutorialDialog(force: true),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Basılı Tut & Mıknatıs',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showScaleSelectionSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.architecture_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            _currentScaleLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down_rounded,
                              size: 16, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18, color: Colors.white24),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    color: (_activeDocPoints.isNotEmpty || _completedMeasurements.isNotEmpty)
                        ? Colors.white
                        : Colors.white30,
                    tooltip: 'Geri Al',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: (_activeDocPoints.isNotEmpty || _completedMeasurements.isNotEmpty)
                        ? _undoLastMeasurementPoint
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: (_activeDocPoints.isNotEmpty || _completedMeasurements.isNotEmpty)
                        ? const Color(0xFFEF4444)
                        : Colors.white30,
                    tooltip: 'Temizle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: (_activeDocPoints.isNotEmpty || _completedMeasurements.isNotEmpty)
                        ? _clearAllMeasurements
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.white70,
                    tooltip: 'Ölçümden Çık',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      setState(() {
                        _measureMode = CadMeasureMode.none;
                        _activeDocPoints.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_measureMode == CadMeasureMode.calibrate)
              _buildCalibrateStatusRow()
            else if (_measureMode == CadMeasureMode.distance)
              _buildDistanceStatusRow()
            else if (_measureMode == CadMeasureMode.area)
              _buildAreaStatusRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasureModeChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.black87 : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black87 : Colors.white,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDistanceStatusRow() {
    double dist = 0.0;
    if (_activeDocPoints.length >= 2) {
      dist = (_activeDocPoints[1] - _activeDocPoints[0]).distance * _metersPerDocUnit;
    }

    String promptText = '';
    Color statusColor = const Color(0xFF38BDF8);
    IconData statusIcon = Icons.touch_app_rounded;

    if (_activeDocPoints.isEmpty) {
      promptText = '1. Noktayı seçin: Parmağınızı ekrana basılı tutun';
      statusColor = const Color(0xFF38BDF8);
      statusIcon = Icons.touch_app_rounded;
    } else if (_activeDocPoints.length == 1) {
      promptText = '2. Noktayı seçin: Basılı tutun (Serbestçe kaydırabilirsiniz)';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.pan_tool_alt_rounded;
    } else {
      promptText = 'Mesafe: ${_formatDistance(dist)}';
      statusColor = const Color(0xFF38BDF8);
      statusIcon = Icons.straighten_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              promptText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.8,
                fontWeight: _activeDocPoints.length >= 2 ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (_activeDocPoints.length >= 2)
            InkWell(
              onTap: () {
                setState(() {
                  _completeActiveMeasurement();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+ Yeni Ölçü',
                  style: TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAreaStatusRow() {
    final area = _calculatePolygonAreaMeters(_activeDocPoints, _metersPerDocUnit);
    final perim = _calculatePolygonPerimeterMeters(_activeDocPoints, _metersPerDocUnit);

    String promptText = '';
    if (_activeDocPoints.isEmpty) {
      promptText = '1. Köşeyi seçin: Parmağınızı ekrana basılı tutun';
    } else if (_activeDocPoints.length == 1) {
      promptText = '2. Köşeyi seçin: Basılı tutun (Kaydırabilirsiniz)';
    } else if (_activeDocPoints.length == 2) {
      promptText = '3. Köşeyi seçin: Basılı tutun (Alan oluşturuluyor)';
    } else {
      promptText = 'Alan: ${_formatArea(area)} • Çevre: ${_formatDistance(perim)}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.crop_square_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              promptText,
              style: const TextStyle(color: Colors.white, fontSize: 11.8, fontWeight: FontWeight.w600),
            ),
          ),
          if (_activeDocPoints.length >= 3)
            InkWell(
              onTap: () {
                setState(() {
                  _completeActiveMeasurement();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✓ Tamamla',
                  style: TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalibrateStatusRow() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.adjust_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🎯 Referans: Ölçüsü bilinen 2 nokta seçin (${_activeDocPoints.length}/2)',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }



  static String _formatDistance(double meters) {
    if (meters < 0.01) {
      return '${(meters * 1000).toStringAsFixed(0)} mm';
    } else if (meters < 1.0) {
      return '${(meters * 100).toStringAsFixed(1)} cm';
    } else if (meters < 1000.0) {
      return '${meters.toStringAsFixed(2)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  static String _formatArea(double sqMeters) {
    if (sqMeters < 0.01) {
      return '${(sqMeters * 10000).toStringAsFixed(1)} cm²';
    } else if (sqMeters < 10000.0) {
      return '${sqMeters.toStringAsFixed(2)} m²';
    } else {
      return '${(sqMeters / 10000.0).toStringAsFixed(2)} ha';
    }
  }

  static double _calculatePolygonAreaMeters(List<Offset> docPoints, double metersPerUnit) {
    if (docPoints.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < docPoints.length; i++) {
      final p1 = docPoints[i];
      final p2 = docPoints[(i + 1) % docPoints.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    final double docArea = (sum.abs()) / 2.0;
    return docArea * (metersPerUnit * metersPerUnit);
  }

  static double _calculatePolygonPerimeterMeters(List<Offset> docPoints, double metersPerUnit) {
    if (docPoints.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < docPoints.length; i++) {
      final p1 = docPoints[i];
      final p2 = docPoints[(i + 1) % docPoints.length];
      sum += (p2 - p1).distance;
    }
    return sum * metersPerUnit;
  }
}

class _BlueprintMinimapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF090D14);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.28)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Grid ve bloklar
    canvas.drawRect(Rect.fromLTWH(w * 0.04, h * 0.12, w * 0.26, h * 0.76), linePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.35, h * 0.12, w * 0.26, h * 0.76), linePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.66, h * 0.12, w * 0.30, h * 0.76), linePaint);

    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sol Üst Büyüteç İçinde Gerçek CAD Çizimini Yüksek Çözünürlüklü & Mıknatıslı Çizen CustomPainter
/// Sol Üst Büyüteç İçinde Gerçek CAD Çizimini Yüksek Çözünürlüklü & Mıknatıslı Çizen CustomPainter
class _LoupeDrawingPainter extends CustomPainter {
  final ui.Image? screenshotImage;
  final Offset? aimScreenPos;
  final Size capturedScreenSize;
  final ui.Image? loupeImage;
  final Offset? aimDocPos;
  final Size docPageSize;
  final double effectiveScale;
  final bool isSnapped;
  final String snapLabel;
  final bool paperMode;
  final List<Offset> activeDocPoints;
  final double metersPerDocUnit;
  final Offset Function(Offset) docToScreen;

  _LoupeDrawingPainter({
    required super.repaint,
    required this.screenshotImage,
    required this.aimScreenPos,
    required this.capturedScreenSize,
    required this.loupeImage,
    required this.aimDocPos,
    required this.docPageSize,
    required this.effectiveScale,
    required this.isSnapped,
    required this.snapLabel,
    required this.paperMode,
    required this.activeDocPoints,
    required this.metersPerDocUnit,
    required this.docToScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Tuval arka planı (CAD Siyahı veya Pafta Beyazı)
    final bgPaint = Paint()
      ..color = paperMode ? Colors.white : const Color(0xFF000000);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Gerçek CAD Ekran Çizimini Büyütülmüş & Hedef Odaklı Olarak Çiz
    if (screenshotImage != null && aimScreenPos != null) {
      final img = screenshotImage!;
      final aim = aimScreenPos!;

      final double sW = capturedScreenSize.width > 0
          ? capturedScreenSize.width
          : img.width.toDouble();
      final double sH = capturedScreenSize.height > 0
          ? capturedScreenSize.height
          : img.height.toDouble();
      const double loupeZoom = 2.8;

      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(center.dx, center.dy);
      canvas.scale(loupeZoom, loupeZoom);
      canvas.translate(-aim.dx, -aim.dy);

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, sW, sH),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else if (loupeImage != null && aimDocPos != null) {
      // Yedek (Fallback): Yüksek çözünürlüklü vektörel raster CAD çizimi
      final img = loupeImage!;
      final aim = aimDocPos!;
      final double docW = docPageSize.width > 0 ? docPageSize.width : 1000.0;
      final double loupeScale = math.max(effectiveScale * 2.8, 2.5);
      final double scaleX = img.width / docW;
      final double renderScale = loupeScale / scaleX;

      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(center.dx, center.dy);
      canvas.scale(renderScale, renderScale);
      canvas.translate(-aim.dx * scaleX, -aim.dy * scaleX);

      canvas.drawImage(
        img,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      // Raster / ekran görüntüsü henüz yüklenirken zarif teknik CAD ızgarası
      final gridPaint = Paint()
        ..color = (paperMode ? Colors.black12 : Colors.white12)
        ..strokeWidth = 0.8;
      for (double x = 0; x < w; x += 14) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
      }
      for (double y = 0; y < h; y += 14) {
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }
    }

    // 3. Aktif Ölçüm Çizgisi (Bir önceki noktadan hedefe dinamik çizgi)
    if (activeDocPoints.isNotEmpty && aimScreenPos != null) {
      final lastScreen = docToScreen(activeDocPoints.last);
      const double loupeZoom = 2.8;
      final Offset lastInLoupe = Offset(
        center.dx + (lastScreen.dx - aimScreenPos!.dx) * loupeZoom,
        center.dy + (lastScreen.dy - aimScreenPos!.dy) * loupeZoom,
      );
      final activeLinePaint = Paint()
        ..color = isSnapped ? const Color(0xFF10B981) : const Color(0xFF00E5FF)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(lastInLoupe, center, activeLinePaint);

      // Son noktanın kendisi
      canvas.drawCircle(
        lastInLoupe,
        4.5,
        Paint()..color = const Color(0xFF00E5FF),
      );
    }

    // 4. Büyüteç Merkez Artı Kılı (Crosshair) - Ekran görüntüsündeki gibi net beyaz artı
    final crosshairPaint = Paint()
      ..color = isSnapped ? const Color(0xFF10B981) : Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    const double armLength = 26.0;
    // Yatay artı çizgisi
    canvas.drawLine(
      Offset(center.dx - armLength, center.dy),
      Offset(center.dx + armLength, center.dy),
      crosshairPaint,
    );
    // Dikey artı çizgisi
    canvas.drawLine(
      Offset(center.dx, center.dy - armLength),
      Offset(center.dx, center.dy + armLength),
      crosshairPaint,
    );

    // 5. Mıknatıs (OSNAP) Kenetlenme Göstergesi
    if (isSnapped) {
      final snapBoxPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 16, height: 16),
        snapBoxPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoupeDrawingPainter oldDelegate) => true;
}

/// CAD Vektörel Çizim Üzerinde Ölçüm & Alan Çizen CustomPainter
class _CadMeasurePainter extends CustomPainter {
  final List<CadMeasurement> completedMeasurements;
  final List<Offset> activeDocPoints;
  final CadMeasureMode activeMode;
  final double metersPerDocUnit;
  final Offset Function(Offset) docToScreen;
  final Offset Function(Offset) screenToDoc;
  final int? draggingIndex;
  final double scale;
  final bool isMeasuring;
  final bool paperMode;
  final bool isAiming;
  final Offset? aimScreenPos;
  final bool isSnapped;
  final String snapLabel;
  final Offset? snapGuideStartScreen;
  final Offset? snapGuideEndScreen;

  _CadMeasurePainter({
    required this.completedMeasurements,
    required this.activeDocPoints,
    required this.activeMode,
    required this.metersPerDocUnit,
    required this.docToScreen,
    required this.screenToDoc,
    required this.draggingIndex,
    required this.scale,
    required this.isMeasuring,
    required this.paperMode,
    required this.isAiming,
    required this.aimScreenPos,
    required this.isSnapped,
    required this.snapLabel,
    required this.snapGuideStartScreen,
    required this.snapGuideEndScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. TAMAMLANMIŞ ÖLÇÜMLERİ ÇİZ
    for (final m in completedMeasurements) {
      if (m.type == CadMeasureMode.distance) {
        _drawDistanceLine(canvas, m.docPoints, m.metersPerDocUnit, m.color);
      } else if (m.type == CadMeasureMode.area) {
        _drawAreaPolygon(canvas, m.docPoints, m.metersPerDocUnit, m.color);
      }
    }

    // 2. AKTİF (ÇİZİLMEKTE OLAN) ÖLÇÜMLERİ ÇİZ
    if (activeDocPoints.isNotEmpty) {
      if (activeMode == CadMeasureMode.distance) {
        _drawActiveDistance(canvas);
      } else if (activeMode == CadMeasureMode.area) {
        _drawActiveArea(canvas);
      } else if (activeMode == CadMeasureMode.calibrate) {
        _drawActiveCalibrate(canvas);
      }
    }

    // 3. BASILI TUTARAK HEDEFLEME & MIKNATIS (OSNAP) ÇİZİMİ
    if (isAiming && aimScreenPos != null) {
      _drawAimingAndSnapping(canvas, size);
    }
  }

  void _drawDistanceLine(Canvas canvas, List<Offset> docPoints, double unitScale, Color color) {
    if (docPoints.length < 2) return;
    for (int i = 0; i < docPoints.length - 1; i++) {
      final s1 = docToScreen(docPoints[i]);
      final s2 = docToScreen(docPoints[i + 1]);

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(s1, s2, linePaint);

      _drawArchitecturalTick(canvas, s1, color);
      _drawArchitecturalTick(canvas, s2, color);

      _drawHandle(canvas, s1, color);
      _drawHandle(canvas, s2, color);

      final mid = (s1 + s2) / 2;
      final distMeters = (docPoints[i + 1] - docPoints[i]).distance * unitScale;
      _drawBadge(canvas, mid, '📐 ${_DwgGoruntuleyiciEkraniState._formatDistance(distMeters)}', color);
    }
  }

  void _drawAreaPolygon(Canvas canvas, List<Offset> docPoints, double unitScale, Color color) {
    if (docPoints.length < 3) return;
    final screenPoints = docPoints.map(docToScreen).toList();

    final path = Path()..moveTo(screenPoints[0].dx, screenPoints[0].dy);
    for (int i = 1; i < screenPoints.length; i++) {
      path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22)..style = PaintingStyle.fill);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    for (final pt in screenPoints) {
      _drawHandle(canvas, pt, color);
    }

    double sumX = 0.0;
    double sumY = 0.0;
    for (final p in screenPoints) {
      sumX += p.dx;
      sumY += p.dy;
    }
    final centroid = Offset(sumX / screenPoints.length, sumY / screenPoints.length);

    final area = _DwgGoruntuleyiciEkraniState._calculatePolygonAreaMeters(docPoints, unitScale);
    final perim = _DwgGoruntuleyiciEkraniState._calculatePolygonPerimeterMeters(docPoints, unitScale);
    _drawBadge(
      canvas,
      centroid,
      '⬡ ${_DwgGoruntuleyiciEkraniState._formatArea(area)}\nÇevre: ${_DwgGoruntuleyiciEkraniState._formatDistance(perim)}',
      color,
    );
  }

  void _drawActiveDistance(Canvas canvas) {
    const color = Color(0xFF38BDF8);
    final s1 = docToScreen(activeDocPoints[0]);

    if (activeDocPoints.length == 1) {
      _drawHandle(canvas, s1, color, isPulsing: true);
      _drawBadge(canvas, Offset(s1.dx, s1.dy - 24), '1. Nokta', color);
    } else if (activeDocPoints.length >= 2) {
      _drawDistanceLine(canvas, activeDocPoints, metersPerDocUnit, color);
    }
  }

  void _drawActiveArea(Canvas canvas) {
    const color = Color(0xFF10B981);
    final screenPoints = activeDocPoints.map(docToScreen).toList();

    if (screenPoints.length == 1) {
      _drawHandle(canvas, screenPoints[0], color, isPulsing: true);
      _drawBadge(canvas, Offset(screenPoints[0].dx, screenPoints[0].dy - 24), '1. Köşe', color);
    } else if (screenPoints.length == 2) {
      canvas.drawLine(
        screenPoints[0],
        screenPoints[1],
        Paint()
          ..color = color
          ..strokeWidth = 2.0,
      );
      _drawHandle(canvas, screenPoints[0], color);
      _drawHandle(canvas, screenPoints[1], color);
      final mid = (screenPoints[0] + screenPoints[1]) / 2;
      final dist = (activeDocPoints[1] - activeDocPoints[0]).distance * metersPerDocUnit;
      _drawBadge(canvas, mid, _DwgGoruntuleyiciEkraniState._formatDistance(dist), color);
    } else if (screenPoints.length >= 3) {
      final path = Path()..moveTo(screenPoints[0].dx, screenPoints[0].dy);
      for (int i = 1; i < screenPoints.length; i++) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      for (int i = 0; i < screenPoints.length; i++) {
        _drawHandle(canvas, screenPoints[i], color, isSelected: draggingIndex == i);
      }

      double sumX = 0.0;
      double sumY = 0.0;
      for (final p in screenPoints) {
        sumX += p.dx;
        sumY += p.dy;
      }
      final centroid = Offset(sumX / screenPoints.length, sumY / screenPoints.length);
      final area = _DwgGoruntuleyiciEkraniState._calculatePolygonAreaMeters(activeDocPoints, metersPerDocUnit);
      final perim = _DwgGoruntuleyiciEkraniState._calculatePolygonPerimeterMeters(activeDocPoints, metersPerDocUnit);
      _drawBadge(
        canvas,
        centroid,
        '⬡ ${_DwgGoruntuleyiciEkraniState._formatArea(area)}\nÇevre: ${_DwgGoruntuleyiciEkraniState._formatDistance(perim)}',
        color,
      );
    }
  }

  void _drawActiveCalibrate(Canvas canvas) {
    const color = Color(0xFFF59E0B);
    final screenPoints = activeDocPoints.map(docToScreen).toList();

    if (screenPoints.length == 1) {
      _drawHandle(canvas, screenPoints[0], color, isPulsing: true);
      _drawBadge(canvas, Offset(screenPoints[0].dx, screenPoints[0].dy - 24), '1. Referans Noktası', color);
    } else if (screenPoints.length >= 2) {
      canvas.drawLine(
        screenPoints[0],
        screenPoints[1],
        Paint()
          ..color = color
          ..strokeWidth = 2.4,
      );
      _drawArchitecturalTick(canvas, screenPoints[0], color);
      _drawArchitecturalTick(canvas, screenPoints[1], color);
      _drawHandle(canvas, screenPoints[0], color);
      _drawHandle(canvas, screenPoints[1], color);
      final mid = (screenPoints[0] + screenPoints[1]) / 2;
      _drawBadge(canvas, mid, '🎯 Kalibrasyon Hattı', color);
    }
  }

  void _drawArchitecturalTick(Canvas canvas, Offset p, Color color) {
    const double len = 7.0;
    const double d = len * 0.7071;
    canvas.drawLine(
      Offset(p.dx - d, p.dy + d),
      Offset(p.dx + d, p.dy - d),
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.square,
    );
  }

  void _drawHandle(Canvas canvas, Offset p, Color color, {bool isPulsing = false, bool isSelected = false}) {
    canvas.drawCircle(
      p,
      isSelected ? 9.0 : 6.0,
      Paint()..color = color..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      p,
      isSelected ? 4.5 : 2.5,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  void _drawBadge(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    const padH = 8.0;
    const padV = 4.0;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.94),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawAimingAndSnapping(Canvas canvas, Size size) {
    if (!isAiming || aimScreenPos == null) return;
    final aim = aimScreenPos!;
    final themeColor = isSnapped ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

    // 1. Ortogonal aks kılavuz çizgisi (0° / 90°)
    if (snapGuideStartScreen != null && snapGuideEndScreen != null) {
      final guidePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, snapGuideStartScreen!, snapGuideEndScreen!, guidePaint);
    }

    // 2. Aktif son noktadan hedefe canlı dinamik çizgi
    if (activeDocPoints.isNotEmpty) {
      final lastScreen = docToScreen(activeDocPoints.last);
      final dynamicLinePaint = Paint()
        ..color = themeColor.withValues(alpha: 0.85)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, lastScreen, aim, dynamicLinePaint);

      // Dinamik mesafe etiketi
      final mid = (lastScreen + aim) / 2;
      final docDist = (screenToDoc(aim) - activeDocPoints.last).distance * metersPerDocUnit;
      _drawBadge(canvas, mid, _DwgGoruntuleyiciEkraniState._formatDistance(docDist), themeColor);
    }

    // 3. Nişan Alma / Mıknatıs Göstergesi (Canvas üzerindeki artı ve OSNAP kutusu)
    if (isSnapped) {
      // Mıknatıslı Kenetlenme (OSNAP Yeşil Kutu)
      final snapBoxPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromCenter(center: aim, width: 16, height: 16), snapBoxPaint);

      // Dış halka
      canvas.drawCircle(
        aim,
        14.0,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Etiket
      _drawBadge(canvas, Offset(aim.dx, aim.dy - 22), snapLabel, const Color(0xFF10B981));
    } else {
      // Serbest Hedefleme Artı Kılı
      final crosshairPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(aim.dx - 18, aim.dy), Offset(aim.dx + 18, aim.dy), crosshairPaint);
      canvas.drawLine(Offset(aim.dx, aim.dy - 18), Offset(aim.dx, aim.dy + 18), crosshairPaint);

      canvas.drawCircle(
        aim,
        10.0,
        Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Merkez minik nokta
    canvas.drawCircle(
      aim,
      3.0,
      Paint()..color = themeColor..style = PaintingStyle.fill,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    final double distance = (p2 - p1).distance;
    if (distance <= 0) return;
    final Offset dir = (p2 - p1) / distance;
    double currentDistance = 0.0;
    while (currentDistance < distance) {
      final double nextDistance = (currentDistance + dashWidth).clamp(0.0, distance);
      canvas.drawLine(p1 + dir * currentDistance, p1 + dir * nextDistance, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _CadMeasurePainter oldDelegate) => true;
}

