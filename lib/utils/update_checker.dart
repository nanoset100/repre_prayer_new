import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/remote_config_service.dart';

class UpdateChecker {
  static const String _skipKey = 'update_skip_until';

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      // Android: Google Play In-App Update 우선 시도
      if (Platform.isAndroid) {
        final handled = await _tryInAppUpdate(context);
        if (handled) return; // In-App Update로 처리 완료
      }

      // In-App Update 불가 시 기존 Remote Config 방식으로 폴백
      await _fallbackRemoteConfigUpdate(context);
    } catch (e) {
      debugPrint('[UpdateChecker] 체크 실패: $e');
    }
  }

  /// Google Play In-App Update (Android 전용)
  /// Play Store에 새 버전이 있으면 앱 안에서 바로 다운로드 & 설치
  static Future<bool> _tryInAppUpdate(BuildContext context) async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      debugPrint('[InAppUpdate] available: ${updateInfo.updateAvailability}');
      debugPrint('[InAppUpdate] immediateAllowed: ${updateInfo.immediateUpdateAllowed}');
      debugPrint('[InAppUpdate] flexibleAllowed: ${updateInfo.flexibleUpdateAllowed}');

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // 긴급 업데이트 (Immediate): 전체 화면, 자동 설치
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        }

        // 유연 업데이트 (Flexible): 백그라운드 다운로드, 재시작 안내
        if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // 다운로드 완료 후 설치 안내
          if (!context.mounted) return true;
          _showFlexibleCompleteSnackBar(context);
          return true;
        }
      }

      return false; // 업데이트 없음
    } catch (e) {
      debugPrint('[InAppUpdate] 실패 (Play Store 미지원 등): $e');
      return false; // In-App Update 불가 → 폴백
    }
  }

  /// Flexible 업데이트 다운로드 완료 후 재시작 안내
  static void _showFlexibleCompleteSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('업데이트가 다운로드되었습니다!'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: '재시작',
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }

  /// 기존 Remote Config 기반 업데이트 안내 (폴백)
  static Future<void> _fallbackRemoteConfigUpdate(BuildContext context) async {
    final rc = RemoteConfigService();
    final minVersion = rc.getMinVersion();
    final updateMsg = rc.getUpdateMsg();
    final updateUrl = rc.getUpdateUrl();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

    debugPrint('[UpdateChecker] 현재 버전: $currentVersionCode, 최소 버전: $minVersion');

    if (currentVersionCode >= minVersion) return;

    // "나중에" 누른 후 24시간 내에는 다시 안 보여주기
    final prefs = await SharedPreferences.getInstance();
    final skipUntil = prefs.getInt(_skipKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < skipUntil) {
      debugPrint('[UpdateChecker] 24시간 스킵 중');
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('💡 업데이트 안내'),
        content: Text(updateMsg),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setInt(
                _skipKey,
                DateTime.now()
                    .add(const Duration(hours: 24))
                    .millisecondsSinceEpoch,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text(
              '나중에',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(updateUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text(
              '업데이트 하러가기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
