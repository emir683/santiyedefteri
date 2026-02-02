import 'package:flutter/material.dart';

class PrivacyProvider with ChangeNotifier {
  bool _isHidden = false;

  bool get isHidden => _isHidden;

  void togglePrivacy() {
    _isHidden = !_isHidden;
    notifyListeners();
  }
}