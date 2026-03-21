
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:adx_sdk/adx_sdk.dart';

// ⚠️ 에러 해결의 핵심 2: 파일을 절대 못 찾을 수 없도록 '프로젝트 이름'을 포함한 정확한 주소를 적었습니다.
import 'package:repre_prayer_new/screens/prayer_input_screen.dart';

void main() async {
  // 플러그인 초기화 확인
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase 초기화
  try {
    await Firebase.initializeApp();
    debugPrint('[main] Firebase 성공');
  } catch (e) {
    debugPrint('[main] Firebase 실패: $e');
  }

  // 2. AD(x) SDK 초기화 (Android 전용)
  if (Platform.isAndroid) {
    try {
      await AdxSdk.initialize(
        "69b8f240f57ff90001000012",              // AD(x) APP ID
        AdxCommon.gdprTypeDirectNotRequired,     // 한국 (비EEA) — 동의창 불필요
        [],                                      // 테스트 기기 ID
      );
      debugPrint('[main] AD(x) 초기화 성공');
    } catch (e) {
      debugPrint('[main] AD(x) 초기화 실패: $e');
    }
  }

  // 3. 환경 변수(.env) 로드
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('[main] dotenv 성공');
  } catch (e) {
    debugPrint('[main] dotenv 실패: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대표기도문 작성',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      // 시작 화면 설정 (원래대로 const를 붙여 안정성을 높였습니다)
      home: const PrayerInputScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}