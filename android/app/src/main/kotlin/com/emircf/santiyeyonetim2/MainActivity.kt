package com.emircf.santiyeyonetim2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.emircf.santiyeyonetim/audio_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "muteSystemStream" -> {
                    try {
                        audioManager.setStreamMute(AudioManager.STREAM_SYSTEM, true)
                        audioManager.setStreamMute(AudioManager.STREAM_NOTIFICATION, true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "unmuteSystemStream" -> {
                    try {
                        audioManager.setStreamMute(AudioManager.STREAM_SYSTEM, false)
                        audioManager.setStreamMute(AudioManager.STREAM_NOTIFICATION, false)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamMute(AudioManager.STREAM_SYSTEM, false)
            audioManager.setStreamMute(AudioManager.STREAM_NOTIFICATION, false)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamMute(AudioManager.STREAM_SYSTEM, false)
            audioManager.setStreamMute(AudioManager.STREAM_NOTIFICATION, false)
        } catch (_: Exception) {}
    }
}
