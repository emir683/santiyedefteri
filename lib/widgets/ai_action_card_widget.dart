import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ai_action_model.dart';

class AIActionCardWidget extends StatefulWidget {
  final AIActionCardData cardData;
  final Future<void> Function(AIActionCardData data) onConfirm;
  final VoidCallback onEdit;
  final bool isDark;

  const AIActionCardWidget({
    super.key,
    required this.cardData,
    required this.onConfirm,
    required this.onEdit,
    required this.isDark,
  });

  @override
  State<AIActionCardWidget> createState() => _AIActionCardWidgetState();
}

class _AIActionCardWidgetState extends State<AIActionCardWidget> {
  bool _isLoading = false;

  bool get _isSummary =>
      widget.cardData.type == AIActionType.siteMonthlySummary ||
      widget.cardData.type == AIActionType.workerMonthlySummary;

  IconData _getCardIcon() {
    switch (widget.cardData.type) {
      case AIActionType.addWorker:
        return Icons.person_add_alt_1_rounded;
      case AIActionType.addPayment:
        return Icons.payments_rounded;
      case AIActionType.submitDailyLog:
        return Icons.assignment_turned_in_rounded;
      case AIActionType.addSite:
        return Icons.apartment_rounded;
      case AIActionType.siteMonthlySummary:
        return Icons.analytics_rounded;
      case AIActionType.workerMonthlySummary:
        return Icons.account_balance_wallet_rounded;
      case AIActionType.materialCalculation:
        return Icons.calculate_rounded;
    }
  }

  Color _getAccentColor() {
    switch (widget.cardData.type) {
      case AIActionType.addWorker:
        return const Color(0xFF10B981);
      case AIActionType.addPayment:
        return const Color(0xFF059669);
      case AIActionType.submitDailyLog:
        return const Color(0xFFF59E0B);
      case AIActionType.addSite:
        return const Color(0xFF8B5CF6);
      case AIActionType.siteMonthlySummary:
        return const Color(0xFF06B6D4);
      case AIActionType.workerMonthlySummary:
        return const Color(0xFF0D9488);
      case AIActionType.materialCalculation:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.cardData.status == AIActionStatus.pending;
    final isConfirmed = widget.cardData.status == AIActionStatus.confirmed;
    final accentColor = _getAccentColor();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? accentColor.withValues(alpha: 0.45)
              : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0)),
          width: isConfirmed ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isConfirmed
                ? accentColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ÜST BAŞLIK ALANI (Overflow-Proof) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFEDF2F7),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCardIcon(),
                      size: 15,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.cardData.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildHeaderBadge(),
                ],
              ),
            ),

            // ── KART İÇERİĞİ / VERİ SATIRLARI ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._buildFieldRows(),
                  const SizedBox(height: 10),

                  // Aksiyon Butonları (Bekliyor durumunda)
                  if (isPending)
                    Row(
                      children: [
                        // Onayla Butonu
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: _isLoading ? null : _handleConfirm,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF0D9488)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Onayla',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Düzenle / İncele Butonu
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: _isLoading ? null : widget.onEdit,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Düzenle',
                                style: GoogleFonts.poppins(
                                  color: widget.isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (isConfirmed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isSummary
                            ? const Color(0xFF06B6D4).withValues(alpha: 0.1)
                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isSummary
                                ? Icons.auto_graph_rounded
                                : Icons.check_circle_rounded,
                            color: _isSummary
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _isSummary
                                  ? 'Kayıtlardan anlık hesaplandı'
                                  : 'Kayıt başarıyla tamamlandı',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: _isSummary
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF10B981),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sağ üst rozet: Kullanıcı isteğiyle "Bekliyor" yazısı kaldırıldı.
  /// Yalnızca özet durumunda veya onaylandığında küçük temiz rozet gösterilir.
  Widget _buildHeaderBadge() {
    if (widget.cardData.status == AIActionStatus.pending) {
      // Bekliyor yazısı tamamen kaldırıldı
      return const SizedBox.shrink();
    }

    if (_isSummary) {
      return Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          'Aylık Özet',
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF06B6D4),
          ),
        ),
      );
    }

    if (widget.cardData.status == AIActionStatus.confirmed) {
      return Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 11, color: Color(0xFF10B981)),
            const SizedBox(width: 3),
            Text(
              'Onaylandı',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _buildFieldRows() {
    final d = widget.cardData.data;
    final List<Widget> rows = [];

    switch (widget.cardData.type) {
      case AIActionType.addWorker:
        final ad = d['ad'] ?? d['name'] ?? '—';
        final isciTuru = d['isciTuru'] ?? 'Çekirdek Ekip';
        final wage = d['gunlukMaas'] ?? d['wage'];
        final wageText = wage != null ? '$wage ₺ / Günlük' : 'Belirtilmedi';

        rows.add(_buildInfoRow('👤 Personel:', '$ad'));
        rows.add(_buildInfoRow('🏷️ Ekip Türü:', '$isciTuru'));
        rows.add(_buildInfoRow('💵 Günlük Maaş:', wageText, isHighlight: true));
        break;

      case AIActionType.addPayment:
        final worker = d['worker'] ?? '—';
        final amt = d['miktar'] ?? d['amount'];
        final amtText = amt != null ? '$amt ₺' : '0 ₺';

        rows.add(_buildInfoRow('👷 Personel:', '$worker'));
        rows.add(_buildInfoRow('💰 Avans Tutarı:', amtText, isHighlight: true));
        break;

      case AIActionType.submitDailyLog:
        final site = d['santiyeAdi'] ?? d['site'] ?? 'Mevcut Şantiye';
        rows.add(_buildInfoRow('🏗️ Şantiye:', '$site'));
        rows.add(_buildInfoRow('👥 Puantaj:', d['workers_summary'] ?? 'Puantaj hazır'));
        if (d['expenses_summary'] != null && d['expenses_summary'].toString().isNotEmpty) {
          rows.add(_buildInfoRow('💸 Giderler:', d['expenses_summary'].toString()));
        }
        break;

      case AIActionType.addSite:
        final siteName = d['ad'] ?? d['name'] ?? '—';
        final il = d['il'] ?? d['city'] ?? 'Belirtilmedi';
        final ilce = (d['ilce'] ?? '').toString();
        rows.add(_buildInfoRow('🏗️ Şantiye Adı:', '$siteName'));
        rows.add(_buildInfoRow('📍 Konum:', ilce.isNotEmpty ? '$ilce / $il' : '$il'));
        break;

      case AIActionType.siteMonthlySummary:
        rows.add(_buildInfoRow('🏗️ Şantiye:', '${d['site_name'] ?? '—'}'));
        rows.add(_buildInfoRow('📅 Dönem:', '${d['period'] ?? 'Bu Ay'}'));
        rows.add(_buildInfoRow('👥 Toplam İş Gücü:', '${d['total_work_days'] ?? 0} Yevmiye (${d['report_count'] ?? 0} Rapor)'));
        rows.add(_buildInfoRow('⛽ Yakıt / Mazot:', '${d['fuel_cost'] ?? 0} ₺'));
        rows.add(_buildInfoRow('🍲 Yemek Gideri:', '${d['food_cost'] ?? 0} ₺'));
        rows.add(_buildInfoRow('📦 Ek Masraflar:', '${d['extra_cost'] ?? 0} ₺'));
        rows.add(_buildInfoRow('👷 İşçilik Maliyeti:', '${d['labor_cost'] ?? 0} ₺'));
        rows.add(_buildInfoRow('💸 Toplam Gider:', '${d['total_expense'] ?? 0} ₺', isHighlight: true, highlightColor: Colors.redAccent));
        if ((d['total_income'] ?? 0) > 0) {
          rows.add(_buildInfoRow('💵 Alınan Hakediş:', '${d['total_income']} ₺'));
          rows.add(_buildInfoRow('⚖️ Kalan Bakiye:', '${d['net_balance']} ₺', isHighlight: true, highlightColor: const Color(0xFF10B981)));
        }
        break;

      case AIActionType.workerMonthlySummary:
        rows.add(_buildInfoRow('👤 Personel:', '${d['worker_name'] ?? '—'} (${d['worker_role'] ?? 'Ekip'})'));
        rows.add(_buildInfoRow('📅 Dönem:', '${d['period'] ?? 'Bu Ay'}'));
        rows.add(_buildInfoRow('💵 Yevmiye:', '${d['daily_wage'] ?? 0} ₺ / Günlük'));
        rows.add(_buildInfoRow('⏱️ Puantaj:', '${d['total_days'] ?? 0} Gün (${d['full_days'] ?? 0} Tam, ${d['half_days'] ?? 0} Y.)'));
        rows.add(_buildInfoRow('💰 Hak Ediş:', '${d['total_earned'] ?? 0} ₺', isHighlight: true));
        rows.add(_buildInfoRow('💸 Verilen Avans:', '${d['total_advance'] ?? 0} ₺'));
        final net = (d['net_balance'] ?? 0) as num;
        rows.add(_buildInfoRow('⚖️ Kalan Alacak:', '$net ₺', isHighlight: true, highlightColor: net >= 0 ? const Color(0xFF10B981) : Colors.redAccent));
        break;
      case AIActionType.materialCalculation:
        rows.add(_buildInfoRow('📐 Ölçüt:', '${d['primaryLabel'] ?? 'Alan'}: ${d['primaryValue'] ?? 0} ${d['primaryUnit'] ?? 'm²'}'));
        if (d['secondaryValue'] != null) {
          rows.add(_buildInfoRow('📏 Boyut:', '${d['secondaryLabel'] ?? 'Kalınlık'}: ${d['secondaryValue']} ${d['secondaryUnit'] ?? 'cm'}'));
        }
        rows.add(_buildInfoRow('📦 Sipariş Miktarı:', '${d['anaMiktar'] ?? '—'}', isHighlight: true));
        rows.add(_buildInfoRow('🚚 Lojistik & Ambalaj:', '${d['lojistik'] ?? '—'}'));
        rows.add(_buildInfoRow('💰 Tahmini Maliyet:', '${d['toplamMaliyet'] ?? 0} ₺', isHighlight: true));
        break;
    }

    return rows;
  }

  /// Overflow-safe bilgi satırı (Esnek flex paylaşımı, asla taşma yapmaz)
  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 5,
            fit: FlexFit.tight,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            fit: FlexFit.tight,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: isHighlight ? 12.5 : 12,
                color: isHighlight
                    ? (highlightColor ?? const Color(0xFF10B981))
                    : (widget.isDark ? Colors.white : const Color(0xFF1E293B)),
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm(widget.cardData);
      if (mounted) {
        setState(() {
          widget.cardData.status = AIActionStatus.confirmed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
