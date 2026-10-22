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
import 'cad_arkaplan_servisi.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
      'https://urge-beliefs-number-unless.trycloudflare.com';

  bool _isLoading = false;
  int _loadingStep = 1;
  String _loadingStatusText = 'CAD Motoru Hazırlanıyor...';
  String _loadingSubText = 'Çizim GPU donanım motoruna aktarılıyor';
  String _loadingFileName = '';
  String _loadingFileSize = '';
  String _loadingFileId = '';
  bool _runInBackgroundRequested = false;
  Timer? _stageTimer;
  Timer? _ipucuTimer;
  int _guncelIpucuIndeksi = 0;

  static const List<Map<String, String>> _kMuhendislikIpuclari = [
    {
      'kategori': '💡 Biliyor muydunuz?',
      'ipucu': '24 MB\'lık bir DWG dosyası, CAD motorumuz tarafından 4.8 milyon çizgi ve 2.1 milyon dolgu geometrisine ayrıştırılarak sıfır-kopya WebGL ikili formatına çevrilir.',
    },
    {
      'kategori': '🏗️ Şantiye İpucu',
      'ipucu': 'Beton dökümü esnasında vibratörün kalıba ve donatıya direkt temas etmemesi, segregasyon riskini ve hava boşluklarını minimuma indirir.',
    },
    {
      'kategori': '📐 CAD Motoru',
      'ipucu': 'Projenizdeki 7 seviyeli iç içe bloklar ve Türkçe SHX karakterler, akıllı vektör motoru ile aslına sadık biçimde tam koordinatlarıyla çözümleniyor.',
    },
    {
      'kategori': '🏛️ Statik Analiz',
      'ipucu': 'Kolon-kiriş birleşim bölgelerindeki etriye sıklaştırması, deprem yatay kuvvetlerinin güvenle karşılanmasında en kritik taşıyıcı detaydır.',
    },
    {
      'kategori': '⚡ GPU Hızlandırma',
      'ipucu': 'Çiziminiz doğrudan telefonunuzun grafik işlemcisine (GPU VBO) aktarılarak 60 FPS akıcı kaydırma (pan) ve yakınlaştırma (zoom) performansı sunulur.',
    },
    {
      'kategori': '🔩 Donatı Detayı',
      'ipucu': 'Paspayı mesnetleri, donatının korozyona uğramasını önleyen ve yangın dayanımını artıran hayati bir şantiye emniyet unsurudur.',
    },
    {
      'kategori': '🎨 Akıllı Katmanlar',
      'ipucu': 'Çizim yüklendikten sonra \'Katmanlar\' menüsünden mimari, statik, mekanik ve tefriş katmanlarını tek dokunuşla açıp kapatabilirsiniz.',
    },
    {
      'kategori': '📏 Hassas Ölçüm',
      'ipucu': 'OSNAP mıknatıs modu ile çizimdeki herhangi iki köşe, orta nokta veya kesişim noktasını milimetrik kesinlikle ölçebilirsiniz.',
    },
  ];

  void _startTipRotation() {
    _ipucuTimer?.cancel();
    _guncelIpucuIndeksi = 0;
    _ipucuTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _guncelIpucuIndeksi = (_guncelIpucuIndeksi + 1) % _kMuhendislikIpuclari.length;
        });
      } else {
        timer.cancel();
      }
    });
  }

  List<SavedCadProject> _savedProjects = [];
  StreamSubscription<CadFilePayload>? _cadStreamSub;

  // Hazır örnek CAD çizimleri (V2 Yüksek Performans Motoru)
  static const List<Map<String, String>> _hazirOrnekler = [
    {
      'id': 'bc00f9c7-d593-49d7-9f4e-ceefb57f27b8',
      'ad': 'Kapalı Spor Salonu Statik Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad-v2.html?id=bc00f9c7-d593-49d7-9f4e-ceefb57f27b8&title=Kapal%C4%B1%20Spor%20Salonu%20Statik%20Projesi',
      'aciklama': 'Temel aplikasyon, kolon, kiriş ve donatı detayları',
      'boyut': '846K Çizim Detayı',
      'colorHex': '0xFF38BDF8',
    },
    {
      'id': '5d6e89b2-bdac-4ff9-8e7c-c129c1fc68e2',
      'ad': 'Hasan Aktaş Statik Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad-v2.html?id=5d6e89b2-bdac-4ff9-8e7c-c129c1fc68e2&title=HASAN%20AKTA%C5%9E%20STAT%C4%B0K%20PROJES%C4%B0',
      'aciklama': 'Tüm katlar, kiriş açılımları ve kalıp planları',
      'boyut': '589K Çizim Detayı',
      'colorHex': '0xFF10B981',
    },
    {
      'id': 'a6003203-6143-414a-bc21-5929f5e8c61e',
      'ad': 'Yağmur Suyu Deposu Mimari Projesi',
      'url':
          '$_kCadServerUrl/webgl-cad-v2.html?id=a6003203-6143-414a-bc21-5929f5e8c61e&title=Ya%C4%9Fmur%20Suyu%20Deposu%20Mimari',
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
    _stageTimer?.cancel();
    _ipucuTimer?.cancel();
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
      await _openSavedProject(existing);
      return;
    }

    // 2. Yeni dosya -> V2 Sunucu Motorunda dönüştür ve WebGL ile aç
    _stageTimer?.cancel();
    _runInBackgroundRequested = false;
    _loadingFileId = '';
    _startTipRotation();
    setState(() {
      _isLoading = true;
      _loadingStep = 1;
      _loadingFileName = fileName;
      _loadingFileSize = _formatFileSize(fileSize);
      _loadingStatusText = 'CAD Dosyası Hazırlanıyor...';
      _loadingSubText = 'Çizim dosyası ($fileName) inceleniyor ve paketleniyor...';
    });

    _stageTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isLoading) {
        setState(() {
          _loadingStep = 2;
          _loadingStatusText = 'V2 Sunucusuna Aktarılıyor...';
          _loadingSubText =
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
        await http.MultipartFile.fromPath('file', file.path, filename: fileName),
      );

      // Uygulama tamamen kapalı olsa bile uzaktan bildirim gelebilmesi için FCM token ekle
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          request.fields['fcm_token'] = fcmToken;
        }
      } catch (e) {
        debugPrint('FCM token eklenemedi: $e');
      }
      request.fields['project_name'] = fileName;

      Timer(const Duration(milliseconds: 3000), () {
        if (mounted && _isLoading && _loadingStep < 3) {
          setState(() {
            _loadingStep = 3;
            _loadingStatusText = 'V2 Motoru Çizimi Çözümlüyor...';
            _loadingSubText =
                'Direct DXF motoru ile ACI renkler, dolgular ve sıfır-kopya binary paket üretiliyor...';
          });
        }
      });

      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 5));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final String? webglUrl = data['webglUrl'] as String?;
        final String? fileId = data['id'] as String?;
        _loadingFileId = fileId ?? '';

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
          resolvedWebglUrl =
              '$_kCadServerUrl/webgl-cad-v2.html?title=${Uri.encodeComponent(fileName)}';
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

        // Kullanıcı bu süreçte "Arka Plana Al" butonuna bastıysa doğrudan arka plan servisine aktar
        if (_runInBackgroundRequested) {
          _ipucuTimer?.cancel();
          if (_loadingFileId.isNotEmpty && _loadingFileId.startsWith('temp_')) {
            CadArkaplanServisi().gorevGuncelleVeyaDegistir(
              eskiFileId: _loadingFileId,
              yeniFileId: fileId ?? '',
              projeAdi: fileName,
              webglUrl: resolvedWebglUrl,
            );
          } else {
            CadArkaplanServisi().projeyiArkaPlanaAl(
              fileId: fileId ?? '',
              projeAdi: fileName,
              webglUrl: resolvedWebglUrl,
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _loadingStep = 4;
            _loadingStatusText = 'GPU Donanım Motoru Başlatılıyor...';
            _loadingSubText =
                'Sıfır-kopya ikili (binary) geometri verisi WebGL tuvaline yükleniyor...';
          });
        }

        await Future.delayed(const Duration(milliseconds: 300));
        _ipucuTimer?.cancel();

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
        throw Exception(
            'Dönüştürme başarısız (Kod: ${streamedResponse.statusCode})');
      }
    } catch (e) {
      _stageTimer?.cancel();
      _ipucuTimer?.cancel();
      debugPrint('[CAD Direct Open Error V2] $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CAD dosyası V2 motorunda açılamadı: $e'),
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

  // Ana Menü Tasarım Sistemi Renkleri ve Yardımcıları
  static const Color _kBrandTeal = Color(0xFF0F7C86);
  static const Color _kTitleDark = Color(0xFF102A43);

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
            color: const Color(0xFF79E9D7).withValues(alpha: isDark ? 0.03 : 0.08),
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
                  'WebGL Çizim Motoru',
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _buildPanelGlassIconBadge(
                icon: Icons.add_rounded,
                size: 36,
                iconSize: 20,
                borderRadius: 18,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                child: Column(
                  children: [
                    // 0. Arka Planda Çözümlenen Projeler Varsa Göster
                    _buildActiveBackgroundTasksBanner(),

                    // 1. Hero / Hızlı Eylem Kartı (Tam Ortalanmış & Ana Menü Cam Tasarımı)
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

  /// 1. Hero / Hızlı Dosya Yükleme Kartı (Ana Ekrandaki Birebir Cam Kart Tasarımı, Kusursuz Ortalanmış)
  Widget _buildHeroUploadCard(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return _buildPanelGlassCard(
      onTap: _pickFileAndOpen,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      borderRadius: 22,
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPanelGlassIconBadge(
                icon: Icons.file_open_rounded,
                accentColor: _kBrandTeal,
                size: 58,
                iconSize: 28,
                borderRadius: 18,
              ),
              const SizedBox(height: 14),
              Text(
                'Yeni CAD Çizimi Aç',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cihazınızdan .dwg veya .dxf dosyası seçin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kBrandTeal.withValues(alpha: isDark ? 0.16 : 0.10),
                      (isDark ? const Color(0xFF15313A) : const Color(0xFFE9F8FA))
                          .withValues(alpha: isDark ? 0.6 : 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _kBrandTeal.withValues(alpha: isDark ? 0.22 : 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.layers_outlined,
                      color: _kBrandTeal,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DWG & DXF Format Desteği',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF5EEAD4) : _kBrandTeal,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Son Açılan Çizimler Bölümü (Ana Menü Tasarım Dili)
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
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_savedProjects.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kBrandTeal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_savedProjects.length}',
                      style: const TextStyle(
                        color: _kBrandTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
                child: const Text(
                  'Temizle',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_savedProjects.isEmpty)
          _buildPanelGlassCard(
            borderRadius: 18,
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
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Açtığınız projeler buraya kaydedilir ve bir daha beklemeden açılır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.7),
                      fontSize: 11.5,
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

  /// Tekil Son Açılan Proje Kartı (Ana Menü Cam Kartı)
  Widget _buildRecentProjectItem(
    SavedCadProject project,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final sizeFormatted = _formatFileSize(project.fileSize);
    final dateFormatted = _formatDate(project.savedAt);

    return _buildPanelGlassCard(
      onTap: () => _openSavedProject(project),
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // İkon Rozeti (Ana Menü Teal)
          _buildPanelGlassIconBadge(
            icon: Icons.architecture_rounded,
            accentColor: _kBrandTeal,
            size: 42,
            iconSize: 22,
            borderRadius: 12,
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
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            color: Color(0xFF10B981),
                            size: 11,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Anında Aç',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
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
                        style: TextStyle(
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
                        style: TextStyle(
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
                      color: _kBrandTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Projeyi Aç',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Listeden Kaldır',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
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

  /// 3. Hazır Örnek CAD Çizimleri Bölümü (Ana Menü Cam Kartları)
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
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
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
            final colorInt = int.tryParse(sample['colorHex'] ?? '') ?? 0xFF0F7C86;
            final itemColor = Color(colorInt);

            return _buildPanelGlassCard(
              onTap: () => _openSampleProject(sample),
              borderRadius: 18,
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  _buildPanelGlassIconBadge(
                    icon: Icons.view_in_ar_rounded,
                    accentColor: itemColor,
                    size: 42,
                    iconSize: 22,
                    borderRadius: 12,
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
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sample['aciklama'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sample['boyut'] ?? '',
                          style: TextStyle(
                            color: itemColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: textSecondary.withValues(alpha: 0.4),
                    size: 14,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Yükleme Ekranı Overlay (V2 Gelişmiş 4 Aşamalı Gösterge)
  Widget _buildLoadingOverlay(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? const Color(0xFF161F2E) : Colors.white,
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF0F7C86).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 32,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F7C86).withValues(alpha: 0.25),
                          const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF0F7C86).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          valueColor: AlwaysStoppedAnimation<Color>(_kBrandTeal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _loadingStatusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loadingSubText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (_loadingFileName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 15, color: _kBrandTeal),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _loadingFileName,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11.5,
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
                                color: textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStepIndicator(1, 'Hazırlık', isDark),
                      _buildStepConnector(1),
                      _buildStepIndicator(2, 'Aktarım', isDark),
                      _buildStepConnector(2),
                      _buildStepIndicator(3, 'V2 Motor', isDark),
                      _buildStepConnector(3),
                      _buildStepIndicator(4, 'GPU Çizim', isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 16),
                  // Mühendislik & Şantiye İpucu Kartı (Dinamik Dönen Bilgiler)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kBrandTeal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _kMuhendislikIpuclari[_guncelIpucuIndeksi]['kategori'] ?? '💡 Bilgi',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kBrandTeal,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _kMuhendislikIpuclari[_guncelIpucuIndeksi]['ipucu'] ?? '',
                            key: ValueKey<int>(_guncelIpucuIndeksi),
                            style: TextStyle(
                              fontSize: 11,
                              color: textPrimary.withValues(alpha: 0.9),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            _stageTimer?.cancel();
                            _ipucuTimer?.cancel();
                            setState(() {
                              _isLoading = false;
                            });
                          },
                          child: const Text(
                            'İptal Et',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBrandTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 16),
                          label: const Text(
                            'Arka Plana Al (Bildir)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            _runInBackgroundRequested = true;
                            _stageTimer?.cancel();
                            _ipucuTimer?.cancel();
                            setState(() {
                              _isLoading = false;
                            });
                            if (_loadingFileId.isNotEmpty) {
                              CadArkaplanServisi().projeyiArkaPlanaAl(
                                fileId: _loadingFileId,
                                projeAdi: _loadingFileName,
                                webglUrl: '$_kCadServerUrl/webgl-cad-v2.html?id=$_loadingFileId&title=${Uri.encodeComponent(_loadingFileName)}',
                              );
                            } else {
                              final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
                              _loadingFileId = tempId;
                              CadArkaplanServisi().projeyiArkaPlanaAl(
                                fileId: tempId,
                                projeAdi: _loadingFileName,
                                webglUrl: '$_kCadServerUrl/webgl-cad-v2.html?title=${Uri.encodeComponent(_loadingFileName)}',
                              );
                            }
                          },
                        ),
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

  /// Arka planda devam eden çizimler varsa üst banner olarak gösterir
  Widget _buildActiveBackgroundTasksBanner() {
    return ValueListenableBuilder<List<CadArkaplanGorevi>>(
      valueListenable: CadArkaplanServisi().aktifGorevlerNotifier,
      builder: (context, gorevler, _) {
        final aktifler = gorevler.where((g) => !g.tamamlandi).toList();
        if (aktifler.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: aktifler.map((g) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F7C86).withValues(alpha: 0.16),
                      const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0F7C86).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7C86)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'CAD Arka Planda Hazırlanıyor',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                              const Spacer(),
                              Text(
                                '%${g.tahminYuzde} (${g.gecenSaniye} sn)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F7C86)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g.projeAdi,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator(int stepNumber, String label, bool isDark) {
    final isDone = _loadingStep > stepNumber;
    final isActive = _loadingStep == stepNumber;
    final color = isDone
        ? const Color(0xFF10B981)
        : (isActive ? _kBrandTeal : (isDark ? Colors.white24 : Colors.black26));

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF10B981)
                  : (isActive ? _kBrandTeal.withValues(alpha: 0.2) : Colors.transparent),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive || isDone ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white38 : Colors.black38),
              fontSize: 9,
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
      width: 10,
      height: 2,
      margin: const EdgeInsets.only(bottom: 15),
      color: isDone ? const Color(0xFF10B981) : Colors.white12,
    );
  }

  /// Sunucu adresi (Cloudflare tunnel vb.) değişse bile kayıtlı projenin güncel sunucu üzerinden açılmasını sağlar
  String _resolveProjectWebglUrl(SavedCadProject project) {
    if (project.id.isNotEmpty && !project.id.startsWith('17')) {
      return '$_kCadServerUrl/webgl-cad-v2.html?id=${project.id}&title=${Uri.encodeComponent(project.fileName)}';
    }
    String url = project.webglUrl;
    if (url.contains('/webgl-cad.html')) {
      url = url.replaceAll('/webgl-cad.html', '/webgl-cad-v2.html');
    }
    if (url.contains('.trycloudflare.com')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final baseUri = Uri.parse(_kCadServerUrl);
        return uri.replace(scheme: baseUri.scheme, host: baseUri.host, port: baseUri.hasPort ? baseUri.port : null).toString();
      }
    }
    return url;
  }

  Future<void> _openSavedProject(SavedCadProject project) async {
    final resolvedUrl = _resolveProjectWebglUrl(project);
    final updatedProject = SavedCadProject(
      id: project.id,
      fileName: project.fileName,
      originalFilePath: project.originalFilePath,
      fileSize: project.fileSize,
      savedAt: DateTime.now(),
      webglUrl: resolvedUrl,
    );
    await _saveProjectToRecent(updatedProject);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CadWebglEkrani(
            webglUrl: resolvedUrl,
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
