import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KlavuzEkrani extends StatefulWidget {
  final bool isFromMenu; // Menüden mi açıldı yoksa ilk açılış mı?
  const KlavuzEkrani({super.key, this.isFromMenu = false});

  @override
  State<KlavuzEkrani> createState() => _KlavuzEkraniState();
}

class _KlavuzEkraniState extends State<KlavuzEkrani> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Hoş Geldiniz!",
      "desc": "Şantiye Defteri ile tüm saha operasyonlarını tek yerden, kolayca yönetin.",
      "icon": Icons.waving_hand,
      "color": Colors.orange
    },
    {
      "title": "Günlük Raporlar",
      "desc": "Hızlı yoklama ile işçileri seçin, masrafları girin ve günü kapatın.",
      "icon": Icons.edit_calendar,
      "color": Colors.green
    },
    {
      "title": "Hesap Takibi",
      "desc": "İşçi alacaklarını, avansları ve şantiye kâr/zarar durumunu anlık görün.",
      "icon": Icons.account_balance_wallet,
      "color": Colors.blue
    },
    {
      "title": "PDF Paylaşım",
      "desc": "Ay sonu raporlarını tek tıkla PDF yapın veya WhatsApp'tan özet geçin.",
      "icon": Icons.picture_as_pdf,
      "color": Colors.redAccent
    },
  ];

  Future<void> _bitir() async {
    if (!widget.isFromMenu) {
      // Eğer ilk açılışsa, hafızaya "görüldü" olarak kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('klavuzGoruldu', true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // SKIP BUTONU
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _bitir,
                child: Text(widget.isFromMenu ? "Kapat" : "Atla", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            // SLIDER ALANI
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page['icon'], size: 100, color: page['color']),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // NOKTALAR VE BUTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sayfa Noktaları
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? Colors.green : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // İleri / Bitir Butonu
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _bitir();
                      } else {
                        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? "BAŞLA" : "İLERİ"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}