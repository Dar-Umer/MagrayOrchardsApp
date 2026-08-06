import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme_config.dart';
import '../services/api_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _paletteName = 'emerald';
  String _fontFamily = 'Inter';
  bool _isLoading = false;

  String get paletteName => _paletteName;
  String get fontFamily => _fontFamily;
  bool get isLoading => _isLoading;

  ThemeData get themeData => ThemeConfig.buildThemeData(
        paletteName: _paletteName,
        fontFamily: _fontFamily,
      );

  Map<int, Color> get paletteColors => ThemeConfig.getPaletteColors(_paletteName);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _paletteName = prefs.getString('theme_palette') ?? 'emerald';
    _fontFamily = prefs.getString('theme_font') ?? 'Inter';
    notifyListeners();

    _fetchFromServer();
  }

  Future<void> _fetchFromServer() async {
    try {
      final response = await ApiService.get('/settings/theme');
      final data = response['data'] ?? response;
      final palette = data['theme_palette'] as String?;
      final font = data['font_family'] as String?;

      bool changed = false;
      if (palette != null && ThemeConfig.palettes.containsKey(palette) && palette != _paletteName) {
        _paletteName = palette;
        changed = true;
      }
      if (font != null && ThemeConfig.fonts.containsKey(font) && font != _fontFamily) {
        _fontFamily = font;
        changed = true;
      }

      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_palette', _paletteName);
        await prefs.setString('theme_font', _fontFamily);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setPalette(String name) async {
    if (!ThemeConfig.palettes.containsKey(name)) return;
    _paletteName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_palette', name);
    notifyListeners();
  }

  Future<void> setFont(String name) async {
    if (!ThemeConfig.fonts.containsKey(name)) return;
    _fontFamily = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_font', name);
    notifyListeners();
  }
}
