import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_model.dart';
import '../utils/storage_service.dart';
import '../utils/network_helper.dart';
import '../utils/update_checker.dart';
import 'prayer_list_screen.dart';
import '../services/openai_api_service.dart';
import '../services/remote_config_service.dart';
import 'package:adx_sdk/adx_sdk.dart';

class PrayerInputScreen extends StatefulWidget {
  const PrayerInputScreen({super.key});

  @override
  State<PrayerInputScreen> createState() => _PrayerInputScreenState();
}

class _PrayerInputScreenState extends State<PrayerInputScreen> {
  static const String _adxBannerUnitId = "69b8f24ecb688c8ca0286bcd";

  List<Map<String, dynamic>> categories = [];
  final Map<String, IconData> _iconMap = {
    '주일예배': Icons.wb_sunny,
    '금요예배': Icons.star,
    '금요일예배': Icons.star,
    '구역예배': Icons.groups,
    '새벽예배': Icons.brightness_5,
    '심방예배': Icons.home_repair_service,
    '수요예배': Icons.water_drop,
    '가정예배': Icons.home,
    '병원예배': Icons.local_hospital,
    '특별예배': Icons.event,
  };

  int selectedIndex = 3;
  final TextEditingController prayerTypeController = TextEditingController();
  final TextEditingController prayerContentController = TextEditingController();
  bool _isLoading = false;
  String? _lastAiPrayer;
  bool _isPrayerTypeEditable = false;

  @override
  void initState() {
    super.initState();
    _initRemoteConfig();
    _loadSelectedPrayerType();
    // 초기값 설정 (가져오는 동안 빈 화면 방지)
    categories = [
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
    _updatePrayerTypeUI(selectedIndex);
    _loadAdxBanner();
  }

  void _loadAdxBanner() {
    if (!Platform.isAndroid) return;
    AdxSdk.setBannerPosition(_adxBannerUnitId, AdxCommon.positionBottomCenter);
    AdxSdk.loadBannerAd(_adxBannerUnitId, AdxCommon.size_320x50);
  }

  @override
  void dispose() {
    if (Platform.isAndroid) AdxSdk.destroyBannerAd(_adxBannerUnitId);
    prayerTypeController.dispose();
    prayerContentController.dispose();
    super.dispose();
  }

  void _updatePrayerTypeUI(int idx) {
    if (idx < 0 || idx >= categories.length) return;
    
    setState(() {
      selectedIndex = idx;
      final label = categories[idx]['label'];
      if (label == '특별예배') {
        prayerTypeController.text = '';
        _isPrayerTypeEditable = true;
      } else {
        prayerTypeController.text = label;
        _isPrayerTypeEditable = false;
      }
    });
  }

  Future<void> _initRemoteConfig() async {
    final rc = RemoteConfigService();
    await rc.initialize();
    _updateCategories();
    if (mounted) {
      UpdateChecker.checkUpdate(context);
    }
  }

  void _updateCategories() {
    final rc = RemoteConfigService();
    final labels = rc.getCategories();
    setState(() {
      categories = labels.map((label) {
        return {
          'label': label,
          'icon': _iconMap[label] ?? Icons.church, // 매칭되는 아이콘 없으면 기본 아이콘
        };
      }).toList();
      
      // 선택된 인덱스 범위 확인
      if (selectedIndex >= categories.length) {
        selectedIndex = 0;
      }
    });
    _updatePrayerTypeUI(selectedIndex);
  }

  Future<void> _loadSelectedPrayerType() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString('selectedPrayerType');
    if (selected != null) {
      final idx = categories.indexWhere((c) => c['label'] == selected);
      if (idx != -1) {
        _updatePrayerTypeUI(idx);
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
    final idx = categories.indexWhere((c) => c['label'] == type);
    if (idx != -1) {
      _updatePrayerTypeUI(idx);
    }
  }

  void _onCategoryTap(int idx) async {
    _updatePrayerTypeUI(idx);
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
          Navigator.of(context).push(
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
        // API 실패 시 자동으로 샘플 기도문 삽입 (에러 다이얼로그 없이 자연스럽게 처리)
        _insertSamplePrayer(prayerType);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI 연결 중 문제가 발생하여 샘플 기도문을 제공합니다. 내용을 수정하여 사용하세요.'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF795548),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _insertSamplePrayer(String prayerType) {
    final displayType = prayerType.isNotEmpty ? prayerType : '예배';
    String samplePrayer =
        '사랑과 은혜가 풍성하신 하나님 아버지, 오늘 이 $displayType 시간에 저희를 불러주시고 함께해 주심을 감사드립니다.\n\n'
        '주님, 바쁜 일상 속에서도 이렇게 주님 앞에 나아올 수 있는 은혜에 감사합니다. '
        '저희의 마음을 열어주시고, 주님의 말씀 앞에 겸손히 서게 하여 주옵소서.\n\n'
        '하나님, 저희의 부족함과 연약함을 고백합니다. '
        '때로는 주님의 뜻보다 저희의 생각을 앞세우고, 이웃을 사랑하기보다 자신만을 돌아보았습니다. '
        '이 시간 저희의 허물을 용서하시고, 새롭게 하여 주옵소서.\n\n'
        '이 자리에 함께한 모든 성도들의 가정과 삶 위에 주님의 평강이 임하게 하시고, '
        '아픈 분들에게는 치유의 손길을, 어려움 가운데 있는 분들에게는 위로와 힘을 더하여 주옵소서. '
        '오늘 전해주실 말씀을 통해 저희 삶이 변화되고, 주님의 뜻대로 살아가는 저희가 되게 하여 주옵소서.\n\n'
        '이 모든 말씀을 우리 주 예수 그리스도의 이름으로 기도합니다. 아멘.';
    setState(() {
      prayerContentController.text = samplePrayer;
      _lastAiPrayer = samplePrayer;
    });
  }

  Future<bool> _showCloseAd() async {
    const platform = MethodChannel('com.nanoset.repre_prayer_app/close_ad');
    try {
      final bool? result = await platform.invokeMethod<bool>('showCloseAd');
      return result ?? false;
    } catch (e) {
      return false;
    }
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
    return PopScope(
      canPop: true, // Predictive Back Gesture 애니메이션 허용
      onPopInvokedWithResult: (didPop, result) async {
        // canPop: true일 때 didPop은 항상 true이지만, 
        // 루트 화면에서는 시스템이 종료되기 전 Native OnBackInvokedCallback이 먼저 가로채서 광고를 보여줌
        if (didPop) return; 
        await _showCloseAd();
      },
      child: Scaffold(
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
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
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
                          backgroundColor: const Color(0xFFF5C842),
                          foregroundColor: Colors.black87,
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
                                    color: Colors.black54,
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
                const SizedBox(height: 14),
                // 기도문 입력/결과 박스 (항상 표시, 편집 가능)
                TextField(
                  controller: prayerContentController,
                  maxLines: null,
                  minLines: 6,
                  decoration: InputDecoration(
                    hintText: 'AI 도움받기를 누르면 예배기도문이 나옵니다',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: gridBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: mainGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(18),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 60 + MediaQuery.of(context).viewPadding.bottom,
      ),
    ),
    );
  }
}
