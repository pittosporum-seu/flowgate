import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyLocale = 'persisted_locale';

/// 语言设置：null 表示跟随系统
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null);

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLocale);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
  }

  /// 设置语言；null = 跟随系统
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale?.languageCode ?? '');
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());
