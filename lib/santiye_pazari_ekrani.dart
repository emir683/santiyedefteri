import 'package:cloud_firestore/cloud_firestore.dart';
import 'tema_ayarlari.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bildirim_servisi.dart';
import 'data/turkiye_il_ilce.dart';
import 'firestore_servisi.dart';
import 'format_yardimcisi.dart';
import 'models/kullanici_saha_profili.dart';
import 'widgets/floating_liquid_app_bar.dart';
import 'widgets/glass_surface.dart';

class SantiyePazariEkrani extends StatefulWidget {
  final String teamId;
  final int baslangicSekmesi; // 0: İlanlar, 1: Profilim
  final bool gomuluMod;
  final VoidCallback? onEkibeAktarildi;

  const SantiyePazariEkrani({
    super.key,
    required this.teamId,
    this.baslangicSekmesi = 0,
    this.gomuluMod = false,
    this.onEkibeAktarildi,
  });

  @override
  State<SantiyePazariEkrani> createState() => _SantiyePazariEkraniState();
}

class _SantiyePazariEkraniState extends State<SantiyePazariEkrani> {
  Color get _themePrimary => AppTheme.primary(context);
  Color get _themeAccent => AppTheme.accent(context);
  Color get _themeContrastIcon => AppTheme.contrastIcon(context);
  List<Color> get _themeGradient => AppTheme.gradient(context);

  late int _seciliSekme; // 0: İlanlar, 1: Profilim
  int _profilAltSekme = 0; // 0: İlanlarım, 1: Favorilerim, 2: Mesajlarım

  String _seciliKategori =
      'tumu'; // 'tumu' | 'is_ilani' | 'usta_ekip' | 'sirket_vitrini'
  String _seciliInsaatKategorisi =
      'tumu'; // 'kalip_demir', 'kalip', 'demir', 'duz_isci', 'siva', vb.
  String _seciliSehir = 'Tüm Türkiye';
  String _seciliSeviyeFiltre =
      'tumu'; // 'tumu' | 'ekip' | 'usta' | 'normal_isci' | 'operator'
  String _seciliUcretTipiFiltre =
      'tumu'; // 'tumu' | 'metrekare' | 'goturu' | 'gunluk'
  String _seciliProjeTipi =
      'tumu'; // 'tumu' | 'konut' | 'villa' | 'ticari' | 'fabrika' | 'altyapi' | 'tadilat'
  bool _siralaTarihYeniMi = true; // true: En Yeni, false: En Eski

  final TextEditingController _aramaCtrl = TextEditingController();
  String _aramaMetni = '';

  final Set<String> _bildirilenIlanIdleri = {};
  final Set<String> _bildirilenAnlasmaKeyleri = {};

  // Lokal favori önbelleği (anlık UI yanıtı için)
  final Set<String> _yerelFavoriler = {};

  @override
  void initState() {
    super.initState();
    _seciliSekme = widget.baslangicSekmesi.clamp(0, 1);
  }

  @override
  void didUpdateWidget(covariant SantiyePazariEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baslangicSekmesi != widget.baslangicSekmesi) {
      setState(() {
        _seciliSekme = widget.baslangicSekmesi.clamp(0, 1);
      });
    }
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  int get _aktifFiltreSayisi {
    int sayac = 0;
    if (_seciliKategori != 'tumu') sayac++;
    if (_seciliInsaatKategorisi != 'tumu') sayac++;
    if (_seciliSehir != 'Tüm Türkiye') sayac++;
    if (_seciliSeviyeFiltre != 'tumu') sayac++;
    if (_seciliUcretTipiFiltre != 'tumu') sayac++;
    if (_seciliProjeTipi != 'tumu') sayac++;
    return sayac;
  }

  Future<void> _telefonAra(String telefon) async {
    final clean = telefon.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappMesajGonder(String telefon, String baslik) async {
    var clean = telefon.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '9$clean';
    if (!clean.startsWith('90') && clean.length == 10) clean = '90$clean';
    if (clean.isEmpty) return;
    final msg = Uri.encodeComponent(
      'Merhaba, Şantiye Puantaj Defteri uygulamasındaki "$baslik" ilanınız için iletişime geçiyorum.',
    );
    final uri = Uri.parse('https://wa.me/$clean?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _webSitesiAc(String url) async {
    if (url.trim().isEmpty) return;
    var clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    final uri = Uri.tryParse(clean);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _fotografBuyutDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Fotoğraf yüklenemedi',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SantiyePazarIlani> _ornekBaslangicIlanlari() {
    final now = DateTime.now();
    return [
      SantiyePazarIlani(
        id: 'seed_ilan_1',
        olusturanUid: 'seed_muteahhit_1',
        olusturanAd: 'Kuzey Yapı & Taahhüt A.Ş.',
        kullaniciTipi: KullaniciRolu.muteahhit,
        ilanKategorisi: 'is_ilani',
        kategoriKodu: 'siva',
        projeTipi: 'konut',
        sgkDurumu: 'taseron_sozlesmesi',
        arananSeviye: 'ekip',
        ucretTipi: 'metrekare',
        ucretTutari: 420,
        tahminiMetrajVeyaGun: '4.500 m²',
        ekipKisiSayisi: 8,
        konaklamaVarMi: true,
        yemekVarMi: true,
        ulasimServisVarMi: true,
        isgKkdSaglanacakMi: true,
        fazlaMesaiVarMi: true,
        aletEkipmanDurumu: 'santiyeden',
        odemePeriyodu: 'haftalik',
        avansImkaniVarMi: true,
        baslamaTarihiTipi: 'hemen',
        baslik: '48 Dairelik Projeye Metrekare Usulü Sıvacı Ekibi Aranıyor',
        brans: 'Sıva (Kara & Alçı)',
        seviye: 'Taşeron / Ekip Başı',
        sehir: 'İstanbul',
        ilce: 'Başakşehir',
        sirketAdi: 'Kuzey Yapı & Taahhüt A.Ş.',
        kapasiteVeyaUcret: '420 ₺/m²',
        aciklama:
            '4.500 m² alçı ve kara sıva işi için donanımlı ekip aranıyor. Şantiyede koğuş, 3 öğün sıcak yemek ve haftalık düzenli hakediş mevcuttur.',
        telefon: '0532 000 00 00',
        tarih: now.subtract(const Duration(hours: 2)),
        acilMi: true,
        goruntulenmeSayisi: 142,
        favoriSayisi: 19,
      ),
      SantiyePazarIlani(
        id: 'seed_ilan_2',
        olusturanUid: 'seed_muteahhit_2',
        olusturanAd: 'Anadolu Konut İnşaat',
        kullaniciTipi: KullaniciRolu.muteahhit,
        ilanKategorisi: 'is_ilani',
        kategoriKodu: 'duz_isci',
        projeTipi: 'ticari',
        sgkDurumu: 'sgk_yapilacak',
        arananSeviye: 'normal_isci',
        ucretTipi: 'gunluk',
        ucretTutari: 1850,
        tahminiMetrajVeyaGun: 'Sürekli / 6 Ay',
        ekipKisiSayisi: 5,
        konaklamaVarMi: true,
        yemekVarMi: true,
        ulasimServisVarMi: true,
        isgKkdSaglanacakMi: true,
        fazlaMesaiVarMi: true,
        odemePeriyodu: 'aylik',
        baslamaTarihiTipi: 'hemen',
        baslik: 'Şantiye Saha Temizliği ve Malzeme Taşıma İçin Normal İşçi',
        brans: 'Genel Şantiye Düz İşçisi',
        seviye: 'Düz İşçi / Yevmiyeli',
        sehir: 'Ankara',
        ilce: 'Çankaya',
        sirketAdi: 'Anadolu Konut İnşaat',
        kapasiteVeyaUcret: '1.850 ₺/Gün',
        aciklama:
            'Şantiye bünyesinde malzeme sevkiyatı ve kat temizliklerinde çalışacak düz işçiler aranıyor. SGK girişi, öğle yemeği ve şantiye servisi mevcuttur.',
        telefon: '0533 111 22 33',
        tarih: now.subtract(const Duration(hours: 5)),
        acilMi: false,
        goruntulenmeSayisi: 89,
        favoriSayisi: 8,
      ),
      SantiyePazarIlani(
        id: 'seed_ilan_3',
        olusturanUid: 'seed_muteahhit_3',
        olusturanAd: 'Ege Taahhüt Mühendislik',
        kullaniciTipi: KullaniciRolu.muteahhit,
        ilanKategorisi: 'is_ilani',
        kategoriKodu: 'kalip',
        projeTipi: 'konut',
        sgkDurumu: 'taseron_sozlesmesi',
        arananSeviye: 'ekip',
        ucretTipi: 'metrekare',
        ucretTutari: 390,
        tahminiMetrajVeyaGun: '6.000 m²',
        ekipKisiSayisi: 10,
        konaklamaVarMi: true,
        yemekVarMi: true,
        ulasimServisVarMi: false,
        isgKkdSaglanacakMi: true,
        aletEkipmanDurumu: 'santiyeden',
        odemePeriyodu: 'onbes_gunluk',
        avansImkaniVarMi: true,
        baslik: 'Toplu Konut Projesine Sadece Kalıp Ekibi Aranıyor',
        brans: 'Sadece Kalıp (Ahşap & Çelik)',
        seviye: 'Taşeron Ekip',
        sehir: 'İzmir',
        ilce: 'Bornova',
        sirketAdi: 'Ege Taahhüt Mühendislik',
        kapasiteVeyaUcret: '390 ₺/m²',
        aciklama:
            'Perde ve döşeme kalıbı çakacak, projesine uygun çalışacak 8-12 kişilik sadece kalıpçı ekibi aranıyor. Malzeme ve vinç şantiyeden.',
        telefon: '0535 444 55 66',
        tarih: now.subtract(const Duration(hours: 8)),
        acilMi: true,
        goruntulenmeSayisi: 215,
        favoriSayisi: 27,
      ),
      SantiyePazarIlani(
        id: 'seed_ilan_4',
        olusturanUid: 'seed_muteahhit_4',
        olusturanAd: 'Başkent Endüstriyel Yapı',
        kullaniciTipi: KullaniciRolu.muteahhit,
        ilanKategorisi: 'is_ilani',
        kategoriKodu: 'demir',
        projeTipi: 'fabrika',
        sgkDurumu: 'sgk_yapilacak',
        arananSeviye: 'ekip',
        ucretTipi: 'goturu',
        ucretTutari: 650000,
        tahminiMetrajVeyaGun: '240 Ton Demir',
        ekipKisiSayisi: 6,
        konaklamaVarMi: true,
        yemekVarMi: true,
        odemePeriyodu: 'haftalik',
        baslik: 'Fabrika Radye Temel & Kolon Donatısı İçin Sadece Demir Ekibi',
        brans: 'Sadece Demir Bağlama',
        seviye: 'Demirci Ekibi',
        sehir: 'Kocaeli',
        ilce: 'Gebze',
        sirketAdi: 'Başkent Endüstriyel Yapı',
        kapasiteVeyaUcret: '650.000 ₺ Toplam',
        aciklama:
            '240 ton donatı demiri büküm ve bağlama işi için sadece demir ustalarından oluşan ekip arıyoruz.',
        telefon: '0536 777 88 99',
        tarih: now.subtract(const Duration(hours: 12)),
        acilMi: true,
        goruntulenmeSayisi: 174,
        favoriSayisi: 22,
      ),
      SantiyePazarIlani(
        id: 'seed_ilan_5',
        olusturanUid: 'seed_ekip_1',
        olusturanAd: 'Usta Mehmet Demir & Ekibi',
        kullaniciTipi: KullaniciRolu.taseronKalfa,
        ilanKategorisi: 'usta_ekip',
        kategoriKodu: 'kalip_demir',
        arananSeviye: 'ekip',
        ucretTipi: 'metrekare',
        ucretTutari: 440,
        tahminiMetrajVeyaGun: 'Aylık 3.500 m²',
        ekipKisiSayisi: 7,
        konaklamaVarMi: true,
        yemekVarMi: false,
        aletEkipmanDurumu: 'ustadan',
        deneyimYili: '10+ Yıl',
        belgeGerekliMi: true,
        baslik: '7 Kişilik Tecrübeli Kalıp & Demir Ekibi Boşta',
        brans: 'Kalıp & Demir (Birlikte)',
        seviye: 'Ekip Başı',
        sehir: 'Bursa',
        ilce: 'Nilüfer',
        sirketAdi: '',
        kapasiteVeyaUcret: '440 ₺/m²',
        aciklama:
            'Kendi el aletlerimiz, vibratör ve lazer hizalamamızla anahtar teslim kaba yapı kalıp ve demir işi alıyoruz.',
        telefon: '0544 222 33 44',
        tarih: now.subtract(const Duration(days: 1)),
        acilMi: true,
        goruntulenmeSayisi: 310,
        favoriSayisi: 45,
      ),
      SantiyePazarIlani(
        id: 'seed_ilan_6',
        olusturanUid: 'seed_sirket_1',
        olusturanAd: 'Kuzey İskele & Kalıp Sistemleri A.Ş.',
        kullaniciTipi: KullaniciRolu.muteahhit,
        ilanKategorisi: 'sirket_vitrini',
        kategoriKodu: 'iskele',
        arananSeviye: 'ekip',
        ucretTipi: 'metrekare',
        ucretTutari: 45,
        tahminiMetrajVeyaGun: '20.000 m² Stok',
        ekipKisiSayisi: 15,
        konaklamaVarMi: false,
        yemekVarMi: false,
        sirketAdi: 'Kuzey İskele & Kalıp A.Ş.',
        kapasiteVeyaUcret: '20.000 m² Flanşlı İskele',
        baslik: 'Kiralık Güvenlikli Dış Cephe İskelesi & Kurulum Ekibi',
        brans: 'İskele Kurulum & Söküm',
        seviye: 'Kurumsal Şirket',
        sehir: 'İstanbul',
        ilce: 'Tuzla',
        aciklama:
            'TSE belgeli flanşlı güvenlikli iskele kiralama ve profesyonel sertifikalı montaj-söküm ekiplerimizle Türkiye geneli hizmet vermekteyiz.',
        telefon: '0216 444 00 11',
        tarih: now.subtract(const Duration(days: 2)),
        acilMi: false,
        goruntulenmeSayisi: 420,
        favoriSayisi: 61,
      ),
    ];
  }

  /// Arama Modalı (Overflow-free)
  Future<void> _aramaModalAc(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: PanelGlassWidgets.buildModalSheet(
            context: ctx,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PanelGlassWidgets.buildIconBadge(
                      context: ctx,
                      icon: Icons.search_rounded,
                      accentColor: _themeContrastIcon,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'İlanlarda Ara',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF102A43),
                        ),
                      ),
                    ),
                    if (_aramaMetni.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _aramaCtrl.clear();
                            _aramaMetni = '';
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text('Temizle'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                PanelGlassWidgets.buildInset(
                  context: ctx,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: TextField(
                    controller: _aramaCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _aramaMetni = v),
                    decoration: InputDecoration(
                      hintText:
                          'Sadece kalıp, düz işçi, sıvacı, demir, m² veya il...',
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _themeContrastIcon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Sonuçları Göster',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Filtreler Modalı (Overflow-free)
  Future<void> _filtreModalAc(BuildContext context) async {
    final ilAdlari = [
      'Tüm Türkiye',
      ...TurkiyeIlIlce.iller.map((e) => e['il'] as String),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: PanelGlassWidgets.buildModalSheet(
                context: context,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          PanelGlassWidgets.buildIconBadge(
                            context: context,
                            icon: Icons.tune_rounded,
                            accentColor: _themeContrastIcon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pazar Filtreleri',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _seciliKategori = 'tumu';
                                _seciliInsaatKategorisi = 'tumu';
                                _seciliSehir = 'Tüm Türkiye';
                                _seciliSeviyeFiltre = 'tumu';
                                _seciliUcretTipiFiltre = 'tumu';
                                _seciliProjeTipi = 'tumu';
                              });
                              setState(() {});
                            },
                            child: Text('Sıfırla'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // İlan Türü
                      Text(
                        'İlan Türü (Kimden)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFilterChoiceChip(
                            label: 'Tümü',
                            selected: _seciliKategori == 'tumu',
                            onTap: () {
                              setModalState(() => _seciliKategori = 'tumu');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'İş İlanları (İş Veren)',
                            selected: _seciliKategori == 'is_ilani',
                            onTap: () {
                              setModalState(() => _seciliKategori = 'is_ilani');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Ustalar & Ekipler (İş Arayan)',
                            selected: _seciliKategori == 'usta_ekip',
                            onTap: () {
                              setModalState(
                                () => _seciliKategori = 'usta_ekip',
                              );
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Şirketler & Ekipman',
                            selected: _seciliKategori == 'sirket_vitrini',
                            onTap: () {
                              setModalState(
                                () => _seciliKategori = 'sirket_vitrini',
                              );
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // İnşaat İş Kolları & Branş Kategorileri
                      Text(
                        'İnşaat Kategorisi / İş Kolu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFilterChoiceChip(
                            label: 'Tüm Kategoriler',
                            selected: _seciliInsaatKategorisi == 'tumu',
                            onTap: () {
                              setModalState(
                                () => _seciliInsaatKategorisi = 'tumu',
                              );
                              setState(() {});
                            },
                          ),
                          ...InsaatKategorileri.tumu.map(
                            (kat) => _buildFilterChoiceChip(
                              label: kat['baslik'] as String,
                              selected: _seciliInsaatKategorisi == kat['id'],
                              onTap: () {
                                setModalState(
                                  () =>
                                      _seciliInsaatKategorisi =
                                          kat['id'] as String,
                                );
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Proje Tipi
                      Text(
                        'Proje Tipi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFilterChoiceChip(
                            label: 'Tüm Projeler',
                            selected: _seciliProjeTipi == 'tumu',
                            onTap: () {
                              setModalState(() => _seciliProjeTipi = 'tumu');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Konut / Toplu Konut',
                            selected: _seciliProjeTipi == 'konut',
                            onTap: () {
                              setModalState(() => _seciliProjeTipi = 'konut');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Villa / Müstakil',
                            selected: _seciliProjeTipi == 'villa',
                            onTap: () {
                              setModalState(() => _seciliProjeTipi = 'villa');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Ticari / AVM / Plaza',
                            selected: _seciliProjeTipi == 'ticari',
                            onTap: () {
                              setModalState(() => _seciliProjeTipi = 'ticari');
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Fabrika / Sanayi',
                            selected: _seciliProjeTipi == 'fabrika',
                            onTap: () {
                              setModalState(() => _seciliProjeTipi = 'fabrika');
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Şehir
                      Text(
                        'Şehir / İl',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _seciliSehir,
                            isExpanded: true,
                            items:
                                ilAdlari
                                    .map(
                                      (il) => DropdownMenuItem(
                                        value: il,
                                        child: Text(
                                          il,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => _seciliSehir = v);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Ücret Tipi
                      Text(
                        'Ücretlendirme Tipi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFilterChoiceChip(
                            label: 'Tüm Ücretler',
                            selected: _seciliUcretTipiFiltre == 'tumu',
                            onTap: () {
                              setModalState(
                                () => _seciliUcretTipiFiltre = 'tumu',
                              );
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'm² Hesabı (₺/m²)',
                            selected: _seciliUcretTipiFiltre == 'metrekare',
                            onTap: () {
                              setModalState(
                                () => _seciliUcretTipiFiltre = 'metrekare',
                              );
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Götürü (Paket ₺)',
                            selected: _seciliUcretTipiFiltre == 'goturu',
                            onTap: () {
                              setModalState(
                                () => _seciliUcretTipiFiltre = 'goturu',
                              );
                              setState(() {});
                            },
                          ),
                          _buildFilterChoiceChip(
                            label: 'Günlük Ücret (₺/Gün)',
                            selected: _seciliUcretTipiFiltre == 'gunluk',
                            onTap: () {
                              setModalState(
                                () => _seciliUcretTipiFiltre = 'gunluk',
                              );
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Filtreleri Uygula',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected
                  ? _themePrimary.withValues(alpha: 0.18)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected
                    ? _themeContrastIcon
                    : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color:
                selected
                    ? _themeContrastIcon
                    : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  /// İlan Detay Modalı (Görüntülenme Sayacı ve Favorileme Entegre)
  Future<void> _ilanDetayModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required SantiyePazarIlani ilan,
    required String benimUid,
    required String benimAd,
    required String benimTelefon,
    required List<PazarAnlasmaTeklifi> anlasmalar,
    required bool favorideMi,
    required Function(bool yeniDurum) onFavoriToggle,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final benimIlanim = ilan.olusturanUid == benimUid;

    // Görüntülenme sayısını arka planda artır
    servisi.pazarIlaniGoruntulenmeArtir(ilan.id, ilan.olusturanUid);

    final mevcutAnlasma = anlasmalar.cast<PazarAnlasmaTeklifi?>().firstWhere(
      (a) =>
          a != null &&
          (a.ilanId == ilan.id ||
              (a.aliciUid == ilan.olusturanUid && a.gonderenUid == benimUid)),
      orElse: () => null,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: PanelGlassWidgets.buildModalSheet(
                context: ctx,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst Başlık, Favori ve Kapat Butonları (Overflow-free)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ilan.baslik,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Favori Butonu
                          IconButton(
                            icon: Icon(
                              favorideMi
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color:
                                  favorideMi ? Colors.redAccent : Colors.grey,
                            ),
                            tooltip:
                                favorideMi
                                    ? 'Favorilerden Çıkar'
                                    : 'Favorilere Ekle',
                            onPressed: () {
                              final yeni = !favorideMi;
                              setModalState(() => favorideMi = yeni);
                              onFavoriToggle(yeni);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // GÖRÜNTÜLENME & FAVORİ SAYACI ŞERİDİ
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye_rounded,
                              size: 16,
                              color: _themeContrastIcon,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${ilan.goruntulenmeSayisi + 1} kişi gördü',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF102A43),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.favorite_rounded,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${ilan.favoriSayisi + (favorideMi ? 1 : 0)} favori',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // İLAN FOTOĞRAFLARI (Varsa Yatay Galeri)
                      if (ilan.fotograflar.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ilan.fotograflar.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final url = ilan.fotograflar[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _fotografBuyutDialog(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        url,
                                        width: 170,
                                        height: 130,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 170,
                                          height: 130,
                                          color: Colors.black12,
                                          child: const Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${i + 1}/${ilan.fotograflar.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // WEB SİTESİ BUTONU (Varsa)
                      if (ilan.webSitesi.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _webSitesiAc(ilan.webSitesi),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _themePrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _themePrimary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 16,
                                  color: _themeContrastIcon,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Web Sitesi: ${ilan.webSitesi}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _themeContrastIcon,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: _themeContrastIcon,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // İLAN SAHİBİ / FİRMA - DETAYLARI GÖRMEK İÇİN TIKLAYIN KARTI
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _yayinlayanProfiliVeReferanslariModalAc(
                            context: context,
                            servisi: servisi,
                            hedefUid: ilan.olusturanUid,
                            hedefAd: ilan.olusturanAd,
                            hedefBrans: ilan.brans,
                            hedefSeviye: ilan.seviye,
                            hedefSirket: ilan.sirketAdi,
                            hedefSehir: ilan.sehir,
                            hedefTelefon: ilan.telefon,
                            benimUid: benimUid,
                            benimAd: benimAd,
                            hedefHakkinda: ilan.aciklama,
                            hedefWebSitesi: ilan.webSitesi,
                            hedefFotograflar: ilan.fotograflar,
                          );
                        },
                        child: PanelGlassWidgets.buildCard(
                          context: ctx,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              PanelGlassWidgets.buildIconBadge(
                                context: ctx,
                                icon: KullaniciRolu.rolIkonu(
                                  ilan.kullaniciTipi,
                                ),
                                accentColor: _themeContrastIcon,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            ilan.sirketAdi.isNotEmpty
                                                ? ilan.sirketAdi
                                                : ilan.olusturanAd,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF102A43),
                                            ),
                                          ),
                                        ),
                                        if (benimIlanim) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF0F7C86,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Benim İlanım',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: _themeContrastIcon,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${ilan.olusturanAd} • ${ilan.brans} (${ilan.seviye})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.touch_app_rounded,
                                          size: 13,
                                          color: _themeContrastIcon,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Detayları görmek için tıklayın (Tanıtım, Referanslar, Yorumlar)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _themeContrastIcon,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: _themeContrastIcon,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Rozetler: Kategori, Proje, Ücret, Konum
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (ilan.kategoriKodu.isNotEmpty)
                            _buildDetayRozet(
                              icon: Icons.category_rounded,
                              label: InsaatKategorileri.kategoriAdi(
                                ilan.kategoriKodu,
                              ),
                              color: _themeContrastIcon,
                            ),
                          _buildDetayRozet(
                            icon: Icons.location_on_outlined,
                            label:
                                '${ilan.sehir}${ilan.ilce.isNotEmpty ? " / ${ilan.ilce}" : ""}',
                            color: _themeContrastIcon,
                          ),
                          _buildDetayRozet(
                            icon: Icons.payments_outlined,
                            label: ilan.ucretEtiketi,
                            color: const Color(0xFFD97706),
                          ),
                          if (ilan.tahminiMetrajVeyaGun.isNotEmpty)
                            _buildDetayRozet(
                              icon: Icons.straighten_rounded,
                              label: 'Miktar: ${ilan.tahminiMetrajVeyaGun}',
                              color: const Color(0xFF0E7490),
                            ),
                          _buildDetayRozet(
                            icon: Icons.groups_rounded,
                            label: '${ilan.ekipKisiSayisi} Kişi',
                            color: _themeContrastIcon,
                          ),
                          if (ilan.projeTipi.isNotEmpty)
                            _buildDetayRozet(
                              icon: Icons.apartment_rounded,
                              label: SantiyePazarIlani.projeTipiBasligi(
                                ilan.projeTipi,
                              ),
                              color: const Color(0xFF0E7490),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Şantiye Şartları & İmkanlar
                      Text(
                        'Şantiye Şartları & İmkanlar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildSartItem(
                              icon: Icons.hotel_rounded,
                              label: 'Koğuş / Kalacak Yer',
                              value: ilan.konaklamaVarMi ? 'Var' : 'Yok',
                              positive: ilan.konaklamaVarMi,
                            ),
                            _buildSartItem(
                              icon: Icons.restaurant_rounded,
                              label: 'Yemek Durumu',
                              value:
                                  ilan.yemekVarMi
                                      ? 'Yemek Dahil'
                                      : 'Kendisine Ait',
                              positive: ilan.yemekVarMi,
                            ),
                            _buildSartItem(
                              icon: Icons.directions_bus_rounded,
                              label: 'Servis / Ulaşım',
                              value:
                                  ilan.ulasimServisVarMi ? 'Servis Var' : 'Yok',
                              positive: ilan.ulasimServisVarMi,
                            ),
                            _buildSartItem(
                              icon: Icons.verified_user_rounded,
                              label: 'Sigorta / SGK',
                              value: SantiyePazarIlani.sgkDurumBasligi(
                                ilan.sgkDurumu,
                              ),
                              positive: true,
                            ),
                            _buildSartItem(
                              icon: Icons.health_and_safety_rounded,
                              label: 'İSG & KKD Ekipmanı',
                              value:
                                  ilan.isgKkdSaglanacakMi
                                      ? 'Şantiyeden Verilir'
                                      : 'Usta Getirir',
                              positive: ilan.isgKkdSaglanacakMi,
                            ),
                            _buildSartItem(
                              icon: Icons.construction_rounded,
                              label: 'Takım & Aletler',
                              value:
                                  ilan.aletEkipmanDurumu == 'santiyeden'
                                      ? 'Şantiyeden'
                                      : 'Usta Kendisi Getirir',
                              positive: true,
                            ),
                            _buildSartItem(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Hakediş & Ödeme',
                              value:
                                  ilan.odemePeriyodu == 'haftalik'
                                      ? 'Haftalık Hakediş'
                                      : (ilan.odemePeriyodu == 'onbes_gunluk'
                                          ? '15 Günlük'
                                          : 'Aylık'),
                              positive: true,
                            ),
                            if (ilan.fazlaMesaiVarMi)
                              _buildSartItem(
                                icon: Icons.access_time_filled_rounded,
                                label: 'Fazla Mesai',
                                value: 'Mesai Ücreti Var',
                                positive: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Açıklama
                      Text(
                        'İlan Açıklaması',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PanelGlassWidgets.buildInset(
                        context: ctx,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          ilan.aciklama,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Eylem Butonları
                      if (!benimIlanim) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themePrimary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(Icons.chat_bubble_rounded),
                          label: Text(
                            mevcutAnlasma != null
                                ? 'Mesajlaşmaya Git (Sohbeti Aç)'
                                : 'Mesaj Gönder & Teklif Ver',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (mevcutAnlasma != null) {
                              _mesajlasmaSohbetModalAc(
                                context: context,
                                servisi: servisi,
                                anlasma: mevcutAnlasma,
                                benimUid: benimUid,
                                benimAd: benimAd,
                              );
                            } else {
                              _iletisimVeAnlasmaTeklifiModalAc(
                                context: context,
                                servisi: servisi,
                                benimUid: benimUid,
                                benimAd: benimAd,
                                benimTelefon: benimTelefon,
                                ilan: ilan,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            if (ilan.telefon.trim().isNotEmpty) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _themeContrastIcon,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: Icon(Icons.chat_outlined, size: 18),
                                  label: Text('WhatsApp'),
                                  onPressed:
                                      () => _whatsappMesajGonder(
                                        ilan.telefon,
                                        ilan.baslik,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _themeContrastIcon,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: Icon(Icons.phone_outlined, size: 18),
                                  label: Text('Ara'),
                                  onPressed: () => _telefonAra(ilan.telefon),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        if (!ilan.id.startsWith('profil_'))
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(
                                alpha: 0.15,
                              ),
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.redAccent),
                              ),
                            ),
                            icon: Icon(Icons.delete_outline_rounded),
                            label: Text(
                              'İlanı Yayından Kaldır (Sil)',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            onPressed: () async {
                              await servisi.pazarIlaniSil(ilan.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'İlanınız yayından kaldırıldı.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSartItem({
    required IconData icon,
    required String label,
    required String value,
    required bool positive,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: positive ? _themeContrastIcon : Colors.grey,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: positive ? _themeContrastIcon : Colors.black87,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetayRozet({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Canlı Mesajlaşma & Sohbet Ekranı
  Future<void> _mesajlasmaSohbetModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required PazarAnlasmaTeklifi anlasma,
    required String benimUid,
    required String benimAd,
  }) async {
    final msgCtrl = TextEditingController();
    final scrollCtrl = ScrollController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final karsiTarafAd =
        anlasma.gonderenUid == benimUid ? anlasma.aliciAd : anlasma.gonderenAd;
    final aktarildiMi = anlasma.durum == 'ekibe_aktarildi';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.sizeOf(context).height * 0.88,
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                MediaQuery.viewInsetsOf(context).bottom + 12,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: context,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        PanelGlassWidgets.buildIconBadge(
                          context: context,
                          icon: Icons.chat_bubble_rounded,
                          accentColor: _themeContrastIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                karsiTarafAd,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                              Text(
                                '${anlasma.ekipAdi} • ${anlasma.ilanBaslik}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    Expanded(
                      child:
                          anlasma.mesajlar.isEmpty
                              ? Center(
                                child: Text(
                                  'Henüz mesaj yok. İlk mesajı siz gönderin.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: anlasma.mesajlar.length,
                                itemBuilder: (context, idx) {
                                  final msg = anlasma.mesajlar[idx];
                                  final benMi = msg['gonderenUid'] == benimUid;
                                  final metin = msg['mesaj']?.toString() ?? '';
                                  final gonderen =
                                      msg['gonderenAd']?.toString() ?? '';

                                  final bubbleBg =
                                      benMi
                                          ? _themePrimary
                                          : (isDark
                                              ? Colors.white.withValues(
                                                alpha: 0.12,
                                              )
                                              : Colors.black.withValues(
                                                alpha: 0.07,
                                              ));
                                  final bubbleTextColor =
                                      benMi
                                          ? (ThemeData.estimateBrightnessForColor(
                                                    _themePrimary,
                                                  ) ==
                                                  Brightness.light
                                              ? const Color(0xFF0F172A)
                                              : Colors.white)
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A));

                                  return Align(
                                    alignment:
                                        benMi
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.sizeOf(context).width *
                                            0.75,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bubbleBg,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            benMi
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                        children: [
                                          if (!benMi)
                                            Text(
                                              gonderen,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: _themeContrastIcon,
                                              ),
                                            ),
                                          Text(
                                            metin,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: bubbleTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),

                    if (!aktarildiMi && widget.teamId.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final ozelEkip = SantiyeOzelEkibi(
                            id: '',
                            ekipAdi: anlasma.ekipAdi,
                            brans: anlasma.brans,
                            ekipBasiAd: karsiTarafAd,
                            ekipBasiTelefon:
                                anlasma.aliciTelefon.isNotEmpty
                                    ? anlasma.aliciTelefon
                                    : anlasma.gonderenTelefon,
                            ekipBasiUid:
                                anlasma.gonderenUid == benimUid
                                    ? anlasma.aliciUid
                                    : anlasma.gonderenUid,
                            santiyeId: anlasma.santiyeId,
                            santiyeAdi: anlasma.santiyeAdi,
                            kisiSayisi: anlasma.ekipKisiSayisi,
                            anlasmaTipi: anlasma.ucretTipi,
                            birimUcret: anlasma.birimUcret,
                            toplamAnlasmaMiktari:
                                anlasma.ucretTipi == 'goturu'
                                    ? 100
                                    : anlasma.tahminiIsMiktari,
                            olusturulmaTarihi: DateTime.now(),
                          );

                          await servisi.santiyeOzelEkibiEkle(
                            widget.teamId,
                            ozelEkip,
                            iscilereDeEkle: true,
                          );

                          final yeniMesajlar = [
                            ...anlasma.mesajlar,
                            {
                              'gonderenUid': benimUid,
                              'gonderenAd': benimAd,
                              'mesaj':
                                  '🤝 Anlaşma onaylandı! ${anlasma.ekipAdi} ekibi Şantiyeler & İşçiler sekmesine eklendi.',
                              'tarih': DateTime.now().toIso8601String(),
                            },
                          ];

                          final guncel = PazarAnlasmaTeklifi(
                            id: anlasma.id,
                            ilanId: anlasma.ilanId,
                            ilanBaslik: anlasma.ilanBaslik,
                            gonderenUid: anlasma.gonderenUid,
                            gonderenAd: anlasma.gonderenAd,
                            gonderenTelefon: anlasma.gonderenTelefon,
                            gonderenTeamId: anlasma.gonderenTeamId,
                            aliciUid: anlasma.aliciUid,
                            aliciAd: anlasma.aliciAd,
                            aliciTelefon: anlasma.aliciTelefon,
                            brans: anlasma.brans,
                            ekipAdi: anlasma.ekipAdi,
                            santiyeId: anlasma.santiyeId,
                            santiyeAdi: anlasma.santiyeAdi,
                            ucretTipi: anlasma.ucretTipi,
                            birimUcret: anlasma.birimUcret,
                            tahminiIsMiktari: anlasma.tahminiIsMiktari,
                            ekipKisiSayisi: anlasma.ekipKisiSayisi,
                            durum: 'ekibe_aktarildi',
                            mesajlar: yeniMesajlar,
                            guncellenmeTarihi: DateTime.now(),
                          );

                          await servisi.pazarAnlasmasiKaydetVeyaGuncelle(
                            guncel,
                          );
                          setModalState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${anlasma.ekipAdi}" İşçiler & Ekipler sekmesine eklendi!',
                                ),
                                backgroundColor: _themePrimary,
                              ),
                            );
                          }
                          widget.onEkibeAktarildi?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0F7C86,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFF0F7C86,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.handshake_rounded,
                                size: 16,
                                color: _themeContrastIcon,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Anlaşmayı Onayla & Şantiyeye / İşçilere Ekle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: PanelGlassWidgets.buildInset(
                            context: context,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            child: TextField(
                              controller: msgCtrl,
                              decoration: InputDecoration(
                                hintText: 'Mesajınızı yazın...',
                                border: InputBorder.none,
                              ),
                              onSubmitted:
                                  (text) => _mesajGonderTrigger(
                                    text: text,
                                    anlasma: anlasma,
                                    servisi: servisi,
                                    benimUid: benimUid,
                                    benimAd: benimAd,
                                    msgCtrl: msgCtrl,
                                    setModalState: setModalState,
                                    scrollCtrl: scrollCtrl,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _themePrimary,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(Icons.send_rounded, size: 18),
                          onPressed:
                              () => _mesajGonderTrigger(
                                text: msgCtrl.text,
                                anlasma: anlasma,
                                servisi: servisi,
                                benimUid: benimUid,
                                benimAd: benimAd,
                                msgCtrl: msgCtrl,
                                setModalState: setModalState,
                                scrollCtrl: scrollCtrl,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _mesajGonderTrigger({
    required String text,
    required PazarAnlasmaTeklifi anlasma,
    required FirestoreServisi servisi,
    required String benimUid,
    required String benimAd,
    required TextEditingController msgCtrl,
    required StateSetter setModalState,
    required ScrollController scrollCtrl,
  }) async {
    final temiz = text.trim();
    if (temiz.isEmpty) return;
    msgCtrl.clear();

    final guncelMesajlar = [
      ...anlasma.mesajlar,
      {
        'gonderenUid': benimUid,
        'gonderenAd': benimAd,
        'mesaj': temiz,
        'tarih': DateTime.now().toIso8601String(),
      },
    ];

    anlasma.mesajlar.add({
      'gonderenUid': benimUid,
      'gonderenAd': benimAd,
      'mesaj': temiz,
      'tarih': DateTime.now().toIso8601String(),
    });
    setModalState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    final guncel = PazarAnlasmaTeklifi(
      id: anlasma.id,
      ilanId: anlasma.ilanId,
      ilanBaslik: anlasma.ilanBaslik,
      gonderenUid: anlasma.gonderenUid,
      gonderenAd: anlasma.gonderenAd,
      gonderenTelefon: anlasma.gonderenTelefon,
      gonderenTeamId: anlasma.gonderenTeamId,
      aliciUid: anlasma.aliciUid,
      aliciAd: anlasma.aliciAd,
      aliciTelefon: anlasma.aliciTelefon,
      brans: anlasma.brans,
      ekipAdi: anlasma.ekipAdi,
      santiyeId: anlasma.santiyeId,
      santiyeAdi: anlasma.santiyeAdi,
      ucretTipi: anlasma.ucretTipi,
      birimUcret: anlasma.birimUcret,
      tahminiIsMiktari: anlasma.tahminiIsMiktari,
      ekipKisiSayisi: anlasma.ekipKisiSayisi,
      durum: anlasma.durum,
      mesajlar: guncelMesajlar,
      guncellenmeTarihi: DateTime.now(),
    );

    await servisi.pazarAnlasmasiKaydetVeyaGuncelle(guncel);
  }

  /// Yeni İletişim & Teklif Başlatma Modalı
  Future<void> _iletisimVeAnlasmaTeklifiModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required String benimAd,
    required String benimTelefon,
    required SantiyePazarIlani ilan,
  }) async {
    final ekipAdiCtrl = TextEditingController(
      text: _bransdanEkipAdiUret(ilan.brans, ilan.arananSeviye),
    );
    final ucretCtrl = TextEditingController(
      text: ilan.ucretTutari > 0 ? ilan.ucretTutari.toStringAsFixed(0) : '400',
    );
    final miktarCtrl = TextEditingController(
      text:
          ilan.tahminiMetrajVeyaGun.isNotEmpty
              ? ilan.tahminiMetrajVeyaGun
              : '1000',
    );
    final kisiSayisiCtrl = TextEditingController(
      text: ilan.ekipKisiSayisi.toString(),
    );
    final mesajCtrl = TextEditingController();
    String seciliUcretTipi =
        ilan.ucretTipi == 'teklife_acik' ? 'metrekare' : ilan.ucretTipi;
    String seciliSantiyeId = '';
    String seciliSantiyeAdi = 'Ana Şantiye';
    bool gonderiliyor = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: context,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          PanelGlassWidgets.buildIconBadge(
                            context: context,
                            icon: Icons.chat_bubble_outline_rounded,
                            accentColor: _themeContrastIcon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mesaj & Teklif Gönder',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '${ilan.olusturanAd} • ${ilan.baslik}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: ekipAdiCtrl,
                          decoration: InputDecoration(
                            labelText: 'Ekip / İş Başlığı',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: seciliUcretTipi,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'metrekare',
                                      child: Text('m² Hesabı'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'goturu',
                                      child: Text('Götürü'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'gunluk',
                                      child: Text('Günlük'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(() => seciliUcretTipi = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: TextField(
                                controller: ucretCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      seciliUcretTipi == 'metrekare'
                                          ? 'm² Ücreti (₺)'
                                          : (seciliUcretTipi == 'goturu'
                                              ? 'Toplam ₺'
                                              : 'Günlük ₺'),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: TextField(
                          controller: mesajCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'İlan Sahibine Mesajınız...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon:
                            gonderiliyor
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(Icons.send_rounded),
                        label: Text(
                          'Mesajı & Teklifi Gönder',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed:
                            gonderiliyor
                                ? null
                                : () async {
                                  if (mesajCtrl.text.trim().isEmpty) return;
                                  setModalState(() => gonderiliyor = true);

                                  final ucret =
                                      double.tryParse(
                                        ucretCtrl.text
                                            .replaceAll(',', '.')
                                            .trim(),
                                      ) ??
                                      0;
                                  final miktar =
                                      double.tryParse(
                                        miktarCtrl.text
                                            .replaceAll(',', '.')
                                            .trim(),
                                      ) ??
                                      1.0;
                                  final kisi =
                                      int.tryParse(
                                        kisiSayisiCtrl.text.trim(),
                                      ) ??
                                      1;
                                  final anlasmaId =
                                      'anlasma_${DateTime.now().millisecondsSinceEpoch}';

                                  final yeniAnlasma = PazarAnlasmaTeklifi(
                                    id: anlasmaId,
                                    ilanId: ilan.id,
                                    ilanBaslik: ilan.baslik,
                                    gonderenUid: benimUid,
                                    gonderenAd: benimAd,
                                    gonderenTelefon: benimTelefon,
                                    gonderenTeamId: widget.teamId,
                                    aliciUid: ilan.olusturanUid,
                                    aliciAd: ilan.olusturanAd,
                                    aliciTelefon: ilan.telefon,
                                    brans: ilan.brans,
                                    ekipAdi:
                                        ekipAdiCtrl.text.trim().isEmpty
                                            ? 'Özel Ekip'
                                            : ekipAdiCtrl.text.trim(),
                                    santiyeId: seciliSantiyeId,
                                    santiyeAdi: seciliSantiyeAdi,
                                    ucretTipi: seciliUcretTipi,
                                    birimUcret: ucret,
                                    tahminiIsMiktari: miktar,
                                    ekipKisiSayisi: kisi,
                                    durum: 'bekliyor',
                                    mesajlar: [
                                      {
                                        'gonderenUid': benimUid,
                                        'gonderenAd': benimAd,
                                        'mesaj': mesajCtrl.text.trim(),
                                        'tarih':
                                            DateTime.now().toIso8601String(),
                                      },
                                    ],
                                    guncellenmeTarihi: DateTime.now(),
                                  );

                                  await servisi
                                      .pazarAnlasmasiKaydetVeyaGuncelle(
                                        yeniAnlasma,
                                      );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _seciliSekme = 1;
                                    _profilAltSekme =
                                        2; // Profilim -> Mesajlarım sekmesine geç
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${ilan.olusturanAd} kullanıcısına mesajınız iletildi!',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF0F7C86,
                                        ),
                                      ),
                                    );
                                  }
                                },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _bransdanEkipAdiUret(String brans, String arananSeviye) {
    final b = brans.toLowerCase();
    if (arananSeviye == 'normal_isci') return 'Genel Saha İşçisi ($brans)';
    if (b.contains('kalıp') && b.contains('demir')) {
      return 'Kalıp & Demir Ekibi';
    }
    if (b.contains('kalıp')) return 'Kalıpçı Ekibi';
    if (b.contains('demir')) return 'Demirci Ekibi';
    if (b.contains('sıva') || b.contains('alçı')) return 'Sıvacı Ekibi';
    if (b.contains('boya')) return 'Boya Ekibi';
    if (b.contains('seramik') || b.contains('fayans')) return 'Seramik Ekibi';
    if (b.contains('elektrik')) return 'Elektrik Ekibi';
    return '$brans Ekibi';
  }

  /// Alarm Kurma Modalı (Overflow-free)
  Future<void> _ilanAlarmiModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required List<PazarIlanAlarmi> mevcutAlarmlar,
  }) async {
    final ilAdlari = [
      'Tüm Türkiye',
      ...TurkiyeIlIlce.iller.map((e) => e['il'] as String),
    ];
    String seciliSehir = _seciliSehir;
    String seciliSeviye = _seciliSeviyeFiltre;
    String seciliUcret = _seciliUcretTipiFiltre;
    final kelimeCtrl = TextEditingController(text: _aramaMetni);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: context,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PanelGlassWidgets.buildIconBadge(
                          context: context,
                          icon: Icons.notifications_active_rounded,
                          accentColor: _themeContrastIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Benzer İlan Bildirim Alarmı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PanelGlassWidgets.buildInset(
                      context: context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: TextField(
                        controller: kelimeCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Aranacak kelime (Örn: Sadece Kalıp, Sıvacı)',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PanelGlassWidgets.buildInset(
                      context: context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: seciliSehir,
                          isExpanded: true,
                          items:
                              ilAdlari
                                  .map(
                                    (il) => DropdownMenuItem(
                                      value: il,
                                      child: Text(
                                        il,
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => seciliSehir = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themePrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final yeniAlarm = PazarIlanAlarmi(
                          id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
                          anahtarKelime: kelimeCtrl.text.trim(),
                          sehir: seciliSehir,
                          arananSeviye: seciliSeviye,
                          ucretTipi: seciliUcret,
                        );
                        await servisi.ilanAlarmlariniKaydet([
                          ...mevcutAlarmlar,
                          yeniAlarm,
                        ]);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'İlan bildirimi alarmı kaydedildi!',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Alarmı Kur',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 🌟 YENİ İLAN YAYINLAMA MODALI (Row Overflow Düzeltildi - Expanded eklendi)
  Future<void> _yeniIlanDialogAc(
    BuildContext context,
    FirestoreServisi servisi,
    KullaniciSahaProfili profil,
    String kullaniciAd,
  ) async {
    final baslikCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final tahminiMiktarCtrl = TextEditingController(text: '3.000 m²');
    final ucretTutariCtrl = TextEditingController(text: '400');
    final telefonCtrl = TextEditingController(text: profil.telefon);
    final ekipKisiCtrl = TextEditingController(text: '6');
    final sirketAdiCtrl = TextEditingController(text: profil.sirketAdi);
    final makineKapasiteCtrl = TextEditingController();
    final webSitesiCtrl = TextEditingController(text: profil.webSitesi);
    final List<String> fotograflar = List<String>.from(profil.fotograflar);
    final fotoUrlCtrl = TextEditingController();

    int seciliMod =
        profil.kullaniciTipi == KullaniciRolu.muteahhit
            ? 0
            : (profil.kullaniciTipi == KullaniciRolu.taseronKalfa ||
                    profil.kullaniciTipi == KullaniciRolu.isciUsta
                ? 1
                : 0);

    String seciliInsaatKategorisi = 'kalip_demir';
    String seciliArananTur = 'ekip';
    String seciliProjeTipi = 'konut';
    String seciliSgkDurumu = 'sgk_yapilacak';
    String seciliAletDurumu = 'santiyeden';
    String seciliOdemePeriyodu = 'haftalik';
    String seciliBaslamaTarihi = 'hemen';
    String seciliDeneyim = '3-5 Yıl';
    String seciliSehir = profil.sehir.isNotEmpty ? profil.sehir : 'İstanbul';
    String ucretTipi = 'metrekare';

    bool konaklamaVarMi = true;
    bool yemekVarMi = true;
    bool ulasimServisVarMi = true;
    bool isgKkdSaglanacakMi = true;
    bool fazlaMesaiVarMi = false;
    bool avansImkaniVarMi = true;
    bool belgeGerekliMi = false;
    bool acilMi = false;
    bool sehirDisinaGiderMi = true;
    bool kaydediliyor = false;

    final ilAdlari = TurkiyeIlIlce.iller.map((e) => e['il'] as String).toList();

    void baslikOnerisiUret(StateSetter setModalState) {
      final katBaslik = InsaatKategorileri.kategoriAdi(seciliInsaatKategorisi);
      if (seciliMod == 0) {
        if (seciliArananTur == 'normal_isci' ||
            seciliInsaatKategorisi == 'duz_isci') {
          baslikCtrl.text =
              '$seciliSehir Şantiyesine Günlük Yevmiyeli Düz İşçi Aranıyor';
        } else if (seciliArananTur == 'ekip') {
          baslikCtrl.text =
              '$seciliSehir Projesine Metrekare Usulü $katBaslik Aranıyor';
        } else {
          baslikCtrl.text =
              '$seciliSehir Şantiyemize Deneyimli $katBaslik Aranıyor';
        }
      } else if (seciliMod == 1) {
        if (seciliArananTur == 'ekip') {
          baslikCtrl.text =
              '${ekipKisiCtrl.text} Kişilik Tecrübeli $katBaslik Ekibi İş Arıyor';
        } else if (seciliArananTur == 'normal_isci') {
          baslikCtrl.text =
              '$seciliSehir Genelinde Şantiyede Çalışacak Düz İşçi (İş Arıyorum)';
        } else {
          baslikCtrl.text =
              '$seciliDeneyim Tecrübeli $katBaslik Ustası (İş Arıyorum)';
        }
      } else {
        final sirket =
            sirketAdiCtrl.text.trim().isNotEmpty
                ? sirketAdiCtrl.text.trim()
                : 'Taşeron Şirketimiz';
        baslikCtrl.text = '$sirket • $katBaslik & Taahhüt Hizmetleri';
      }
      setModalState(() {});
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: context,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🌟 ÜST BAR - OVERFLOW FIXED: Expanded kullanılarak sağdaki taşma çözüldü!
                      Row(
                        children: [
                          PanelGlassWidgets.buildIconBadge(
                            context: context,
                            icon: Icons.add_business_rounded,
                            accentColor: _themeContrastIcon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Yeni Pazar İlanı Oluştur',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // İlan Amacı Seçici (3 Mod)
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildModTabItem(
                              label: 'İş Veriyorum',
                              subLabel: 'İşçi & Ekip Ara',
                              icon: Icons.hail_rounded,
                              selected: seciliMod == 0,
                              onTap: () {
                                setModalState(() {
                                  seciliMod = 0;
                                  baslikOnerisiUret(setModalState);
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildModTabItem(
                              label: 'İş Arıyorum',
                              subLabel: 'Usta & Ekip',
                              icon: Icons.handyman_rounded,
                              selected: seciliMod == 1,
                              onTap: () {
                                setModalState(() {
                                  seciliMod = 1;
                                  baslikOnerisiUret(setModalState);
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildModTabItem(
                              label: 'Şirket Vitrini',
                              subLabel: 'Taşeron & Kiralık',
                              icon: Icons.domain_rounded,
                              selected: seciliMod == 2,
                              onTap: () {
                                setModalState(() {
                                  seciliMod = 2;
                                  baslikOnerisiUret(setModalState);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (seciliMod == 0) ...[
                        Text(
                          'Kimi Arıyorsunuz?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _themeContrastIcon,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildFilterChoiceChip(
                              label: '👷 Genel Şantiye Düz İşçisi',
                              selected: seciliArananTur == 'normal_isci',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'normal_isci';
                                    seciliInsaatKategorisi = 'duz_isci';
                                    ucretTipi = 'gunluk';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '👥 Taşeron / Usta Ekibi',
                              selected: seciliArananTur == 'ekip',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'ekip';
                                    ucretTipi = 'metrekare';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '🔨 Kıdemli Usta / Kalfa',
                              selected: seciliArananTur == 'usta',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'usta';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '🚜 İş Makinesi Operatörü',
                              selected: seciliArananTur == 'operator',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'operator';
                                    seciliInsaatKategorisi = 'operator';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                          ],
                        ),
                      ] else if (seciliMod == 1) ...[
                        Text(
                          'Profiliniz / Statünüz',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _themeContrastIcon,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildFilterChoiceChip(
                              label: '🔨 Bireysel Kıdemli Usta',
                              selected: seciliArananTur == 'usta',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'usta';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '👥 Ekip Başı (Taşeron Ekip)',
                              selected: seciliArananTur == 'ekip',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'ekip';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '👷 Genel Şantiye Düz İşçisi',
                              selected: seciliArananTur == 'normal_isci',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'normal_isci';
                                    seciliInsaatKategorisi = 'duz_isci';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                            _buildFilterChoiceChip(
                              label: '🚜 İş Makinesi Operatörü',
                              selected: seciliArananTur == 'operator',
                              onTap:
                                  () => setModalState(() {
                                    seciliArananTur = 'operator';
                                    seciliInsaatKategorisi = 'operator';
                                    baslikOnerisiUret(setModalState);
                                  }),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // İnşaat Branşı
                      Text(
                        'İnşaat İş Kolu / Kategorisi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: seciliInsaatKategorisi,
                            isExpanded: true,
                            items:
                                InsaatKategorileri.tumu
                                    .map(
                                      (k) => DropdownMenuItem(
                                        value: k['id'] as String,
                                        child: Row(
                                          children: [
                                            Icon(
                                              k['ikon'] as IconData,
                                              size: 16,
                                              color: _themeContrastIcon,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                k['baslik'] as String,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() {
                                  seciliInsaatKategorisi = v;
                                  baslikOnerisiUret(setModalState);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Proje Tipi & Şehir
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Proje Tipi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                PanelGlassWidgets.buildInset(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: seciliProjeTipi,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'konut',
                                          child: Text(
                                            'Konut / Site',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'villa',
                                          child: Text(
                                            'Villa / Müstakil',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ticari',
                                          child: Text(
                                            'Ticari / Plaza',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'fabrika',
                                          child: Text(
                                            'Fabrika / Depo',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'altyapi',
                                          child: Text(
                                            'Altyapı & Yol',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'tadilat',
                                          child: Text(
                                            'Tadilat & Restorasyon',
                                            style: TextStyle(fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setModalState(
                                            () => seciliProjeTipi = v,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Şehir / İl',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                PanelGlassWidgets.buildInset(
                                  context: context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: seciliSehir,
                                      isExpanded: true,
                                      items:
                                          ilAdlari
                                              .map(
                                                (il) => DropdownMenuItem(
                                                  value: il,
                                                  child: Text(
                                                    il,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setModalState(() {
                                            seciliSehir = v;
                                            baslikOnerisiUret(setModalState);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Ücret Tipi ve Tutar
                      Row(
                        children: [
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: ucretTipi,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'metrekare',
                                      child: Text('m² Hesabı (₺/m²)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'goturu',
                                      child: Text('Götürü (Toplam ₺)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'gunluk',
                                      child: Text('Günlük (₺/Gün)'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(() => ucretTipi = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: TextField(
                                controller: ucretTutariCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      ucretTipi == 'metrekare'
                                          ? 'm² Ücreti (₺)'
                                          : (ucretTipi == 'goturu'
                                              ? 'Götürü (₺)'
                                              : 'Günlük (₺)'),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Miktar ve Kişi Sayısı
                      Row(
                        children: [
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: TextField(
                                controller: tahminiMiktarCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Miktar (Örn: 3.500 m²)',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: TextField(
                                controller: ekipKisiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Kişi Sayısı',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Şantiye Şartları & Yan Haklar
                      Text(
                        'Şantiye Şartları & Yan Haklar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _themeContrastIcon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: Text('🛏️ Koğuş / Kalacak Yer'),
                            selected: konaklamaVarMi,
                            onSelected:
                                (v) => setModalState(() => konaklamaVarMi = v),
                          ),
                          FilterChip(
                            label: Text('🍲 Yemek Dahil (3 Öğün)'),
                            selected: yemekVarMi,
                            onSelected:
                                (v) => setModalState(() => yemekVarMi = v),
                          ),
                          FilterChip(
                            label: Text('🚌 Servis / Ulaşım Desteği'),
                            selected: ulasimServisVarMi,
                            onSelected:
                                (v) =>
                                    setModalState(() => ulasimServisVarMi = v),
                          ),
                          FilterChip(
                            label: Text('🦺 İSG & KKD Şantiyeden'),
                            selected: isgKkdSaglanacakMi,
                            onSelected:
                                (v) =>
                                    setModalState(() => isgKkdSaglanacakMi = v),
                          ),
                          FilterChip(
                            label: Text('⏱️ Fazla Mesai İmkanı'),
                            selected: fazlaMesaiVarMi,
                            onSelected:
                                (v) => setModalState(() => fazlaMesaiVarMi = v),
                          ),
                          FilterChip(
                            label: Text('💵 Avans İmkanı Var'),
                            selected: avansImkaniVarMi,
                            onSelected:
                                (v) =>
                                    setModalState(() => avansImkaniVarMi = v),
                          ),
                          if (seciliMod == 1)
                            FilterChip(
                              label: Text('🌍 Şehir Dışına Gidebilirim'),
                              selected: sehirDisinaGiderMi,
                              onSelected:
                                  (v) => setModalState(
                                    () => sehirDisinaGiderMi = v,
                                  ),
                            ),
                          FilterChip(
                            label: Text('⚡ ACİL İlan'),
                            selected: acilMi,
                            onSelected: (v) => setModalState(() => acilMi = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: seciliSgkDurumu,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'sgk_yapilacak',
                                      child: Text(
                                        'SGK Girişi Yapılacak',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'taseron_sozlesmesi',
                                      child: Text(
                                        'Taşeron Sözleşmesi',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'yevmiyeli',
                                      child: Text(
                                        'Günlük / Serbest',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(() => seciliSgkDurumu = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: seciliOdemePeriyodu,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'haftalik',
                                      child: Text(
                                        'Haftalık Hakediş',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'onbes_gunluk',
                                      child: Text(
                                        '15 Günlük Hakediş',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'aylik',
                                      child: Text(
                                        'Aylık Maaş',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'is_bitimi',
                                      child: Text(
                                        'İş Bitimi Hakediş',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(
                                        () => seciliOdemePeriyodu = v,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (seciliMod == 2) ...[
                        PanelGlassWidgets.buildInset(
                          context: context,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: sirketAdiCtrl,
                            decoration: InputDecoration(
                              labelText: 'Şirket / Firma Ünvanı',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        PanelGlassWidgets.buildInset(
                          context: context,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: makineKapasiteCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  'Ekipman Parkı / İskele & Makine Kapasitesi',
                              hintText:
                                  'Örn: 10.000 m² Flanşlı İskele, 3 Ekskavatör',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // İlan Başlığı ve Açıklaması
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: baslikCtrl,
                          decoration: InputDecoration(
                            labelText: 'İlan Başlığı',
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: _themeContrastIcon,
                              ),
                              tooltip: 'Otomatik Başlık Öner',
                              onPressed: () => baslikOnerisiUret(setModalState),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: telefonCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'İletişim Telefon Numarası',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: TextField(
                          controller: aciklamaCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText:
                                seciliMod == 0
                                    ? 'Şantiye İş Detayları, Hakediş ve Çalışma Koşulları...'
                                    : (seciliMod == 1
                                        ? 'Ustalık Geçmişiniz, Referanslarınız ve Ekip Detaylarınız...'
                                        : 'Şirket Hizmetleri, Faaliyet Alanları ve Referans Projeler...'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Web Sitesi (İsteğe Bağlı)
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: webSitesiCtrl,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'Web Sitesi (Opsiyonel)',
                            hintText: 'Örn: https://kuzeyyapi.com',
                            prefixIcon: Icon(
                              Icons.language_rounded,
                              size: 18,
                              color: _themeContrastIcon,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Fotoğraflar / Proje Görselleri
                      PanelGlassWidgets.buildInset(
                        context: context,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 18,
                                  color: _themeContrastIcon,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'İlan & Referans Fotoğrafları',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF102A43),
                                    ),
                                  ),
                                ),
                                if (fotograflar.isEmpty)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Örnek Ekle',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        fotograflar.addAll([
                                          'https://images.unsplash.com/photo-1541888946425-d0fbb18615f8?w=800',
                                          'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800',
                                        ]);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: fotoUrlCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Fotoğraf Linki (URL)',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                      ),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _themePrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Ekle',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    final url = fotoUrlCtrl.text.trim();
                                    if (url.isNotEmpty) {
                                      setModalState(() {
                                        fotograflar.add(url);
                                        fotoUrlCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (fotograflar.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 75,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: fotograflar.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (ctx, i) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            fotograflar[i],
                                            width: 75,
                                            height: 75,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Container(
                                                  width: 75,
                                                  height: 75,
                                                  color: Colors.black12,
                                                  child: const Icon(
                                                    Icons
                                                        .broken_image_rounded,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                fotograflar.removeAt(i);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            kaydediliyor
                                ? null
                                : () async {
                                  if (baslikCtrl.text.trim().isEmpty) {
                                    baslikOnerisiUret(setModalState);
                                  }
                                  setModalState(() => kaydediliyor = true);

                                  final ucret =
                                      double.tryParse(
                                        ucretTutariCtrl.text
                                            .replaceAll(',', '.')
                                            .trim(),
                                      ) ??
                                      0;
                                  final kisi =
                                      int.tryParse(ekipKisiCtrl.text.trim()) ??
                                      1;
                                  final katBaslik =
                                      InsaatKategorileri.kategoriAdi(
                                        seciliInsaatKategorisi,
                                      );

                                  final kategoriStr =
                                      seciliMod == 0
                                          ? 'is_ilani'
                                          : (seciliMod == 1
                                              ? (seciliArananTur ==
                                                      'normal_isci'
                                                  ? 'normal_isci'
                                                  : 'usta_ekip')
                                              : 'sirket_vitrini');

                                  final myUid =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      '';
                                  final yeniIlan = SantiyePazarIlani(
                                    id:
                                        'pazar_${DateTime.now().millisecondsSinceEpoch}',
                                    olusturanUid: myUid,
                                    olusturanAd: kullaniciAd,
                                    kullaniciTipi:
                                        seciliMod == 0
                                            ? KullaniciRolu.muteahhit
                                            : (seciliMod == 2
                                                ? KullaniciRolu.muteahhit
                                                : KullaniciRolu.taseronKalfa),
                                    ilanKategorisi: kategoriStr,
                                    kategoriKodu: seciliInsaatKategorisi,
                                    projeTipi: seciliProjeTipi,
                                    sgkDurumu: seciliSgkDurumu,
                                    arananSeviye: seciliArananTur,
                                    ucretTipi: ucretTipi,
                                    ucretTutari: ucret,
                                    tahminiMetrajVeyaGun:
                                        tahminiMiktarCtrl.text.trim(),
                                    ekipKisiSayisi: kisi,
                                    konaklamaVarMi: konaklamaVarMi,
                                    yemekVarMi: yemekVarMi,
                                    ulasimServisVarMi: ulasimServisVarMi,
                                    isgKkdSaglanacakMi: isgKkdSaglanacakMi,
                                    fazlaMesaiVarMi: fazlaMesaiVarMi,
                                    aletEkipmanDurumu: seciliAletDurumu,
                                    odemePeriyodu: seciliOdemePeriyodu,
                                    avansImkaniVarMi: avansImkaniVarMi,
                                    deneyimYili: seciliDeneyim,
                                    belgeGerekliMi: belgeGerekliMi,
                                    baslamaTarihiTipi: seciliBaslamaTarihi,
                                    baslik: baslikCtrl.text.trim(),
                                    brans: katBaslik,
                                    seviye:
                                        SantiyePazarIlani.arananSeviyeBasligi(
                                          seciliArananTur,
                                        ),
                                    sehir: seciliSehir,
                                    ilce: '',
                                    sirketAdi: sirketAdiCtrl.text.trim(),
                                    kapasiteVeyaUcret:
                                        makineKapasiteCtrl.text
                                                .trim()
                                                .isNotEmpty
                                            ? makineKapasiteCtrl.text.trim()
                                            : '$ucret ₺',
                                    aciklama:
                                        aciklamaCtrl.text.trim().isEmpty
                                            ? '$seciliSehir projesinde $katBaslik alanında detaylı bilgi için iletişime geçebilirsiniz.'
                                            : aciklamaCtrl.text.trim(),
                                    telefon: telefonCtrl.text.trim(),
                                    webSitesi: webSitesiCtrl.text.trim(),
                                    fotograflar: fotograflar,
                                    tarih: DateTime.now(),
                                    acilMi: acilMi,
                                    goruntulenmeSayisi: 1,
                                    favoriSayisi: 0,
                                  );

                                  await servisi.pazarIlaniEkle(
                                    yeniIlan.toMap(),
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _seciliSekme = 1;
                                    _profilAltSekme =
                                        0; // Profilim -> İlanlarım sekmesine geç
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'İlanınız başarıyla yayınlandı!',
                                        ),
                                        backgroundColor: _themePrimary,
                                      ),
                                    );
                                  }
                                },
                        child:
                            kaydediliyor
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  'İlanı Yayınla',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModTabItem({
    required String label,
    required String subLabel,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color:
                selected
                    ? _themeContrastIcon
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _themeContrastIcon,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color:
                      selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  color: selected ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final servisi = FirestoreServisi(kullaniciId: uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingLiquidAppBar(
        title: 'Şantiye Pazarı & İlanlar',
        showHamburger: widget.gomuluMod,
        showPrivacyButton: false,
      ),
      body: GlassPageSurface(
        preferSoftLightBackground: true,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: servisi.getSantiyePazariKullanicilariStream(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            KullaniciSahaProfili benimProfil = const KullaniciSahaProfili();
            String benimAd = 'Şantiye Üyesi';
            List<PazarIlanAlarmi> benimAlarmlar = const [];
            final Set<String> benimFavoriIlanIdleri = Set<String>.from(
              _yerelFavoriler,
            );

            final tumIlanlar = <SantiyePazarIlani>[];
            final anlasmaMap = <String, PazarAnlasmaTeklifi>{};

            for (final doc in docs) {
              final data = doc.data();
              final docUid = doc.id;
              final ad =
                  (data['adSoyad'] ?? data['username'] ?? 'Şantiye Üyesi')
                      .toString();
              final profil = KullaniciSahaProfili.fromUserDoc(data);

              if (docUid == uid) {
                benimProfil = profil;
                benimAd = ad;
                final rawAlarmlar = data['ilanAlarmlari'] as List? ?? const [];
                benimAlarmlar =
                    rawAlarmlar
                        .whereType<Map>()
                        .map(
                          (m) => PazarIlanAlarmi.fromMap(
                            Map<String, dynamic>.from(m),
                          ),
                        )
                        .toList();

                final rawFavs =
                    data['pazarFavoriIlanlari'] as List? ?? const [];
                for (final f in rawFavs) {
                  benimFavoriIlanIdleri.add(f.toString());
                }
              }

              final rawIlanlar = data['pazarIlanlari'] as List? ?? const [];
              for (final item in rawIlanlar) {
                if (item is Map) {
                  tumIlanlar.add(
                    SantiyePazarIlani.fromMap(Map<String, dynamic>.from(item)),
                  );
                }
              }

              if (profil.tamamlandiMi && profil.vitrindeGoster) {
                final kategori =
                    profil.kullaniciTipi == KullaniciRolu.muteahhit
                        ? 'sirket_vitrini'
                        : (profil.isciVeyaUstaMi ? 'normal_isci' : 'usta_ekip');
                final seviyeKod =
                    profil.isciVeyaUstaMi
                        ? (profil.seviye.toLowerCase().contains('işçi')
                            ? 'normal_isci'
                            : 'usta')
                        : 'ekip';
                tumIlanlar.add(
                  SantiyePazarIlani(
                    id: 'profil_$docUid',
                    olusturanUid: docUid,
                    olusturanAd: ad,
                    kullaniciTipi: profil.kullaniciTipi,
                    ilanKategorisi: kategori,
                    kategoriKodu:
                        profil.brans.toLowerCase().contains('kalıp')
                            ? 'kalip'
                            : 'kaba_iscilik',
                    arananSeviye: seviyeKod,
                    ucretTipi: profil.isciVeyaUstaMi ? 'gunluk' : 'metrekare',
                    ucretTutari: profil.gunlukYevmiyeBeklentisi,
                    tahminiMetrajVeyaGun: profil.calismaKapasitesi,
                    ekipKisiSayisi: profil.isciVeyaUstaMi ? 1 : 6,
                    baslik:
                        profil.sirketAdi.isNotEmpty
                            ? '${profil.sirketAdi} • ${profil.brans}'
                            : '$ad • ${profil.brans} (${profil.seviye})',
                    brans: profil.brans,
                    seviye: profil.seviye,
                    sehir: profil.sehir,
                    sirketAdi: profil.sirketAdi,
                    kapasiteVeyaUcret: profil.calismaKapasitesi,
                    aciklama:
                        profil.hakkinda.isNotEmpty
                            ? profil.hakkinda
                            : '${profil.sehir} genelinde ${profil.brans} alanında proje ve şantiye işleri için iletişime geçebilirsiniz.',
                    telefon: profil.telefon,
                    tarih: DateTime.now().subtract(const Duration(hours: 3)),
                    acilMi: profil.isAriyorum || profil.ustaAriyorum,
                    goruntulenmeSayisi: 85,
                    favoriSayisi: 12,
                  ),
                );
              }

              final rawAnlasmalar =
                  data['pazarAnlasmalari'] as List? ?? const [];
              for (final aItem in rawAnlasmalar) {
                if (aItem is Map) {
                  final teklif = PazarAnlasmaTeklifi.fromMap(
                    Map<String, dynamic>.from(aItem),
                  );
                  if (teklif.gonderenUid == uid || teklif.aliciUid == uid) {
                    final mevcut = anlasmaMap[teklif.id];
                    if (mevcut == null ||
                        teklif.guncellenmeTarihi.isAfter(
                          mevcut.guncellenmeTarihi,
                        ) ||
                        teklif.mesajlar.length > mevcut.mesajlar.length) {
                      anlasmaMap[teklif.id] = teklif;
                    }
                  }
                }
              }
            }

            tumIlanlar.addAll(_ornekBaslangicIlanlari());

            if (benimAlarmlar.isNotEmpty) {
              for (final ilan in tumIlanlar) {
                if (ilan.olusturanUid == uid) continue;
                final eslesiyor = benimAlarmlar.any(
                  (alarm) => alarm.ilanaUyuyorMu(ilan),
                );
                if (eslesiyor && !_bildirilenIlanIdleri.contains(ilan.id)) {
                  _bildirilenIlanIdleri.add(ilan.id);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    BildirimServisi().pazarEslesenIlanBildirimiGonder(
                      ilanId: ilan.id,
                      baslik: ilan.baslik,
                      detay:
                          '${ilan.sehir} • ${ilan.brans} • ${ilan.ucretEtiketi}',
                    );
                  });
                }
              }
            }

            final benimAnlasmalarim =
                anlasmaMap.values.toList()..sort(
                  (a, b) => b.guncellenmeTarihi.compareTo(a.guncellenmeTarihi),
                );

            for (final anlasma in benimAnlasmalarim) {
              final bKey =
                  '${anlasma.id}_${anlasma.durum}_${anlasma.mesajlar.length}';
              if (!_bildirilenAnlasmaKeyleri.contains(bKey) &&
                  anlasma.mesajlar.isNotEmpty &&
                  anlasma.mesajlar.last['gonderenUid'] != uid) {
                _bildirilenAnlasmaKeyleri.add(bKey);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  BildirimServisi().pazarAnlasmaBildirimiGonder(
                    bildirimKey: bKey,
                    baslik: '🤝 Şantiye Pazarı: ${anlasma.ekipAdi}',
                    detay:
                        '${anlasma.mesajlar.last['gonderenAd']}: ${anlasma.mesajlar.last['mesaj']}',
                  );
                });
              }
            }

            // Listeler
            final benimIlanlarim =
                tumIlanlar.where((ilan) => ilan.olusturanUid == uid).toList();
            final benimFavoriIlanlarim =
                tumIlanlar
                    .where((ilan) => benimFavoriIlanIdleri.contains(ilan.id))
                    .toList();

            // Pazar İlanları Filtreleme
            final filtreliIlanlar =
                tumIlanlar.where((ilan) {
                  if (_seciliKategori == 'is_ilani' &&
                      ilan.ilanKategorisi != 'is_ilani') {
                    return false;
                  }
                  if (_seciliKategori == 'usta_ekip' &&
                      ilan.ilanKategorisi != 'usta_ekip' &&
                      ilan.ilanKategorisi != 'normal_isci') {
                    return false;
                  }
                  if (_seciliKategori == 'sirket_vitrini' &&
                      ilan.ilanKategorisi != 'sirket_vitrini') {
                    return false;
                  }

                  if (_seciliInsaatKategorisi != 'tumu' &&
                      ilan.kategoriKodu.isNotEmpty) {
                    if (ilan.kategoriKodu != _seciliInsaatKategorisi) {
                      return false;
                    }
                  }

                  if (_seciliProjeTipi != 'tumu' && ilan.projeTipi.isNotEmpty) {
                    if (ilan.projeTipi != _seciliProjeTipi) {
                      return false;
                    }
                  }

                  if (_seciliSehir != 'Tüm Türkiye' &&
                      ilan.sehir != _seciliSehir) {
                    return false;
                  }

                  if (_seciliSeviyeFiltre != 'tumu' &&
                      ilan.arananSeviye != _seciliSeviyeFiltre) {
                    return false;
                  }

                  if (_seciliUcretTipiFiltre != 'tumu' &&
                      ilan.ucretTipi != _seciliUcretTipiFiltre) {
                    return false;
                  }

                  if (_aramaMetni.trim().isNotEmpty) {
                    final k = _aramaMetni.trim().toLowerCase();
                    final araMetin =
                        '${ilan.baslik} ${ilan.brans} ${ilan.seviye} ${ilan.sehir} ${ilan.ilce} ${ilan.aciklama} ${ilan.kategoriKodu}'
                            .toLowerCase();
                    if (!araMetin.contains(k)) return false;
                  }

                  return true;
                }).toList();

            filtreliIlanlar.sort((a, b) {
              return _siralaTarihYeniMi
                  ? b.tarih.compareTo(a.tarih)
                  : a.tarih.compareTo(b.tarih);
            });

            void favoriDegistir(SantiyePazarIlani ilan, bool yeniDurum) {
              HapticFeedback.selectionClick();
              setState(() {
                if (yeniDurum) {
                  _yerelFavoriler.add(ilan.id);
                  benimFavoriIlanIdleri.add(ilan.id);
                } else {
                  _yerelFavoriler.remove(ilan.id);
                  benimFavoriIlanIdleri.remove(ilan.id);
                }
              });
              servisi.pazarIlaniFavoriDegistir(
                ilan.id,
                yeniDurum,
                ilan.olusturanUid,
              );
            }

            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    FloatingLiquidAppBar.topPadding(context, extra: 8),
                    14,
                    widget.gomuluMod ? 110 : 32,
                  ),
                  children: [
                    // 🌟 1. ÜST SEKME SEÇİCİ: İlanlar • Profilim (Yönetim Merkezi)
                    PanelGlassWidgets.buildCard(
                      context: context,
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          _buildPazarTabChip(
                            index: 0,
                            label: 'Pazar İlanları',
                            icon: Icons.storefront_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildPazarTabChip(
                            index: 1,
                            label: 'Profilim & İlanlarım',
                            icon: Icons.person_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🌟 SEKME 0: İLANLAR (Arama & Filtre Kontrol Çubuğu)
                    if (_seciliSekme == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _aramaModalAc(context),
                              child: PanelGlassWidgets.buildInset(
                                context: context,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                borderColor:
                                    _aramaMetni.isNotEmpty
                                        ? _themeContrastIcon
                                        : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 16,
                                      color: _themeContrastIcon,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _aramaMetni.isEmpty
                                            ? 'Ara'
                                            : _aramaMetni,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight:
                                              _aramaMetni.isEmpty
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                    if (_aramaMetni.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap:
                                            () => setState(() {
                                              _aramaCtrl.clear();
                                              _aramaMetni = '';
                                            }),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _filtreModalAc(context),
                              child: PanelGlassWidgets.buildInset(
                                context: context,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                borderColor:
                                    _aktifFiltreSayisi > 0
                                        ? _themeContrastIcon
                                        : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 15,
                                      color: _themeContrastIcon,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        _aktifFiltreSayisi == 0
                                            ? 'Filtrele'
                                            : 'Filtre ($_aktifFiltreSayisi)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight:
                                              _aktifFiltreSayisi > 0
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(
                                  () =>
                                      _siralaTarihYeniMi = !_siralaTarihYeniMi,
                                );
                              },
                              child: PanelGlassWidgets.buildInset(
                                context: context,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.swap_vert_rounded,
                                      size: 15,
                                      color: _themeContrastIcon,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        _siralaTarihYeniMi
                                            ? 'En Yeni'
                                            : 'En Eski',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF102A43),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap:
                                () => _ilanAlarmiModalAc(
                                  context: context,
                                  servisi: servisi,
                                  mevcutAlarmlar: benimAlarmlar,
                                ),
                            child: PanelGlassWidgets.buildInset(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              borderColor:
                                  benimAlarmlar.isNotEmpty
                                      ? const Color(
                                        0xFF0F7C86,
                                      ).withValues(alpha: 0.6)
                                      : null,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: 16,
                                    color: _themeContrastIcon,
                                  ),
                                  if (benimAlarmlar.isNotEmpty) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${benimAlarmlar.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _themeContrastIcon,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // İLANLAR LİSTESİ
                      if (filtreliIlanlar.isEmpty)
                        PanelGlassWidgets.buildCard(
                          context: context,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: _themeContrastIcon,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Aramanıza uygun ilan bulunamadı.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtreliIlanlar.map((ilan) {
                          final fav = benimFavoriIlanIdleri.contains(ilan.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildKompaktIlanKarti(
                              context: context,
                              servisi: servisi,
                              ilan: ilan,
                              benimUid: uid,
                              benimAd: benimAd,
                              benimTelefon: benimProfil.telefon,
                              alarmEslesiyor: benimAlarmlar.any(
                                (a) => a.ilanaUyuyorMu(ilan),
                              ),
                              anlasmalar: benimAnlasmalarim,
                              favorideMi: fav,
                              onFavoriToggle:
                                  (yeni) => favoriDegistir(ilan, yeni),
                              isDark: isDark,
                            ),
                          );
                        }),
                    ] else ...[
                      // 🌟 SEKME 1: PROFİLİM & YÖNETİM MERKEZİ (İlanlarım, Favorilerim, Mesajlarım)
                      _buildProfilimMerkezi(
                        context: context,
                        servisi: servisi,
                        benimUid: uid,
                        benimAd: benimAd,
                        benimProfil: benimProfil,
                        ilanlarim: benimIlanlarim,
                        favorilerim: benimFavoriIlanlarim,
                        anlasmalarim: benimAnlasmalarim,
                        favoriIlanIdleri: benimFavoriIlanIdleri,
                        onFavoriToggle: favoriDegistir,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),

                Positioned(
                  right: 16,
                  bottom: widget.gomuluMod ? 100 : 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'santiye_pazari_ilan_ac_fab',
                    backgroundColor: _themePrimary,
                    foregroundColor: Colors.white,
                    icon: Icon(Icons.add_business_rounded),
                    label: Text(
                      'İlan Aç',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed:
                        () => _yeniIlanDialogAc(
                          context,
                          servisi,
                          benimProfil,
                          benimAd,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPazarTabChip({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final secili = _seciliSekme == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _seciliSekme = index);
        },
        child: PanelGlassWidgets.buildInset(
          context: context,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          borderColor: secili ? _themeContrastIcon : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    secili
                        ? _themeContrastIcon
                        : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: secili ? FontWeight.w800 : FontWeight.w600,
                    color:
                        secili
                            ? _themeContrastIcon
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF102A43)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🌟 PROFİLİM MERKEZİ (İlanlarım, Favorilerim, Mesajlarım tek yerde)
  Widget _buildProfilimMerkezi({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required String benimAd,
    required KullaniciSahaProfili benimProfil,
    required List<SantiyePazarIlani> ilanlarim,
    required List<SantiyePazarIlani> favorilerim,
    required List<PazarAnlasmaTeklifi> anlasmalarim,
    required Set<String> favoriIlanIdleri,
    required Function(SantiyePazarIlani ilan, bool yeni) onFavoriToggle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Profil Kartı
        PanelGlassWidgets.buildCard(
          context: context,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PanelGlassWidgets.buildIconBadge(
                context: context,
                icon: KullaniciRolu.rolIkonu(benimProfil.kullaniciTipi),
                accentColor: _themeContrastIcon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benimAd,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${KullaniciRolu.rolBasligi(benimProfil.kullaniciTipi)} • ${benimProfil.sehir.isNotEmpty ? benimProfil.sehir : "Türkiye"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Alt Sekmeler: İlanlarım • Favorilerim • Mesajlarım • İş Geçmişim • Referanslarım • Referans Verdiklerim
        PanelGlassWidgets.buildCard(
          context: context,
          padding: const EdgeInsets.all(6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTabItem(
                  label: 'İlanlarım (${ilanlarim.length})',
                  icon: Icons.list_alt_rounded,
                  selected: _profilAltSekme == 0,
                  onTap: () => setState(() => _profilAltSekme = 0),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildSubTabItem(
                  label: 'Favorilerim (${favorilerim.length})',
                  icon: Icons.favorite_rounded,
                  selected: _profilAltSekme == 1,
                  onTap: () => setState(() => _profilAltSekme = 1),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildSubTabItem(
                  label: 'Mesajlarım (${anlasmalarim.length})',
                  icon: Icons.chat_bubble_outline_rounded,
                  selected: _profilAltSekme == 2,
                  onTap: () => setState(() => _profilAltSekme = 2),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildSubTabItem(
                  label: 'İş Geçmişim',
                  icon: Icons.work_history_rounded,
                  selected: _profilAltSekme == 3,
                  onTap: () => setState(() => _profilAltSekme = 3),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildSubTabItem(
                  label: 'Referanslarım',
                  icon: Icons.verified_user_rounded,
                  selected: _profilAltSekme == 4,
                  onTap: () => setState(() => _profilAltSekme = 4),
                  isDark: isDark,
                ),
                const SizedBox(width: 4),
                _buildSubTabItem(
                  label: 'Referans Verdiklerim',
                  icon: Icons.rate_review_rounded,
                  selected: _profilAltSekme == 5,
                  onTap: () => setState(() => _profilAltSekme = 5),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Alt Sekme İçeriği
        if (_profilAltSekme == 0) ...[
          // İLANLARIM
          if (ilanlarim.isEmpty)
            PanelGlassWidgets.buildCard(
              context: context,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.post_add_rounded,
                      size: 40,
                      color: _themeContrastIcon,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz yayınlanmış bir ilanınız bulunmuyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themePrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.add_rounded, size: 18),
                      label: Text('Yeni İlan Yayınla'),
                      onPressed:
                          () => _yeniIlanDialogAc(
                            context,
                            servisi,
                            benimProfil,
                            benimAd,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...ilanlarim.map(
              (ilan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildKompaktIlanKarti(
                  context: context,
                  servisi: servisi,
                  ilan: ilan,
                  benimUid: benimUid,
                  benimAd: benimAd,
                  benimTelefon: benimProfil.telefon,
                  alarmEslesiyor: false,
                  anlasmalar: anlasmalarim,
                  favorideMi: favoriIlanIdleri.contains(ilan.id),
                  onFavoriToggle: (yeni) => onFavoriToggle(ilan, yeni),
                  isDark: isDark,
                ),
              ),
            ),
        ] else if (_profilAltSekme == 1) ...[
          // FAVORİLERİM
          if (favorilerim.isEmpty)
            PanelGlassWidgets.buildCard(
              context: context,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 40,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz favorilere eklediğiniz bir ilan yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pazardaki ilanların üzerindeki kalp ikonuna dokunarak favorilerinize ekleyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...favorilerim.map(
              (ilan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildKompaktIlanKarti(
                  context: context,
                  servisi: servisi,
                  ilan: ilan,
                  benimUid: benimUid,
                  benimAd: benimAd,
                  benimTelefon: benimProfil.telefon,
                  alarmEslesiyor: false,
                  anlasmalar: anlasmalarim,
                  favorideMi: true,
                  onFavoriToggle: (yeni) => onFavoriToggle(ilan, yeni),
                  isDark: isDark,
                ),
              ),
            ),
        ] else if (_profilAltSekme == 2) ...[
          // MESAJLARIM & ANLAŞMALAR
          _buildMesajlarVeAnlasmalarListesi(
            context: context,
            servisi: servisi,
            benimUid: benimUid,
            benimAd: benimAd,
            anlasmalar: anlasmalarim,
            isDark: isDark,
          ),
        ] else if (_profilAltSekme == 3) ...[
          // İŞ GEÇMİŞİM (PORTFÖY)
          _buildIsGecmisiListesi(
            context: context,
            servisi: servisi,
            benimUid: benimUid,
            isDark: isDark,
          ),
        ] else if (_profilAltSekme == 4) ...[
          // REFERANSLARIM (BANA GELEN)
          _buildReferanslarimListesi(
            context: context,
            servisi: servisi,
            benimUid: benimUid,
            benimAd: benimAd,
            isDark: isDark,
          ),
        ] else ...[
          // REFERANS VERDİKLERİM
          _buildVerilenReferanslarListesi(
            context: context,
            servisi: servisi,
            benimUid: benimUid,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildSubTabItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = _themePrimary;
    final activeText =
        ThemeData.estimateBrightnessForColor(activeBg) == Brightness.light
            ? const Color(0xFF0F172A)
            : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? activeBg
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color:
                  selected
                      ? activeText
                      : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color:
                    selected
                        ? activeText
                        : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 5 Yıldızlı Puan Gösterici
  Widget _buildYildizPuani(
    double puan, {
    double size = 15,
    Color color = const Color(0xFFF59E0B),
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final double diff = puan - index;
        IconData icon;
        if (diff >= 1.0) {
          icon = Icons.star_rounded;
        } else if (diff >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }

  /// Form Girdi Alanı Yardımcısı
  Widget _buildFormInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
  }) {
    return Builder(
      builder: (context) {
        return PanelGlassWidgets.buildInset(
          context: context,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              prefixIcon:
                  icon != null
                      ? Icon(icon, size: 18, color: _themeContrastIcon)
                      : null,
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  /// İlan Yayınlayan Kişinin / Şirketin Geçmiş İşleri, Yorumları ve Referansları Modalı
  Future<void> _yayinlayanProfiliVeReferanslariModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String hedefUid,
    required String hedefAd,
    required String hedefBrans,
    required String hedefSeviye,
    required String hedefSirket,
    required String hedefSehir,
    required String hedefTelefon,
    required String benimUid,
    required String benimAd,
    String? hedefHakkinda,
    String? hedefWebSitesi,
    List<String>? hedefFotograflar,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int profilModalSekme =
        0; // 0: Geçmiş İşler & Portföy, 1: Referanslar & Yorumlar

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeBg = _themePrimary;
            final activeFg =
                ThemeData.estimateBrightnessForColor(activeBg) ==
                        Brightness.light
                    ? const Color(0xFF0F172A)
                    : Colors.white;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.90,
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: PanelGlassWidgets.buildModalSheet(
                context: ctx,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header & Kapat Butonu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PanelGlassWidgets.buildIconBadge(
                          context: ctx,
                          icon: Icons.business_center_rounded,
                          accentColor: _themeContrastIcon,
                          compact: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hedefAd,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                              if (hedefSirket.isNotEmpty)
                                Text(
                                  hedefSirket,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              Text(
                                '$hedefBrans • $hedefSeviye • ${hedefSehir.isNotEmpty ? hedefSehir : "Türkiye"}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    // Web Sitesi Butonu (Varsa)
                    if (hedefWebSitesi != null &&
                        hedefWebSitesi.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _webSitesiAc(hedefWebSitesi),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _themePrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _themePrimary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language_rounded,
                                size: 15,
                                color: _themeContrastIcon,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  hedefWebSitesi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: _themeContrastIcon,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Tanıtım & Hakkında (Varsa)
                    if (hedefHakkinda != null &&
                        hedefHakkinda.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (isDark
                                    ? Colors.white
                                    : Colors.black)
                                .withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: _themeContrastIcon,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tanıtım & Açıklama',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hedefHakkinda,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color:
                                    isDark
                                        ? Colors.white70
                                        : const Color(0xFF334E68),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Çalışma & Referans Fotoğrafları Galerisi (Varsa)
                    if (hedefFotograflar != null &&
                        hedefFotograflar.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 13,
                                color: _themeContrastIcon,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Çalışma & Proje Fotoğrafları (${hedefFotograflar.length})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _themeContrastIcon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: hedefFotograflar.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, idx) {
                                final imgUrl = hedefFotograflar[idx];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap:
                                      () => _fotografBuyutDialog(
                                        context,
                                        imgUrl,
                                      ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      imgUrl,
                                      width: 110,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            width: 110,
                                            height: 80,
                                            color: Colors.black12,
                                            child: const Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Sekme Seçici: [Geçmiş İşler & Portföy] • [Referanslar & Yorumlar]
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap:
                                  () =>
                                      setModalState(() => profilModalSekme = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      profilModalSekme == 0
                                          ? activeBg
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Geçmiş İşler & Portföy',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          profilModalSekme == 0
                                              ? activeFg
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap:
                                  () =>
                                      setModalState(() => profilModalSekme = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      profilModalSekme == 1
                                          ? activeBg
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Referanslar & Yorumlar',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          profilModalSekme == 1
                                              ? activeFg
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sekme İçerikleri
                    Expanded(
                      child: SingleChildScrollView(
                        child:
                            profilModalSekme == 0
                                ? _buildGecmisIslerView(
                                  ctx: ctx,
                                  servisi: servisi,
                                  uid: hedefUid,
                                  isDark: isDark,
                                )
                                : _buildReferanslarView(
                                  ctx: ctx,
                                  servisi: servisi,
                                  hedefUid: hedefUid,
                                  isDark: isDark,
                                ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Alt Aksiyon Butonu: Referans / Yorum Ekle (Kendi profili değilse)
                    if (hedefUid != benimUid)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_rounded, size: 18),
                        label: const Text(
                          'Bu Firmaya / Ustaya Referans & Yorum Yaz',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          _referansEkleModalAc(
                            context: context,
                            servisi: servisi,
                            hedefUid: hedefUid,
                            hedefAd: hedefAd,
                            benimUid: benimUid,
                            benimAd: benimAd,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Kullanıcının Geçmiş İşleri & Portföy Görünümü
  Widget _buildGecmisIslerView({
    required BuildContext ctx,
    required FirestoreServisi servisi,
    required String uid,
    required bool isDark,
  }) {
    return FutureBuilder<List<KullaniciIsGecmisi>>(
      future: servisi.getKullaniciIsGecmisi(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return PanelGlassWidgets.buildInset(
            context: ctx,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 42,
                  color: _themeContrastIcon,
                ),
                const SizedBox(height: 10),
                Text(
                  'Henüz kayıtlı geçmiş iş / proje bulunmuyor.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kullanıcı henüz tamamladığı projeleri portföyüne eklememiş.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children:
              list.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PanelGlassWidgets.buildInset(
                    context: ctx,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.projeAdi,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                            ),
                            if (item.tamamlanmaYili.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0F7C86,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.tamamlanmaYili,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (item.isVerenVeyaSirket.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'İşveren / Ana Yüklenici: ${item.isVerenVeyaSirket}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (item.rolVeyaKapsam.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.handyman_rounded,
                                text: item.rolVeyaKapsam,
                                color: _themeContrastIcon,
                              ),
                            if (item.metrajVeyaBuyukluk.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.straighten_rounded,
                                text: item.metrajVeyaBuyukluk,
                                color: const Color(0xFFD97706),
                              ),
                            if (item.sehir.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.location_on_rounded,
                                text: item.sehir,
                                color: const Color(0xFF0E7490),
                              ),
                          ],
                        ),
                        if (item.aciklama.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.aciklama,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  /// Kullanıcının Referansları & Yorumları Görünümü
  Widget _buildReferanslarView({
    required BuildContext ctx,
    required FirestoreServisi servisi,
    required String hedefUid,
    required bool isDark,
  }) {
    return StreamBuilder<List<KullaniciReferansi>>(
      stream: servisi.getKullaniciReferanslariStream(hedefUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return PanelGlassWidgets.buildInset(
            context: ctx,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(
              children: [
                const Icon(
                  Icons.star_outline_rounded,
                  size: 42,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(height: 10),
                Text(
                  'Henüz referans veya değerlendirme bulunmuyor.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Birlikte çalıştığınız müteahhit veya ustalar yorum bıraktığında burada gözükecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        final double toplamPuan =
            list.fold(0.0, (total, r) => total + r.puan);
        final double ortalama =
            list.isNotEmpty ? toplamPuan / list.length : 5.0;

        return Column(
          children: [
            // Özet Puan Kartı
            PanelGlassWidgets.buildInset(
              context: ctx,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ortalama.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF102A43),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildYildizPuani(ortalama, size: 16),
                        ],
                      ),
                      Text(
                        '${list.length} Doğrulanmış Referans & Yorum',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Referans Kartları
            ...list.map((ref) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PanelGlassWidgets.buildInset(
                  context: ctx,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ref.referansVerenSirket.isNotEmpty
                                      ? ref.referansVerenSirket
                                      : ref.referansVerenAd,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF102A43),
                                  ),
                                ),
                                if (ref.referansVerenSirket.isNotEmpty &&
                                    ref.referansVerenAd.isNotEmpty)
                                  Text(
                                    '${ref.referansVerenAd}${ref.referansVerenUnvan.isNotEmpty ? " • ${ref.referansVerenUnvan}" : ""}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _themeContrastIcon,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _buildYildizPuani(ref.puan, size: 14),
                        ],
                      ),
                      if (ref.projeAdi.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Proje: ${ref.projeAdi}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '“${ref.yorum}”',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (ref.referansVerenTelefon.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_in_talk_rounded,
                              size: 12,
                              color: _themeContrastIcon,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Teyit: ${ref.referansVerenTelefon}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _themeContrastIcon,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// Yeni Referans & Yorum Ekleme Modalı
  Future<void> _referansEkleModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String hedefUid,
    required String hedefAd,
    required String benimUid,
    required String benimAd,
    bool hariciReferansMi = false,
  }) async {
    final sirketCtrl = TextEditingController();
    final yetkiliCtrl = TextEditingController(
      text: hariciReferansMi ? '' : benimAd,
    );
    final unvanCtrl = TextEditingController();
    final telefonCtrl = TextEditingController();
    final projeCtrl = TextEditingController();
    final yorumCtrl = TextEditingController();
    double secilenPuan = 5.0;
    bool kaydediliyor = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.90,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: ctx,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              hariciReferansMi
                                  ? 'Dış Referans & Tavsiye Ekle'
                                  : '$hedefAd İçin Referans & Yorum Yaz',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Yıldız Puan Seçici
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Puanınız: ${secilenPuan.toInt()} / 5',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starVal = index + 1.0;
                                return IconButton(
                                  icon: Icon(
                                    starVal <= secilenPuan
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 32,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  onPressed: () {
                                    setModalState(() => secilenPuan = starVal);
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildFormInput(
                        controller: sirketCtrl,
                        label: 'Referans Olan Firma / Şirket Adı',
                        hint: 'Örn: Sinpaş GYO, Kalyon Yapı, Demir İnşaat',
                        icon: Icons.apartment_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFormInput(
                              controller: yetkiliCtrl,
                              label: 'Yetkili Adı',
                              hint: 'Örn: Ahmet Yılmaz',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormInput(
                              controller: unvanCtrl,
                              label: 'Görevi / Unvanı',
                              hint: 'Örn: Proje Müdürü',
                              icon: Icons.badge_outlined,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFormInput(
                              controller: projeCtrl,
                              label: 'Birlikte Çalışılan Proje',
                              hint: 'Örn: Ataşehir Konakları',
                              icon: Icons.construction_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormInput(
                              controller: telefonCtrl,
                              label: 'Teyit Telefonu (Opsiyonel)',
                              hint: '0532 ...',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildFormInput(
                        controller: yorumCtrl,
                        label: 'Referans Yorumu & Değerlendirme *',
                        hint:
                            'İşçilik kalitesi, teslim süresi ve iş ahlakı hakkında detaylı yorumunuz...',
                        icon: Icons.comment_outlined,
                        maxLines: 4,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            kaydediliyor
                                ? null
                                : () async {
                                  if (yorumCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lütfen referans yorumu yazınız.',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => kaydediliyor = true);
                                  final ref = KullaniciReferansi(
                                    id:
                                        'ref_${DateTime.now().millisecondsSinceEpoch}',
                                    hedefUid: hedefUid,
                                    hedefAd: hedefAd,
                                    referansVerenUid:
                                        hariciReferansMi ? hedefUid : benimUid,
                                    referansVerenAd:
                                        yetkiliCtrl.text.trim().isNotEmpty
                                            ? yetkiliCtrl.text.trim()
                                            : benimAd,
                                    referansVerenSirket: sirketCtrl.text.trim(),
                                    referansVerenUnvan: unvanCtrl.text.trim(),
                                    referansVerenTelefon:
                                        telefonCtrl.text.trim(),
                                    projeAdi: projeCtrl.text.trim(),
                                    yorum: yorumCtrl.text.trim(),
                                    puan: secilenPuan,
                                    tarih: DateTime.now(),
                                  );
                                  await servisi.referansKaydet(ref);
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Referans ve değerlendirme başarıyla kaydedildi.',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                },
                        child: Text(
                          kaydediliyor
                              ? 'Kaydediliyor...'
                              : 'Referansı Kaydet & Yayınla',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Yeni Geçmiş İş / Proje Ekleme Modalı
  Future<void> _yeniIsGecmisiModalAc({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
  }) async {
    final projeCtrl = TextEditingController();
    final isVerenCtrl = TextEditingController();
    final rolCtrl = TextEditingController();
    final sehirCtrl = TextEditingController();
    final yilCtrl = TextEditingController();
    final metrajCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    bool kaydediliyor = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.90,
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: PanelGlassWidgets.buildModalSheet(
                context: ctx,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Tamamlanan Yeni Proje / İş Ekle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildFormInput(
                        controller: projeCtrl,
                        label: 'Proje / Şantiye Adı *',
                        hint: 'Örn: Kartal Kentsel Dönüşüm Projesi',
                        icon: Icons.apartment_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      _buildFormInput(
                        controller: isVerenCtrl,
                        label: 'İşveren / Ana Yüklenici Firma',
                        hint: 'Örn: Sinpaş GYO, Taşyapı, Ahmet Bey',
                        icon: Icons.domain_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFormInput(
                              controller: rolCtrl,
                              label: 'Yapılan İş & Kapsam',
                              hint: 'Örn: Kalıp & Demir (8 Kişi)',
                              icon: Icons.handyman_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormInput(
                              controller: sehirCtrl,
                              label: 'Şehir / Konum',
                              hint: 'Örn: İstanbul / Kartal',
                              icon: Icons.location_on_outlined,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFormInput(
                              controller: yilCtrl,
                              label: 'Tamamlanma Yılı / Dönem',
                              hint: 'Örn: 2024',
                              icon: Icons.calendar_today_rounded,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormInput(
                              controller: metrajCtrl,
                              label: 'Büyüklük / Metraj',
                              hint: 'Örn: 18.000 m², 4 Katlı',
                              icon: Icons.straighten_rounded,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildFormInput(
                        controller: aciklamaCtrl,
                        label: 'Proje Notu & Detayları',
                        hint:
                            'Kullanılan teknikler, süre, ekip performansı hakkında detaylar...',
                        icon: Icons.notes_rounded,
                        maxLines: 3,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            kaydediliyor
                                ? null
                                : () async {
                                  if (projeCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lütfen proje adını giriniz.',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => kaydediliyor = true);
                                  final isGecmisi = KullaniciIsGecmisi(
                                    id:
                                        'is_${DateTime.now().millisecondsSinceEpoch}',
                                    kullaniciUid: benimUid,
                                    projeAdi: projeCtrl.text.trim(),
                                    isVerenVeyaSirket: isVerenCtrl.text.trim(),
                                    rolVeyaKapsam: rolCtrl.text.trim(),
                                    sehir: sehirCtrl.text.trim(),
                                    tamamlanmaYili: yilCtrl.text.trim(),
                                    metrajVeyaBuyukluk: metrajCtrl.text.trim(),
                                    aciklama: aciklamaCtrl.text.trim(),
                                    tarih: DateTime.now(),
                                  );
                                  await servisi.isGecmisiEkle(
                                    isGecmisi.toMap(),
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Geçmiş iş / proje başarıyla eklendi.',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                },
                        child: Text(
                          kaydediliyor
                              ? 'Kaydediliyor...'
                              : 'Projeyi Portföye Ekle',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Profilim: İş Geçmişim Sekmesi
  Widget _buildIsGecmisiListesi({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required bool isDark,
  }) {
    return FutureBuilder<List<KullaniciIsGecmisi>>(
      future: servisi.getKullaniciIsGecmisi(benimUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Başlık & Ekle Butonu
            PanelGlassWidgets.buildCard(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.work_history_rounded,
                    size: 20,
                    color: _themeContrastIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tamamlanan Projeler & Portföy (${list.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                        Text(
                          'Müteahhit ve müşterilerin görmesi için geçmiş işlerinizi vitrine koyun',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _themePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'İş Ekle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed:
                        () => _yeniIsGecmisiModalAc(
                          context: context,
                          servisi: servisi,
                          benimUid: benimUid,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (list.isEmpty)
              PanelGlassWidgets.buildCard(
                context: context,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_special_outlined,
                        size: 42,
                        color: _themeContrastIcon,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Henüz iş geçmişi eklemediniz.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tamamladığınız konut, villa, tadilat veya kaba yapı işlerini ekleyerek ilanlarınızın güvenilirliğini artırın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themePrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('İlk Projeyi Ekle'),
                        onPressed:
                            () => _yeniIsGecmisiModalAc(
                              context: context,
                              servisi: servisi,
                              benimUid: benimUid,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...list.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PanelGlassWidgets.buildCard(
                    context: context,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.projeAdi,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF102A43),
                                ),
                              ),
                            ),
                            if (item.tamamlanmaYili.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0F7C86,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.tamamlanmaYili,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Sil',
                              onPressed: () async {
                                final onay = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (dCtx) => AlertDialog(
                                        title: const Text('Projeyi Sil'),
                                        content: Text(
                                          '“${item.projeAdi}” iş geçmişinizden kaldırılsın mı?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.pop(dCtx, false),
                                            child: const Text('Vazgeç'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(dCtx, true),
                                            child: const Text(
                                              'Sil',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                                if (onay == true) {
                                  await servisi.isGecmisiSil(item.id);
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        if (item.isVerenVeyaSirket.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'İşveren / Yüklenici: ${item.isVerenVeyaSirket}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (item.rolVeyaKapsam.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.handyman_rounded,
                                text: item.rolVeyaKapsam,
                                color: _themeContrastIcon,
                              ),
                            if (item.metrajVeyaBuyukluk.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.straighten_rounded,
                                text: item.metrajVeyaBuyukluk,
                                color: const Color(0xFFD97706),
                              ),
                            if (item.sehir.isNotEmpty)
                              _buildMiniBadge(
                                icon: Icons.location_on_rounded,
                                text: item.sehir,
                                color: const Color(0xFF0E7490),
                              ),
                          ],
                        ),
                        if (item.aciklama.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.aciklama,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  /// Profilim: Referanslarım (Bana Gelen) Sekmesi
  Widget _buildReferanslarimListesi({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required String benimAd,
    required bool isDark,
  }) {
    return StreamBuilder<List<KullaniciReferansi>>(
      stream: servisi.getKullaniciReferanslariStream(benimUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data ?? const [];
        final double toplamPuan = list.fold(0.0, (s, r) => s + r.puan);
        final double ort = list.isNotEmpty ? toplamPuan / list.length : 5.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Başlık & Puan & Dış Referans Ekle Butonu
            PanelGlassWidgets.buildCard(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 22,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Referanslarım (${list.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                            if (list.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildYildizPuani(ort, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                ort.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Müşterilerinizden ve çalıştığınız şirketlerden gelen onaylı referanslar',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Referans Ekle',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed:
                        () => _referansEkleModalAc(
                          context: context,
                          servisi: servisi,
                          hedefUid: benimUid,
                          hedefAd: benimAd,
                          benimUid: benimUid,
                          benimAd: benimAd,
                          hariciReferansMi: true,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (list.isEmpty)
              PanelGlassWidgets.buildCard(
                context: context,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.star_outline_rounded,
                        size: 42,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Henüz bir referansınız veya değerlendirmeniz yok.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pazarda birlikte çalıştığınız müteahhit veya ustalar ilan detayınızdan size referans yazabilir. Ayrıca geçmişte çalıştığınız şirketleri "Referans Ekle" ile kendiniz de portföyünüze kaydedebilirsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Dış Referans Ekle'),
                        onPressed:
                            () => _referansEkleModalAc(
                              context: context,
                              servisi: servisi,
                              hedefUid: benimUid,
                              hedefAd: benimAd,
                              benimUid: benimUid,
                              benimAd: benimAd,
                              hariciReferansMi: true,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...list.map((ref) {
                final benimYazdigim = ref.referansVerenUid == benimUid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PanelGlassWidgets.buildCard(
                    context: context,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.referansVerenSirket.isNotEmpty
                                        ? ref.referansVerenSirket
                                        : ref.referansVerenAd,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF102A43),
                                    ),
                                  ),
                                  if (ref.referansVerenSirket.isNotEmpty &&
                                      ref.referansVerenAd.isNotEmpty)
                                    Text(
                                      '${ref.referansVerenAd}${ref.referansVerenUnvan.isNotEmpty ? " • ${ref.referansVerenUnvan}" : ""}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: _themeContrastIcon,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildYildizPuani(ref.puan, size: 14),
                            if (benimYazdigim) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Referansı Sil',
                                onPressed: () async {
                                  final onay = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (dCtx) => AlertDialog(
                                          title: const Text('Referansı Sil'),
                                          content: const Text(
                                            'Bu referans kaydı kaldırılsın mı?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    dCtx,
                                                    false,
                                                  ),
                                              child: const Text('Vazgeç'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(dCtx, true),
                                              child: const Text(
                                                'Sil',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                  if (onay == true) {
                                    await servisi.referansSil(ref.id);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                        if (ref.projeAdi.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Çalışılan Proje: ${ref.projeAdi}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '“${ref.yorum}”',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        if (ref.referansVerenTelefon.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_in_talk_rounded,
                                size: 12,
                                color: _themeContrastIcon,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Teyit: ${ref.referansVerenTelefon}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _themeContrastIcon,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  /// Profilim: Referans Verdiklerim Sekmesi
  Widget _buildVerilenReferanslarListesi({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required bool isDark,
  }) {
    return StreamBuilder<List<KullaniciReferansi>>(
      stream: servisi.getVerilenReferanslarStream(benimUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelGlassWidgets.buildCard(
              context: context,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.rate_review_rounded,
                    size: 22,
                    color: _themeContrastIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Referans Verdiklerim (${list.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                        Text(
                          'Pazardaki ustalara ve şirketlere yazdığınız referans ve değerlendirmeler',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (list.isEmpty)
              PanelGlassWidgets.buildCard(
                context: context,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 42,
                        color: _themeContrastIcon,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Henüz kimseye referans vermediniz.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Şantiye Pazarındaki ilan detaylarına giderek iş yaptığınız güvenilir usta ve şirketlere referans mektubu yazabilirsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...list.map((ref) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PanelGlassWidgets.buildCard(
                    context: context,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.hedefAd.isNotEmpty
                                        ? ref.hedefAd
                                        : 'İlan Sahibi',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF102A43),
                                    ),
                                  ),
                                  if (ref.projeAdi.isNotEmpty)
                                    Text(
                                      'Proje: ${ref.projeAdi}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildYildizPuani(ref.puan, size: 14),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Referansı Sil',
                              onPressed: () async {
                                final onay = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (dCtx) => AlertDialog(
                                        title: const Text('Referansı Kaldır'),
                                        content: const Text(
                                          'Bu kullanıcıya yazdığınız referans silinsin mi?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () =>
                                                    Navigator.pop(dCtx, false),
                                            child: const Text('Vazgeç'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(dCtx, true),
                                            child: const Text(
                                              'Sil',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                                if (onay == true) {
                                  await servisi.referansSil(ref.id);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '“${ref.yorum}”',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  /// Sadeleştirilmiş Kısa Özet İlan Kartı (Görüntülenme Sayısı ve Favorileme Entegre)
  Widget _buildKompaktIlanKarti({
    required BuildContext context,
    required FirestoreServisi servisi,
    required SantiyePazarIlani ilan,
    required String benimUid,
    required String benimAd,
    required String benimTelefon,
    required bool alarmEslesiyor,
    required List<PazarAnlasmaTeklifi> anlasmalar,
    required bool favorideMi,
    required Function(bool yeniDurum) onFavoriToggle,
    required bool isDark,
  }) {
    final katAdi = InsaatKategorileri.kategoriAdi(ilan.kategoriKodu);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          () => _ilanDetayModalAc(
            context: context,
            servisi: servisi,
            ilan: ilan,
            benimUid: benimUid,
            benimAd: benimAd,
            benimTelefon: benimTelefon,
            anlasmalar: anlasmalar,
            favorideMi: favorideMi,
            onFavoriToggle: onFavoriToggle,
          ),
      child: PanelGlassWidgets.buildCard(
        context: context,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderAccent:
            alarmEslesiyor ? _themePrimary.withValues(alpha: 0.6) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Kısım: Fotoğraf (varsa), Başlık, Acil Rozeti ve Favori Butonu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ilan.fotograflar.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: Colors.black12,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            ilan.fotograflar.first,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  size: 22,
                                  color: Colors.grey,
                                ),
                          ),
                          if (ilan.fotograflar.length > 1)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${ilan.fotograflar.length}',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ilan.baslik,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF102A43),
                              ),
                            ),
                          ),
                          if (ilan.acilMi) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'ACİL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          // Favori İkonu
                          GestureDetector(
                            onTap: () => onFavoriToggle(!favorideMi),
                            child: Icon(
                              favorideMi
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color:
                                  favorideMi ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Rozetler & Görüntülenme / Favori İstatistikleri
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (ilan.kategoriKodu.isNotEmpty)
                        _buildMiniBadge(
                          icon: Icons.foundation_rounded,
                          text: katAdi,
                          color: _themeContrastIcon,
                        ),
                      _buildMiniBadge(
                        icon: Icons.location_on_outlined,
                        text:
                            '${ilan.sehir}${ilan.ilce.isNotEmpty ? " / ${ilan.ilce}" : ""}',
                        color: const Color(0xFF0E7490),
                      ),
                      if (ilan.webSitesi.isNotEmpty)
                        _buildMiniBadge(
                          icon: Icons.language_rounded,
                          text: 'Web',
                          color: _themeContrastIcon,
                        ),
                      if (ilan.tahminiMetrajVeyaGun.isNotEmpty)
                        _buildMiniBadge(
                          icon: Icons.straighten_rounded,
                          text: ilan.tahminiMetrajVeyaGun,
                          color: const Color(0xFF0E7490),
                        ),
                      _buildMiniBadge(
                        icon: Icons.payments_outlined,
                        text: ilan.ucretEtiketi,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Kaç kişi gördü / favoriledi minyatür istatistik
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove_red_eye_rounded,
                          size: 11,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${ilan.goruntulenmeSayisi}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 11,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${ilan.favoriSayisi + (favorideMi ? 1 : 0)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Mesajlar Listesi
  Widget _buildMesajlarVeAnlasmalarListesi({
    required BuildContext context,
    required FirestoreServisi servisi,
    required String benimUid,
    required String benimAd,
    required List<PazarAnlasmaTeklifi> anlasmalar,
    required bool isDark,
  }) {
    if (anlasmalar.isEmpty) {
      return PanelGlassWidgets.buildCard(
        context: context,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: _themeContrastIcon,
              ),
              const SizedBox(height: 10),
              Text(
                'Henüz Mesajlaşmanız Yok',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'İlan detayından "Mesaj Gönder & Teklif Ver" butonuna dokunarak ilan sahipleriyle sohbet başlatabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children:
          anlasmalar.map((anlasma) {
            final karsiTarafAd =
                anlasma.gonderenUid == benimUid
                    ? anlasma.aliciAd
                    : anlasma.gonderenAd;
            final sonMsg =
                anlasma.mesajlar.isNotEmpty ? anlasma.mesajlar.last : null;
            final sonMesajMetin =
                sonMsg?['mesaj']?.toString() ?? 'Görüşme başlatıldı';
            final aktarildiMi = anlasma.durum == 'ekibe_aktarildi';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap:
                    () => _mesajlasmaSohbetModalAc(
                      context: context,
                      servisi: servisi,
                      anlasma: anlasma,
                      benimUid: benimUid,
                      benimAd: benimAd,
                    ),
                child: PanelGlassWidgets.buildCard(
                  context: context,
                  padding: const EdgeInsets.all(12),
                  borderAccent:
                      aktarildiMi ? _themePrimary.withValues(alpha: 0.6) : null,
                  child: Row(
                    children: [
                      PanelGlassWidgets.buildIconBadge(
                        context: context,
                        icon:
                            aktarildiMi
                                ? Icons.verified_rounded
                                : Icons.forum_rounded,
                        accentColor:
                            aktarildiMi
                                ? _themeContrastIcon
                                : const Color(0xFF0E7490),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    karsiTarafAd,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF102A43),
                                    ),
                                  ),
                                ),
                                Text(
                                  FormatYardimcisi.paraFormatla(
                                    anlasma.birimUcret,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _themeContrastIcon,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${anlasma.ekipAdi} • ${anlasma.ilanBaslik}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sonMesajMetin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
