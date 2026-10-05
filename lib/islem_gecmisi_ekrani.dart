import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firestore_servisi.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_empty_state.dart';

const Color _kBrandTeal = Color(0xFF14B8A6);

class IslemGecmisiEkrani extends StatefulWidget {
  final String teamId;

  const IslemGecmisiEkrani({super.key, required this.teamId});

  @override
  State<IslemGecmisiEkrani> createState() => _IslemGecmisiEkraniState();
}

class _IslemGecmisiEkraniState extends State<IslemGecmisiEkrani> {
  bool _taraniyor = false;
  bool _duzeltiyor = false;
  bool _taramaTamamlandi = false;
  List<RaporCakismaGrubu> _cakismalar = [];
  String? _geriAliniyorId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _servis().eskiYedekleriTemizle(widget.teamId);
  }

  FirestoreServisi _servis() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FirestoreServisi(kullaniciId: uid);
  }

  Future<void> _islemGeriAlOnayi(
    String historyDocId,
    String islemTipi,
    Map<String, dynamic> detaylar,
    Map<String, dynamic> fullData,
  ) async {
    String baslik = 'İşlemi Geri Al';
    String aciklama = 'Bu işlemi geri almak istediğinize emin misiniz?';
    String icerikOzeti = '';

    final timestamp = fullData['tarih'] as Timestamp?;
    final int gecenGun =
        timestamp != null ? DateTime.now().difference(timestamp.toDate()).inDays : 0;
    final int kalanGun = (30 - gecenGun).clamp(0, 30);

    if (islemTipi == 'SANTIYE_SILME') {
      final santiyeAdi = detaylar['santiyeAdi'] ?? 'Şantiye';
      baslik = 'Şantiyeyi Geri Yükle';
      aciklama =
          "'$santiyeAdi' şantiyesini ve bu şantiye silindiğinde kaldırılan tüm bağlı verileri geri getirmek üzeresiniz.";
      final int raporSayisi = (detaylar['silinenRaporSayisi'] ?? 0) as int;
      final int odemeSayisi = (detaylar['silinenOdemeSayisi'] ?? 0) as int;
      if (raporSayisi > 0 || odemeSayisi > 0) {
        icerikOzeti =
            '• 1 adet Şantiye\n• $raporSayisi adet Günlük Rapor\n• $odemeSayisi adet Alınan Ödeme';
      }
    } else if (islemTipi == 'ISCI_SILME') {
      final isciAdi = detaylar['isciAdi'] ?? 'İşçi';
      baslik = 'İşçiyi Geri Yükle';
      aciklama =
          "'$isciAdi' işçisini ve bu işçi silindiğinde kaldırılan tüm avans kayıtlarını geri getirmek üzeresiniz.";
      final int avansSayisi = (detaylar['silinenAvansSayisi'] ?? 0) as int;
      if (avansSayisi > 0) {
        icerikOzeti = '• 1 adet İşçi Profili\n• $avansSayisi adet Verilen Avans';
      }
    } else if (islemTipi == 'ODEME_SILME') {
      baslik = 'Ödemeyi Geri Yükle';
      aciklama =
          "${detaylar['miktar'] ?? ''} TL tutarındaki silinen ödeme kaydını geri getirmek istiyor musunuz?";
    } else if (islemTipi == 'AVANS_SILME') {
      baslik = 'Avansı Geri Yükle';
      aciklama =
          "${detaylar['isci'] ?? 'İşçiye ait'} ${detaylar['miktar'] ?? ''} TL tutarındaki silinen avans kaydını geri getirmek istiyor musunuz?";
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final onaylandi = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Kapat",
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2228) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFD8EAF0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kBrandTeal.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings_backup_restore_rounded,
                          color: _kBrandTeal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          baslik,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F243A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    aciklama,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : const Color(0xFF334E68),
                      height: 1.4,
                    ),
                  ),
                  if (icerikOzeti.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kBrandTeal.withValues(alpha: isDark ? 0.12 : 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _kBrandTeal.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Geri yüklenecek veriler:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _kBrandTeal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            icerikOzeti,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: isDark ? Colors.white70 : const Color(0xFF102A43),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Silinen veriler 30 gün boyunca saklanır ($kalanGun gün kaldı).',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            "Vazgeç",
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text(
                            "Geri Yükle",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBrandTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
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

    if (onaylandi != true || !mounted) return;

    setState(() => _geriAliniyorId = historyDocId);

    try {
      final mesaj = await _servis().islemGeriAl(widget.teamId, historyDocId, fullData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(mesaj)),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Geri alma hatası: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _geriAliniyorId = null);
      }
    }
  }

  Future<void> _cakismalariTara() async {
    if (_taraniyor) return;
    setState(() {
      _taraniyor = true;
      _taramaTamamlandi = false;
    });

    try {
      final sonuc = await _servis().cakisanRaporlariBul(widget.teamId);
      if (!mounted) return;
      setState(() {
        _cakismalar = sonuc;
        _taramaTamamlandi = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çakışma taraması sırasında hata: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _taraniyor = false);
      }
    }
  }

  Future<void> _birlestir(RaporCakismaGrubu grup) async {
    if (_duzeltiyor) return;
    setState(() => _duzeltiyor = true);
    try {
      await _servis().cakisanRaporlariBirlastir(widget.teamId, grup);
      if (!mounted) return;
      setState(() {
        _cakismalar.remove(grup);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıtlar birleştirildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Birleştirme hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _duzeltiyor = false);
      }
    }
  }

  Future<void> _fazlalariSil(RaporCakismaGrubu grup) async {
    if (_duzeltiyor) return;
    setState(() => _duzeltiyor = true);
    try {
      await _servis().cakisanRaporlardaFazlalariSil(widget.teamId, grup);
      if (!mounted) return;
      setState(() {
        _cakismalar.remove(grup);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fazlalık kayıtlar silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silme hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _duzeltiyor = false);
      }
    }
  }

  Map<String, dynamic> _getStyleForAction(String? islemTipi) {
    switch (islemTipi) {
      case 'ISCI_EKLEME':
        return {'icon': Icons.person_add, 'color': Colors.blue};
      case 'ISCI_SILME':
      case 'UYE_CIKARMA':
      case 'SANTIYE_SILME':
      case 'ODEME_SILME':
      case 'AVANS_SILME':
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
      case 'SANTIYE_GERI_YUKLEME':
      case 'ISCI_GERI_YUKLEME':
      case 'ODEME_GERI_YUKLEME':
      case 'AVANS_GERI_YUKLEME':
        return {'icon': Icons.settings_backup_restore_rounded, 'color': _kBrandTeal};
      default:
        return {'icon': Icons.history, 'color': Colors.grey};
    }
  }

  Widget _buildLogContent(
    String islemTipi,
    Map<String, dynamic> detaylar,
    String username,
    bool isDark,
  ) {
    final style = TextStyle(
      fontSize: 15,
      color: isDark ? Colors.white : const Color(0xFF102A43),
    );
    final bold = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : const Color(0xFF0F243A),
    );

    final spans = <TextSpan>[
      TextSpan(text: '$username ', style: bold.copyWith(color: _kBrandTeal)),
    ];

    switch (islemTipi) {
      case 'ISCI_EKLEME':
        spans.add(
          TextSpan(
            text:
                "${detaylar['isciAdi'] ?? 'birini'} adlı kişiyi işçi olarak ekledi.",
            style: style,
          ),
        );
        break;
      case 'ISCI_GUNCELLEME':
        spans.add(
          TextSpan(
            text:
                "${detaylar['isciAdi'] ?? 'bir'} işçisinin bilgilerini güncelledi.",
            style: style,
          ),
        );
        break;
      case 'ISCI_SILME':
        final avansSayisi = detaylar['silinenAvansSayisi'];
        String extra = '';
        if (avansSayisi != null && avansSayisi > 0) {
          extra = ' ($avansSayisi avans kaydı dahil)';
        }
        spans.add(
          TextSpan(
            text: "${detaylar['isciAdi'] ?? 'bir'} adlı işçiyi sildi$extra.",
            style: style,
          ),
        );
        break;
      case 'ISCI_GERI_YUKLEME':
        final avansSayisi = detaylar['geriYuklenenAvansSayisi'];
        String extra = '';
        if (avansSayisi != null && avansSayisi > 0) {
          extra = ' (bağlı $avansSayisi avans kaydı dahil)';
        }
        spans.add(
          TextSpan(
            text: "${detaylar['isciAdi'] ?? 'bir'} işçisini ve bağlı kayıtlarını geri yükledi$extra.",
            style: style,
          ),
        );
        break;
      case 'SANTIYE_EKLEME':
        spans.add(
          TextSpan(
            text: "${detaylar['santiyeAdi'] ?? 'yeni'} şantiyesini ekledi.",
            style: style,
          ),
        );
        break;
      case 'SANTIYE_SILME':
        final raporSayisi = detaylar['silinenRaporSayisi'];
        final odemeSayisi = detaylar['silinenOdemeSayisi'];
        String extra = '';
        if (raporSayisi != null && raporSayisi > 0) {
          extra = ' ($raporSayisi rapor${odemeSayisi != null && odemeSayisi > 0 ? ', $odemeSayisi ödeme' : ''} dahil)';
        }
        spans.add(
          TextSpan(
            text: "${detaylar['santiyeAdi'] ?? 'bir'} şantiyesini sildi$extra.",
            style: style,
          ),
        );
        break;
      case 'SANTIYE_GERI_YUKLEME':
        final raporSayisi = detaylar['geriYuklenenRaporSayisi'];
        final odemeSayisi = detaylar['geriYuklenenOdemeSayisi'];
        String extra = '';
        if (raporSayisi != null && raporSayisi > 0) {
          extra = ' (bağlı $raporSayisi rapor${odemeSayisi != null && odemeSayisi > 0 ? ', $odemeSayisi ödeme' : ''} dahil)';
        }
        spans.add(
          TextSpan(
            text: "${detaylar['santiyeAdi'] ?? 'bir'} şantiyesini ve bağlı kayıtlarını geri yükledi$extra.",
            style: style,
          ),
        );
        break;
      case 'GUNLUK_RAPOR_EKLEME':
      case 'GUNLUK_RAPOR_GUNCELLEME':
        String tarihStr = '';
        if (detaylar['tarih'] != null) {
          try {
            final dt = DateTime.parse(detaylar['tarih']);
            tarihStr = ' (${DateFormat('dd MMM', 'tr_TR').format(dt)})';
          } catch (_) {}
        }
        spans.add(
          TextSpan(
            text:
                "${detaylar['santiyeAdi'] ?? 'Bilinmeyen'} şantiyesinin raporunu girdi/güncelledi$tarihStr.",
            style: style,
          ),
        );
        break;
      case 'ODEME_EKLEME':
        spans.add(
          TextSpan(
            text: "${detaylar['miktar']} TL tutarında ödeme girişi yaptı.",
            style: style,
          ),
        );
        break;
      case 'ODEME_SILME':
        spans.add(
          TextSpan(
            text: "${detaylar['miktar'] ?? ''} TL tutarındaki ödeme kaydını sildi.",
            style: style,
          ),
        );
        break;
      case 'ODEME_GERI_YUKLEME':
        spans.add(
          TextSpan(
            text: "silinen ${detaylar['miktar'] ?? ''} TL ödeme kaydını geri yükledi.",
            style: style,
          ),
        );
        break;
      case 'AVANS_EKLEME':
        spans.add(
          TextSpan(
            text:
                "${detaylar['isci'] ?? 'İşçiye'} ${detaylar['miktar']} TL avans verdi.",
            style: style,
          ),
        );
        break;
      case 'AVANS_SILME':
        spans.add(
          TextSpan(
            text:
                "${detaylar['isci'] ?? 'İşçiye ait'} ${detaylar['miktar'] ?? ''} TL avans kaydını sildi.",
            style: style,
          ),
        );
        break;
      case 'AVANS_GERI_YUKLEME':
        spans.add(
          TextSpan(
            text:
                "silinen ${detaylar['miktar'] ?? ''} TL avans kaydını geri yükledi.",
            style: style,
          ),
        );
        break;
      case 'UYE_CIKARMA':
        spans.add(TextSpan(text: 'Bir üyeyi ekipten çıkardı.', style: style));
        break;
      default:
        spans.add(TextSpan(text: 'bir işlem yaptı.', style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildCakismaPanel(bool isDark) {
    final panelBg = isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD);
    final panelBorder =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD8EAF0);

    return Card(
      elevation: 2,
      color: panelBg,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule_folder_outlined, color: _kBrandTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Çakışan Günlük Raporlar',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F243A),
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed:
                      (_taraniyor || _duzeltiyor) ? null : _cakismalariTara,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrandTeal.withValues(alpha: 0.16),
                    foregroundColor: _kBrandTeal,
                  ),
                  child:
                      _taraniyor
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Çakışan Günleri Tara'),
                ),
              ],
            ),
            if (_taramaTamamlandi) ...[
              const SizedBox(height: 8),
              Text(
                _cakismalar.isEmpty
                    ? 'Çakışma bulunmadı.'
                    : '${_cakismalar.length} çakışma bulundu.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334E68),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCakismaCard(RaporCakismaGrubu grup, bool isDark) {
    final tarih = DateFormat('dd MMM yyyy', 'tr_TR').format(grup.gun);
    final colorBg = isDark ? const Color(0xFF0F1720) : const Color(0xFFF8FCFE);
    final borderColor =
        isDark ? Colors.orange.withValues(alpha: 0.25) : const Color(0xFFF3C78A);

    return Card(
      elevation: 0,
      color: colorBg,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$tarih • ${grup.santiyeAdi}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${grup.raporlar.length} kayıt bulundu',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF486581),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _duzeltiyor ? null : () => _birlestir(grup),
                    icon: const Icon(Icons.merge_type_rounded),
                    label: const Text('Birleştir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _duzeltiyor ? null : () => _fazlalariSil(grup),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      foregroundColor: Colors.red.shade400,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Fazlayı Sil'),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final historyRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('history')
        .orderBy('tarih', descending: true)
        .limit(50);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: const FloatingLiquidAppBar(
        title: 'İşlem Geçmişi',
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Column(
          children: [
            SizedBox(
              height: FloatingLiquidAppBar.topPadding(context, extra: 4),
            ),
            _buildCakismaPanel(isDark),
            if (_cakismalar.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _cakismalar.length,
                  itemBuilder:
                      (context, index) =>
                          _buildCakismaCard(_cakismalar[index], isDark),
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: historyRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _kBrandTeal),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const GlassEmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'İşlem Geçmişi Boş',
                      description:
                          'Şantiye, çalışan veya puantaj kayıtları üzerinde gerçekleştirilen tüm işlemler burada kronolojik olarak listelenir.',
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final docId = docs[index].id;
                      final data = docs[index].data() as Map<String, dynamic>;
                      final timestamp = data['tarih'] as Timestamp?;
                      final zaman =
                          timestamp != null
                              ? DateFormat(
                                'dd MMM yyyy, HH:mm',
                                'tr_TR',
                              ).format(timestamp.toDate())
                              : '-';
                      final islemTipi = data['islemTipi'] ?? 'BILINMEYEN';
                      final username = data['kullaniciUsername'] ?? 'Bilinmeyen';
                      final detaylar =
                          (data['detaylar'] ?? {}) as Map<String, dynamic>;
                      final styleInfo = _getStyleForAction(islemTipi);

                      final bool geriAlinabilir = islemTipi == 'SANTIYE_SILME' ||
                          islemTipi == 'ISCI_SILME' ||
                          islemTipi == 'ODEME_SILME' ||
                          islemTipi == 'AVANS_SILME';
                      final bool geriAlindi = data['geriAlindi'] == true;
                      final int gecenGun = timestamp != null
                          ? DateTime.now().difference(timestamp.toDate()).inDays
                          : 0;
                      final bool suresiDoldu = gecenGun >= 30;
                      final int kalanGun = (30 - gecenGun).clamp(0, 30);

                      return Card(
                        elevation: 2,
                        color:
                            isDark
                                ? const Color(0xFF101317)
                                : const Color(0xFFF7FBFD),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFD8EAF0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (styleInfo['color'] as Color)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  styleInfo['icon'] as IconData,
                                  color: styleInfo['color'] as Color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLogContent(
                                      islemTipi,
                                      detaylar,
                                      username as String,
                                      isDark,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          zaman,
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black45,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (geriAlinabilir) ...[
                                          if (geriAlindi)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.green.withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 12,
                                                    color: Colors.green.shade400,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Geri Alındı',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.green.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (suresiDoldu)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey.withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.timer_off_outlined,
                                                    size: 12,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Süresi Doldu (30g)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            OutlinedButton.icon(
                                              onPressed:
                                                  _geriAliniyorId == docId
                                                      ? null
                                                      : () => _islemGeriAlOnayi(
                                                        docId,
                                                        islemTipi,
                                                        detaylar,
                                                        data,
                                                      ),
                                              icon:
                                                  _geriAliniyorId == docId
                                                      ? const SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: _kBrandTeal,
                                                            ),
                                                      )
                                                      : const Icon(
                                                        Icons.undo_rounded,
                                                        size: 14,
                                                      ),
                                              label: Text(
                                                kalanGun <= 1
                                                    ? 'Geri Al (Son 24s)'
                                                    : 'Geri Al (${kalanGun}g)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: _kBrandTeal,
                                                side: BorderSide(
                                                  color: _kBrandTeal.withValues(alpha: 
                                                    0.4,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    _kBrandTeal.withValues(alpha: 
                                                      0.08,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                        ],
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
            ),
          ],
        ),
      ),
    );
  }
}
