import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  // 최소 요구 버전 (이 버전 미만이면 팝업 표시)
  static const int minimumVersionCode = 113; // v1.1.2

  // Google Play 스토어 링크
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.nanoset.repre_prayer_app';

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.parse(packageInfo.buildNumber);

      debugPrint('[UPDATE] 현재 버전: $currentBuild, 최소 버전: $minimumVersionCode');

      if (currentBuild < minimumVersionCode) {
        debugPrint('[UPDATE] ⚠️ 구버전 감지! 업데이트 팝업 표시');
        if (context.mounted) {
          showUpdateDialog(context);
        }
      } else {
        debugPrint('[UPDATE] ✓ 최신 버전 사용 중');
      }
    } catch (e) {
      debugPrint('[UPDATE] ❌ 버전 체크 실패: $e');
    }
  }

  static void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 클릭으로 닫기 불가
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('🙏', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('업데이트 안내'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI 기도문 생성 기능이 개선되었습니다.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '정상적인 서비스 이용을 위해\nPlay 스토어에서 최신 버전으로\n업데이트해 주세요.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '업데이트 후 AI 기도문이\n정상 작동됩니다.',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 나중에 버튼 - 앱은 계속 사용 가능하되 AI 기능만 제한
              Navigator.pop(context);
            },
            child: const Text(
              '나중에',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(playStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              'Play 스토어 업데이트',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
