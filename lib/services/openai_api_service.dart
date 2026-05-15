import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIApiService {
  static const String _serverUrl = 'https://logosflow-production.up.railway.app';
  static const int _maxRetries = 2;
  static const Duration _timeout = Duration(seconds: 40);

  static String get _appKey => dotenv.env['APP_SECRET_KEY'] ?? '';

  static Future<String> generatePrayer(String prayerType) async {
    debugPrint('[Prayer] generatePrayer 호출: $prayerType');

    int retryCount = 0;
    Exception? lastException;

    while (retryCount <= _maxRetries) {
      try {
        final response = await http.post(
          Uri.parse('$_serverUrl/ai/prayer'),
          headers: {
            'Content-Type': 'application/json',
            'X-App-Key': _appKey,
          },
          body: jsonEncode({'prayer_type': prayerType}),
        ).timeout(_timeout);

        debugPrint('[Prayer] 응답 코드: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          return data['prayer'].toString().trim();
        } else if (response.statusCode == 429 || response.statusCode >= 500) {
          lastException = Exception('서버 응답 오류: ${response.statusCode}');
          retryCount++;
          if (retryCount <= _maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          }
        } else {
          throw Exception('API 요청 오류: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('[Prayer] 예외 발생 (시도 ${retryCount + 1}/${_maxRetries + 1}): $e');
        lastException = e is Exception ? e : Exception(e.toString());
        retryCount++;
        if (retryCount <= _maxRetries) {
          await Future.delayed(Duration(seconds: retryCount));
          continue;
        }
      }
    }

    debugPrint('[Prayer] ❌ 모든 재시도 실패: $lastException');
    throw Exception('AI 서비스가 일시적으로 불안정합니다. 잠시 후 다시 시도해주세요.');
  }
}
