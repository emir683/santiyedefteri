package com.emircf.santiyepuantaj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.emircf.santiyeyonetim/audio_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            val pinchClass = Class.forName("com.github.barteksc.pdfviewer.util.Constants\$Pinch")
            pinchClass.getField("MAXIMUM_ZOOM").set(null, 100000f)
            pinchClass.getField("MINIMUM_ZOOM").set(null, 0.1f)
        } catch (_: Throwable) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "setPdfMaxZoom" -> {
                    try {
                        val maxZ = (call.argument<Double>("maxZoom") ?: 100000.0).toFloat()
                        val minZ = (call.argument<Double>("minZoom") ?: 0.1).toFloat()
                        val pinchClass = Class.forName("com.github.barteksc.pdfviewer.util.Constants\$Pinch")
                        pinchClass.getField("MAXIMUM_ZOOM").set(null, maxZ)
                        pinchClass.getField("MINIMUM_ZOOM").set(null, minZ)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
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
