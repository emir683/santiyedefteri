import 'package:flutter/material.dart';
import '../data/turkiye_il_ilce.dart';
import '../models/kullanici_saha_profili.dart';
import '../tema_ayarlari.dart';

class SahaRolSeciciFormu extends StatelessWidget {
  final String seciliRol;
  final String seciliBrans;
  final String seciliSeviye;
  final String seciliKapasite;
  final String seciliSehir;
  final TextEditingController sirketAdiController;
  final TextEditingController? telefonController;
  final TextEditingController? hakkindaController;
  final TextEditingController? yevmiyeBeklentisiController;
  final bool isAriyorum;
  final bool ustaAriyorum;
  final bool vitrindeGoster;
  final bool detayliMod;
  final ValueChanged<String> onRolChanged;
  final ValueChanged<String> onBransChanged;
  final ValueChanged<String> onSeviyeChanged;
  final ValueChanged<String> onKapasiteChanged;
  final ValueChanged<String> onSehirChanged;
  final ValueChanged<bool>? onIsAriyorumChanged;
  final ValueChanged<bool>? onUstaAriyorumChanged;
  final ValueChanged<bool>? onVitrindeGosterChanged;

  const SahaRolSeciciFormu({
    super.key,
    required this.seciliRol,
    required this.seciliBrans,
    required this.seciliSeviye,
    required this.seciliKapasite,
    required this.seciliSehir,
    required this.sirketAdiController,
    this.telefonController,
    this.hakkindaController,
    this.yevmiyeBeklentisiController,
    this.isAriyorum = false,
    this.ustaAriyorum = false,
    this.vitrindeGoster = true,
    this.detayliMod = false,
    required this.onRolChanged,
    required this.onBransChanged,
    required this.onSeviyeChanged,
    required this.onKapasiteChanged,
    required this.onSehirChanged,
    this.onIsAriyorumChanged,
    this.onUstaAriyorumChanged,
    this.onVitrindeGosterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary = AppTheme.primary(context);
    final themeContrastIcon = AppTheme.contrastIcon(context);
    final aktifRol =
        seciliRol.isNotEmpty ? seciliRol : KullaniciRolu.muteahhit;
    final branslar = KullaniciRolu.bransSecenekleri(aktifRol);
    final seviyeler = KullaniciRolu.seviyeSecenekleri(aktifRol);
    final kapasiteler =
        KullaniciRolu.kapasiteVeyaCalismaSekliSecenekleri(aktifRol);

    final gecerliBrans =
        branslar.contains(seciliBrans) ? seciliBrans : branslar.first;
    final gecerliSeviye =
        seviyeler.contains(seciliSeviye) ? seciliSeviye : seviyeler.first;
    final gecerliKapasite =
        kapasiteler.contains(seciliKapasite)
            ? seciliKapasite
            : kapasiteler.first;
    final iller = TurkiyeIlIlce.iller.map((e) => e['il'] as String).toList();
    final gecerliSehir =
        iller.contains(seciliSehir) ? seciliSehir : 'İstanbul';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Şantiyede Ne İş Yapıyorsunuz?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF102A43),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Seçiminize göre ana ekranınız, puantaj araçlarınız ve ilan vitrininiz özelleştirilir.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        ...KullaniciRolu.tumRoller.map((rol) {
          final String id = rol['id'] as String;
          final bool isSelected = aktifRol == id;
          final Color accent = rol['renk'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onRolChanged(id),
              child: PanelGlassWidgets.buildInset(
                context: context,
                borderColor:
                    isSelected
                        ? themePrimary.withValues(alpha: 0.85)
                        : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    PanelGlassWidgets.buildIconBadge(
                      context: context,
                      icon: rol['ikon'] as IconData,
                      accentColor: accent,
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rol['baslik'] as String,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rol['altBaslik'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color:
                          isSelected
                              ? themeContrastIcon
                              : (isDark ? Colors.white30 : Colors.black26),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        Text(
          '2. Görev, Branş ve Seviye Bilgileriniz',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF102A43),
          ),
        ),
        const SizedBox(height: 10),
        _buildDropdownTile(
          context: context,
          label:
              aktifRol == KullaniciRolu.muteahhit
                  ? 'Faaliyet Alanı / Sektör'
                  : (aktifRol == KullaniciRolu.santiyeSefi
                      ? 'Meslek / Uzmanlık Alanı'
                      : 'Ustalık Branşı / Yaptığı İş'),
          icon: Icons.construction_rounded,
          value: gecerliBrans,
          items: branslar,
          onChanged: (v) {
            if (v != null) onBransChanged(v);
          },
        ),
        const SizedBox(height: 10),
        _buildDropdownTile(
          context: context,
          label:
              aktifRol == KullaniciRolu.isciUsta
                  ? 'Ustalık & Görev Seviyesi'
                  : 'Görev / Pozisyon Seviyesi',
          icon: Icons.workspace_premium_rounded,
          value: gecerliSeviye,
          items: seviyeler,
          onChanged: (v) {
            if (v != null) onSeviyeChanged(v);
          },
        ),
        const SizedBox(height: 10),
        _buildDropdownTile(
          context: context,
          label:
              aktifRol == KullaniciRolu.taseronKalfa
                  ? 'Ekip Kişi Sayısı / Kapasite'
                  : (aktifRol == KullaniciRolu.isciUsta
                      ? 'Tercih Edilen Çalışma Şekli'
                      : 'Aktif Proje / Şantiye Ölçeği'),
          icon:
              aktifRol == KullaniciRolu.taseronKalfa
                  ? Icons.groups_2_rounded
                  : Icons.tune_rounded,
          value: gecerliKapasite,
          items: kapasiteler,
          onChanged: (v) {
            if (v != null) onKapasiteChanged(v);
          },
        ),
        const SizedBox(height: 10),
        _buildDropdownTile(
          context: context,
          label: 'Bulunduğunuz Şehir (İl)',
          icon: Icons.location_on_outlined,
          value: gecerliSehir,
          items: iller,
          onChanged: (v) {
            if (v != null) onSehirChanged(v);
          },
        ),
        if (aktifRol != KullaniciRolu.isciUsta) ...[
          const SizedBox(height: 10),
          _buildTextInputTile(
            context: context,
            controller: sirketAdiController,
            label:
                aktifRol == KullaniciRolu.muteahhit
                    ? 'Şirket / Müteahhitlik Firma Adı'
                    : (aktifRol == KullaniciRolu.taseronKalfa
                        ? 'Ekip veya Taşeron Adı (Opsiyonel)'
                        : 'Çalıştığınız Şirket / Şantiye (Opsiyonel)'),
            icon: Icons.business_rounded,
          ),
        ],
        if (detayliMod) ...[
          if (telefonController != null) ...[
            const SizedBox(height: 10),
            _buildTextInputTile(
              context: context,
              controller: telefonController!,
              label: 'İletişim Telefonu (İlan & Vitrin İçin Opsiyonel)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
          if (aktifRol == KullaniciRolu.isciUsta &&
              yevmiyeBeklentisiController != null) ...[
            const SizedBox(height: 10),
            _buildTextInputTile(
              context: context,
              controller: yevmiyeBeklentisiController!,
              label: 'Günlük Yevmiye / Ücret Beklentiniz (TL - Opsiyonel)',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
          ],
          if (hakkindaController != null) ...[
            const SizedBox(height: 10),
            _buildTextInputTile(
              context: context,
              controller: hakkindaController!,
              label:
                  aktifRol == KullaniciRolu.muteahhit
                      ? 'Şirket Tanıtımı / Yaptığınız Projeler'
                      : 'Deneyim & Referans Notunuz (Örn: 12 yıllık kalıp ustasıyım)',
              icon: Icons.notes_rounded,
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 12),
          if (aktifRol == KullaniciRolu.isciUsta ||
              aktifRol == KullaniciRolu.taseronKalfa)
            PanelGlassWidgets.buildInset(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  aktifRol == KullaniciRolu.taseronKalfa
                      ? 'Ekibim İş Alabilir / Müsait'
                      : 'İş Arıyorum / Şu An Müsaitim',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                subtitle: Text(
                  'Açık olduğunda müteahhitler Şantiye Pazarı\'nda sizi "Müsait" olarak görür.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                value: isAriyorum,
                activeThumbColor: Colors.white,
                activeTrackColor: themePrimary,
                onChanged: onIsAriyorumChanged,
              ),
            ),
          if (aktifRol == KullaniciRolu.muteahhit ||
              aktifRol == KullaniciRolu.santiyeSefi)
            PanelGlassWidgets.buildInset(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Şirketimi & Usta Arayışımı Vitrinde Göster',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
                subtitle: Text(
                  'Ustalar ve taşeron ekipler şirket kartınızı Şantiye Pazarı\'nda görebilir.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                value: ustaAriyorum,
                activeThumbColor: Colors.white,
                activeTrackColor: themePrimary,
                onChanged: onUstaAriyorumChanged,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDropdownTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeContrast = AppTheme.contrastIcon(context);
    return PanelGlassWidgets.buildInset(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF101317) : Colors.white,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF102A43),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          prefixIcon: Icon(icon, size: 20, color: themeContrast),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        items:
            items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextInputTile({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeContrast = AppTheme.contrastIcon(context);
    return PanelGlassWidgets.buildInset(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF102A43),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          prefixIcon: Icon(icon, size: 20, color: themeContrast),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}

