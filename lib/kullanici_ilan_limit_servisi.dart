import 'models/kullanici_saha_profili.dart';

class IlanLimitDurumu {
  final int buHaftakiIlanSayisi;
  final int buAykiIlanSayisi;
  final int kalanHaftalikHak;
  final int kalanAylikHak;
  final bool yayinlayabilirMi;
  final String? engelMesaji;

  IlanLimitDurumu({
    required this.buHaftakiIlanSayisi,
    required this.buAykiIlanSayisi,
    required this.kalanHaftalikHak,
    required this.kalanAylikHak,
    required this.yayinlayabilirMi,
    this.engelMesaji,
  });

  static const int haftalikLimit = 1;
  static const int aylikLimit = 4;
}

/// Kullanıcının Şantiye Pazarı ilan haklarını (haftada 1, ayda en fazla 4) denetleyen servis
class KullaniciIlanLimitServisi {
  static IlanLimitDurumu limitHesapla(List<SantiyePazarIlani> kullaniciIlanlari) {
    final now = DateTime.now();
    final yediGunOnce = now.subtract(const Duration(days: 7));
    final otuzGunOnce = now.subtract(const Duration(days: 30));

    // Otomatik vitrin ilanları ('profil_') kullanıcı kotasını etkilemez
    final gercekIlanlar =
        kullaniciIlanlari.where((i) => !i.id.startsWith('profil_')).toList();

    int buHafta = 0;
    int buAy = 0;

    for (final ilan in gercekIlanlar) {
      if (ilan.tarih.isAfter(yediGunOnce)) {
        buHafta++;
      }
      if (ilan.tarih.isAfter(otuzGunOnce)) {
        buAy++;
      }
    }

    final int kalanHaftalik = (IlanLimitDurumu.haftalikLimit - buHafta).clamp(
      0,
      IlanLimitDurumu.haftalikLimit,
    );
    final int kalanAylik = (IlanLimitDurumu.aylikLimit - buAy).clamp(
      0,
      IlanLimitDurumu.aylikLimit,
    );

    String? engel;
    if (kalanHaftalik <= 0) {
      engel =
          'Haftalık 1 ücretsiz ilan limitinize ulaştınız. Yeni ilan hakkınız bir hafta sonra yenilenecektir.';
    } else if (kalanAylik <= 0) {
      engel =
          'Aylık 4 ilan kotanızı doldurdunuz. Yeni ilan hakkınız sonraki ay yenilenecektir.';
    }

    return IlanLimitDurumu(
      buHaftakiIlanSayisi: buHafta,
      buAykiIlanSayisi: buAy,
      kalanHaftalikHak: kalanHaftalik,
      kalanAylikHak: kalanAylik,
      yayinlayabilirMi: kalanHaftalik > 0 && kalanAylik > 0,
      engelMesaji: engel,
    );
  }
}

