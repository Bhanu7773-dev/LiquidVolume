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
    

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Accessibility Service Created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Service Connected")
        audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        val info = serviceInfo
        info.flags = info.flags or android.accessibilityservice.AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        serviceInfo = info
    }

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var repeatRunnable: Runnable? = null
    private var isHolding = false

    override fun onKeyEvent(event: KeyEvent): Boolean {
        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN -> {

                if (event.action == KeyEvent.ACTION_DOWN && !isHolding) {
                    isHolding = true

                    val direction =
                        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP)
                            android.media.AudioManager.ADJUST_RAISE
                        else
                            android.media.AudioManager.ADJUST_LOWER

                    repeatRunnable = object : Runnable {
                        override fun run() {
                            changeVolume(direction)
                            sendVolumeEvent()
                            handler.postDelayed(this, 120) // repeat speed
                        }
                    }

                    handler.post(repeatRunnable!!)
                    return true
                }

                if (event.action == KeyEvent.ACTION_UP) {
                    isHolding = false
                    repeatRunnable?.let { handler.removeCallbacks(it) }
                    repeatRunnable = null
                    return true
                }
            }
        }
        return false
    }

    private fun changeVolume(direction: Int) {
        audioManager.adjustStreamVolume(
            android.media.AudioManager.STREAM_MUSIC,
            direction,
            android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE
        )
    }

    private fun sendVolumeEvent() {
        if (!::audioManager.isInitialized) return
        val current = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
        val max = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)

        // Show native panel
        startService(Intent(this, VolumePanelService::class.java))
        VolumePanelService.instance?.showPanel(current, max)
    }


    fun applySliderVolume(streamType: Int, target: Int) {
        if (!::audioManager.isInitialized) return

        val max = audioManager.getStreamMaxVolume(streamType)
        val current = audioManager.getStreamVolume(streamType)

        val safeTarget = target.coerceIn(0, max)
        val delta = safeTarget - current
        if (delta == 0) return

        val direction =
            if (delta > 0) android.media.AudioManager.ADJUST_RAISE
            else android.media.AudioManager.ADJUST_LOWER

        val flags = android.media.AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE

        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        // Auto-exit Silent/DND if increasing Ringer/Notif volume
        if (target > 0 && (streamType == android.media.AudioManager.STREAM_RING || streamType == android.media.AudioManager.STREAM_NOTIFICATION)) {
            if (notificationManager.isNotificationPolicyAccessGranted) {
                if (audioManager.ringerMode != android.media.AudioManager.RINGER_MODE_NORMAL) {
                     audioManager.ringerMode = android.media.AudioManager.RINGER_MODE_NORMAL
                }
            }
        }

        repeat(kotlin.math.abs(delta)) {
            // Defensive check to avoid overshooting
            val now = audioManager.getStreamVolume(streamType)
            if ((direction == android.media.AudioManager.ADJUST_RAISE && now >= safeTarget) ||
                (direction == android.media.AudioManager.ADJUST_LOWER && now <= safeTarget)
            ) return@repeat
            
            try {
                audioManager.adjustStreamVolume(streamType, direction, flags)
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException: Not allowed to change Do Not Disturb state")
                return@repeat
            }
        }

        Log.d(TAG, "Volume adjusted (Stream $streamType): $current -> $safeTarget")
    }


    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "Service Destroyed")
    }
}
