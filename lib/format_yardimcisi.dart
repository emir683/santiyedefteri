import 'package:intl/intl.dart';

class Formatlayici {
  static String yap(double tutar) {
    // 1. Adım: Sadece sayıyı Türkçe formatına (1.000,00) çevir
    // #,##0.00 deseni: Binlik ayırıcı kullan ve her zaman 2 kuruş hanesi göster demektir.
    final format = NumberFormat("#,##0.00", "tr_TR");

    // 2. Adım: Sonuna manuel olarak " TL" ekle
    return "${format.format(tutar)} TL";
  }

  static double parse(String text) {
    if (text.isEmpty) return 0;
    // Virgül ondalık, nokta binlik ayracı.
    // Önce noktaları kaldır (1.000 -> 1000)
    // Sonra virgülü noktaya çevir (10,50 -> 10.50)
    String clean = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }
}
