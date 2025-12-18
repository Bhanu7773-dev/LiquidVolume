import 'dart:async';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'services/volume_service.dart';

const String _kPortName = 'OVERLAY_PORT';

void main() {
  runApp(const LiquidVolumeApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlaySlider()),
  );
}

class LiquidVolumeApp extends StatelessWidget {
  const LiquidVolumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Volume',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;
  double _volumeLevel = 0.5;
  StreamSubscription? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _initVolumeListener();
    _initOverlayCommunication(); // Replacing listener with port
  }

  void _initOverlayCommunication() {
    // Determine if we already registered port? IsolateNameServer.registerPortWithName return bool
    final receivePort = ReceivePort();
    final res = IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      _kPortName,
    );
    if (!res) {
      // Ideally unregister first, but since it's main app isolate, it might persist?
      IsolateNameServer.removePortNameMapping(_kPortName);
      IsolateNameServer.registerPortWithName(receivePort.sendPort, _kPortName);
    }

    receivePort.listen((message) {
      if (message is int) {
        // message is now target index (0-15 typical)
        VolumeService.setVolume(
          message.toDouble() / 15.0,
        ); // pass normalized for legacy or update VolumeService
        // Actually, let's pass the raw int target if we update VolumeService to support it
        // For now, we reuse setVolume which takes double, but we should make a setVolumeTarget method
        // Or cleaner: Update VolumeService.setVolume to take int?
        // Let's stick to the plan: Call a new method on MethodChannel
        // Correcting channel usage to match VolumeService
        const platform = MethodChannel('com.example.liquid_volume/permissions');
        platform.invokeMethod('setVolumeTarget', {'target': message});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final overlay = await VolumeService.checkOverlayPermission();
    final accessibility = await VolumeService.isAccessibilityEnabled();
    setState(() {
      _hasOverlayPermission = overlay;
      _hasAccessibilityPermission = accessibility;
    });
  }

  void _initVolumeListener() {
    print("LiquidVolume: Initializing volume listener");
    _volumeSubscription = VolumeService.volumeEvents.listen((event) {
      print("LiquidVolume: Received event: $event");
      // Received normalized volume (0.0 - 1.0) from MainActivity
      if (event is double) {
        _updateVolumeFromNative(event);
      } else if (event is Map) {
        // Handle map if we decide to send map again, or just ignore
      }
    });
  }

  bool _isInteracting = false;

  void _updateVolumeFromNative(double normalized) {
    if (_isInteracting) return; // Ignore native updates while user is dragging
    print(
      "LiquidVolume: Updating volume from native: $normalized (current: $_volumeLevel)",
    );
    // Only update if difference is significant to avoid fighting with slider
    if ((_volumeLevel - normalized).abs() > 0.05) {
      setState(() => _volumeLevel = normalized);
    }
    _showOverlay();
  }

  // Restored for Test Button compatibility
  void _onVolumeEvent(String direction) {
    if (direction == "volume_up") {
      setState(() => _volumeLevel = (_volumeLevel + 0.1).clamp(0.0, 1.0));
      VolumeService.setVolume(_volumeLevel);
    } else {
      setState(() => _volumeLevel = (_volumeLevel - 0.1).clamp(0.0, 1.0));
      VolumeService.setVolume(_volumeLevel);
    }
    _showOverlay();
  }

  Future<void> _showOverlay() async {
    print("LiquidVolume: _showOverlay called");
    final bool isActive = await FlutterOverlayWindow.isActive();
    print("LiquidVolume: Is overlay active? $isActive");
    final double currentVolume = await VolumeService.getVolume();
    print("LiquidVolume: Current volume: $currentVolume");

    if (!isActive) {
      print("LiquidVolume: Attempting to show overlay");
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: "Liquid Volume",
        overlayContent: "Volume Slider",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
      );
    }
    // Update local level and share with overlay
    _volumeLevel = currentVolume;
    await FlutterOverlayWindow.shareData(_volumeLevel);
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Liquid Volume",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Premium Non-Root Customization",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              _buildPermissionTile(
                "Overlay Permission",
                "Required to show the slider over other apps",
                _hasOverlayPermission,
                () => VolumeService.requestOverlayPermission().then(
                  (_) => _checkPermissions(),
                ),
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                "Accessibility Service",
                "Required to detect volume button presses",
                _hasAccessibilityPermission,
                () => VolumeService.openAccessibilitySettings(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _onVolumeEvent("volume_up"),
                child: const Text("Test Slider"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String subtitle,
    bool granted,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(
          granted ? Icons.check_circle : Icons.error_outline,
          color: granted ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
    );
  }
}

class OverlaySlider extends StatefulWidget {
  const OverlaySlider({super.key});

  @override
  State<OverlaySlider> createState() => _OverlaySliderState();
}

class _OverlaySliderState extends State<OverlaySlider> {
  double _volumeLevel = 0.5;
  Timer? _hideTimer;
  DateTime _lastUpdate = DateTime.now();
  bool _isInteracting = false;
  bool _isVisible = false;
  StreamSubscription? _listenerSubscription;

  @override
  void initState() {
    super.initState();
    print("LiquidVolume: OverlaySlider initState");

    // Trigger visual entry after short delay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _isVisible = true);
    });

    _fetchInitialVolume();
    _listenerSubscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is double) {
        if (mounted) {
          setState(() {
            if (!_isInteracting) _volumeLevel = data;
            _isVisible = true; // Ensure visible on every update/open
          });
        }
        _resetHideTimer();
      }
    });
    _resetHideTimer();
  }

  Future<void> _fetchInitialVolume() async {
    final vol = await VolumeService.getVolume();
    setState(() => _volumeLevel = vol);
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Reverse animation
        setState(() => _isVisible = false);
        // Wait for animation to finish then close
        Future.delayed(const Duration(milliseconds: 350), () {
          FlutterOverlayWindow.closeOverlay();
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _listenerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: AnimatedSlide(
            offset: _isVisible ? Offset.zero : const Offset(1.5, 0.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: LiquidSlider(
              value: _volumeLevel,
              onChanged: (val) {
                setState(() => _volumeLevel = val);
                // Throttled update to native
                if (DateTime.now().difference(_lastUpdate) >
                    const Duration(milliseconds: 50)) {
                  _lastUpdate = DateTime.now();
                  // Send desired target via Isolate to main app
                  final int target = (val * 15).round();
                  final SendPort? sendPort = IsolateNameServer.lookupPortByName(
                    _kPortName,
                  );
                  if (sendPort != null) {
                    sendPort.send(target);
                  } else {
                    print("LiquidVolume: Could not find main isolate port");
                  }
                }
                _resetHideTimer();
              },
              onChangeStart: () => _isInteracting = true,
              onChangeEnd: () => _isInteracting = false,
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  const LiquidSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  State<LiquidSlider> createState() => _LiquidSliderState();
}

class _LiquidSliderState extends State<LiquidSlider> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, opacity, child) {
        final clampedOpacity = opacity.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedOpacity,
          child: Transform.scale(
            scale: 0.8 + (0.2 * clampedOpacity),
            child: child,
          ),
        );
      },
      child: Container(
        height: 250,
        width: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          // User requested removal of "dark shadow" for glass look
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Icon(Icons.volume_up, color: Colors.white, size: 24),
                ),
                Expanded(
                  child: GestureDetector(
                    onVerticalDragStart: (_) {
                      setState(() => _isDragging = true);
                      widget.onChangeStart?.call();
                    },
                    onVerticalDragEnd: (_) {
                      setState(() => _isDragging = false);
                      widget.onChangeEnd?.call();
                    },
                    onVerticalDragCancel: () {
                      setState(() => _isDragging = false);
                      widget.onChangeEnd?.call();
                    },
                    onVerticalDragUpdate: (details) {
                      final delta = details.primaryDelta! / 200;
                      widget.onChanged((widget.value - delta).clamp(0.0, 1.0));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Background track
                            Container(color: Colors.white.withOpacity(0.1)),
                            // "Liquid" fill with smooth animation
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: widget.value),
                              duration: _isDragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedValue, child) {
                                return FractionallySizedBox(
                                  heightFactor: animatedValue.clamp(0.0, 1.0),
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purpleAccent.withOpacity(0.8),
                                      Colors.deepPurple.withOpacity(0.9),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  // Removed explicit radius on fill to let ClipRRect handle it,
                                  // BUT to keep top rounded we need it?
                                  // Actually, if we want "Liquid" surface to be flat-ish or rounded, we can keep radius.
                                  // But if we remove it, the top is square.
                                  // Let's keep radius on fill, ClipRRect handles the bottom cut-off.
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purpleAccent.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "${(widget.value * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
