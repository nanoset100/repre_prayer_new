import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_model.dart';

class StorageService {
  static const String key = 'saved_prayers';
  static const String versionKey = 'app_data_version';
  static const int currentDataVersion = 1; // 현재 데이터 버전

  // 데이터 버전 확인 및 마이그레이션
  static Future<void> _migrateDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(versionKey) ?? 0;
    
    if (savedVersion < currentDataVersion) {
      // 버전이 다르면 마이그레이션 수행
      try {
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          final List<dynamic> decoded = json.decode(jsonStr);
          
          // 이전 버전의 데이터 형식 확인 및 변환
          // 현재는 데이터 형식이 동일하지만, 향후 변경 시 여기서 처리
          if (decoded.isNotEmpty) {
            // 데이터 검증 및 정리
            final validData = decoded.where((item) {
              return item is Map<String, dynamic> &&
                  item.containsKey('id') &&
                  item.containsKey('date') &&
                  item.containsKey('prayerType') &&
                  item.containsKey('content');
            }).toList();
            
            if (validData.length != decoded.length) {
              // 잘못된 데이터가 있으면 정리된 데이터로 저장
              await prefs.setString(key, json.encode(validData));
            }
          }
        }
        
        // 버전 업데이트
        await prefs.setInt(versionKey, currentDataVersion);
      } catch (e) {
        // 마이그레이션 실패 시 로그만 남기고 계속 진행
        // 사용자 데이터를 보호하기 위해 기존 데이터는 유지
        print('데이터 마이그레이션 중 오류 발생: $e');
      }
    }
  }

  static Future<List<PrayerModel>> loadPrayers() async {
    // 마이그레이션 먼저 수행
    await _migrateDataIfNeeded();
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return PrayerModel.listFromJson(decoded);
    } catch (e) {
      // JSON 파싱 오류 시 빈 리스트 반환 (데이터 손실 방지)
      print('기도문 데이터 로드 중 오류 발생: $e');
      return [];
    }
  }

  static Future<void> savePrayer(PrayerModel prayer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prayers = await loadPrayers();
      prayers.insert(0, prayer);
      await prefs.setString(key, json.encode(PrayerModel.listToJson(prayers)));
      // 데이터 버전도 함께 저장 (이미 마이그레이션에서 설정되지만 안전을 위해)
      await prefs.setInt(versionKey, currentDataVersion);
    } catch (e) {
      print('기도문 저장 중 오류 발생: $e');
      rethrow; // 저장 실패는 사용자에게 알려야 함
    }
  }

  static Future<void> deletePrayer(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prayers = await loadPrayers();
      prayers.removeWhere((e) => e.id == id);
      await prefs.setString(key, json.encode(PrayerModel.listToJson(prayers)));
    } catch (e) {
      print('기도문 삭제 중 오류 발생: $e');
      rethrow; // 삭제 실패는 사용자에게 알려야 함
    }
  }
  
  // 데이터 백업 (향후 기능 확장용)
  static Future<String> exportData() async {
    final prayers = await loadPrayers();
    return json.encode(PrayerModel.listToJson(prayers));
  }
  
  // 데이터 복원 (향후 기능 확장용)
  static Future<void> importData(String jsonData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<dynamic> decoded = json.decode(jsonData);
      final prayers = PrayerModel.listFromJson(decoded);
      await prefs.setString(key, json.encode(PrayerModel.listToJson(prayers)));
      await prefs.setInt(versionKey, currentDataVersion);
    } catch (e) {
      print('데이터 복원 중 오류 발생: $e');
      rethrow;
    }
  }
}
