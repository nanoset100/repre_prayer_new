import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  static const String _categoriesKey = 'worship_categories';
  static const String _minVersionKey = 'min_version';
  static const String _updateMsgKey = 'update_msg';
  static const String _updateUrlKey = 'update_url';

  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults({
        _categoriesKey: json.encode([
          "주일예배", "금요일예배", "구역예배", "새벽예배", "심방예배", "수요예배", "가정예배", "병원예배", "특별예배"
        ]),
        _minVersionKey: 125, // v1.1.14 빌드 번호
        _updateMsgKey: "새로운 기능(기독교 절기 반영 등)이 추가되었습니다. 최신 버전으로 업데이트하여 더욱 은혜로운 기도문을 만나보세요!",
        _updateUrlKey: "https://play.google.com/store/apps/details?id=com.nanoset.repre_prayer_app",
      });

      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 1),
      ));

      await fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfig] 초기화 실패: $e');
    }
  }

  Future<void> fetchAndActivate() async {
    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] 업데이트 성공');
    } catch (e) {
      debugPrint('[RemoteConfig] 페치 실패: $e');
    }
  }

  List<String> getCategories() {
    try {
      final jsonStr = _remoteConfig.getString(_categoriesKey);
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[RemoteConfig] 카테고리 파싱 실패: $e');
      return ["주일예배", "금요일예배", "구역예배", "새벽예배", "심방예배", "수요예배", "가정예배", "병원예배", "특별예배"];
    }
  }

  int getMinVersion() => _remoteConfig.getInt(_minVersionKey);
  String getUpdateMsg() => _remoteConfig.getString(_updateMsgKey);
  String getUpdateUrl() => _remoteConfig.getString(_updateUrlKey);
}
