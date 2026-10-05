import 'package:flutter/material.dart';
import 'animasyon_yardimcisi.dart';
import 'tur_servisi.dart';

/// Ana menüdeki 3 adımlı başlangıç rehber kartı.
/// Kullanıcı 3 adımı tamamlayınca ya da X'e basınca kapanır.
class RehberKarti extends StatefulWidget {
  final String teamId;
  final VoidCallback? onSantiyeGit;
  final VoidCallback? onIsciGit;
  final VoidCallback? onRaporGit;

  const RehberKarti({
    super.key,
    required this.teamId,
    this.onSantiyeGit,
    this.onIsciGit,
    this.onRaporGit,
  });

  @override
  State<RehberKarti> createState() => _RehberKartiState();
}

class _RehberKartiState extends State<RehberKarti>
    with SingleTickerProviderStateMixin {
  bool _adim1 = false;
  bool _adim2 = false;
  bool _adim3 = false;
  bool _gosterilmeli = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _yukleDurumlar();
  }

  Future<void> _yukleDurumlar() async {
    final goster = await TurServisi.rehberGosterilmeli();
    final a1 = await TurServisi.adim1Tamamlandi();
    final a2 = await TurServisi.adim2Tamamlandi();
    final a3 = await TurServisi.adim3Tamamlandi();
    if (mounted) {
      setState(() {
        _gosterilmeli = goster;
        _adim1 = a1;
        _adim2 = a2;
        _adim3 = a3;
      });
      if (goster) _animController.forward();
    }
  }

  Future<void> _kapat() async {
    await _animController.reverse();
    await TurServisi.rehberKapat();
    if (mounted) setState(() => _gosterilmeli = false);
  }

  int get _tamamlananSayisi => [_adim1, _adim2, _adim3].where((v) => v).length;

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gosterilmeli) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1B2838), const Color(0xFF0D1B2A)]
                : [const Color(0xFF1565C0), const Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık Satırı
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👋', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Haydi Başlayalım!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'İlk günlük raporunu birlikte girelim. '
                          '$_tamamlananSayisi/3 adım tamamlandı.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _kapat,
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),

              // İlerleme Çubuğu
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _tamamlananSayisi / 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  minHeight: 6,
                ),
              ),

              // Adımlar
              const SizedBox(height: 18),
              _buildAdim(
                no: 1,
                tamamlandi: _adim1,
                icon: Icons.home_work_outlined,
                baslik: '1. Şantiye Ekle',
                aciklama: 'Çalıştığın projeyi sisteme tanıt',
                onTap: _adim1 ? null : () async {
                  widget.onSantiyeGit?.call();
                  // Geri döndüğünde adımı kontrol et; SantiyeEkrani tarafında işlenecek
                },
              ),
              const SizedBox(height: 10),
              _buildAdim(
                no: 2,
                tamamlandi: _adim2,
                icon: Icons.groups_outlined,
                baslik: '2. İşçi Ekle',
                aciklama: 'Ekibindeki kişileri listeye ekle',
                onTap: (!_adim1 || _adim2) ? null : () async {
                  widget.onIsciGit?.call();
                },
                kilitli: !_adim1,
              ),
              const SizedBox(height: 10),
              _buildAdim(
                no: 3,
                tamamlandi: _adim3,
                icon: Icons.edit_calendar_outlined,
                baslik: '3. İlk Günlük Raporu Gir',
                aciklama: 'Bugünün yoklamasını ve masraflarını kaydet',
                onTap: (!_adim2 || _adim3) ? null : () async {
                  widget.onRaporGit?.call();
                },
                kilitli: !_adim2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdim({
    required int no,
    required bool tamamlandi,
    required IconData icon,
    required String baslik,
    required String aciklama,
    VoidCallback? onTap,
    bool kilitli = false,
  }) {
    final double opacity = kilitli ? 0.45 : 1.0;

    return AnimasyonluButon(
      onPressed: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tamamlandi
                ? Colors.green.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tamamlandi
                  ? Colors.greenAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tamamlandi
                      ? Colors.greenAccent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: tamamlandi
                    ? const Icon(Icons.check, color: Colors.greenAccent, size: 20)
                    : Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: TextStyle(
                        color: tamamlandi
                            ? Colors.greenAccent
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: tamamlandi
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (!tamamlandi) ...[
                      const SizedBox(height: 2),
                      Text(
                        aciklama,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!tamamlandi && !kilitli)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 14,
                ),
              if (kilitli)
                Icon(
                  Icons.lock_outline,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
