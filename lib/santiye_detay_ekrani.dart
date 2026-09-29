import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data_models.dart';
import 'firestore_servisi.dart';
import 'user_model.dart';
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
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Column(
          children: [
            SizedBox(height: FloatingLiquidAppBar.topPadding(context, extra: 0)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF101317).withOpacity(0.94)
                          : const Color(0xFFF7FBFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.08)
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
                            () => _gosterilenAy = DateTime(
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
                            () => _gosterilenAy = DateTime(
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
                stream: servisi.getRaporlarStream(widget.teamId, baslangic, bitis),
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
                      final durum = calisma.durum.toLowerCase();
                      if (durum.contains('tam')) {
                        toplamYevmiyeSayisi += 1;
                      } else if (durum.contains('yar')) {
                        toplamYevmiyeSayisi += 0.5;
                      }
                    }
                  }

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
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFD8EAF0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.2 : 0.06,
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
                                toplamYevmiyeSayisi
                                    .toStringAsFixed(
                                      toplamYevmiyeSayisi % 1 == 0 ? 0 : 1,
                                    ),
                                isDark
                                    ? Colors.lightGreenAccent
                                    : const Color(0xFF1B7F4D),
                              ),
                              _buildSummaryItem(
                                "\u00c7al\u0131\u015f\u0131lan G\u00fcn",
                                "$toplamCalisilanGun",
                                isDark
                                    ? Colors.white
                                    : const Color(0xFF0F2A44),
                              ),
                            ],
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
                                    ? Colors.white.withOpacity(0.08)
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
                              color: _kBrandTeal.withOpacity(0.14),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${rapor.calisanlar.length} Çalışan • ${toplamMasraf.toStringAsFixed(2)} TL Masraf",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
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
    final konumTitle = hasLocation
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
            color: isDark
                ? Colors.white.withValues(alpha: _isWeatherExpanded ? 0.12 : 0.07)
                : const Color(0xFF14B8A6).withValues(alpha: _isWeatherExpanded ? 0.3 : 0.2),
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
                borderRadius: BorderRadius.circular(_isWeatherExpanded ? 20 : 16),
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
                              ? TurkiyeIlIlce.getWeatherIcon(_weatherData!['weathercode'] ?? 0)
                              : Icons.location_on_rounded,
                          color: _weatherData != null ? const Color(0xFFF59E0B) : _kBrandTeal,
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
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!_isWeatherExpanded && _weatherData != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kBrandTeal.withValues(alpha: 0.15),
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
                                          : (hasLocation ? "Detayları görmek için dokunun" : "İl/ilçe seçmek için dokunun")))
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: _kBrandTeal),
                          ),
                        ),
                      if (_isWeatherExpanded) ...[
                        IconButton(
                          tooltip: "İl / İlçe Değiştir",
                          icon: const Icon(Icons.tune_rounded, size: 20, color: _kBrandTeal),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                            icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _isLoadingWeather
                                ? null
                                : () => _fetchWeather(_secilenIl!, _secilenIlce),
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
                crossFadeState: _isWeatherExpanded
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
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: _kBrandTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _kBrandTeal.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_location_alt_rounded, color: _kBrandTeal, size: 20),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBrandTeal),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Hava durumu verisi alınıyor...",
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
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
                              TurkiyeIlIlce.getWeatherIcon(_weatherData!['weathercode'] ?? 0),
                              size: 42,
                              color: const Color(0xFFF59E0B),
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
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Rüzgar ve Diğer Göstergeler
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.air_rounded, size: 16, color: Colors.blueAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${_weatherData!['windspeed']} km/s",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                                  : const Color(0xFFDEF7EC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF059669).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _weatherData!['sahaYorumu']!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
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
                              itemCount: (_weatherData!['daily'] as List).take(6).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final gun = (_weatherData!['daily'] as List)[index];
                                final rawTime = gun['time']?.toString() ?? '';
                                String gunEtiketi = "Gün";
                                try {
                                  final parsedDate = DateTime.parse(rawTime);
                                  final now = DateTime.now();
                                  if (parsedDate.day == now.day && parsedDate.month == now.month) {
                                    gunEtiketi = "Bugün";
                                  } else {
                                    const gunAdlari = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
                                    gunEtiketi = gunAdlari[parsedDate.weekday - 1];
                                  }
                                } catch (_) {}

                                return Container(
                                  width: 58,
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        gunEtiketi,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      Icon(
                                        TurkiyeIlIlce.getWeatherIcon(gun['code'] ?? 0),
                                        size: 18,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                      Text(
                                        "${gun['max']?.round() ?? '-'}°",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
}
