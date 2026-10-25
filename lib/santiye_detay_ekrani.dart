import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'data_models.dart';
import 'firestore_servisi.dart';
import 'user_model.dart';
import 'format_yardimcisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'data/turkiye_il_ilce.dart';
import 'widgets/il_ilce_secici_modal.dart';

const double _shellDockBodyPadding = 132;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

class SantiyeDetayEkrani extends StatefulWidget {
  final String santiyeAdi;
  final String teamId;
  final String? il;
  final String? ilce;

  const SantiyeDetayEkrani({
    super.key,
    required this.santiyeAdi,
    required this.teamId,
    this.il,
    this.ilce,
  });

  @override
  State<SantiyeDetayEkrani> createState() => _SantiyeDetayEkraniState();
}

class _SantiyeDetayEkraniState extends State<SantiyeDetayEkrani> {
  VoidCallback? _onPaylasimTiklandi;
  late DateTime _gosterilenAy;
  String? _secilenIl;
  String? _secilenIlce;
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = false;
  bool _isWeatherExpanded = false;

  @override
  void initState() {
    super.initState();
    _gosterilenAy = DateTime.now();
    _secilenIl = widget.il;
    _secilenIlce = widget.ilce;
    if (_secilenIl != null && _secilenIl!.isNotEmpty) {
      _fetchWeather(_secilenIl!, _secilenIlce);
    }
  }

  Future<void> _fetchWeather(String il, [String? ilce]) async {
    if (!mounted) return;
    setState(() {
      _isLoadingWeather = true;
    });
    try {
      final data = await TurkiyeIlIlce.fetchWeather(il: il, ilce: ilce);
      if (mounted) {
        setState(() {
          _weatherData = data;
        });
      }
    } catch (e) {
      debugPrint("Hava durumu alınırken hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baslangic = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final bitis = DateTime(
      _gosterilenAy.year,
      _gosterilenAy.month + 1,
      0,
      23,
      59,
      59,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: FloatingLiquidAppBar(
        title: widget.santiyeAdi,
        showPrivacyButton: true,
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Raporu Metin Olarak Paylaş',
              onPressed: () {
                if (_onPaylasimTiklandi != null) {
                  _onPaylasimTiklandi!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veriler yükleniyor...')),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Column(
          children: [
            SizedBox(
              height: FloatingLiquidAppBar.topPadding(context, extra: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF101317).withValues(alpha: 0.94)
                          : const Color(0xFFF7FBFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFD8EAF0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: _kBrandTealDark,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _gosterilenAy = DateTime(
                                  _gosterilenAy.year,
                                  _gosterilenAy.month - 1,
                                ),
                          ),
                    ),
                    Text(
                      DateFormat.yMMMM('tr_TR').format(_gosterilenAy),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: _kBrandTealDark,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _gosterilenAy = DateTime(
                                  _gosterilenAy.year,
                                  _gosterilenAy.month + 1,
                                ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<GunlukSantiyeRaporu>>(
                stream: servisi.getRaporlarStream(
                  widget.teamId,
                  baslangic,
                  bitis,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final raporlar =
                      (snapshot.data ?? [])
                          .where((r) => r.santiyeAdi == widget.santiyeAdi)
                          .toList();
                  if (raporlar.isEmpty) {
                    return Center(
                      child: Text(
                        "Bu ay şantiyede işlem yok.",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    );
                  }

                  raporlar.sort((a, b) => a.tarih.compareTo(b.tarih));

                  final toplamMasrafGenel = raporlar.fold<double>(
                    0,
                    (toplam, rapor) =>
                        toplam +
                        rapor.benzinGideri +
                        rapor.yemekGideri +
                        rapor.ekMasraflar,
                  );
                  final toplamCalisilanGun = raporlar.length;

                  double toplamYevmiyeSayisi = 0;
                  for (final rapor in raporlar) {
                    for (final calisma in rapor.calisanlar) {
                      toplamYevmiyeSayisi += parseDurumCarpani(calisma.durum);
                    }
                  }

                  _onPaylasimTiklandi = () {
                    final donemStr = DateFormat.yMMMM('tr_TR').format(_gosterilenAy);
                    final metin = _santiyeRaporuMetniOlustur(
                      donem: donemStr,
                      raporlar: raporlar,
                      toplamMasrafGenel: toplamMasrafGenel,
                      toplamYevmiyeSayisi: toplamYevmiyeSayisi,
                      toplamCalisilanGun: toplamCalisilanGun,
                    );
                    _paylasimMenusunuGoster(
                      context: context,
                      baslik: "${widget.santiyeAdi} - Rapor Paylaşımı",
                      metin: metin,
                      isDark: isDark,
                      pdfDosyaAdi: "santiye_raporu_${widget.santiyeAdi}_$donemStr.pdf",
                      pdfOlusturucu: () => _santiyeRaporuPdfOlustur(
                        donem: donemStr,
                        raporlar: raporlar,
                        toplamMasrafGenel: toplamMasrafGenel,
                        toplamYevmiyeSayisi: toplamYevmiyeSayisi,
                        toplamCalisilanGun: toplamCalisilanGun,
                      ),
                    );
                  };

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  isDark
                                      ? const [
                                        Color(0xFF182330),
                                        Color(0xFF10212A),
                                      ]
                                      : const [
                                        Color(0xFFEAF4F8),
                                        Color(0xFFDDECF3),
                                      ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFD8EAF0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.06,
                                ),
                                blurRadius: isDark ? 8 : 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryItem(
                                "Toplam Masraf",
                                "${toplamMasrafGenel.toStringAsFixed(0)} TL",
                                isDark
                                    ? Colors.orangeAccent
                                    : const Color(0xFFB46900),
                              ),
                              _buildSummaryItem(
                                "Yevmiye Say\u0131s\u0131",
                                toplamYevmiyeSayisi.toStringAsFixed(
                                  toplamYevmiyeSayisi % 1 == 0 ? 0 : 1,
                                ),
                                isDark
                                    ? Colors.lightGreenAccent
                                    : const Color(0xFF1B7F4D),
                              ),
                              _buildSummaryItem(
                                "\u00c7al\u0131\u015f\u0131lan G\u00fcn",
                                "$toplamCalisilanGun",
                                isDark ? Colors.white : const Color(0xFF0F2A44),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ÖZET KARTININ ALTINDAKİ ŞIK PAYLAŞ BUTONU
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 10.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  isDark
                                      ? const [
                                        Color(0xFF0F766E),
                                        Color(0xFF14B8A6),
                                      ]
                                      : const [
                                        Color(0xFF0D9488),
                                        Color(0xFF14B8A6),
                                      ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0D9488,
                                ).withValues(alpha: isDark ? 0.35 : 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                final donemStr = DateFormat.yMMMM(
                                  'tr_TR',
                                ).format(_gosterilenAy);
                                final metin = _santiyeRaporuMetniOlustur(
                                  donem: donemStr,
                                  raporlar: raporlar,
                                  toplamMasrafGenel: toplamMasrafGenel,
                                  toplamYevmiyeSayisi: toplamYevmiyeSayisi,
                                  toplamCalisilanGun: toplamCalisilanGun,
                                );
                                _paylasimMenusunuGoster(
                                  context: context,
                                  baslik:
                                      "${widget.santiyeAdi} - Rapor Paylaşımı",
                                  metin: metin,
                                  isDark: isDark,
                                  pdfDosyaAdi:
                                      "santiye_raporu_${widget.santiyeAdi}_$donemStr.pdf",
                                  pdfOlusturucu:
                                      () => _santiyeRaporuPdfOlustur(
                                        donem: donemStr,
                                        raporlar: raporlar,
                                        toplamMasrafGenel: toplamMasrafGenel,
                                        toplamYevmiyeSayisi:
                                            toplamYevmiyeSayisi,
                                        toplamCalisilanGun: toplamCalisilanGun,
                                      ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.share_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Şantiye Raporunu Paylaş",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        "PDF & Metin",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildSantiyeHavaDurumuKarti(isDark),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            _shellDockBodyPadding,
                          ),
                          itemCount: raporlar.length,
                          itemBuilder: (context, index) {
                            final rapor = raporlar[index];
                            final toplamMasraf =
                                rapor.benzinGideri +
                                rapor.yemekGideri +
                                rapor.ekMasraflar;

                            final masrafDetaySatirlari = <Widget>[
                              if (rapor.benzinGideri > 0)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.local_gas_station,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  title: Text(
                                    "Benzin: ${rapor.benzinGideri.toStringAsFixed(2)} TL",
                                  ),
                                  subtitle: Text(
                                    "Ödeyen: ${rapor.benzinGideriIsciAdi?.isNotEmpty == true ? rapor.benzinGideriIsciAdi : 'Belirtilmedi'}",
                                  ),
                                ),
                              if (rapor.yemekGideri > 0)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.restaurant,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  title: Text(
                                    "Yemek: ${rapor.yemekGideri.toStringAsFixed(2)} TL",
                                  ),
                                  subtitle: Text(
                                    "Ödeyen: ${rapor.yemekGideriIsciAdi?.isNotEmpty == true ? rapor.yemekGideriIsciAdi : 'Belirtilmedi'}",
                                  ),
                                ),
                              if (rapor.ekMasraflar > 0)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  title: Text(
                                    "Ek Masraf: ${rapor.ekMasraflar.toStringAsFixed(2)} TL",
                                  ),
                                  subtitle: Text(
                                    "Ödeyen: ${rapor.ekMasraflarIsciAdi?.isNotEmpty == true ? rapor.ekMasraflarIsciAdi : 'Belirtilmedi'}",
                                  ),
                                ),
                            ];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : const Color(0xFFD8EAF0),
                                ),
                              ),
                              color:
                                  isDark
                                      ? const Color(0xFF101317)
                                      : const Color(0xFFF7FBFD),
                              child: ExpansionTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _kBrandTeal.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DateFormat('dd').format(rapor.tarih),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _kBrandTealDark,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  DateFormat.EEEE('tr_TR').format(rapor.tarih),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "${rapor.calisanlar.length} Çalışan • ${toplamMasraf.toStringAsFixed(2)} TL Masraf",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                children: [
                                  const Divider(height: 1),
                                  ...rapor.calisanlar.map(
                                    (c) => ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.person_outline,
                                        size: 18,
                                      ),
                                      title: Text(c.isci.ad),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              c.durum == "Tam Gün"
                                                  ? Colors.green.withValues(
                                                    alpha: 0.2,
                                                  )
                                                  : Colors.orange.withValues(
                                                    alpha: 0.2,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          c.durum,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                c.durum == "Tam Gün"
                                                    ? Colors.green
                                                    : Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (toplamMasraf > 0) ...[
                                    ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.attach_money,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      title: const Text("Günlük Masraf Detayı"),
                                      trailing: Text(
                                        "${toplamMasraf.toStringAsFixed(2)} TL",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                    ...masrafDetaySatirlari,
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color valueColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSantiyeHavaDurumuKarti(bool isDark) {
    final hasLocation = _secilenIl != null && _secilenIl!.isNotEmpty;
    final konumTitle =
        hasLocation
            ? ((_secilenIlce != null && _secilenIlce!.isNotEmpty)
                ? '$_secilenIlce, $_secilenIl'
                : '$_secilenIl (Merkez)')
            : 'Konum Belirtilmedi';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? const Color(0xFF141920) : const Color(0xFFF0FDF4))
                  .withValues(alpha: isDark ? 0.95 : 0.92),
              (isDark ? const Color(0xFF0F141B) : const Color(0xFFE6F4EA))
                  .withValues(alpha: isDark ? 0.98 : 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(_isWeatherExpanded ? 20 : 16),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withValues(
                      alpha: _isWeatherExpanded ? 0.12 : 0.07,
                    )
                    : const Color(
                      0xFF14B8A6,
                    ).withValues(alpha: _isWeatherExpanded ? 0.3 : 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: _isWeatherExpanded ? 14 : 8,
              offset: Offset(0, _isWeatherExpanded ? 6 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık / Kapalı Özet Satırı (Tıklanabilir)
              InkWell(
                borderRadius: BorderRadius.circular(
                  _isWeatherExpanded ? 20 : 16,
                ),
                onTap: () {
                  setState(() {
                    _isWeatherExpanded = !_isWeatherExpanded;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: _isWeatherExpanded ? 14 : 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _kBrandTeal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _weatherData != null
                              ? TurkiyeIlIlce.getWeatherIcon(
                                _weatherData!['weathercode'] ?? 0,
                              )
                              : Icons.location_on_rounded,
                          color:
                              _weatherData != null
                                  ? TurkiyeIlIlce.getWeatherColor(
                                    _weatherData!['weathercode'] ?? 0,
                                  )
                                  : _kBrandTeal,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    konumTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!_isWeatherExpanded &&
                                    _weatherData != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kBrandTeal.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${_weatherData!['temperature']?.round() ?? '--'}°C",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _kBrandTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !_isWeatherExpanded
                                  ? (_weatherData != null
                                      ? "${_weatherData!['description'] ?? 'Hava Durumu'} • 💨 ${_weatherData!['windspeed']} km/s"
                                      : (_isLoadingWeather
                                          ? "Hava durumu güncelleniyor..."
                                          : (hasLocation
                                              ? "Detayları görmek için dokunun"
                                              : "İl/ilçe seçmek için dokunun")))
                                  : "Şantiye Sahası Canlı Hava Durumu",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingWeather)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kBrandTeal,
                            ),
                          ),
                        ),
                      if (_isWeatherExpanded) ...[
                        IconButton(
                          tooltip: "İl / İlçe Değiştir",
                          icon: const Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: _kBrandTeal,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () async {
                            final res = await IlIlceSeciciModal.goster(
                              context,
                              baslangicIl: _secilenIl,
                              baslangicIlce: _secilenIlce,
                            );
                            if (res != null) {
                              setState(() {
                                _secilenIl = res.il;
                                _secilenIlce = res.ilce;
                              });
                              _fetchWeather(res.il, res.ilce);
                            }
                          },
                        ),
                        if (hasLocation)
                          IconButton(
                            tooltip: "Yenile",
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Colors.grey,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed:
                                _isLoadingWeather
                                    ? null
                                    : () => _fetchWeather(
                                      _secilenIl!,
                                      _secilenIlce,
                                    ),
                          ),
                      ],
                      // Açma / Kapama Oku
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AnimatedRotation(
                          turns: _isWeatherExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 24,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Açılır Gövde (Detaylı Bilgiler)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 280),
                crossFadeState:
                    _isWeatherExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 14, thickness: 0.8),
                      // Konum seçilmediyse ekleme çağrısı
                      if (!hasLocation)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final res = await IlIlceSeciciModal.goster(context);
                            if (res != null) {
                              setState(() {
                                _secilenIl = res.il;
                                _secilenIlce = res.ilce;
                              });
                              _fetchWeather(res.il, res.ilce);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _kBrandTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _kBrandTeal.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  color: _kBrandTeal,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "İl ve İlçe Seçerek Hava Durumunu Aktifleştir",
                                  style: TextStyle(
                                    color: _kBrandTeal,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isLoadingWeather && _weatherData == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kBrandTeal,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Hava durumu verisi alınıyor...",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_weatherData != null) ...[
                        // Ana Hava Bilgisi Satırı
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              TurkiyeIlIlce.getWeatherIcon(
                                _weatherData!['weathercode'] ?? 0,
                              ),
                              size: 42,
                              color: TurkiyeIlIlce.getWeatherColor(
                                _weatherData!['weathercode'] ?? 0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${_weatherData!['temperature']?.round() ?? '--'}",
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const Text(
                                      "°C",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _kBrandTeal,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _weatherData!['description'] ?? "Hava Durumu",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Rüzgar ve Diğer Göstergeler
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.air_rounded,
                                    size: 16,
                                    color: Colors.blueAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${_weatherData!['windspeed']} km/s",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Şantiye Sahası Durumu / Emniyet Yorumu Kutusu
                        if (_weatherData!['sahaYorumu'] != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(
                                        0xFF064E3B,
                                      ).withValues(alpha: 0.3)
                                      : const Color(0xFFDEF7EC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF059669,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _weatherData!['sahaYorumu']!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF047857),
                              ),
                            ),
                          ),

                        // 5 Günlük Tahmin Listesi (Varsa)
                        if (_weatherData!['daily'] != null &&
                            (_weatherData!['daily'] as List).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  (_weatherData!['daily'] as List)
                                      .take(6)
                                      .length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final gun =
                                    (_weatherData!['daily'] as List)[index];
                                final rawTime = gun['time']?.toString() ?? '';
                                String gunEtiketi = "Gün";
                                try {
                                  final parsedDate = DateTime.parse(rawTime);
                                  final now = DateTime.now();
                                  if (parsedDate.day == now.day &&
                                      parsedDate.month == now.month) {
                                    gunEtiketi = "Bugün";
                                  } else {
                                    const gunAdlari = [
                                      "Pzt",
                                      "Sal",
                                      "Çar",
                                      "Per",
                                      "Cum",
                                      "Cmt",
                                      "Paz",
                                    ];
                                    gunEtiketi =
                                        gunAdlari[parsedDate.weekday - 1];
                                  }
                                } catch (_) {}

                                return Container(
                                  width: 58,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.white.withValues(
                                              alpha: 0.04,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.white.withValues(
                                                alpha: 0.06,
                                              )
                                              : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        gunEtiketi,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                        ),
                                      ),
                                      Icon(
                                        TurkiyeIlIlce.getWeatherIcon(
                                          gun['code'] ?? 0,
                                        ),
                                        size: 18,
                                        color: TurkiyeIlIlce.getWeatherColor(
                                          gun['code'] ?? 0,
                                        ),
                                      ),
                                      Text(
                                        "${gun['max']?.round() ?? '-'}°",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ] else
                        const Text(
                          "Hava durumu verisi alınamadı. İnternet bağlantınızı kontrol edip yenileyin.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ŞANTİYE RAPOR METNİ OLUŞTURUCU ---
  String _santiyeRaporuMetniOlustur({
    required String donem,
    required List<GunlukSantiyeRaporu> raporlar,
    required double toplamMasrafGenel,
    required double toplamYevmiyeSayisi,
    required int toplamCalisilanGun,
  }) {
    final sb = StringBuffer();
    sb.writeln('🏗️ ŞANTİYE FAALİYET VE MASRAF RAPORU');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('🏢 Şantiye: ${widget.santiyeAdi}');
    if (_secilenIl != null && _secilenIl!.isNotEmpty) {
      final ilceStr =
          _secilenIlce != null && _secilenIlce!.isNotEmpty
              ? ' / $_secilenIlce'
              : '';
      sb.writeln('📍 Konum: $_secilenIl$ilceStr');
    }
    sb.writeln('📅 Dönem: $donem');
    sb.writeln('');

    final yevmiyeStr =
        toplamYevmiyeSayisi % 1 == 0
            ? toplamYevmiyeSayisi.toInt().toString()
            : toplamYevmiyeSayisi.toStringAsFixed(1);

    sb.writeln('📊 ÇALIŞMA ÖZETİ');
    sb.writeln('• Çalışılan Gün Sayısı: $toplamCalisilanGun gün');
    sb.writeln('• Toplam Yevmiye: $yevmiyeStr yevmiye');

    // Personel Dağılımı ve Masraf Dağılımı
    final Map<String, double> isciYevmiyeleri = {};
    final Map<String, int> isciTamGun = {};
    final Map<String, int> isciYarimGun = {};

    double topBenzin = 0;
    double topYemek = 0;
    double topEk = 0;

    for (final r in raporlar) {
      topBenzin += r.benzinGideri;
      topYemek += r.yemekGideri;
      topEk += r.ekMasraflar;

      for (final c in r.calisanlar) {
        final ad = c.isci.ad.trim();
        final carpan = parseDurumCarpani(c.durum);
        if (c.durum.contains('tam') || c.durum.contains('Tam')) {
          isciTamGun[ad] = (isciTamGun[ad] ?? 0) + 1;
        } else if (c.durum.contains('yar') || c.durum.contains('Yar')) {
          isciYarimGun[ad] = (isciYarimGun[ad] ?? 0) + 1;
        } else if (c.durum.contains('mesai') || c.durum.contains('Mesai')) {
          isciTamGun[ad] = (isciTamGun[ad] ?? 0) + 1;
        }
        isciYevmiyeleri[ad] = (isciYevmiyeleri[ad] ?? 0) + carpan;
      }
    }

    sb.writeln('• Çalışan Personel Sayısı: ${isciYevmiyeleri.length} kişi');

    sb.writeln('');
    sb.writeln('💰 MASRAF DAĞILIMI');
    sb.writeln('• Benzin Gideri: ${Formatlayici.yap(topBenzin)}');
    sb.writeln('• Yemek Gideri: ${Formatlayici.yap(topYemek)}');
    sb.writeln('• Ek Masraflar: ${Formatlayici.yap(topEk)}');
    sb.writeln('──────────────────────────────');
    sb.writeln(
      '💳 TOPLAM OPERASYONEL MASRAF: ${Formatlayici.yap(toplamMasrafGenel)}',
    );

    // Personel Listesi
    if (isciYevmiyeleri.isNotEmpty) {
      sb.writeln('');
      sb.writeln('👷 ÇALIŞAN PERSONEL VE YEVMİYELER');
      final siraliIsciler =
          isciYevmiyeleri.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in siraliIsciler) {
        final tam = isciTamGun[entry.key] ?? 0;
        final yarim = isciYarimGun[entry.key] ?? 0;
        final yevStr =
            entry.value % 1 == 0
                ? '${entry.value.toInt()} yevmiye'
                : '${entry.value.toStringAsFixed(1)} yevmiye';
        final gunDetay =
            yarim > 0 ? ' ($tam Tam, $yarim Yarım)' : ' ($tam Tam)';
        sb.writeln('• ${entry.key}: $yevStr$gunDetay');
      }
    }

    // Günlük Notlar (varsa son 5)
    final aciklamaliRaporlar =
        raporlar.where((r) => r.aciklama.trim().isNotEmpty).toList();
    if (aciklamaliRaporlar.isNotEmpty) {
      sb.writeln('');
      sb.writeln('📝 GÜNLÜK NOTLAR & YAPILAN İŞLER');
      for (final r in aciklamaliRaporlar.take(5)) {
        final tStr = DateFormat('dd.MM.yyyy').format(r.tarih);
        sb.writeln('• $tStr: ${r.aciklama.trim()}');
      }
      if (aciklamaliRaporlar.length > 5) {
        sb.writeln('... ve ${aciklamaliRaporlar.length - 5} günün daha notu');
      }
    }

    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📱 Şantiye Yönetim Sistemi');
    return sb.toString();
  }

  // --- ŞANTİYE RAPOR PDF OLUŞTURUCU ---
  Future<Uint8List> _santiyeRaporuPdfOlustur({
    required String donem,
    required List<GunlukSantiyeRaporu> raporlar,
    required double toplamMasrafGenel,
    required double toplamYevmiyeSayisi,
    required int toplamCalisilanGun,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final yevmiyeStr =
        toplamYevmiyeSayisi % 1 == 0
            ? toplamYevmiyeSayisi.toInt().toString()
            : toplamYevmiyeSayisi.toStringAsFixed(1);

    // Personel Dağılımı ve Masraf Dağılımı
    final Map<String, double> isciYevmiyeleri = {};
    final Map<String, int> isciTamGun = {};
    final Map<String, int> isciYarimGun = {};

    double topBenzin = 0;
    double topYemek = 0;
    double topEk = 0;

    for (final r in raporlar) {
      topBenzin += r.benzinGideri;
      topYemek += r.yemekGideri;
      topEk += r.ekMasraflar;

      for (final c in r.calisanlar) {
        final ad = c.isci.ad.trim();
        final carpan = parseDurumCarpani(c.durum);
        if (c.durum.contains('tam') || c.durum.contains('Tam')) {
          isciTamGun[ad] = (isciTamGun[ad] ?? 0) + 1;
        } else if (c.durum.contains('yar') || c.durum.contains('Yar')) {
          isciYarimGun[ad] = (isciYarimGun[ad] ?? 0) + 1;
        } else if (c.durum.contains('mesai') || c.durum.contains('Mesai')) {
          isciTamGun[ad] = (isciTamGun[ad] ?? 0) + 1;
        }
        isciYevmiyeleri[ad] = (isciYevmiyeleri[ad] ?? 0) + carpan;
      }
    }

    final siraliIsciler =
        isciYevmiyeleri.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: ttf),
        build:
            (context) => [
              // Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F7C86'),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Şantiye Faaliyet ve Masraf Raporu',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Şantiye: ${widget.santiyeAdi}',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 13,
                            color: PdfColors.white,
                          ),
                        ),
                        if (_secilenIl != null && _secilenIl!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Konum: $_secilenIl${_secilenIlce != null && _secilenIlce!.isNotEmpty ? ' / $_secilenIlce' : ''}',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              color: PdfColor.fromHex('#E0F2FE'),
                            ),
                          ),
                        ],
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Dönem: $donem',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 10.5,
                            color: PdfColor.fromHex('#E0F2FE'),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Şantiye Yönetim',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#E0F2FE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Özet Kartları
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPdfInfoCard(
                    'Çalışılan Gün',
                    '$toplamCalisilanGun gün',
                    '#EFF6FF',
                    '#1D4ED8',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Toplam Yevmiye',
                    '$yevmiyeStr yevmiye',
                    '#F0FDF4',
                    '#15803D',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Çalışan Personel',
                    '${isciYevmiyeleri.length} kişi',
                    '#F3E8FF',
                    '#7E22CE',
                    ttf,
                  ),
                  _buildPdfInfoCard(
                    'Toplam Masraf',
                    Formatlayici.yap(toplamMasrafGenel),
                    '#FEF2F2',
                    '#B91C1C',
                    ttf,
                    isBold: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // Masraf Dağılımı Tablosu
              _buildPdfSectionTitle('Operasyonel Masraf Dağılımı', ttf),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#334155'),
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                headers: ['Masraf Kalemi', 'Tutar'],
                data: [
                  ['Benzin Gideri', Formatlayici.yap(topBenzin)],
                  ['Yemek Gideri', Formatlayici.yap(topYemek)],
                  ['Ek Masraflar', Formatlayici.yap(topEk)],
                  [
                    'Toplam Operasyonel Masraf',
                    Formatlayici.yap(toplamMasrafGenel),
                  ],
                ],
              ),
              pw.SizedBox(height: 18),

              // Personel ve Yevmiyeler Tablosu
              _buildPdfSectionTitle(
                'Personel Çalışma Dağılımı (Yevmiyeler)',
                ttf,
              ),
              pw.SizedBox(height: 6),
              siraliIsciler.isEmpty
                  ? pw.Text(
                    'Bu şantiyede kayıtlı personel çalışması bulunmamaktadır.',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  )
                  : pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(
                      font: ttf,
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0F7C86'),
                    ),
                    cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    headers: [
                      'Personel Adı',
                      'Tam Gün',
                      'Yarım Gün',
                      'Toplam Yevmiye',
                    ],
                    data:
                        siraliIsciler.map((e) {
                          final tam = isciTamGun[e.key] ?? 0;
                          final yarim = isciYarimGun[e.key] ?? 0;
                          final yevStr =
                              e.value % 1 == 0
                                  ? '${e.value.toInt()}'
                                  : e.value.toStringAsFixed(1);
                          return [e.key, '$tam', '$yarim', '$yevStr yevmiye'];
                        }).toList(),
                  ),
              pw.SizedBox(height: 18),

              // Günlük Faaliyet ve Masraf Çizelgesi
              _buildPdfSectionTitle('Günlük Faaliyet & Masraf Çizelgesi', ttf),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E293B'),
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 5,
                ),
                headers: [
                  'Tarih',
                  'Kişi',
                  'Benzin',
                  'Yemek',
                  'Ek Masraf',
                  'Açıklama / Not',
                ],
                data:
                    raporlar.map((r) {
                      final tStr = DateFormat('dd.MM.yyyy').format(r.tarih);
                      final kisiSayisi = r.calisanlar.length;
                      final aciklamaKisa =
                          r.aciklama.trim().isEmpty ? '-' : r.aciklama.trim();
                      return [
                        tStr,
                        '$kisiSayisi',
                        Formatlayici.yap(r.benzinGideri),
                        Formatlayici.yap(r.yemekGideri),
                        Formatlayici.yap(r.ekMasraflar),
                        aciklamaKisa,
                      ];
                    }).toList(),
              ),
              pw.SizedBox(height: 12),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bu rapor Şantiye Puantaj ve Yönetim Sistemi ile üretilmiştir.',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Sayfa 1',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfInfoCard(
    String title,
    String value,
    String bgColorHex,
    String textColorHex,
    pw.Font font, {
    bool isBold = false,
  }) {
    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(bgColorHex),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 8.5,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSectionTitle(String title, pw.Font font) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: font,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#0F172A'),
      ),
    );
  }

  // --- MODERN PAYLAŞIM MENÜSÜ ---
  void _paylasimMenusunuGoster({
    required BuildContext context,
    required String baslik,
    required String metin,
    required bool isDark,
    required Future<Uint8List> Function() pdfOlusturucu,
    required String pdfDosyaAdi,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (c) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF131922).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: Color(0xFF0D9488),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            baslik,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(c),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          metin,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            height: 1.45,
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buton 1: PDF Olarak Paylaş / Yazdır
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7C86),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      label: Text(
                        "PDF Olarak Paylaş / Yazdır",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(c);
                        try {
                          final bytes = await pdfOlusturucu();
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: pdfDosyaAdi,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("PDF oluşturulurken hata: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Buton 2: Metin Olarak Paylaş (WhatsApp / SMS)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        "Metin Olarak Paylaş (WhatsApp / SMS)",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(c);
                        final box = context.findRenderObject() as RenderBox?;
                        final origin = (box != null && box.hasSize)
                            ? (box.localToGlobal(Offset.zero) & box.size)
                            : const Rect.fromLTWH(0, 0, 100, 100);
                        Share.share(metin, subject: baslik, sharePositionOrigin: origin);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Buton 3: Metni Kopyala
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                        side: BorderSide(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : const Color(0xFFCBD5E1),
                        ),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        "Metni Kopyala",
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: metin));
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text("Rapor metni panoya kopyalandı!"),
                              ],
                            ),
                            backgroundColor: const Color(0xFF0D9488),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
