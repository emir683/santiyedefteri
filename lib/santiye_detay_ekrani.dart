import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';

class SantiyeDetayEkrani extends StatefulWidget {
  final String santiyeAdi;
  final String teamId;

  const SantiyeDetayEkrani({super.key, required this.santiyeAdi, required this.teamId});

  @override
  State<SantiyeDetayEkrani> createState() => _SantiyeDetayEkraniState();
}

class _SantiyeDetayEkraniState extends State<SantiyeDetayEkrani> {
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
    final baslangic = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final bitis = DateTime(_gosterilenAy.year, _gosterilenAy.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(title: Text(widget.santiyeAdi)),
      body: Column(
        children: [
          // MODERN TARİH SEÇİCİ
          Padding(
            padding: const EdgeInsets.all(16.0),
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

          Expanded(
            child: StreamBuilder<List<GunlukSantiyeRaporu>>(
              stream: servisi.getRaporlarStream(widget.teamId, baslangic, bitis),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final raporlar = (snapshot.data ?? []).where((r) => r.santiyeAdi == widget.santiyeAdi).toList();
                if (raporlar.isEmpty) return const Center(child: Text("Bu ay şantiyede işlem yok."));

                raporlar.sort((a, b) => a.tarih.compareTo(b.tarih));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: raporlar.length,
                  itemBuilder: (context, index) {
                    final rapor = raporlar[index];
                    final toplamMasraf = rapor.benzinGideri + rapor.yemekGideri + rapor.ekMasraflar;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(DateFormat('dd').format(rapor.tarih), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                        title: Text(DateFormat.EEEE('tr_TR').format(rapor.tarih), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${rapor.calisanlar.length} Çalışan • $toplamMasraf TL Masraf", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        children: [
                          const Divider(height: 1),
                          ...rapor.calisanlar.map((c) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline, size: 18),
                            title: Text(c.isci.ad),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.durum == "Tam Gün" ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: Text(c.durum, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.durum == "Tam Gün" ? Colors.green : Colors.orange)),
                            ),
                          )),
                          if(toplamMasraf > 0) ListTile(dense: true, leading: const Icon(Icons.attach_money, size: 18, color: Colors.redAccent), title: const Text("Günlük Masraf Detayı"), trailing: Text("$toplamMasraf TL", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))
                        ],
                      ),
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
}