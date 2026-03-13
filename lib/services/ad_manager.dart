import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────────
// AdManager — SDK 독립적 추상 인터페이스
//
// 향후 AD(X) 미디에이션 SDK로 교체할 때는
// AdMobAdManager 대신 새 구현체(예: AdxAdManager)를
// 만들어 `AdManager.instance`에 할당하기만 하면 됩니다.
// UI 코드(prayer_input_screen.dart)는 전혀 수정 불필요.
// ─────────────────────────────────────────────────
abstract class AdManager {
  /// 앱 전역 싱글톤. 교체 시 이 한 줄만 바꾸면 됩니다.
  static final AdManager instance = AdMobAdManager();

  /// main()에서 MobileAds SDK 초기화 시 호출
  Future<void> initialize();

  /// 배너 광고 위젯 반환 — 로드·해제 등 수명 주기를 내부에서 완전 관리
  Widget buildBannerAd(BuildContext context);
}

// ─────────────────────────────────────────────────
// AdMobAdManager — AdMob 전용 구현체
// ─────────────────────────────────────────────────
class AdMobAdManager implements AdManager {
  // 디버그 모드: 구글 공식 테스트 ID 강제 적용 (계정 보호)
  // 릴리즈 모드: 실제 광고 단위 ID 사용
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _prodAdUnitId = 'ca-app-pub-8256212284177777/7609302052';
  static String get _adUnitId => kDebugMode ? _testAdUnitId : _prodAdUnitId;

  @override
  Future<void> initialize() => MobileAds.instance.initialize();

  @override
  Widget buildBannerAd(BuildContext context) {
    return _AdMobBannerWidget(adUnitId: _adUnitId);
  }
}

// ─────────────────────────────────────────────────
// _AdMobBannerWidget — 배너 수명 주기를 자체 관리하는 내부 위젯
//
// • 로드 전: SizedBox(height: 50) → 레이아웃 jank 방지
// • 로드 성공: 적응형 배너 높이로 AdWidget 표시
// • 로드 실패: SizedBox(height: 0) → 조용히 사라짐
// ─────────────────────────────────────────────────
class _AdMobBannerWidget extends StatefulWidget {
  final String adUnitId;
  const _AdMobBannerWidget({required this.adUnitId});

  @override
  State<_AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<_AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies는 context가 준비된 후 최초 1회만 로드
    if (_bannerAd == null && !_hasFailed) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final screenWidth = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          screenWidth,
        ) ??
        AdSize.banner; // fallback: 표준 배너

    // BannerAd를 먼저 할당한 후 load() 호출
    // → onAdLoaded 콜백 시 _bannerAd가 이미 null이 아님이 보장됨
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] 배너 로드 실패: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _hasFailed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 로드 실패: 공간 차지 없이 숨김
    if (_hasFailed) return const SizedBox.shrink();

    // 로드 전: 50px 공간 확보 → 레이아웃 jank 방지
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }

    // 로드 성공: 실제 적응형 배너 표시
    return SizedBox(
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
