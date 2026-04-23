import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'rol_provider.dart';

const double _shellDockBodyPadding = 132;
const Color _kBrandTealDark = Color(0xFF0F7C86);

class IsciDetayEkrani extends StatefulWidget {
  final Isci isci;
  final String teamId;

  const IsciDetayEkrani({super.key, required this.isci, required this.teamId});

  @override
  State<IsciDetayEkrani> createState() => _IsciDetayEkraniState();
}

class _IsciDetayEkraniState extends State<IsciDetayEkrani> {
  late DateTime _gosterilenAy;

  @override
  void initState() {
    super.initState();
    _gosterilenAy = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFinans = Provider.of<RolProvider>(context).isFinansalErisim;

    // Ayın başı ve sonu
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
        title: Text(widget.isci.ad),
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
          // 1. TARİH SEÇİCİ (Modern)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    icon: const Icon(Icons.chevron_left, color: _kBrandTealDark),
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
                    icon: const Icon(Icons.chevron_right, color: _kBrandTealDark),
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

          // 2. VERİLERİ ÇEK (Raporlar + Avanslar)
          Expanded(
            child: StreamBuilder<List<GunlukSantiyeRaporu>>(
              stream: servisi.getRaporlarStream(
                widget.teamId,
                baslangic,
                bitis,
              ),
              builder: (context, snapshotRaporlar) {
                // Raporlar yüklenirken bekleme
                if (!snapshotRaporlar.hasData)
                  return const Center(child: CircularProgressIndicator());

                return StreamBuilder<List<VerilenAvans>>(
                  stream: servisi.getAvanslarStream(widget.teamId),
                  builder: (context, snapshotAvanslar) {
                    // Avanslar yüklenirken bekleme
                    if (!snapshotAvanslar.hasData)
                      return const Center(child: CircularProgressIndicator());

                    // --- HESAPLAMA MOTORU ---
                    final raporlar = snapshotRaporlar.data!;
                    final avanslar = snapshotAvanslar.data!;

                    // Listeyi oluşturacak veri havuzu
                    final tumHareketler = <Map<String, dynamic>>[];

                    int tamGun = 0;
                    int yarimGun = 0;
                    double toplamHakedis = 0;
                    double toplamAvans = 0;
                    double toplamKarsilananGider = 0;

                    bool isciEslesiyor({
                      required String? raporIsciId,
                      required String? raporIsciAdi,
                    }) {
                      final hedefId = widget.isci.id?.trim();
                      final raporId = raporIsciId?.trim();
                      if (hedefId != null &&
                          hedefId.isNotEmpty &&
                          raporId != null &&
                          raporId.isNotEmpty) {
                        return hedefId == raporId;
                      }
                      return (raporIsciAdi ?? '').trim().toLowerCase() ==
                          widget.isci.ad.trim().toLowerCase();
                    }

                    // 1. Çalışma Verilerini İşle
                    for (var rapor in raporlar) {
                      for (var calisma in rapor.calisanlar) {
                        if (calisma.isci.ad == widget.isci.ad) {
                          // İstatistikleri topla
                          if (calisma.durum == "Tam Gün") tamGun++;
                          if (calisma.durum == "Yarım Gün") yarimGun++;

                          // Listeye ekle
                          tumHareketler.add({
                            'tip': 'calisma',
                            'tarih': rapor.tarih,
                            'baslik': rapor.santiyeAdi,
                            'detay': calisma.durum,
                            'tutar':
                                calisma.durum == "Tam Gün"
                                    ? widget.isci.gunlukMaas
                                    : (widget.isci.gunlukMaas / 2),
                          });
                        }
                      }

                      if (rapor.benzinGideri > 0 &&
                          isciEslesiyor(
                            raporIsciId: rapor.benzinGideriIsciId,
                            raporIsciAdi: rapor.benzinGideriIsciAdi,
                          )) {
                        toplamKarsilananGider += rapor.benzinGideri;
                        tumHareketler.add({
                          'tip': 'gider',
                          'giderTipi': 'Benzin Gideri',
                          'tarih': rapor.tarih,
                          'baslik': rapor.santiyeAdi,
                          'detay': 'Benzin karşıladı',
                          'tutar': rapor.benzinGideri,
                        });
                      }

                      if (rapor.yemekGideri > 0 &&
                          isciEslesiyor(
                            raporIsciId: rapor.yemekGideriIsciId,
                            raporIsciAdi: rapor.yemekGideriIsciAdi,
                          )) {
                        toplamKarsilananGider += rapor.yemekGideri;
                        tumHareketler.add({
                          'tip': 'gider',
                          'giderTipi': 'Yemek Gideri',
                          'tarih': rapor.tarih,
                          'baslik': rapor.santiyeAdi,
                          'detay': 'Yemek karşıladı',
                          'tutar': rapor.yemekGideri,
                        });
                      }

                      if (rapor.ekMasraflar > 0 &&
                          isciEslesiyor(
                            raporIsciId: rapor.ekMasraflarIsciId,
                            raporIsciAdi: rapor.ekMasraflarIsciAdi,
                          )) {
                        toplamKarsilananGider += rapor.ekMasraflar;
                        tumHareketler.add({
                          'tip': 'gider',
                          'giderTipi': 'Ek Masraf',
                          'tarih': rapor.tarih,
                          'baslik': rapor.santiyeAdi,
                          'detay': 'Ek masraf karşıladı',
                          'tutar': rapor.ekMasraflar,
                        });
                      }
                    }

                    // 2. Avans Verilerini İşle (Sadece seçili ay)
                    for (var avans in avanslar) {
                      if (avans.isci.ad == widget.isci.ad &&
                          avans.tarih.year == _gosterilenAy.year &&
                          avans.tarih.month == _gosterilenAy.month) {
                        toplamAvans += avans.miktar;

                        tumHareketler.add({
                          'tip': 'avans',
                          'tarih': avans.tarih,
                          'baslik': "Avans Alındı",
                          'detay': "Ödeme",
                          'tutar':
                              -avans
                                  .miktar, // Eksi bakiye olarak gösterelim (görsel amaçlı)
                        });
                      }
                    }

                    // Maaş Hesabı
                    toplamHakedis =
                        (tamGun * widget.isci.gunlukMaas) +
                        (yarimGun * (widget.isci.gunlukMaas / 2));
                    double kalanAlacak =
                        toplamHakedis - toplamAvans + toplamKarsilananGider;

                    // Listeyi tarihe göre sırala
                    tumHareketler.sort(
                      (a, b) => (a['tarih'] as DateTime).compareTo(b['tarih']),
                    );

                    return Column(
                      children: [
                        // 3. ÖZET KARTI (HESAP TABLOSU)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
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
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSummaryItem(
                                      "Çalışılan",
                                      "${tamGun}T, ${yarimGun}Y",
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F2A44),
                                    ),
                                    _buildSummaryItem(
                                      "Hakediş",
                                      isFinans
                                          ? "${toplamHakedis.toStringAsFixed(0)} ₺"
                                          : "--",
                                      isDark
                                          ? Colors.lightGreenAccent
                                          : const Color(0xFF1B7F4D),
                                    ),
                                    _buildSummaryItem(
                                      "Avans",
                                      isFinans
                                          ? "${toplamAvans.toStringAsFixed(0)} ₺"
                                          : "--",
                                      isDark
                                          ? Colors.orangeAccent
                                          : const Color(0xFFB46900),
                                    ),
                                  ],
                                ),
                                if (isFinans) ...[
                                  Divider(
                                    color:
                                        isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                    height: 24,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "KALAN ALACAK: ",
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        "${kalanAlacak.toStringAsFixed(2)} TL",
                                        style: TextStyle(
                                          color:
                                              kalanAlacak >= 0
                                                  ? (isDark
                                                      ? Colors.white
                                                      : const Color(
                                                        0xFF0F2A44,
                                                      ))
                                                  : Colors.redAccent,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Karşıladığı gider: ",
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "${toplamKarsilananGider.toStringAsFixed(2)} TL",
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.orangeAccent
                                                  : const Color(0xFFB46900),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 4. HAREKET LİSTESİ (Çalışma + Avanslar)
                        Expanded(
                          child:
                              tumHareketler.isEmpty
                                  ? Center(
                                    child: Text(
                                      "Bu ay kayıt bulunamadı.",
                                      style: TextStyle(
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      _shellDockBodyPadding,
                                    ),
                                    itemCount: tumHareketler.length,
                                    itemBuilder: (context, index) {
                                      final item = tumHareketler[index];
                                      final bool isAvans = item['tip'] == 'avans';
                                      final bool isGider = item['tip'] == 'gider';
                                      final double tutar =
                                          (item['tutar'] as double)
                                              .abs(); // Mutlak değer

                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isAvans
                                                    ? Colors.red.withOpacity(0.3)
                                                    : isGider
                                                        ? Colors.orange.withOpacity(
                                                          0.3,
                                                        )
                                                        : Colors.green.withOpacity(
                                                          0.3,
                                                        ),
                                            width: 1,
                                          ),
                                        ),
                                        color:
                                            isDark
                                                ? const Color(0xFF101317)
                                                : const Color(0xFFF7FBFD),
                                        child: ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color:
                                                  isAvans
                                                      ? Colors.red.withOpacity(0.1)
                                                      : isGider
                                                          ? Colors.orange
                                                              .withOpacity(0.1)
                                                          : Colors.green
                                                              .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              isAvans
                                                  ? Icons.money_off
                                                  : isGider
                                                      ? Icons.receipt_long
                                                      : Icons.engineering,
                                              color:
                                                  isAvans
                                                      ? Colors.red
                                                      : isGider
                                                          ? Colors.orange
                                                          : Colors.green,
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            item['baslik'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            "${DateFormat('dd MMM EEEE', 'tr_TR').format(item['tarih'])} • ${item['detay']}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing:
                                              isFinans
                                                  ? Text(
                                                    "${isAvans ? '-' : '+'}${tutar.toStringAsFixed(0)} ₺",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color:
                                                          isAvans
                                                              ? Colors.red
                                                              : isGider
                                                                  ? Colors.orange
                                                                  : Colors.green,
                                                    ),
                                                  )
                                                  : null,
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  // Özet Kartı İçin Yardımcı Widget
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
