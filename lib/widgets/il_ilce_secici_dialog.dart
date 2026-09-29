import 'package:flutter/material.dart';
import '../data/turkiye_il_ilce.dart';

class IlIlceSeciciDialog extends StatefulWidget {
  final String? baslangicIl;
  final String? baslangicIlce;

  const IlIlceSeciciDialog({
    super.key,
    this.baslangicIl,
    this.baslangicIlce,
  });

  /// Kolay çağrım için statik yardımcı fonksiyon.
  static Future<Map<String, dynamic>?> goster(
    BuildContext context, {
    String? baslangicIl,
    String? baslangicIlce,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IlIlceSeciciDialog(
        baslangicIl: baslangicIl,
        baslangicIlce: baslangicIlce,
      ),
    );
  }

  @override
  State<IlIlceSeciciDialog> createState() => _IlIlceSeciciDialogState();
}

class _IlIlceSeciciDialogState extends State<IlIlceSeciciDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Map<String, dynamic>? _seciliIlData;
  String _searchQuery = '';

  static String _normalize(String s) {
    return s
        .trim()
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  @override
  void initState() {
    super.initState();
    // Eğer başlangıçta bir il verilmişse doğrudan o ilin ilçelerine açılabilir
    if (widget.baslangicIl != null && widget.baslangicIl!.trim().isNotEmpty) {
      final normBaslangic = _normalize(widget.baslangicIl!);
      for (final item in TurkiyeIlIlce.iller) {
        if (_normalize(item['il'] as String) == normBaslangic) {
          _seciliIlData = item;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = _normalize(val);
    });
  }

  void _iliSec(Map<String, dynamic> ilData) {
    _focusNode.unfocus();
    setState(() {
      _seciliIlData = ilData;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _illereDon() {
    _focusNode.unfocus();
    setState(() {
      _seciliIlData = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _secimiTamamla({
    required String il,
    required String? ilce,
    required double lat,
    required double lon,
  }) {
    _focusNode.unfocus();
    final displayName = ilce != null ? '$ilce, $il' : il;
    Navigator.pop(context, {
      'il': il,
      'ilce': ilce,
      'name': displayName,
      'lat': lat,
      'lon': lon,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final dialogHeight = (mediaQuery.size.height * 0.72).clamp(420.0, 620.0);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131A22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: dialogHeight,
        ),
        child: Column(
          children: [
            // 1. ÜST BAŞLIK ALANI
            _buildHeader(isDark),

            // 2. ARAMA KUTUSU
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _seciliIlData == null
                      ? '81 İl İçinde Ara (örn. Ankara)...'
                      : '${_seciliIlData!['il']} İlçelerinde Ara...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // 3. LİSTE ALANI (İller veya İlçeler)
            Expanded(
              child: _seciliIlData == null
                  ? _buildIllerListesi(isDark)
                  : _buildIlcelerListesi(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final bool ilSecili = _seciliIlData != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: Row(
        children: [
          if (ilSecili) ...[
            InkWell(
              onTap: _illereDon,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 20,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ilSecili
                      ? '${_seciliIlData!['il']} İlçeleri'
                      : 'Türkiye İlleri',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ilSecili
                      ? 'Bir ilçe seçin veya il merkezini belirleyin'
                      : 'Toplam 81 il • İlçeleri görmek için bir ile tıklayın',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _buildIllerListesi(bool isDark) {
    final tumIller = TurkiyeIlIlce.iller;
    final filtrelenmisIller = tumIller.where((item) {
      if (_searchQuery.isEmpty) return true;
      final ilAdi = _normalize(item['il'] as String);
      final plaka = (item['plaka'] as num).toString();
      return ilAdi.contains(_searchQuery) || plaka.startsWith(_searchQuery);
    }).toList();

    if (filtrelenmisIller.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 10),
              const Text(
                'Aradığınız il bulunamadı.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: filtrelenmisIller.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 64,
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      ),
      itemBuilder: (context, index) {
        final item = filtrelenmisIller[index];
        final ilAdi = item['il'] as String;
        final plaka = item['plaka'] as int;
        final ilceler = (item['ilceler'] as List<dynamic>?) ?? [];

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              plaka.toString().padLeft(2, '0'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          title: Text(
            ilAdi,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${ilceler.length} İlçe',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          onTap: () => _iliSec(item),
        );
      },
    );
  }

  Widget _buildIlcelerListesi(bool isDark) {
    final ilAdi = _seciliIlData!['il'] as String;
    final lat = (_seciliIlData!['lat'] as num).toDouble();
    final lon = (_seciliIlData!['lon'] as num).toDouble();
    final ilceler = ((_seciliIlData!['ilceler'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();

    final filtrelenmisIlceler = ilceler.where((ilce) {
      if (_searchQuery.isEmpty) return true;
      return _normalize(ilce).contains(_searchQuery);
    }).toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        // 1. İL MERKEZİ / TÜM İL SEÇENEĞİ (En üstte sabit kolay erişim)
        if (_searchQuery.isEmpty || _normalize(ilAdi).contains(_searchQuery) || _normalize('merkez').contains(_searchQuery))
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.domain_rounded,
                  size: 20,
                  color: Color(0xFF0F766E),
                ),
              ),
              title: Text(
                '$ilAdi (Tüm İl / İl Merkezi)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                ),
              ),
              subtitle: const Text(
                'Belirli bir ilçe seçmeden il geneli için kaydet',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: Color(0xFF0F766E),
              ),
              onTap: () => _secimiTamamla(
                il: ilAdi,
                ilce: null,
                lat: lat,
                lon: lon,
              ),
            ),
          ),

        if (filtrelenmisIlceler.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'İlçeler (${filtrelenmisIlceler.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...filtrelenmisIlceler.map((ilce) {
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.place_outlined,
                  size: 17,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              title: Text(
                ilce,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                ilAdi,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFCBD5E1),
              ),
              onTap: () => _secimiTamamla(
                il: ilAdi,
                ilce: ilce,
                lat: lat,
                lon: lon,
              ),
            );
          }),
        ] else if (_searchQuery.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Center(
              child: Text(
                'Aranan kriterde "$ilAdi" ilçesi bulunamadı.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
