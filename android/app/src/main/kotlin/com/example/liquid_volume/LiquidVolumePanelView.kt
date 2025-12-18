package com.example.liquid_volume

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.content.Context
import android.graphics.*
import android.media.AudioManager
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator

class LiquidVolumePanelView(context: Context) : View(context) {

    // Callback interface for Service communication
    interface OnExpandListener {
        fun onExpandRequested()
    }

    var expandListener: OnExpandListener? = null

    enum class VolumeStream(val stream: Int) {
        MEDIA(AudioManager.STREAM_MUSIC)
    }

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // ===== STATE =====
    // No more expansion state here - this view is STATIC
    
    // Touch State
    private var draggingStream: VolumeStream? = null
    private var mediaProgress = 0f

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
    private val iconDrawable by lazy {
        context.getDrawable(R.drawable.ic_music_note)
    }

    // ===== LAYOUT METRICS =====
    private val SLIDER_WIDTH = 140f
    private val MAIN_HEIGHT = 600f
    private val MENU_GAP = 30f
    private val MENU_SIZE = 140f
    
    private val TOTAL_HEIGHT = MAIN_HEIGHT + MENU_GAP + MENU_SIZE

    init {
        syncVolume()
        isClickable = true
        isFocusable = true

        setOnTouchListener { _, event ->
            val service = context as? VolumePanelService
            
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    if (isMenuButton(event.x, event.y)) {
                        expandListener?.onExpandRequested()
                        service?.cancelAutoHide()
                        return@setOnTouchListener true
                    }

                    if (event.y <= MAIN_HEIGHT) {
                        draggingStream = VolumeStream.MEDIA
                        service?.cancelAutoHide()
                        true
                    } else {
                        false
                    }
                }

                MotionEvent.ACTION_MOVE -> {
                    draggingStream?.let {
                        service?.cancelAutoHide()
                        updateVolumeFromTouch(event.y)
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

    // ===== ENTRANCE / EXIT ANIMATIONS =====
    fun animateShow() {
        post {
            translationX = width.toFloat()
            alpha = 1f // Visual fix: Ensure visible
            animate()
                .translationX(0f)
                .setDuration(400)
                .setInterpolator(DecelerateInterpolator())
                .start()
        }
    }

    fun animateHide(onEnd: () -> Unit) {
        animate()
            .translationX(width.toFloat())
            .alpha(0f) // Fade out to mask artifacts
            .setDuration(400)
            .setInterpolator(android.view.animation.AccelerateInterpolator())
            .withEndAction {
                visibility = View.GONE // Safety: Ensure invisible
                onEnd()
            }
            .start()
    }

    // ===== LOGIC =====
    fun updateVolume(current: Int, max: Int) {
        syncVolume()
        invalidate()
    }

    private fun updateVolumeFromTouch(y: Float) {
        // Simple hit test: entire height 0..MAIN_HEIGHT
        val percent = 1f - (y / MAIN_HEIGHT)
        val clamped = percent.coerceIn(0f, 1f)
        mediaProgress = clamped
        
        applyVolume(clamped)
        invalidate()
    }

    private fun applyVolume(percent: Float) {
        val streamType = AudioManager.STREAM_MUSIC
        val max = audioManager.getStreamMaxVolume(streamType)
        val target = (percent * max).toInt().coerceIn(0, max)
        
        // Delegate to AccessibilityService
        val service = VolumeAccessibilityService.instance
        if (service != null) {
            service.applySliderVolume(streamType, target)
        } else {
            try {
                audioManager.setStreamVolume(streamType, target, 0)
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }
    }

    private fun syncVolume() {
        val streamType = AudioManager.STREAM_MUSIC
        val max = audioManager.getStreamMaxVolume(streamType)
        val cur = audioManager.getStreamVolume(streamType)
        mediaProgress = if (max > 0) cur.toFloat() / max else 0f
    }

    // ===== SIZE =====
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // STATIC Fixed Size
        setMeasuredDimension(SLIDER_WIDTH.toInt(), TOTAL_HEIGHT.toInt())
    }

    // ===== DRAW =====
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val w = width.toFloat()
        val rect = RectF(0f, 0f, w, MAIN_HEIGHT)
        
        // 1. Draw Media Slider
        drawSlider(canvas, rect)

        // 2. Draw Menu Button
        val menuTop = MAIN_HEIGHT + MENU_GAP
        val menuRect = RectF(0f, menuTop, w, menuTop + MENU_SIZE)
        drawMenuButton(canvas, menuRect)
    }
    
    private fun drawSlider(canvas: Canvas, rect: RectF) {
        // 1. Background
        val radius = rect.width() / 2f
        canvas.drawRoundRect(rect, radius, radius, bgPaint)

        // 2. Inner Track
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

        // 3. Fill
        val fillHeight = track.height() * mediaProgress
        val fillRect = RectF(
            track.left,
            track.bottom - fillHeight,
            track.right,
            track.bottom
        )
        canvas.drawRoundRect(fillRect, 20f, 20f, fillPaint)

        // 4. Icon
        canvas.save()
        val cx = rect.centerX()
        val cy = rect.top + 60f
        
        val iconSize = 64
        val halfSize = iconSize / 2
        
        iconDrawable?.let {
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
    
    private fun drawMenuButton(canvas: Canvas, rect: RectF) {
        canvas.drawOval(rect, bgPaint)
        
        val cx = rect.centerX()
        val cy = rect.centerY()
        val dotR = 6f
        val dotGap = 24f
        
        canvas.drawCircle(cx - dotGap, cy, dotR, iconPaint)
        canvas.drawCircle(cx, cy, dotR, iconPaint)
        canvas.drawCircle(cx + dotGap, cy, dotR, iconPaint)
    }

    private fun isMenuButton(x: Float, y: Float): Boolean {
        val menuTop = MAIN_HEIGHT + MENU_GAP
        return y in menuTop..(menuTop + MENU_SIZE)
    }
}
