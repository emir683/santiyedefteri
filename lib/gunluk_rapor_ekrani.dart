import 'dart:ui'; // Blur efekti için gerekli
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'privacy_provider.dart';
import 'santiye_ekrani.dart';
import 'isci_ekrani.dart';

class GunlukRaporEkrani extends StatefulWidget {
  final String teamId;
  const GunlukRaporEkrani({super.key, required this.teamId});

  @override
  State<GunlukRaporEkrani> createState() => _GunlukRaporEkraniState();
}

class _GunlukRaporEkraniState extends State<GunlukRaporEkrani> {
  DateTime _seciliGun = DateTime.now();
  DateTime _odaklanilanGun = DateTime.now();
  bool _calendarVisible = false;

  // --- HIZLI YOKLAMA POPUP (Aynı) ---
  void _hizliYoklamaBaslat(
    BuildContext context,
    GunlukSantiyeRaporu rapor,
    List<Isci> tumIsciler,
    StateSetter setMainModalState,
    VoidCallback onDegisiklik,
  ) {
    Map<String, String> geciciDurumlar = {};
    for (var isci in tumIsciler) {
      var mevcutKayit =
          rapor.calisanlar.where((c) => c.isci.ad == isci.ad).firstOrNull;
      geciciDurumlar[isci.id ?? isci.ad] =
          mevcutKayit != null ? mevcutKayit.durum : "Yok";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setSheetState) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Hızlı Yoklama",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child:
                          tumIsciler.isEmpty
                              ? const Center(
                                child: Text("Kayıtlı işçi bulunamadı."),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: tumIsciler.length,
                                itemBuilder: (context, index) {
                                  final isci = tumIsciler[index];
                                  final String id = isci.id ?? isci.ad;
                                  final String durum =
                                      geciciDurumlar[id] ?? "Yok";
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF2C2C2E)
                                              : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? Colors.transparent
                                                : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isci.ad,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildYoklamaOption(
                                              "Yok",
                                              durum == "Yok",
                                              Colors.grey,
                                              isDark,
                                              () => setSheetState(
                                                () =>
                                                    geciciDurumlar[id] = "Yok",
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildYoklamaOption(
                                              "Yarım",
                                              durum == "Yarım Gün",
                                              Colors.orange,
                                              isDark,
                                              () => setSheetState(
                                                () =>
                                                    geciciDurumlar[id] =
                                                        "Yarım Gün",
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildYoklamaOption(
                                              "Tam",
                                              durum == "Tam Gün",
                                              Colors.green,
                                              isDark,
                                              () => setSheetState(
                                                () =>
                                                    geciciDurumlar[id] =
                                                        "Tam Gün",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setMainModalState(() {
                            rapor.calisanlar.clear();
                            geciciDurumlar.forEach((id, seciliDurum) {
                              if (seciliDurum != "Yok") {
                                final isci = tumIsciler.firstWhere(
                                  (i) => (i.id ?? i.ad) == id,
                                );
                                rapor.calisanlar.add(
                                  GunlukCalisma(isci: isci, durum: seciliDurum),
                                );
                              }
                            });
                          });
                          onDegisiklik();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "YOKLAMAYI ONAYLA",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildYoklamaOption(
    String text,
    bool isSelected,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected ? color : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isSelected
                      ? color
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 0 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
          child: Text(
            text,
            style: TextStyle(
              color:
                  isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.black54),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // --- RAPOR DÜZENLEME EKRANI ---
  void _raporDuzenle(
    BuildContext context,
    FirestoreServisi servisi,
    String santiyeAdi,
    GunlukSantiyeRaporu? mevcutRapor,
    List<Isci> tumIsciler,
  ) {
    final rapor =
        mevcutRapor ??
        GunlukSantiyeRaporu(santiyeAdi: santiyeAdi, tarih: _seciliGun);

    final benzinCtrl = TextEditingController(
      text: rapor.benzinGideri == 0 ? "" : rapor.benzinGideri.toString(),
    );
    final yemekCtrl = TextEditingController(
      text: rapor.yemekGideri == 0 ? "" : rapor.yemekGideri.toString(),
    );
    final ekMasrafCtrl = TextEditingController(
      text: rapor.ekMasraflar == 0 ? "" : rapor.ekMasraflar.toString(),
    );
    final aciklamaCtrl = TextEditingController(text: rapor.aciklama);

    bool degisiklikVar = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent, // 1. ARKA PLAN ŞEFFAF
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;

              Future<void> verileriKaydet() async {
                rapor.benzinGideri = double.tryParse(benzinCtrl.text) ?? 0;
                rapor.yemekGideri = double.tryParse(yemekCtrl.text) ?? 0;
                rapor.ekMasraflar = double.tryParse(ekMasrafCtrl.text) ?? 0;
                rapor.aciklama = aciklamaCtrl.text.trim();
                await servisi.raporKaydet(widget.teamId, rapor);
                if (mounted) Navigator.pop(context);
              }

              Future<bool> onWillPop() async {
                if (!degisiklikVar) return true;
                final sonuc = await showDialog<String>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        title: const Text("Kaydedilmemiş Değişiklikler"),
                        content: const Text("Kaydetmek ister misiniz?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, 'iptal'),
                            child: const Text("Vazgeç"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, 'kapat'),
                            child: const Text(
                              "Kaydetme",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(c, 'kaydet'),
                            child: const Text("Kaydet"),
                          ),
                        ],
                      ),
                );
                if (sonuc == 'kaydet') {
                  await verileriKaydet();
                  return true;
                } else if (sonuc == 'kapat') {
                  return true;
                }
                return false;
              }

              return PopScope(
                canPop: !degisiklikVar,
                onPopInvoked: (didPop) async {
                  if (didPop) return;
                  if (await onWillPop() && context.mounted)
                    Navigator.of(context).pop();
                },

                // 2. BLUR EFEKTİ İÇİN ClipRRect ve BackdropFilter KULLANIYORUZ
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10,
                      sigmaY: 10,
                    ), // Bulanıklık şiddeti
                    child: Container(
                      decoration: BoxDecoration(
                        // 3. RENK OPAKLIĞINI DÜŞÜRÜYORUZ (Şeffaflık)
                        color:
                            isDark
                                ? const Color(0xFF121212).withOpacity(
                                  0.35,
                                ) // Koyu modda %85 opak siyah
                                : Colors.white.withOpacity(
                                  0.40,
                                ), // Açık modda %90 opak beyaz
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ), // Üstte ince cam çizgisi
                      ),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        maxChildSize: 0.95,
                        minChildSize: 0.5,
                        expand: false,
                        builder:
                            (_, scrollController) => Column(
                              children: [
                                // Tutamaç
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),

                                Expanded(
                                  child: ListView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(24),
                                    children: [
                                      Text(
                                        santiyeAdi,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                          'tr_TR',
                                        ).format(_seciliGun),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Çalışanlar Başlığı ve Butonlar
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "Çalışan Personeller",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.flash_on,
                                              size: 16,
                                            ),
                                            label: const Text("Hızlı Yoklama"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade800,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed:
                                                () => _hizliYoklamaBaslat(
                                                  context,
                                                  rapor,
                                                  tumIsciler,
                                                  setModalState,
                                                  () => degisiklikVar = true,
                                                ),
                                          ),
                                        ],
                                      ),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text("Tek Kişi Ekle"),
                                          onPressed: () {
                                            final eklenebilirIsciler =
                                                tumIsciler
                                                    .where(
                                                      (i) =>
                                                          !rapor.calisanlar.any(
                                                            (c) =>
                                                                c.isci.ad ==
                                                                i.ad,
                                                          ),
                                                    )
                                                    .toList();
                                            showDialog(
                                              context: context,
                                              builder: (dCtx) {
                                                return AlertDialog(
                                                  title: const Text("İşçi Seç"),
                                                  content: SizedBox(
                                                    width: double.maxFinite,
                                                    child:
                                                        eklenebilirIsciler
                                                                .isEmpty
                                                            ? const Text(
                                                              "Eklenebilecek işçi kalmadı.",
                                                            )
                                                            : ListView.builder(
                                                              shrinkWrap: true,
                                                              itemCount:
                                                                  eklenebilirIsciler
                                                                      .length,
                                                              itemBuilder:
                                                                  (
                                                                    c,
                                                                    i,
                                                                  ) => ListTile(
                                                                    leading: CircleAvatar(
                                                                      child: Text(
                                                                        eklenebilirIsciler[i]
                                                                            .ad[0],
                                                                      ),
                                                                    ),
                                                                    title: Text(
                                                                      eklenebilirIsciler[i]
                                                                          .ad,
                                                                    ),
                                                                    onTap: () {
                                                                      Navigator.pop(
                                                                        dCtx,
                                                                      );
                                                                      showDialog(
                                                                        context:
                                                                            context,
                                                                        builder:
                                                                            (
                                                                              secimCtx,
                                                                            ) => AlertDialog(
                                                                              title: Text(
                                                                                "${eklenebilirIsciler[i].ad} Durumu",
                                                                              ),
                                                                              content: const Text(
                                                                                "Nasıl çalıştı?",
                                                                              ),
                                                                              actions: [
                                                                                TextButton(
                                                                                  onPressed: () {
                                                                                    setModalState(
                                                                                      () {
                                                                                        rapor.calisanlar.add(
                                                                                          GunlukCalisma(
                                                                                            isci:
                                                                                                eklenebilirIsciler[i],
                                                                                            durum:
                                                                                                "Yarım Gün",
                                                                                          ),
                                                                                        );
                                                                                        degisiklikVar =
                                                                                            true;
                                                                                      },
                                                                                    );
                                                                                    Navigator.pop(
                                                                                      secimCtx,
                                                                                    );
                                                                                  },
                                                                                  child: const Text(
                                                                                    "Yarım",
                                                                                  ),
                                                                                ),
                                                                                ElevatedButton(
                                                                                  onPressed: () {
                                                                                    setModalState(
                                                                                      () {
                                                                                        rapor.calisanlar.add(
                                                                                          GunlukCalisma(
                                                                                            isci:
                                                                                                eklenebilirIsciler[i],
                                                                                            durum:
                                                                                                "Tam Gün",
                                                                                          ),
                                                                                        );
                                                                                        degisiklikVar =
                                                                                            true;
                                                                                      },
                                                                                    );
                                                                                    Navigator.pop(
                                                                                      secimCtx,
                                                                                    );
                                                                                  },
                                                                                  child: const Text(
                                                                                    "Tam",
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                      );
                                                                    },
                                                                  ),
                                                            ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),

                                      // Çalışan Listesi
                                      if (rapor.calisanlar.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? Colors.white.withOpacity(
                                                      0.05,
                                                    )
                                                    : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              "Henüz çalışan eklenmedi.",
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...rapor.calisanlar.map(
                                          (c) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? const Color(0xFF252525)
                                                      : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.withOpacity(
                                                  0.1,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Colors.blue
                                                      .withOpacity(0.2),
                                                  child: Text(
                                                    c.isci.ad[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        c.isci.ad,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              c.durum ==
                                                                      "Tam Gün"
                                                                  ? Colors.green
                                                                      .withOpacity(
                                                                        0.2,
                                                                      )
                                                                  : Colors
                                                                      .orange
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          c.durum,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                c.durum ==
                                                                        "Tam Gün"
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .orange,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed:
                                                      () => setModalState(() {
                                                        rapor.calisanlar.remove(
                                                          c,
                                                        );
                                                        degisiklikVar = true;
                                                      }),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 24),
                                      const Text(
                                        "Günlük Masraflar",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Giderler (Focus Modlu)
                                      _buildFocusInput(
                                        context: context,
                                        controller: benzinCtrl,
                                        label: "Benzin Gideri",
                                        icon: Icons.local_gas_station_outlined,
                                        isDark: isDark,
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFocusInput(
                                        context: context,
                                        controller: yemekCtrl,
                                        label: "Yemek Gideri",
                                        icon: Icons.restaurant_outlined,
                                        isDark: isDark,
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildFocusInput(
                                        context: context,
                                        controller: ekMasrafCtrl,
                                        label: "Ek Masraflar",
                                        icon: Icons.add_shopping_cart_outlined,
                                        isDark: isDark,
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                      ),

                                      const SizedBox(height: 24),
                                      const Text(
                                        "Açıklama / Not",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Not Alanı (Focus Modlu - MultiLine)
                                      _buildFocusInput(
                                        context: context,
                                        controller: aciklamaCtrl,
                                        label: "Notunuzu girin...",
                                        icon: Icons.note_alt_outlined,
                                        isDark: isDark,
                                        onChanged:
                                            () => setModalState(
                                              () => degisiklikVar = true,
                                            ),
                                        isMultiLine: true,
                                      ),

                                      const SizedBox(height: 32),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 4,
                                        ),
                                        onPressed: verileriKaydet,
                                        child: const Text(
                                          "KAYDET VE KAPAT",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  // ==========================================
  // 3. ODAKLANAN INPUT WIDGET'I (YENİ) 👁️✨
  // ==========================================
  Widget _buildFocusInput({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onChanged,
    bool isMultiLine = false,
  }) {
    return Consumer<PrivacyProvider>(
      builder: (context, privacy, child) {
        final String displayValue =
            controller.text.isEmpty
                ? ""
                : (privacy.isHidden && !isMultiLine ? "****" : controller.text);

        return InkWell(
          onTap: () {
            // Tıklayınca Odak Modunu Aç (Dialog)
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: "Kapat",
              barrierColor: Colors.black.withOpacity(0.8), // Arka planı karart
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (ctx, anim1, anim2) {
                return Scaffold(
                  // Klavye yönetimi için Scaffold şart
                  backgroundColor: Colors.transparent,
                  body: Stack(
                    children: [
                      // Bulanıklık Efekti
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(color: Colors.transparent),
                      ),
                      // İçerik
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: controller,
                                autofocus: true, // Otomatik klavye aç
                                keyboardType:
                                    isMultiLine
                                        ? TextInputType.multiline
                                        : TextInputType.number,
                                maxLines: isMultiLine ? 3 : 1,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(icon, color: Colors.black87),
                                  suffixText: isMultiLine ? null : "TL",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 20,
                                  ),
                                ),
                                onChanged: (val) {
                                  onChanged(); // Değişiklik var işaretle
                                },
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  "TAMAM",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  "Kapat",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ).then((_) {
              // Dialog kapanınca ana ekranı güncelle (değer değişmiş olabilir)
              onChanged();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 16),
                Expanded(
                  // Yazıyı sarmaladık, böylece taşma yapamaz
                  child: Text(
                    displayValue.isEmpty
                        ? "Girilmedi"
                        : "$displayValue${isMultiLine ? '' : ' TL'}",
                    textAlign: TextAlign.right, // Sağa yasla
                    maxLines: 1, // Tek satır olsun
                    overflow: TextOverflow.ellipsis, // Sığmazsa "..." koy
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          displayValue.isEmpty
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black),
                      fontSize: 16,
                    ),
                  ),
                ),
                // -------------------------------
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // YENİ KULLANICI ONBOARDING WIDGET'I
  // ==========================================
  Widget _buildOnboardingWidget({
    required BuildContext context,
    required bool isDark,
    required bool santiyelerBos,
    required bool iscilerBos,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.engineering_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              "Başlamak için hazır mısınız?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Günlük rapor oluşturabilmek için önce şantiye ve işçi eklemeniz gerekiyor.",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Şantiye Ekle Butonu
            if (santiyelerBos)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.construction, size: 20),
                  label: const Text("Şantiye Ekle"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SantiyeEkrani(teamId: widget.teamId),
                      ),
                    );
                  },
                ),
              ),

            // İşçi Ekle Butonu
            if (iscilerBos)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, size: 20),
                  label: const Text("İşçi Ekle"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IsciEkrani(teamId: widget.teamId),
                      ),
                    );
                  },
                ),
              ),

            // Durum bilgileri
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  santiyelerBos ? Icons.close : Icons.check_circle,
                  size: 16,
                  color: santiyelerBos ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  santiyelerBos ? "Şantiye yok" : "Şantiye ✓",
                  style: TextStyle(
                    color: santiyelerBos ? Colors.red : Colors.green,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  iscilerBos ? Icons.close : Icons.check_circle,
                  size: 16,
                  color: iscilerBos ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  iscilerBos ? "İşçi yok" : "İşçi ✓",
                  style: TextStyle(
                    color: iscilerBos ? Colors.red : Colors.green,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final genisBaslangic = DateTime(2024, 1, 1);
    final genisBitis = DateTime(2026, 12, 31);

    return Scaffold(
      appBar: AppBar(title: const Text('Günlük Rapor')),
      body: StreamBuilder<List<GunlukSantiyeRaporu>>(
        stream: servisi.getRaporlarStream(
          widget.teamId,
          genisBaslangic,
          genisBitis,
        ),
        builder: (context, snapshotRaporlar) {
          if (!snapshotRaporlar.hasData)
            return const Center(child: CircularProgressIndicator());
          final tumRaporlar = snapshotRaporlar.data!;
          List<GunlukSantiyeRaporu> _gununEtkinlikleri(DateTime gun) {
            return tumRaporlar
                .where((rapor) => isSameDay(rapor.tarih, gun))
                .toList();
          }

          final seciliGunRaporlari =
              tumRaporlar.where((r) => isSameDay(r.tarih, _seciliGun)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      DateFormat.yMMMMEEEEd('tr_TR').format(_seciliGun),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        _calendarVisible
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed:
                          () => setState(
                            () => _calendarVisible = !_calendarVisible,
                          ),
                    ),
                    onTap:
                        () => setState(
                          () => _calendarVisible = !_calendarVisible,
                        ),
                  ),
                ),
              ),
              if (_calendarVisible)
                Center(
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TableCalendar(
                        locale: 'tr_TR',
                        firstDay: genisBaslangic,
                        lastDay: genisBitis,
                        focusedDay: _odaklanilanGun,
                        currentDay: _seciliGun,
                        eventLoader: _gununEtkinlikleri,
                        calendarStyle: CalendarStyle(
                          markerDecoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        onDaySelected:
                            (s, f) => setState(() {
                              _seciliGun = s;
                              _odaklanilanGun = f;
                            }),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<Santiye>>(
                  stream: servisi.getSantiyelerStream(widget.teamId),
                  builder: (context, snapshotSantiyeler) {
                    if (!snapshotSantiyeler.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final santiyeler = snapshotSantiyeler.data!;
                    return StreamBuilder<List<Isci>>(
                      stream: servisi.getIscilerStream(widget.teamId),
                      builder: (context, snapshotIsciler) {
                        final tumIsciler = snapshotIsciler.data ?? [];

                        // Yeni kullanıcı için onboarding kontrolü
                        if (santiyeler.isEmpty || tumIsciler.isEmpty) {
                          return _buildOnboardingWidget(
                            context: context,
                            isDark: isDark,
                            santiyelerBos: santiyeler.isEmpty,
                            iscilerBos: tumIsciler.isEmpty,
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: santiyeler.length,
                          itemBuilder: (context, index) {
                            final santiyeAdi = santiyeler[index].ad;
                            final mevcutRapor =
                                seciliGunRaporlari
                                    .where((r) => r.santiyeAdi == santiyeAdi)
                                    .firstOrNull;
                            final bool dolu = mevcutRapor != null;
                            Color cardColor =
                                isDark ? const Color(0xFF1E1E1E) : Colors.white;
                            Color? borderColor = Colors.grey.withOpacity(0.3);
                            if (dolu) {
                              cardColor =
                                  isDark
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.green.shade50;
                              borderColor = Colors.green;
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: borderColor!,
                                    width: 2.0,
                                  ),
                                ),
                                color: cardColor,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap:
                                      () => _raporDuzenle(
                                        context,
                                        servisi,
                                        santiyeAdi,
                                        mevcutRapor,
                                        tumIsciler,
                                      ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 20,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color:
                                                    dolu
                                                        ? Colors.green
                                                        : Colors.grey.shade400,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                dolu
                                                    ? Icons.check
                                                    : Icons.construction,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    santiyeAdi,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Consumer<PrivacyProvider>(
                                                    builder: (
                                                      context,
                                                      privacy,
                                                      child,
                                                    ) {
                                                      if (!dolu)
                                                        return const Text(
                                                          "Veri girilmemiş",
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                          ),
                                                        );
                                                      final toplam =
                                                          mevcutRapor!
                                                              .benzinGideri +
                                                          mevcutRapor
                                                              .yemekGideri +
                                                          mevcutRapor
                                                              .ekMasraflar;
                                                      final tutarMetni =
                                                          privacy.isHidden
                                                              ? "**** TL"
                                                              : "${toplam.toStringAsFixed(2)} TL";
                                                      return Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "${mevcutRapor.calisanlar.length} çalışan",
                                                            style: TextStyle(
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .white70
                                                                      : Colors
                                                                          .black87,
                                                            ),
                                                          ),
                                                          Text(
                                                            "Toplam: $tutarMetni",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .greenAccent
                                                                      : Colors
                                                                          .green
                                                                          .shade800,
                                                            ),
                                                          ),
                                                          if (mevcutRapor
                                                              .aciklama
                                                              .isNotEmpty)
                                                            Text(
                                                              "📝 ${mevcutRapor.aciklama}",
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey[600],
                                                              ),
                                                            ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
