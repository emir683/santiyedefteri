// lib/saha_operasyon_merkezi_ekrani.dart

import 'dart:ui';
import 'tema_ayarlari.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'animasyon_yardimcisi.dart';
import 'data/saha_katalog_verileri.dart';
import 'dwg_goruntuleyici_ekrani.dart';
import 'models/kullanici_saha_profili.dart';
import 'services/saha_pdf_servisi.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';

class SahaOperasyonMerkeziEkrani extends StatefulWidget {
  final String teamId;
  final int baslangicSekmesi; // 0: Malzeme/İrsaliye, 1: Ekipman/Zimmet, 2: İSG/Evrak, 3: Metraj/Keşif
  final bool gomuluMod;

  const SahaOperasyonMerkeziEkrani({
    super.key,
    required this.teamId,
    this.baslangicSekmesi = 0,
    this.gomuluMod = false,
  });

  @override
  State<SahaOperasyonMerkeziEkrani> createState() =>
      _SahaOperasyonMerkeziEkraniState();
}

class _SahaOperasyonMerkeziEkraniState
    extends State<SahaOperasyonMerkeziEkrani> {
  Color get _themePrimary => AppTheme.primary(context);
  Color get _themeAccent => AppTheme.accent(context);
  Color get _themeContrastIcon => AppTheme.contrastIcon(context);
  List<Color> get _themeGradient => AppTheme.gradient(context);

  late int _seciliSekme;

  // Hızlı Metraj & Keşif Hesaplayıcı alanları
  final _enCtrl = TextEditingController(text: '10');
  final _boyCtrl = TextEditingController(text: '15');
  final _kalinlikCtrl = TextEditingController(text: '0.20');

  final _demirCapCtrl = TextEditingController(text: '14');
  final _demirBoyCtrl = TextEditingController(text: '12');
  final _demirAdetCtrl = TextEditingController(text: '50');

  final _duvarBoyCtrl = TextEditingController(text: '20');
  final _duvarYukseklikCtrl = TextEditingController(text: '2.80');
  final _duvarBoslukCtrl = TextEditingController(text: '4.5');
  String _seciliTuglaTipi = '13.5\'luk Tuğla';

  final _kalipEnCtrl = TextEditingController(text: '10');
  final _kalipBoyCtrl = TextEditingController(text: '15');
  final _kalipYukseklikCtrl = TextEditingController(text: '3.0');
  String _kalipTuru = 'Döşeme Kalıbı';

  final _hafriyatEnCtrl = TextEditingController(text: '15');
  final _hafriyatBoyCtrl = TextEditingController(text: '20');
  final _hafriyatDerinlikCtrl = TextEditingController(text: '3.5');

  final _sapAlanCtrl = TextEditingController(text: '120');
  final _sapKalinlikCtrl = TextEditingController(text: '5.0');

  final _boyaAlanCtrl = TextEditingController(text: '250');
  final _seramikAlanCtrl = TextEditingController(text: '85');
  final _yalitimAlanCtrl = TextEditingController(text: '200');
  final _alcipanAlanCtrl = TextEditingController(text: '100');

  String _seciliMetrajFiltresi = 'Tümü';

  @override
  void initState() {
    super.initState();
    _seciliSekme = widget.baslangicSekmesi.clamp(0, 3);
  }

  @override
  void didUpdateWidget(covariant SahaOperasyonMerkeziEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baslangicSekmesi != widget.baslangicSekmesi) {
      setState(() {
        _seciliSekme = widget.baslangicSekmesi.clamp(0, 3);
      });
    }
  }

  @override
  void dispose() {
    _enCtrl.dispose();
    _boyCtrl.dispose();
    _kalinlikCtrl.dispose();
    _demirCapCtrl.dispose();
    _demirBoyCtrl.dispose();
    _demirAdetCtrl.dispose();
    _duvarBoyCtrl.dispose();
    _duvarYukseklikCtrl.dispose();
    _duvarBoslukCtrl.dispose();
    _kalipEnCtrl.dispose();
    _kalipBoyCtrl.dispose();
    _kalipYukseklikCtrl.dispose();
    _hafriyatEnCtrl.dispose();
    _hafriyatBoyCtrl.dispose();
    _hafriyatDerinlikCtrl.dispose();
    _sapAlanCtrl.dispose();
    _sapKalinlikCtrl.dispose();
    _boyaAlanCtrl.dispose();
    _seramikAlanCtrl.dispose();
    _yalitimAlanCtrl.dispose();
    _alcipanAlanCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _sahaRef => FirebaseFirestore
      .instance
      .collection('teams')
      .doc(widget.teamId)
      .collection('saha_operasyon');

  CollectionReference<Map<String, dynamic>> get _santiyelerRef =>
      FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('santiyeler');

  CollectionReference<Map<String, dynamic>> get _workersRef =>
      FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('workers');

  // ──────────────────────────────────────────────────────────────────────────
  // 1. KATALOG SEÇİM MODALI (İŞ MAKİNESİ, İSG/KKD, MALZEME)
  // ──────────────────────────────────────────────────────────────────────────
  Future<SahaKatalogItem?> _katalogSeciciModal(
    BuildContext context,
    String tip,
  ) async {
    List<SahaKatalogItem> kaynakListe;
    String sayfaBaslik;

    if (tip == 'zimmet') {
      kaynakListe = SahaKatalogVerileri.isMakineleriVeEkipmanlar;
      sayfaBaslik = 'İş Makinesi & Ekipman Katalogu';
    } else if (tip == 'isg') {
      kaynakListe = SahaKatalogVerileri.isgVeKkdKatalogu;
      sayfaBaslik = 'İSG & KKD Standart Katalogu (6331 Uyumlu)';
    } else {
      kaynakListe = SahaKatalogVerileri.malzemeKatalogu;
      sayfaBaslik = 'İnşaat Malzemeleri Katalogu';
    }

    final kategoriler = ['Tümü', ...kaynakListe.map((e) => e.kategori).toSet()];

    return await showModalBottomSheet<SahaKatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String arama = '';
        String seciliKategori = 'Tümü';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final filtrelenmis = kaynakListe.where((item) {
              final matchKategori =
                  seciliKategori == 'Tümü' || item.kategori == seciliKategori;
              final matchArama = arama.isEmpty ||
                  item.ad.toLowerCase().contains(arama.toLowerCase()) ||
                  (item.standartKodu ?? '')
                      .toLowerCase()
                      .contains(arama.toLowerCase()) ||
                  (item.aciklama ?? '')
                      .toLowerCase()
                      .contains(arama.toLowerCase());
              return matchKategori && matchArama;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PanelGlassWidgets.buildIconBadge(
                        context: context,
                        icon: tip == 'zimmet'
                            ? Icons.precision_manufacturing_rounded
                            : (tip == 'isg'
                                ? Icons.health_and_safety_rounded
                                : Icons.inventory_2_rounded),
                        accentColor: _themeContrastIcon,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sayfaBaslik,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Arama Çubuğu
                  PanelGlassWidgets.buildInset(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: TextField(
                      onChanged: (v) => setSheetState(() => arama = v),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, size: 20),
                        hintText: 'Katalogda ara (örn: Baret, Ekskavatör, Beton, C30...)',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Kategori Filtre Hapları
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: kategoriler.map((kat) {
                        final selected = seciliKategori == kat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(kat),
                            selected: selected,
                            onSelected: (_) => setSheetState(() => seciliKategori = kat),
                            selectedColor: _themePrimary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF102A43)),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Liste
                  Expanded(
                    child: filtrelenmis.isEmpty
                        ? Center(
                            child: Text(
                              'Aramanıza uygun kayıt bulunamadı.\nAşağıdan manuel olarak yazabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtrelenmis.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filtrelenmis[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(ctx, item),
                                child: PanelGlassWidgets.buildCard(
                                  context: context,
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.ad,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF102A43),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 3,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                if (item.standartKodu != null)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _themeContrastIcon
                                                          .withValues(alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      item.standartKodu!,
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: _themeContrastIcon,
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  'Birim: ${item.varsayilanBirim}',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (item.aciklama != null) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                item.aciklama!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: _themeContrastIcon,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. MEVCUT ŞANTİYELER SEÇİCİ MODALI
  // ──────────────────────────────────────────────────────────────────────────
  Future<String?> _santiyeSeciciModal(BuildContext context) async {
    final snapshot = await _santiyelerRef.get();
    final santiyeler = snapshot.docs.map((d) {
      final data = d.data();
      return (data['ad'] ?? '').toString();
    }).where((ad) => ad.isNotEmpty).toList();

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String manuelSantiye = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PanelGlassWidgets.buildIconBadge(
                        context: context,
                        icon: Icons.apartment_rounded,
                        accentColor: _themeContrastIcon,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mevcut Şantiyeyi Seçin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (santiyeler.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz kayıtlı şantiye bulunamadı. Aşağıdan şantiye adını yazabilirsiniz.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: santiyeler.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final ad = santiyeler[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, ad),
                            child: PanelGlassWidgets.buildCard(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    size: 20,
                                    color: _themeContrastIcon,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ad,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Veya Listede Olmayan Yeni Şantiye / Kat Yazın:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: PanelGlassWidgets.buildInset(
                          context: context,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            onChanged: (v) => setSheetState(() => manuelSantiye = v),
                            decoration: InputDecoration(
                              hintText: 'Şantiye adı yazın...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: manuelSantiye.trim().isEmpty
                            ? null
                            : () => Navigator.pop(ctx, manuelSantiye.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Seç'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. MEVCUT USTA / ÇALIŞAN SEÇİCİ MODALI
  // ──────────────────────────────────────────────────────────────────────────
  Future<Map<String, String?>?> _ustaSeciciModal(BuildContext context) async {
    final snapshot = await _workersRef.get();
    final ustalar = snapshot.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'ad': (data['ad'] ?? '').toString(),
        'meslek': (data['meslek'] ?? data['isciTuru'] ?? 'Usta').toString(),
        'tc': data['tcNo'] as String?,
      };
    }).where((u) => u['ad']!.isNotEmpty).toList();

    return await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String arama = '';
        String manuelUsta = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final filtrelenmis = ustalar.where((u) {
              return arama.isEmpty ||
                  u['ad']!.toLowerCase().contains(arama.toLowerCase()) ||
                  u['meslek']!.toLowerCase().contains(arama.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PanelGlassWidgets.buildIconBadge(
                        context: context,
                        icon: Icons.engineering_rounded,
                        accentColor: _themeContrastIcon,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ekipteki Ustayı / Personeli Seçin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PanelGlassWidgets.buildInset(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: TextField(
                      onChanged: (v) => setSheetState(() => arama = v),
                      decoration: InputDecoration(
                        icon: Icon(Icons.search_rounded, size: 20),
                        hintText: 'Usta veya meslek ara...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrelenmis.isEmpty
                        ? Center(
                            child: Text(
                              'Ekipte usta kaydı bulunamadı.\nAşağıdan manuel isim yazabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtrelenmis.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final u = filtrelenmis[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(ctx, u),
                                child: PanelGlassWidgets.buildCard(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _themePrimary
                                            .withValues(alpha: 0.15),
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: _themeContrastIcon,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u['ad']!,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF102A43),
                                              ),
                                            ),
                                            Text(
                                              u['meslek']!,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: _themeContrastIcon,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veya Listede Olmayan İsim Yazın:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: PanelGlassWidgets.buildInset(
                          context: context,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: TextField(
                            onChanged: (v) => setSheetState(() => manuelUsta = v),
                            decoration: InputDecoration(
                              hintText: 'Ad Soyad / Unvan...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: manuelUsta.trim().isEmpty
                            ? null
                            : () => Navigator.pop(ctx, {
                                  'ad': manuelUsta.trim(),
                                  'meslek': 'Çalışan / Usta',
                                  'tc': null,
                                }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Seç'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. YENİ SAHA KAYDI EKLEME MODALI (TAM ENTEGRE SEÇİCİLER & STANDARTLAR)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _yeniSahaKaydiEkleModal(BuildContext context) async {
    final String tip =
        _seciliSekme == 0 ? 'malzeme' : (_seciliSekme == 1 ? 'zimmet' : 'isg');

    final baslikCtrl = TextEditingController();
    final miktarCtrl = TextEditingController();
    final seriNoCtrl = TextEditingController();
    final calismaSaatiCtrl = TextEditingController();
    final blokKatCtrl = TextEditingController();
    final notCtrl = TextEditingController();

    String? secilenStandart;
    String? secilenSantiye;
    String? secilenUstaAdi;
    String? secilenUstaMeslek;
    String? secilenUstaTc;
    bool acilDurum = false;

    // Varsayılan mevcut şantiyeyi yüklemeye çalış
    try {
      final sSnap = await _santiyelerRef.limit(1).get();
      if (sSnap.docs.isNotEmpty) {
        secilenSantiye = (sSnap.docs.first.data()['ad'] ?? '').toString();
      }
    } catch (_) {}

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: AnimasyonluDialog.gecisYapici,
      pageBuilder: (ctx, a1, a2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.transparent),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        color: Colors.transparent,
                        child: PanelGlassWidgets.buildCard(
                          context: context,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Başlık Çubuğu
                              Row(
                                children: [
                                  PanelGlassWidgets.buildIconBadge(
                                    context: context,
                                    icon: tip == 'malzeme'
                                        ? Icons.inventory_2_outlined
                                        : (tip == 'zimmet'
                                            ? Icons.precision_manufacturing_rounded
                                            : Icons.health_and_safety_outlined),
                                    accentColor: _themeContrastIcon,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tip == 'malzeme'
                                          ? 'Malzeme / İrsaliye Kaydı'
                                          : (tip == 'zimmet'
                                              ? 'İş Makinesi & Ekipman Zimmeti'
                                              : 'İSG & KKD Zimmet Tutanağı'),
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: Icon(Icons.close_rounded),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 1. TANIM & KATALOGDAN SEÇİM
                              Row(
                                children: [
                                  Expanded(
                                    child: PanelGlassWidgets.buildInset(
                                      context: context,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      child: TextField(
                                        controller: baslikCtrl,
                                        decoration: InputDecoration(
                                          labelText: tip == 'malzeme'
                                              ? 'Malzeme Cinsi'
                                              : (tip == 'zimmet'
                                                  ? 'İş Makinesi / Ekipman'
                                                  : 'KKD Donanımı / Denetim'),
                                          hintText: tip == 'malzeme'
                                              ? 'Örn: C30 Beton, Ø14 Demir'
                                              : (tip == 'zimmet'
                                                  ? 'Örn: JCB Bekoloder, Hilti'
                                                  : 'Örn: Çene Bantlı Baret (EN 397)'),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.list_alt_rounded, size: 18),
                                    label: Text('Katalog'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _themePrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final secilen = await _katalogSeciciModal(
                                        context,
                                        tip,
                                      );
                                      if (secilen != null) {
                                        setModalState(() {
                                          baslikCtrl.text = secilen.ad;
                                          secilenStandart = secilen.standartKodu;
                                          if (tip == 'malzeme' && miktarCtrl.text.isEmpty) {
                                            miktarCtrl.text = secilen.varsayilanBirim;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              if (secilenStandart != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 15,
                                      color: _themeContrastIcon,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Mevzuat Standardı: $secilenStandart',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _themeContrastIcon,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),

                              // 2. MEVCUT ŞANTİYE SEÇİCİ
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () async {
                                        final secilen =
                                            await _santiyeSeciciModal(context);
                                        if (secilen != null) {
                                          setModalState(
                                            () => secilenSantiye = secilen,
                                          );
                                        }
                                      },
                                      child: PanelGlassWidgets.buildInset(
                                        context: context,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.apartment_rounded,
                                              size: 18,
                                              color: _themeContrastIcon,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Şantiye Sahası',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    secilenSantiye ?? 'Şantiye Seçiniz',
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: secilenSantiye != null
                                                          ? (isDark
                                                              ? Colors.white
                                                              : const Color(0xFF102A43))
                                                          : Colors.orangeAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: _themeContrastIcon,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: PanelGlassWidgets.buildInset(
                                      context: context,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      child: TextField(
                                        controller: blokKatCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Blok / Kat (Opsiyonel)',
                                          hintText: 'Örn: A Blok 3. Kat',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 3. USTA / PERSONEL SEÇİMİ VEYA MİKTAR
                              if (tip == 'zimmet' || tip == 'isg') ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    final secilen =
                                        await _ustaSeciciModal(context);
                                    if (secilen != null) {
                                      setModalState(() {
                                        secilenUstaAdi = secilen['ad'];
                                        secilenUstaMeslek = secilen['meslek'];
                                        secilenUstaTc = secilen['tc'];
                                      });
                                    }
                                  },
                                  child: PanelGlassWidgets.buildInset(
                                    context: context,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.engineering_rounded,
                                          size: 20,
                                          color: _themeContrastIcon,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tip == 'zimmet'
                                                    ? 'Zimmet Alan Usta / Operatör'
                                                    : 'KKD Teslim Edilen Çalışan',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                secilenUstaAdi != null
                                                    ? '$secilenUstaAdi (${secilenUstaMeslek ?? "Usta"})'
                                                    : 'Usta / Personel Seçiniz (Dokunun)',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: secilenUstaAdi != null
                                                      ? (isDark
                                                          ? Colors.white
                                                          : const Color(0xFF102A43))
                                                      : Colors.orangeAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: _themeContrastIcon,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              if (tip == 'zimmet') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: PanelGlassWidgets.buildInset(
                                        context: context,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        child: TextField(
                                          controller: seriNoCtrl,
                                          decoration: InputDecoration(
                                            labelText: 'Plaka / Seri No',
                                            hintText: 'Örn: 34 SNT 99',
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: PanelGlassWidgets.buildInset(
                                        context: context,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        child: TextField(
                                          controller: calismaSaatiCtrl,
                                          decoration: InputDecoration(
                                            labelText: 'Başlangıç Çalışma Saati',
                                            hintText: 'Örn: 1.250 Saat',
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ] else if (tip == 'malzeme') ...[
                                PanelGlassWidgets.buildInset(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: TextField(
                                    controller: miktarCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Miktar ve Birim',
                                      hintText: 'Örn: 48 m³ (3 Mikser) veya 15 Ton',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // 4. İRSALİYE NO / AÇIKLAMA NOTU
                              PanelGlassWidgets.buildInset(
                                context: context,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                              child: TextField(
                                controller: notCtrl,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: tip == 'malzeme'
                                      ? 'İrsaliye No / Tedarikçi / Açıklama'
                                      : 'Durum / Tutanak Notu',
                                  hintText: tip == 'malzeme'
                                      ? 'Örn: İrsaliye No: 2026-981 / Çimsa'
                                      : 'Ekipman sağlam teslim edildi / periyodik kontrolü tamam.',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 5. ACİL DURUM SWITCH
                            PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  tip == 'malzeme'
                                      ? 'Acil Malzeme Talebi (Eksik Stok)'
                                      : (tip == 'zimmet'
                                          ? 'Bakım / Arıza Uyarısı Var'
                                          : 'Kritik İSG Eksikliği Var'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                value: acilDurum,
                                activeThumbColor: Colors.white,
                                activeTrackColor: _themePrimary,
                                onChanged: (v) =>
                                    setModalState(() => acilDurum = v),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 6. KAYDET BUTONU
                            ElevatedButton.icon(
                              icon: Icon(Icons.check_rounded),
                              label: Text(
                                'Resmi Saha Kaydını Oluştur',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _themePrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final baslik = baslikCtrl.text.trim();
                                if (baslik.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lütfen bir başlık veya malzeme/ekipman seçin.'),
                                    ),
                                  );
                                  return;
                                }

                                final santiyeAna = secilenSantiye ?? 'Merkez Şantiye';
                                final blokKat = blokKatCtrl.text.trim();
                                final tamSantiye = blokKat.isNotEmpty
                                    ? '$santiyeAna ($blokKat)'
                                    : santiyeAna;

                                final miktarVeyaKisi = tip == 'malzeme'
                                    ? miktarCtrl.text.trim()
                                    : (secilenUstaAdi ?? 'Sorumlu Belirtilmedi');

                                await _sahaRef.add({
                                  'tip': tip,
                                  'baslik': baslik,
                                  'miktarVeyaKisi': miktarVeyaKisi,
                                  'santiye': tamSantiye,
                                  'not': notCtrl.text.trim(),
                                  'standart': secilenStandart,
                                  'seriNo': seriNoCtrl.text.trim(),
                                  'calismaSaati': calismaSaatiCtrl.text.trim(),
                                  'tcKimlikNo': secilenUstaTc,
                                  'ustaMeslek': secilenUstaMeslek,
                                  'acil': acilDurum,
                                  'tarih': FieldValue.serverTimestamp(),
                                });

                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingLiquidAppBar(
        title: 'Saha Operasyon Merkezi',
        showHamburger: widget.gomuluMod,
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  FloatingLiquidAppBar.topPadding(context, extra: 8),
                  16,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. ÜST 4'LÜ SEKME KARTI
                    PanelGlassWidgets.buildCard(
                      context: context,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTabItem(
                                  context: context,
                                  index: 0,
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Malzeme & İrsaliye',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabItem(
                                  context: context,
                                  index: 1,
                                  icon: Icons.precision_manufacturing_outlined,
                                  label: 'Makine & Zimmet',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTabItem(
                                  context: context,
                                  index: 2,
                                  icon: Icons.health_and_safety_outlined,
                                  label: 'İSG & Evrak',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabItem(
                                  context: context,
                                  index: 3,
                                  icon: Icons.calculate_outlined,
                                  label: 'Metraj & CAD',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_seciliSekme == 3)
                      _buildMetrajVeCadBolumu(context, isDark)
                    else
                      _buildCanliSahaKayitlariBolumu(context, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _seciliSekme == index;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _seciliSekme = index),
      child: PanelGlassWidgets.buildInset(
        context: context,
        borderColor: selected
            ? _themePrimary.withValues(alpha: 0.85)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? _themeContrastIcon
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? _themeContrastIcon
                      : (isDark ? Colors.white70 : const Color(0xFF102A43)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanliSahaKayitlariBolumu(BuildContext context, bool isDark) {
    final String aktifTip =
        _seciliSekme == 0 ? 'malzeme' : (_seciliSekme == 1 ? 'zimmet' : 'isg');

    final String baslik = _seciliSekme == 0
        ? 'Malzeme Girişi, İrsaliye & Talep Takibi'
        : (_seciliSekme == 1
            ? 'İş Makinesi Saatleri & Ekipman Zimmeti'
            : 'İSG Saha Denetimi & KKD Zimmet Takibi');

    final String altAciklama = _seciliSekme == 0
        ? 'Sahaya gelen beton, demir, çimento irsaliyelerini veya eksik malzeme taleplerini kaydedin.'
        : (_seciliSekme == 1
            ? 'Hangi kırıcı, matkap, iskele hangi ustada zimmetli veya kepçe kaç saat çalıştı takip edin.'
            : '6331 İSG Kanunu ve KKD Yönetmeliği uyumlu resmi teslim tutanakları ve saha denetimleri.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelGlassWidgets.buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PanelGlassWidgets.buildIconBadge(
                    context: context,
                    icon: _seciliSekme == 0
                        ? Icons.local_shipping_outlined
                        : (_seciliSekme == 1
                            ? Icons.handyman_outlined
                            : Icons.verified_user_outlined),
                    accentColor: _themeContrastIcon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baslik,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          altAciklama,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Toplu İcmal PDF Butonu
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _sahaRef
                          .orderBy('tarih', descending: true)
                          .limit(80)
                          .snapshots(),
                      builder: (context, snap) {
                        final allDocs = (snap.data?.docs ?? const [])
                            .where((d) => (d.data()['tip'] ?? 'malzeme') == aktifTip)
                            .toList();

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: allDocs.isEmpty
                              ? null
                              : () async {
                                  final kayitlar =
                                      allDocs.map((doc) => doc.data()).toList();
                                  await SahaPdfServisi.topluRaporOlustur(
                                    kayitlar: kayitlar,
                                    tip: aktifTip,
                                    teamId: widget.teamId,
                                  );
                                },
                          child: PanelGlassWidgets.buildInset(
                            context: context,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 16,
                                  color: allDocs.isEmpty
                                      ? Colors.grey
                                      : _themeContrastIcon,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'İcmal PDF',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: allDocs.isEmpty
                                          ? Colors.grey
                                          : _themeContrastIcon,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Yeni Kayıt Ekle Butonu
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _yeniSahaKaydiEkleModal(context),
                      child: PanelGlassWidgets.buildInset(
                        context: context,
                        borderColor:
                            _themePrimary.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: _themeContrastIcon,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Yeni Kayıt Ekle',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _themeContrastIcon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sahaRef
              .orderBy('tarih', descending: true)
              .limit(80)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = (snapshot.data?.docs ?? const [])
                .where((d) => (d.data()['tip'] ?? 'malzeme') == aktifTip)
                .toList();

            if (docs.isEmpty) {
              return PanelGlassWidgets.buildCard(
                context: context,
                child: Column(
                  children: [
                    PanelGlassWidgets.buildIconBadge(
                      context: context,
                      icon: Icons.post_add_rounded,
                      accentColor: _themeContrastIcon,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz kayıt eklenmedi',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sağ üstteki "Yeni Kayıt Ekle" butonuna dokunarak hazır katalogdan veya serbestçe ilk saha kaydınızı oluşturun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final ts = d['tarih'] as Timestamp?;
                final tarihStr = ts != null
                    ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate())
                    : 'Yeni';
                final bool acil = d['acil'] == true;
                final standart = d['standart'] as String?;
                final seriNo = d['seriNo'] as String?;
                final calismaSaati = d['calismaSaati'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PanelGlassWidgets.buildCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PanelGlassWidgets.buildIconBadge(
                              context: context,
                              icon: acil
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                              accentColor: acil
                                  ? const Color(0xFFD97706)
                                  : _themeContrastIcon,
                              compact: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (d['baslik'] ?? '').toString(),
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF102A43),
                                          ),
                                        ),
                                      ),
                                      if (standart != null) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _themeContrastIcon
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              standart,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: _themeContrastIcon,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if ((d['miktarVeyaKisi'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          aktifTip == 'malzeme'
                                              ? Icons.scale_rounded
                                              : Icons.person_rounded,
                                          size: 14,
                                          color: _themeContrastIcon,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            aktifTip == 'malzeme'
                                                ? 'Miktar: ${d['miktarVeyaKisi']}'
                                                : 'Sorumlu / Usta: ${d['miktarVeyaKisi']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _themeContrastIcon,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if ((d['santiye'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.apartment_rounded,
                                          size: 13,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Şantiye: ${d['santiye']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (seriNo != null && seriNo.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Plaka / Seri No: $seriNo ${calismaSaati != null && calismaSaati.isNotEmpty ? "• Sayaç: $calismaSaati" : ""}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                  if ((d['not'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      d['not'].toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    tarihStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Alt Eylem Butonları: Resmi İmzalı PDF Çıktısı & Silme
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'Resmi İmzalı Tutanak (PDF)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _themePrimary
                                      .withValues(alpha: 0.12),
                                  foregroundColor: _themeContrastIcon,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () async {
                                  await SahaPdfServisi.kayitIcinResmiTutanakOlustur(
                                    kayit: d,
                                    teamId: widget.teamId,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                final onay = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Kaydı Sil'),
                                    content: Text(
                                      'Bu saha kaydını silmek istediğinize emin misiniz?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text('Vazgeç'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(
                                          'Sil',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (onay == true) {
                                  await doc.reference.delete();
                                }
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _sonucKopyala(BuildContext context, String baslik, String ozet) {
    Clipboard.setData(ClipboardData(text: '[$baslik]\n$ozet\n(Şantiye Puantaj Defteri)'));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('$baslik metraj sonucu panoya kopyalandı.')),
          ],
        ),
        backgroundColor: _themePrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMetrajVeCadBolumu(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CAD Kısayol Kartı
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              SayfaGecisi(sayfa: const DwgGoruntuleyiciEkrani()),
            );
          },
          child: PanelGlassWidgets.buildCard(
            context: context,
            child: Row(
              children: [
                PanelGlassWidgets.buildIconBadge(
                  context: context,
                  icon: Icons.architecture_rounded,
                  accentColor: _themeContrastIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DWG / DXF Görüntüleyici',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CAD paftalarını, katmanları ve aksları açın',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Metraj Kategori Filtre Hapları
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              'Tümü',
              'Beton & Demir',
              'Duvar & Kalıp',
              'Kazı & Hafriyat',
              'İnce İşler',
              'Yalıtım',
            ].map((kategori) {
              final secili = _seciliMetrajFiltresi == kategori;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(kategori),
                  selected: secili,
                  onSelected: (_) => setState(() => _seciliMetrajFiltresi = kategori),
                  selectedColor: _themePrimary,
                  labelStyle: TextStyle(
                    color: secili
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF102A43)),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // 1. BETON & MİKSER HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Beton & Demir') ...[
          _buildBetonHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 2. İNŞAAT DEMİRİ & TONAJ HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Beton & Demir') ...[
          _buildDemirHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 3. DUVAR & TUĞLA & HARÇ HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Duvar & Kalıp') ...[
          _buildDuvarTuglaHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 4. KALIP & PLYWOOD & KERESTE HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Duvar & Kalıp') ...[
          _buildKalipPlywoodHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 5. HAFRİYAT & KAZI & KAMYON SEFERİ
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Kazı & Hafriyat') ...[
          _buildHafriyatKamyonHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 6. SIVA & ŞAP & HARÇ HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'İnce İşler') ...[
          _buildSivaSapHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 7. BOYA & ASTAR HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'İnce İşler') ...[
          _buildBoyaAstarHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 8. FAYANS & SERAMİK & YAPIŞTIRICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'İnce İşler') ...[
          _buildSeramikFayansHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 9. SU YALITIMI & MEMBRAN HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'Yalıtım') ...[
          _buildSuYalitimiHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],

        // 10. ALÇIPAN ASMA TAVAN & DUVAR HESAPLAYICI
        if (_seciliMetrajFiltresi == 'Tümü' || _seciliMetrajFiltresi == 'İnce İşler') ...[
          _buildAlcipanHesaplayici(context, isDark),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  // 1. BETON HESAPLAYICI
  Widget _buildBetonHesaplayici(BuildContext context, bool isDark) {
    final en = double.tryParse(_enCtrl.text.replaceAll(',', '.')) ?? 0;
    final boy = double.tryParse(_boyCtrl.text.replaceAll(',', '.')) ?? 0;
    final kalinlik = double.tryParse(_kalinlikCtrl.text.replaceAll(',', '.')) ?? 0;
    final netHacim = en * boy * kalinlik;
    final fireliHacim = netHacim * 1.05;
    final mikserSayisi = (fireliHacim / 10.0).ceil();

    final ozet = 'Net Hacim: ${netHacim.toStringAsFixed(2)} m³ | +%5 Fireli: ${fireliHacim.toStringAsFixed(2)} m³ (~$mikserSayisi Mikser)';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.layers_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hazır Beton & Mikser Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Beton & Mikser', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _enCtrl, 'En (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _boyCtrl, 'Boy (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _kalinlikCtrl, 'Kalınlık (m)')),
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Net: ${netHacim.toStringAsFixed(2)} m³ (+%5: ${fireliHacim.toStringAsFixed(2)} m³)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  '~$mikserSayisi transmikser (10m³)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. DEMİR HESAPLAYICI
  Widget _buildDemirHesaplayici(BuildContext context, bool isDark) {
    final cap = double.tryParse(_demirCapCtrl.text.replaceAll(',', '.')) ?? 0;
    final demirBoy = double.tryParse(_demirBoyCtrl.text.replaceAll(',', '.')) ?? 0;
    final adet = double.tryParse(_demirAdetCtrl.text.replaceAll(',', '.')) ?? 0;
    final birimAgirlik = (cap * cap) / 162.0;
    final toplamDemirKg = birimAgirlik * demirBoy * adet;
    final bagTeli = toplamDemirKg * 0.015;

    final ozet = 'Ø$cap mm Donatı | Toplam: ${toplamDemirKg.toStringAsFixed(1)} kg (${(toplamDemirKg / 1000).toStringAsFixed(3)} Ton) | Bağ Teli: ~${bagTeli.toStringAsFixed(1)} kg';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.straighten_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İnşaat Demiri & Tonaj Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'İnşaat Demiri', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _demirCapCtrl, 'Çap Ø (mm)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _demirBoyCtrl, 'Boy (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _demirAdetCtrl, 'Adet')),
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Toplam: ${toplamDemirKg.toStringAsFixed(1)} kg (${(toplamDemirKg / 1000).toStringAsFixed(3)} Ton)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Birim: ${birimAgirlik.toStringAsFixed(3)} kg/m • Tel: ~${bagTeli.toStringAsFixed(1)}kg',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. DUVAR & TUĞLA HESAPLAYICI
  Widget _buildDuvarTuglaHesaplayici(BuildContext context, bool isDark) {
    final boy = double.tryParse(_duvarBoyCtrl.text.replaceAll(',', '.')) ?? 0;
    final yukseklik = double.tryParse(_duvarYukseklikCtrl.text.replaceAll(',', '.')) ?? 0;
    final bosluk = double.tryParse(_duvarBoslukCtrl.text.replaceAll(',', '.')) ?? 0;
    final brutAlan = boy * yukseklik;
    final netAlan = (brutAlan - bosluk).clamp(0.0, 999999.0);

    double katsayi = 28.0; // 13.5'luk tuğla
    int paletKapasite = 400;
    if (_seciliTuglaTipi.contains('19')) {
      katsayi = 25.0;
      paletKapasite = 300;
    } else if (_seciliTuglaTipi.contains('Gazbeton') || _seciliTuglaTipi.contains('Ytong')) {
      katsayi = 6.7;
      paletKapasite = 60;
    } else if (_seciliTuglaTipi.contains('Bims')) {
      katsayi = 12.5;
      paletKapasite = 90;
    }

    final toplamAdet = (netAlan * katsayi * 1.07).ceil(); // +%7 fire
    final paletSayisi = (toplamAdet / paletKapasite).ceil();
    final cimentoTorba = (netAlan * 0.18).ceil(); // ~0.18 torba/m² harç çimentosu

    final ozet = 'Net Alan: ${netAlan.toStringAsFixed(1)} m² | Toplam $_seciliTuglaTipi: $toplamAdet Adet (~$paletSayisi Palet) | Çimento: ~$cimentoTorba Torba';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.grid_view_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Duvar, Tuğla & Harç Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Duvar & Tuğla', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tuğla Tipi Seçimi
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                '13.5\'luk Tuğla',
                '19\'luk Tuğla',
                'Ytong / Gazbeton',
                'Bims Blok',
              ].map((t) {
                final sec = _seciliTuglaTipi == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(t, style: TextStyle(fontSize: 11, fontWeight: sec ? FontWeight.w700 : FontWeight.normal)),
                    selected: sec,
                    onSelected: (_) => setState(() => _seciliTuglaTipi = t),
                    selectedColor: _themePrimary.withValues(alpha: 0.25),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _duvarBoyCtrl, 'Duvar Boyu (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _duvarYukseklikCtrl, 'Yükseklik (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _duvarBoslukCtrl, 'Boşluk (m²)')),
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Gereken: $toplamAdet Adet (~$paletSayisi Palet)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Net: ${netAlan.toStringAsFixed(1)} m² • Harç: ~$cimentoTorba Torba Çimento',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. KALIP & PLYWOOD & KERESTE HESAPLAYICI
  Widget _buildKalipPlywoodHesaplayici(BuildContext context, bool isDark) {
    final en = double.tryParse(_kalipEnCtrl.text.replaceAll(',', '.')) ?? 0;
    final boy = double.tryParse(_kalipBoyCtrl.text.replaceAll(',', '.')) ?? 0;
    final h = double.tryParse(_kalipYukseklikCtrl.text.replaceAll(',', '.')) ?? 0;

    double kalipAlani;
    if (_kalipTuru == 'Döşeme Kalıbı') {
      kalipAlani = en * boy;
    } else {
      // Çift yüzlü perde/kolon kalıbı
      kalipAlani = 2 * (en + boy) * h;
    }

    final plakaSayisi = ((kalipAlani * 1.08) / 3.125).ceil(); // 250x125cm = 3.125 m² plaka
    final keresteM3 = kalipAlani * 0.025; // 5x10 ızgara
    final dikmeSayisi = (kalipAlani * 1.1).ceil(); // 1 m²'ye 1.1 teleskopik dikme

    final ozet = 'Kalıp Alanı: ${kalipAlani.toStringAsFixed(1)} m² | Plywood Plaka (250x125): $plakaSayisi Adet | 5x10 Kereste: ${keresteM3.toStringAsFixed(2)} m³ | Dikme: ~$dikmeSayisi Adet';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.view_in_ar_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kalıp, Plywood & Kereste Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Kalıp & Plywood', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: Text('Döşeme Kalıbı', style: TextStyle(fontSize: 11)),
                selected: _kalipTuru == 'Döşeme Kalıbı',
                onSelected: (_) => setState(() => _kalipTuru = 'Döşeme Kalıbı'),
                selectedColor: _themePrimary.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Perde / Kolon Kalıbı', style: TextStyle(fontSize: 11)),
                selected: _kalipTuru == 'Perde / Kolon Kalıbı',
                onSelected: (_) => setState(() => _kalipTuru = 'Perde / Kolon Kalıbı'),
                selectedColor: _themePrimary.withValues(alpha: 0.25),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _kalipEnCtrl, 'En (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _kalipBoyCtrl, 'Boy (m)')),
              if (_kalipTuru != 'Döşeme Kalıbı') ...[
                const SizedBox(width: 6),
                Expanded(child: _buildCalcField(context, _kalipYukseklikCtrl, 'Yükseklik (m)')),
              ],
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Kalıp: ${kalipAlani.toStringAsFixed(1)} m² • Plywood: $plakaSayisi Plaka',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  '5x10: ${keresteM3.toStringAsFixed(2)} m³ • ~$dikmeSayisi Dikme',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. HAFRİYAT & KAZI & KAMYON HESAPLAYICI
  Widget _buildHafriyatKamyonHesaplayici(BuildContext context, bool isDark) {
    final en = double.tryParse(_hafriyatEnCtrl.text.replaceAll(',', '.')) ?? 0;
    final boy = double.tryParse(_hafriyatBoyCtrl.text.replaceAll(',', '.')) ?? 0;
    final h = double.tryParse(_hafriyatDerinlikCtrl.text.replaceAll(',', '.')) ?? 0;
    final netHacim = en * boy * h;
    final kabarmisHacim = netHacim * 1.25; // %25 kabarma
    final seferSayisi = (kabarmisHacim / 15.0).ceil(); // 15 m³ kamyon
    final tonaj = netHacim * 1.7; // 1.7 ton/m³ zemin

    final ozet = 'Net Kazı: ${netHacim.toStringAsFixed(1)} m³ | Kabarmış: ${kabarmisHacim.toStringAsFixed(1)} m³ (~$seferSayisi Kamyon Seferi - 15m³) | Ağırlık: ~${tonaj.toStringAsFixed(0)} Ton';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.terrain_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hafriyat, Kazı & Kamyon Sefer Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Hafriyat & Kazı', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _hafriyatEnCtrl, 'Kazı Eni (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _hafriyatBoyCtrl, 'Kazı Boyu (m)')),
              const SizedBox(width: 6),
              Expanded(child: _buildCalcField(context, _hafriyatDerinlikCtrl, 'Derinlik (m)')),
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Kabarmış Hacim: ${kabarmisHacim.toStringAsFixed(1)} m³ (~$seferSayisi Sefer)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Net: ${netHacim.toStringAsFixed(1)} m³ • Tonaj: ~${tonaj.toStringAsFixed(0)} Ton',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. SIVA & ŞAP HESAPLAYICI
  Widget _buildSivaSapHesaplayici(BuildContext context, bool isDark) {
    final alan = double.tryParse(_sapAlanCtrl.text.replaceAll(',', '.')) ?? 0;
    final cm = double.tryParse(_sapKalinlikCtrl.text.replaceAll(',', '.')) ?? 0;
    final harcHacim = alan * (cm / 100.0);
    final cimentoTorba = ((harcHacim * 350) / 50.0).ceil(); // 350 doz şap
    final kumTon = harcHacim * 1.4;

    final ozet = 'Alan: ${alan.toStringAsFixed(1)} m² ($cm cm) | Harç Hacmi: ${harcHacim.toStringAsFixed(2)} m³ | Çimento: ~$cimentoTorba Torba (50kg) | 0-3 Şap Kumu: ~${kumTon.toStringAsFixed(1)} Ton';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.water_drop_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sıva, Şap & Şantiye Harcı Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Şap & Sıva', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCalcField(context, _sapAlanCtrl, 'Uygulama Alanı (m²)')),
              const SizedBox(width: 8),
              Expanded(child: _buildCalcField(context, _sapKalinlikCtrl, 'Kalınlık (cm)')),
            ],
          ),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Harç: ${harcHacim.toStringAsFixed(2)} m³ • Çimento: ~$cimentoTorba Torba',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Şap Kumu: ~${kumTon.toStringAsFixed(1)} Ton (350 Doz)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 7. BOYA & ASTAR HESAPLAYICI
  Widget _buildBoyaAstarHesaplayici(BuildContext context, bool isDark) {
    final alan = double.tryParse(_boyaAlanCtrl.text.replaceAll(',', '.')) ?? 0;
    final boyaKg = alan * 0.28; // 2 kat son kat boya
    final tenekeBoya = (boyaKg / 20.0).ceil(); // 20 kg büyük teneke
    final astarKg = alan * 0.10;
    final tenekeAstar = (astarKg / 15.0).ceil();

    final ozet = 'Boya Alanı: ${alan.toStringAsFixed(1)} m² | Son Kat Boya (2 Kat): ~${boyaKg.toStringAsFixed(1)} kg (~$tenekeBoya Teneke 20kg) | Astar: ~${astarKg.toStringAsFixed(1)} kg (~$tenekeAstar Teneke 15kg)';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.format_paint_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Boya & Astar Hesabı (2 Kat)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Boya & Astar', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCalcField(context, _boyaAlanCtrl, 'Toplam Boya Alanı (Duvar + Tavan m²)'),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Boya: ~$tenekeBoya Teneke (20kg) [${boyaKg.toStringAsFixed(1)} kg]',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Astar: ~$tenekeAstar Teneke (15kg) [2 Kat]',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 8. SERAMİK & FAYANS HESAPLAYICI
  Widget _buildSeramikFayansHesaplayici(BuildContext context, bool isDark) {
    final alan = double.tryParse(_seramikAlanCtrl.text.replaceAll(',', '.')) ?? 0;
    final fireliAlan = alan * 1.08; // +%8 fire
    final kutuSayisi = (fireliAlan / 1.44).ceil(); // 1 kutu = 1.44 m²
    final yapistiriciTorba = ((alan * 5.0) / 25.0).ceil(); // 5kg/m² -> 25kg torba
    final derzKg = (alan * 0.35).ceil();

    final ozet = 'Net Alan: ${alan.toStringAsFixed(1)} m² (+%8 Fireli: ${fireliAlan.toStringAsFixed(1)} m²) | Seramik: $kutuSayisi Kutu (1.44m²) | Yapıştırıcı: $yapistiriciTorba Torba (25kg) | Derz: ~$derzKg kg';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.crop_square_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fayans, Seramik & Yapıştırıcı Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Fayans & Seramik', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCalcField(context, _seramikAlanCtrl, 'Kaplama Alanı (m²)'),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Gereken: $kutuSayisi Kutu (${fireliAlan.toStringAsFixed(1)} m²)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Yapıştırıcı: $yapistiriciTorba Torba • Derz: ~$derzKg kg',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 9. SU YALITIMI & MEMBRAN HESAPLAYICI
  Widget _buildSuYalitimiHesaplayici(BuildContext context, bool isDark) {
    final alan = double.tryParse(_yalitimAlanCtrl.text.replaceAll(',', '.')) ?? 0;
    final biniAlan = alan * 1.10; // %10 bini bindirme payı
    final ruloSayisi = (biniAlan / 10.0).ceil(); // 1 rulo = 10 m²
    final astarTeneke = ((alan * 0.40) / 17.0).ceil(); // 17 kg bitüm astar

    final ozet = 'Alan: ${alan.toStringAsFixed(1)} m² | 4mm Membran: $ruloSayisi Rulo (10m²) | Bitüm Astar Emülsiyon: $astarTeneke Teneke (17kg)';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.shield_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Su Yalıtımı & Bitümlü Membran Hesabı',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Su Yalıtımı', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCalcField(context, _yalitimAlanCtrl, 'Yalıtım Yapılacak Alan (m²)'),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Gereken: $ruloSayisi Rulo (10 m²)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'Astar: $astarTeneke Teneke (17kg) [%10 Bini Paylı]',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 10. ALÇIPAN ASMA TAVAN & DUVAR HESAPLAYICI
  Widget _buildAlcipanHesaplayici(BuildContext context, bool isDark) {
    final alan = double.tryParse(_alcipanAlanCtrl.text.replaceAll(',', '.')) ?? 0;
    final plakaSayisi = ((alan * 1.07) / 3.0).ceil(); // 1.20x2.50 = 3.0 m² plaka
    final tcProfilMetre = (alan * 1.8).ceil();
    final tuProfilMetre = (alan * 0.8).ceil();
    final derzTorba = ((alan * 0.4) / 30.0).ceil();

    final ozet = 'Alan: ${alan.toStringAsFixed(1)} m² | Alçıpan Plaka: $plakaSayisi Adet (1.20x2.50m) | C Profil: $tcProfilMetre m • U Profil: $tuProfilMetre m | Derz Dolgu: $derzTorba Torba';

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.border_all_rounded,
                accentColor: _themeContrastIcon,
                compact: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alçıpan Asma Tavan & Bölme Duvar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 17, color: _themeContrastIcon),
                onPressed: () => _sonucKopyala(context, 'Alçıpan & Profil', ozet),
                tooltip: 'Sonucu Kopyala',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCalcField(context, _alcipanAlanCtrl, 'Asma Tavan / Duvar Alanı (m²)'),
          const SizedBox(height: 10),
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Alçıpan: $plakaSayisi Plaka (3.0 m²)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                Text(
                  'C: ${tcProfilMetre}m • U: ${tuProfilMetre}m • Derz: $derzTorba Torba',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _themeContrastIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcField(
    BuildContext context,
    TextEditingController ctrl,
    String label,
  ) {
    return PanelGlassWidgets.buildInset(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          isDense: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
