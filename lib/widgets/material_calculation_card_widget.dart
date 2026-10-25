import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ai_action_model.dart';
import '../models/metraj_hesap_model.dart';
import '../services/ai/insaat_metraj_hesaplayici.dart';

/// ŞPD AI - Akıllı İnşaat Malzeme & Metraj Hesaplama Kartı 🧱📐
/// Chat mesajı içerisinde interaktif olarak parametrelerin değiştirilip
/// anında yeniden hesaplanmasını sağlar.
class MaterialCalculationCardWidget extends StatefulWidget {
  final AIActionCardData cardData;
  final bool isDark;
  final ValueChanged<AIActionCardData>? onUpdate;

  const MaterialCalculationCardWidget({
    super.key,
    required this.cardData,
    required this.isDark,
    this.onUpdate,
  });

  @override
  State<MaterialCalculationCardWidget> createState() =>
      _MaterialCalculationCardWidgetState();
}

class _MaterialCalculationCardWidgetState
    extends State<MaterialCalculationCardWidget>
    with SingleTickerProviderStateMixin {
  late MetrajHesapModel _model;
  bool _isEditing = false;
  bool _isDetailsExpanded = false;

  // Edit Controller'ları
  late TextEditingController _primaryValCtrl;
  late TextEditingController _secondaryValCtrl;
  late TextEditingController _birimFiyatCtrl;
  late String _selectedVariant;

  @override
  void initState() {
    super.initState();
    _initFromData();
  }

  @override
  void didUpdateWidget(covariant MaterialCalculationCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardData.data != widget.cardData.data) {
      _initFromData();
    }
  }

  void _initFromData() {
    _model = MetrajHesapModel.fromMap(widget.cardData.data);
    _primaryValCtrl = TextEditingController(
      text: InsaatMetrajHesaplayici.formatDouble(_model.primaryValue),
    );
    _secondaryValCtrl = TextEditingController(
      text: _model.secondaryValue != null
          ? InsaatMetrajHesaplayici.formatDouble(_model.secondaryValue!)
          : '',
    );
    _birimFiyatCtrl = TextEditingController(
      text: _model.birimFiyat.toInt().toString(),
    );
    _selectedVariant = _model.selectedVariant;
  }

  @override
  void dispose() {
    _primaryValCtrl.dispose();
    _secondaryValCtrl.dispose();
    _birimFiyatCtrl.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    switch (_model.category) {
      case 'beton':
        return const Color(0xFF10B981); // Emerald
      case 'tugla':
        return const Color(0xFFF97316); // Orange
      case 'seramik':
        return const Color(0xFF06B6D4); // Cyan
      case 'sap':
        return const Color(0xFF3B82F6); // Blue
      case 'siva':
        return const Color(0xFF8B5CF6); // Purple
      case 'boya':
        return const Color(0xFFEC4899); // Pink
      case 'demir':
        return const Color(0xFF64748B); // Slate
      case 'alcipan':
        return const Color(0xFF14B8A6); // Teal
      case 'mantolama':
        return const Color(0xFFEAB308); // Amber
      case 'yalitim':
        return const Color(0xFF0284C7); // Light Blue
      case 'hafriyat':
        return const Color(0xFFD97706); // Dark Amber
      case 'parke':
        return const Color(0xFF854D0E); // Brown
      default:
        return const Color(0xFF10B981);
    }
  }

  void _performRecalculate() {
    HapticFeedback.mediumImpact();
    final pVal = double.tryParse(_primaryValCtrl.text.replaceAll(',', '.')) ??
        _model.primaryValue;
    final sVal = _model.secondaryValue != null
        ? (double.tryParse(_secondaryValCtrl.text.replaceAll(',', '.')) ??
            _model.secondaryValue)
        : null;
    final bFiyat =
        double.tryParse(_birimFiyatCtrl.text.replaceAll(',', '.')) ??
            _model.birimFiyat;

    final updatedModel = InsaatMetrajHesaplayici.recalculate(
      _model,
      primaryValue: pVal,
      secondaryValue: sVal,
      variant: _selectedVariant,
      birimFiyat: bFiyat,
    );

    setState(() {
      _model = updatedModel;
      _isEditing = false;
    });

    final updatedCard = widget.cardData.copyWith(
      title: updatedModel.title,
      description: updatedModel.ozetBilgi,
      data: updatedModel.toMap(),
    );

    widget.onUpdate?.call(updatedCard);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              '${updatedModel.title} güncellendi!',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyReportToClipboard() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _model.raporMetni));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Metraj raporu panoya kopyalandı 📋',
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _shareReport() {
    HapticFeedback.lightImpact();
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 100, 100);
    Share.share(
      _model.raporMetni,
      subject: _model.title,
      sharePositionOrigin: origin,
    );
  }

  void _adjustPrimaryValue(double delta) {
    HapticFeedback.selectionClick();
    final current =
        double.tryParse(_primaryValCtrl.text.replaceAll(',', '.')) ??
            _model.primaryValue;
    final next = (current + delta).clamp(1.0, 100000.0);
    _primaryValCtrl.text = InsaatMetrajHesaplayici.formatDouble(next);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getCategoryColor();
    final isDark = widget.isDark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. ÜST BAŞLIK BAR (İkon + Başlık + Düzenle Butonu) ──
            _buildHeader(accentColor, isDark),

            // ── 2. ANA METRİK KARTLARI (3 KPI: Miktar, Lojistik, Maliyet) ──
            _buildKeyMetricsRow(accentColor, isDark),

            // ── 3. MEVCUT GİRDİ ROZETLERİ (Parametreler) ──
            _buildParametersPills(accentColor, isDark),

            // ── 4. İNTERAKTİF DÜZENLEME PANELİ (Açık ise görünür) ──
            if (_isEditing) _buildInlineEditPanel(accentColor, isDark),

            // ── 5. DETAYLI RAPOR & MALZEME LİSTESİ (Açılır/Kapanır) ──
            if (_isDetailsExpanded) _buildExpandedDetails(accentColor, isDark),

            // ── 6. ALT AKSİYON BAR (Değerleri Değiştir / Kopyala / Paylaş) ──
            _buildFooterActions(accentColor, isDark),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFEDF2F7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Kategori İkonu
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor,
                  accentColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _model.icon,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Başlık & Alt Başlık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _model.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _model.selectedVariant.isNotEmpty
                      ? _model.selectedVariant
                      : 'Şantiyeye Özel Metraj Hesabı',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Değerleri Düzenle Butonu (Üst Hızlı Buton)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isEditing = !_isEditing);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _isEditing
                      ? accentColor.withValues(alpha: 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isEditing
                        ? accentColor.withValues(alpha: 0.5)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isEditing ? Icons.close_rounded : Icons.tune_rounded,
                      size: 13,
                      color: _isEditing
                          ? accentColor
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isEditing ? 'Kapat' : 'Düzenle',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isEditing
                            ? accentColor
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. KEY METRICS ROW (Miktar, Lojistik, Maliyet)
  // ─────────────────────────────────────────────────────────────
  Widget _buildKeyMetricsRow(Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          // 1. Miktar
          Expanded(
            child: _metricBox(
              icon: Icons.inventory_2_rounded,
              value: _model.anaMiktar,
              label: _model.anaMiktarLabel,
              color: accentColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // 2. Lojistik / Paket
          Expanded(
            child: _metricBox(
              icon: Icons.local_shipping_rounded,
              value: _model.lojistik,
              label: _model.lojistikLabel,
              color: const Color(0xFF06B6D4), // Cyan
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Maliyet
          Expanded(
            child: _metricBox(
              icon: Icons.payments_rounded,
              value: InsaatMetrajHesaplayici.formatPara(_model.toplamMaliyet),
              label: _model.toplamMaliyetLabel,
              color: const Color(0xFFF59E0B), // Amber
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. PARAMETERS ROW (Pills)
  // ─────────────────────────────────────────────────────────────
  Widget _buildParametersPills(Color accentColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: [
          _pill(
            '📐 ${_model.primaryLabel}: ${InsaatMetrajHesaplayici.formatDouble(_model.primaryValue)} ${_model.primaryUnit}',
            accentColor,
            isDark,
          ),
          if (_model.secondaryValue != null && _model.secondaryLabel != null)
            _pill(
              '📏 ${_model.secondaryLabel}: ${InsaatMetrajHesaplayici.formatDouble(_model.secondaryValue!)} ${_model.secondaryUnit}',
              const Color(0xFF3B82F6),
              isDark,
            ),
          _pill(
            '⚠️ Fire: ${_model.firePayi}',
            const Color(0xFFF59E0B),
            isDark,
          ),
          _pill(
            '💰 Birim: ${InsaatMetrajHesaplayici.formatPara(_model.birimFiyat)}',
            const Color(0xFF10B981),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF334155),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. INLINE EDIT PANEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildInlineEditPanel(Color accentColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Değerleri Değiştir & Hesapla',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Ana Girdi (Alan / Kazı Hacmi)
          Text(
            '${_model.primaryLabel} (${_model.primaryUnit})',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _primaryValCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white12
                      : const Color(0xFFCBD5E1),
                ),
              ),
              suffixText: _model.primaryUnit,
            ),
          ),
          const SizedBox(height: 5),
          // Hızlı Adım Butonları (alt satırda, taşmaz)
          Wrap(
            spacing: 5,
            children: [
              _quickStepButton('-50', () => _adjustPrimaryValue(-50), isDark),
              _quickStepButton('-10', () => _adjustPrimaryValue(-10), isDark),
              _quickStepButton('+10', () => _adjustPrimaryValue(10), isDark),
              _quickStepButton('+50', () => _adjustPrimaryValue(50), isDark),
            ],
          ),
          const SizedBox(height: 10),

          // 2. İkincil Girdi (Kalınlık / Yükseklik) - Varsa
          if (_model.secondaryValue != null && _model.secondaryLabel != null) ...[
            Text(
              '${_model.secondaryLabel} (${_model.secondaryUnit})',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _secondaryValCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                suffixText: _model.secondaryUnit,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 3. Malzeme Varyantı Seçimi
          if (_model.availableVariants.isNotEmpty) ...[
            Text(
              'Malzeme Türü / Sınıfı',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _model.availableVariants.map((variant) {
                final isSelected = _selectedVariant == variant;
                return ChoiceChip(
                  label: Text(variant),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                  selected: isSelected,
                  selectedColor: accentColor,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? accentColor
                          : (isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedVariant = variant);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // 4. Birim Fiyat (TL)
          Text(
            _model.birimFiyatLabel,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _birimFiyatCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
              ),
              suffixText: '₺',
            ),
          ),
          const SizedBox(height: 12),

          // Hesapla Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _performRecalculate,
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: Text(
                'Anında Yeniden Hesapla',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStepButton(String text, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. EXPANDED DETAILS (Detaylı Liste & Şantiye Notları)
  // ─────────────────────────────────────────────────────────────
  Widget _buildExpandedDetails(Color accentColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarf Malzemeler
          if (_model.sarfMalzemeler.isNotEmpty) ...[
            Text(
              '📦 İhtiyaç Duyulan Malzemeler:',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ..._model.sarfMalzemeler.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Şantiye Tavsiyeleri
          if (_model.tavsiyeler.isNotEmpty) ...[
            Text(
              '💡 Şantiye Şefine Tavsiyeler:',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 6),
            ..._model.tavsiyeler.map(
              (tavsiye) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tavsiye,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. FOOTER ACTIONS (Değerleri Değiştir / Detayları Gör / Kopyala / Paylaş)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFooterActions(Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFEDF2F7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Detayları Aç/Kapat Butonu
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isDetailsExpanded = !_isDetailsExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDetailsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _isDetailsExpanded ? 'Detayı Gizle' : 'Detaylı Rapor',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Kopyala Butonu
          IconButton(
            onPressed: _copyReportToClipboard,
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Raporu Kopyala',
            visualDensity: VisualDensity.compact,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),

          // Paylaş Butonu
          IconButton(
            onPressed: _shareReport,
            icon: const Icon(Icons.share_rounded, size: 16),
            tooltip: 'Raporu Paylaş',
            visualDensity: VisualDensity.compact,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ],
      ),
    );
  }
}
