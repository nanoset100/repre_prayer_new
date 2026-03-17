import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/prayer_input_screen.dart';
import 'services/ad_manager.dart';

// 전역 에러 핸들러 설정
void setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // 사용자에게 노출되지 않도록 내부 로깅만 수행
    debugPrint('Flutter 에러: ${details.exception}');
  };

  // 비동기 에러 핸들러
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught 비동기 에러: $error');
    return true;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[main] Firebase 초기화 실패: $e');
  }

  try {
    await AdManager.instance.initialize();
  } catch (e) {
    debugPrint('[main] AdManager 초기화 실패: $e');
  }

  // 전역 에러 핸들링 설정
  setupErrorHandling();

  try {
    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    debugPrint('[ENV] .env 파일 로드 성공');
    debugPrint('[ENV] API KEY 길이: ${apiKey.length} (비어있음: ${apiKey.isEmpty})');
    if (apiKey.isEmpty) {
      debugPrint('[ENV] ⚠️ 경고: API 키가 비어있습니다!');
    } else {
      debugPrint('[ENV] ✓ API 키 정상 로드 (${apiKey.substring(0, 10)}...)');
    }
  } catch (e) {
    debugPrint('[ENV] ❌ 환경 설정 로드 실패: $e');
    // 사용자에게는 오류 메시지를 직접 노출하지 않음
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대표기도문 작성',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const NetworkAwareApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 네트워크 연결 상태 확인 래퍼
class NetworkAwareApp extends StatefulWidget {
  const NetworkAwareApp({super.key});

  @override
  State<NetworkAwareApp> createState() => _NetworkAwareAppState();
}

class _NetworkAwareAppState extends State<NetworkAwareApp> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 네트워크 체크 제거 - 실제 사용 시에만 체크하도록 변경
    // Google Play Store 환경에서 불필요한 경고를 방지
  }

  @override
  Widget build(BuildContext context) {
    return const PrayerInputScreen();
  }
}
