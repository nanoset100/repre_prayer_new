import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIApiService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const int _maxRetries = 2; // 최대 재시도 횟수
  static const Duration _timeout = Duration(seconds: 30); // API 타임아웃

  static Future<String> generatePrayer(String prayerType) async {
    // print('[OpenAI] generatePrayer 호출됨');
    // print('[OpenAI] API KEY: \x1B[32m"+_apiKey+"\x1B[0m');
    // print('[OpenAI] 예배명: $prayerType');

    // 재시도 로직
    int retryCount = 0;
    Exception? lastException;

    while (retryCount <= _maxRetries) {
      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'store': false,
            'model': 'gpt-4o-mini',
            'messages': [
              {
                'role': 'system',
                'content': '''
당신은 교회 예배를 위한 대표기도문 작성을 도와주는 목사님입니다.
기도문의 길이는 천천히 읽었을 때 약 5분 정도 걸리도록 작성해주세요.
이를 위해 다음 사항을 꼭 지켜주세요:
1. '하느님'이라는 표현은 절대로 사용하지 말고, 항상 '하나님'으로 통일하여 표현합니다.
2. 기도의 마무리는 반드시 "예수님의 이름으로 기도합니다."라는 표현으로 끝내야 합니다.
3. 예배, 찬양과 감사, 죄에 대한 고백, 회중 전체의 염원과 소망, 말씀과 목회자를 담은 간구.
4. 대표기도문에는 반드시 입력한 예배 이름 "$prayerType"을(를) 1회 이상 언급해주세요.
5. 각 문장마다 자연스러운 쉼표나 마침표를 사용하여 숨을 쉴 수 있도록 합니다.
6. 어려운 단어를 피하고 누구나 쉽게 이해할 수 있는 단어를 사용합니다.
7. 문단을 명확하게 나누어 전체적으로 깔끔한 느낌을 줍니다.
8. 핵심 메시지를 중심으로 문장을 구성하여 집중력을 유지할 수 있도록 합니다.
9. 기도의 흐름이 자연스럽고, 듣는 이의 마음에 잘 와닿도록 작성합니다.
10. 기도의 길이는 천천히 읽었을 때 약 5분 분량으로 (1000-1200자).
11. 의미 없이 반복되는 표현을 피하고, 진심을 담아 정중하고 은혜롭게 작성해주세요.
12. 기도의 시작부터 마침까지 자연스러운 흐름을 유지하여 듣는 사람이 끝까지 집중할 수 있도록 합니다.
''',
              },
              {'role': 'user', 'content': '대표기도문을 작성해주세요.'},
            ],
            'max_tokens': 2000,
            'temperature': 0.7,
          }),
        ).timeout(_timeout); // 타임아웃 설정

        // print(
        //   '[OpenAI] 응답 코드: \x1B[34m${response.statusCode}\x1B[0m',
        // );
        // print('[OpenAI] 응답 바디: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['choices'][0]['message']['content'].toString().trim();
        } else if (response.statusCode == 429 || response.statusCode >= 500) {
          // 429 (Too Many Requests) 또는 5xx 서버 오류는 재시도
          lastException = Exception('서버 응답 오류: ${response.statusCode}');
          retryCount++;
          if (retryCount <= _maxRetries) {
            await Future.delayed(Duration(seconds: retryCount)); // 점진적 대기
            continue;
          }
        } else {
          // 4xx 클라이언트 오류는 재시도 없이 즉시 실패
          throw Exception('API 요청 오류: ${response.statusCode}');
        }
      } catch (e) {
        // print('[OpenAI] 예외 발생 (시도 ${retryCount + 1}/${_maxRetries + 1}): $e');
        lastException = e is Exception ? e : Exception(e.toString());
        retryCount++;

        if (retryCount <= _maxRetries) {
          await Future.delayed(Duration(seconds: retryCount)); // 점진적 대기
          continue;
        }
      }
    }

    // 모든 재시도 실패
    // print('[OpenAI] 모든 재시도 실패');
    throw Exception('AI 서비스가 일시적으로 불안정합니다. 잠시 후 다시 시도해주세요.');
  }
}
