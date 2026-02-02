import 'dart:ui'; // Blur efekti için GEREKLİ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'format_yardimcisi.dart'; // Para formatı için

class OdemelerEkrani extends StatefulWidget {
  final String teamId;
  const OdemelerEkrani({super.key, required this.teamId});

  @override
  State<OdemelerEkrani> createState() => _OdemelerEkraniState();
}

class _OdemelerEkraniState extends State<OdemelerEkrani> {
  // --- 1. SİLME ONAYI (MODERN & BLUR) ---
  Future<void> _silmeOnayi(BuildContext context, VoidCallback onConfirm) async {
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Silinsin mi?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Bu kaydı kalıcı olarak silmek istediğinize emin misiniz?",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "İptal",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onConfirm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Sil",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // --- 2. ÖDEME EKLEME DİYALOĞU (MODERN & BLUR) ---
  void _odemeEkleDialog(BuildContext context, FirestoreServisi servisi) {
    final miktarCtrl = TextEditingController();
    final alanKisiCtrl = TextEditingController();
    String? seciliSantiye;
    DateTime seciliTarih = DateTime.now();

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
              child: StreamBuilder<List<Santiye>>(
                stream: servisi.getSantiyelerStream(widget.teamId),
                builder: (context, snapshot) {
                  final santiyeler = snapshot.data ?? [];
                  return StatefulBuilder(
                    builder:
                        (ctx, setDialogState) => Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Yeni Ödeme Girişi",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  if (santiyeler.isEmpty)
                                    const Text(
                                      "Önce şantiye ekleyin.",
                                      style: TextStyle(color: Colors.redAccent),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: seciliSantiye,
                                          hint: const Text(
                                            "Şantiye Seçin",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          dropdownColor: const Color(
                                            0xFF2C2C2E,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          items:
                                              santiyeler
                                                  .map(
                                                    (s) => DropdownMenuItem(
                                                      value: s.ad,
                                                      child: Text(s.ad),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged:
                                              (v) => setDialogState(
                                                () => seciliSantiye = v,
                                              ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),

                                  _buildBlurInput(
                                    miktarCtrl,
                                    "Miktar",
                                    Icons.attach_money,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBlurInput(
                                    alanKisiCtrl,
                                    "Alan Kişi",
                                    Icons.person_outline,
                                    isNumber: false,
                                  ),
                                  const SizedBox(height: 16),

                                  InkWell(
                                    onTap: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: seciliTarih,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (p != null)
                                        setDialogState(() => seciliTarih = p);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Tarih: ${DateFormat('dd.MM.yyyy').format(seciliTarih)}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            "İptal",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              (seciliSantiye == null)
                                                  ? null
                                                  : () async {
                                                    if (miktarCtrl
                                                        .text
                                                        .isNotEmpty) {
                                                      final odeme = AlinanOdeme(
                                                        miktar:
                                                            double.tryParse(
                                                              miktarCtrl.text,
                                                            ) ??
                                                            0,
                                                        santiyeAdi:
                                                            seciliSantiye!,
                                                        alanKisi:
                                                            alanKisiCtrl.text,
                                                        tarih: seciliTarih,
                                                      );
                                                      Navigator.pop(ctx);
                                                      await servisi.odemeEkle(
                                                        widget.teamId,
                                                        odeme,
                                                      );
                                                    }
                                                  },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            "Kaydet",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 3. AVANS EKLEME DİYALOĞU (MODERN & BLUR) ---
  void _avansEkleDialog(BuildContext context, FirestoreServisi servisi) {
    final miktarCtrl = TextEditingController();
    Isci? seciliIsci;
    DateTime seciliTarih = DateTime.now();

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
              child: StreamBuilder<List<Isci>>(
                stream: servisi.getIscilerStream(widget.teamId),
                builder: (context, snapshot) {
                  final isciler = snapshot.data ?? [];
                  return StatefulBuilder(
                    builder:
                        (ctx, setDialogState) => Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Yeni Avans Girişi",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  if (isciler.isEmpty)
                                    const Text(
                                      "Önce işçi ekleyin.",
                                      style: TextStyle(color: Colors.redAccent),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<Isci>(
                                          value: seciliIsci,
                                          hint: const Text(
                                            "İşçi Seçin",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          dropdownColor: const Color(
                                            0xFF2C2C2E,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          items:
                                              isciler
                                                  .map(
                                                    (i) => DropdownMenuItem(
                                                      value: i,
                                                      child: Text(i.ad),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged:
                                              (v) => setDialogState(
                                                () => seciliIsci = v,
                                              ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),

                                  _buildBlurInput(
                                    miktarCtrl,
                                    "Miktar",
                                    Icons.attach_money,
                                  ),
                                  const SizedBox(height: 16),

                                  InkWell(
                                    onTap: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: seciliTarih,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (p != null)
                                        setDialogState(() => seciliTarih = p);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Tarih: ${DateFormat('dd.MM.yyyy').format(seciliTarih)}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            "İptal",
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              (seciliIsci == null)
                                                  ? null
                                                  : () async {
                                                    if (miktarCtrl
                                                        .text
                                                        .isNotEmpty) {
                                                      final avans =
                                                          VerilenAvans(
                                                            miktar:
                                                                double.tryParse(
                                                                  miktarCtrl
                                                                      .text,
                                                                ) ??
                                                                0,
                                                            isci: seciliIsci!,
                                                            tarih: seciliTarih,
                                                          );
                                                      Navigator.pop(ctx);
                                                      await servisi.avansEkle(
                                                        widget.teamId,
                                                        avans,
                                                      );
                                                    }
                                                  },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            "Kaydet",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  // --- YARDIMCI INPUT WIDGET ---
  Widget _buildBlurInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = true,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ödemeler ve Avanslar"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.download), text: "Alınan"),
              Tab(icon: Icon(Icons.upload), text: "Verilen"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: ÖDEMELER LİSTESİ
            Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _odemeEkleDialog(context, servisi),
                label: const Text("Ödeme Ekle"),
                icon: const Icon(Icons.add),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              body: StreamBuilder<List<AlinanOdeme>>(
                stream: servisi.getOdemelerStream(widget.teamId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  final odemeler = snapshot.data ?? [];
                  if (odemeler.isEmpty)
                    return const Center(child: Text("Kayıtlı ödeme yok."));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: odemeler.length,
                    itemBuilder: (context, index) {
                      final odeme = odemeler[index];
                      // Formatlayici.yap() kullanıyoruz
                      return _buildModernListCard(
                        context: context,
                        isDark: isDark,
                        icon: Icons.arrow_downward,
                        iconColor: Colors.green,
                        title: Formatlayici.yap(
                          odeme.miktar,
                        ), // ÖRNEK: 10.000,00 TL
                        subtitle: "${odeme.santiyeAdi} - ${odeme.alanKisi}",
                        date: odeme.tarih,
                        onDelete:
                            () => _silmeOnayi(
                              context,
                              () => servisi.odemeSil(widget.teamId, odeme.id!),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
            // TAB 2: AVANSLAR LİSTESİ
            Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _avansEkleDialog(context, servisi),
                label: const Text("Avans Ekle"),
                icon: const Icon(Icons.add),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              body: StreamBuilder<List<VerilenAvans>>(
                stream: servisi.getAvanslarStream(widget.teamId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  final avanslar = snapshot.data ?? [];
                  if (avanslar.isEmpty)
                    return const Center(child: Text("Kayıtlı avans yok."));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: avanslar.length,
                    itemBuilder: (context, index) {
                      final avans = avanslar[index];
                      // Formatlayici.yap() kullanıyoruz
                      return _buildModernListCard(
                        context: context,
                        isDark: isDark,
                        icon: Icons.arrow_upward,
                        iconColor: Colors.redAccent,
                        title: Formatlayici.yap(
                          avans.miktar,
                        ), // ÖRNEK: 5.000,00 TL
                        subtitle: avans.isci.ad,
                        date: avans.tarih,
                        onDelete:
                            () => _silmeOnayi(
                              context,
                              () => servisi.avansSil(widget.teamId, avans.id!),
                            ),
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

  // --- ORTAK MODERN KART TASARIMI ---
  Widget _buildModernListCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required DateTime date,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            Text(
              DateFormat('dd.MM.yyyy').format(date),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
