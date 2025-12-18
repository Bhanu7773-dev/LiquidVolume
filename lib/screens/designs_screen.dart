import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DesignsScreen extends StatefulWidget {
  const DesignsScreen({super.key});

  @override
  State<DesignsScreen> createState() => _DesignsScreenState();
}

class _DesignsScreenState extends State<DesignsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
          children: [
            _buildDesignCard(
              title: "Liquid Default",
              isSelected: true,
              preview: const _DefaultStylePreview(),
            ),
            _buildDesignCard(
              title: "Spotify Vibe",
              isSelected: false,
              preview: const _SpotifyStylePreview(),
            ),
            _buildDesignCard(
              title: "Instagram",
              isSelected: false,
              preview: const _InstagramStylePreview(),
            ),
            _buildDesignCard(
              title: "Telegram",
              isSelected: false,
              preview: const _TelegramStylePreview(),
            ),
            _buildDesignCard(
              title: "YouTube",
              isSelected: false,
              preview: const _YouTubeStylePreview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignCard({
    required String title,
    required bool isSelected,
    required Widget preview,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4), // Dark background for the card
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: Colors.deepPurpleAccent, width: 2)
            : Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: Center(child: preview)),
          Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.deepPurpleAccent,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultStylePreview extends StatelessWidget {
  const _DefaultStylePreview();

  @override
  Widget build(BuildContext context) {
    // Smoked Glass: Transparent black tint for depth, no blur
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.transparent, // Back to clear
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Menu Dots (Separate Circle)
          Positioned(
            bottom: 15, // moved down
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), // subtle background
                shape: BoxShape.circle,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(),
                  const SizedBox(width: 3),
                  _dot(),
                  const SizedBox(width: 3),
                  _dot(),
                ],
              ),
            ),
          ),
          // Track
          Positioned(
            top: 40,
            bottom: 50,
            width: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60, // 50% volume
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Icon
          const Positioned(
            top: 15,
            child: Icon(Icons.music_note, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SpotifyStylePreview extends StatelessWidget {
  const _SpotifyStylePreview();

  @override
  Widget build(BuildContext context) {
    // Spotify Style: Solid Dark Grey, Bright Green Slider
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF191414), // Spotify Black/Dark Grey
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Album Art Placeholder
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 15, bottom: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1DB954), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 14),
          ),

          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track Background
                Container(
                  width: 12, // Increased from 6
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Active Level
                Positioned(
                  bottom: 10,
                  child: Container(
                    width: 12, // Increased from 6
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Icon
          const Padding(
            padding: EdgeInsets.only(bottom: 20, top: 10),
            child: FaIcon(
              FontAwesomeIcons.spotify,
              color: Color(0xFF1DB954),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstagramStylePreview extends StatelessWidget {
  const _InstagramStylePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glassy Track
          Container(
            width: 6,
            height: 90, // Shortened from 110
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Filled Level
          Positioned(
            bottom: 50, // Adjusted to match new track bottom
            child: Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 15,
            child: FaIcon(
              FontAwesomeIcons.instagram,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramStylePreview extends StatelessWidget {
  const _TelegramStylePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2AABEE), // Telegram Blue
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bubble aesthetic track
          Container(
            width: 14,
            height: 85, // Shortened from 90
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 20,
            child: FaIcon(
              FontAwesomeIcons.telegram,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubeStylePreview extends StatelessWidget {
  const _YouTubeStylePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF212121), // YT Dark
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Red Accent Track
          Container(
            width: 8,
            height: 90, // Shortened from 100
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 35,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000), // YT Red
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Positioned(
            bottom: 20,
            child: FaIcon(
              FontAwesomeIcons.youtube,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
