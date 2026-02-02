import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class IslemGecmisiEkrani extends StatefulWidget {
  final String teamId;
  const IslemGecmisiEkrani({super.key, required this.teamId});

  @override
  State<IslemGecmisiEkrani> createState() => _IslemGecmisiEkraniState();
}

class _IslemGecmisiEkraniState extends State<IslemGecmisiEkrani> {

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  // İşlem tipine göre renk ve ikon seçimi
  Map<String, dynamic> _getStyleForAction(String? islemTipi) {
    switch (islemTipi) {
      case 'ISCI_EKLEME':
        return {'icon': Icons.person_add, 'color': Colors.blue};
      case 'ISCI_SILME':
      case 'UYE_CIKARMA':
      case 'SANTIYE_SILME':
        return {'icon': Icons.delete_forever, 'color': Colors.redAccent};
      case 'ISCI_GUNCELLEME':
        return {'icon': Icons.manage_accounts, 'color': Colors.orange};
      case 'SANTIYE_EKLEME':
        return {'icon': Icons.domain_add, 'color': Colors.purple};
      case 'GUNLUK_RAPOR_EKLEME':
      case 'GUNLUK_RAPOR_GUNCELLEME':
        return {'icon': Icons.edit_calendar, 'color': Colors.green};
      case 'ODEME_EKLEME':
        return {'icon': Icons.download, 'color': Colors.teal};
      case 'AVANS_EKLEME':
        return {'icon': Icons.upload, 'color': Colors.pinkAccent};
      default:
        return {'icon': Icons.history, 'color': Colors.grey};
    }
  }

 Widget _buildLogContent(String islemTipi, Map<String, dynamic> detaylar, String username) {
    // style değişkeni burada tanımlı olduğu için aşağıda 'const' kullanamayız
    final style = const TextStyle(fontSize: 15, color: Colors.white);
    final bold = const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white);
    
    List<TextSpan> spans = [
      TextSpan(text: "$username ", style: bold.copyWith(color: Colors.greenAccent)), 
    ];

    switch (islemTipi) {
      case 'ISCI_EKLEME':
        spans.add(TextSpan(text: "${detaylar['isciAdi'] ?? 'birini'} adlı kişiyi işçi olarak ekledi.", style: style));
        break;
      case 'ISCI_GUNCELLEME':
        spans.add(TextSpan(text: "${detaylar['isciAdi'] ?? 'bir'} işçisinin bilgilerini güncelledi.", style: style));
        break;
      case 'ISCI_SILME':
        // Buradaki TextSpan'ın başında const OLMAMALI çünkü style değişkenini kullanıyoruz
        spans.add(TextSpan(text: "Bir işçiyi sildi.", style: style));
        break;
      case 'SANTIYE_EKLEME':
        spans.add(TextSpan(text: "${detaylar['santiyeAdi'] ?? 'yeni'} şantiyesini ekledi.", style: style));
        break;
      case 'SANTIYE_SILME':
        spans.add(TextSpan(text: "${detaylar['santiyeAdi'] ?? 'bir'} şantiyesini sildi.", style: style));
        break;
      case 'GUNLUK_RAPOR_EKLEME':
      case 'GUNLUK_RAPOR_GUNCELLEME':
        String tarihStr = "";
        if (detaylar['tarih'] != null) {
          try {
            final dt = DateTime.parse(detaylar['tarih']);
            tarihStr = " (${DateFormat('dd MMM').format(dt)})";
          } catch (_) {}
        }
        spans.add(TextSpan(text: "${detaylar['santiyeAdi'] ?? 'Bilinmeyen'} şantiyesinin raporunu girdi/güncelledi$tarihStr.", style: style));
        break;
      case 'ODEME_EKLEME':
        spans.add(TextSpan(text: "${detaylar['miktar']} TL tutarında ödeme girişi yaptı.", style: style));
        break;
      case 'AVANS_EKLEME':
        spans.add(TextSpan(text: "${detaylar['isci'] ?? 'İşçiye'} ${detaylar['miktar']} TL avans verdi.", style: style));
        break;
      case 'UYE_CIKARMA':
        // Hata veren yer burasıydı: const TextSpan(...) -> TextSpan(...) yaptık
        spans.add(TextSpan(text: "Bir üyeyi ekipten çıkardı.", style: style));
        break;
      default:
        // Hata veren yer burasıydı: const TextSpan(...) -> TextSpan(...) yaptık
        spans.add(TextSpan(text: "bir işlem yaptı.", style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('history')
        .orderBy('tarih', descending: true)
        .limit(50); // Son 50 işlem yeterli

    return Scaffold(
      appBar: AppBar(title: const Text("İşlem Geçmişi")),
      body: StreamBuilder<QuerySnapshot>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade800),
                  const SizedBox(height: 16),
                  const Text("Henüz işlem geçmişi yok.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              final Timestamp? timestamp = data['tarih'];
              final String zaman = timestamp != null
                  ? DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(timestamp.toDate())
                  : '-';
              
              final String islemTipi = data['islemTipi'] ?? 'BILINMEYEN';
              final String username = data['kullaniciUsername'] ?? 'Bilinmeyen';
              final Map<String, dynamic> detaylar = data['detaylar'] ?? {};
              
              final styleInfo = _getStyleForAction(islemTipi);

              return Card(
                elevation: 2,
                color: const Color(0xFF1E1E1E), // Modern koyu kart rengi
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // İKON KUTUSU
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (styleInfo['color'] as Color).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(styleInfo['icon'], color: styleInfo['color'], size: 24),
                      ),
                      const SizedBox(width: 16),
                      
                      // İÇERİK
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogContent(islemTipi, detaylar, username),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(zaman, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}