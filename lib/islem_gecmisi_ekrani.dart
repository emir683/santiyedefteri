import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'firestore_servisi.dart';
import 'widgets/glass_surface.dart';

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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  FirestoreServisi _servis() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FirestoreServisi(kullaniciId: uid);
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
        spans.add(TextSpan(text: 'Bir işçiyi sildi.', style: style));
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
        spans.add(
          TextSpan(
            text: "${detaylar['santiyeAdi'] ?? 'bir'} şantiyesini sildi.",
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
      case 'AVANS_EKLEME':
        spans.add(
          TextSpan(
            text:
                "${detaylar['isci'] ?? 'İşçiye'} ${detaylar['miktar']} TL avans verdi.",
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
        isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFD8EAF0);

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
                    backgroundColor: _kBrandTeal.withOpacity(0.16),
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
        isDark ? Colors.orange.withOpacity(0.25) : const Color(0xFFF3C78A);

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
                      backgroundColor: Colors.red.withOpacity(0.12),
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
      backgroundColor:
          isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isDark
                ? const Color(0xFF101317).withOpacity(0.92)
                : Colors.white.withOpacity(0.88),
        surfaceTintColor: Colors.transparent,
        title: const Text('İşlem Geçmişi'),
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Column(
          children: [
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 80,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz işlem geçmişi yok.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
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
                                    ? Colors.white.withOpacity(0.08)
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
                                      .withOpacity(0.15),
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
                                      islemTipi as String,
                                      detaylar,
                                      username as String,
                                      isDark,
                                    ),
                                    const SizedBox(height: 8),
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
