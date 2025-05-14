import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/prayer_input_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    print(
      'API KEY: [32m[1m[4m[7m${dotenv.env['OPENAI_API_KEY']}[0m',
    ); // 실제 값 확인용
  } catch (e, st) {
    print('dotenv [31m로드 실패[0m: $e');
    print('STACK: $st');
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
      home: const PrayerInputScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
