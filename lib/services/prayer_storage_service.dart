import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerStorageService {
  static const String key = 'saved_prayers';

  static Future<List<Map<String, dynamic>>> loadPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> savePrayer(Map<String, dynamic> prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = await loadPrayers();
    prayers.insert(0, prayer);
    await prefs.setString(key, json.encode(prayers));
  }

  static Future<void> deletePrayer(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = await loadPrayers();
    if (index >= 0 && index < prayers.length) {
      prayers.removeAt(index);
      await prefs.setString(key, json.encode(prayers));
    }
  }
}
