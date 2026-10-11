package com.emircf.santiyepuantaj

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import java.io.File

class MainActivity: FlutterActivity() {
    private val TAG = "CAD_INTENT"
    private val CHANNEL = "com.emircf.santiyeyonetim/audio_control"
    private val CAD_CHANNEL = "com.emircf.santiyeyonetim/cad_intent"
    private var cadMethodChannel: MethodChannel? = null
    private var pendingCadFile: Map<String, String>? = null

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

        // CAD Dosya Açma / Paylaşma Intent Kanalı
        cadMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAD_CHANNEL)
        cadMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialCadFile" -> {
                    Log.d(TAG, "Dart getInitialCadFile cagirdi. Mevcut pendingCadFile: $pendingCadFile")
                    val fileData = pendingCadFile
                    pendingCadFile = null
                    result.success(fileData)
                }
                else -> result.notImplemented()
            }
        }

        // Soğuk açılış (Cold boot) sırasında açılan dosya varsa hemen yakala
        Log.d(TAG, "configureFlutterEngine intent: ${intent?.action}, data: ${intent?.data}")
        intent?.let { handleCadIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "onNewIntent calisti: action=${intent.action}, data=${intent.data}")
        handleCadIntent(intent)
    }

    private fun handleCadIntent(intent: Intent) {
        val action = intent.action
        Log.d(TAG, "handleCadIntent: action=$action, data=${intent.data}, type=${intent.type}")
        if (action == Intent.ACTION_VIEW || action == Intent.ACTION_SEND) {
            val uri: Uri? = when (action) {
                Intent.ACTION_SEND -> {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                        ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
                }
                else -> {
                    intent.data
                        ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
                }
            }

            Log.d(TAG, "Cikarilan URI: $uri")
            if (uri != null) {
                Thread {
                    val fileData = processIntentUri(uri)
                    Log.d(TAG, "processIntentUri sonucu: $fileData")
                    if (fileData != null) {
                        pendingCadFile = fileData
                        runOnUiThread {
                            cadMethodChannel?.invokeMethod("onCadFileReceived", fileData)
                        }
                    }
                }.start()
            }
        }
    }

    private fun processIntentUri(uri: Uri): Map<String, String>? {
        return try {
            Log.d(TAG, "processIntentUri basladi: $uri (scheme: ${uri.scheme})")
            var displayName: String? = null

            if (uri.scheme == "content") {
                try {
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (cursor.moveToFirst() && nameIndex != -1) {
                            displayName = cursor.getString(nameIndex)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "DISPLAY_NAME okunamadi: ${e.message}")
                }
            }

            if (displayName.isNullOrBlank()) {
                displayName = uri.lastPathSegment ?: "proje_cizimi.dwg"
            }

            if (displayName!!.contains("/")) {
                displayName = displayName!!.substringAfterLast("/")
            }

            val inboxDir = File(cacheDir, "cad_inbox")
            if (!inboxDir.exists()) inboxDir.mkdirs()

            val safeName = displayName!!.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
            val destFile = File(inboxDir, "${System.currentTimeMillis()}_$safeName")

            Log.d(TAG, "Dosya kopyalaniyor: ${destFile.absolutePath}")

            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            if (destFile.exists() && destFile.length() > 0) {
                Log.d(TAG, "Dosya basariyla kopyalandi! Boyut=${destFile.length()}, isim=$displayName")
                mapOf(
                    "filePath" to destFile.absolutePath,
                    "fileName" to displayName!!
                )
            } else {
                Log.e(TAG, "destFile olusmadi veya 0 bayt!")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "processIntentUri hatasi: ${e.message}", e)
            null
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
