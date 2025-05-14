import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_model.dart';

class StorageService {
  static const String key = 'saved_prayers';

  static Future<List<PrayerModel>> loadPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> decoded = json.decode(jsonStr);
    return PrayerModel.listFromJson(decoded);
  }

  static Future<void> savePrayer(PrayerModel prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = await loadPrayers();
    prayers.insert(0, prayer);
    await prefs.setString(key, json.encode(PrayerModel.listToJson(prayers)));
  }

  static Future<void> deletePrayer(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final prayers = await loadPrayers();
    prayers.removeWhere((e) => e.id == id);
    await prefs.setString(key, json.encode(PrayerModel.listToJson(prayers)));
  }
}
