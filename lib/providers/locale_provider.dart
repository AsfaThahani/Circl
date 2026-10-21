import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale type) {
    if (_locale == type) return;
    _locale = type;
    notifyListeners();
  }
}
