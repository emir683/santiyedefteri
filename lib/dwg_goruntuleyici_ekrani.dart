import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cad_intent_service.dart';
import 'cad_webgl_ekrani.dart';
import 'widgets/glass_surface.dart';

/// Önbelleğe kaydedilen ve son açılan CAD projeleri modeli
class SavedCadProject {
  final String id;
  final String fileName;
  final String? originalFilePath;
  final int fileSize;
  final DateTime savedAt;
  final String webglUrl;

  SavedCadProject({
    required this.id,
    required this.fileName,
    this.originalFilePath,
    required this.fileSize,
    required this.savedAt,
    required this.webglUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'originalFilePath': originalFilePath,
    'fileSize': fileSize,
    'savedAt': savedAt.toIso8601String(),
    'webglUrl': webglUrl,
  };

  factory SavedCadProject.fromJson(Map<String, dynamic> json) =>
      SavedCadProject(
        id: json['id'] as String? ?? '',
        fileName: json['fileName'] as String? ?? 'CAD Projesi',
        originalFilePath: json['originalFilePath'] as String?,
        fileSize: json['fileSize'] as int? ?? 0,
        savedAt:
            DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
        webglUrl: json['webglUrl'] as String? ?? '',
      );
}

/// CAD & DWG Görüntüleyici Ekranı
/// Saf WebGL Donanım Hızlandırmalı CAD Motoru (GPU Render, Kesintisiz)
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

class _DwgGoruntuleyiciEkraniState extends State<DwgGoruntuleyiciEkrani> {
  // Oracle Cloud üzerinde çalışan özel CAD Vektör sunucumuz
  static const String _kCadServerUrl =
      'https://durham-recommended-processing-seconds.trycloudflare.com';

  bool _isLoading = false;
  String _loadingStatusText = 'CAD Motoru Hazırlanıyor...';
  String _loadingSubText = 'Çizim GPU donanım motoruna aktarılıyor';

  List<SavedCadProject> _savedProjects = [];
  StreamSubscription<CadFilePayload>? _cadStreamSub;

  // Hazır örnek CAD çizimleri
  static const List<Map<String, String>> _hazirOrnekler = [
    {
      'id': 'bc00f9c7-d593-49d7-9f4e-ceefb57f27b8',
      'ad': 'Kapalı Spor Salonu Statik Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad.html?id=bc00f9c7-d593-49d7-9f4e-ceefb57f27b8&title=Kapal%C4%B1%20Spor%20Salonu%20Statik%20Projesi',
      'aciklama': 'Temel aplikasyon, kolon, kiriş ve donatı detayları',
      'boyut': '846K Çizim Detayı',
      'colorHex': '0xFF38BDF8',
    },
    {
      'id': '5d6e89b2-bdac-4ff9-8e7c-c129c1fc68e2',
      'ad': 'Hasan Aktaş Statik Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad.html?id=5d6e89b2-bdac-4ff9-8e7c-c129c1fc68e2&title=HASAN%20AKTA%C5%9E%20STAT%C4%B0K%20PROJES%C4%B0',
      'aciklama': 'Tüm katlar, kiriş açılımları ve kalıp planları',
      'boyut': '589K Çizim Detayı',
      'colorHex': '0xFF10B981',
    },
    {
      'id': 'a6003203-6143-414a-bc21-5929f5e8c61e',
      'ad': 'Yağmur Suyu Deposu Mimari Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad.html?id=a6003203-6143-414a-bc21-5929f5e8c61e&title=Ya%C4%9Fmur%20Suyu%20Deposu%20Mimari',
      'aciklama': 'Mimari kesit, plan ve kot detayları',
      'boyut': '102K Çizim Detayı',
      'colorHex': '0xFFF59E0B',
    },
  ];

  @override
  void initState() {
    super.initState();
    DwgGoruntuleyiciEkrani.isScreenActive = true;

    _loadSavedProjects();

    // WhatsApp veya dosya yöneticisinden ekran açıkken gelen yeni dosyaları doğrudan WebGL ile aç (Seçim ekranı yok)
    _cadStreamSub = CadIntentService.instance.fileStream.listen((payload) {
      final f = File(payload.filePath);
      if (f.existsSync()) {
        _openCadFileDirectly(f, payload.fileName);
      }
    });

    // Harici dosya yolu verilmişse doğrudan WebGL ile aç
    if (widget.initialLocalFilePath != null &&
        widget.initialLocalFilePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final f = File(widget.initialLocalFilePath!);
        if (f.existsSync()) {
          _openCadFileDirectly(
            f,
            widget.initialFileName ?? 'Proje Çizimi.dwg',
          );
        }
      });
    } else if (widget.initialDwgUrl != null &&
        widget.initialDwgUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openWebglUrlDirectly(
          widget.initialDwgUrl!,
          widget.initialProjeAdi ?? 'CAD Projesi',
        );
      });
    }
  }

  @override
  void dispose() {
    DwgGoruntuleyiciEkrani.isScreenActive = false;
    _cadStreamSub?.cancel();
    super.dispose();
  }

  /// Yerel hafızaya kaydedilmiş son açılan projeleri yükler
  Future<void> _loadSavedProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_cad_projects_list') ?? [];
      final List<SavedCadProject> loaded = [];
      for (final raw in list) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final proj = SavedCadProject.fromJson(map);
          if (proj.webglUrl.isNotEmpty) {
            loaded.add(proj);
          }
        } catch (_) {}
      }
      loaded.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      if (mounted) {
        setState(() {
          _savedProjects = loaded;
        });
      }
    } catch (e) {
      debugPrint('[CAD Load Error] $e');
    }
  }

  /// Projeyi son açılanlara kaydeder / günceller
  Future<void> _saveProjectToRecent(SavedCadProject project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedProjects.removeWhere(
        (p) => p.id == project.id || (p.fileName == project.fileName && p.fileSize == project.fileSize),
      );
      _savedProjects.insert(0, project);

      final encodedList =
          _savedProjects.take(25).map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('saved_cad_projects_list', encodedList);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[CAD Save Error] $e');
    }
  }

  /// Projeyi son açılanlar listesinden kaldırır
  Future<void> _removeProjectFromRecent(SavedCadProject project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedProjects.removeWhere((p) => p.id == project.id);
      final encodedList =
          _savedProjects.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('saved_cad_projects_list', encodedList);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${project.fileName} son açılanlardan kaldırıldı.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[CAD Delete Error] $e');
    }
  }

  /// Son açılan projeleri tamamen temizler
  Future<void> _clearAllRecentProjects() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Son Açılanları Temizle',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Text(
          'Son açılan CAD projeleri listesi temizlensin mi?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cad_projects_list');
      if (mounted) {
        setState(() {
          _savedProjects.clear();
        });
      }
    }
  }

  /// Cihazdan dosya seçip doğrudan açma
  Future<void> _pickFileAndOpen() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dwg', 'dxf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        await _openCadFileDirectly(file, fileName);
      }
    } catch (e) {
      debugPrint('[CAD Picker Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçilemedi: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// CAD dosyasını doğrudan WebGL ile açar (Daha önce açılmışsa anında açar, yoksa dönüştürür)
  Future<void> _openCadFileDirectly(File file, String fileName) async {
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    // 1. Önbellekte bu dosya zaten var mı kontrol et (Beklemeden anında açılış)
    SavedCadProject? existing;
    for (final p in _savedProjects) {
      if ((p.originalFilePath != null && p.originalFilePath == file.path) ||
          (p.fileName == fileName && p.fileSize == fileSize && p.webglUrl.isNotEmpty)) {
        existing = p;
        break;
      }
    }

    if (existing != null && existing.webglUrl.isNotEmpty) {
      await _saveProjectToRecent(existing);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CadWebglEkrani(
              webglUrl: existing!.webglUrl,
              projeAdi: existing.fileName,
            ),
          ),
        );
      }
      return;
    }

    // 2. Yeni dosya -> Sunucuda dönüştür ve WebGL ile aç
    setState(() {
      _isLoading = true;
      _loadingStatusText = 'WebGL Motoru Hazırlanıyor...';
      _loadingSubText = 'Çizim GPU donanım motoruna aktarılıyor';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_kCadServerUrl/api/convert'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path, filename: fileName),
      );

      final streamedResponse = await request.send();
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
              '$_kCadServerUrl/webgl-cad.html?id=$fileId&title=${Uri.encodeComponent(fileName)}';
        } else {
          resolvedWebglUrl =
              '$_kCadServerUrl/webgl-cad.html?title=${Uri.encodeComponent(fileName)}';
        }

        final newProj = SavedCadProject(
          id: fileId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: fileName,
          originalFilePath: file.path,
          fileSize: fileSize,
          savedAt: DateTime.now(),
          webglUrl: resolvedWebglUrl,
        );

        await _saveProjectToRecent(newProj);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CadWebglEkrani(
                webglUrl: resolvedWebglUrl,
                projeAdi: fileName,
              ),
            ),
          );
        }
      } else {
        throw Exception('Dönüştürme başarısız (Kod: ${streamedResponse.statusCode})');
      }
    } catch (e) {
      debugPrint('[CAD Direct Open Error] $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CAD dosyası açılamadı: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// WebGL URL'sini doğrudan açma
  void _openWebglUrlDirectly(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CadWebglEkrani(
          webglUrl: url,
          projeAdi: title,
        ),
      ),
    );
  }

  /// Örnek projeyi doğrudan açma
  Future<void> _openSampleProject(Map<String, String> sample) async {
    final title = sample['ad'] ?? 'Örnek Proje';
    final url = sample['url'] ?? '';
    final id = sample['id'] ?? '';

    final proj = SavedCadProject(
      id: id,
      fileName: title,
      fileSize: 0,
      savedAt: DateTime.now(),
      webglUrl: url,
    );
    await _saveProjectToRecent(proj);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CadWebglEkrani(
            webglUrl: url,
            projeAdi: title,
          ),
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
    if (diff.inDays == 0) {
      return 'Bugün, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) {
      return 'Dün, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
              'CAD Görüntüleyici',
              style: GoogleFonts.poppins(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
                  'WebGL Motoru',
                  style: GoogleFonts.poppins(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              tooltip: 'Yeni Çizim Seç',
              onPressed: _pickFileAndOpen,
            ),
          ),
        ],
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Ana Kaydırılabilir İçerik (RenderFlex / Overpixel Korumalı)
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero / Hızlı Eylem Kartı (Yeni Çizim Seç)
                    _buildHeroUploadCard(isDark, textPrimary, textSecondary),

                    const SizedBox(height: 22),

                    // 2. Son Açılan Çizimler Bölümü
                    _buildRecentProjectsSection(
                      isDark,
                      textPrimary,
                      textSecondary,
                    ),

                    const SizedBox(height: 24),

                    // 3. Hazır Örnek CAD Çizimleri Bölümü
                    _buildSampleProjectsSection(
                      isDark,
                      textPrimary,
                      textSecondary,
                    ),
                  ],
                ),
              ),

              // Yükleme / Dönüştürme Göstergesi
              if (_isLoading)
                _buildLoadingOverlay(isDark, textPrimary, textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Hero / Hızlı Dosya Yükleme Kartı (Uygulama İçi Cam Tasarımı)
  Widget _buildHeroUploadCard(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GlassSectionCard(
      lightweight: true,
      borderRadius: 20,
      onTap: _pickFileAndOpen,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.file_open_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yeni CAD Çizimi Aç',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cihazınızdan .dwg veya .dxf dosyası seçin',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.layers_outlined,
                  color: Color(0xFF0284C7),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'DWG & DXF Format Desteği',
                  style: GoogleFonts.poppins(
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Son Açılan Çizimler Bölümü (Glass Tasarım)
  Widget _buildRecentProjectsSection(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Son Açılan Çizimler',
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_savedProjects.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_savedProjects.length}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF0284C7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_savedProjects.isNotEmpty)
              TextButton(
                onPressed: _clearAllRecentProjects,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Temizle',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_savedProjects.isEmpty)
          GlassSectionCard(
            lightweight: true,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: textSecondary.withValues(alpha: 0.4),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Henüz açılan bir CAD çizimi yok',
                    style: GoogleFonts.poppins(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Açtığınız projeler buraya kaydedilir ve bir daha beklemeden açılır.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _savedProjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final project = _savedProjects[index];
              return _buildRecentProjectItem(
                project,
                isDark,
                textPrimary,
                textSecondary,
              );
            },
          ),
      ],
    );
  }

  /// Tekil Son Açılan Proje Kartı (GlassSectionCard)
  Widget _buildRecentProjectItem(
    SavedCadProject project,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final sizeFormatted = _formatFileSize(project.fileSize);
    final dateFormatted = _formatDate(project.savedAt);

    return GlassSectionCard(
      lightweight: true,
      borderRadius: 16,
      onTap: () => _openSavedProject(project),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // İkon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.architecture_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Metin Alanı (Overpixel Engellemek için Expanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.flash_on_rounded,
                            color: Color(0xFF10B981),
                            size: 11,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Anında Aç',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sizeFormatted.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sizeFormatted,
                        style: GoogleFonts.poppins(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(color: textSecondary, fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dateFormatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Aksiyon Menüsü
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: textSecondary,
              size: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            onSelected: (val) {
              if (val == 'open') {
                _openSavedProject(project);
              } else if (val == 'delete') {
                _removeProjectFromRecent(project);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Projeyi Aç',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Listeden Kaldır',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Hazır Örnek CAD Çizimleri Bölümü (GlassSectionCard)
  Widget _buildSampleProjectsSection(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hazır Örnek CAD Çizimleri',
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _hazirOrnekler.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final sample = _hazirOrnekler[index];
            final colorInt = int.tryParse(sample['colorHex'] ?? '') ?? 0xFF0284C7;
            final itemColor = Color(colorInt);

            return GlassSectionCard(
              lightweight: true,
              borderRadius: 16,
              onTap: () => _openSampleProject(sample),
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.view_in_ar_rounded,
                      color: itemColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sample['ad'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sample['aciklama'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sample['boyut'] ?? '',
                          style: GoogleFonts.poppins(
                            color: itemColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: textSecondary.withValues(alpha: 0.4),
                    size: 13,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Yükleme Ekranı Overlay
  Widget _buildLoadingOverlay(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _loadingStatusText,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _loadingSubText,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSavedProject(SavedCadProject project) async {
    await _saveProjectToRecent(project);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CadWebglEkrani(
            webglUrl: project.webglUrl,
            projeAdi: project.fileName,
          ),
        ),
      );
    }
  }
}
class BoxInsets {
  static BoxShadow boxShadow({
    required Color color,
    required double blurRadius,
    required Offset offset,
  }) {
    return BoxShadow(
      color: color,
      blurRadius: blurRadius,
      offset: offset,
    );
  }
}
