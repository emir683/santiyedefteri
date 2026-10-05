import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/connectivity_sync_service.dart';

class OfflineSyncBanner extends StatefulWidget {
  final bool compact;
  const OfflineSyncBanner({super.key, this.compact = false});

  static void showSyncDetailSheet(
    BuildContext context, [
    ConnectivitySyncService? service,
  ]) {
    _OfflineSyncBannerState.showSyncDetailSheet(context, service);
  }

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends State<OfflineSyncBanner>
    with SingleTickerProviderStateMixin {
  bool _showOnlineSuccessBriefly = false;
  SyncStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<ConnectivitySyncService>();
    final currentStatus = syncService.status;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Çevrimdışından veya senkronizasyondan Çevrimiçine geçildiğinde 3.5 sn onay göster
    if ((_lastStatus == SyncStatus.offline ||
            _lastStatus == SyncStatus.syncing) &&
        currentStatus == SyncStatus.online) {
      _showOnlineSuccessBriefly = true;
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) {
          setState(() {
            _showOnlineSuccessBriefly = false;
          });
        }
      });
    }
    _lastStatus = currentStatus;

    if (currentStatus == SyncStatus.online && !_showOnlineSuccessBriefly) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactBanner(context, syncService, currentStatus, isDark);
    }

    return _buildFullBanner(context, syncService, currentStatus, isDark);
  }

  Widget _buildFullBanner(
    BuildContext context,
    ConnectivitySyncService syncService,
    SyncStatus status,
    bool isDark,
  ) {
    final isOffline = status == SyncStatus.offline;
    final isSyncing = status == SyncStatus.syncing;

    final Color bgColor =
        isOffline
            ? const Color(0xFFD97706) // Sıcak Amber
            : isSyncing
            ? const Color(0xFF0284C7) // Gökyüzü Mavisi
            : const Color(0xFF16A34A); // Zümrüt Yeşili

    final IconData icon =
        isOffline
            ? Icons.cloud_off_rounded
            : isSyncing
            ? Icons.sync_rounded
            : Icons.check_circle_rounded;

    final String title =
        isOffline
            ? "Çevrimdışı Mod (İnternet Yok)"
            : isSyncing
            ? "İnternet Bağlandı • Buluta Eşitleniyor..."
            : "Tüm Veriler Eşitlendi";

    final String subtitle =
        isOffline
            ? "Rapor ve puantajlar telefona güvenle kaydediliyor. İnternet gelince otomatik eşitlenecek."
            : isSyncing
            ? "Sahada girdiğiniz yerel kayıtlar bulut sunucuya aktarılıyor, lütfen bekleyin."
            : "Şantiye kayıtlarınız güncel ve bulut ile tam uyumlu.";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: isDark ? 0.88 : 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showSyncDetailSheet(context, syncService),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child:
                      isSyncing
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Bilgi",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 14,
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

  Widget _buildCompactBanner(
    BuildContext context,
    ConnectivitySyncService syncService,
    SyncStatus status,
    bool isDark,
  ) {
    final isOffline = status == SyncStatus.offline;
    final isSyncing = status == SyncStatus.syncing;

    final Color bgColor =
        isOffline
            ? const Color(0xFFD97706)
            : isSyncing
            ? const Color(0xFF0284C7)
            : const Color(0xFF16A34A);

    return InkWell(
      onTap: () => showSyncDetailSheet(context, syncService),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: isDark ? 0.9 : 0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 14,
              ),
            const SizedBox(width: 6),
            Text(
              isOffline
                  ? "Çevrimdışı (Telefona Kaydediliyor)"
                  : isSyncing
                  ? "Buluta Eşitleniyor..."
                  : "Eşitlendi",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showSyncDetailSheet(
    BuildContext context, [
    ConnectivitySyncService? service,
  ]) {
    final syncService =
        service ?? Provider.of<ConnectivitySyncService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = syncService.status;
    final lastSync = syncService.lastSyncTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => SafeArea(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF131922).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F7C86).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          color: Color(0xFF0F7C86),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Çevrimdışı Çalışma & Eşitleme",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    isDark: isDark,
                    icon:
                        status == SyncStatus.online
                            ? Icons.wifi_rounded
                            : status == SyncStatus.syncing
                            ? Icons.sync_rounded
                            : Icons.wifi_off_rounded,
                    title: "Bağlantı Durumu",
                    value:
                        status == SyncStatus.online
                            ? "Çevrimiçi (İnternet Var)"
                            : status == SyncStatus.syncing
                            ? "Senkronizasyon Yapılıyor..."
                            : "Çevrimdışı (İnternet Yok)",
                    valueColor:
                        status == SyncStatus.online
                            ? Colors.green
                            : status == SyncStatus.syncing
                            ? Colors.blue
                            : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    isDark: isDark,
                    icon: Icons.storage_rounded,
                    title: "Yerel Önbellek (Kalıcı)",
                    value: "Aktif (Sınırsız Kapasite)",
                    valueColor: const Color(0xFF0F7C86),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    isDark: isDark,
                    icon: Icons.history_rounded,
                    title: "Son Başarılı Eşitleme",
                    value:
                        lastSync != null
                            ? DateFormat('dd.MM.yyyy HH:mm').format(lastSync)
                            : "Uygulama açılışında",
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "💡 Bilgi: Şantiye bodrumlarında veya kırsal alanda internet kesilse bile raporlarınızı, çalışan puantajlarını ve avansları kaydetmeye devam edebilirsiniz. İnternet geri geldiğinde tüm veriler arka planda kayıpsız eşitlenir.",
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color:
                            isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7C86),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final success = await syncService.syncNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  success
                                      ? Icons.check_circle_outline
                                      : Icons.wifi_off,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    success
                                        ? "Bulut eşitlemesi başarıyla tamamlandı!"
                                        : "İnternet bağlantısı bulunamadı. Verileriniz yerel bellekte güvende.",
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      "Şimdi Eşitlemeyi Dene",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildDetailRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F7C86)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color:
                  valueColor ??
                  (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
