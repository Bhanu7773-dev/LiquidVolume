import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/volume_service.dart';

void main() {
  runApp(const LiquidVolumeApp());
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
      }
    });
  }

  void _updateVolumeFromNative(double normalized) {
    print(
      "LiquidVolume: Updating volume from native: $normalized (current: $_volumeLevel)",
    );
    // Only update if difference is significant
    if ((_volumeLevel - normalized).abs() > 0.05) {
      setState(() => _volumeLevel = normalized);
    }
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
