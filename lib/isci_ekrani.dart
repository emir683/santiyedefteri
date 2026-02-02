import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'isci_detay_ekrani.dart';
import 'dart:ui';
class IsciEkrani extends StatefulWidget {
  final String teamId;
  const IsciEkrani({super.key, required this.teamId});

  @override
  State<IsciEkrani> createState() => _IsciEkraniState();
}

class _IsciEkraniState extends State<IsciEkrani> {
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _maasController = TextEditingController();

  @override
  void dispose() {
    _adController.dispose();
    _maasController.dispose();
    super.dispose();
  }

  // İşçi Ekleme veya Düzenleme Diyaloğu
 Future<void> _isciEkleVeyaDuzenleDialog(FirestoreServisi servisi, {Isci? mevcutIsci}) async {
    if (mevcutIsci != null) {
      _adController.text = mevcutIsci.ad;
      _maasController.text = mevcutIsci.gunlukMaas.toString();
    } else {
      _adController.clear();
      _maasController.clear();
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            // BLUR EFEKTİ
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
            
            // PENCERE
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mevcutIsci != null ? 'İşçiyi Düzenle' : 'Yeni İşçi Ekle',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 24),
                      
                      // AD SOYAD INPUT
                      TextField(
                        controller: _adController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Ad Soyad",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.person, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // MAAŞ INPUT
                      TextField(
                        controller: _maasController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Günlük Maaş (TL)",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.attach_money, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // BUTONLAR
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx), 
                              child: const Text("İptal", style: TextStyle(color: Colors.grey))
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_adController.text.isNotEmpty && _maasController.text.isNotEmpty) {
                                  final isci = Isci(
                                    id: mevcutIsci?.id,
                                    ad: _adController.text.trim(),
                                    gunlukMaas: double.tryParse(_maasController.text) ?? 0,
                                  );
                                  
                                  if (mevcutIsci != null) {
                                    await servisi.isciGuncelle(widget.teamId, isci);
                                  } else {
                                    await servisi.isciEkle(widget.teamId, isci);
                                  }
                                  if (mounted) Navigator.pop(ctx);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, // Mavi buton
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Future<void> _silmeOnayi(FirestoreServisi servisi, String isciId, String isciAdi) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_remove, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "İşçiyi Sil", 
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "'$isciAdi' adlı işçiyi silmek istediğinize emin misiniz?",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[300], fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx), 
                              child: const Text("İptal", style: TextStyle(color: Colors.grey))
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await servisi.isciSil(widget.teamId, isciId);
                                if (mounted) Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              child: const Text("Sil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('İşçiler')),
      body: StreamBuilder<List<Isci>>(
        stream: servisi.getIscilerStream(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Henüz işçi eklenmemiş.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }
          
          final isciler = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: isciler.length,
            itemBuilder: (context, index) {
              final isci = isciler[index];
              
              return Card(
                elevation: 4, // Gölge efekti
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!, 
                    width: 1
                  ), // İnce çerçeve
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Detay sayfasına git
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => IsciDetayEkrani(isci: isci, teamId: widget.teamId)
                      )
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Sol İkon Kutusu
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.engineering, 
                            size: 30, 
                            color: isDark ? Colors.white70 : Colors.blue
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Orta Bilgi Alanı
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isci.ad, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isci.gunlukMaas.toStringAsFixed(2)} TL / Gün', 
                                style: TextStyle(
                                  fontWeight: FontWeight.w500, 
                                  color: isDark ? Colors.grey[400] : Colors.grey[700]
                                )
                              ),
                            ],
                          ),
                        ),
                        
                        // Sağ Butonlar
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue), 
                              onPressed: () => _isciEkleVeyaDuzenleDialog(servisi, mevcutIsci: isci)
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                              onPressed: () => _silmeOnayi(servisi, isci.id!, isci.ad)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _isciEkleVeyaDuzenleDialog(servisi),
        icon: const Icon(Icons.person_add),
        label: const Text("İşçi Ekle"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}