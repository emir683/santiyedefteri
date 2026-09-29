// Türkiye'nin 81 İli ve Tüm İlçeleri (Koordinatlarıyla)
// Hava durumu ve konum seçimi için offline, hızlı ve kapsamlı veri tabanı.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IlIlceItem {
  final String il;
  final String? ilce;
  final double lat;
  final double lon;

  const IlIlceItem({
    required this.il,
    this.ilce,
    required this.lat,
    required this.lon,
  });

  String get displayName => ilce != null ? '$ilce, $il' : il;
}

class TurkiyeIlIlce {
  static const List<Map<String, dynamic>> iller = [
    {
      'il': 'Adana',
      'plaka': 1,
      'lat': 37.0000,
      'lon': 35.3213,
      'ilceler': [
        'Seyhan', 'Yüreğir', 'Çukurova', 'Sarıçam', 'Ceyhan', 'Kozan',
        'İmamoğlu', 'Karataş', 'Karaisalı', 'Pozantı', 'Yumurtalık',
        'Tufanbeyli', 'Feke', 'Aladağ', 'Saimbeyli'
      ],
    },
    {
      'il': 'Adıyaman',
      'plaka': 2,
      'lat': 37.7648,
      'lon': 38.2786,
      'ilceler': [
        'Merkez', 'Kahta', 'Besni', 'Gölbaşı', 'Gerger', 'Sincik',
        'Çelikhan', 'Tut', 'Samsat'
      ],
    },
    {
      'il': 'Afyonkarahisar',
      'plaka': 3,
      'lat': 38.7507,
      'lon': 30.5567,
      'ilceler': [
        'Merkez', 'Sandıklı', 'Dinar', 'Bolvadin', 'Sinanpaşa', 'Emirdağ',
        'Şuhut', 'Çay', 'İhsaniye', 'İscehisar', 'Sultandağı', 'Çobanlar',
        'Dazkırı', 'Başmakçı', 'Hocalar', 'Kızılören', 'Evciler', 'Bayat'
      ],
    },
    {
      'il': 'Ağrı',
      'plaka': 4,
      'lat': 39.7191,
      'lon': 43.0503,
      'ilceler': [
        'Merkez', 'Patnos', 'Doğubayazıt', 'Diyadin', 'Eleşkirt', 'Tutak',
        'Taşlıçay', 'Hamur'
      ],
    },
    {
      'il': 'Amasya',
      'plaka': 5,
      'lat': 40.6534,
      'lon': 35.8336,
      'ilceler': [
        'Merkez', 'Merzifon', 'Suluova', 'Taşova', 'Gümüşhacıköy', 'Göynücek',
        'Hamamözü'
      ],
    },
    {
      'il': 'Ankara',
      'plaka': 6,
      'lat': 39.9334,
      'lon': 32.8597,
      'ilceler': [
        'Çankaya', 'Keçiören', 'Yenimahalle', 'Mamak', 'Etimesgut', 'Sincan',
        'Altındağ', 'Pursaklar', 'Gölbaşı', 'Polatlı', 'Çubuk', 'Kahramankazan',
        'Beypazarı', 'Elmadağ', 'Nallıhan', 'Haymana', 'Kızılcahamam', 'Bala',
        'Ayaş', 'Kalecik', 'Güdül', 'Çamlıdere', 'Akyurt', 'Evren', 'Şereflikoçhisar'
      ],
    },
    {
      'il': 'Antalya',
      'plaka': 7,
      'lat': 36.8969,
      'lon': 30.7133,
      'ilceler': [
        'Muratpaşa', 'Kepez', 'Alanya', 'Manavgat', 'Konyaaltı', 'Serik',
        'Aksu', 'Kumluca', 'Döşemealtı', 'Kaş', 'Korkuteli', 'Gazipaşa',
        'Finike', 'Kemer', 'Elmalı', 'Demre', 'Akseki', 'Gündoğmuş', 'İbradı'
      ],
    },
    {
      'il': 'Artvin',
      'plaka': 8,
      'lat': 41.1828,
      'lon': 41.8183,
      'ilceler': [
        'Merkez', 'Hopa', 'Borçka', 'Yusufeli', 'Arhavi', 'Şavşat',
        'Ardanuç', 'Murgul', 'Kemalpaşa'
      ],
    },
    {
      'il': 'Aydın',
      'plaka': 9,
      'lat': 37.8560,
      'lon': 27.8416,
      'ilceler': [
        'Efeler', 'Nazilli', 'Söke', 'Kuşadası', 'Didim', 'İncirliova',
        'Çine', 'Germencik', 'Bozdoğan', 'Köşk', 'Kuyucak', 'Sultanhisar',
        'Karacasu', 'Buharkent', 'Yenipazar', 'Koçarlı', 'Karpuzlu'
      ],
    },
    {
      'il': 'Balıkesir',
      'plaka': 10,
      'lat': 39.6484,
      'lon': 27.8826,
      'ilceler': [
        'Altıeylül', 'Karesi', 'Edremit', 'Bandırma', 'Gönen', 'Ayvalık',
        'Burhaniye', 'Bigadiç', 'Susurluk', 'Dursunbey', 'Sındırgı', 'İvrindi',
        'Erdek', 'Havran', 'Kepsut', 'Manyas', 'Savaştepe', 'Balya', 'Gömeç',
        'Marmara'
      ],
    },
    {
      'il': 'Bilecik',
      'plaka': 11,
      'lat': 40.1451,
      'lon': 29.9799,
      'ilceler': [
        'Merkez', 'Bozüyük', 'Osmaneli', 'Söğüt', 'Gölpazarı', 'Pazaryeri',
        'İnhisar', 'Yenipazar'
      ],
    },
    {
      'il': 'Bingöl',
      'plaka': 12,
      'lat': 38.8854,
      'lon': 40.4983,
      'ilceler': [
        'Merkez', 'Genç', 'Solhan', 'Karlıova', 'Adaklı', 'Kiğı',
        'Yedisu', 'Yayladere'
      ],
    },
    {
      'il': 'Bitlis',
      'plaka': 13,
      'lat': 38.4006,
      'lon': 42.1095,
      'ilceler': [
        'Tatvan', 'Merkez', 'Güroymak', 'Ahlat', 'Hizan', 'Mutki', 'Adilcevaz'
      ],
    },
    {
      'il': 'Bolu',
      'plaka': 14,
      'lat': 40.7392,
      'lon': 31.6089,
      'ilceler': [
        'Merkez', 'Gerede', 'Mudurnu', 'Göynük', 'Mengen', 'Yeniçağa',
        'Dörtdivan', 'Seben', 'Kıbrıscık'
      ],
    },
    {
      'il': 'Burdur',
      'plaka': 15,
      'lat': 37.7203,
      'lon': 30.2908,
      'ilceler': [
        'Merkez', 'Bucak', 'Gölhisar', 'Yeşilova', 'Ağlasun', 'Çavdır',
        'Tefenni', 'Karamanlı', 'Kemer', 'Altınyayla', 'Çeltikçi'
      ],
    },
    {
      'il': 'Bursa',
      'plaka': 16,
      'lat': 40.1885,
      'lon': 29.0610,
      'ilceler': [
        'Osmangazi', 'Yıldırım', 'Nilüfer', 'İnegöl', 'Gemlik', 'Mustafakemalpaşa',
        'Mudanya', 'Gürsu', 'Karacabey', 'Orhangazi', 'Kestel', 'Yenişehir',
        'İznik', 'Orhaneli', 'Keles', 'Büyükorhan', 'Harmancık'
      ],
    },
    {
      'il': 'Çanakkale',
      'plaka': 17,
      'lat': 40.1553,
      'lon': 26.4142,
      'ilceler': [
        'Merkez', 'Biga', 'Çan', 'Gelibolu', 'Yenice', 'Ayvacık',
        'Ezine', 'Bayramiç', 'Lapseki', 'Eceabat', 'Gökçeada', 'Bozcaada'
      ],
    },
    {
      'il': 'Çankırı',
      'plaka': 18,
      'lat': 40.6013,
      'lon': 33.6134,
      'ilceler': [
        'Merkez', 'Çerkeş', 'Ilgaz', 'Orta', 'Şabanözü', 'Kurşunlu',
        'Yapraklı', 'Kızılırmak', 'Eldivan', 'Atkaracalar', 'Korgun', 'Bayramören'
      ],
    },
    {
      'il': 'Çorum',
      'plaka': 19,
      'lat': 40.5506,
      'lon': 34.9556,
      'ilceler': [
        'Merkez', 'Sungurlu', 'Osmancık', 'İskilip', 'Alaca', 'Bayat',
        'Mecitözü', 'Kargı', 'Ortaköy', 'Uğurludağ', 'Dodurga', 'Oğuzlar',
        'Laçin', 'Boğazkale'
      ],
    },
    {
      'il': 'Denizli',
      'plaka': 20,
      'lat': 37.7765,
      'lon': 29.0864,
      'ilceler': [
        'Pamukkale', 'Merkezefendi', 'Çivril', 'Acıpayam', 'Tavas', 'Honaz',
        'Sarayköy', 'Buldan', 'Kale', 'Çal', 'Çameli', 'Serinhisar',
        'Güney', 'Bozkurt', 'Babadağ', 'Bekilli', 'Beyağaç', 'Baklan'
      ],
    },
    {
      'il': 'Diyarbakır',
      'plaka': 21,
      'lat': 37.9144,
      'lon': 40.2306,
      'ilceler': [
        'Bağlar', 'Kayapınar', 'Yenişehir', 'Sur', 'Ergani', 'Bismil',
        'Silvan', 'Çınar', 'Çermik', 'Dicle', 'Kulp', 'Hani',
        'Madeni', 'Lice', 'Eğil', 'Hazro', 'Kocaköy', 'Çüngüş'
      ],
    },
    {
      'il': 'Edirne',
      'plaka': 22,
      'lat': 41.6768,
      'lon': 26.5603,
      'ilceler': [
        'Merkez', 'Keşan', 'Uzunköprü', 'İpsala', 'Havsa', 'Meriç',
        'Enez', 'Süloğlu', 'Lalapaşa'
      ],
    },
    {
      'il': 'Elazığ',
      'plaka': 23,
      'lat': 38.6810,
      'lon': 39.2264,
      'ilceler': [
        'Merkez', 'Kovancılar', 'Karakoçan', 'Palu', 'Arıcak', 'Baskil',
        'Maden', 'Sivrice', 'Keban', 'Alacakaya', 'Ağın'
      ],
    },
    {
      'il': 'Erzincan',
      'plaka': 24,
      'lat': 39.7500,
      'lon': 39.5000,
      'ilceler': [
        'Merkez', 'Tercan', 'Üzümlü', 'Çayırlı', 'İliç', 'Kemah',
        'Kemaliye', 'Refahiye', 'Otlukbeli'
      ],
    },
    {
      'il': 'Erzurum',
      'plaka': 25,
      'lat': 39.9043,
      'lon': 41.2679,
      'ilceler': [
        'Yakutiye', 'Palandöken', 'Aziziye', 'Horasan', 'Oltu', 'Pasinler',
        'Karayazı', 'Hınıs', 'Tekman', 'Karaçoban', 'Aşkale', 'Şenkaya',
        'Çat', 'Köprüköy', 'İspir', 'Tortum', 'Narman', 'Uzundere',
        'Olur', 'Pazaryolu'
      ],
    },
    {
      'il': 'Eskişehir',
      'plaka': 26,
      'lat': 39.7767,
      'lon': 30.5206,
      'ilceler': [
        'Odunpazarı', 'Tepebaşı', 'Sivrihisar', 'Çifteler', 'Seyitgazi',
        'Alpu', 'Mihalıççık', 'Mahmudiye', 'Beylikova', 'İnönü',
        'Günyüzü', 'Han', 'Mihalgazi', 'Sarıcakaya'
      ],
    },
    {
      'il': 'Gaziantep',
      'plaka': 27,
      'lat': 37.0662,
      'lon': 37.3833,
      'ilceler': [
        'Şahinbey', 'Şehitkamil', 'Nizip', 'İslahiye', 'Nurdağı', 'Araban',
        'Oğuzeli', 'Yavuzeli', 'Karkamış'
      ],
    },
    {
      'il': 'Giresun',
      'plaka': 28,
      'lat': 40.9128,
      'lon': 38.3895,
      'ilceler': [
        'Merkez', 'Bulancak', 'Espiye', 'Görele', 'Tirebolu', 'Dereli',
        'Şebinkarahisar', 'Keşap', 'Yağlıdere', 'Alucra', 'Piraziz', 'Eynesil',
        'Çamoluk', 'Güce', 'Doğankent', 'Çanakçı'
      ],
    },
    {
      'il': 'Gümüşhane',
      'plaka': 29,
      'lat': 40.4600,
      'lon': 39.4700,
      'ilceler': [
        'Merkez', 'Kelkit', 'Şiran', 'Kürtün', 'Torul', 'Köse'
      ],
    },
    {
      'il': 'Hakkari',
      'plaka': 30,
      'lat': 37.5833,
      'lon': 43.7333,
      'ilceler': [
        'Yüksekova', 'Merkez', 'Şemdinli', 'Çukurca', 'Derecik'
      ],
    },
    {
      'il': 'Hatay',
      'plaka': 31,
      'lat': 36.4018,
      'lon': 36.3498,
      'ilceler': [
        'Antakya', 'İskenderun', 'Defne', 'Dörtyol', 'Samandağ', 'Kırıkhan',
        'Reyhanlı', 'Arsuz', 'Altınözü', 'Hassa', 'Erzin', 'Payas',
        'Belen', 'Yayladağı', 'Kumlu'
      ],
    },
    {
      'il': 'Isparta',
      'plaka': 32,
      'lat': 37.7648,
      'lon': 30.5566,
      'ilceler': [
        'Merkez', 'Yalvaç', 'Eğirdir', 'Şarkikaraağaç', 'Gelendost', 'Keçiborlu',
        'Senirkent', 'Sütçüler', 'Gönen', 'Uluborlu', 'Atabey', 'Aksu', 'Yenişarbademli'
      ],
    },
    {
      'il': 'Mersin',
      'plaka': 33,
      'lat': 36.8000,
      'lon': 34.6333,
      'ilceler': [
        'Tarsus', 'Toroslar', 'Akdeniz', 'Yenişehir', 'Mezitli', 'Erdemli',
        'Silifke', 'Anamur', 'Mut', 'Bozyazı', 'Gülnar', 'Aydıncık', 'Çamlıyayla'
      ],
    },
    {
      'il': 'İstanbul',
      'plaka': 34,
      'lat': 41.0082,
      'lon': 28.9784,
      'ilceler': [
        'Kadıköy', 'Beşiktaş', 'Şişli', 'Üsküdar', 'Fatih', 'Bakırköy', 'Beyoğlu',
        'Sarıyer', 'Kartal', 'Maltepe', 'Pendik', 'Ümraniye', 'Ataşehir',
        'Başakşehir', 'Beylikdüzü', 'Esenyurt', 'Küçükçekmece', 'Bağcılar',
        'Bahçelievler', 'Zeytinburnu', 'Gaziosmanpaşa', 'Sultangazi', 'Eyüpsultan',
        'Kağıthane', 'Avcılar', 'Büyükçekmece', 'Silivri', 'Çatalca', 'Şile',
        'Çekmeköy', 'Sancaktepe', 'Sultanbeyli', 'Tuzla', 'Arnavutköy', 'Bayrampaşa',
        'Güngören', 'Esenler', 'Adalar', 'Beykoz'
      ],
    },
    {
      'il': 'İzmir',
      'plaka': 35,
      'lat': 38.4192,
      'lon': 27.1287,
      'ilceler': [
        'Konak', 'Karşıyaka', 'Bornova', 'Buca', 'Çiğli', 'Gaziemir',
        'Karabağlar', 'Bayraklı', 'Torbalı', 'Menemen', 'Kemalpaşa', 'Ödemiş',
        'Aliağa', 'Bergama', 'Tire', 'Balçova', 'Narlıdere', 'Urla', 'Çeşme',
        'Seferihisar', 'Dikili', 'Kiraz', 'Kınık', 'Beydağ', 'Bayındır',
        'Selçuk', 'Foça', 'Güzelbahçe', 'Menderes', 'Karaburun'
      ],
    },
    {
      'il': 'Kars',
      'plaka': 36,
      'lat': 40.6167,
      'lon': 43.1000,
      'ilceler': [
        'Merkez', 'Kağızman', 'Sarıkamış', 'Selim', 'Digor', 'Arpaçay',
        'Akyaka', 'Susuz'
      ],
    },
    {
      'il': 'Kastamonu',
      'plaka': 37,
      'lat': 41.3887,
      'lon': 33.7827,
      'ilceler': [
        'Merkez', 'Tosya', 'Taşköprü', 'Cide', 'İnebolu', 'Araç', 'Devrekani',
        'Bozkurt', 'Daday', 'Azdavay', 'Çatalzeytin', 'Küre', 'Doğanyurt',
        'İhsangazi', 'Pınarbaşı', 'Şenpazar', 'Abana', 'Seydiler', 'Hanönü', 'Ağlı'
      ],
    },
    {
      'il': 'Kayseri',
      'plaka': 38,
      'lat': 38.7312,
      'lon': 35.4787,
      'ilceler': [
        'Melikgazi', 'Kocasinan', 'Talas', 'Develi', 'Yahyalı', 'Bünyan',
        'Pınarbaşı', 'Tomarza', 'Yeşilhisar', 'Sarıoğlan', 'Hacılar', 'Sarız',
        'İncesu', 'Felahiye', 'Özvatan', 'Akkışla'
      ],
    },
    {
      'il': 'Kırklareli',
      'plaka': 39,
      'lat': 41.7333,
      'lon': 27.2167,
      'ilceler': [
        'Lüleburgaz', 'Merkez', 'Babaeski', 'Vize', 'Pınarhisar', 'Demirköy',
        'Pehlivanköy', 'Kofçaz'
      ],
    },
    {
      'il': 'Kırşehir',
      'plaka': 40,
      'lat': 39.1425,
      'lon': 34.1709,
      'ilceler': [
        'Merkez', 'Kaman', 'Mucur', 'Çiçekdağı', 'Akpınar', 'Boztepe', 'Akçakent'
      ],
    },
    {
      'il': 'Kocaeli',
      'plaka': 41,
      'lat': 40.8533,
      'lon': 29.8815,
      'ilceler': [
        'Gebze', 'İzmit', 'Darıca', 'Körfez', 'Gölcük', 'Derince',
        'Çayırova', 'Kartepe', 'Başiskele', 'Karamürsel', 'Kandıra', 'Dilovası'
      ],
    },
    {
      'il': 'Konya',
      'plaka': 42,
      'lat': 37.8667,
      'lon': 32.4833,
      'ilceler': [
        'Selçuklu', 'Meram', 'Karatay', 'Ereğli', 'Akşehir', 'Beyşehir',
        'Cihanbeyli', 'Kulu', 'Seydişehir', 'Ilgın', 'Bozkır', 'Karapınar',
        'Sarayönü', 'Yunak', 'Kadınhanı', 'Çumra', 'Doğanhisar', 'Hüyük',
        'Altınekin', 'Hadim', 'Çeltik', 'Güneysınır', 'Taşkent', 'Tuzlukçu',
        'Akören', 'Derebucak', 'Halkapınar', 'Yalıhüyük', 'Emirgazi', 'Derbent', 'Ahırlı'
      ],
    },
    {
      'il': 'Kütahya',
      'plaka': 43,
      'lat': 39.4167,
      'lon': 29.9833,
      'ilceler': [
        'Merkez', 'Tavşanlı', 'Simav', 'Gediz', 'Emet', 'Altıntaş',
        'Domaniç', 'Hisarcık', 'Aslanapa', 'Çavdarhisar', 'Şaphane', 'Pazarlar', 'Dumlupınar'
      ],
    },
    {
      'il': 'Malatya',
      'plaka': 44,
      'lat': 38.3552,
      'lon': 38.3095,
      'ilceler': [
        'Battalgazi', 'Yeşilyurt', 'Doğanşehir', 'Akçadağ', 'Darende', 'Hekimhan',
        'Pütürge', 'Yazıhan', 'Arapgir', 'Kuluncak', 'Arguvan', 'Kale', 'Doğanyol'
      ],
    },
    {
      'il': 'Manisa',
      'plaka': 45,
      'lat': 38.6191,
      'lon': 27.4289,
      'ilceler': [
        'Yunusemre', 'Şehzadeler', 'Akhisar', 'Salihli', 'Turgutlu', 'Soma',
        'Alaşehir', 'Saruhanlı', 'Demirci', 'Kula', 'Kırkağaç', 'Sarıgöl',
        'Gördes', 'Selendi', 'Ahmetli', 'Gölmarmara', 'Köprübaşı'
      ],
    },
    {
      'il': 'Kahramanmaraş',
      'plaka': 46,
      'lat': 37.5858,
      'lon': 36.9371,
      'ilceler': [
        'Onikişubat', 'Dulkadiroğlu', 'Elbistan', 'Afşin', 'Türkoğlu', 'Pazarcık',
        'Göksun', 'Andırın', 'Çağlayancerit', 'Nurhak', 'Ekinözü'
      ],
    },
    {
      'il': 'Mardin',
      'plaka': 47,
      'lat': 37.3212,
      'lon': 40.7245,
      'ilceler': [
        'Kızıltepe', 'Artuklu', 'Midyat', 'Nusaybin', 'Derik', 'Mazıdağı',
        'Dargeçit', 'Savur', 'Yeşilli', 'Ömerli'
      ],
    },
    {
      'il': 'Muğla',
      'plaka': 48,
      'lat': 37.2153,
      'lon': 28.3636,
      'ilceler': [
        'Bodrum', 'Fethiye', 'Milas', 'Menteşe', 'Marmaris', 'Seydikemer',
        'Ortaca', 'Yatağan', 'Dalaman', 'Köyceğiz', 'Ula', 'Datça', 'Kavaklıdere'
      ],
    },
    {
      'il': 'Muş',
      'plaka': 49,
      'lat': 38.9462,
      'lon': 41.7539,
      'ilceler': [
        'Merkez', 'Bulanık', 'Malazgirt', 'Varto', 'Hasköy', 'Korkut'
      ],
    },
    {
      'il': 'Nevşehir',
      'plaka': 50,
      'lat': 38.6939,
      'lon': 34.6857,
      'ilceler': [
        'Merkez', 'Ürgüp', 'Avanos', 'Gülşehir', 'Derinkuyu', 'Kozaklı',
        'Acıgöl', 'Hacıbektaş'
      ],
    },
    {
      'il': 'Niğde',
      'plaka': 51,
      'lat': 37.9667,
      'lon': 34.6833,
      'ilceler': [
        'Merkez', 'Bor', 'Çiftlik', 'Ulukışla', 'Altunhisar', 'Çamardı'
      ],
    },
    {
      'il': 'Ordu',
      'plaka': 52,
      'lat': 40.9839,
      'lon': 37.8764,
      'ilceler': [
        'Altınordu', 'Ünye', 'Fatsa', 'Gölköy', 'Korgan', 'Kumru',
        'Perşembe', 'Aybastı', 'Ulubey', 'Akkuş', 'Mesudiye', 'Gürgentepe',
        'İkizce', 'Çatalpınar', 'Çaybaşı', 'Kabadüz', 'Kabataş', 'Çamaş', 'Gülyalı'
      ],
    },
    {
      'il': 'Rize',
      'plaka': 53,
      'lat': 41.0201,
      'lon': 40.5234,
      'ilceler': [
        'Merkez', 'Çayeli', 'Ardeşen', 'Pazar', 'Fındıklı', 'Güneysu',
        'Kalkandere', 'İyidere', 'Derepazarı', 'Çamlıhemşin', 'İkizdere', 'Hemşin'
      ],
    },
    {
      'il': 'Sakarya',
      'plaka': 54,
      'lat': 40.7569,
      'lon': 30.3783,
      'ilceler': [
        'Adapazarı', 'Serdivan', 'Akyazı', 'Erenler', 'Hendek', 'Karasu',
        'Geyve', 'Arifiye', 'Sapanca', 'Pamukova', 'Ferizli', 'Kocaali',
        'Kaynarca', 'Söğütlü', 'Karapürçek', 'Taraklı'
      ],
    },
    {
      'il': 'Samsun',
      'plaka': 55,
      'lat': 41.2928,
      'lon': 36.3313,
      'ilceler': [
        'İlkadım', 'Atakum', 'Bafra', 'Çarşamba', 'Canik', 'Vezirköprü',
        'Terme', 'Tekkeköy', 'Havza', 'Alaçam', '19 Mayıs', 'Ayvacık',
        'Kavak', 'Salıpazarı', 'Asarcık', 'Ladik', 'Yakakent'
      ],
    },
    {
      'il': 'Siirt',
      'plaka': 56,
      'lat': 37.9333,
      'lon': 41.9500,
      'ilceler': [
        'Merkez', 'Kurtalan', 'Pervari', 'Baykan', 'Şirvan', 'Eruh', 'Tillo'
      ],
    },
    {
      'il': 'Sinop',
      'plaka': 57,
      'lat': 42.0231,
      'lon': 35.1531,
      'ilceler': [
        'Merkez', 'Boyabat', 'Gerze', 'Ayancık', 'Durağan', 'Türkeli',
        'Erfelek', 'Saraydüzü', 'Dikmen'
      ],
    },
    {
      'il': 'Sivas',
      'plaka': 58,
      'lat': 39.7477,
      'lon': 37.0179,
      'ilceler': [
        'Merkez', 'Şarkışla', 'Yıldızeli', 'Suşehri', 'Gemerek', 'Zara',
        'Kangal', 'Gürün', 'Divriği', 'Koyulhisar', 'Altınyayla', 'Hafik',
        'Ulaş', 'İmranlı', 'Akıncılar', 'Gölova', 'Doğanşar'
      ],
    },
    {
      'il': 'Tekirdağ',
      'plaka': 59,
      'lat': 40.9833,
      'lon': 27.5167,
      'ilceler': [
        'Çorlu', 'Süleymanpaşa', 'Çerkezköy', 'Kapaklı', 'Ergene', 'Malkara',
        'Saray', 'Hayrabolu', 'Şarköy', 'Muratlı', 'Marmaraereğlisi'
      ],
    },
    {
      'il': 'Tokat',
      'plaka': 60,
      'lat': 40.3167,
      'lon': 36.5500,
      'ilceler': [
        'Merkez', 'Erbaa', 'Turhal', 'Niksar', 'Zile', 'Reşadiye',
        'Almus', 'Pazar', 'Yeşilyurt', 'Artova', 'Sulusaray', 'Başçiftlik'
      ],
    },
    {
      'il': 'Trabzon',
      'plaka': 61,
      'lat': 41.0015,
      'lon': 39.7178,
      'ilceler': [
        'Ortahisar', 'Akçaabat', 'Araklı', 'Of', 'Yomra', 'Arsin',
        'Vakfıkebir', 'Sürmene', 'Maçka', 'Beşikdüzü', 'Çarşıbaşı', 'Tonya',
        'Düzköy', 'Çaykara', 'Şalpazarı', 'Hayrat', 'Köprübaşı', 'Dernekpazarı'
      ],
    },
    {
      'il': 'Tunceli',
      'plaka': 62,
      'lat': 39.1079,
      'lon': 39.5401,
      'ilceler': [
        'Merkez', 'Pertek', 'Mazgirt', 'Çemişgezek', 'Hozat', 'Ovacık',
        'Pülümür', 'Nazımiye'
      ],
    },
    {
      'il': 'Şanlıurfa',
      'plaka': 63,
      'lat': 37.1674,
      'lon': 38.7955,
      'ilceler': [
        'Eyyübiye', 'Haliliye', 'Siverek', 'Viranşehir', 'Karaköprü', 'Akçakale',
        'Suruç', 'Birecik', 'Ceylanpınar', 'Harran', 'Bozova', 'Hilvan', 'Halfeti'
      ],
    },
    {
      'il': 'Uşak',
      'plaka': 64,
      'lat': 38.6823,
      'lon': 29.4082,
      'ilceler': [
        'Merkez', 'Banaz', 'Eşme', 'Sivaslı', 'Ulubey', 'Karahallı'
      ],
    },
    {
      'il': 'Van',
      'plaka': 65,
      'lat': 38.4891,
      'lon': 43.4089,
      'ilceler': [
        'İpekyolu', 'Erciş', 'Tuşba', 'Edremit', 'Özalp', 'Çaldıran',
        'Başkale', 'Muradiye', 'Gürpınar', 'Gevaş', 'Saray', 'Çatak', 'Bahçesaray'
      ],
    },
    {
      'il': 'Yozgat',
      'plaka': 66,
      'lat': 39.8181,
      'lon': 34.8147,
      'ilceler': [
        'Merkez', 'Sorgun', 'Akdağmadeni', 'Yerköy', 'Boğazlıyan', 'Sarıkaya',
        'Çekerek', 'Şefaatli', 'Saraykent', 'Çayıralan', 'Kadışehri', 'Aydıncık',
        'Yenifakılı', 'Çandır'
      ],
    },
    {
      'il': 'Zonguldak',
      'plaka': 67,
      'lat': 41.4564,
      'lon': 31.7987,
      'ilceler': [
        'Ereğli', 'Merkez', 'Çaycuma', 'Devrek', 'Kozlu', 'Alaplı',
        'Kilimli', 'Gökçebey'
      ],
    },
    {
      'il': 'Aksaray',
      'plaka': 68,
      'lat': 38.3687,
      'lon': 34.0370,
      'ilceler': [
        'Merkez', 'Ortaköy', 'Eskil', 'Gülağaç', 'Güzelyurt', 'Ağaçören',
        'Sultanhanı', 'Sarıyahşi'
      ],
    },
    {
      'il': 'Bayburt',
      'plaka': 69,
      'lat': 40.2552,
      'lon': 40.2249,
      'ilceler': [
        'Merkez', 'Demirözü', 'Aydıntepe'
      ],
    },
    {
      'il': 'Karaman',
      'plaka': 70,
      'lat': 37.1759,
      'lon': 33.2287,
      'ilceler': [
        'Merkez', 'Ermenek', 'Sarıveliler', 'Ayrancı', 'Kazımkarabekir', 'Başyayla'
      ],
    },
    {
      'il': 'Kırıkkale',
      'plaka': 71,
      'lat': 39.8468,
      'lon': 33.5153,
      'ilceler': [
        'Merkez', 'Yahşihan', 'Keskin', 'Delice', 'Bahşılı', 'Sulakyurt',
        'Balışeyh', 'Karakeçili', 'Çelebi'
      ],
    },
    {
      'il': 'Batman',
      'plaka': 72,
      'lat': 37.8812,
      'lon': 41.1294,
      'ilceler': [
        'Merkez', 'Kozluk', 'Sason', 'Beşiri', 'Gercüş', 'Hasankeyf'
      ],
    },
    {
      'il': 'Şırnak',
      'plaka': 73,
      'lat': 37.5164,
      'lon': 42.4611,
      'ilceler': [
        'Cizre', 'Silopi', 'Merkez', 'İdil', 'Uludere', 'Beytüşşebap', 'Güçlükonak'
      ],
    },
    {
      'il': 'Bartın',
      'plaka': 74,
      'lat': 41.6344,
      'lon': 32.3375,
      'ilceler': [
        'Merkez', 'Ulus', 'Amasra', 'Kurucaşile'
      ],
    },
    {
      'il': 'Ardahan',
      'plaka': 75,
      'lat': 41.1105,
      'lon': 42.7022,
      'ilceler': [
        'Merkez', 'Göle', 'Çıldır', 'Hanak', 'Posof', 'Damal'
      ],
    },
    {
      'il': 'Iğdır',
      'plaka': 76,
      'lat': 39.9196,
      'lon': 44.0450,
      'ilceler': [
        'Merkez', 'Tuzluca', 'Aralık', 'Karakoyunlu'
      ],
    },
    {
      'il': 'Yalova',
      'plaka': 77,
      'lat': 40.6500,
      'lon': 29.2667,
      'ilceler': [
        'Merkez', 'Çiftlikköy', 'Çınarcık', 'Altınova', 'Armutlu', 'Termal'
      ],
    },
    {
      'il': 'Karabük',
      'plaka': 78,
      'lat': 41.2061,
      'lon': 32.6204,
      'ilceler': [
        'Merkez', 'Safranbolu', 'Yenice', 'Eskipazar', 'Eflani', 'Ovacık'
      ],
    },
    {
      'il': 'Kilis',
      'plaka': 79,
      'lat': 36.7184,
      'lon': 37.1212,
      'ilceler': [
        'Merkez', 'Musabeyli', 'Elbeyli', 'Polateli'
      ],
    },
    {
      'il': 'Osmaniye',
      'plaka': 80,
      'lat': 37.0742,
      'lon': 36.2472,
      'ilceler': [
        'Merkez', 'Kadirli', 'Düziçi', 'Bahçe', 'Toprakkale', 'Sumbas', 'Hasanbeyli'
      ],
    },
    {
      'il': 'Düzce',
      'plaka': 81,
      'lat': 40.8438,
      'lon': 31.1565,
      'ilceler': [
        'Merkez', 'Akçakoca', 'Kaynaşlı', 'Gölyaka', 'Çilimli', 'Yığılca',
        'Gümüşova', 'Cumayeri'
      ],
    },
  ];

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .trim();
  }

  /// Tüm iller ve ilçeler içinde arama yapar.
  static List<IlIlceItem> ara(String sorgu, {int limit = 20}) {
    final queryNorm = _normalize(sorgu);

    if (queryNorm.isEmpty) {
      // Boş sorguda popüler illeri ve ilk illeri göster
      return iller.take(limit).map((m) {
        return IlIlceItem(
          il: m['il'] as String,
          lat: (m['lat'] as num).toDouble(),
          lon: (m['lon'] as num).toDouble(),
        );
      }).toList();
    }

    final List<IlIlceItem> sonuclar = [];

    // 1. Önce doğrudan İl adı eşleşmeleri (En yüksek öncelik)
    for (final item in iller) {
      final ilAdi = item['il'] as String;
      final ilNorm = _normalize(ilAdi);
      final lat = (item['lat'] as num).toDouble();
      final lon = (item['lon'] as num).toDouble();

      if (ilNorm == queryNorm) {
        sonuclar.insert(0, IlIlceItem(il: ilAdi, lat: lat, lon: lon));
      } else if (ilNorm.startsWith(queryNorm)) {
        sonuclar.add(IlIlceItem(il: ilAdi, lat: lat, lon: lon));
      }
    }

    // 2. İlçe adı eşleşmeleri
    for (final item in iller) {
      final ilAdi = item['il'] as String;
      final lat = (item['lat'] as num).toDouble();
      final lon = (item['lon'] as num).toDouble();
      final ilceler = (item['ilceler'] as List<dynamic>?) ?? [];

      for (final ilce in ilceler) {
        final ilceAdi = ilce.toString();
        final ilceNorm = _normalize(ilceAdi);

        if (ilceNorm == queryNorm) {
          sonuclar.insert(0, IlIlceItem(il: ilAdi, ilce: ilceAdi, lat: lat, lon: lon));
        } else if (ilceNorm.startsWith(queryNorm)) {
          sonuclar.add(IlIlceItem(il: ilAdi, ilce: ilceAdi, lat: lat, lon: lon));
        } else if (ilceNorm.contains(queryNorm)) {
          sonuclar.add(IlIlceItem(il: ilAdi, ilce: ilceAdi, lat: lat, lon: lon));
        }

        if (sonuclar.length >= limit * 2) break;
      }
    }

    // 3. İl adı içerenler (içinde geçiyorsa)
    for (final item in iller) {
      final ilAdi = item['il'] as String;
      final ilNorm = _normalize(ilAdi);
      final lat = (item['lat'] as num).toDouble();
      final lon = (item['lon'] as num).toDouble();

      if (ilNorm.contains(queryNorm) && !sonuclar.any((s) => s.il == ilAdi && s.ilce == null)) {
        sonuclar.add(IlIlceItem(il: ilAdi, lat: lat, lon: lon));
      }
    }

    return sonuclar.take(limit).toList();
  }

  /// Türkiye'nin alfabetik sıralı 81 İl listesi
  static List<String> get tumIller {
    final list = iller.map((m) => m['il'] as String).toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  /// Seçilen İlin tüm ilçelerini döner (alfabetik sıralı)
  static List<String> getIlceler(String ilAdi) {
    final item = iller.firstWhere(
      (m) => _normalize(m['il'] as String) == _normalize(ilAdi),
      orElse: () => const {},
    );
    if (item.isEmpty) return const [];
    final ilceler = List<String>.from(item['ilceler'] as List<dynamic>? ?? []);
    ilceler.sort((a, b) => a.compareTo(b));
    return ilceler;
  }

  /// Belirtilen il ve ilçenin yaklaşık enlem/boylam koordinatlarını döner
  static IlIlceItem? getKonum({required String il, String? ilce}) {
    final item = iller.firstWhere(
      (m) => _normalize(m['il'] as String) == _normalize(il),
      orElse: () => const {},
    );
    if (item.isEmpty) return null;
    return IlIlceItem(
      il: item['il'] as String,
      ilce: ilce,
      lat: (item['lat'] as num).toDouble(),
      lon: (item['lon'] as num).toDouble(),
    );
  }

  /// WMO Hava Durumu Kodunu Türkçe açıklamaya çevirir
  static String getWeatherDesc(int code) {
    if (code == 0) return "Açık ve Güneşli";
    if (code == 1 || code == 2) return "Az / Parçalı Bulutlu";
    if (code == 3) return "Çok Bulutlu / Kapalı";
    if (code <= 48) return "Sisli ve Puslu";
    if (code <= 55) return "Hafif Çisenti";
    if (code <= 65) return "Yağmurlu";
    if (code <= 75) return "Kar Yağışlı";
    if (code <= 82) return "Kuvvetli Sağanak Yağış";
    if (code <= 86) return "Yoğun Kar Sağanağı";
    if (code <= 99) return "Gök Gürültülü Fırtına";
    return "Bulutlu";
  }

  /// WMO Hava Durumu Koduna uygun ikon döner
  static IconData getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code <= 48) return Icons.foggy;
    if (code <= 55) return Icons.water_drop_outlined;
    if (code <= 65) return Icons.water_drop_rounded;
    if (code <= 75) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.grain_rounded;
    if (code <= 86) return Icons.snowing;
    if (code <= 99) return Icons.thunderstorm_rounded;
    return Icons.wb_cloudy_rounded;
  }

  /// Şantiye sahasına özel hava durumu değerlendirmesi
  static String getSantiyeHavaYorumu(num temp, num windSpeed, int code) {
    if (temp <= 0) {
      return "⚠️ Don Riski: Sıcaklık sıfırın altında. Beton dökümünde antifriz ve sıcak tutma önlemleri zorunludur.";
    }
    if (code >= 80 || code >= 95) {
      return "⛈️ Fırtına / Şiddetli Yağış: Açık alanda çalışma, iskele ve vinç operasyonlarında azami dikkat gerekir.";
    }
    if (code >= 51 && code <= 77) {
      return "🌧️ Yağışlı / Karlı: Zemin kayganlaşabilir. Dış cephe, çatı ve hafriyat işlerini planlayarak yürütün.";
    }
    if (windSpeed >= 35) {
      return "💨 Şiddetli Rüzgar ($windSpeed km/s): Kule vinç ve yüksekte çalışma emniyet tedbirlerini gözden geçirin.";
    }
    if (temp >= 35) {
      return "☀️ Aşırı Sıcak: Taze betonda hızlı su kaybına karşı sulama (kür) sıklığını artırın ve işçi molalarını düzenleyin.";
    }
    return "✅ Saha Şartları Uygun: Açık hava inşaat ve montaj işleri için elverişli hava koşulları.";
  }

  /// Verilen il ve ilçe için Open-Meteo'dan anlık ve 7 günlük hava durumu çeker
  static Future<Map<String, dynamic>?> fetchWeather({
    required String il,
    String? ilce,
  }) async {
    try {
      double? lat;
      double? lon;

      // 1. Eğer ilçe varsa geocoding ile ilçenin tam koordinatını bulmayı dene
      if (ilce != null && ilce.trim().isNotEmpty && ilce != 'Merkez') {
        try {
          final query = Uri.encodeComponent('$ilce $il');
          final geoUrl = Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=$query&count=1&language=tr&format=json',
          );
          final geoRes = await http.get(geoUrl).timeout(const Duration(seconds: 4));
          if (geoRes.statusCode == 200) {
            final geoData = jsonDecode(geoRes.body);
            if (geoData['results'] != null && (geoData['results'] as List).isNotEmpty) {
              lat = (geoData['results'][0]['latitude'] as num).toDouble();
              lon = (geoData['results'][0]['longitude'] as num).toDouble();
            }
          }
        } catch (_) {}
      }

      // 2. İlçe bulunamadıysa veya merkez ise ilin yerel koordinatlarını al
      if (lat == null || lon == null) {
        final konum = getKonum(il: il, ilce: ilce);
        if (konum != null) {
          lat = konum.lat;
          lon = konum.lon;
        }
      }

      if (lat == null || lon == null) return null;

      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode,windspeed_10m_max&timezone=auto',
      );
      final weatherRes = await http.get(weatherUrl).timeout(const Duration(seconds: 5));

      if (weatherRes.statusCode == 200) {
        final wData = jsonDecode(weatherRes.body) as Map<String, dynamic>;
        final current = wData['current_weather'] as Map<String, dynamic>?;
        final daily = wData['daily'] as Map<String, dynamic>?;

        List<Map<String, dynamic>> gunlukList = [];
        if (daily != null && daily['time'] != null) {
          final times = daily['time'] as List;
          final maxes = daily['temperature_2m_max'] as List? ?? [];
          final mines = daily['temperature_2m_min'] as List? ?? [];
          final codes = daily['weathercode'] as List? ?? [];
          final winds = daily['windspeed_10m_max'] as List? ?? [];

          for (int i = 0; i < times.length; i++) {
            gunlukList.add({
              'time': times[i],
              'max': i < maxes.length ? maxes[i] : null,
              'min': i < mines.length ? mines[i] : null,
              'code': i < codes.length ? codes[i] : 0,
              'wind': i < winds.length ? winds[i] : 0,
            });
          }
        }

        return {
          'lat': lat,
          'lon': lon,
          'il': il,
          'ilce': ilce,
          'locationTitle': (ilce != null && ilce.isNotEmpty) ? '$ilce, $il' : il,
          'current': current,
          'daily': gunlukList,
          'temperature': current?['temperature'],
          'windspeed': current?['windspeed'],
          'weathercode': current?['weathercode'] ?? 0,
          'description': getWeatherDesc(current?['weathercode'] ?? 0),
          'sahaYorumu': getSantiyeHavaYorumu(
            current?['temperature'] ?? 20,
            current?['windspeed'] ?? 0,
            current?['weathercode'] ?? 0,
          ),
        };
      }
    } catch (e) {
      debugPrint("fetchWeather hatası: $e");
    }
    return null;
  }
}
