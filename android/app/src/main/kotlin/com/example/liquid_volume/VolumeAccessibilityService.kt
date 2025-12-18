package com.example.liquid_volume

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent


class VolumeAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "VolumeService"
        var instance: VolumeAccessibilityService? = null
    }

    private lateinit var audioManager: android.media.AudioManager
    
    // Repeat logic - Production Grade
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var repeatRunnable: Runnable? = null
    private var repeatingDirection: String? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Accessibility Service Created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Service Connected")
        audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
        
        val info = serviceInfo
        info.flags = info.flags or android.accessibilityservice.AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        serviceInfo = info
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN -> {

                when (event.action) {
                    KeyEvent.ACTION_DOWN -> {
                        // Only start if not already repeating (repeatCount 0)
                        // Note: We ignore subsequent repeat events from system to rely on our own timing
                        if (event.repeatCount == 0) {
                            val dir = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "volume_up" else "volume_down"

                            // First immediate change
                            changeVolume(dir)
                            sendVolumeEvent(dir)

                            startRepeating(dir)
                        }
                        return true
                    }

                    KeyEvent.ACTION_UP -> {
                        stopRepeating()
                        return true
                    }
                }
            }
        }
        return super.onKeyEvent(event)
    }

    private fun startRepeating(direction: String) {
        stopRepeating() // safety

        repeatingDirection = direction

        repeatRunnable = object : Runnable {
            override fun run() {
                val dir = repeatingDirection ?: return
                changeVolume(dir)
                sendVolumeEvent(dir)

                // Repeat speed (matches system feel)
                handler.postDelayed(this, 80) // ~12.5 steps/sec
            }
        }

        // Initial delay before auto-repeat starts
        handler.postDelayed(repeatRunnable!!, 350)
    }

    private fun stopRepeating() {
        repeatRunnable?.let { handler.removeCallbacks(it) }
        repeatRunnable = null
        repeatingDirection = null
    }

    private fun changeVolume(direction: String) {
        val stream = android.media.AudioManager.STREAM_MUSIC
        val flags = android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE

        when (direction) {
            "volume_up" -> {
                audioManager.adjustStreamVolume(stream, android.media.AudioManager.ADJUST_RAISE, flags)
            }
            "volume_down" -> {
                audioManager.adjustStreamVolume(stream, android.media.AudioManager.ADJUST_LOWER, flags)
            }
        }
    }

    fun applySliderVolume(target: Int) {
        if (!::audioManager.isInitialized) return

        val stream = android.media.AudioManager.STREAM_MUSIC
        val max = audioManager.getStreamMaxVolume(stream)
        val current = audioManager.getStreamVolume(stream)

        val safeTarget = target.coerceIn(0, max)
        val delta = safeTarget - current
        if (delta == 0) return

        val direction =
            if (delta > 0) android.media.AudioManager.ADJUST_RAISE
            else android.media.AudioManager.ADJUST_LOWER

        val flags = android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE

        repeat(kotlin.math.abs(delta)) {
            // Defensive check to avoid overshooting
            val now = audioManager.getStreamVolume(stream)
            if ((direction == android.media.AudioManager.ADJUST_RAISE && now >= safeTarget) ||
                (direction == android.media.AudioManager.ADJUST_LOWER && now <= safeTarget)
            ) return@repeat
            
            audioManager.adjustStreamVolume(stream, direction, flags)
        }

        Log.d(TAG, "Volume adjusted: $current -> $safeTarget")
    }

    private fun sendVolumeEvent(direction: String) {
        if (!::audioManager.isInitialized) return
        val stream = android.media.AudioManager.STREAM_MUSIC
        val currentVolume = audioManager.getStreamVolume(stream)
        val maxVolume = audioManager.getStreamMaxVolume(stream)
        
        val intent = Intent("com.example.liquid_volume.VOLUME_CHANGED")
        intent.setPackage(packageName)
        intent.putExtra("volume", currentVolume)
        intent.putExtra("max", maxVolume)
        intent.putExtra("direction", direction) // Keep direction for legacy if needed, but volume is source of truth
        sendBroadcast(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        stopRepeating()
        instance = null
        Log.d(TAG, "Service Destroyed")
    }
}
