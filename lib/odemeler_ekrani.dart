import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'animasyon_yardimcisi.dart';
import 'data_models.dart';
import 'firestore_servisi.dart';
import 'format_yardimcisi.dart';
import 'user_model.dart';

const double _shellDockBodyPadding = 132;
const double _shellDockFabPadding = 96;
const Color _kBrandTeal = Color(0xFF14B8A6);

class OdemelerEkrani extends StatefulWidget {
  final String teamId;

  const OdemelerEkrani({super.key, required this.teamId});

  @override
  State<OdemelerEkrani> createState() => _OdemelerEkraniState();
}

class _OdemelerEkraniState extends State<OdemelerEkrani>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _silmeOnayi(BuildContext context, VoidCallback onConfirm) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
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
                        'Silinsin mi?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu kayd\u0131 kal\u0131c\u0131 olarak silmek istedi\u011Finize emin misiniz?',
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
                                '\u0130ptal',
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
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Sil',
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

  void _odemeEkleDialog(BuildContext context, FirestoreServisi servisi) {
    final miktarCtrl = TextEditingController();
    final alanKisiCtrl = TextEditingController();
    String? seciliSantiye;
    DateTime seciliTarih = DateTime.now();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
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
                                    '\u00D6deme Giri\u015Fi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (santiyeler.isEmpty)
                                    const Text(
                                      '\u00D6nce \u015Fantiye ekleyin.',
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
                                            '\u015Eantiye Se\u00E7in',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          dropdownColor: const Color(0xFF2C2C2E),
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
                                    'Miktar',
                                    Icons.attach_money,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBlurInput(
                                    alanKisiCtrl,
                                    'Alan Ki\u015Fi',
                                    Icons.person_outline,
                                    isNumber: false,
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: seciliTarih,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => seciliTarih = picked);
                                      }
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
                                            'Tarih: ${DateFormat('dd.MM.yyyy').format(seciliTarih)}',
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
                                            '\u0130ptal',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              seciliSantiye == null
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
                                            backgroundColor: _kBrandTeal,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Kaydet',
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

  void _avansEkleDialog(BuildContext context, FirestoreServisi servisi) {
    final miktarCtrl = TextEditingController();
    Isci? seciliIsci;
    DateTime seciliTarih = DateTime.now();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
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
                                    'Avans Giri\u015Fi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (isciler.isEmpty)
                                    const Text(
                                      '\u00D6nce i\u015F\u00E7i ekleyin.',
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
                                            '\u0130\u015F\u00E7i Se\u00E7in',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                          dropdownColor: const Color(0xFF2C2C2E),
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
                                    'Miktar',
                                    Icons.attach_money,
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: seciliTarih,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => seciliTarih = picked);
                                      }
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
                                            'Tarih: ${DateFormat('dd.MM.yyyy').format(seciliTarih)}',
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
                                            '\u0130ptal',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              seciliIsci == null
                                                  ? null
                                                  : () async {
                                                    if (miktarCtrl
                                                        .text
                                                        .isNotEmpty) {
                                                      final avans = VerilenAvans(
                                                        miktar:
                                                            double.tryParse(
                                                              miktarCtrl.text,
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
                                            backgroundColor: _kBrandTeal,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Kaydet',
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

  Widget _buildOdemelerListesi(
    BuildContext context,
    FirestoreServisi servisi,
    bool isDark,
  ) {
    return StreamBuilder<List<AlinanOdeme>>(
      stream: servisi.getOdemelerStream(widget.teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerYukleniyor(satirSayisi: 5);
        }

        final odemeler = snapshot.data ?? [];
        if (odemeler.isEmpty) {
          return Center(
            child: Text(
              'Kay\u0131tl\u0131 \u00F6deme yok.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            _shellDockBodyPadding,
          ),
          itemCount: odemeler.length,
          itemBuilder: (context, index) {
            final odeme = odemeler[index];
            return _buildModernListCard(
              context: context,
              isDark: isDark,
              icon: Icons.arrow_downward,
              iconColor: Colors.green,
              title: Formatlayici.yap(odeme.miktar),
              subtitle: '${odeme.santiyeAdi} - ${odeme.alanKisi}',
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
    );
  }

  Widget _buildAvanslarListesi(
    BuildContext context,
    FirestoreServisi servisi,
    bool isDark,
  ) {
    return StreamBuilder<List<VerilenAvans>>(
      stream: servisi.getAvanslarStream(widget.teamId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerYukleniyor(satirSayisi: 5);
        }

        final avanslar = snapshot.data ?? [];
        if (avanslar.isEmpty) {
          return Center(
            child: Text(
              'Kay\u0131tl\u0131 avans yok.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            _shellDockBodyPadding,
          ),
          itemCount: avanslar.length,
          itemBuilder: (context, index) {
            final avans = avanslar[index];
            return _buildModernListCard(
              context: context,
              isDark: isDark,
              icon: Icons.arrow_upward,
              iconColor: Colors.redAccent,
              title: Formatlayici.yap(avans.miktar),
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
    );
  }

  Widget _buildAktifFab(FirestoreServisi servisi) {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        heroTag: 'odeme_fab',
        onPressed: () => _odemeEkleDialog(context, servisi),
        label: const Text('\u00D6deme Ekle'),
        icon: const Icon(Icons.add),
        backgroundColor: _kBrandTeal,
        foregroundColor: Colors.white,
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'avans_fab',
      onPressed: () => _avansEkleDialog(context, servisi),
      label: const Text('Avans Ekle'),
      icon: const Icon(Icons.add),
      backgroundColor: _kBrandTeal,
      foregroundColor: Colors.white,
    );
  }

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _glassCardDecoration(isDark),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildGlassIconBadge(
          isDark: isDark,
          icon: icon,
          color: iconColor,
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

  BoxDecoration _glassCardDecoration(bool isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (isDark ? const Color(0xFF15181D) : const Color(0xFFEDFFFF))
              .withOpacity(isDark ? 0.96 : 0.72),
          (isDark ? const Color(0xFF090B0F) : const Color(0xFFF7FBFD))
              .withOpacity(isDark ? 0.98 : 0.90),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color:
            isDark
                ? Colors.white.withOpacity(0.07)
                : const Color(0xFFD8EAF0).withOpacity(0.90),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
          blurRadius: isDark ? 22 : 18,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: const Color(0xFF79E9D7).withOpacity(isDark ? 0.04 : 0.10),
          blurRadius: isDark ? 18 : 28,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  Widget _buildGlassIconBadge({
    required bool isDark,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.18 : 0.14),
            (isDark ? const Color(0xFF171B20) : Colors.white).withOpacity(
              isDark ? 0.82 : 0.92,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.16 : 0.12)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context, listen: false);
    final servisi = FirestoreServisi(kullaniciId: user?.uid ?? '');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('\u00D6demeler ve Avanslar'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kBrandTeal,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          indicatorColor: _kBrandTeal,
          indicatorWeight: 2.8,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Al\u0131nan'),
            Tab(icon: Icon(Icons.upload), text: 'Verilen'),
          ],
        ),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOdemelerListesi(context, servisi, isDark),
            _buildAvanslarListesi(context, servisi, isDark),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _shellDockFabPadding),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) => _buildAktifFab(servisi),
        ),
      ),
    );
  }
}
