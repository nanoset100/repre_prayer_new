import 'package:flutter/material.dart';
import '../models/prayer_model.dart';

class PrayerDetailScreen extends StatelessWidget {
  final PrayerModel prayer;
  const PrayerDetailScreen({super.key, required this.prayer});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
               if (Navigator.of(context).canPop()) {
                 Navigator.of(context).pop();
               } else {
                 Navigator.of(context).maybePop();
               }
            },
          ),
          title: const Text(
            '기도문 전체 보기',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: const Color(0xFFFFF4F8),
        bottomNavigationBar: SizedBox(height: 60 + MediaQuery.of(context).viewPadding.bottom), // 배너 광고 높이 + 하단 안전 영역
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F4E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prayer.date,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF218C5A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                prayer.prayerType,
                style: const TextStyle(
                  color: Color(0xFF21A366),
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                prayer.content,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
