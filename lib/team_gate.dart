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
    final user = Provider.of<UserModel>(context, listen: false);

    if (_ekipAdiController.text.isEmpty || _sifreController.text.isEmpty) {
      setState(() => _error = "Lutfen tum alanlari doldurun.");
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
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
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = errorMessage ?? "Islem basarisiz. Bilgileri kontrol edin.";
      _loading = false;
    });
  }

  Future<void> _kisiselDevamEt() async {
    final user = Provider.of<UserModel>(context, listen: false);

    setState(() {
      _loading = true;
      _error = '';
    });

    final firestoreServisi = FirestoreServisi(kullaniciId: user.uid);
    String? teamId;
    String? errorMessage;

    try {
      teamId = await firestoreServisi.kisiselEkipOlustur();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (teamId != null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = errorMessage ?? "Bir hata olustu.";
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF0F7C86);

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
                  "Bu uygulama sadece puantaj yazmak icin degil. Hesap karismasin, ekip ayni kaydi tek yerden tutsun diye var.",
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
                  title: "Ekiple calisiyorum",
                  subtitle:
                      "Yaninda isci varsa, puantaji bazen birden fazla kisi tutuyorsa veya ay sonu hesaplar karisiyorsa bu kisim sana gore.",
                  bullets: const [
                    "Ayni ekibin kaydini birlikte yonetin",
                    "Santiyeye gore puantaj ve masraf tutun",
                    "Ay sonu hesabini tek yerden cikarin",
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
                  title: "Kendi hesabimi tutacagim",
                  subtitle:
                      "Yevmiye usulu calisiyorsan ve sadece kendi gununu, odemeni ve alacagini takip etmek istiyorsan bu kisim sana gore.",
                  bullets: const [
                    "Kendi gunlerini duzenli kaydet",
                    "Aldigin odemeyi takip et",
                    "Ay sonunda hesabin net ciksin",
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
            _isJoining ? "Hazir bir ekibe gir" : "Yeni ekip kur",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _isJoining
                ? "Baska biri bu ekibi kurduysa ekip adini ve sifresini gir. Ayni kayit uzerinden devam edin."
                : "Eger puantaji siz yonetecekseniz once ekibi kurun. Sonra ekibinizdeki diger kisileri baglayin.",
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
                  label: "Ekibe katil",
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
              labelText: "Ekip adi",
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
              labelText: "Ekip sifresi",
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
                    _isJoining ? "Ekiple ayni hesaba gec" : "Ekibi kur ve basla",
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
            "Kisisel kullanim",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "Bu secenekte uygulama sana ozel calisir. Kendi gununu, odemeni ve hesabini takip edersin. Sonradan istersen ekipli kullanim tarafina da gecebilirsin.",
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
            "Yevmiye usulu calisan, kendi hesabini duzenli tutmak isteyen ustaya uygun.",
          ),
          const SizedBox(height: 10),
          _ozellikKutusu(
            isDark,
            "Ne kazanirsin?",
            "Defter karistirmadan nerede kac gun calistigini ve ne alacagin oldugunu gorursun.",
          ),
          const SizedBox(height: 18),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text("Kendi hesabimla basla"),
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
