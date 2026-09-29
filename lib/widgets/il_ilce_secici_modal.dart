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

/// Türkiye 81 İl ve İlçe seçimi için modern, adımlı ve aramalı alt modal sheet.
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
    return showModalBottomSheet<IlIlceSecimSonucu>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    // Filtrelenmiş liste
    final ilListesi = TurkiyeIlIlce.tumIller.where((il) {
      if (_filtre.isEmpty) return true;
      return _normalize(il).contains(_normalize(_filtre));
    }).toList();

    final ilceListesi = ilSecildi
        ? TurkiyeIlIlce.getIlceler(_secilenIl!).where((ilce) {
            if (_filtre.isEmpty) return true;
            return _normalize(ilce).contains(_normalize(_filtre));
          }).toList()
        : <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14171C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Üst tutamaç
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Başlık ve Adım Çubuğu
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF14B8A6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ilSecildi
                                ? "$_secilenIl İlçesi Seçin"
                                : "Şehir (İl) Seçin",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            ilSecildi
                                ? "Adım 2/2: İlgili ilçeyi belirleyin veya Merkez'i seçin"
                                : "Adım 1/2: Türkiye'nin 81 ilinden birini seçin",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ilSecildi)
                      IconButton(
                        tooltip: "İl Değiştir",
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () {
                          setState(() {
                            _secilenIl = null;
                            _secilenIlce = null;
                            _filtre = '';
                            _aramaController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),

              // Arama Çubuğu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  controller: _aramaController,
                  onChanged: (val) {
                    setState(() {
                      _filtre = val.trim();
                    });
                  },
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: ilSecildi
                        ? "$_secilenIl ilçelerinde ara..."
                        : "81 il içinde ara...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF14B8A6)),
                    suffixIcon: _filtre.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Liste İçeriği
              Expanded(
                child: !ilSecildi
                    // 1. ADIM: İLLER LİSTESİ
                    ? ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: ilListesi.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                        ),
                        itemBuilder: (context, index) {
                          final il = ilListesi[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                il.substring(0, 1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF14B8A6),
                                ),
                              ),
                            ),
                            title: Text(
                              il,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Colors.grey,
                            ),
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
                    // 2. ADIM: SEÇİLEN İLİN İLÇELERİ
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          // Hızlıca "Tüm İl / İl Merkezi" seçeneği
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
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
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city_rounded, color: Color(0xFF14B8A6)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$_secilenIl (Merkez / Genel)",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF14B8A6),
                                          ),
                                        ),
                                        Text(
                                          "Belirli bir ilçe seçmeden tüm şehir olarak kaydet",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF14B8A6)),
                                ],
                              ),
                            ),
                          ),

                          ...ilceListesi.map((ilce) {
                            final seciliMi = _secilenIlce == ilce;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                Icons.pin_drop_outlined,
                                color: seciliMi ? const Color(0xFF14B8A6) : Colors.grey,
                                size: 20,
                              ),
                              title: Text(
                                ilce,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: seciliMi ? FontWeight.bold : FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              trailing: seciliMi
                                  ? const Icon(Icons.check_rounded, color: Color(0xFF14B8A6))
                                  : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
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
        );
      },
    );
  }
}
