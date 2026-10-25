import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../puanlama_servisi.dart';

class PuanlamaDiyalogu extends StatefulWidget {
  const PuanlamaDiyalogu({super.key});

  static Future<void> goster(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'puanlama_diyalogu',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return const PuanlamaDiyalogu();
      },
    );
  }

  @override
  State<PuanlamaDiyalogu> createState() => _PuanlamaDiyaloguState();
}

class _PuanlamaDiyaloguState extends State<PuanlamaDiyalogu> {
  int _seciliPuan = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String get _aciklamaMetni {
    if (_seciliPuan == 0) {
      return 'Şantiye Puantaj Defteri size yardımcı oluyor mu? Deneyiminizi puanlayarak bize destek olabilirsiniz.';
    } else if (_seciliPuan >= 4) {
      final storeAdi = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? "App Store'da" : "Play Store'da";
      return 'Bunu duyduğumuza çok sevindik! 🎉 $storeAdi bizi 5 yıldızla puanlayarak ekibimize destek olmak ister misiniz?';
    } else {
      return 'Deneyiminizi geliştirmek istiyoruz. Neyi daha iyi yapabilirdik? Birkaç cümleyle anlatabilir misiniz?';
    }
  }

  Future<void> _puanlamaTamamla() async {
    if (_seciliPuan == 0 || _gonderiliyor) return;

    if (_seciliPuan >= 4) {
      Navigator.of(context).pop();
      await PuanlamaServisi.markRated();
      await PuanlamaServisi.openStore();
    } else {
      setState(() => _gonderiliyor = true);
      final mesaj = _feedbackController.text.trim();
      await PuanlamaServisi.geriBildirimKaydet(
        puan: _seciliPuan,
        mesaj: mesaj.isEmpty ? null : mesaj,
      );
      await PuanlamaServisi.markRated();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Geri bildiriminiz için teşekkürler! Görüşleriniz bizim için çok değerli.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: keyboardBottom + 24,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF161F2A), Color(0xFF0F151E)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF0F7FA)],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFB6DDE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İkon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rate_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Başlık
                  Text(
                    'Uygulamayı Puanla',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102A43),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dinamik Açıklama
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _aciklamaMetni,
                      key: ValueKey<int>(_seciliPuan >= 4 ? 4 : (_seciliPuan > 0 ? 1 : 0)),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : const Color(0xFF526772),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 5 Yıldız Satırı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= _seciliPuan;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _seciliPuan = starIndex;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: starIndex == _seciliPuan ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isSelected
                                  ? const Color(0xFFFFB300)
                                  : (isDark ? Colors.white24 : Colors.grey[400]),
                              size: 42,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // 1-3 Yıldız Seçildiğinde Geri Bildirim Metin Kutusu
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: _seciliPuan > 0 && _seciliPuan < 4
                        ? Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: TextField(
                              controller: _feedbackController,
                              maxLines: 3,
                              minLines: 2,
                              maxLength: 350,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Görüş ve önerilerinizi buraya yazabilirsiniz (isteğe bağlı)...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFEAF2F6),
                                counterText: '',
                                contentPadding: const EdgeInsets.all(14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF14B8A6),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // Aksiyon Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _seciliPuan == 0 || _gonderiliyor
                          ? null
                          : _puanlamaTamamla,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _seciliPuan >= 4
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF14B8A6),
                        disabledBackgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey[200],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _gonderiliyor
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_seciliPuan >= 4) ...[
                                  const Icon(Icons.open_in_new_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                                        ? "App Store'da Puanla"
                                        : "Play Store'da Puanla",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ] else if (_seciliPuan > 0) ...[
                                  const Icon(Icons.send_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Geri Bildirimi Gönder',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Puanınızı Seçin',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.black26,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Daha Sonra Butonu
                  TextButton(
                    onPressed: _gonderiliyor
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await PuanlamaServisi.remindLater();
                          },
                    child: Text(
                      'Daha sonra',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
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
}
