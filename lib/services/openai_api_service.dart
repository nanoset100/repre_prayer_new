import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIApiService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> generatePrayer(String prompt) async {
    print('[OpenAI] generatePrayer 호출됨');
    print('[OpenAI] API KEY: [32m$_apiKey[0m');
    print('[OpenAI] 프롬프트: $prompt');
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''
당신은 교회 예배를 위한 대표기도문 작성을 도와주는 목사님입니다.
기도문의 길이는 천천히 읽었을 때 약 5분 정도 걸리도록 작성해주세요.
이를 위해 다음 사항을 꼭 지켜주세요:
1. '하느님'이라는 표현은 절대로 사용하지 말고, 항상 '하나님'으로 통일하여 표현합니다.
2. 기도의 마무리는 반드시 "예수님의 이름으로 기도합니다."라는 표현으로 끝내야 합니다.
3. 예배,찬양과 감사, 죄에 대한 고백, 회중 전체의 염원과 소망,말씀과 목회자을 담은 간구
4. 대표기도문에는 해당 예배 이름을 꼭 1회 이상 언급할 것 (예: 주일예배, 구역예배 등)
5. 각 문장마다 자연스러운 쉼표나 마침표를 사용하여 숨을 쉴 수 있도록 합니다.
6. 어려운 단어를 피하고 누구나 쉽게 이해할 수 있는 단어를 사용합니다.
7. 문단을 명확하게 나누어 전체적으로 깔끔한 느낌을 줍니다.
8. 핵심 메시지를 중심으로 문장을 구성하여 집중력을 유지할 수 있도록 합니다.
9. 기도의 흐름이 자연스럽고, 듣는 이의 마음에 잘 와닿도록 작성합니다.
10. 기도의 길이는 천천히 읽었을 때 약 5분 분량으로 (1000-1200자 단어).
11. 의미 없이 반복되는 표현을 피하고, 진심을 담아 정중하고 은혜롭게 작성해주세요.
12. 기도의 시작부터 마침까지 자연스러운 흐름을 유지하여 듣는 사람이 끝까지 집중할 수 있도록 합니다.
''',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 1500,
          'temperature': 0.7,
        }),
      );
      print('[OpenAI] 응답 코드: [34m${response.statusCode}[0m');
      print('[OpenAI] 응답 바디: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('OpenAI API 오류: ${response.body}');
      }
    } catch (e, st) {
      print('[OpenAI] 예외 발생: $e');
      print('[OpenAI] STACK: $st');
      rethrow;
    }
  }
}
