package com.nanoset.repre_prayer_app

import android.content.DialogInterface
import android.os.Bundle
import com.adxcorp.ads.nativeads.AdxCloseAdFactory
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private val closeNativeAdUnitId = "69b8f2fbcb688c8ca0286be5"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AdxCloseAdFactory.init(this, closeNativeAdUnitId, "앱을 종료하시겠습니까?")
        AdxCloseAdFactory.preloadAd()
    }

    override fun onBackPressed() {
        AdxCloseAdFactory.showCloseAd(
            this,
            DialogInterface.OnClickListener { _, _ -> finish() },
            DialogInterface.OnCancelListener { }
        )
    }

    override fun onDestroy() {
        AdxCloseAdFactory.destroy()
        super.onDestroy()
    }
}
