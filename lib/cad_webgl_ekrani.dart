import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'tema_ayarlari.dart';

/// WebGL CAD Donanım Motoru Görüntüleyici Ekranı
/// Büyük ve karmaşık CAD projelerini GPU hızlandırmasıyla yüksek hızda görüntüler.
/// Uygulama tasarım sistemine tam uyumlu, açık ve koyu mod destekli.
class CadWebglEkrani extends StatefulWidget {
  final String webglUrl;
  final String projeAdi;
  final String? localPdfPath;

  const CadWebglEkrani({
    super.key,
    required this.webglUrl,
    required this.projeAdi,
    this.localPdfPath,
  });

  @override
  State<CadWebglEkrani> createState() => _CadWebglEkraniState();
}

class _CadWebglEkraniState extends State<CadWebglEkrani> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;
  bool _urlLoaded = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final WebViewController controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..clearCache()
      ..clearLocalStorage()
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebGL CAD Error] ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'CAD motoru yüklenemedi: ${error.description}';
              });
            }
          },
        ),
      );

    _controller = controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_urlLoaded) {
      _urlLoaded = true;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final themeStr = isDark ? 'dark' : 'light';

      String finalUrl = widget.webglUrl;
      final cacheBuster = 'v=5.3&t=${DateTime.now().millisecondsSinceEpoch}';
      finalUrl += (finalUrl.contains('?') ? '&' : '?') + cacheBuster;
      if (!finalUrl.contains('theme=')) {
        finalUrl += '&theme=$themeStr';
      }
      _controller.loadRequest(Uri.parse(finalUrl));
    }
  }

  Future<void> _openInExternalBrowser() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String targetUrl = widget.webglUrl;
    final cacheBuster = 'v=5.3&t=${DateTime.now().millisecondsSinceEpoch}';
    targetUrl += (targetUrl.contains('?') ? '&' : '?') + cacheBuster;
    if (!targetUrl.contains('theme=')) {
      targetUrl += '&theme=${isDark ? 'dark' : 'light'}';
    }
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final appBarBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final appBarFg = isDark ? Colors.white : const Color(0xFF0F172A);
    final scaffoldBg = isDark ? const Color(0xFF0B0F19) : AppColors.lightBackground;
    final accentColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: appBarBg,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: appBarFg, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Geri Dön',
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Text(
                    widget.projeAdi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: appBarFg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (widget.localPdfPath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.picture_as_pdf_rounded, color: accentColor, size: 15),
                      label: Text(
                        'PDF',
                        style: GoogleFonts.poppins(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.open_in_browser_rounded, color: appBarFg.withValues(alpha: 0.7), size: 19),
                  tooltip: 'Tarayıcıda Aç',
                  onPressed: _openInExternalBrowser,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: appBarFg.withValues(alpha: 0.7), size: 20),
                  tooltip: 'Yenile',
                  onPressed: () => _controller.reload(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. WebGL Canvas (WebView)
          WebViewWidget(controller: _controller),

          // 2. Yükleniyor Göstergesi
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress / 100.0 : null,
                backgroundColor: Colors.transparent,
                color: accentColor,
                minHeight: 2.5,
              ),
            ),

          // 3. Hata Durumu Overlay (Over-pixel önlemeli)
          if (_errorMessage != null && !_isLoading)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        'Çizim Yüklenemedi',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _controller.reload(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text('Tekrar Dene', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openInExternalBrowser,
                            icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                            label: Text('Tarayıcıda Aç', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
