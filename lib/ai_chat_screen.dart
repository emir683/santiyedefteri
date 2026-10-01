import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'models/ai_action_model.dart';
import 'services/ai/ai_service.dart';
import 'services/ai/ai_rate_limiter.dart';
import 'widgets/ai_action_card_widget.dart';
import 'widgets/gemini_splash_effect.dart';
import 'firestore_servisi.dart';
import 'data_models.dart';
import 'user_model.dart';

class AIChatScreen extends StatefulWidget {
  final String teamId;
  final List<Isci> isciler;
  final List<Santiye> santiyeler;
  final String? initialPrompt;

  const AIChatScreen({
    super.key,
    required this.teamId,
    this.isciler = const [],
    this.santiyeler = const [],
    this.initialPrompt,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<AIChatMessage> _messages = [];
  bool _isProcessing = false;
  int _remainingAiQuota = 10;
  final GlobalKey<MysticalWavesState> _bottomWavesKey = GlobalKey();

  // Ses Motoru
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitialized = false;

  // Animasyon
  late AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _speech = stt.SpeechToText();
    _initSpeech();
    _loadQuota();
    AIService.setRateLimitChecker(() => AiRateLimiter.checkAndIncrement());

    _textController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendText(widget.initialPrompt!);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    _waveAnimController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
            _bottomWavesKey.currentState?.setVoiceActive(false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _bottomWavesKey.currentState?.setVoiceActive(false);
        },
      );
    } catch (_) {}
  }

  Future<void> _stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      await _speech.cancel();
    } catch (_) {}
    if (mounted) {
      setState(() => _isListening = false);
      _bottomWavesKey.currentState?.setVoiceActive(false);
    }
  }

  Future<void> _toggleListening() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _stopListening();
      if (_textController.text.trim().isNotEmpty) {
        _handleSendText(_textController.text);
      }
      return;
    }

    if (!_speechInitialized) {
      await _initSpeech();
    }
    if (!_speechInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon başlatılamadı.')),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    _bottomWavesKey.currentState?.setVoiceActive(true);

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onSoundLevelChange: (level) {
          if (!mounted || !_isListening) return;
          // Android/iOS STT seviyesi: dB (-30..10) veya standart 0..10
          final raw = level.isNegative ? (level + 24).clamp(0.0, 30.0) : level;
          final normalized = (raw / 10.0).clamp(0.0, 1.0);
          _bottomWavesKey.currentState?.updateVoiceLevel(normalized);
        },
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _textController.text = result.recognizedWords;
          });
          _bottomWavesKey.currentState?.pulse();
          if (result.finalResult) {
            _stopListening();
            if (_textController.text.trim().isNotEmpty) {
              _handleSendText(_textController.text);
            }
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
        _bottomWavesKey.currentState?.setVoiceActive(false);
      }
    }
  }

  Future<void> _loadQuota() async {
    final remaining = await AiRateLimiter.getRemainingToday();
    if (mounted) {
      setState(() {
        _remainingAiQuota = remaining;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Future<void> _handleSendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isProcessing) return;

    // Kullanıcı mesajı gönderdiği anda klavyeyi anında kapat
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    _focusNode.unfocus();

    _textController.clear();
    HapticFeedback.lightImpact();

    final userMsg = AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isProcessing = true;
    });
    _bottomWavesKey.currentState?.startAnimation();
    _scrollToBottom();

    try {
      final workerNames = widget.isciler.map((i) => i.ad).toList();
      final siteNames = widget.santiyeler.map((s) => s.ad).toList();
      final userModel = Provider.of<UserModel?>(context, listen: false);
      final kullaniciId = userModel?.uid ?? '';
      final servisi = FirestoreServisi(kullaniciId: kullaniciId);

      final aiMsg = await AIService.processChatMessage(
        trimmed,
        workerNames: workerNames,
        siteNames: siteNames,
        isciler: widget.isciler,
        santiyeler: widget.santiyeler,
        teamId: widget.teamId,
        servisi: servisi,
      );

      // Klavyenin kapanma animasyonunun rahatça tamamlanması ve doğal düşünme hissi için hafif gecikme
      await Future.delayed(const Duration(milliseconds: 450));

      if (mounted) {
        setState(() {
          _messages.add(aiMsg);
          _isProcessing = false;
        });
        _bottomWavesKey.currentState?.stopAnimation();
        _loadQuota();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            AIChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: 'Üzgünüm, isteğinizi işlerken bir sorun oluştu: $e',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isProcessing = false;
        });
        _bottomWavesKey.currentState?.stopAnimation();
        _scrollToBottom();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ONAY & DATABASE İŞLEMLERİ (CONFIRM ACTIONS)
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleCardConfirm(AIActionCardData card) async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    final kullaniciId = userModel?.uid ?? '';
    final servisi = FirestoreServisi(kullaniciId: kullaniciId);

    switch (card.type) {
      case AIActionType.addWorker:
        final name = (card.data['ad'] ?? card.data['name'] ?? '').toString().trim();
        final isciTuru = (card.data['isciTuru'] ?? 'Çekirdek Ekip').toString();
        final wage = (card.data['gunlukMaas'] ?? card.data['wage'] is num)
            ? ((card.data['gunlukMaas'] ?? card.data['wage']) as num).toDouble()
            : (double.tryParse('${card.data['gunlukMaas'] ?? card.data['wage']}') ?? 0.0);

        if (name.isEmpty) {
          throw Exception('Personel adı boş olamaz.');
        }

        final isci = Isci(
          ad: name,
          isciTuru: isciTuru,
          gunlukMaas: wage,
        );

        await servisi.isciEkle(widget.teamId, isci);
        break;

      case AIActionType.addPayment:
        final workerId = (card.data['worker_id'] ?? '').toString();
        final workerName = (card.data['worker'] ?? '').toString().trim();
        final amount = (card.data['miktar'] ?? card.data['amount'] is num)
            ? ((card.data['miktar'] ?? card.data['amount']) as num).toDouble()
            : (double.tryParse('${card.data['miktar'] ?? card.data['amount']}') ?? 0.0);

        if (amount <= 0) {
          throw Exception('Geçerli bir avans tutarı belirtilmelidir.');
        }

        Isci? targetWorker;
        if (workerId.isNotEmpty) {
          for (final isci in widget.isciler) {
            if (isci.id == workerId) {
              targetWorker = isci;
              break;
            }
          }
        }
        if (targetWorker == null && workerName.isNotEmpty) {
          for (final isci in widget.isciler) {
            if (isci.ad.toLowerCase() == workerName.toLowerCase()) {
              targetWorker = isci;
              break;
            }
          }
        }

        if (targetWorker == null) {
          throw Exception('Lütfen ekip listenizden geçerli bir personel seçin.');
        }

        await servisi.avansEkle(
          widget.teamId,
          VerilenAvans(
            miktar: amount,
            isci: targetWorker,
            tarih: DateTime.now(),
          ),
        );
        break;

      case AIActionType.submitDailyLog:
        final santiyeId = card.data['santiye_id']?.toString();
        final santiyeAdi = card.data['santiyeAdi'] ?? card.data['site']?.toString();

        Santiye? santiye;
        if (santiyeId != null && santiyeId.isNotEmpty) {
          for (final s in widget.santiyeler) {
            if (s.id == santiyeId) {
              santiye = s;
              break;
            }
          }
        }
        if (santiye == null && santiyeAdi != null && santiyeAdi.isNotEmpty) {
          for (final s in widget.santiyeler) {
            if (s.ad.toLowerCase() == santiyeAdi.toLowerCase()) {
              santiye = s;
              break;
            }
          }
        }
        santiye ??= (widget.santiyeler.isNotEmpty ? widget.santiyeler.first : null);

        if (santiye == null) {
          throw Exception('İşlemin atanacağı bir şantiye bulunamadı. Lütfen önce bir şantiye oluşturun.');
        }

        final isciDurumlari = (card.data['isci_durumlari'] is Map)
            ? Map<String, String>.from(card.data['isci_durumlari'])
            : <String, String>{};

        final calisanlarList = <GunlukCalisma>[];
        for (final isci in widget.isciler) {
          final key = isci.id ?? isci.ad;
          final durum = isciDurumlari[key] ?? isciDurumlari[isci.ad];
          if (durum != null && durum != 'Gelmedi' && durum != 'Yok') {
            calisanlarList.add(GunlukCalisma(
              isci: isci,
              durum: durum,
            ));
          }
        }

        final yemek = (card.data['yemekGideri'] ?? card.data['yemek'] is num)
            ? ((card.data['yemekGideri'] ?? card.data['yemek']) as num).toDouble()
            : (double.tryParse('${card.data['yemekGideri'] ?? card.data['yemek']}') ?? 0.0);
        final benzin = (card.data['benzinGideri'] ?? card.data['benzin'] is num)
            ? ((card.data['benzinGideri'] ?? card.data['benzin']) as num).toDouble()
            : (double.tryParse('${card.data['benzinGideri'] ?? card.data['benzin']}') ?? 0.0);
        final ekMasraf = (card.data['ekMasraflar'] ?? card.data['ek_masraf'] is num)
            ? ((card.data['ekMasraflar'] ?? card.data['ek_masraf']) as num).toDouble()
            : (double.tryParse('${card.data['ekMasraflar'] ?? card.data['ek_masraf']}') ?? 0.0);
        final aciklama = (card.data['aciklama'] ?? 'ŞPD AI ile oluşturuldu.').toString();

        final bugun = DateTime.now();
        final gunTarih = DateTime(bugun.year, bugun.month, bugun.day);

        final yeniRapor = GunlukSantiyeRaporu(
          santiyeAdi: santiye.ad,
          tarih: gunTarih,
          benzinGideri: benzin,
          yemekGideri: yemek,
          ekMasraflar: ekMasraf,
          aciklama: aciklama,
          calisanlar: calisanlarList,
        );

        await servisi.raporKaydet(widget.teamId, yeniRapor);
        break;

      case AIActionType.addSite:
        final siteName = (card.data['ad'] ?? card.data['name'] ?? '').toString().trim();
        final il = (card.data['il'] ?? card.data['city'] ?? '').toString().trim();
        final ilce = (card.data['ilce'] ?? '').toString().trim();

        if (siteName.isEmpty) {
          throw Exception('Şantiye adı boş olamaz.');
        }

        final santiye = Santiye(
          ad: siteName,
          il: il.isNotEmpty ? il : null,
          ilce: ilce.isNotEmpty ? ilce : null,
        );

        await servisi.santiyeEkle(widget.teamId, santiye);
        break;

      case AIActionType.siteMonthlySummary:
      case AIActionType.workerMonthlySummary:
        return;
    }

    if (mounted) {
      setState(() {
        _messages.add(
          AIChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: '✅ **${card.title}** işlemi başarıyla kaydedildi!',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _openEditModal(AIActionCardData card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return _buildEditSheet(card, isDark, ctx);
      },
    );
  }

  Widget _buildEditSheet(AIActionCardData card, bool isDark, BuildContext ctx) {
    // Form controller'ları ve durumları
    final nameCtrl = TextEditingController(
      text: (card.data['ad'] ?? card.data['name'] ?? '').toString(),
    );
    String selectedIsciTuru = (card.data['isciTuru'] ?? 'Çekirdek Ekip').toString();
    final wageCtrl = TextEditingController(
      text: (card.data['gunlukMaas'] ?? card.data['wage'] ?? 1500).toString(),
    );

    // Avans için
    String? selectedWorkerId;
    if (card.type == AIActionType.addPayment) {
      final wId = card.data['worker_id']?.toString();
      final wName = card.data['worker']?.toString().toLowerCase();
      if (wId != null && widget.isciler.any((i) => i.id == wId)) {
        selectedWorkerId = wId;
      } else if (wName != null && widget.isciler.any((i) => i.ad.toLowerCase() == wName)) {
        selectedWorkerId = widget.isciler.firstWhere((i) => i.ad.toLowerCase() == wName).id;
      } else if (widget.isciler.isNotEmpty) {
        selectedWorkerId = widget.isciler.first.id ?? widget.isciler.first.ad;
      }
    }
    final paymentAmountCtrl = TextEditingController(
      text: (card.data['miktar'] ?? card.data['amount'] ?? 500).toString(),
    );

    // Günlük Rapor için
    String? selectedSiteId;
    if (card.type == AIActionType.submitDailyLog) {
      final sId = card.data['santiye_id']?.toString();
      final sAdi = (card.data['santiyeAdi'] ?? card.data['site'])?.toString().toLowerCase();
      if (sId != null && widget.santiyeler.any((s) => s.id == sId)) {
        selectedSiteId = sId;
      } else if (sAdi != null && widget.santiyeler.any((s) => s.ad.toLowerCase() == sAdi)) {
        selectedSiteId = widget.santiyeler.firstWhere((s) => s.ad.toLowerCase() == sAdi).id;
      } else if (widget.santiyeler.isNotEmpty) {
        selectedSiteId = widget.santiyeler.first.id;
      }
    }
    final Map<String, String> tempIsciDurumlari = {};
    if (card.data['isci_durumlari'] is Map) {
      for (final entry in (card.data['isci_durumlari'] as Map).entries) {
        tempIsciDurumlari[entry.key.toString()] = entry.value.toString();
      }
    }
    for (final isci in widget.isciler) {
      final key = isci.id ?? isci.ad;
      if (!tempIsciDurumlari.containsKey(key) && !tempIsciDurumlari.containsKey(isci.ad)) {
        tempIsciDurumlari[key] = 'Tam Gün';
      }
    }

    final yemekCtrl = TextEditingController(
      text: (card.data['yemekGideri'] ?? card.data['yemek'] ?? 0).toString(),
    );
    final benzinCtrl = TextEditingController(
      text: (card.data['benzinGideri'] ?? card.data['benzin'] ?? 0).toString(),
    );
    final ekMasrafCtrl = TextEditingController(
      text: (card.data['ekMasraflar'] ?? card.data['ek_masraf'] ?? 0).toString(),
    );
    final aciklamaCtrl = TextEditingController(
      text: (card.data['aciklama'] ?? 'ŞPD AI ile oluşturuldu.').toString(),
    );

    // Şantiye için
    final siteNameCtrl = TextEditingController(
      text: (card.data['ad'] ?? card.data['name'] ?? '').toString(),
    );
    final siteCityCtrl = TextEditingController(
      text: (card.data['il'] ?? card.data['city'] ?? 'İstanbul').toString(),
    );
    final siteIlceCtrl = TextEditingController(
      text: (card.data['ilce'] ?? '').toString(),
    );

    return StatefulBuilder(
      builder: (context, setModalState) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: EdgeInsets.only(
              top: 18,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_note, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${card.title} - Düzenle',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── 1. PERSONEL EKLEME DÜZENLEME ───
                  if (card.type == AIActionType.addWorker) ...[
                    _buildLabel('👤 Personel Adı Soyadı', isDark),
                    _buildTextInput(
                      controller: nameCtrl,
                      hint: 'Örn: Ahmet Usta',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('🏷️ Ekip Türü', isDark),
                    Row(
                      children: ['Çekirdek Ekip', 'Misafir'].map((tur) {
                        final isSelected = selectedIsciTuru == tur;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  tur,
                                  style: GoogleFonts.poppins(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF10B981),
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedIsciTuru = tur);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('💵 Günlük Maaş / Yevmiye (₺)', isDark),
                    _buildTextInput(
                      controller: wageCtrl,
                      hint: '1500',
                      isDark: isDark,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],

                  // ─── 2. AVANS / ÖDEME DÜZENLEME (LİSTEDEN İŞÇİ SEÇİMİ) ───
                  if (card.type == AIActionType.addPayment) ...[
                    _buildLabel('👷 Personel Seçimi (Ekip Listesinden)', isDark),
                    if (widget.isciler.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Ekibinizde henüz kayıtlı personel bulunmuyor. Önce personel ekleyebilirsiniz.',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.amber[800]),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedWorkerId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: widget.isciler.map((i) {
                              final id = i.id ?? i.ad;
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Row(
                                  children: [
                                    Text(
                                      i.ad,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        i.isciTuru,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedWorkerId = val);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _buildLabel('💰 Avans Tutarı (₺)', isDark),
                    _buildTextInput(
                      controller: paymentAmountCtrl,
                      hint: '500',
                      isDark: isDark,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],

                  // ─── 3. GÜNLÜK RAPOR & PUANTAJ (LİSTEDEN ŞANTİYE VE İŞÇİ PUANTAJI) ───
                  if (card.type == AIActionType.submitDailyLog) ...[
                    _buildLabel('🏗️ Şantiye Seçimi', isDark),
                    if (widget.santiyeler.isEmpty)
                      Text(
                        'Kayıtlı şantiye bulunamadı. Lütfen önce şantiye ekleyin.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.redAccent),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSiteId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: widget.santiyeler.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text(
                                  s.ad,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedSiteId = val);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('👥 Personel Puantajı', isDark),
                        if (widget.isciler.isNotEmpty)
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    for (var isci in widget.isciler) {
                                      final k = isci.id ?? isci.ad;
                                      tempIsciDurumlari[k] = 'Tam Gün';
                                      tempIsciDurumlari[isci.ad] = 'Tam Gün';
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Hepsi Tam',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  setModalState(() {
                                    for (var isci in widget.isciler) {
                                      final k = isci.id ?? isci.ad;
                                      tempIsciDurumlari[k] = 'Yarım Gün';
                                      tempIsciDurumlari[isci.ad] = 'Yarım Gün';
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Hepsi Yarım',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (widget.isciler.isEmpty)
                      Text(
                        'Ekipte işçi bulunamadı.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: widget.isciler.map((isci) {
                            final key = isci.id ?? isci.ad;
                            final rawStatus = tempIsciDurumlari[key] ?? tempIsciDurumlari[isci.ad] ?? 'Tam Gün';
                            final currentStatus = (rawStatus == 'Gelmedi' || rawStatus == 'İzinli') ? 'Yok' : rawStatus;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEDF2F7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          isci.ad,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${isci.isciTuru})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // Tam Gün
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              setModalState(() {
                                                tempIsciDurumlari[key] = 'Tam Gün';
                                                tempIsciDurumlari[isci.ad] = 'Tam Gün';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: currentStatus == 'Tam Gün'
                                                    ? const Color(0xFF10B981)
                                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: currentStatus == 'Tam Gün'
                                                      ? const Color(0xFF10B981)
                                                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Tam',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: currentStatus == 'Tam Gün' ? FontWeight.w600 : FontWeight.w500,
                                                  color: currentStatus == 'Tam Gün' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Yarım Gün
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              setModalState(() {
                                                tempIsciDurumlari[key] = 'Yarım Gün';
                                                tempIsciDurumlari[isci.ad] = 'Yarım Gün';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: currentStatus == 'Yarım Gün'
                                                    ? Colors.orange
                                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: currentStatus == 'Yarım Gün'
                                                      ? Colors.orange
                                                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Yarım',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: currentStatus == 'Yarım Gün' ? FontWeight.w600 : FontWeight.w500,
                                                  color: currentStatus == 'Yarım Gün' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Yok
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              setModalState(() {
                                                tempIsciDurumlari[key] = 'Yok';
                                                tempIsciDurumlari[isci.ad] = 'Yok';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: currentStatus == 'Yok'
                                                    ? Colors.grey
                                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: currentStatus == 'Yok'
                                                      ? Colors.grey
                                                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Yok',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: currentStatus == 'Yok' ? FontWeight.w600 : FontWeight.w500,
                                                  color: currentStatus == 'Yok' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _buildLabel('💸 Giderler (TL)', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextInput(
                            controller: yemekCtrl,
                            hint: 'Yemek ₺',
                            isDark: isDark,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextInput(
                            controller: benzinCtrl,
                            hint: 'Benzin ₺',
                            isDark: isDark,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextInput(
                            controller: ekMasrafCtrl,
                            hint: 'Ek Masraf ₺',
                            isDark: isDark,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('📝 Açıklama / Not', isDark),
                    _buildTextInput(
                      controller: aciklamaCtrl,
                      hint: 'Açıklama...',
                      isDark: isDark,
                    ),
                  ],

                  // ─── 4. ŞANTİYE EKLEME DÜZENLEME ───
                  if (card.type == AIActionType.addSite) ...[
                    _buildLabel('🏗️ Şantiye Adı', isDark),
                    _buildTextInput(
                      controller: siteNameCtrl,
                      hint: 'Örn: Kadıköy Konutları',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('📍 İl', isDark),
                              _buildTextInput(
                                controller: siteCityCtrl,
                                hint: 'İstanbul',
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('🏘️ İlçe', isDark),
                              _buildTextInput(
                                controller: siteIlceCtrl,
                                hint: 'Kadıköy',
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'İptal',
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () {
                            final updatedData = Map<String, dynamic>.from(card.data);

                            if (card.type == AIActionType.addWorker) {
                              updatedData['ad'] = nameCtrl.text.trim();
                              updatedData['name'] = nameCtrl.text.trim();
                              updatedData['isciTuru'] = selectedIsciTuru;
                              final w = double.tryParse(wageCtrl.text.trim()) ?? 0.0;
                              updatedData['gunlukMaas'] = w;
                              updatedData['wage'] = w;
                            } else if (card.type == AIActionType.addPayment) {
                              Isci? pickedWorker;
                              if (selectedWorkerId != null) {
                                for (var i in widget.isciler) {
                                  if (i.id == selectedWorkerId || i.ad == selectedWorkerId) {
                                    pickedWorker = i;
                                    break;
                                  }
                                }
                              }
                              updatedData['worker_id'] = pickedWorker?.id ?? selectedWorkerId ?? '';
                              updatedData['worker'] = pickedWorker?.ad ?? '';
                              final amt = double.tryParse(paymentAmountCtrl.text.trim()) ?? 0.0;
                              updatedData['amount'] = amt;
                              updatedData['miktar'] = amt;
                            } else if (card.type == AIActionType.submitDailyLog) {
                              Santiye? pickedSite;
                              if (selectedSiteId != null) {
                                for (var s in widget.santiyeler) {
                                  if (s.id == selectedSiteId) {
                                    pickedSite = s;
                                    break;
                                  }
                                }
                              }
                              updatedData['santiye_id'] = pickedSite?.id ?? selectedSiteId ?? '';
                              updatedData['site'] = pickedSite?.ad ?? '';
                              updatedData['santiyeAdi'] = pickedSite?.ad ?? '';
                              updatedData['isci_durumlari'] = tempIsciDurumlari;
                              final ym = double.tryParse(yemekCtrl.text.trim()) ?? 0.0;
                              final bz = double.tryParse(benzinCtrl.text.trim()) ?? 0.0;
                              final ek = double.tryParse(ekMasrafCtrl.text.trim()) ?? 0.0;
                              updatedData['yemek'] = ym;
                              updatedData['yemekGideri'] = ym;
                              updatedData['benzin'] = bz;
                              updatedData['benzinGideri'] = bz;
                              updatedData['ek_masraf'] = ek;
                              updatedData['ekMasraflar'] = ek;
                              final calisanSayisi = tempIsciDurumlari.values.where((v) => v != 'Yok' && v != 'Gelmedi').length;
                              final tamSayisi = tempIsciDurumlari.values.where((v) => v == 'Tam Gün').length;
                              final yarimSayisi = tempIsciDurumlari.values.where((v) => v == 'Yarım Gün').length;
                              updatedData['workers_summary'] = calisanSayisi > 0
                                  ? '$calisanSayisi Çalışan ($tamSayisi Tam, $yarimSayisi Yarım)'
                                  : 'Çalışan yok';
                              updatedData['expenses_summary'] = [
                                if (ym > 0) 'Yemek: $ym ₺',
                                if (bz > 0) 'Benzin: $bz ₺',
                                if (ek > 0) 'Ek Masraf: $ek ₺',
                              ].join(', ');
                            } else if (card.type == AIActionType.addSite) {
                              updatedData['ad'] = siteNameCtrl.text.trim();
                              updatedData['name'] = siteNameCtrl.text.trim();
                              updatedData['il'] = siteCityCtrl.text.trim();
                              updatedData['city'] = siteCityCtrl.text.trim();
                              updatedData['ilce'] = siteIlceCtrl.text.trim();
                            }

                            Navigator.pop(ctx);
                            final updatedCard = card.copyWith(data: updatedData);
                            _handleCardConfirm(updatedCard);
                          },
                          child: Text(
                            'Kaydet & Onayla',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        fontSize: 13.5,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: isDark ? Colors.white38 : Colors.grey[400],
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF10B981),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
      ),
    );
  }

  void _openHelpGuide() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ŞPD Aİ Rehberi',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Kalan kullanım hakkı: $_remainingAiQuota',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _helpItem(
                  '👷 Personel Ekleme',
                  '"Yeni usta ekle adı Ahmet Kaya yevmiyesi 2200 TL"',
                ),
                _helpItem(
                  '💰 Avans / Ödeme',
                  '"Ali ustaya 3000 TL elden avans verdim"',
                ),
                _helpItem(
                  '📋 Günlük Puantaj',
                  '"Merkez şantiyede Ali tam gün Veli yarım gün çalıştı 600 TL yemek"',
                ),
                _helpItem(
                  '🏗️ Şantiye Açma',
                  '"Yeni şantiye ekle Kadıköy Konutları İstanbul"',
                ),
                _helpItem(
                  '🔍 Bilgi ve Rapor',
                  '"Ahmet\'in bu ay kaç yevmiyesi var?" veya serbest sorular!',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tamam',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _helpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // KALAN AI SORU HAKKI BİLGİ DİYALOĞU (POPUP)
  // ─────────────────────────────────────────────────────────────
  void _showQuotaInfoDialog(bool isDark) {
    _loadQuota();
    showDialog(
      context: context,
      builder: (ctx) {
        final percent = (_remainingAiQuota / 10.0).clamp(0.0, 1.0);
        final isLow = _remainingAiQuota <= 2;
        final statusColor = isLow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Parlayan Rozet
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor,
                      statusColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Başlık
              Text(
                'Günlük AI Soru Hakkınız',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Yapay Zekâ Soru Kotası',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // Kalan Hak Kartı ve İlerleme Çubuğu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        children: [
                          TextSpan(
                            text: '$_remainingAiQuota',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          TextSpan(
                            text: ' / 10 ',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(
                            text: 'Soru Kaldı',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 7,
                        backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bilgilendirici Maddeler
              _quotaInfoItem(
                Icons.restore_rounded,
                'Her Gece Sıfırlanır',
                'Günlük 10 soru hakkınız her gece saat 00:00\'da otomatik olarak yenilenir.',
                isDark,
              ),
              const SizedBox(height: 10),
              _quotaInfoItem(
                Icons.verified_rounded,
                'Şantiye İşlemleri Sınırsız',
                'Puantaj işleme, hakediş hesaplama ve rapor alma komutları bu haktan düşmez, tamamen sınırsızdır.',
                isDark,
              ),
              const SizedBox(height: 18),

              // Anladım Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Anladım',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quotaInfoItem(IconData icon, String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BAR KALAN HAK ROZETİ (TIKLANABİLİR)
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuotaBadge(bool isDark) {
    final isLow = _remainingAiQuota <= 2;
    final color = isLow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showQuotaInfoDialog(isDark),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '$_remainingAiQuota/10',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD SCREEN
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Uygulamamızın standart ekran arka plan rengi
    final screenBgColor = isDark ? const Color(0xFF0C1219) : const Color(0xFFF0F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: Stack(
        children: [
          // 1. Üst Ambiyans Işıltısı (Uygulamanın Teal/Emerald Parıltısı)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.4),
                    radius: 0.9,
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: isDark ? 0.16 : 0.22),
                      const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.08 : 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Alt Ambiyans Aura Parıltısı (Mikrofonla konuşurken ve klavyede canlanan ışıma)
          Positioned(
            bottom: -30,
            left: 0,
            right: 0,
            height: _isListening ? 310 : 210,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 1.0),
                    radius: _isListening ? 1.2 : 0.8,
                    colors: [
                      const Color(0xFF10B981).withValues(
                        alpha: isDark ? (_isListening ? 0.28 : 0.10) : (_isListening ? 0.32 : 0.14),
                      ),
                      const Color(0xFF06B6D4).withValues(
                        alpha: isDark ? (_isListening ? 0.18 : 0.05) : (_isListening ? 0.20 : 0.08),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Klavyenin Tam Üstünden "Bir Şeyler Yaz" ve Baloncuklara Doğru Yukarı Atan Mistik Dalgalar (Aura Mesh)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: MysticalWaves(
                key: _bottomWavesKey,
                height: 150,
                animationDuration: const Duration(milliseconds: 350),
                waveDuration: const Duration(seconds: 3),
                waveColors: [
                  const Color(0xFF10B981).withValues(alpha: 0.65), // Emerald
                  const Color(0xFF06B6D4).withValues(alpha: 0.55), // Cyan
                  const Color(0xFF34D399).withValues(alpha: 0.40), // Mint
                ],
              ),
            ),
          ),

          // 3. İçerik ve Arayüz Katmanı
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Bar (Eski ekrandaki gibi Geri Tuşu + "ŞPD Aİ" Kapsülü + Ayar Butonu)
                _buildTopBar(isDark),

                // Gövde Alanı: Karşılama Ekranı ya da Mesajlar
                Expanded(
                  child: _messages.isEmpty
                      ? _buildHeroWelcomeView(isDark)
                      : _buildConversationView(isDark),
                ),

                // Alt Giriş Barı ("Bir şeyler yaz...")
                _buildFloatingInputBar(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP BAR (Geri Tuşu + "ŞPD Aİ" Kapsülü + Ayar Butonu)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol Kısım: Eski Ekrandaki Gibi Geri Tuşu + "ŞPD Aİ" Kapsülü
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Geri Butonu
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161A22)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // "ŞPD Aİ" Kapsülü
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161A22)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Uygulama Renklerinde Zümrüt/Teal Rozet
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: GeminiLogo(
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ŞPD Aİ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sağ Kısım: Kalan Hak Rozeti + Yeni Sohbet (Varsa) + Dairesel Ayar/Rehber Butonu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kalan AI Soru Hakkı Kapsülü (Tıklanabilir)
              _buildQuotaBadge(isDark),
              const SizedBox(width: 6),

              if (_messages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _messages.clear()),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161A22)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),

              // Dairesel Ayar Butonu
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openHelpGuide,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161A22)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 19,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO WELCOME VIEW (Gümüş Yerine "ŞPD Aİ" Başlığı + Karşılama)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroWelcomeView(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // 1. Yukarıdaki Gümüş Yapı Yerine: ŞPD Aİ Sanatsal Merkez Alanı
          _buildSpdAiCenterpiece(isDark),

          const SizedBox(height: 14),

          // 2. Kapsül Rozet: "Akıllı Saha Asistanı"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161A22)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Akıllı Saha Asistanı',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF0D9488),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. İstenen Karşılama Başlığı:
          // "merhaba ustam buguün sana nasıl yardımcı olabilirim"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                children: [
                  const TextSpan(text: 'Merhaba, Ustam!\nBugün sana nasıl\n'),
                  WidgetSpan(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                      ).createShader(bounds),
                      child: Text(
                        'yardımcı olabilirim?',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // 4. 3 Sıralı Yatay Kaydırılabilir Kutu Grupları
          _buildScrollablePromptRows(isDark),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GÜMÜŞ YAPI YERİNE: ŞPD Aİ MERKEZİ SANAT GRAFİĞİ
  // ─────────────────────────────────────────────────────────────
  Widget _buildSpdAiCenterpiece(bool isDark) {
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, child) {
        final float = math.sin(_waveAnimController.value * math.pi) * 6.0;

        return Transform.translate(
          offset: Offset(0, float),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF161A22),
                        const Color(0xFF102820),
                        const Color(0xFF0B1917),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF0FDF4),
                        const Color(0xFFECFEFF),
                      ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gemini Yıldız Rozeti
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: GeminiLogo(
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Büyük "ŞPD Aİ" Başlığı
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  ).createShader(bounds),
                  child: Text(
                    'ŞPD Aİ',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),

                // Alt Açıklama
                Text(
                  'Aylık Raporlar, Puantaj, Hakediş & Şantiye Asistanı',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3 SIRALI YATAY KAYDIRILABİLİR KUTULAR (UYGULAMA RENKLERİYLE)
  // ─────────────────────────────────────────────────────────────
  Widget _buildScrollablePromptRows(bool isDark) {
    return Column(
      children: [
        // Satır 1: Şantiye & İşçi Aylık Özetleri (Aylık Durum, Hakediş, Bakiye)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 20, bottom: 10),
          child: Row(
            children: [
              _buildPromptPill(
                icon: Icons.analytics_rounded,
                iconColor: const Color(0xFF10B981),
                text: 'Şantiyenin bu ayki harcama ve puantaj özeti',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF06B6D4),
                text: 'Ustanın bu ayki hakediş ve avans durumu',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF059669),
                text: 'Bu ay ustaya ne kadar alacak kaldı?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.pie_chart_rounded,
                iconColor: const Color(0xFFF59E0B),
                text: 'Şantiyenin toplam maliyeti ve gider dökümü',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF3B82F6),
                text: 'Usta bu ay toplam kaç gün çalıştı?',
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Satır 2: Günlük Puantaj & Hızlı İşlemler (Kademeli / Offsetli)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 48, right: 20, bottom: 10),
          child: Row(
            children: [
              _buildPromptPill(
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFF10B981),
                text: 'Bugün bütün ekip tam gün çalıştı',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.price_check_rounded,
                iconColor: const Color(0xFF059669),
                text: 'Ahmet ustaya 2.000 ₺ avans verdim',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.local_gas_station_rounded,
                iconColor: const Color(0xFFEF4444),
                text: 'Bugün 850 ₺ benzin, 450 ₺ yemek masrafı yaz',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.person_add_alt_1_rounded,
                iconColor: const Color(0xFF06B6D4),
                text: 'Ali ustayı 1.500 ₺ yevmiye ile ekle',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.apartment_rounded,
                iconColor: const Color(0xFF8B5CF6),
                text: 'Kadıköy Konakları şantiyesini ekle',
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Satır 3: Akıllı Metraj & Malzeme Hesaplayıcı (Çevrimdışı Mühendislik Motoru)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 36, right: 20, bottom: 10),
          child: Row(
            children: [
              _buildPromptPill(
                icon: Icons.square_foot_rounded,
                iconColor: const Color(0xFFF59E0B),
                text: '350 m² tabliyeye 15 cm C30 beton kaç mikser gider?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.view_in_ar_rounded,
                iconColor: const Color(0xFFEF4444),
                text: '120 m² duvara 13.5 tuğla öreceğiz, kaç adet tuğla ve harç lazım?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.grid_view_rounded,
                iconColor: const Color(0xFF06B6D4),
                text: '80 m² alana seramik döşemek için kaç paket ve yapıştırıcı lazım?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF10B981),
                text: '150 m2 daireye 5 cm şap atacağız, ne kadar kum ve çimento gerekir?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.agriculture_rounded,
                iconColor: const Color(0xFF8B5CF6),
                text: '400 m2 arsada 2.5m temel kazısı kaç kamyon hafriyat çıkar?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.home_work_rounded,
                iconColor: const Color(0xFFEC4899),
                text: '300 m2 dış cepheye mantolama ne kadar strafor ve file tutar?',
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Satır 4: Teknik Mühendislik & Danışmanlık
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 6),
          child: Row(
            children: [
              _buildPromptPill(
                icon: Icons.engineering_rounded,
                iconColor: const Color(0xFF0D9488),
                text: 'Beton dökümü öncesi nelere dikkat edilmeli?',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFFE11D48),
                text: 'Şantiye iş güvenliği ve risk kontrol listesi',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.straighten_rounded,
                iconColor: const Color(0xFF06B6D4),
                text: 'Demir donatı bindirme ve paspayı kuralları',
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildPromptPill(
                icon: Icons.science_rounded,
                iconColor: const Color(0xFF10B981),
                text: 'C30 beton dayanımı ve priz alma süreleri',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Beyaz / Koyu Cam Kart Kapsülü
  Widget _buildPromptPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSendText(text),
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161A22).withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.85),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sol Yuvarlak Renkli İkon Rozeti
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 14,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Metin
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF1E293B),
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

  // ─────────────────────────────────────────────────────────────
  // CONVERSATION VIEW (Mesajlar Aktifken)
  // ─────────────────────────────────────────────────────────────
  Widget _buildConversationView(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _messages.length + (_isProcessing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isProcessing) {
                return _buildTypingIndicator(isDark);
              }
              final msg = _messages[index];
              return _buildMessageItem(msg, isDark);
            },
          ),
        ),

        // Sohbet sırasında da hızlı öneriler
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildMiniPromptChip('📊 Şantiye Aylık Özeti', isDark),
              const SizedBox(width: 8),
              _buildMiniPromptChip('👤 Personel Hakediş Özeti', isDark),
              const SizedBox(width: 8),
              _buildMiniPromptChip('💰 Avans Verdim', isDark),
              const SizedBox(width: 8),
              _buildMiniPromptChip('📝 Bugünkü Puantajı İşle', isDark),
              const SizedBox(width: 8),
              _buildMiniPromptChip('👷 Yeni Usta Ekle', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPromptChip(String text, bool isDark) {
    return InkWell(
      onTap: () => _handleSendText(text.replaceFirst(RegExp(r'^[^\s]+\s'), '')),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161A22).withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(AIChatMessage msg, bool isDark) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }

    // AI Mesajı
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                (msg.actionCard != null ? 0.94 : 0.85),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: msg.actionCard != null ? 10 : 14,
            vertical: msg.actionCard != null ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 10),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ŞPD Aİ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                msg.text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (msg.actionCard != null)
                AIActionCardWidget(
                  cardData: msg.actionCard!,
                  onConfirm: _handleCardConfirm,
                  onEdit: () => _openEditModal(msg.actionCard!),
                  isDark: isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ŞPD Aİ düşünüyor...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FLOATING GİRİŞ KAPSÜLÜ ("Bir şeyler yaz...")
  // ─────────────────────────────────────────────────────────────
  Widget _buildFloatingInputBar(bool isDark) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161A22).withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? (_isProcessing
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.14))
                    : (_isProcessing
                        ? const Color(0xFF10B981).withValues(alpha: 0.55)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
                width: _isProcessing ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isProcessing
                      ? const Color(0xFF10B981).withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: _isProcessing ? 22 : 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Metin Giriş Alanı: İstenen "Bir şeyler yaz..." Placeholder'ı
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: (text) {
                      _bottomWavesKey.currentState?.pulse();
                    },
                    onTap: () {
                      _bottomWavesKey.currentState?.pulse();
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Dinliyorum, konuşun...'
                          : 'Bir şeyler yaz...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: _isListening
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white38 : Colors.grey[400]),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _handleSendText,
                  ),
                ),
                const SizedBox(width: 6),

                // Uygulama Renklerinde Zümrüt/Teal Gradient Buton (Mikrofon / Gönder)
                InkWell(
                  onTap: () {
                    if (hasText) {
                      _handleSendText(_textController.text);
                    } else {
                      _toggleListening();
                    }
                  },
                  borderRadius: BorderRadius.circular(26),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                              .withValues(alpha: 0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasText
                          ? Icons.arrow_upward_rounded
                          : (_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                      color: Colors.white,
                      size: 20,
                    ),
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
