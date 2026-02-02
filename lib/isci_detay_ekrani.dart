import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';

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

    // Ayın başı ve sonu
    final baslangic = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final bitis = DateTime(_gosterilenAy.year, _gosterilenAy.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isci.ad)),
      body: Column(
        children: [
          // 1. TARİH SEÇİCİ (Modern)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _gosterilenAy = DateTime(_gosterilenAy.year, _gosterilenAy.month - 1))),
                  Text(DateFormat.yMMMM('tr_TR').format(_gosterilenAy), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _gosterilenAy = DateTime(_gosterilenAy.year, _gosterilenAy.month + 1))),
                ],
              ),
            ),
          ),

          // 2. VERİLERİ ÇEK (Raporlar + Avanslar)
          Expanded(
            child: StreamBuilder<List<GunlukSantiyeRaporu>>(
              stream: servisi.getRaporlarStream(widget.teamId, baslangic, bitis),
              builder: (context, snapshotRaporlar) {
                // Raporlar yüklenirken bekleme
                if (!snapshotRaporlar.hasData) return const Center(child: CircularProgressIndicator());

                return StreamBuilder<List<VerilenAvans>>(
                  stream: servisi.getAvanslarStream(widget.teamId),
                  builder: (context, snapshotAvanslar) {
                    // Avanslar yüklenirken bekleme
                    if (!snapshotAvanslar.hasData) return const Center(child: CircularProgressIndicator());

                    // --- HESAPLAMA MOTORU ---
                    final raporlar = snapshotRaporlar.data!;
                    final avanslar = snapshotAvanslar.data!;
                    
                    // Listeyi oluşturacak veri havuzu
                    final tumHareketler = <Map<String, dynamic>>[];

                    int tamGun = 0;
                    int yarimGun = 0;
                    double toplamHakedis = 0;
                    double toplamAvans = 0;

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
                            'tutar': calisma.durum == "Tam Gün" ? widget.isci.gunlukMaas : (widget.isci.gunlukMaas / 2)
                          });
                        }
                      }
                    }

                    // 2. Avans Verilerini İşle (Sadece seçili ay)
                    for (var avans in avanslar) {
                      if (avans.isci.ad == widget.isci.ad && avans.tarih.year == _gosterilenAy.year && avans.tarih.month == _gosterilenAy.month) {
                        toplamAvans += avans.miktar;
                        
                        tumHareketler.add({
                          'tip': 'avans',
                          'tarih': avans.tarih,
                          'baslik': "Avans Alındı",
                          'detay': "Ödeme",
                          'tutar': -avans.miktar // Eksi bakiye olarak gösterelim (görsel amaçlı)
                        });
                      }
                    }

                    // Maaş Hesabı
                    toplamHakedis = (tamGun * widget.isci.gunlukMaas) + (yarimGun * (widget.isci.gunlukMaas / 2));
                    double kalanAlacak = toplamHakedis - toplamAvans;

                    // Listeyi tarihe göre sırala
                    tumHareketler.sort((a, b) => (a['tarih'] as DateTime).compareTo(b['tarih']));

                    return Column(
                      children: [
                        // 3. ÖZET KARTI (HESAP TABLOSU)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark 
                                  ? [Colors.blueGrey.shade900, Colors.blueGrey.shade800] 
                                  : [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSummaryItem("Çalışılan", "${tamGun}T, ${yarimGun}Y", Colors.white),
                                    _buildSummaryItem("Hakediş", "${toplamHakedis.toStringAsFixed(0)} ₺", Colors.lightGreenAccent),
                                    _buildSummaryItem("Avans", "${toplamAvans.toStringAsFixed(0)} ₺", Colors.orangeAccent),
                                  ],
                                ),
                                const Divider(color: Colors.white24, height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("KALAN ALACAK: ", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                    Text(
                                      "${kalanAlacak.toStringAsFixed(2)} TL",
                                      style: TextStyle(
                                        color: kalanAlacak >= 0 ? Colors.white : Colors.redAccent,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 4. HAREKET LİSTESİ (Çalışma + Avanslar)
                        Expanded(
                          child: tumHareketler.isEmpty
                          ? const Center(child: Text("Bu ay kayıt bulunamadı."))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: tumHareketler.length,
                              itemBuilder: (context, index) {
                                final item = tumHareketler[index];
                                final bool isAvans = item['tip'] == 'avans';
                                final double tutar = (item['tutar'] as double).abs(); // Mutlak değer

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: isAvans ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3), width: 1)
                                  ),
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isAvans ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10)
                                      ),
                                      child: Icon(
                                        isAvans ? Icons.money_off : Icons.engineering,
                                        color: isAvans ? Colors.red : Colors.green,
                                        size: 20
                                      ),
                                    ),
                                    title: Text(item['baslik'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      "${DateFormat('dd MMM EEEE', 'tr_TR').format(item['tarih'])} • ${item['detay']}",
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])
                                    ),
                                    trailing: Text(
                                      "${isAvans ? '-' : '+'}${tutar.toStringAsFixed(0)} ₺",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isAvans ? Colors.red : Colors.green
                                      ),
                                    ),
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
    );
  }

  // Özet Kartı İçin Yardımcı Widget
  Widget _buildSummaryItem(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}