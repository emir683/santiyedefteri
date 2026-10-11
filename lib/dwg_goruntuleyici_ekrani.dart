import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class DwgGoruntuleyiciEkrani extends StatefulWidget {
  final String? initialDwgUrl;
  final String? initialProjeAdi;

  const DwgGoruntuleyiciEkrani({
    super.key,
    this.initialDwgUrl,
    this.initialProjeAdi,
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
    'docW': 24000.0,
    'docH': 1968.0,
  });
  Size _docPageSize = const Size(24000, 1968);
  bool _isMinimapExpanded = true;

  String _loadingStatusText = 'CAD Vektör Motoru Başlatılıyor...';
  String _loadingSubText = 'Oracle Cloud LibreDWG Hazırlanıyor';

  late AnimationController _animController;

  // Sunucumuzdaki hazır örnek CAD çizimleri
  static const List<Map<String, String>> _hazirOrnekler = [
    {
      'ad': 'Gerçek Şantiye DWG Projesi',
      'url': '$_kCadServerUrl/files/gercek-dwg-projesi.pdf',
      'aciklama': 'Kapsamlı kalıp ve mimari uygulama paftası',
      'boyut': '15.2 MB',
    },
    {
      'ad': 'Örnek 1: Mimari Kat Planı',
      'url': '$_kCadServerUrl/files/sample-plan.pdf',
      'aciklama': 'Mimari salon, oda, kapı, pencere ve kot ölçüleri',
      'boyut': '2.1 MB',
    },
    {
      'ad': 'Örnek 2: Statik Taşıyıcı Planı',
      'url': '$_kCadServerUrl/files/sample-statik.pdf',
      'aciklama': 'Akslar, kolon aplikasyon, kirişler ve kalıp detayları',
      'boyut': '1.8 MB',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.initialProjeAdi ?? 'Gerçek Şantiye DWG Projesi';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    if (widget.initialDwgUrl != null && widget.initialDwgUrl!.isNotEmpty) {
      _dwgUrlDonusturVeYukle(widget.initialDwgUrl!);
    } else {
      _ornekYukle(_hazirOrnekler.first['url']!, _hazirOrnekler.first['ad']!);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _currentScaleNotifier.dispose();
    _minimapNotifier.dispose();
    super.dispose();
  }

  /// Açık olan projeyi kapatıp CAD çalışma alanına döner
  void _dosyayiKapat() {
    setState(() {
      _localPdfPath = null;
      _pdfBytes = null;
      _lastSelectedFile = null;
      _errorMessage = null;
      _isLoading = false;
      _currentTitle = 'CAD Proje Görüntüleyici';
      _currentScaleNotifier.value = 1.0;
    });
  }

  /// Uzak DWG URL'sini indirip Oracle Cloud LibreDWG motoruna aktarır
  Future<void> _dwgUrlDonusturVeYukle(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingStatusText = 'DWG Dosyası İndiriliyor...';
      _loadingSubText = 'Proje dosyası sunucudan alınıyor';
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
          _errorMessage = 'DWG dosyası indirilemedi (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'DWG indirme hatası: $e';
      });
    }
  }

  /// Örnek Vektörel PDF dosyasını sunucudan indirip doğrudan yerel GPU'da açar
  Future<void> _ornekYukle(String url, String ad) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentTitle = ad;
      _loadingStatusText = 'Vektörel Çizim Yükleniyor...';
      _loadingSubText = 'Flutter Native Grafik Motoru Hazırlanıyor';
    });

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final localPdf = File(
            '${tempDir.path}/cad_view_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await localPdf.writeAsBytes(res.bodyBytes);

        setState(() {
          _pdfBytes = res.bodyBytes;
          _localPdfPath = localPdf.path;
          _isLoading = false;
        });
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
      _errorMessage = null;
      _currentTitle = fileName;
      _loadingStatusText = 'DWG/DXF Sunucuya Aktarılıyor...';
      _loadingSubText = '$fileName LibreDWG 2.0 tam çizim motorunda işleniyor';
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

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        String? pdfUrl = data['pdfUrl'] as String?;

        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          if (pdfUrl.startsWith('/')) {
            pdfUrl = '$_kCadServerUrl$pdfUrl';
          } else if (pdfUrl.contains('localhost')) {
            pdfUrl = pdfUrl.replaceFirst(
                RegExp(r'https?://localhost(:\d+)?'), _kCadServerUrl);
          }

          setState(() {
            _loadingStatusText = 'Sınırsız Vektör Çizimi Hazırlanıyor...';
            _loadingSubText = 'GPU ile 120 FPS Donanım İvmeli Render';
          });
          await _ornekYukle(pdfUrl, fileName);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Sunucu dönüşümü tamamladı ancak vektörel çıktı üretilemedi. Lütfen dosyanın bozuk olmadığından emin olun.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sunucu hatası (${streamedResponse.statusCode}): $responseBody';
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

    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      appBar: _buildAppBar(hasLoadedProject),
      body: Stack(
        children: [
          // 1. ANA ÇALIŞMA ALANI (PROJE AÇIK DEĞİLSE MODERN CAD DASHBOARD, AÇIKSA VEKTÖR ÇİZİM)
          if (!hasLoadedProject && !_isLoading)
            _buildEmptyWorkspaceHub()
          else if (hasLoadedProject)
            _buildCadCanvas(),

          // 2. PROJE RADARI / MİNİMAP (Yalnızca proje açıkken)
          if (hasLoadedProject && !_isLoading && _errorMessage == null)
            Positioned(
              top: 14,
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

          // 4. PREMİUM CAD YÜKLEME EKRANI
          if (_isLoading)
            _buildLoadingOverlay(),

          // 5. HATA EKRANI
          if (_errorMessage != null && !_isLoading)
            _buildErrorOverlay(),
        ],
      ),
    );
  }

  /// Modern Üst Bar
  PreferredSizeWidget _buildAppBar(bool hasLoadedProject) {
    return AppBar(
      backgroundColor: const Color(0xFF0D131F),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasLoadedProject
                      ? const Color(0xFF10B981)
                      : const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                hasLoadedProject
                    ? 'Sınırsız Vektörel CAD Engine'
                    : 'CAD Stüdyo • Çizim Seçin',
                style: TextStyle(
                  color: hasLoadedProject
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
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
            icon: const Icon(Icons.help_outline_rounded,
                color: Colors.white60, size: 20),
            tooltip: 'CAD Yardım',
            onPressed: _showHelpDialog,
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  /// Başlangıçta açılan modern CAD Çalışma Alanı Hub'ı
  Widget _buildEmptyWorkspaceHub() {
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
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
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
                        const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        const Color(0xFF10B981).withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.architecture_rounded,
                    color: Color(0xFF38BDF8),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'CAD Proje Görüntüleyici',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'DWG ve DXF projelerinizi sınırsız ultra zoom ile pürüzsüz inceleyin. Model ve pafta alanındaki tüm çizgiler kayıpsız çizilir.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _cihazdanDwgSecVeYukle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.file_upload_rounded, size: 22),
                  label: const Text(
                    'Cihazdan DWG / DXF Seç & Aç',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFormatBadge('AutoCAD .DWG'),
                    const SizedBox(width: 8),
                    _buildFormatBadge('Vektör .DXF'),
                    const SizedBox(width: 8),
                    _buildFormatBadge('Sınırsız Zoom'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // HAZIR ÖRNEK PROJELER BÖLÜMÜ
          Row(
            children: [
              const Icon(Icons.folder_special_rounded,
                  color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Test İçin Hazır Örnekler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${_hazirOrnekler.length} Örnek',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ..._hazirOrnekler.map((ornek) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: Color(0xFF38BDF8),
                    size: 24,
                  ),
                ),
                title: Text(
                  ornek['ad']!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ornek['aciklama']!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                onTap: () => _ornekYukle(ornek['url']!, ornek['ad']!),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ÖZELLİK VİTRİNİ
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  Icons.zoom_in_rounded,
                  'Sınırsız Odaklı Yakınlaştırma',
                  'En ufak kot, yazı ve kesit detaylarını kayıpsız okuyun.',
                ),
                const Divider(color: Colors.white10, height: 22),
                _buildFeatureRow(
                  Icons.radar_rounded,
                  'Kuşbakışı Radar (Minimap)',
                  'Büyük paftalarda projenin neresinde olduğunuzu anlık görün.',
                ),
                const Divider(color: Colors.white10, height: 22),
                _buildFeatureRow(
                  Icons.layers_rounded,
                  'Tam Çizim & Katman Koruma',
                  'Model ve pafta alanındaki tüm nesneler kesilmeden çizilir.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF10B981), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white54,
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
          },
          onLoadComplete: (pages) async {
            try {
              await _pdfViewController?.setZoomLimits(0.1, 50.0, 100000.0);
            } catch (_) {}
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

  /// Yükleme Ekranı Overlay'i
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF090D14),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _animController,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.25),
                            width: 3.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF38BDF8),
                            width: 2.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.architecture_rounded,
                        color: Color(0xFF38BDF8),
                        size: 30,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _loadingStatusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadingSubText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const SizedBox(
                    width: 180,
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hata Ekranı Overlay'i
  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF090D14),
        padding: const EdgeInsets.all(28),
        child: Center(
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
                  size: 44,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Çizim Yüklenemedi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: _dosyayiKapat,
                    child: const Text('Geri Dön'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.file_upload_rounded, size: 18),
                    label: const Text('Dosya Seç'),
                    onPressed: _cihazdanDwgSecVeYukle,
                  ),
                ],
              ),
            ],
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
            Text(
              'CAD Görüntüleyici Rehberi',
              style: TextStyle(color: Colors.white, fontSize: 16),
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
