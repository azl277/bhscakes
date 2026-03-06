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
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/background.mp4")
      ..initialize().then((_) {
        setState(() {});

        _controller.setVolume(0);
        _controller.setLooping(true);
        _controller.play();
      });

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
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    final double logoSize = isMobile ? 180 : 250;
    final double fontSize = isMobile ? 24 : 32;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
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

          Container(color: Colors.black.withOpacity(0.3)),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/bhslogo.png',
                  width: logoSize,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),

                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'we bake the best',
                      textStyle: GoogleFonts.indieFlower(
                        fontSize: fontSize,
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
                      speed: const Duration(milliseconds: 150),
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
