package com.nanoset.repre_prayer_app

import android.content.DialogInterface
import android.os.Bundle
import com.adxcorp.ads.nativeads.AdxCloseAdFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val closeNativeAdUnitId = "69b8f2fbcb688c8ca0286be5"
    private val CHANNEL = "com.nanoset.repre_prayer_app/close_ad"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AdxCloseAdFactory.init(this, closeNativeAdUnitId, "앱을 종료하시겠습니까?")
        AdxCloseAdFactory.preloadAd()

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "showCloseAd") {
                    AdxCloseAdFactory.showCloseAd(
                        this,
                        DialogInterface.OnClickListener { _, _ -> finish() },
                        DialogInterface.OnCancelListener { }
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // onBackPressed 제거: Flutter가 라우트 pop을 정상 처리
    // 메인 화면(PrayerInputScreen)에서만 Flutter PopScope → MethodChannel로 Close Ad 호출

    override fun onDestroy() {
        AdxCloseAdFactory.destroy()
        super.onDestroy()
    }
}
