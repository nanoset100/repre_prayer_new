import 'package:flutter/material.dart';
import '../models/prayer_model.dart';
import '../utils/storage_service.dart';
import 'prayer_detail_screen.dart';

class PrayerListScreen extends StatefulWidget {
  const PrayerListScreen({super.key});

  @override
  State<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends State<PrayerListScreen> {
  List<PrayerModel> prayers = [];

  @override
  void initState() {
    super.initState();
    _loadPrayers();
  }

  Future<void> _loadPrayers() async {
    try {
      final loaded = await StorageService.loadPrayers();
      if (!mounted) return;
      setState(() {
        prayers = loaded;
      });
    } catch (e) {
      debugPrint('기도문 로드 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기도문을 불러오는 중 오류가 발생했습니다.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deletePrayer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('삭제 확인'),
            content: const Text('정말로 이 기도문을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    
    try {
      await StorageService.deletePrayer(id);
      await _loadPrayers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제되었습니다'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    } catch (e) {
      debugPrint('기도문 삭제 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제에 실패했습니다. 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
        backgroundColor: const Color(0xFFFFF4F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
            onPressed: () {
               if (Navigator.of(context).canPop()) {
                 Navigator.of(context).pop();
               } else {
                 // 갈 곳이 없다면 무조건 닫기 (메인으로 추락되는 것 방지, 혹은 메인화면 pushReplacement 옵션 등)
                 Navigator.of(context).maybePop();
               }
            },
          ),
          centerTitle: true,
          title: const Text(
            '저장된 기도문',
            style: TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        body:
            prayers.isEmpty
                ? const Center(
                  child: Text(
                    '저장된 기도문이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prayers.length,
                  itemBuilder: (context, idx) {
                    final prayer = prayers[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrayerDetailScreen(prayer: prayer),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFD4F4E0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '[${prayer.date}]',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF218C5A),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      prayer.prayerType,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF21A366),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  margin: const EdgeInsets.only(right: 32),
                                  child: Text(
                                    prayer.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _deletePrayer(prayer.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
