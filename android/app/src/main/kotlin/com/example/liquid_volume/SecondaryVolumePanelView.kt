package com.example.liquid_volume

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.media.AudioManager
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator

class SecondaryVolumePanelView(context: Context) : View(context) {

    enum class VolumeStream(val stream: Int) {
        RING(AudioManager.STREAM_RING),
        NOTIFICATION(AudioManager.STREAM_NOTIFICATION),
        ALARM(AudioManager.STREAM_ALARM)
    }

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // ===== STATE =====
    // Fade in animation
    private var showProgress = 0f
    private var showAnimator: ValueAnimator? = null
    
    // Touch State
    private var draggingStream: VolumeStream? = null

    private val streamProgress = mutableMapOf(
        VolumeStream.RING to 0f,
        VolumeStream.NOTIFICATION to 0f,
        VolumeStream.ALARM to 0f
    )

    // ===== PAINTS =====
    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(40, 200, 230, 255)
    }

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = LinearGradient(
            0f, 0f, 0f, 1000f,
            Color.parseColor("#B388FF"),
            Color.parseColor("#7C4DFF"),
            Shader.TileMode.CLAMP
        )
    }

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(35, 0, 0, 0)
    }

    private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }

    // ===== ICONS =====
    private val iconDrawables by lazy {
        mapOf(
            VolumeStream.RING to context.getDrawable(R.drawable.ic_ring_volume),
            VolumeStream.NOTIFICATION to context.getDrawable(R.drawable.ic_notifications),
            VolumeStream.ALARM to context.getDrawable(R.drawable.ic_alarm)
        )
    }

    // ===== LAYOUT METRICS =====
    private val SLIDER_WIDTH = 140f
    private val SLIDER_GAP = 20f
    private val MAIN_HEIGHT = 600f
    private val MENU_GAP = 30f // Not used but keeps metrics consistent height-wise if needed?
    // Actually we only need MAIN_HEIGHT. The secondary panel doesn't have the menu button below.
    // BUT we should keep TOTAL_HEIGHT matching the main panel so they vertically align easily.
    
    private val MENU_SIZE = 140f
    private val TOTAL_HEIGHT = MAIN_HEIGHT + MENU_GAP + MENU_SIZE

    init {
        syncAllVolumes()
        isClickable = true
        isFocusable = true
        
        setOnTouchListener { _, event ->
            val service = context as? VolumePanelService
            service?.cancelAutoHide() // Any touch here keeps panel alive

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    draggingStream = hitTestSlider(event.x, event.y)
                    draggingStream != null
                }
                MotionEvent.ACTION_MOVE -> {
                    draggingStream?.let {
                        updateStreamFromTouch(it, event.y)
                        true
                    } ?: false
                }
                MotionEvent.ACTION_UP,
                MotionEvent.ACTION_CANCEL -> {
                    service?.scheduleAutoHide()
                    draggingStream = null
                    true
                }
                else -> false
            }
        }
    }
    
    fun animateShow() {
        // Fade In ONLY (No Slide)
        alpha = 0f
        animate()
            .alpha(1f)
            .setDuration(300)
            .setInterpolator(DecelerateInterpolator())
            .start()
    }
    
    fun animateHide(onEnd: () -> Unit) {
        animate()
            .alpha(0f)
            .setDuration(300)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                visibility = View.GONE // Safety: Ensure invisible
                onEnd()
            }
            .start()
    }
    
    fun updateVolume(current: Int, max: Int) {
        // We act largely independent but good to sync
        syncAllVolumes()
        invalidate()
    }

    private fun hitTestSlider(x: Float, y: Float): VolumeStream? {
        val sliders = getVisibleSliders()
        sliders.forEach { (stream, rect) ->
            if (rect.contains(x, y)) return stream
        }
        return null
    }

    private fun updateStreamFromTouch(stream: VolumeStream, y: Float) {
        val rect = getVisibleSliders()[stream] ?: return
        val percent = 1f - ((y - rect.top) / rect.height())
        val clamped = percent.coerceIn(0f, 1f)
        streamProgress[stream] = clamped
        
        // Use the Service bridge
        val max = audioManager.getStreamMaxVolume(stream.stream)
        val target = (clamped * max).toInt().coerceIn(0, max)
        
        val service = VolumeAccessibilityService.instance
        if (service != null) {
            service.applySliderVolume(stream.stream, target)
        } else {
             audioManager.setStreamVolume(stream.stream, target, 0)
        }
        invalidate()
    }

    private fun syncAllVolumes() {
        streamProgress.keys.forEach {
            val max = audioManager.getStreamMaxVolume(it.stream)
            val cur = audioManager.getStreamVolume(it.stream)
            streamProgress[it] = if (max > 0) cur.toFloat() / max else 0f
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Fixed width: 3 sliders + 2 gaps
        // 140 * 3 + 20 * 2 = 420 + 40 = 460
        val w = (SLIDER_WIDTH * 3 + SLIDER_GAP * 2).toInt()
        setMeasuredDimension(w, TOTAL_HEIGHT.toInt())
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        // Draw 3 sliders side-by-side
        // Layout: ALARM | NOTIF | RING  (Right to Left visually?)
        // The main slider is to our Right.
        // So standard order from Right to Left: Ring, Notif, Alarm
        
        val w = width.toFloat()
        var currentRight = w
        
        val list = listOf(VolumeStream.RING, VolumeStream.NOTIFICATION, VolumeStream.ALARM)
        
        list.forEachIndexed { index, stream ->
             val left = currentRight - SLIDER_WIDTH
             val rect = RectF(left, 0f, currentRight, MAIN_HEIGHT)
             drawSlider(canvas, stream, rect)
             currentRight -= (SLIDER_WIDTH + SLIDER_GAP)
        }
    }
    
    private fun drawSlider(canvas: Canvas, stream: VolumeStream, rect: RectF) {
        // Reuse identical drawing logic
        val radius = rect.width() / 2f
        canvas.drawRoundRect(rect, radius, radius, bgPaint)

        val trackPadding = 20f
        val trackTop = rect.top + 120f 
        val trackBottom = rect.bottom - 40f
        
        val track = RectF(
            rect.centerX() - trackPadding,
            trackTop, 
            rect.centerX() + trackPadding,
            trackBottom
        )
        canvas.drawRoundRect(track, 20f, 20f, trackPaint)

        val fillHeight = track.height() * (streamProgress[stream] ?: 0f)
        val fillRect = RectF(
            track.left,
            track.bottom - fillHeight,
            track.right,
            track.bottom
        )
        canvas.drawRoundRect(fillRect, 20f, 20f, fillPaint)

        canvas.save()
        val cx = rect.centerX()
        val cy = rect.top + 60f
        
        val iconSize = 64
        val halfSize = iconSize / 2
        
        val drawable = iconDrawables[stream]
        drawable?.let {
            it.setBounds(
                (cx - halfSize).toInt(),
                (cy - halfSize).toInt(),
                (cx + halfSize).toInt(),
                (cy + halfSize).toInt()
            )
            it.setTint(Color.WHITE)
            it.draw(canvas)
        }
        canvas.restore()
    }

    private fun getVisibleSliders(): Map<VolumeStream, RectF> {
        val w = width.toFloat()
        val map = mutableMapOf<VolumeStream, RectF>()
        var currentRight = w
        
        val list = listOf(VolumeStream.RING, VolumeStream.NOTIFICATION, VolumeStream.ALARM)
        list.forEach { stream ->
             val left = currentRight - SLIDER_WIDTH
             map[stream] = RectF(left, 0f, currentRight, MAIN_HEIGHT)
             currentRight -= (SLIDER_WIDTH + SLIDER_GAP)
        }
        return map
    }
}
