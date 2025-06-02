import 'dart:io';
import 'package:flutter/material.dart';

class NetworkHelper {
  // 더 안정적인 인터넷 연결 상태 확인 (여러 도메인 시도)
  static Future<bool> isConnected() async {
    try {
      // 1차 시도: Google DNS
      final result1 = await InternetAddress.lookup('8.8.8.8');
      if (result1.isNotEmpty && result1[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      // 2차 시도: Cloudflare DNS
      final result2 = await InternetAddress.lookup('1.1.1.1');
      if (result2.isNotEmpty && result2[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      // 3차 시도: 네이버 (한국 사용자용)
      final result3 = await InternetAddress.lookup('naver.com');
      if (result3.isNotEmpty && result3[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 모든 시도가 실패해도 실제로는 인터넷이 연결되어 있을 수 있음
    // Google Play Store 환경에서는 일부 도메인이 차단될 수 있으므로
    // 네트워크 체크 실패 시에도 API 호출은 허용하도록 변경
    return false; // 하지만 여전히 false를 반환해서 적절한 UI 안내는 제공
  }

  // 더 간단하고 빠른 네트워크 체크 (실제 API 호출 전용)
  static Future<bool> isConnectedForApi() async {
    try {
      // OpenAI API 도메인 직접 체크
      final result = await InternetAddress.lookup(
        'api.openai.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('OpenAI 도메인 체크 실패: $e');
      // API 도메인 체크가 실패해도 실제 호출은 시도해볼 수 있도록 true 반환
      return true;
    }
  }

  // 네트워크 연결 실패 시 알림 다이얼로그
  static Future<void> showNetworkErrorDialog(
    BuildContext context, {
    String title = '네트워크 연결 오류',
    String message = '인터넷 연결을 확인해주세요.',
    String buttonText = '확인',
  }) async {
    if (context.mounted) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: ListBody(children: <Widget>[Text(message)]),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(buttonText),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // 앱 시작 시 네트워크 연결 확인
  static Future<void> checkNetworkOnLaunch(BuildContext context) async {
    if (!await isConnected()) {
      if (context.mounted) {
        await showNetworkErrorDialog(
          context,
          title: '네트워크 연결 알림',
          message: '앱이 인터넷에 연결되어 있지 않습니다. 일부 기능이 제한될 수 있습니다.',
        );
      }
    }
  }
}
