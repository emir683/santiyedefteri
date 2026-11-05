import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'animasyon_yardimcisi.dart';
import 'firestore_servisi.dart';
import 'format_yardimcisi.dart';
import 'isci_ekrani.dart';
import 'models/kullanici_saha_profili.dart';
import 'santiye_ekrani.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';
import 'tema_ayarlari.dart';

class SantiyeVeIsciMerkeziEkrani extends StatefulWidget {
  final String teamId;
  final int baslangicAltSekme; // 0: Şantiyeler, 1: İşçiler (Ekipler dahil)
  final ValueChanged<int>? onAltSekmeDegisti;

  const SantiyeVeIsciMerkeziEkrani({
    super.key,
    required this.teamId,
    this.baslangicAltSekme = 0,
    this.onAltSekmeDegisti,
  });

  @override
  State<SantiyeVeIsciMerkeziEkrani> createState() =>
      _SantiyeVeIsciMerkeziEkraniState();
}

class _SantiyeVeIsciMerkeziEkraniState
    extends State<SantiyeVeIsciMerkeziEkrani> {
  Color get _themePrimary => AppTheme.primary(context);
  Color get _themeAccent => AppTheme.accent(context);
  Color get _themeContrastIcon => AppTheme.contrastIcon(context);

  late int _altSekme;

  @override
  void initState() {
    super.initState();
    _altSekme = widget.baslangicAltSekme.clamp(0, 1);
  }

  @override
  void didUpdateWidget(covariant SantiyeVeIsciMerkeziEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baslangicAltSekme != widget.baslangicAltSekme) {
      setState(() {
        _altSekme = widget.baslangicAltSekme.clamp(0, 1);
      });
    }
  }

  void _altSekmeSec(int index) {
    if (_altSekme == index) return;
    HapticFeedback.selectionClick();
    setState(() => _altSekme = index);
    widget.onAltSekmeDegisti?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingLiquidAppBar(
        title: _altSekme == 0 ? 'Şantiyeler' : 'İşçiler & Ekipler',
        showHamburger: true,
        showPrivacyButton: true,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _altSekme,
                children: [
                  SantiyeEkrani(
                    teamId: widget.teamId,
                    otomatikTurAktif: false,
                  ),
                  IsciEkrani(
                    teamId: widget.teamId,
                    otomatikTurAktif: false,
                  ),
                ],
              ),
            ),
            Positioned(
              top: FloatingLiquidAppBar.topPadding(context, extra: 4),
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: PanelGlassWidgets.buildCard(
                    context: context,
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _buildSegmentChip(
                          context: context,
                          index: 0,
                          label: 'Şantiyeler',
                          icon: Icons.home_work_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildSegmentChip(
                          context: context,
                          index: 1,
                          label: 'İşçiler & Ekipler',
                          icon: Icons.groups_rounded,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentChip({
    required BuildContext context,
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final secili = _altSekme == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _altSekmeSec(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color:
                secili
                    ? _themePrimary.withValues(
                      alpha: isDark ? 0.30 : 0.16,
                    )
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  secili
                      ? _themeContrastIcon
                      : Colors.transparent,
              width: secili ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color:
                    secili
                        ? _themeContrastIcon
                        : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: secili ? FontWeight.w800 : FontWeight.w600,
                    color:
                        secili
                            ? (isDark ? Colors.white : const Color(0xFF102A43))
                            : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şantiye Özel Ekipleri (Hakediş, Metraj, Avans) İçin Yardımcı Kart ve Diyaloglar
class SantiyeEkipYardimcisi {
  static Widget buildOzelEkipKarti({
    required BuildContext context,
    required String teamId,
    required SantiyeOzelEkibi ekip,
    required FirestoreServisi servisi,
    required bool privacyHidden,
    required bool isDark,
  }) {
    final themeContrastIcon = AppTheme.contrastIcon(context);
    final tipBaslik = SantiyePazarIlani.ucretTipiBasligi(ekip.anlasmaTipi);
    final birimMetin =
        ekip.anlasmaTipi == 'metrekare'
            ? '${ekip.birimUcret.toStringAsFixed(0)} ₺/m²'
            : (ekip.anlasmaTipi == 'goturu'
                ? 'Götürü: ${FormatYardimcisi.paraFormatla(ekip.birimUcret)}'
                : '${ekip.birimUcret.toStringAsFixed(0)} ₺/Gün');

    return PanelGlassWidgets.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: Icons.groups_rounded,
                accentColor: themeContrastIcon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0F7C86,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ekip.santiyeAdi,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: themeContrastIcon,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD97706,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$tipBaslik • ${ekip.kisiSayisi} Kişi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ekip.ekipAdi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ekip.ekipBasiAd.isNotEmpty ? ekip.ekipBasiAd : "Ekip"} • ${ekip.brans} • $birimMetin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await servisi.santiyeOzelEkibiSil(teamId, ekip.id);
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // İlerleme Çubuğu ve Tutar Özeti
          PanelGlassWidgets.buildInset(
            context: context,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        ekip.anlasmaTipi == 'metrekare'
                            ? '${ekip.tamamlananMiktar.toStringAsFixed(0)} / ${ekip.toplamAnlasmaMiktari.toStringAsFixed(0)} m²'
                            : (ekip.anlasmaTipi == 'goturu'
                                ? 'Götürü: %${ekip.tamamlananMiktar.toStringAsFixed(0)}'
                                : '${ekip.tamamlananMiktar.toStringAsFixed(1)} Gün'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '%${(ekip.ilerlemeOrani * 100).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: themeContrastIcon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ekip.ilerlemeOrani,
                    minHeight: 6,
                    backgroundColor:
                        isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      themeContrastIcon,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Hakediş: ${privacyHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(ekip.toplamHakedisTutari)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      'Ödenen: ${privacyHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(ekip.odenenTutar)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: themeContrastIcon,
                      ),
                    ),
                    Text(
                      'Kalan: ${privacyHidden ? "•••• ₺" : FormatYardimcisi.paraFormatla(ekip.kalanBakiye)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap:
                      () => ekipPuantajVeyaHakedisGirModal(
                        context: context,
                        teamId: teamId,
                        servisi: servisi,
                        ekip: ekip,
                      ),
                  child: PanelGlassWidgets.buildInset(
                    context: context,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    borderColor: const Color(
                      0xFF0F7C86,
                    ).withValues(alpha: 0.45),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_chart_rounded,
                          size: 15,
                          color: themeContrastIcon,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            ekip.anlasmaTipi == 'gunluk'
                                ? 'Puantaj Gir'
                                : 'Hakediş Gir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap:
                      () => ekipOdemeGirModal(
                        context: context,
                        teamId: teamId,
                        servisi: servisi,
                        ekip: ekip,
                      ),
                  child: PanelGlassWidgets.buildInset(
                    context: context,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 15,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Ödeme Yap',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
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
          if (ekip.hakedisKayitlari.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Kayıtlar (${ekip.hakedisKayitlari.length})',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              children:
                  ekip.hakedisKayitlari.take(4).map((k) {
                    final tip = k['tip']?.toString() ?? 'hakedis';
                    final tutar = ((k['tutar'] ?? 0) as num).toDouble();
                    final miktar = ((k['miktar'] ?? 0) as num).toDouble();
                    final birim = k['birim']?.toString() ?? '';
                    final aciklama = k['aciklama']?.toString() ?? '';
                    DateTime t = DateTime.now();
                    if (k['tarih'] is Timestamp) {
                      t = (k['tarih'] as Timestamp).toDate();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tip == 'odeme'
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.straighten_rounded,
                              size: 14,
                              color:
                                  tip == 'odeme'
                                      ? themeContrastIcon
                                      : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('dd.MM').format(t)} • $aciklama ${miktar > 0 ? "(+$miktar $birim)" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              privacyHidden
                                  ? '•••• ₺'
                                  : FormatYardimcisi.paraFormatla(tutar),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    tip == 'odeme'
                                        ? themeContrastIcon
                                        : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> ekipPuantajVeyaHakedisGirModal({
    required BuildContext context,
    required String teamId,
    required FirestoreServisi servisi,
    required SantiyeOzelEkibi ekip,
  }) async {
    final miktarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: AnimasyonluDialog.gecisYapici,
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              24,
              18,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                color: Colors.transparent,
                child: PanelGlassWidgets.buildCard(
                  context: ctx,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${ekip.ekipAdi} • Hakediş Gir',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ekip.santiyeAdi} • ${SantiyePazarIlani.ucretTipiBasligi(ekip.anlasmaTipi)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: miktarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                ekip.anlasmaTipi == 'metrekare'
                                    ? 'İlerleme (m²)'
                                    : (ekip.anlasmaTipi == 'goturu'
                                        ? 'İlerleme Oranı (%)'
                                        : 'Çalışılan Gün'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: aciklamaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Açıklama (Örn: 2. Kat Sıva)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary(context),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          'Kaydet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () async {
                          final miktar =
                              double.tryParse(
                                miktarCtrl.text.replaceAll(',', '.').trim(),
                              ) ??
                              0;
                          if (miktar <= 0) return;
                          await servisi.santiyeOzelEkibiHakedisVeyaPuantajGir(
                            teamId: teamId,
                            ekip: ekip,
                            eklenecekMiktar: miktar,
                            aciklama:
                                aciklamaCtrl.text.trim().isEmpty
                                    ? 'Hakediş Girişi'
                                    : aciklamaCtrl.text.trim(),
                            tarih: DateTime.now(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> ekipOdemeGirModal({
    required BuildContext context,
    required String teamId,
    required FirestoreServisi servisi,
    required SantiyeOzelEkibi ekip,
  }) async {
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: AnimasyonluDialog.gecisYapici,
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              24,
              18,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                color: Colors.transparent,
                child: PanelGlassWidgets.buildCard(
                  context: ctx,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${ekip.ekipAdi} • Ödeme Yap',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: tutarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Ödenen Tutar (₺)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: aciklamaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Açıklama (Örn: Avans / Hakediş Ödemesi)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary(context),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(Icons.payments_rounded, size: 18),
                        label: Text(
                          'Ödemeyi Kaydet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () async {
                          final tutar =
                              double.tryParse(
                                tutarCtrl.text.replaceAll(',', '.').trim(),
                              ) ??
                              0;
                          if (tutar <= 0) return;
                          await servisi.santiyeOzelEkibiOdemeGir(
                            teamId: teamId,
                            ekip: ekip,
                            odemeTutari: tutar,
                            aciklama: aciklamaCtrl.text.trim(),
                            tarih: DateTime.now(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> yeniSantiyeEkibiDialogAc(
    BuildContext context,
    String teamId,
    FirestoreServisi servisi,
  ) async {
    final ekipAdiCtrl = TextEditingController();
    final ekipBasiCtrl = TextEditingController();
    final telefonCtrl = TextEditingController();
    final kisiSayisiCtrl = TextEditingController(text: '5');
    final birimUcretCtrl = TextEditingController();
    final toplamMiktarCtrl = TextEditingController(text: '1000');

    final santiyeler = await servisi.getSantiyelerStream(teamId).first;
    String seciliSantiye =
        santiyeler.isNotEmpty ? santiyeler.first.ad : 'Merkez Şantiye';
    String seciliBrans = 'Duvar, Sıva & Alçı Ekibi';
    String seciliAnlasmaTipi = 'metrekare';

    final branslar = KullaniciRolu.bransSecenekleri(
      KullaniciRolu.taseronKalfa,
    );

    if (!context.mounted) return;

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
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  24,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Material(
                    color: Colors.transparent,
                    child: PanelGlassWidgets.buildCard(
                      context: context,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Yeni Şantiye Ekibi Ekle',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (santiyeler.isNotEmpty)
                            PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: DropdownButtonFormField<String>(
                                initialValue: seciliSantiye,
                                decoration: InputDecoration(
                                  labelText: 'Şantiye',
                                  border: InputBorder.none,
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
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => seciliSantiye = v);
                                  }
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          PanelGlassWidgets.buildInset(
                            context: context,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: TextField(
                              controller: ekipAdiCtrl,
                              decoration: InputDecoration(
                                labelText: 'Ekip Adı (Örn: Sıvacı Ekibi)',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          PanelGlassWidgets.buildInset(
                            context: context,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: seciliBrans,
                              decoration: InputDecoration(
                                labelText: 'Branş',
                                border: InputBorder.none,
                              ),
                              items:
                                  branslar
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b,
                                          child: Text(b),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(() => seciliBrans = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: PanelGlassWidgets.buildInset(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: TextField(
                                    controller: ekipBasiCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Ekip Başı',
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
                                    controller: kisiSayisiCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Kişi',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          PanelGlassWidgets.buildInset(
                            context: context,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: seciliAnlasmaTipi,
                              decoration: InputDecoration(
                                labelText: 'Hakediş Türü',
                                border: InputBorder.none,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'metrekare',
                                  child: Text('Metrekare (₺ / m²)'),
                                ),
                                DropdownMenuItem(
                                  value: 'goturu',
                                  child: Text('Götürü (Toplam ₺)'),
                                ),
                                DropdownMenuItem(
                                  value: 'gunluk',
                                  child: Text('Günlük (₺ / Gün)'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setModalState(() => seciliAnlasmaTipi = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                    controller: birimUcretCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText:
                                          seciliAnlasmaTipi == 'metrekare'
                                              ? 'Birim (₺/m²)'
                                              : (seciliAnlasmaTipi == 'goturu'
                                                  ? 'Götürü (₺)'
                                                  : 'Günlük (₺)'),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              if (seciliAnlasmaTipi != 'goturu') ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PanelGlassWidgets.buildInset(
                                    context: context,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: TextField(
                                      controller: toplamMiktarCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText:
                                            seciliAnlasmaTipi == 'metrekare'
                                                ? 'Metraj (m²)'
                                                : 'Süre (Gün)',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary(context),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(Icons.group_add_rounded, size: 18),
                            label: Text(
                              'Ekibi Ekle',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            onPressed: () async {
                              final ad =
                                  ekipAdiCtrl.text.trim().isEmpty
                                      ? seciliBrans
                                      : ekipAdiCtrl.text.trim();
                              final ucret =
                                  double.tryParse(
                                    birimUcretCtrl.text
                                        .replaceAll(',', '.')
                                        .trim(),
                                  ) ??
                                  0;
                              final miktar =
                                  seciliAnlasmaTipi == 'goturu'
                                      ? 100.0
                                      : (double.tryParse(
                                            toplamMiktarCtrl.text
                                                .replaceAll(',', '.')
                                                .trim(),
                                          ) ??
                                          100.0);
                              final kisi =
                                  int.tryParse(kisiSayisiCtrl.text.trim()) ?? 1;

                              final yeniEkip = SantiyeOzelEkibi(
                                id: '',
                                ekipAdi: ad,
                                brans: seciliBrans,
                                ekipBasiAd: ekipBasiCtrl.text.trim(),
                                ekipBasiTelefon: telefonCtrl.text.trim(),
                                santiyeAdi: seciliSantiye,
                                kisiSayisi: kisi,
                                anlasmaTipi: seciliAnlasmaTipi,
                                birimUcret: ucret,
                                toplamAnlasmaMiktari: miktar,
                                olusturulmaTarihi: DateTime.now(),
                              );

                              await servisi.santiyeOzelEkibiEkle(
                                teamId,
                                yeniEkip,
                                iscilereDeEkle: true,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

