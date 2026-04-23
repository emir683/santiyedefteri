import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static const String _androidWidgetName = 'KontrolMerkeziWidgetProvider';

  static Future<void> syncMonthSummary({
    required String ekipAdi,
    required DateTime tarih,
    required int raporGirilenGun,
    required int calisanSayisi,
    required int santiyeSayisi,
    required double odemeToplami,
    required double toplamMasraf,
    required bool finansalErisim,
    required bool privacyHidden,
  }) async {
    if (!Platform.isAndroid) return;

    final monthLabel = DateFormat.yMMMM('tr_TR').format(tarih);
    final paraFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL',
      decimalDigits: 0,
    );

    final odemeText =
        finansalErisim && !privacyHidden
            ? paraFormatter.format(odemeToplami)
            : 'Kilitli';
    final masrafText =
        finansalErisim && !privacyHidden
            ? paraFormatter.format(toplamMasraf)
            : 'Kilitli';

    await Future.wait([
      HomeWidget.saveWidgetData<String>('km_team_name', ekipAdi),
      HomeWidget.saveWidgetData<String>('km_month_label', monthLabel),
      HomeWidget.saveWidgetData<int>('km_report_days', raporGirilenGun),
      HomeWidget.saveWidgetData<int>('km_worker_count', calisanSayisi),
      HomeWidget.saveWidgetData<int>('km_site_count', santiyeSayisi),
      HomeWidget.saveWidgetData<String>('km_payment_total', odemeText),
      HomeWidget.saveWidgetData<String>('km_expense_total', masrafText),
      HomeWidget.saveWidgetData<bool>('km_finance_visible', finansalErisim),
    ]);

    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      qualifiedAndroidName:
          'com.emircf.santiyepuantaj.$_androidWidgetName',
    );
  }
}
