package com.example.liquid_volume

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VOLUME_CHANNEL = "com.example.liquid_volume/volume"
    private val PERMISSION_CHANNEL = "com.example.liquid_volume/permissions"
    private var eventSink: EventChannel.EventSink? = null
    private var isReceiverRegistered = false
    
    // Receiver is now tied to Activity lifecycle to prevent leaks
    private val volumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val volume = intent?.getIntExtra("volume", -1) ?: -1
            if (volume >= 0) {
                // Normalize volume (0.0 - 1.0)
                // Use 'max' from intent if available (Performance optimization)
                val maxExtra = intent?.getIntExtra("max", -1) ?: -1
                
                val max = if (maxExtra > 0) {
                    maxExtra
                } else {
                    // Fallback: Safe context usage (Defensive hardening)
                    val audioManager = context?.applicationContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                }
                
                eventSink?.success(volume.toDouble() / max.toDouble())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Register receiver in onCreate to allow background updates (overlay support)
        if (!isReceiverRegistered) {
            val filter = IntentFilter("com.example.liquid_volume.VOLUME_CHANGED")
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(volumeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(volumeReceiver, filter)
            }
            isReceiverRegistered = true
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(volumeReceiver)
            } catch (e: Exception) {
                // Already unregistered or not registered
            }
            isReceiverRegistered = false
        }
    }

    // Removed onStart/onStop registration to allow background listening
    override fun onStart() {
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for real-time volume button listening
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // MethodChannel for checking and requesting permissions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "openDNDSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this, VolumeAccessibilityService::class.java))
                }
                "getVolume" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    result.success(currentVolume.toDouble() / maxVolume.toDouble())
                }
                "setVolume" -> {
                    // Legacy support: Flutter sends 0.0-1.0 double
                    val volume = call.argument<Double>("volume")
                    if (volume != null) {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val targetVolume = (volume * maxVolume).toInt().coerceIn(0, maxVolume)

                        if (VolumeAccessibilityService.instance != null) {
                            VolumeAccessibilityService.instance?.applySliderVolume(AudioManager.STREAM_MUSIC, targetVolume)
                        } else {
                            // BLOCKING setStreamVolume fallback as it causes crashes/OEM issues
                            android.util.Log.w("LiquidVolume", "Accessibility Service not ready. Ignoring volume change.")
                        }
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Volume argument missing", null)
                    }
                }
                "setVolumeTarget" -> {
                    val target = call.argument<Int>("target")
                    if (target != null) {
                        if (VolumeAccessibilityService.instance != null) {
                            VolumeAccessibilityService.instance?.applySliderVolume(AudioManager.STREAM_MUSIC, target)
                            result.success(null)
                        } else {
                            result.error("SERVICE_NOT_READY", "Accessibility Service not active", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Target volume missing", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        val expectedComponentName = "${context.packageName}/${service.name}"
        val enabledServices = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        if (enabledServices == null) return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
