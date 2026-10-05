import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'deep_link_service.dart';
import 'firestore_servisi.dart';
import 'user_model.dart';
import 'widgets/glass_surface.dart';
import 'widgets/floating_liquid_app_bar.dart';

class JoinTeamPage extends StatefulWidget {
  const JoinTeamPage({
    super.key,
    required this.ekipAdi,
    this.ekipId,
    this.sifre,
  });

  final String ekipAdi;
  final String? ekipId;
  final String? sifre;

  @override
  State<JoinTeamPage> createState() => _JoinTeamPageState();
}

class _JoinTeamPageState extends State<JoinTeamPage> {
  bool _loading = false;
  String _error = '';

  Future<void> _ekibeKatil() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() {
        _error =
            "Davet bilgisi al\u0131nd\u0131. Devam etmek i\u00e7in \u00f6nce giri\u015f yapmal\u0131s\u0131n.";
      });
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
      if (widget.ekipId != null && widget.ekipId!.isNotEmpty) {
        teamId = await firestoreServisi.ekibeKatilDavetLinki(
          widget.ekipId!,
          beklenenEkipAdi: widget.ekipAdi,
        );
      } else if (widget.sifre != null && widget.sifre!.isNotEmpty) {
        teamId = await firestoreServisi.ekibeKatil(
          widget.ekipAdi,
          widget.sifre!,
        );
      } else {
        throw Exception("Davet ba\u011flant\u0131s\u0131 eksik veya ge\u00e7ersiz.");
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    if (teamId != null) {
      await DeepLinkService.instance.clearInvite();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _error = errorMessage ?? "Ekibe kat\u0131l\u0131rken bir hata olu\u015ftu.";
      _loading = false;
    });
  }

  Future<void> _vazgec() async {
    await DeepLinkService.instance.clearInvite();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await DeepLinkService.instance.clearInvite();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: FloatingLiquidAppBar(
          title: "Ekibe Katıl",
          showPrivacyButton: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _loading ? null : _vazgec,
          ),
        ),
        body: GlassPageSurface(
          preferSoftLightBackground: true,
          child: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  FloatingLiquidAppBar.topPadding(context, extra: 4),
                  24,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: GlassSectionCard(
                    borderRadius: 30,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const GlassIconBadge(
                              icon: Icons.groups_rounded,
                              color: Color(0xFF24B7A4),
                              size: 58,
                              iconSize: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Ekip Daveti",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF4C6A74),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.ekipAdi,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "\u015eantiye Puantaj Defteri i\u00e7indeki bu ekibe tek dokunu\u015fla kat\u0131labilirsin.",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF516772),
                          ),
                        ),
                        const SizedBox(height: 18),
                        GlassInsetSurface(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ekip Ad\u0131",
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF5B727C),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.ekipAdi,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.ekipId != null && widget.ekipId!.isNotEmpty
                                    ? "G\u00fcvenli ekip davet ba\u011flant\u0131s\u0131 haz\u0131r."
                                    : "Parola tabanl\u0131 davet kullan\u0131lacak.",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF516772),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 
                                isDark ? 0.16 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 
                                  isDark ? 0.28 : 0.18,
                                ),
                              ),
                            ),
                            child: Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF8A8A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _loading ? null : _ekibeKatil,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF24B7A4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            _loading ? "Kat\u0131l\u0131yor..." : "Ekibe Kat\u0131l",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading ? null : _vazgec,
                          child: const Text("\u015eimdilik Vazge\u00e7"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
