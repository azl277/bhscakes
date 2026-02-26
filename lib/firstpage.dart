import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/secondpage.dart';
import 'package:video_player/video_player.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import 'secondpage.dart';

class Firstpage extends StatefulWidget {
  const Firstpage({super.key});

  @override
  State<Firstpage> createState() => _FirstpageState();
}

class _FirstpageState extends State<Firstpage> {
  late VideoPlayerController _controller;
  Timer? _navigationTimer; // 🟢 Reference to cancel timer if needed

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/background.mp4")
      ..initialize().then((_) {
        // Ensure UI updates once video is loaded
        setState(() {}); 
        
        // 🟢 WEB FIX: Mute required for autoplay on many browsers
        _controller.setVolume(0); 
        _controller.setLooping(true);
        _controller.play();
      });

    // 🟢 SAFE NAVIGATION: Store timer to cancel in dispose()
    _navigationTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Secondpage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _navigationTimer?.cancel(); // 🟢 Prevent navigation if widget is destroyed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 RESPONSIVE VARIABLES
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    final double logoSize = isMobile ? 180 : 250; // Larger logo on Web
    final double fontSize = isMobile ? 24 : 32;   // Larger text on Web

    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // 1. BACKGROUND VIDEO
          SizedBox.expand(
            child: _controller.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // 2. DARK OVERLAY (Readability)
          Container(color: Colors.black.withOpacity(0.3)),

          // 3. CENTERED CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🟢 RESPONSIVE LOGO
                Image.asset(
                  'assets/bhslogo.png', // Ensure "assets/" prefix if usually required
                  width: logoSize,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),

                // 🟢 RESPONSIVE ANIMATED TEXT
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'we bake the best',
                      textStyle: GoogleFonts.indieFlower(
                        fontSize: fontSize, // Responsive Size
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(
                            blurRadius: 10.0,
                            color: Colors.black45,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      speed: const Duration(milliseconds: 150), // Slightly faster typing
                    ),
                  ],
                  totalRepeatCount: 1,
                  displayFullTextOnTap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}