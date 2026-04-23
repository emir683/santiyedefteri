import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KlavuzEkrani extends StatefulWidget {
  final bool isFromMenu;
  const KlavuzEkrani({super.key, this.isFromMenu = false});

  @override
  State<KlavuzEkrani> createState() => _KlavuzEkraniState();
}

class _KlavuzEkraniState extends State<KlavuzEkrani> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = const [
    {
      'title': 'Hoş Geldiniz',
      'desc':
          'Şantiye Defteri ile saha operasyonlarını tek merkezden yönetin.',
      'icon': Icons.waving_hand_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Günlük Rapor',
      'desc':
          'Yoklama, puantaj ve masraf kayıtlarını tek ekranda hızlıca girin.',
      'icon': Icons.edit_calendar_rounded,
      'color': Color(0xFF14B8A6),
    },
    {
      'title': 'Şantiye ve İşçi',
      'desc':
          'Projeleri ve personeli ayrı ayrı yönetin, kayıtları düzenli takip edin.',
      'icon': Icons.groups_2_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Finans ve Özet',
      'desc':
          'Ödeme, avans ve ay sonu özetlerini tek bakışta görün.',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFF8B5CF6),
    },
  ];

  Future<void> _bitir() async {
    if (!widget.isFromMenu) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('klavuzGoruldu', true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = _pages[_currentPage];
    final bgTop = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF4F7FB);
    final bgBottom =
        isDark ? const Color(0xFF101822) : const Color(0xFFEAF1F8);
    final cardColor = isDark ? const Color(0xFF161D27) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF102A43);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF4A5568);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _bitir();
      },
      child: Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isFromMenu
                                ? 'Kullanım Kılavuzu'
                                : 'Başlangıç Turu',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentPage + 1}/${_pages.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _bitir,
                      child: Text(
                        widget.isFromMenu ? 'Kapat' : 'Şimdilik Atla',
                        style: TextStyle(color: bodyColor),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _currentPage = value),
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    final accent = item['color'] as Color;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFD7DFEA),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.24 : 0.06,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(
                                    isDark ? 0.20 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: accent,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                item['title'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 27,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item['desc'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: bodyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? (page['color'] as Color)
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _bitir();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: page['color'] as Color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Tamamla'
                            : 'İleri',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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
