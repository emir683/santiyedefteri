// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class WebInstallHelper {
  static bool get isIosSafari {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isAppleMobile =
        ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    final isSafari =
        ua.contains('safari') &&
        !ua.contains('crios') &&
        !ua.contains('fxios') &&
        !ua.contains('edgios');
    return isAppleMobile && isSafari;
  }

  static bool get shouldShowInstallCard {
    if (!isIosSafari) return false;
    final standalone = html.window.matchMedia('(display-mode: standalone)').matches;
    return !standalone;
  }
}
