import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/volume_service.dart';
import 'designs_screen.dart';
import 'per_app_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  StreamSubscription? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _initVolumeListener();
  }

  void _initVolumeListener() {
    // Keep the listener alive at the top level
    _volumeSubscription = VolumeService.volumeEvents.listen((event) {
      if (event is double) {
        // Optional: Update global state or notify sub-screens via Provider/Riverpod if needed later.
        // For now, the native side handles the visual overlay,
        // and SettingsScreen can check/set volume as needed.
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _volumeSubscription?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // animateToPage triggers onPageChanged, which updates the state.
    // However, for immediate feedback on the BottomNavBar, we usually update state here too.
    // To avoid double-builds, we can check if index is different.

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Reveal image
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/pexels-anniroenkae-2832382.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), // "work like page view"
          children: const [DesignsScreen(), PerAppScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.palette_outlined),
              activeIcon: Icon(Icons.palette),
              label: 'Designs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_outlined),
              activeIcon: Icon(Icons.apps),
              label: 'Per App',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings),
              activeIcon: Icon(CupertinoIcons.settings_solid),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
