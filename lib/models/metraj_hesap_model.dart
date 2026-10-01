/// ŞPD AI - İnşaat Malzeme ve Metraj Hesaplama Modeli
/// Kart üzerinde parametrelerin dinamik güncellenmesi ve anlık yeniden hesaplanması için veri yapısı.
class MetrajHesapModel {
  final String category; // 'beton', 'tugla', 'seramik', 'sap', 'siva', 'boya', 'demir', 'alcipan', 'mantolama', 'yalitim', 'hafriyat', 'parke'
  final String title;
  final String icon;
  final String elementAdi;

  // Girdiler / Parametreler (kullanıcının kartta değiştirebileceği değerler)
  final double primaryValue; // Alan (m²) veya Kazı Hacmi (m³)
  final String primaryLabel; // "Döküm Alanı", "Duvar Alanı", "Net Alan"
  final String primaryUnit; // "m²", "m³"

  final double? secondaryValue; // Kalınlık (cm) veya Yükseklik (m)
  final String? secondaryLabel; // "Döküm Kalınlığı", "Şap Kalınlığı"
  final String? secondaryUnit; // "cm", "m"

  final String selectedVariant; // "C25/30", "13.5'luk Tuğla", "60x60 Porselen"
  final List<String> availableVariants; // ['C20', 'C25/30', 'C30', 'C35', 'C40']

  final double birimFiyat; // TL
  final String birimFiyatLabel; // "m³ Beton Fiyatı (TL)", "Adet Tuğla (TL)"

  // Çıktılar / Sonuçlar
  final String anaMiktar; // "15.75 m³", "2.625 Adet", "88.00 m²"
  final String anaMiktarLabel; // "Toplam Sipariş Hacmi", "Sipariş Edilecek Toplam"

  final String lojistik; // "~2 Mikser", "~7 Palet", "~62 Kutu"
  final String lojistikLabel; // "Lojistik & Ambalaj"

  final String firePayi; // "+%5 (+0.75 m³)"
  final double toplamMaliyet; // 41737.5
  final String toplamMaliyetLabel; // "Tahmini Malzeme Maliyeti"

  final List<String> sarfMalzemeler; // Harç, çimento, donatı, kum vb.
  final List<String> tavsiyeler; // Şantiye şefine altın kurallar
  final String raporMetni; // Tam detaylı metin

  const MetrajHesapModel({
    required this.category,
    required this.title,
    required this.icon,
    required this.elementAdi,
    required this.primaryValue,
    required this.primaryLabel,
    required this.primaryUnit,
    this.secondaryValue,
    this.secondaryLabel,
    this.secondaryUnit,
    required this.selectedVariant,
    required this.availableVariants,
    required this.birimFiyat,
    required this.birimFiyatLabel,
    required this.anaMiktar,
    required this.anaMiktarLabel,
    required this.lojistik,
    required this.lojistikLabel,
    required this.firePayi,
    required this.toplamMaliyet,
    required this.toplamMaliyetLabel,
    required this.sarfMalzemeler,
    required this.tavsiyeler,
    required this.raporMetni,
  });

  String get ozetBilgi {
    final sec = (secondaryValue != null && secondaryLabel != null)
        ? ' • $secondaryLabel: ${secondaryValue!.toStringAsFixed(1)} $secondaryUnit'
        : '';
    return '$primaryLabel: ${primaryValue.toStringAsFixed(1)} $primaryUnit$sec';
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'title': title,
      'icon': icon,
      'elementAdi': elementAdi,
      'primaryValue': primaryValue,
      'primaryLabel': primaryLabel,
      'primaryUnit': primaryUnit,
      'secondaryValue': secondaryValue,
      'secondaryLabel': secondaryLabel,
      'secondaryUnit': secondaryUnit,
      'selectedVariant': selectedVariant,
      'availableVariants': availableVariants,
      'birimFiyat': birimFiyat,
      'birimFiyatLabel': birimFiyatLabel,
      'anaMiktar': anaMiktar,
      'anaMiktarLabel': anaMiktarLabel,
      'lojistik': lojistik,
      'lojistikLabel': lojistikLabel,
      'firePayi': firePayi,
      'toplamMaliyet': toplamMaliyet,
      'toplamMaliyetLabel': toplamMaliyetLabel,
      'sarfMalzemeler': sarfMalzemeler,
      'tavsiyeler': tavsiyeler,
      'raporMetni': raporMetni,
    };
  }

  factory MetrajHesapModel.fromMap(Map<String, dynamic> map) {
    return MetrajHesapModel(
      category: map['category']?.toString() ?? 'beton',
      title: map['title']?.toString() ?? 'İnşaat Metrajı',
      icon: map['icon']?.toString() ?? '🧱',
      elementAdi: map['elementAdi']?.toString() ?? '',
      primaryValue: (map['primaryValue'] as num?)?.toDouble() ?? 100.0,
      primaryLabel: map['primaryLabel']?.toString() ?? 'Alan',
      primaryUnit: map['primaryUnit']?.toString() ?? 'm²',
      secondaryValue: (map['secondaryValue'] as num?)?.toDouble(),
      secondaryLabel: map['secondaryLabel']?.toString(),
      secondaryUnit: map['secondaryUnit']?.toString(),
      selectedVariant: map['selectedVariant']?.toString() ?? '',
      availableVariants: (map['availableVariants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      birimFiyat: (map['birimFiyat'] as num?)?.toDouble() ?? 0.0,
      birimFiyatLabel: map['birimFiyatLabel']?.toString() ?? 'Birim Fiyat',
      anaMiktar: map['anaMiktar']?.toString() ?? '',
      anaMiktarLabel: map['anaMiktarLabel']?.toString() ?? 'Toplam Miktar',
      lojistik: map['lojistik']?.toString() ?? '',
      lojistikLabel: map['lojistikLabel']?.toString() ?? 'Lojistik',
      firePayi: map['firePayi']?.toString() ?? '%5',
      toplamMaliyet: (map['toplamMaliyet'] as num?)?.toDouble() ?? 0.0,
      toplamMaliyetLabel:
          map['toplamMaliyetLabel']?.toString() ?? 'Tahmini Maliyet',
      sarfMalzemeler: (map['sarfMalzemeler'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tavsiyeler: (map['tavsiyeler'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      raporMetni: map['raporMetni']?.toString() ?? '',
    );
  }
}
