// lib/widgets/il_ilce_secici_modal.dart

import 'package:flutter/material.dart';
import '../data/turkiye_il_ilce.dart';

class IlIlceSecimSonucu {
  final String il;
  final String? ilce;
  final double? lat;
  final double? lon;

  const IlIlceSecimSonucu({
    required this.il,
    this.ilce,
    this.lat,
    this.lon,
  });

  String get tamKonum => (ilce != null && ilce!.isNotEmpty) ? '$ilce, $il' : il;
}

/// Türkiye 81 İl ve İlçe seçimi için kompakt, şık ve popüler iller öncelikli pop-up diyaloğu.
class IlIlceSeciciModal extends StatefulWidget {
  final String? baslangicIl;
  final String? baslangicIlce;

  const IlIlceSeciciModal({
    super.key,
    this.baslangicIl,
    this.baslangicIlce,
  });

  static Future<IlIlceSecimSonucu?> goster(
    BuildContext context, {
    String? baslangicIl,
    String? baslangicIlce,
  }) {
    return showDialog<IlIlceSecimSonucu>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IlIlceSeciciModal(
        baslangicIl: baslangicIl,
        baslangicIlce: baslangicIlce,
      ),
    );
  }

  @override
  State<IlIlceSeciciModal> createState() => _IlIlceSeciciModalState();
}

class _IlIlceSeciciModalState extends State<IlIlceSeciciModal> {
  final TextEditingController _aramaController = TextEditingController();
  String? _secilenIl;
  String? _secilenIlce;
  String _filtre = '';

  static const List<String> _buyukIller = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Kocaeli',
    'Bursa',
    'Antalya',
  ];

  @override
  void initState() {
    super.initState();
    _secilenIl = widget.baslangicIl;
    _secilenIlce = widget.baslangicIlce;
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ilSecildi = _secilenIl != null && _secilenIl!.isNotEmpty;
    final size = MediaQuery.of(context).size;

    // Filtrelenmiş iller listesi
    final tumIller = TurkiyeIlIlce.tumIller;
    final filtrelenmisIller = tumIller.where((il) {
      if (_filtre.isEmpty) return true;
      return _normalize(il).contains(_normalize(_filtre));
    }).toList();

    // Filtrelenmiş ilçeler listesi
    final ilceListesi = ilSecildi
        ? TurkiyeIlIlce.getIlceler(_secilenIl!).where((ilce) {
            if (_filtre.isEmpty) return true;
            return _normalize(ilce).contains(_normalize(_filtre));
          }).toList()
        : <String>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: size.height * 0.72,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14181F) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFF14B8A6).withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.16),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ÜST BAŞLIK ALANI
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF14B8A6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ilSecildi
                                  ? "$_secilenIl İlçesi"
                                  : "Konum / İl Seçin",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              ilSecildi ? "İlçeyi belirleyin" : "81 İl arasından seçin",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ilSecildi)
                        IconButton(
                          tooltip: "İl Değiştir",
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _secilenIl = null;
                              _secilenIlce = null;
                              _filtre = '';
                              _aramaController.clear();
                            });
                          },
                        ),
                      IconButton(
                        tooltip: "Kapat",
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 2. ARAMA ÇUBUĞU
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _aramaController,
                    onChanged: (val) {
                      setState(() {
                        _filtre = val.trim();
                      });
                    },
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: ilSecildi
                          ? "$_secilenIl ilçelerinde ara..."
                          : "İl adı yazın...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF14B8A6)),
                      suffixIcon: _filtre.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _aramaController.clear();
                                setState(() {
                                  _filtre = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // 3. İL SEÇİMİNDE: BÜYÜK İLLER HIZLI BUTONLARI (Filtre boşken)
                if (!ilSecildi && _filtre.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              "Büyük Şehirler",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _buyukIller.map((il) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _secilenIl = il;
                                  _secilenIlce = null;
                                  _filtre = '';
                                  _aramaController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  il,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF14B8A6),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 14, indent: 16, endIndent: 16),
                ],

                // 4. LİSTE ALANI
                Flexible(
                  child: !ilSecildi
                      // 81 İL LİSTESİ
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                          shrinkWrap: true,
                          itemCount: filtrelenmisIller.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                          ),
                          itemBuilder: (context, index) {
                            final il = filtrelenmisIller[index];
                            final isTopCity = _buyukIller.contains(il);

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isTopCity
                                      ? const Color(0xFF14B8A6).withValues(alpha: 0.15)
                                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  il.substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isTopCity ? const Color(0xFF14B8A6) : Colors.grey,
                                  ),
                                ),
                              ),
                              title: Text(
                                il,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isTopCity ? FontWeight.bold : FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              trailing: isTopCity
                                  ? const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B))
                                  : const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                              onTap: () {
                                setState(() {
                                  _secilenIl = il;
                                  _secilenIlce = null;
                                  _filtre = '';
                                  _aramaController.clear();
                                });
                              },
                            );
                          },
                        )
                      // İLÇE LİSTESİ
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                          shrinkWrap: true,
                          children: [
                            // "Tüm İl / İl Merkezi" Hızlı Seçeneği
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                final konum = TurkiyeIlIlce.getKonum(il: _secilenIl!);
                                Navigator.pop(
                                  context,
                                  IlIlceSecimSonucu(
                                    il: _secilenIl!,
                                    ilce: null,
                                    lat: konum?.lat,
                                    lon: konum?.lon,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_city_rounded, color: Color(0xFF14B8A6), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$_secilenIl (Merkez / Genel)",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: Color(0xFF14B8A6),
                                            ),
                                          ),
                                          Text(
                                            "İlçe belirtmeden tüm şehir için bağla",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF14B8A6), size: 18),
                                  ],
                                ),
                              ),
                            ),

                            ...ilceListesi.map((ilce) {
                              final seciliMi = _secilenIlce == ilce;
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                leading: Icon(
                                  Icons.pin_drop_outlined,
                                  color: seciliMi ? const Color(0xFF14B8A6) : Colors.grey,
                                  size: 18,
                                ),
                                title: Text(
                                  ilce,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: seciliMi ? FontWeight.bold : FontWeight.w500,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                trailing: seciliMi
                                    ? const Icon(Icons.check_rounded, color: Color(0xFF14B8A6), size: 18)
                                    : const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                onTap: () {
                                  final konum = TurkiyeIlIlce.getKonum(il: _secilenIl!, ilce: ilce);
                                  Navigator.pop(
                                    context,
                                    IlIlceSecimSonucu(
                                      il: _secilenIl!,
                                      ilce: ilce,
                                      lat: konum?.lat,
                                      lon: konum?.lon,
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
