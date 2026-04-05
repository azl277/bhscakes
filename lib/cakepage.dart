import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform; 
import 'package:google_fonts/google_fonts.dart';
import 'package:project/addonspage.dart';

import 'package:project/customisepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Loginpage2.dart';
import 'cartpage1.dart';
import 'cupcakepage.dart';
import 'giftpage.dart';

List<Map<String, dynamic>> cartList = [];
ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
List<Map<String, String>> wishlist = [];
final Map<String, Uint8List> globalMemoryImageCache = {};

Widget buildCachedImage(String imageString, {double radius = 18}) {
  Widget image;
  try {
    if (imageString.isEmpty) {
      image = const Icon(Icons.image_not_supported, color: Colors.white24);
    } else if (imageString.startsWith('assets/')) {
      image = Image.asset(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
    } else if (imageString.startsWith('http')) {
      image = Image.network(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
    } else {
      if (!globalMemoryImageCache.containsKey(imageString)) {
        globalMemoryImageCache[imageString] = base64Decode(imageString);
      }
      image = Image.memory(globalMemoryImageCache[imageString] ?? Uint8List(0), fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
    }
  } catch (e) {
    image = const Icon(Icons.broken_image, color: Colors.white24);
  }
  return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: image) : image;
}

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class HoverAnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isAvailable;

  const HoverAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.isAvailable = true,
  });

  @override
  State<HoverAnimatedCard> createState() => _HoverAnimatedCardState();
}

class _HoverAnimatedCardState extends State<HoverAnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuart,
      transformAlignment: FractionalOffset.center,
      transform: Matrix4.identity()
        ..scale(_isHovered && widget.isAvailable ? 1.03 : 1.0)
        ..translate(0.0, _isHovered && widget.isAvailable ? -4.0 : 0.0),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = GestureDetector(
        onTap: widget.isAvailable ? widget.onTap : null,
        child: content,
      );
    }

    return MouseRegion(
      cursor: widget.isAvailable ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: content,
    );
  }
}

class _WishlistButton extends StatefulWidget {
  final Map<String, String> item;
  final VoidCallback onLoginRequired;

  const _WishlistButton({
    required this.item,
    required this.onLoginRequired,
  });

  @override
  State<_WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<_WishlistButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;
  bool _isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_controller);
    
    _checkInitialStatus();
  }

  @override
  void dispose() {
    _isDisposed = true; 
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkInitialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!_isDisposed && mounted) setState(() => _isLoading = false);
      return;
    }
    
    try {
      final event = await FirebaseDatabase.instance
          .ref()
          .child('users/${user.uid}/wishlist')
          .orderByChild('name')
          .equalTo(widget.item['name'])
          .once()
          .timeout(const Duration(seconds: 3)); 
          
      if (!_isDisposed && mounted) {
        setState(() {
          _isLiked = event.snapshot.exists;
          _isLoading = false; 
        });
      }
    } catch (e) {
      debugPrint("Wishlist Load Error for ${widget.item['name']}: $e");
      
      if (!_isDisposed && mounted) {
        setState(() {
          _isLiked = false;
          _isLoading = false; 
        });
      }
    }
  }

  void _handleTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      widget.onLoginRequired();
      return;
    }

    HapticFeedback.lightImpact();
    _controller.forward(from: 0.0); 
    setState(() => _isLiked = !_isLiked); 

    final DatabaseReference wishlistRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/wishlist');
    try {
      final event = await wishlistRef.orderByChild('name').equalTo(widget.item['name']).once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map;
        await wishlistRef.child(data.keys.first.toString()).remove();
      } else {
        await wishlistRef.push().set({
          'name': widget.item['name'], 
          'image': widget.item['image'], 
          'price': widget.item['price'], 
          'desc': widget.item['desc'] ?? '', 
          'added_at': ServerValue.timestamp,
        });
      }
    } catch (e) {
      debugPrint("Wishlist Error: $e");
      if (!_isDisposed && mounted) setState(() => _isLiked = !_isLiked); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: const SizedBox(
          width: 16, 
          height: 16, 
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
        ),
      );
    }
    
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border, 
              color: _isLiked ? Colors.red : Colors.grey, 
              size: 16
            ),
          ),
        ),
      ),
    );
  }
}

class AddOnCard extends StatefulWidget {
  final Map<String, String> item;
  final double width;

  const AddOnCard({super.key, required this.item, this.width = 140});

  @override
  State<AddOnCard> createState() => _AddOnCardState();
}

class _AddOnCardState extends State<AddOnCard> {
  final Color _accentPink = const Color(0xFFFF2E74);

  Future<void> _updateQuantity(int delta, int currentQuantity) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
try {
      if (delta > 0) {
        if (currentQuantity < 10) {
          
          int priceInt = int.tryParse((widget.item['price']?.toString() ?? '0').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

          await dbRef.push().set({
            'name': widget.item['name'] ?? 'Unknown Add-On', 
            'image': widget.item['image'] ?? '',
            'price': priceInt,
            'display_price': widget.item['price']?.toString() ?? '0', 
            'quantity': 1,
            'category': 'AddOn',
            'deliveryTime': widget.item['deliveryTime']?.toString() ?? '0',
            'deliveryUnit': widget.item['deliveryUnit']?.toString() ?? 'Hours',
            'added_at': ServerValue.timestamp,
          });
        }
      } else {
        if (currentQuantity > 0) {
          final snapshot = await dbRef.orderByChild('name').equalTo(widget.item['name']).limitToLast(1).get();

          if (snapshot.exists) {
            Map<dynamic, dynamic> children = snapshot.value as Map;
            String keyToDelete = children.keys.first;
            await dbRef.child(keyToDelete).remove();
          }
        }
      }
    } catch (e) {
      debugPrint("Error updating AddOn: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: cartCountNotifier,
      builder: (context, cartCount, child) {
        int quantity = cartList.where((e) => e['name'] == widget.item['name']).length;

        return HoverAnimatedCard(
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(widget.item['image'] ?? "", fit: BoxFit.contain),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: Column(
                    children: [
                      Text(
                        widget.item['name'] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.item['price'] ?? "",
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accentPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (quantity == 0)
                        InkWell(
                          onTap: () => _updateQuantity(1, quantity),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _accentPink.withOpacity(0.5)),
                            ),
                            child: Center(
                              child: Text(
                                "ADD",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: _accentPink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              InkWell(
                                onTap: () => _updateQuantity(-1, quantity),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.remove,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                "$quantity",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              InkWell(
                                onTap: () => _updateQuantity(1, quantity),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonShimmer({
    super.key, 
    required this.width, 
    required this.height, 
    this.borderRadius = 8
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class FloatingBlurredPng extends StatefulWidget {
  final String imagePath;
  final double size;
  final double blurAmount;
  final Alignment alignment;
  final int durationSeconds;

  const FloatingBlurredPng({
    super.key,
    required this.imagePath,
    required this.size,
    required this.blurAmount,
    required this.alignment,
    required this.durationSeconds,
  });

  @override
  State<FloatingBlurredPng> createState() => _FloatingBlurredPngState();
}

class _FloatingBlurredPngState extends State<FloatingBlurredPng> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _animation.value),
            child: child,
          );
        },
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: widget.blurAmount, sigmaY: widget.blurAmount),
          child: Opacity(
            opacity: 0.7, 
            child: Image.asset(
              widget.imagePath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.cake,
                size: widget.size,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CartBadge extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const CartBadge({super.key, required this.onLoginSuccess});

  @override
  State<CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends State<CartBadge> {
  bool _isLoginPromptOpen = false;
  final Color _accentPink = const Color(0xFFFF2E74);
  Timer? _autoCloseTimer;

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  
  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoginPromptOpen) {
        setState(() {
          _isLoginPromptOpen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: cartCountNotifier,
      builder: (context, cartCount, child) {
        double targetWidth = (!isLoggedIn && _isLoginPromptOpen)
            ? 130.0
            : (cartCount > 0 && isLoggedIn ? 75.0 : 52.0);

        return GestureDetector(
          onTap: () async {
            if (isLoggedIn) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Cartpage1()),
              );
            } else {
              setState(() {
                _isLoginPromptOpen = !_isLoginPromptOpen;
              });

              if (_isLoginPromptOpen) {
                _startAutoCloseTimer();
              }
            }
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _accentPink.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutQuart,
              width: targetWidth,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _accentPink,
                borderRadius: BorderRadius.circular(30),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (isLoggedIn && cartList.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        "${cartList.length}",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (!isLoggedIn && _isLoginPromptOpen) ...[
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isLoginPromptOpen ? 1.0 : 0.0,
                        child: GestureDetector(
                          onTap: () async {
                            _autoCloseTimer?.cancel();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Loginpage2(),
                              ),
                            );
                            if (mounted) {
                              setState(() {
                                _isLoginPromptOpen = false;
                              });
                            }
                            widget.onLoginSuccess();
                          },
                          child: Text(
                            "Login",
                            softWrap: false,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final ValueNotifier<bool> showAppBar;

  CategoryHeaderDelegate({required this.child, required this.showAppBar});

  @override
  double get minExtent => 90.0;
  @override
  double get maxExtent => 90.0;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    final double safeAreaTop = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<bool>(
      valueListenable: showAppBar,
      builder: (context, isVisible, _) {
        bool isPinned = shrinkOffset > 0 || overlapsContent;
        double yOffset = 0.0;

        if (isPinned) {
          if (isVisible) {
            yOffset = safeAreaTop + 70.0;
          } else {
            yOffset = safeAreaTop;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutQuart,
              top: 0,
              left: 0,
              right: 0,
              bottom: -yOffset,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: yOffset > safeAreaTop
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                padding: EdgeInsets.only(top: yOffset + 5, bottom: 5),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: 200,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool shouldRebuild(covariant CategoryHeaderDelegate oldDelegate) => true;
}

class AnimatedTopBanner extends StatefulWidget {
  final bool isMobile;
  
  const AnimatedTopBanner({super.key, required this.isMobile});

  @override
  State<AnimatedTopBanner> createState() => _AnimatedTopBannerState();
}

class _AnimatedTopBannerState extends State<AnimatedTopBanner> {
  int _currentIndex = 0;
  Timer? _imageTimer;

  final List<String> _centerImages = [
    'assets/nb.png', 
    'assets/cf.png',
    'assets/truffle.png',
  ];

  @override
  void initState() {
    super.initState();
    _imageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _centerImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    super.dispose();
  }

  Widget _buildTextContent(bool isWeb) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          "Freshly Baked",
          style: GoogleFonts.playfairDisplay(
            fontSize: isWeb ? 42 : 28, 
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4226), 
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Just for you, everyday.",
          style: GoogleFonts.inter(
            fontSize: isWeb ? 16 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8B5E34),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedImage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Image.asset(
        _centerImages[_currentIndex],
        key: ValueKey<int>(_currentIndex), 
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.isMobile ? 350 : 370, 
      width: widget.isMobile? double.infinity:1300,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.3, 0.5, 0.8, 1.0],
          colors: [
            Color.fromARGB(255, 255, 186, 67),
            Color.fromARGB(255, 255, 199, 45),
            Color.fromARGB(255, 255, 224, 132),
            Color.fromARGB(255, 255, 227, 149),
            Color.fromARGB(255, 255, 223, 158),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          const FloatingBlurredPng(
            imagePath: 'assets/nb.png',
            size: 25,
            blurAmount: 4.0, 
            alignment: Alignment(-0.8, -0.4),
            durationSeconds: 3,
          ),
          const FloatingBlurredPng(
            imagePath: 'assets/cf.png',
            size: 45,
            blurAmount: 2.5,
            alignment: Alignment(0.8, -0.2),
            durationSeconds: 4,
          ),
          const FloatingBlurredPng(
            imagePath: 'assets/truffle.png',
            size: 60,
            blurAmount: 1.0,
            alignment: Alignment(-0.8, 0.2),
            durationSeconds: 5,
          ),

          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: widget.isMobile
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          _buildTextContent(false),
                          const SizedBox(height: 20),
                          Expanded(child: _buildAnimatedImage()),
                          const SizedBox(height: 20),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 80.0),
                            child: _buildTextContent(true),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: _buildAnimatedImage(),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Cakepage extends StatefulWidget {
  final String? heroTag;
  const Cakepage({super.key, this.heroTag});

  @override
  State<Cakepage> createState() => _CakepageState();
}

class _CakepageState extends State<Cakepage> {
  final Map<String, Stream<QuerySnapshot>> _categoryStreams = {};

  final GlobalKey _addOnsKey = GlobalKey();
  final GlobalKey _cakesKey = GlobalKey();
  final GlobalKey _birthdayKey = GlobalKey();
  final GlobalKey _weddingKey = GlobalKey();

  final ValueNotifier<bool> _isScrollingDown = ValueNotifier(false);
  StreamSubscription<DatabaseEvent>? _cartSubscription;
  final Map<String, GlobalKey> _productKeys = {};
  String? _highlightedProductName;

  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _bgBlack = const Color(0xFF050505);

  late ScrollController _scrollController;
  bool _isAppBarVisible = true;

  bool _isStatusBarDark = false;
  final ValueNotifier<bool> _showAppBar = ValueNotifier(true);
  final ValueNotifier<bool> _showShadow = ValueNotifier(false);
  bool _isLoginPromptOpen = false;

  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);
  
  final ValueNotifier<Map<String, String>> _categoryThumbnailsNotifier = ValueNotifier({});
  
  PageController? _pageController;
  int _currentPage = 0;
  Timer? _timer;
  Timer? _highlightTimer;

  int _globalDeliveryMin = 3;
  int _globalDeliveryMax = 4;
  String _globalDeliveryUnit = "Hours";

  late Stream<QuerySnapshot> _productCategoriesStream;
  late Stream<QuerySnapshot> _addonsStream;

  double _calculateDynamicCardWidth(double availableWidth, int itemCount, double minWidth, double spacing, double maxWidth) {
    if (itemCount <= 0) return minWidth;
    double totalSpacing = spacing * (itemCount - 1);
    double calculatedWidth = (availableWidth - totalSpacing) / itemCount;
    
    if (calculatedWidth < minWidth) return minWidth;
    if (calculatedWidth > maxWidth) return maxWidth;
    return calculatedWidth;
  }

  Future<void> _scrollToProduct(String productName) async {
    final key = _productKeys[productName];

    if (key != null && key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutQuart,
        alignment: 0.5,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not find $productName")));
      }
    }
  }

  Future<void> _fetchGlobalSettings() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('settings').doc('store_status').get();
      if (snap.exists && snap.data() != null) {
        final data = (snap.data() as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(() {
            _globalDeliveryMin = data['stdDeliveryMin'] ?? 3;
            _globalDeliveryMax = data['stdDeliveryMax'] ?? 4;
            _globalDeliveryUnit = data['stdDeliveryUnit'] ?? "Hours";
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    }
  }

 Widget _buildAddonsHorizontalList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _addonsStream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
      }

      final docs = snapshot.data?.docs;

      if (docs == null || (docs?.isEmpty ?? true)) {
        return const SizedBox.shrink();
      }

      final products = docs.take(7).toList();
      int totalItems = products.length + 1;
        return Center(  
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableWidth = constraints.maxWidth - 48; // Padding
                double cardWidth = _calculateDynamicCardWidth(availableWidth, totalItems, 110.0, 14.0, 180.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Add Ons", style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllAddonsPage())),
                            child: Text("See All", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _accentPink)),
                          )
                        ],
                      ),
                    ),
                    SizedBox( 
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: totalItems,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          if (index == products.length) return _buildSeeMoreCard(width: cardWidth);
                          final data = (products[index].data() as Map<String, dynamic>?) ?? {};
                          final item = {
                            'name': data['name']?.toString() ?? '',
                            'price': data['price']?.toString() ?? 'Rs 0',
                            'image': data['image']?.toString() ?? '',
                            'category': 'addons',
                            'deliveryTime': data['deliveryTime']?.toString() ?? '0',
                            'deliveryUnit': data['deliveryUnit']?.toString() ?? 'Hours',
                          };
                          return _buildMiniAddOnCard(item, width: cardWidth);
                        },
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeeMoreCard({double width = 120.0}) {
    return HoverAnimatedCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AllAddonsPage()));
      },
      child: Container(
        width: width, 
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accentPink.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: _accentPink, size: 18),
            ),
            const SizedBox(height: 10),
            Text("See More", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMiniAddOnCard(Map<String, String> item, {GlobalKey? itemKey, double width = 100.0}) {
    return HoverAnimatedCard(
      child: Container(
        key: itemKey,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showAddOnModal(item);
            },
            borderRadius: BorderRadius.circular(20),
            splashColor: _accentPink.withOpacity(0.1),
            highlightColor: _accentPink.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF5F8), 
                      child: buildCachedImage(item['image'] ?? '', radius: 0),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              item['price'] ?? 'Rs 0',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _accentPink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _accentPink.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: _accentPink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPulsingTag(String tag) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.08),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }

  void _activateCartListener() {
    final user = FirebaseAuth.instance.currentUser;
    _cartSubscription?.cancel();

    if (user == null) {
      cartList.clear();
      cartCountNotifier.value = 0;
      return;
    }

    final ref = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');

    _cartSubscription = ref.onValue.listen((event) {
      cartList.clear();
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          cartList.add(Map<String, dynamic>.from(value));
        });
      }

      cartCountNotifier.value = cartList.length;
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
    );
    _productCategoriesStream = FirebaseFirestore.instance
        .collection('product_categories')
        .where('type', isEqualTo: 'products')
        .snapshots();

    _addonsStream = FirebaseFirestore.instance
        .collection('addons')
        .snapshots();

    _categoryStreams['addons'] = FirebaseFirestore.instance.collection('addons').snapshots();

    _activateCartListener();
    _preloadThumbnails();
    _fetchGlobalSettings();
    _scrollController.addListener(_onScroll);

    final productRef = FirebaseFirestore.instance.collection('products');

    _categoryStreams['Cakes'] = productRef
        .where('category', whereIn: ['Cakes', 'cakes', 'Cake', 'cake'])
        .snapshots();

    _categoryStreams['birthday'] = productRef
        .where(
          'category',
          whereIn: ['Birthday', 'birthday', 'Birthday Cake', 'birthday cake'],
        )
        .snapshots();

    _categoryStreams['wedding'] = productRef
        .where(
          'category',
          whereIn: ['Wedding', 'wedding', 'Wedding Cake', 'wedding cake'],
        )
        .snapshots();

    
    _categoryStreams['addons'] = FirebaseFirestore.instance
        .collection('products')
        .where('category', whereIn: ['Addons', 'addons', 'Add On', 'add on'])
        .snapshots();

    _categoryStreams['addons'] = productRef
        .where('category', whereIn: ['Addons', 'addons', 'Add On', 'add on'])
        .snapshots();
      
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300) {
        if (!_showShadow.value) _showShadow.value = true;
      } else {
        if (!_showShadow.value) _showShadow.value = false;
      }
    });
  }

  Future<void> _preloadThumbnails() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('product_categories')
          .where('type', isEqualTo: 'products')
          .get();
      List<String> categories = snap.docs
          .map((doc) => doc['name'].toString())
          .toList();

      categories.add('Cupcakes');

      Map<String, String> fetchedThumbnails = {};

      for (String cat in categories) {
        String? url = await _getCategoryThumbnail(cat);
        if (url != null && url.isNotEmpty) {
          fetchedThumbnails[cat] = url;
        }
      }

      if (mounted && fetchedThumbnails.isNotEmpty) {
        final currentMap = Map<String, String>.from(_categoryThumbnailsNotifier.value);
        currentMap.addAll(fetchedThumbnails);
        _categoryThumbnailsNotifier.value = currentMap;
      }
    } catch (e) {
      debugPrint("Error preloading thumbnails: $e");
    }
  }

  void _initController(bool isMobile) {
    double viewport = isMobile ? 1.0 : 0.6;
    if (_pageController == null) {
      _pageController = PageController(
        initialPage: 0,
        viewportFraction: viewport,
      );
      _currentPage = 0;
    } else if (_pageController?.viewportFraction != viewport) {
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: _currentPage,
        viewportFraction: viewport,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();

    if (_scrollController.hasClients) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    _scrollOffset.dispose();
    _categoryThumbnailsNotifier.dispose(); 
    super.dispose();
  }

  void _onScroll() {
    _scrollOffset.value = _scrollController.offset;
    bool shouldBeDark = _scrollController.offset > 360;

    if (shouldBeDark != _isStatusBarDark) {
      _isStatusBarDark = shouldBeDark;

      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: shouldBeDark
              ? Brightness.dark
              : Brightness.light,
        ),
      );
    }
  }

  Uint8List? safeBase64Decode(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;

    try {
      return base64Decode(base64String);
    } catch (e) {
      debugPrint("❌ Image decode failed: $e");
      return null;
    }
  }

  Future<String?> _getCategoryThumbnail(String categoryType) async {
    try {
      if (categoryType.toLowerCase() == 'cupcakes') {
        final doc = await FirebaseFirestore.instance
            .collection('cupcakes')
            .limit(1)
            .get();
        if (doc.docs.isNotEmpty) return doc.docs.first['image']?.toString();
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .where('category', isEqualTo: categoryType)
            .limit(1)
            .get();
        if (doc.docs.isNotEmpty) return doc.docs.first['image']?.toString();
      }
    } catch (e) {
      debugPrint("Error fetching thumbnail for $categoryType: $e");
    }
    return null;
  }
Widget _buildQuickCategories({bool isSticky = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _productCategoriesStream, // Use FirebaseFirestore.instance.collection('product_categories').where('type', isEqualTo: 'gifts').snapshots() if this is the Gift page
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var sortedDocs = snapshot.data?.docs.toList() ?? [];
        sortedDocs?.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
Timestamp? tA = dataA?['createdAt'] as Timestamp?;
          Timestamp? tB = (b.data() as Map)['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tA.compareTo(tB);
        });

        List<Map<String, dynamic>> quickCategories = (sortedDocs ?? []).map((doc) {
          String catName = doc['name'];
          if (!_productKeys.containsKey(catName)) {
            _productKeys[catName] = GlobalKey();
          }
          return {
            "title": catName,
            "type": catName,
            "isRoute": false,
            "key": _productKeys[catName],
          };
        }).toList();

        return Container(
          height: isSticky ? 110 : 95, // Corrected height to prevent clipping
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, // Prevents transparent bleed when scrolling
            boxShadow: isSticky ? [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
            ] : [],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // MAGIC BULLET: Centers items on wide screens
                  children: quickCategories.map((cat) {
                    final String catType = cat['type'];

                    return Padding(
                      padding: const EdgeInsets.only(right: 24.0), // Replaces separatorBuilder
                      child: GestureDetector(
                        onTap: () {
                          if (cat['isRoute'] == true) {
                            if (cat['title'] == 'Cupcakes') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const Cupcakepage()));
                            }
                          } else {
                            final GlobalKey? key = cat['key'];
                            if (key != null && key.currentContext != null) {
                              Scrollable.ensureVisible(
                                key.currentContext!,
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOutCubic,
                                alignment: 0.1,
                              );
                            }
                          }
                        },
                        child: HoverAnimatedCard( // Added hover effect to categories!
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: isSticky ? 65 : 55,
                                width: isSticky ? 65 : 55,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(35),
                                  child: ValueListenableBuilder<Map<String, String>>(
                                    valueListenable: _categoryThumbnailsNotifier,
                                    builder: (context, thumbnails, child) {
                                      return thumbnails.containsKey(catType)
                                          ? buildImage(thumbnails[catType]!, radius: 35)
                                          : const Center(child: Icon(Icons.cake_rounded, color: Color(0xFFFF2E74), size: 24));
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat['title'],
                                style: GoogleFonts.inter(
                                  fontSize: isSticky ? 12 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget buildImage(String imageString, {double radius = 18}) {
    Widget image;

    try {
      if (imageString.startsWith('assets/')) {
        image = Image.asset(
          imageString,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else if (imageString.startsWith('http')) {
        image = Image.network(
          imageString,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else {
        image = Image.memory(
          base64Decode(imageString),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      }
    } catch (e) {
      image = const Icon(Icons.broken_image, color: Colors.white24);
    }

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          "Login Required",
          style: GoogleFonts.playfairDisplay(color: Colors.white),
        ),
        content: Text(
          "Please login to add items to your cart.",
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentPink),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Loginpage2()),
              );
              if (mounted) setState(() {});
            },
            child: const Text("Login", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoWrapper() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('welcome_coupon').snapshots(),
      builder: (context, settingsSnapshot) {
        if (!settingsSnapshot.hasData || settingsSnapshot.data?.exists != true) {
          return const SizedBox.shrink(); 
        }

        final data = settingsSnapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final bool isActive = data['isActive'] ?? false;
        final bool showWebBanner = data['showWebDownloadBanner'] ?? true;
        
        if (!isActive) {
          return const SizedBox.shrink(); 
        }

        final String code = data['code'] ?? 'NEW50';
        final int discount = data['discountAmount'] ?? 50;

        if (kIsWeb) {
          if (showWebBanner) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF000000)], 
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ]
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DOWNLOAD BUTTER HEARTS CAKES APP",
                              style: GoogleFonts.oswald(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                children: [
                                  const TextSpan(text: "GET "),
                                  TextSpan(text: "₹$discount OFF", style: const TextStyle(color: Color(0xFFFF2E74), fontWeight: FontWeight.bold)),
                                  const TextSpan(text: " ON YOUR FIRST ORDER! USE CODE "),
                                  TextSpan(text: code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink(); 
          }
        }

        Widget promoWidget = Column(
          children: [
            _buildPromoContainer(code, discount),
            const SizedBox(height: 25), 
          ],
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return promoWidget; 
        }

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref().child('users/${user.uid}/orders').limitToFirst(1).onValue,
          builder: (context, rtdbSnapshot) {
            if (rtdbSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (rtdbSnapshot.hasData && rtdbSnapshot.data?.snapshot.exists == true) {
              return const SizedBox.shrink(); 
            }
            
            return promoWidget; 
          },
        );
      },
    );
  }

  Widget _buildPromoContainer(String code, int discount) {
    if (kIsWeb) return const SizedBox.shrink();
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), 
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9E1B46), Color(0xFFE63971), Color(0xFFFF8DAF), Color(0xFFE63971), Color(0xFF8A143A),
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "First Order Special",
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFFFF0F5),
                              fontSize: 19, fontWeight: FontWeight.w800,
                              shadows: [BoxShadow(color: Colors.black.withOpacity(0.6), offset: const Offset(1, 1), blurRadius: 2)],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Get ₹$discount OFF on your first purchase.",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13, fontWeight: FontWeight.w500,
                              shadows: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0.5, 0.5), blurRadius: 1)],
                            ),
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  (constraints.maxWidth / 12).floor(),
                                  (index) => Container(
                                    width: 6, height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(1),
                                      boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), offset: const Offset(0, 1), blurRadius: 0)],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFD1DF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(2, 4), blurRadius: 6),
                          BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 2),
                        ],
                      ),
                      child: Text(
                        code,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9E1B46),
                          fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2,
                          shadows: [BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(1, 1), blurRadius: 1)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: -12, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    height: 24, width: 24,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(2, 0), blurRadius: 4, spreadRadius: -1)]),
                  ),
                ),
              ),
              Positioned(
                right: -12, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    height: 24, width: 24,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(-2, 0), blurRadius: 4, spreadRadius: -1)]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _showCustomizeModal(
    Map<String, String> item,
    Map<String, dynamic> availability,
    Map<String, dynamic> rawFlavours, 
    List<dynamic> rawShapes,
    List<dynamic> rawWeights,
  ) {
    
    int parsePriceSafe(dynamic priceData) {
      if (priceData == null) return 0;
      if (priceData is num) return priceData.toInt();
      if (priceData is String) {
        String cleanString = priceData.replaceAll(RegExp(r'[^0-9\-]'), '');
        return int.tryParse(cleanString) ?? 0;
      }
      return 0;
    }

    Map<String, int> availableFlavours = {};
    if (rawFlavours.isNotEmpty) {
       if (rawFlavours.values.first is List) {
           List<dynamic> fList = rawFlavours.values.first as List<dynamic>;
           for(var f in fList) {
               if(f is Map && f['name'] != null) {
                   availableFlavours[f['name'].toString()] = parsePriceSafe(f['price']);
               }
           }
       } else {
           rawFlavours.forEach((key, value) {
              availableFlavours[key] = parsePriceSafe(value);
           });
       }
    }

    bool useOldMultiplierLogic = rawWeights.isEmpty;

    Map<String, int> availableShapes = {};
    if (rawShapes.isNotEmpty) {
      for(var s in rawShapes) {
        if(s is Map && s['name'] != null) {
          availableShapes[s['name'].toString()] = parsePriceSafe(s['price']);
        }
      }
    } else {
      if (availability['round'] != false) availableShapes['Round'] = 0;
      if (availability['square'] != false) availableShapes['Square'] = 0;
      if (availability['heart'] != false) availableShapes['Heart'] = 50; 
      if (availableShapes.isEmpty) availableShapes = {'Round': 0, 'Square': 0, 'Heart': 50};
    }

    Map<String, int> availableWeights = {};
    if (rawWeights.isNotEmpty) {
      double baseWeightVal = 1.0;
      if (rawWeights.first is Map && rawWeights.first['weight'] != null) {
        baseWeightVal = double.tryParse(rawWeights.first['weight'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0;
      }

      for (var w in rawWeights) {
        if (w is Map && w['weight'] != null) {
          int parsedPrice = parsePriceSafe(w['price']);
          double currentWeightVal = double.tryParse(w['weight'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          
          if (currentWeightVal < baseWeightVal && currentWeightVal > 0) {
            parsedPrice = -(parsedPrice.abs());
          }

          availableWeights[w['weight'].toString()] = parsedPrice;
        }
      }
    } else {
      if (availability['halfKg'] != false) availableWeights['0.5 Kg'] = 0;
      if (availability['oneKg'] != false) availableWeights['1 Kg'] = 0;
      if (availability['oneHalfKg'] != false) availableWeights['1.5 Kg'] = 0;
      if (availability['twoKg'] != false) availableWeights['2 Kg'] = 0;
      if (availability['twoHalfKg'] != false) availableWeights['2.5 Kg'] = 0;
      if (availability['threeKg'] != false) availableWeights['3 Kg'] = 0;
      if (availableWeights.isEmpty) availableWeights = {'0.5 Kg': 0, '1 Kg': 0, '1.5 Kg': 0, '2 Kg': 0, '2.5 Kg': 0, '3 Kg': 0};
    }

    final TextEditingController cakeWritingController = TextEditingController();
    final FocusNode writingFocus = FocusNode();

String safeCategory = item['category']?.toString()?.toLowerCase() ?? '';

bool isCakeCategory = item['category'] == null ||
                      safeCategory == 'cakes' ||
                      safeCategory == 'birthday' ||
                      safeCategory == 'wedding' ||
                      safeCategory.contains('cake');
String priceString = (item['isOffer'] == 'true' || item['isOffer'] == true) 
    ? (item['offerPrice']?.toString() ?? '0') 
    : (item['price']?.toString() ?? '0');


    int basePrice = int.tryParse(priceString.replaceAll(RegExp(r'[^0-9\-]'), '')) ?? 0;

    String selectedShape = availableShapes.keys.first;
    int selectedShapePrice = availableShapes.values.first;

    String selectedWeight = availableWeights.containsKey("1 Kg") ? "1 Kg" : availableWeights.keys.first;
    int selectedWeightPrice = availableWeights[selectedWeight] ?? availableWeights.values.first;

    String? selectedFlavourKey = availableFlavours.isNotEmpty ? availableFlavours.keys.first : null;
    int selectedFlavourPrice = availableFlavours.isNotEmpty ? availableFlavours.values.first : 0;
        
    String deliveryTime = item['deliveryTime'] ?? '';
    String deliveryUnit = item['deliveryUnit'] ?? 'Hours';
    int dt = int.tryParse(deliveryTime) ?? 0;
    
    String displayDeliveryTime = "";
    int timeInMinsForColor = 0;

    if (dt > 0) {
      displayDeliveryTime = "Estimated delivery in $deliveryTime $deliveryUnit";
      String u = deliveryUnit.toLowerCase();
      timeInMinsForColor = (u == 'days') ? dt * 24 * 60 : (u == 'minutes' || u == 'mins') ? dt : dt * 60;
    } else {
      displayDeliveryTime = "Standard Delivery: $_globalDeliveryMin to $_globalDeliveryMax $_globalDeliveryUnit";
      String u = _globalDeliveryUnit.toLowerCase();
      timeInMinsForColor = (u == 'days') ? _globalDeliveryMax * 24 * 60 : (u == 'minutes' || u == 'mins') ? _globalDeliveryMax : _globalDeliveryMax * 60;
    }

    Color dTextColor = Colors.blue.shade700;

    if (timeInMinsForColor > 0 && timeInMinsForColor <= 60) {
      dTextColor = Colors.green.shade700;
    } else if (timeInMinsForColor > 300) { 
      dTextColor = Colors.red.shade700;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            int currentPrice = basePrice;
            
            if (useOldMultiplierLogic) {
              double multiplier = 1.0;
              switch (selectedWeight) {
                case '0.5 Kg': multiplier = 0.5; break;
                case '1 Kg': multiplier = 1.0; break;
                case '1.5 Kg': multiplier = 1.5; break;
                case '2 Kg': multiplier = 2.0; break;
                case '2.5 Kg': multiplier = 2.5; break;
                case '3 Kg': multiplier = 3.0; break;
              }
              currentPrice = (basePrice * multiplier).toInt() + selectedFlavourPrice;
              if (selectedShape == "Heart") currentPrice += 50;
            } else {
              currentPrice = basePrice + selectedWeightPrice + selectedShapePrice + selectedFlavourPrice;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 14),
                        Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), 
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          )
                                        ]
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: SizedBox(
                                          height: 110,
                                          width: 110,
                                          child: buildImage(item['image'] ?? ""),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] ?? "",
                                            style: GoogleFonts.playfairDisplay(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          TweenAnimationBuilder<double>(
                                            key: ValueKey(currentPrice),
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOutCubic,
                                            tween: Tween<double>(
                                              begin: basePrice.toDouble(),
                                              end: currentPrice.toDouble(),
                                            ),
                                            builder: (context, value, child) {
                                              return Text(
                                                "₹${value.toInt()}",
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  color: _accentPink,
                                                ),
                                              );
                                            },
                                          ),
                                          
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.green.shade200)
                                            ),
                                            child: Text(
                                              "In Stock",
                                              style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 30),

                               if ((item['desc']?.toString() ?? '').isNotEmpty) ...[
                                  Text("DESCRIPTION", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: Colors.grey.shade500)),
                                  const SizedBox(height: 8),
                                  Text(item['desc'] ?? "", style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: Colors.black87)),
                                  const SizedBox(height: 25),
                                ],
                                
                                Text("DELIVERY", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: Colors.grey.shade500)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined, size: 20, color: dTextColor),
                                    const SizedBox(width: 10),
                                    Text(displayDeliveryTime, style: GoogleFonts.inter(fontSize: 14, color: dTextColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 25),
                                Divider(color: Colors.grey.shade200, thickness: 1.5),
                                const SizedBox(height: 25),

                                _buildPremiumVariantSelector(
                                  title: "Select Shape",
                                  items: availableShapes,
                                  selectedValue: selectedShape,
                                  onSelect: (key, val) => setModalState(() {
                                    selectedShape = key;
                                    selectedShapePrice = val;
                                  })
                                ),

                                _buildPremiumVariantSelector(
                                  title: "Select Weight",
                                  items: availableWeights,
                                  selectedValue: selectedWeight,
                                  onSelect: (key, val) => setModalState(() {
                                    selectedWeight = key;
                                    selectedWeightPrice = val;
                                  })
                                ),

                                _buildPremiumVariantSelector(
                                  title: "Select Flavor",
                                  items: availableFlavours,
                                  selectedValue: selectedFlavourKey ?? '',
                                  onSelect: (key, val) => setModalState(() {
                                    selectedFlavourKey = key;
                                    selectedFlavourPrice = val;
                                  })
                                ),
                                

                              if (isCakeCategory) ...[
                                Text("Message on Cake", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                const SizedBox(height: 12),
                                AnimatedBuilder(
                                  animation: writingFocus,
                                  builder: (ctx, child) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        boxShadow: writingFocus.hasFocus ? [BoxShadow(color: _accentPink.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))] : []
                                      ),
                                      child: TextField(
                                        controller: cakeWritingController,
                                        focusNode: writingFocus,
                                        maxLength: 30,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
                                        decoration: InputDecoration(
                                          hintText: "E.g., Happy Birthday John...",
                                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          counterStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _accentPink, width: 2)),
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.4), width: 1)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10)),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentPink,
                                  elevation: 8,
                                  shadowColor: _accentPink.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Map<String, int> flavorsToPass = {};
                                  if (selectedFlavourKey != null) flavorsToPass[selectedFlavourKey!] = selectedFlavourPrice;

                                  _addToCartWithDetails(item, selectedShape, selectedWeight, currentPrice, flavorsToPass, cakeWritingController.text);
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 12),
                                    TweenAnimationBuilder<double>(
                                      key: ValueKey(currentPrice),
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(begin: basePrice.toDouble(), end: currentPrice.toDouble()),
                                      builder: (context, value, child) {
                                        return Text(
                                          "ADD TO CART  •  ₹${value.toInt()}",
                                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumVariantSelector({
    required String title,
    required Map<String, int> items,
    required String selectedValue,
    required Function(String, int) onSelect,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.entries.map((entry) {
              bool isSelected = selectedValue == entry.key;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(entry.key, entry.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentPink : Colors.white,
                    borderRadius: BorderRadius.circular(30), 
                    border: Border.all(color: isSelected ? _accentPink : Colors.grey.shade300, width: 1.5),
                    boxShadow: isSelected ? [BoxShadow(color: _accentPink.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))] : [],
                  ),
                  child: Text(
                    entry.key,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOnsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: 'addons')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || (snapshot.data?.docs?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }

final products = snapshot.data?.docs ?? [];
        int totalItems = products.length;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableWidth = constraints.maxWidth - 48; 
                double cardWidth = _calculateDynamicCardWidth(availableWidth, totalItems, 140.0, 14.0, 220.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                      child: Text(
                        "Add Ons",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: totalItems,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final data = (products[index].data() as Map<String, dynamic>?) ?? {};

                          final addonItem = {
                            "name": data['name']?.toString() ?? "",
                            "price": data['price']?.toString() ?? "Rs 0",
                            "image": data['image']?.toString() ?? "",
                            'deliveryTime': data['deliveryTime']?.toString() ?? '0',
                            'deliveryUnit': data['deliveryUnit']?.toString() ?? 'Hours',
                          };

                          return AddOnCard(
                            item: addonItem, width: cardWidth
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySkeleton(String title, int crossAxisCount, double childAspectRatio) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
              child: Row(
                children: [
                  Container(
                    height: 20,
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SkeletonShimmer(width: 150, height: 24, borderRadius: 5),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: crossAxisCount * 2,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: const SkeletonShimmer(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 15,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonShimmer(
                                width: double.infinity,
                                height: 16,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 6),
                              SkeletonShimmer(
                                width: 80,
                                height: 12,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SkeletonShimmer(
                                    width: 50,
                                    height: 16,
                                    borderRadius: 4,
                                  ),
                                  SkeletonShimmer(
                                    width: 28,
                                    height: 28,
                                    borderRadius: 14,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, String category, {GlobalKey? key}) {
    if (!_categoryStreams.containsKey(category)) {
      _categoryStreams[category] = FirebaseFirestore.instance.collection('products').where('category', isEqualTo: category).snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _categoryStreams[category],
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final double screenWidth = MediaQuery.of(context).size.width;
        final double width = screenWidth > 1200 ? 1200 : screenWidth;

        int crossAxisCount = width >= 1200 ? 6 : width >= 900 ? 5 : width >= 600 ? 4 : 2; 
        double childAspectRatio = width >= 1200 ? 0.78 : width >= 900 ? 0.72 : width >= 600 ? 0.68 : 0.62; 

        if (snapshot.connectionState == ConnectionState.waiting) return _buildCategorySkeleton(title, crossAxisCount, childAspectRatio);
        if (!snapshot.hasData || (snapshot.data?.docs?.isEmpty ?? true)) return const SizedBox.shrink();

final products = snapshot.data?.docs ?? [];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      Container(height: 18, width: 4, decoration: BoxDecoration(color: _accentPink, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Text(title, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final doc = products[index];
                      final data = (doc.data() as Map<String, dynamic>?) ?? {};
                      
                      final Map<String, String> itemMap = { 
                        'id': doc.id,
                        'name': data['name']?.toString() ?? 'Unknown',
                        'image': data['image']?.toString() ?? '',
                        'price': data['price']?.toString() ?? 'Rs 0',
                        'desc': data['desc']?.toString() ?? '',
                        'isAvailable': (data['isAvailable'] ?? true).toString(),
                        'isOffer': (data['isOffer'] ?? false).toString(),
                        'offerPrice': data['offerPrice']?.toString() ?? '',
                        'deliveryTime': data['deliveryTime']?.toString() ?? '0',
                        'deliveryUnit': data['deliveryUnit']?.toString() ?? 'Hours',
                      };
                      
                      Map<String, dynamic> rawFlavours = data['flavors'] != null && data['flavors'] is List 
                          ? {'list': data['flavors']}
                          : data['flavors'] ?? {};

                      List<dynamic> rawShapes = data['shapes'] is List ? data['shapes'] : [];
                      List<dynamic> rawWeights = data['weights'] is List ? data['weights'] : [];

                      return _buildCompactCakeCard(
                        itemMap, 
                        data['availability'] ?? {}, 
                        rawFlavours, 
                        rawShapes, 
                        rawWeights,
                        itemKey: _productKeys[itemMap['name']]
                      ); 
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniCategorySection(
    String title,
    String category, {
    required GlobalKey<State<StatefulWidget>> key,
  }) {
    final stream = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: category)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        
        if (!snapshot.hasData || (snapshot.data?.docs?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
final products = snapshot.data?.docs ?? [];
        int totalItems = products.length;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableWidth = constraints.maxWidth - 48; 
                double cardWidth = _calculateDynamicCardWidth(availableWidth, totalItems, 110.0, 18.0, 160.0);

                return Column(
                  key: key,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                      child: Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: totalItems,
                        separatorBuilder: (_, __) => const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          final data = (products[index].data() as Map<String, dynamic>?) ?? {};
                          final String name = data['name']?.toString() ?? '';
                          if (name.isNotEmpty && !_productKeys.containsKey(name)) {
                            _productKeys[name] = GlobalKey();
                          }

                          final item = {
                            'name': name,
                            'price': data['price']?.toString() ?? 'Rs 0',
                            'image': data['image']?.toString() ?? '',
                            'category': data['category']?.toString() ?? 'AddOn',
                            'deliveryTime': data['deliveryTime']?.toString() ?? '0',
                            'deliveryUnit': data['deliveryUnit']?.toString() ?? 'Hours',
                          };

                          return _buildMiniAddOnCard(item, itemKey: _productKeys[name], width: cardWidth);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactCakeCard(
    Map<String, String> item,
    Map<String, dynamic> availability,
    Map<String, dynamic> rawFlavours, 
    List<dynamic> rawShapes,
    List<dynamic> rawWeights, {
    GlobalKey? itemKey,
  }) {
    bool isAvailable = item['isAvailable'] != 'false';
    bool isOffer = item['isOffer'] == 'true';
    String offerPrice = item['offerPrice'] ?? '';

    String deliveryTime = item['deliveryTime'] ?? '';
    String deliveryUnit = item['deliveryUnit'] ?? 'Hours';
    int dt = int.tryParse(deliveryTime) ?? 0;
    
    String displayDeliveryTime = "";
    int timeInMinsForColor = 0;

    if (dt > 0) {
      displayDeliveryTime = "Delivers in $deliveryTime $deliveryUnit";
      String u = deliveryUnit.toLowerCase();
      timeInMinsForColor = (u == 'days') ? dt * 24 * 60 : (u == 'minutes' || u == 'mins') ? dt : dt * 60;
    } else {
      displayDeliveryTime = "Delivers in $_globalDeliveryMin to $_globalDeliveryMax $_globalDeliveryUnit";
      String u = _globalDeliveryUnit.toLowerCase();
      timeInMinsForColor = (u == 'days') ? _globalDeliveryMax * 24 * 60 : (u == 'minutes' || u == 'mins') ? _globalDeliveryMax : _globalDeliveryMax * 60;
    }

    Color dTextColor = Colors.blue.shade700;
    Color dBgColor = const Color.fromARGB(255, 255, 255, 255);

    if (timeInMinsForColor > 0 && timeInMinsForColor <= 60) {
      dTextColor = Colors.green.shade700;
      dBgColor = const Color.fromARGB(255, 255, 255, 255);
    } else if (timeInMinsForColor > 300) { 
      dTextColor = Colors.red.shade700;
      dBgColor = const Color.fromARGB(255, 255, 255, 255);
    }

    return HoverAnimatedCard(
      isAvailable: isAvailable,
      onTap: () => _showCustomizeModal(item, availability, rawFlavours, rawShapes, rawWeights),
      child: Container(
        key: itemKey,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Opacity(
                      opacity: isAvailable ? 1.0 : 0.6,
                      child: Hero(
                        tag: "${item['name']}_grid_${item['id']}",
                        child: isAvailable
                            ? buildImage(item['image'] ?? "")
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ]),
                                child: buildImage(item['image'] ?? ""),
                              ),
                      ),
                    ),
                  ),

                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white38,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "SOLD OUT",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (isAvailable && isOffer)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accentPink, Colors.pinkAccent],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _accentPink.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "OFFER",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Positioned(
                    top: 10, 
                    right: 10,
                    child: _WishlistButton(
                      item: item,
                      onLoginRequired: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
                      },
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isAvailable
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['desc'] ?? "Delicious cake",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: dBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled_rounded, size: 10, color: dTextColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayDeliveryTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: dTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isOffer && isAvailable) ...[
                              Text(
                                item['price'] ?? "",
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Rs $offerPrice",
                                style: GoogleFonts.montserrat(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              Text(
                                item['price'] ?? "",
                                style: GoogleFonts.montserrat(
                                  color: isAvailable
                                      ? _accentPink
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? _accentPink
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAvailable
                              ? Icons.add
                              : Icons.remove_shopping_cart_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCartWithDetails(
    Map<String, String> item,
    String shape,
    String weight,
    int price,
    Map<String, int> finalFlavourMap,
    String writing,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Loginpage2()),
      );
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'selected_shape': shape,
      'selected_weight': weight,
      'price': price,
      'display_price': "Rs $price",
      'quantity': 1,
      'flavours': jsonEncode(finalFlavourMap),
      'cakeWriting': writing.isEmpty ? "No Message" : writing,
      'delivery_address': currentSavedAddress,
      'category': 'Cake',
      'added_at': ServerValue.timestamp,
      'deliveryTime': item['deliveryTime'] ?? '0',
      'deliveryUnit': item['deliveryUnit'] ?? 'Hours',
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/${user.uid}/cart',
      );
      await dbRef.push().set(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2000),
            width: MediaQuery.of(context).size.width > 600 ? 400 : null,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentPink.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: _accentPink.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _accentPink, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Added to Basket",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${item['name']} ($weight)",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const Cartpage1()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("View Cart", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Cart Sync Error: $e");
    }
  }

  void _showAddOnModal(Map<String, String> item) {
    int quantity = 1;
    int basePrice =
       int.tryParse(item['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int currentPrice = basePrice * quantity;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 380,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: SizedBox(
                                    height: 100,
                                    width: 100,
                                    child: buildImage(item['image'] ?? ''),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color.fromARGB(
                                            255,
                                            177,
                                            25,
                                            25,
                                          ),
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Rs $basePrice",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _accentPink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            Text(
                              "Select Quantity",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 15),

                            Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Colors.black87,
                                    ),
                                    onPressed: () {
                                      if (quantity > 1)
                                        setModalState(() => quantity--);
                                    },
                                  ),
                                  Text(
                                    "$quantity",
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.black87,
                                    ),
                                    onPressed: () {
                                      if (quantity < 50)
                                        setModalState(() => quantity++);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addAddonToCart(item, quantity, currentPrice);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "ADD TO CART  •  ₹$currentPrice",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addAddonToCart(
    Map<String, String> item,
    int quantity,
    int totalPrice,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': totalPrice,
      'display_price': "Rs $totalPrice",
      'quantity': quantity,
      'category': item['category'] ?? 'AddOn',
      'delivery_address': currentSavedAddress,
      'deliveryTime': item['deliveryTime'] ?? '0',
      'deliveryUnit': item['deliveryUnit'] ?? 'Hours',
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/${user.uid}/cart',
      );
      await dbRef.push().set(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
            width: 400,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentPink.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: _accentPink.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _accentPink, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Added to Basket",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${item['name']} (Qty: $quantity)",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const Cartpage1()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("View Cart", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding addon: $e");
    }
  }

  Future<void> _addToCartSimple(Map<String, String> item) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
      return;
    }

    int priceInt =
       int.tryParse(item['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': priceInt,
      'display_price': item['price'],
      'quantity': 1,
      'category': 'AddOn',
      'deliveryTime': item['deliveryTime'] ?? '0',
      'deliveryUnit': item['deliveryUnit'] ?? 'Hours',
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/${user.uid}/cart',
      );
      await dbRef.push().set(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${item['name']} added to cart!"),
            backgroundColor: _accentPink,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print("Error adding addon: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;
    _initController(isMobile);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal) return false;

              if (notification.direction == ScrollDirection.reverse) {
                if (_showAppBar.value) _showAppBar.value = false;
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_showAppBar.value) _showAppBar.value = true;
              }
              return true;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      
                      widget.heroTag != null
                          ? Hero(
                              tag: widget.heroTag!,
                              child: AnimatedTopBanner(isMobile: isMobile),
                            )
                          : AnimatedTopBanner(isMobile: isMobile),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                child: _buildAddonsHorizontalList(),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 20), 
              ),

                SliverToBoxAdapter(
                  child: _buildPromoWrapper(),
                ),
                 
                SliverPersistentHeader(
                  pinned: true,
                  delegate: CategoryHeaderDelegate(
                    showAppBar: _showAppBar,
                    child: _buildQuickCategories(isSticky: true),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                   stream: _productCategoriesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        );

                      var sortedDocs = snapshot.data?.docs.toList();
                      sortedDocs?.sort((a, b) {
                        Timestamp? tA =
                            (a.data() as Map)['createdAt'] as Timestamp?;
                        Timestamp? tB =
                            (b.data() as Map)['createdAt'] as Timestamp?;
                        if (tA == null || tB == null) return 0;
                        return tA.compareTo(tB);
                      });

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildMiniCategorySection(
                            "Add Ons",
                            "addons",
                            key: _addOnsKey,
                          ),

                          ...(sortedDocs ?? []).map((doc) {
                            String catName = doc['name'];

                            if (!_productKeys.containsKey(catName)) {
                              _productKeys[catName] = GlobalKey();
                            }

                            return _buildCategorySection(
                              catName,
                              catName,
                              key: _productKeys[catName],
                            );
                          }).toList(),

                          const SizedBox(height: 100),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: _showAppBar,
            builder: (context, visible, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
                top: visible ? MediaQuery.of(context).padding.top + 5 : -120,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: visible ? 1 : 0,
                  child: _buildElegantGlassAppBar(isMobile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildElegantGlassAppBar(bool isMobile) {
    final double barHeight = isMobile ? 60.0 : 70.0;
    final double iconSize = isMobile ? 36.0 : 40.0;
    final double horizontalPadding = isMobile ? 12.0 : 24.0;
    final double fontSize = isMobile ? 16.0 : 18.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ValueListenableBuilder<bool>(
          valueListenable: _showShadow,
          builder: (context, showShadow, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: showShadow
                    ? [
                        const BoxShadow(
                          color: Color.fromARGB(30, 0, 0, 0),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: barHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: showShadow
                          ? Colors.black.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    "BUTTER HEARTS CAKES",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.oswald(
                                      color: Colors.white,
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGlassMenuDropdown(size: iconSize),
                            SizedBox(width: isMobile ? 8 : 10),
                            CartBadge(
                              onLoginSuccess: () {
                                _activateCartListener();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassMenuDropdown({double size = 40.0}) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 50),
        elevation: 20,
        tooltip: "Menu",
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        onSelected: (value) {
          if (value == 'cupcakes') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Cupcakepage()),
            );
          } else if (value == 'gifts') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Giftpage()), 
            );
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'cupcakes',
            child: Row(
              children: [
                const Icon(Icons.cake, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Cupcakes', style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'gifts',
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20), 
                const SizedBox(width: 12),
                Text('Gifts', style: GoogleFonts.inter(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

  Widget _buildPromoWrapper() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('welcome_coupon').snapshots(),
      builder: (context, settingsSnapshot) {
if (!settingsSnapshot.hasData || settingsSnapshot.data?.exists != true) { 
  return const SizedBox.shrink(); // or whatever your loading state is
}

var data = settingsSnapshot.data?.data() as Map<String, dynamic>?;

     
        if (data == null) return const SizedBox.shrink();

        final bool isActive = data['isActive'] ?? false;
        final bool showWebBanner = data['showWebDownloadBanner'] ?? true;
        
        if (!isActive) {
          return const SizedBox.shrink(); 
        }

        final String code = data['code'] ?? 'NEW50';
        final int discount = data['discountAmount'] ?? 50;

        if (kIsWeb) {
          if (showWebBanner) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF000000)], 
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ]
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DOWNLOAD BUTTER HEARTS CAKES APP",
                              style: GoogleFonts.oswald(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                children: [
                                  const TextSpan(text: "GET "),
                                  TextSpan(text: "₹$discount OFF", style: const TextStyle(color: Color(0xFFFF2E74), fontWeight: FontWeight.bold)),
                                  const TextSpan(text: " ON YOUR FIRST ORDER! USE CODE "),
                                  TextSpan(text: code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink(); 
          }
        }

        Widget promoWidget = Column(
          children: [
            _buildPromoContainer(code, discount),
            const SizedBox(height: 25), 
          ],
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return promoWidget; 
        }

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref().child('users/${user.uid}/orders').limitToFirst(1).onValue,
          builder: (context, rtdbSnapshot) {
            if (rtdbSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (rtdbSnapshot.hasData && rtdbSnapshot.data?.snapshot.exists == true) {
              return const SizedBox.shrink(); 
            }
            
            return promoWidget; 
          },
        );
      },
    );
  }

  Widget _buildPromoContainer(String code, int discount) {
    if (kIsWeb) return const SizedBox.shrink();
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), 
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9E1B46), Color(0xFFE63971), Color(0xFFFF8DAF), Color(0xFFE63971), Color(0xFF8A143A),
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "First Order Special",
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFFFF0F5),
                              fontSize: 19, fontWeight: FontWeight.w800,
                              shadows: [BoxShadow(color: Colors.black.withOpacity(0.6), offset: const Offset(1, 1), blurRadius: 2)],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Get ₹$discount OFF on your first purchase.",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13, fontWeight: FontWeight.w500,
                              shadows: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0.5, 0.5), blurRadius: 1)],
                            ),
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  (constraints.maxWidth / 12).floor(),
                                  (index) => Container(
                                    width: 6, height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(1),
                                      boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), offset: const Offset(0, 1), blurRadius: 0)],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFD1DF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(2, 4), blurRadius: 6),
                          BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 2),
                        ],
                      ),
                      child: Text(
                        code,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9E1B46),
                          fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2,
                          shadows: [BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(1, 1), blurRadius: 1)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: -12, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    height: 24, width: 24,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(2, 0), blurRadius: 4, spreadRadius: -1)]),
                  ),
                ),
              ),
              Positioned(
                right: -12, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    height: 24, width: 24,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(-2, 0), blurRadius: 4, spreadRadius: -1)]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
