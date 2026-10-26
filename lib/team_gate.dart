import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firestore_servisi.dart';
import 'user_model.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

enum _KullanimTipi { ekipli, kisisel }

class TeamGate extends StatefulWidget {
  const TeamGate({super.key});

  @override
  State<TeamGate> createState() => _TeamGateState();
}

class _TeamGateState extends State<TeamGate> {
  final _ekipAdiController = TextEditingController();
  final _sifreController = TextEditingController();

  bool _isJoining = true;
  bool _loading = false;
  String _error = '';
  _KullanimTipi? _kullanimTipi;

  @override
  void dispose() {
    _ekipAdiController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _submitTeamAction() async {
    final uid = Provider.of<UserModel?>(context, listen: false)?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_ekipAdiController.text.isEmpty || _sifreController.text.isEmpty) {
      setState(() => _error = "Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final firestoreServisi = FirestoreServisi(kullaniciId: uid);
    String? teamId;
    String? errorMessage;

    try {
      if (_isJoining) {
        teamId = await firestoreServisi.ekibeKatil(
          _ekipAdiController.text.trim(),
          _sifreController.text.trim(),
        );
      } else {
        teamId = await firestoreServisi.yeniEkipOlustur(
          _ekipAdiController.text.trim(),
          _sifreController.text.trim(),
        );
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (teamId != null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isJoining
                  ? "Tebrikler! Ekibe başarıyla katıldınız."
                  : "Ekip başarıyla oluşturuldu.",
            ),
            backgroundColor: const Color(0xFF14B8A6),
          ),
        );
        // Kök AuthGate -> Wrapper zaten users/{uid} dokümanını canlı dinlediği için
        // sadece varsa üstteki route'ları kapatıp kök ekrana dönüyoruz.
        Navigator.of(context, rootNavigator: true).popUntil(
          (route) => route.isFirst,
        );
      }
      return;
    }

    setState(() {
      _error = errorMessage ?? "İşlem başarısız. Bilgileri kontrol edin.";
      _loading = false;
    });
  }

  Future<void> _kisiselDevamEt() async {
    final uid = Provider.of<UserModel?>(context, listen: false)?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() {
      _loading = true;
      _error = '';
    });

    final firestoreServisi = FirestoreServisi(kullaniciId: uid);
    String? teamId;
    String? errorMessage;

    try {
      teamId = await firestoreServisi.kisiselEkipOlustur();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (teamId != null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bireysel çalışma alanı hazırlandı."),
            backgroundColor: Color(0xFF14B8A6),
          ),
        );
        Navigator.of(context, rootNavigator: true).popUntil(
          (route) => route.isFirst,
        );
      }
      return;
    }

    setState(() {
      _error = errorMessage ?? "Bir hata oluştu.";
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF0F7C86);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingLiquidAppBar(
        title: "Nasıl kullanacaksın?",
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              FloatingLiquidAppBar.topPadding(context, extra: 4),
              20,
              32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Bu uygulama sadece puantaj yazmak için değil. Hesap karışmasın, ekip aynı kaydı tek yerden tutsun diye var.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _secimKarti(
                    context: context,
                    secili: _kullanimTipi == _KullanimTipi.ekipli,
                    icon: Icons.groups_rounded,
                    title: "Ekiple çalışıyorum",
                    subtitle:
                        "Yanında işçi varsa, puantajı bazen birden fazla kişi tutuyorsa veya ay sonu hesaplar karışıyorsa bu kısım sana göre.",
                    bullets: const [
                      "Aynı ekibin kaydını birlikte yönetin",
                      "Şantiyeye göre puantaj ve masraf tutun",
                      "Ay sonu hesabını tek yerden çıkarın",
                    ],
                    onTap: () {
                      setState(() {
                        _kullanimTipi = _KullanimTipi.ekipli;
                        _error = '';
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _secimKarti(
                    context: context,
                    secili: _kullanimTipi == _KullanimTipi.kisisel,
                    icon: Icons.person_rounded,
                    title: "Kendi hesabımı tutacağım",
                    subtitle:
                        "Yevmiye usulü çalışıyorsan ve sadece kendi gününü, ödemeni ve alacağını takip etmek istiyorsan bu kısım sana göre.",
                    bullets: const [
                      "Kendi günlerini düzenli kaydet",
                      "Aldığın ödemeyi takip et",
                      "Ay sonunda hesabın net çıksın",
                    ],
                    onTap: () {
                      setState(() {
                        _kullanimTipi = _KullanimTipi.kisisel;
                        _error = '';
                      });
                    },
                  ),
                  if (_kullanimTipi != null) ...[
                    const SizedBox(height: 24),
                    if (_kullanimTipi == _KullanimTipi.ekipli)
                      _buildEkipliAkis(context, isDark, accent)
                    else
                      _buildKisiselAkis(context, isDark, accent),
                  ],
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: isDark ? 0.40 : 0.22),
                        ),
                      ),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEkipliAkis(BuildContext context, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD8EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isJoining ? "Hazır bir ekibe gir" : "Yeni ekip kur",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _isJoining
                ? "Başka biri bu ekibi kurduysa ekip adını ve şifresini gir. Aynı kayıt üzerinden devam edin."
                : "Eğer puantajı siz yönetecekseniz önce ekibi kurun. Sonra ekibinizdeki diğer kişileri bağlayın.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniSecimButonu(
                  secili: _isJoining,
                  label: "Ekibe katıl",
                  onTap: () {
                    setState(() {
                      _isJoining = true;
                      _error = '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniSecimButonu(
                  secili: !_isJoining,
                  label: "Ekip kur",
                  onTap: () {
                    setState(() {
                      _isJoining = false;
                      _error = '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _ekipAdiController,
            decoration: InputDecoration(
              labelText: "Ekip adı",
              prefixIcon: const Icon(Icons.groups_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _sifreController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Ekip şifresi",
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _submitTeamAction,
                  icon: Icon(
                    _isJoining ? Icons.login_rounded : Icons.add_business_rounded,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: Text(
                    _isJoining ? "Ekiple aynı hesaba geç" : "Ekibi kur ve başla",
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildKisiselAkis(BuildContext context, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD8EAF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Kişisel kullanım",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "Bu seçenekte uygulama sana özel çalışır. Kendi gününü, ödemeni ve hesabını takip edersin. Sonradan istersen ekipli kullanım tarafına da geçebilirsin.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
            ),
          ),
          const SizedBox(height: 14),
          _ozellikKutusu(
            isDark,
            "Kime uygun?",
            "Yevmiye usulü çalışan, kendi hesabını düzenli tutmak isteyen ustaya uygun.",
          ),
          const SizedBox(height: 10),
          _ozellikKutusu(
            isDark,
            "Ne kazanırsın?",
            "Defter karıştırmadan nerede kaç gün çalıştığını ve ne alacağın olduğunu görürsün.",
          ),
          const SizedBox(height: 18),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text("Kendi hesabımla başla"),
                  onPressed: _kisiselDevamEt,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _secimKarti({
    required BuildContext context,
    required bool secili,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF0F7C86);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: secili
              ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark ? const Color(0xFF101317) : const Color(0xFFF7FBFD)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: secili
                ? accent.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFD8EAF0)),
            width: secili ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  secili
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: secili ? 22 : 16,
                  color: secili ? accent : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
              ),
            ),
            const SizedBox(height: 12),
            ...bullets.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.88)
                              : const Color(0xFF31424E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSecimButonu({
    required bool secili,
    required String label,
    required VoidCallback onTap,
  }) {
    const accent = Color(0xFF0F7C86);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: secili ? accent : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secili ? accent : accent.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: secili ? Colors.white : accent,
          ),
        ),
      ),
    );
  }

  Widget _ozellikKutusu(bool isDark, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF5B6B77),
            ),
          ),
        ],
      ),
    );
  }
}
