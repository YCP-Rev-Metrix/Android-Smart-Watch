package com.example.watch_app

import android.os.Bundle
import android.os.Build
import android.graphics.Rect
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Disable system gestures (back swipe) on Android 11+ for Wear OS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)

            // Hide navigation gestures completely
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemGestures())
                it.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_BARS_BY_SWIPE
            }

            // Disable edge-back gestures by redefining exclusion regions
            window.decorView.setOnApplyWindowInsetsListener { v, insets ->
                val backGestureInsets = insets.getInsets(WindowInsets.Type.systemGestures())

                // Define a rect that covers the entire screen
                // so no region is available for back gestures
                val exclusionRect = Rect(0, 0, v.width, v.height)

                v.systemGestureExclusionRects = listOf(exclusionRect)
                insets
            }
        }
    }
}
