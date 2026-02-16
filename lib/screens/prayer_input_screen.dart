import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_model.dart';
import '../utils/storage_service.dart';
import '../utils/network_helper.dart';
import 'prayer_list_screen.dart';
import '../services/openai_api_service.dart';

class PrayerInputScreen extends StatefulWidget {
  const PrayerInputScreen({super.key});

  @override
  State<PrayerInputScreen> createState() => _PrayerInputScreenState();
}

class _PrayerInputScreenState extends State<PrayerInputScreen> {
  final List<Map<String, dynamic>> categories = [
    {'label': '주일예배', 'icon': Icons.wb_sunny},
    {'label': '금요예배', 'icon': Icons.star},
    {'label': '구역예배', 'icon': Icons.groups},
    {'label': '새벽예배', 'icon': Icons.brightness_5},
    {'label': '심방예배', 'icon': Icons.home_repair_service},
    {'label': '수요예배', 'icon': Icons.water_drop},
    {'label': '가정예배', 'icon': Icons.home},
    {'label': '병원예배', 'icon': Icons.local_hospital},
    {'label': '특별예배', 'icon': Icons.event},
  ];

  int selectedIndex = 3;
  final TextEditingController prayerTypeController = TextEditingController();
  final TextEditingController prayerContentController = TextEditingController();
  bool _isLoading = false;
  String? _lastAiPrayer;
  bool _isPrayerTypeEditable = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedPrayerType();
    prayerTypeController.text = categories[selectedIndex]['label'];
  }

  Future<void> _loadSelectedPrayerType() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString('selectedPrayerType');
    if (selected != null) {
      final idx = categories.indexWhere((c) => c['label'] == selected);
      if (idx != -1) {
        setState(() {
          selectedIndex = idx;
          prayerTypeController.text = categories[idx]['label'];
        });
      }
    }
  }

  Future<void> _saveSelectedPrayerType(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPrayerType', categories[idx]['label']);
    // ignore: avoid_print
    // print(
    //   '[SharedPreferences] selectedPrayerType: ${categories[idx]['label']}',
    // );
  }

  void onPrayerTypeSelected(String type) {
    setState(() {
      if (type == '특별예배') {
        prayerTypeController.text = '';
        _isPrayerTypeEditable = true;
      } else {
        prayerTypeController.text = type;
        _isPrayerTypeEditable = false;
      }
    });
  }

  void _onCategoryTap(int idx) async {
    setState(() {
      selectedIndex = idx;
      if (categories[idx]['label'] == '특별예배') {
        prayerTypeController.text = '';
        _isPrayerTypeEditable = true;
      } else {
        prayerTypeController.text = categories[idx]['label'];
        _isPrayerTypeEditable = false;
      }
    });
    await _saveSelectedPrayerType(idx);
  }

  Future<void> _savePrayer() async {
    final content = prayerContentController.text.trim();
    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용을 입력하세요')));
      return;
    }
    
    // 예배 타입 확인
    final prayerType = prayerTypeController.text.trim();
    if (prayerType.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예배 종류를 선택하세요')));
      return;
    }
    
    try {
      final now = DateTime.now();
      final prayer = PrayerModel(
        id: now.microsecondsSinceEpoch.toString(),
        date: DateFormat('yyyy.MM.dd').format(now),
        prayerType: prayerType,
        content: content,
      );
      await StorageService.savePrayer(prayer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장 완료'),
          duration: Duration(milliseconds: 1000),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      prayerContentController.clear();
      setState(() {
        _lastAiPrayer = null;
      });
      // 1초 후 자동으로 PrayerListScreen으로 이동
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PrayerListScreen()),
          );
        }
      });
    } catch (e) {
      debugPrint('기도문 저장 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getAiPrayer() async {
    if (_isLoading) return;
    final prayerType = prayerTypeController.text.trim();
    // 특별예배일 때 예배명 미입력 시 안내
    if (_isPrayerTypeEditable && prayerType.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예배이름을 입력하세요.')));
      return;
    }
    setState(() => _isLoading = true);

    // 네트워크 연결 상태 확인 (더 관대한 체크)
    await NetworkHelper.isConnectedForApi();

    // 네트워크 체크가 실패해도 실제 API 호출은 시도
    // Google Play Store 환경에서는 도메인 체크가 실패할 수 있지만
    // 실제 API는 작동할 수 있기 때문
    try {
      final aiResult = await OpenAIApiService.generatePrayer(prayerType);
      setState(() {
        prayerContentController.text = aiResult;
        _lastAiPrayer = aiResult;
      });
    } catch (e) {
      debugPrint('AI 생성 실패: $e');
      if (mounted) {
        // 네트워크 오류인지 확인
        final isNetworkError = e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException') ||
            e.toString().contains('연결');

        final errorMessage = isNetworkError
            ? '인터넷 연결을 확인해주세요.\n네트워크가 불안정하거나 연결이 끊어졌습니다.\n\n'
                'Please check your internet connection.\nNetwork is unstable or disconnected.'
            : 'AI 서비스가 일시적으로 불안정합니다.\n잠시 후 다시 시도해주세요.\n\n'
                'AI service is temporarily unavailable.\nPlease try again in a moment.';

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('기도문 생성 안내\n(Prayer Generation Notice)'),
                content: Text(
                  '$errorMessage\n샘플 기도문을 대신 사용하시겠어요?\nWould you like to use a sample prayer instead?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _insertSamplePrayer(prayerType);
                    },
                    child: const Text('예 (Yes)'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('아니오 (No)'),
                  ),
                ],
              ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _insertSamplePrayer(String prayerType) {
    String samplePrayer =
        '사랑과 은혜의 하나님, 이 시간 저희 예배를 받아주시옵소서.\n주님의 은혜와 사랑이 우리 모두에게 충만하게 임하게 하시고,\n말씀을 통해 새 힘을 얻게 하소서.\n예수님의 이름으로 기도합니다. 아멘.';
    setState(() {
      prayerContentController.text = samplePrayer;
      _lastAiPrayer = samplePrayer;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('샘플 기도문이 입력되었습니다. (Sample prayer inserted)'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color gridBg = const Color(0xFFD4F4E0);
    final Color gridSelected = const Color(0xFFA0E7C3);
    final Color mainGreen = const Color(0xFF4CAF50);
    final Color viewBtnBorder = const Color(0xFFD4F4E0);
    final Color viewBtnText = const Color(0xFF218C5A);
    final Color saveBtnBg = const Color(0xFFEAEAEA);
    final double gridBtnSize = MediaQuery.of(context).size.width / 3 - 28;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '대표기도문 작성하기',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: mainGreen,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 9개 예배 버튼
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, idx) {
                      final isSelected = selectedIndex == idx;
                      return GestureDetector(
                        onTap: () => _onCategoryTap(idx),
                        child: Container(
                          width: gridBtnSize,
                          height: gridBtnSize,
                          decoration: BoxDecoration(
                            color: isSelected ? gridSelected : gridBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: mainGreen, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                categories[idx]['icon'],
                                color: isSelected ? mainGreen : Colors.black54,
                                size: 32,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                categories[idx]['label'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: isSelected ? mainGreen : Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                // 선택된 예배명 텍스트필드 (중앙 초기화 아이콘 복구)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prayerTypeController,
                        decoration: InputDecoration(
                          hintText: _isPrayerTypeEditable ? '예배이름을 입력하세요' : '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: mainGreen, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        readOnly: !_isPrayerTypeEditable,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: mainGreen, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF4CAF50),
                        ),
                        iconSize: 26,
                        splashRadius: 24,
                        onPressed: () {
                          setState(() {
                            prayerTypeController.clear();
                            _lastAiPrayer = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 기도문 입력 필드
                TextField(
                  controller: prayerContentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '기도문을 저장하고 크게 보세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: mainGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 18),
                // 버튼 2개
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading ||
                                    (_isPrayerTypeEditable &&
                                        prayerTypeController.text
                                            .trim()
                                            .isEmpty))
                                ? null
                                : _getAiPrayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gridBg,
                          foregroundColor: mainGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('🙏 AI 도움받기'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savePrayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saveBtnBg,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          side: BorderSide(color: Colors.grey[300]!, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        child: const Text('저장하기'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 내 기도문 보기 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrayerListScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.menu_book, color: viewBtnText, size: 24),
                    label: Text(
                      '내 기도문 보기',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: viewBtnText,
                        fontSize: 17,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: viewBtnBorder, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // 생성된 기도문 박스 (AI 생성 시 표시)
                if (_lastAiPrayer != null && _lastAiPrayer!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: gridBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _lastAiPrayer!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
