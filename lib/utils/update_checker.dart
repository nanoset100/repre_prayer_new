import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';

class UpdateChecker {
  static Future<void> checkUpdate(BuildContext context) async {
    try {
      final rc = RemoteConfigService();
      final minVersion = rc.getMinVersion();
      final updateMsg = rc.getUpdateMsg();
      final updateUrl = rc.getUpdateUrl();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('[UpdateChecker] 현재 버전: $currentVersionCode, 최소 버전: $minVersion');

      if (currentVersionCode < minVersion) {
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('💡 업데이트 안내'),
            content: Text(updateMsg),
            actions: [
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(updateUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('업데이트 하러가기', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('[UpdateChecker] 체크 실패: $e');
    }
  }
}
