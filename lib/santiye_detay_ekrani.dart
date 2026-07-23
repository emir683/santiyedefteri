import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'data_models.dart';
import 'firestore_servisi.dart';
import 'user_model.dart';

const double _shellDockBodyPadding = 132;
const Color _kBrandTeal = Color(0xFF14B8A6);
const Color _kBrandTealDark = Color(0xFF0F7C86);

class SantiyeDetayEkrani extends StatefulWidget {
  final String santiyeAdi;
  final String teamId;
  final String? il;

  const SantiyeDetayEkrani({
    super.key,
    required this.santiyeAdi,
    required this.teamId,
    this.il,
  });

  @override
  State<SantiyeDetayEkrani> createState() => _SantiyeDetayEkraniState();
}

class _SantiyeDetayEkraniState extends State<SantiyeDetayEkrani> {
  late DateTime _gosterilenAy;
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _gosterilenAy = DateTime.now();
    if (widget.il != null && widget.il!.isNotEmpty) {
      _fetchWeather(widget.il!);
    }
  }

  Future<void> _fetchWeather(String il) async {
    setState(() {
      _isLoadingWeather = true;
    });
    try {
      final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$il&count=1&language=tr&format=json');
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        if (geoData['results'] != null && geoData['results'].isNotEmpty) {
          final lat = geoData['results'][0]['latitude'];
          final lon = geoData['results'][0]['longitude'];
          final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
          final weatherRes = await http.get(weatherUrl);
          if (weatherRes.statusCode == 200) {
            final wData = jsonDecode(weatherRes.body);
            if (mounted) {
              setState(() {
                _weatherData = wData['current_weather'];
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Hava durumu alinirken hata: $e");
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
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isDark
                ? const Color(0xFF101317).withOpacity(0.92)
                : Colors.white.withOpacity(0.88),
        surfaceTintColor: Colors.transparent,
        title: Text(widget.santiyeAdi),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark
                    ? const [
                      Color(0xFF06090D),
                      Color(0xFF0C1219),
                      Color(0xFF111827),
                    ]
                    : const [
                      Color(0xFFF6FBFD),
                      Color(0xFFECF5F9),
                      Color(0xFFE4EEF4),
                    ],
          ),
        ),
        child: Column(
          children: [
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF101317).withOpacity(0.94) : const Color(0xFFF7FBFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFD8EAF0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud, color: _kBrandTealDark, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (widget.il != null && widget.il!.isNotEmpty) ? widget.il! : 'Konum Belirtilmedi',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      if (widget.il == null || widget.il!.isEmpty)
                                        const Text('Şantiye düzenle ekranından il ekleyin', style: TextStyle(fontSize: 12, color: Colors.grey))
                                      else if (_isLoadingWeather)
                                        const Text('Hava durumu yükleniyor...', style: TextStyle(fontSize: 12, color: Colors.grey))
                                      else if (_weatherData != null)
                                        Text(
                                          'Sıcaklık: ${_weatherData!['temperature']}°C, Rüzgar: ${_weatherData!['windspeed']} km/s',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        )
                                      else
                                        const Text('Hava durumu alınamadı.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}
