package com.example.liquid_volume

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.*
import android.widget.FrameLayout

class VolumePanelService : Service() {

    companion object {
        var instance: VolumePanelService? = null
    }

    private lateinit var windowManager: WindowManager
    private var panelView: View? = null
    private var secondaryView: View? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val hideRunnable = Runnable { hidePanel() }

    fun cancelAutoHide() {
        handler.removeCallbacks(hideRunnable)
    }

    fun scheduleAutoHide() {
        handler.removeCallbacks(hideRunnable)
        handler.postDelayed(hideRunnable, 2000)
    }

    fun showPanel(volume: Int, max: Int) {
        handler.removeCallbacks(hideRunnable)

        if (panelView == null) {
            val view = LiquidVolumePanelView(this)
            panelView = view
            
            // PRE-ANIMATION SETUP (Fixes "Blink" glitch)
            // Move off-screen immediately so first frame renders correctly
            view.translationX = 1000f 
            view.alpha = 0f 
            
            view.expandListener = object : LiquidVolumePanelView.OnExpandListener {
                override fun onExpandRequested() {
                    toggleSecondary()
                }
            }

            val type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )

            params.gravity = Gravity.END or Gravity.CENTER_VERTICAL
            params.x = 24

            windowManager.addView(panelView, params)
            
            // Trigger Slide-in Animation
            view.animateShow()
        } else {
            // Cancel exit animation if any
            panelView?.animate()?.cancel()
            panelView?.translationX = 0f
            panelView?.alpha = 1f
        }

        (panelView as LiquidVolumePanelView).updateVolume(volume, max)
        
        (secondaryView as? SecondaryVolumePanelView)?.updateVolume(volume, max)

        handler.postDelayed(hideRunnable, 2000)
    }
    
    private fun toggleSecondary() {
        if (secondaryView != null) {
            // Close with animation
            val view = secondaryView
            secondaryView = null // clear ref immediately
            (view as? SecondaryVolumePanelView)?.animateHide {
                try {
                    if (view?.parent != null) windowManager.removeView(view)
                } catch (e: Exception) {}
            }
        } else {
            // Open
            val view = SecondaryVolumePanelView(this)
            secondaryView = view
            
            val type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.END or Gravity.CENTER_VERTICAL
            params.x = 184
            
            windowManager.addView(secondaryView, params)
            view.animateShow()
        }
    }

    fun hidePanel() {
        // Hide Main
        panelView?.let { view ->
            handler.removeCallbacks(hideRunnable)
            (view as LiquidVolumePanelView).animateHide {
                try {
                    if (view.parent != null) windowManager.removeView(view)
                } catch (e: Exception) {}
                if (panelView == view) panelView = null
            }
        }
        
        // Hide Secondary Immediate (or animate if we added logic later)
        secondaryView?.let { view ->
             try {
                 if (view.parent != null) windowManager.removeView(view)
             } catch (e: Exception) {}
             secondaryView = null
        }
    }

    override fun onDestroy() {
        hidePanel()
        instance = null
        super.onDestroy()
    }
}
