import 'dart:async';
import 'package:flutter/material.dart';
import '../services/volume_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
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
    if (mounted) {
      setState(() {
        _hasOverlayPermission = overlay;
        _hasAccessibilityPermission = accessibility;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const SizedBox(height: 60),
            const Text(
              "Settings",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Permissions"),
            const SizedBox(height: 16),
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
            _buildSectionHeader("Debug"),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text("Test Slider Slide-In"),
              onPressed: () => VolumeService.setVolume(0.5), // Trigger a change
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
        trailing: Icon(
          granted ? Icons.check_circle : Icons.error_outline,
          color: granted ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
    );
  }
}
