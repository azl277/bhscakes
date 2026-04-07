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

import 'package:project/customisepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Loginpage2.dart';
import 'cartpage1.dart';
import 'cakepage.dart' hide CategoryHeaderDelegate;
import 'cupcakepage.dart';

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
    } else if (imageString.isNotEmpty) {
      if (!globalMemoryImageCache.containsKey(imageString)) {
        try {
          globalMemoryImageCache[imageString] = base64Decode(imageString);
        } catch (e) {
          return const Icon(Icons.broken_image, color: Colors.white24);
        }
      }
      image = Image.memory(globalMemoryImageCache[imageString] ?? Uint8List(0), fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
    } else {
      image = const Icon(Icons.image_not_supported, color: Colors.white24);
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
        final val = event.snapshot.value;
        if (val != null && val is Map) {
          final data = Map<dynamic, dynamic>.from(val);
          await wishlistRef.child(data.keys.first.toString()).remove();
        }
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
          int priceInt = int.tryParse(widget.item['price'] ?? "".replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

          await dbRef.push().set({
            'name': widget.item['name'],
            'image': widget.item['image'],
            'price': priceInt,
            'display_price': widget.item['price'],
            'quantity': 1,
            'category': 'AddOn',
            'deliveryTime': widget.item['deliveryTime'] ?? '0',
            'deliveryUnit': widget.item['deliveryUnit'] ?? 'Hours',
            'added_at': ServerValue.timestamp,
          });
        }
      } else {
        if (currentQuantity > 0) {
          final snapshot = await dbRef.orderByChild('name').equalTo(widget.item['name']).limitToLast(1).get();

          if (snapshot.exists) {
            final val = snapshot.value;
            if (val != null && val is Map) {
              Map<dynamic, dynamic> children = Map<dynamic, dynamic>.from(val);
              String keyToDelete = children.keys.first.toString();
              await dbRef.child(keyToDelete).remove();
            }
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

class FloatingMiniPng extends StatefulWidget {
  final String path;
  final Alignment align;
  final double size;
  final int duration;

  const FloatingMiniPng({
    super.key,
    required this.path,
    required this.align,
    required this.size,
    required this.duration,
  });

  @override
  State<FloatingMiniPng> createState() => _FloatingMiniPngState();
}

class _FloatingMiniPngState extends State<FloatingMiniPng>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _movement;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..repeat(reverse: true);

    _movement = Tween<double>(
      begin: -25.0,
      end: 5.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.align,
      child: AnimatedBuilder(
        animation: _movement,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _movement.value),
            child: Opacity(
              opacity: 0.85,
              child: Image.asset(
                widget.path,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.bakery_dining,
                  size: widget.size * 0.5,
                  color: Colors.white24,
                ),
              ),
            ),
          );
        },
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

class AnimatedTopBackground extends StatefulWidget {
  final bool isMobile;
  const AnimatedTopBackground({super.key, required this.isMobile});

  @override
  State<AnimatedTopBackground> createState() => _AnimatedTopBackgroundState();
}

class _AnimatedTopBackgroundState extends State<AnimatedTopBackground>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _loopController;

  late Animation<double> _imageScaleEntrance;
  late Animation<double> _imageScaleLoop;
  late Animation<Offset> _oreoSlideEntrance;
  late Animation<Offset> _cupcakesSlideEntrance;
  late Animation<Offset> _floatLoop;
  late Animation<double> _fadeEntrance;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _imageScaleEntrance = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _fadeEntrance = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _oreoSlideEntrance = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _cupcakesSlideEntrance = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _imageScaleLoop = Tween<double>(begin: 1.0, end: 1.05).animate( 
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _floatLoop = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.08)).animate(
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _entranceController.forward().then((_) {
      _loopController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = widget.isMobile;

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _loopController]),
      builder: (context, child) {
        return Container(
          height: 320,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
              colors: [
                Color.fromARGB(255, 255, 144, 107),
                Color.fromARGB(255, 240, 139, 125),
                Color.fromARGB(255, 255, 210, 210),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 90,
                child: Opacity(
                  opacity: _fadeEntrance.value,
                  child: FractionalTranslation(
                    translation: _floatLoop.value,
                    child: Text(
                      "NEW LAUNCH",
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 20,
                        color: const Color.fromARGB(255, 255, 208, 0)
                        
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 110,
                child: Opacity(
                  opacity: _fadeEntrance.value,
                  child: FractionalTranslation(
                    translation: _oreoSlideEntrance.value + _floatLoop.value,
                    child: Text(
                      "OREO",
                      style: TextStyle(
                        fontSize: isMobile ? 60 : 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                child: Transform.scale(
                  scale: _imageScaleEntrance.value * _imageScaleLoop.value,
                  child: Image.asset(
                    'assets/cup.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                child: Opacity(
                  opacity: _fadeEntrance.value,
                  child: FractionalTranslation(
                    translation: _cupcakesSlideEntrance.value + (_floatLoop.value * -0.5), 
                    child: Text(
                      "CUPCAKES",
                      style: TextStyle(
                        fontSize: isMobile ? 30 : 40,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 1.2
                          ..color = Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Giftpage extends StatefulWidget {
  final String? heroTag;
  const Giftpage({super.key, this.heroTag});

  @override
  State<Giftpage> createState() => _GiftpageState();
}

class _GiftpageState extends State<Giftpage> {
  final ValueNotifier<bool> _showAppBar = ValueNotifier(true);
  final ValueNotifier<bool> _showShadow = ValueNotifier(false);
  bool _isStatusBarDark = false;

  StreamSubscription<DatabaseEvent>? _cartSubscription;

  final Map<String, GlobalKey> _productKeys = {};
  final GlobalKey _cupcakesKey = GlobalKey(); 
  
  final ValueNotifier<Map<String, String>> _categoryThumbnailsNotifier = ValueNotifier({});

  late ScrollController _scrollController;
  double _lastOffset = 0.0;
  
  final Color _accentPink = const Color(0xFFFF2E74);

  int _globalDeliveryMin = 3;
  int _globalDeliveryMax = 4;
  String _globalDeliveryUnit = "Hours";

  double _calculateDynamicCardWidth(double availableWidth, int itemCount, double minWidth, double spacing, double maxWidth) {
    if (itemCount <= 0) return minWidth;
    double totalSpacing = spacing * (itemCount - 1);
    double calculatedWidth = (availableWidth - totalSpacing) / itemCount;
    
    if (calculatedWidth < minWidth) return minWidth;
    if (calculatedWidth > maxWidth) return maxWidth;
    return calculatedWidth;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _activateCartListener();
    _preloadThumbnails();
    _fetchGlobalSettings(); 
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    _cartSubscription?.cancel();
    _showAppBar.dispose();
    _showShadow.dispose();
    _categoryThumbnailsNotifier.dispose(); 
    super.dispose();
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

  Future<void> _preloadThumbnails() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('product_categories')
          .where('type', isEqualTo: 'gifts') 
          .get();
      List<String> categories = snap.docs.map((doc) => doc['name'].toString()).toList();

      categories.insert(0, 'Cakes');

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
      debugPrint("🚨 Error preloading thumbnails: $e");
    }
  }

  Future<String?> _getCategoryThumbnail(String categoryType) async {
    try {
      if (categoryType.toLowerCase() == 'cakes') {
        final doc = await FirebaseFirestore.instance.collection('products').limit(1).get();
        if (doc.docs.isNotEmpty) return doc.docs.first['image']?.toString();
      } else {
        final doc = await FirebaseFirestore.instance.collection('gifts').where('category', isEqualTo: categoryType).limit(1).get();
        if (doc.docs.isNotEmpty) return doc.docs.first['image']?.toString();
      }
    } catch (e) {
      debugPrint("🚨 Error fetching thumbnail for $categoryType: $e");
    }
    return null;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not find $productName")));
      }
    }
  }

  void _onScroll() {
    double currentOffset = _scrollController.position.pixels;

    if (currentOffset > 300) {
      if (!_showShadow.value) _showShadow.value = true;
    } else {
      if (_showShadow.value) _showShadow.value = false;
    }

    if (currentOffset > 100) {
      if (currentOffset > _lastOffset && _showAppBar.value) {
        _showAppBar.value = false;
      } else if (currentOffset < _lastOffset && !_showAppBar.value) {
        _showAppBar.value = true;
      }
    } else {
      if (!_showAppBar.value) _showAppBar.value = true;
    }
    _lastOffset = currentOffset;

    bool shouldBeDark = currentOffset > 360;
    if (shouldBeDark != _isStatusBarDark) {
      _isStatusBarDark = shouldBeDark;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: shouldBeDark ? Brightness.dark : Brightness.light,
        ),
      );
    }
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
        final val = event.snapshot.value;
        if (val != null && val is Map) {
          final data = Map<dynamic, dynamic>.from(val);
          data.forEach((key, value) {
            if (value != null && value is Map) {
              cartList.add(Map<String, dynamic>.from(value));
            }
          });
        }
      }
      cartCountNotifier.value = cartList.length;
    });
  }

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  void _showLoginRequiredDialog() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
  }

  Widget buildImage(String imageString, {double radius = 18}) {
    Widget image;
    try {
      if (imageString.isEmpty) {
        image = const Icon(Icons.image_not_supported, color: Colors.white24);
      } else if (imageString.startsWith('assets/')) {
        image = Image.asset(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
      } else if (imageString.startsWith('http')) {
        image = Image.network(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
      } else {
        image = Image.memory(base64Decode(imageString), fit: BoxFit.cover, filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24));
      }
    } catch (e) {
      image = const Icon(Icons.broken_image, color: Colors.white24);
    }

    return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: image) : image;
  }
Widget _buildQuickCategories({bool isSticky = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('product_categories').where('type', isEqualTo: 'gifts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();

        var sortedDocs = snapshot.data?.docs.toList();
        sortedDocs?.sort((a, b) {
          Timestamp? tA = (a.data() as Map)['createdAt'] as Timestamp?;
          Timestamp? tB = (b.data() as Map)['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tA.compareTo(tB);
        });

        List<Map<String, dynamic>> quickCategories = (sortedDocs ?? []).map((doc) {
          String catName = doc['name'];
          if (!_productKeys.containsKey(catName)) _productKeys[catName] = GlobalKey();
          return {
            "title": catName,
            "type": catName,
            "isRoute": false,
            "key": _productKeys[catName],
          };
        }).toList();

        return Container(
          height: isSticky ? 110 : 95, 
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, 
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
                  mainAxisSize: MainAxisSize.min, 
                  children: quickCategories.map((cat) {
                    final String catType = cat['type'];

                    return Padding(
                      padding: const EdgeInsets.only(right: 24.0), 
                      child: GestureDetector(
                        onTap: () {
                          if (cat['isRoute'] == true) {
                            if (cat['title'] == 'Cakes') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const Cakepage()));
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
                        child: HoverAnimatedCard(
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
                                          : const Center(child: Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF2E74), size: 24));
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
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: isMobile ? const BouncingScrollPhysics() : const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    _buildTopBackground(isMobile),
                    const SizedBox(height: 35),
                    Padding(padding: EdgeInsets.only(top: isMobile ? 110 : 130)),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _buildPromoWrapper(),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: CategoryHeaderDelegate(
                  showAppBar: _showAppBar, 
                  child: _buildQuickCategories(isSticky: true)
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('product_categories').where('type', isEqualTo: 'gifts').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                    
                    var sortedDocs = snapshot.data?.docs.toList();
                    sortedDocs?.sort((a, b) {
                      Timestamp? tA = (a.data() as Map)['createdAt'] as Timestamp?;
                      Timestamp? tB = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (tA == null || tB == null) return 0;
                      return tA.compareTo(tB);
                    });

                    return Column(
                      children: [
                        ...(sortedDocs ?? []).map((doc) {
                          String catName = doc['name'];
                          if (!_productKeys.containsKey(catName)) {
                            _productKeys[catName] = GlobalKey();
                          }
                          return _buildCategorySection(catName, catName, key: _productKeys[catName]);
                        }).toList(),
                        const SizedBox(height: 100),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: 25,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showAppBar,
              builder: (context, visible, child) {
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  offset: visible ? Offset.zero : const Offset(0, -1.5),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: visible ? 1 : 0,
                    child: _buildElegantGlassAppBar(isMobile),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBackground(bool isMobile) {
    return Center(
      child: Container(
         height: isMobile ? 350 : 370, 
      width: isMobile? double.infinity:1300,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC48B55), Color(0xFF8B5A2B), Color(0xFF5C3A21)],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center( 
            child: ConstrainedBox( 
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1, 
                      child: Center(
                        child: Image.asset(
                          'assets/flwr2.png', 
                          fit: BoxFit.contain,
                          height: isMobile ? 180 : 240, 
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.cake,
                            color: Colors.white24,
                            size: 100,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20), 
                    Expanded(
                      flex: 1, 
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "FRESH",
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: isMobile ? 26 : 42, 
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "FLOWERS",
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFFFE082), 
                              fontSize: isMobile ? 22 : 36, 
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Bouquet",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isMobile ? 12 : 16, 
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                  Container(height: 20, width: 4, decoration: BoxDecoration(color: _accentPink, borderRadius: BorderRadius.circular(3))),
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, mainAxisSpacing: 18, crossAxisSpacing: 18, childAspectRatio: childAspectRatio),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: const BoxDecoration(color: Color(0xFFF9F9F9), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                            child: const SkeletonShimmer(width: double.infinity, height: double.infinity, borderRadius: 15),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonShimmer(width: double.infinity, height: 16, borderRadius: 4),
                              SizedBox(height: 6),
                              SkeletonShimmer(width: 80, height: 12, borderRadius: 4),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SkeletonShimmer(width: 50, height: 16, borderRadius: 4),
                                  SkeletonShimmer(width: 28, height: 28, borderRadius: 14),
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
    final stream = FirebaseFirestore.instance.collection('gifts').where('category', isEqualTo: category).snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || (snapshot.data?.docs?.isEmpty ?? true)) return const SizedBox.shrink();

        final double screenWidth = MediaQuery.of(context).size.width;
        final double width = screenWidth > 1200 ? 1200 : screenWidth;

        int crossAxisCount = width >= 1200 ? 6 : width >= 900 ? 5 : width >= 600 ? 4 : 2; 
        double childAspectRatio = width >= 1200 ? 0.78 : width >= 900 ? 0.72 : width >= 600 ? 0.68 : 0.62; 

final products = snapshot.data?.docs ?? [];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
                  child: Row(
                    children: [
                      Container(height: 20, width: 4, decoration: BoxDecoration(color: _accentPink, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Text(title, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount, mainAxisSpacing: 18, crossAxisSpacing: 18, childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = (doc.data() as Map<String, dynamic>?) ?? {};
                    
                    final Map<String, String> giftItem = { 
                      'id': doc.id,
                      'name': data['name']?.toString() ?? 'Unknown',
                      'category': data['category']?.toString() ?? 'gifts',
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

                    return _buildCompactGiftCard(giftItem, rawFlavours); 
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactGiftCard(Map<String, String> item, Map<String, dynamic> rawFlavours) { 
    bool isAvailable = item['isAvailable'] != 'false';
    bool isOffer = item['isOffer'] == 'true';
    String offerPrice = item['offerPrice'] ?? '';
    
    String dTime = item['deliveryTime'] ?? '0';
    String dUnit = item['deliveryUnit'] ?? 'Hours';
    int dt = int.tryParse(dTime) ?? 0;

    int timeInMins = 0;
    String displayTime = "";

    if (dt > 0) {
      displayTime = "Delivers in $dTime $dUnit";
      String u = dUnit.toLowerCase();
      timeInMins = (u == 'days') ? dt * 1440 : (u.contains('min') ? dt : dt * 60);
    } else {
      displayTime = "Delivers in $_globalDeliveryMin to $_globalDeliveryMax $_globalDeliveryUnit";
      String u = _globalDeliveryUnit.toLowerCase();
      timeInMins = (u == 'days') ? _globalDeliveryMax * 1440 : (u.contains('min') ? _globalDeliveryMax : _globalDeliveryMax * 60);
    }

    Color dColor = Colors.blue.shade700;
    Color dBg = Colors.blue.shade50;
    if (timeInMins > 0 && timeInMins <= 60) { dColor = Colors.green.shade700; dBg = Colors.green.shade50; }
    else if (timeInMins > 300) { dColor = Colors.red.shade700; dBg = const Color.fromARGB(255, 255, 255, 255); }

    List<String> flavorNames = [];
    if (rawFlavours.isNotEmpty) {
       if (rawFlavours.values.first is List) {
           List<dynamic> fList = rawFlavours.values.first as List<dynamic>;
           for(var f in fList) {
               if(f is Map && f['name'] != null) {
                   flavorNames.add(f['name'].toString());
               }
           }
       } else {
           rawFlavours.forEach((key, value) {
              flavorNames.add(key);
           });
       }
    }

    return HoverAnimatedCard(
      isAvailable: isAvailable,
      onTap: () => _showCustomizeModal(item, rawFlavours),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      color: const Color(0xFFF9F9F9),
                      child: Opacity(
                        opacity: isAvailable ? 1.0 : 0.6,
                        child: Hero(
                          tag: "${item['name']}_grid_${item['id']}",
                          child: isAvailable
                              ? buildImage(item['image'] ?? "", radius: 0)
                              : ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      1, 0,
                                  ]),
                                  child: buildImage(item['image'] ?? "", radius: 0),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white38, width: 1)),
                            child: Text("SOLD OUT", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
                          ),
                        ),
                      ),
                    ),
                  if (isAvailable && isOffer)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF2E74), Colors.pinkAccent]),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF2E74).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text("OFFER", style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8, right: 8,
                    child: _WishlistButton(
                      item: item,
                      onLoginRequired: _showLoginRequiredDialog,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item['name'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, fontSize: 14, color: isAvailable ? Colors.black87 : Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(item['desc'] ?? "Beautiful gift", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
                  
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: dBg, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled_rounded, size: 10, color: dColor),
                        const SizedBox(width: 4),
                        Expanded(child: Text(displayTime, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: dColor))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOffer && isAvailable) ...[
                              Text(item['price'] ?? "", style: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 10, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w600)),
                              Text("Rs $offerPrice", style: GoogleFonts.montserrat(color: Colors.green.shade600, fontWeight: FontWeight.w800, fontSize: 13)),
                            ] else ...[
                              Text(item['price'] ?? "", style: GoogleFonts.montserrat(color: isAvailable ? _accentPink : Colors.grey.shade400, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        height: 32, width: 32,
                        decoration: BoxDecoration(
                            color: isAvailable ? _accentPink : Colors.grey.shade200, shape: BoxShape.circle,
                            boxShadow: isAvailable ? [BoxShadow(color: _accentPink.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))] : []),
                        child: Icon(isAvailable ? Icons.add : Icons.remove_shopping_cart_rounded, color: isAvailable ? Colors.white : Colors.grey.shade400, size: 18),
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

  void _showCustomizeModal(Map<String, String> item, Map<String, dynamic> rawFlavours) {
    bool isOffer = item['isOffer'] == 'true';
    String activePriceString = (isOffer && item['offerPrice'] != null && (item['offerPrice'] ?? "").isNotEmpty) ? item['offerPrice'] ?? "" : item['price'] ?? ""; 

  int basePrice = int.tryParse(
  activePriceString?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''
) ?? 0;
    int originalBasePrice = int.tryParse(
  item['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''
) ?? basePrice;
        
    Map<String, int> availableFlavours = {};
    if (rawFlavours.isNotEmpty) {
       if (rawFlavours.values.first is List) {
           List<dynamic> fList = rawFlavours.values.first as List<dynamic>;
           for(var f in fList) {
               if(f is Map && f['name'] != null) {
                   availableFlavours[f['name'].toString()] = f['price'] as int;
               }
           }
       } else {
           rawFlavours.forEach((key, value) {
              availableFlavours[key] = int.tryParse(value.toString()) ?? 0;
           });
       }
    }

    String? selectedFlavourKey = availableFlavours.isNotEmpty ? availableFlavours.keys.first : null;
    int selectedFlavourPrice = availableFlavours.isNotEmpty ? availableFlavours.values.first : 0;

    String dTime = item['deliveryTime'] ?? '0';
    String dUnit = item['deliveryUnit'] ?? 'Hours';
    int dt = int.tryParse(dTime) ?? 0;
    
    int timeInMins = 0;
    String displayDeliveryTime = "";

    if (dt > 0) {
      displayDeliveryTime = "Estimated delivery in $dTime $dUnit";
      String u = dUnit.toLowerCase();
      timeInMins = (u == 'days') ? dt * 1440 : (u.contains('min') ? dt : dt * 60);
    } else {
      displayDeliveryTime = "Standard Delivery: $_globalDeliveryMin to $_globalDeliveryMax $_globalDeliveryUnit";
      String u = _globalDeliveryUnit.toLowerCase();
      timeInMins = (u == 'days') ? _globalDeliveryMax * 1440 : (u.contains('min') ? _globalDeliveryMax : _globalDeliveryMax * 60);
    }

    Color dTextColor = Colors.blue.shade700;
    if (timeInMins > 0 && timeInMins <= 60) {
      dTextColor = Colors.green.shade700;
    } else if (timeInMins > 300) { 
      dTextColor = Colors.red.shade700;
    }

    final Widget cachedGiftImage = Container(
      height: 95, width: 95, padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Hero(tag: "${item['name']}_modal_${item['id']}", child: buildImage(item['image'] ?? "")),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        String selectedPack = "1 Unit";
        int currentPrice = basePrice + selectedFlavourPrice;
        int originalCurrentPrice = originalBasePrice + selectedFlavourPrice;

        return StatefulBuilder(
          builder: (context, setModalState) {
            int calculatePrice(String pack, int base) {
              if (pack == "1 Unit") return base;
              if (pack == "2 Units") return base * 2;
              if (pack == "5 Units") return base * 5;
              return base;
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(margin: const EdgeInsets.only(top: 15), width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                cachedGiftImage,
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? "", style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1)),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeOutQuart,
                                            tween: Tween<double>(begin: currentPrice.toDouble(), end: currentPrice.toDouble()),
                                            builder: (context, value, child) {
                                              return Text("₹${value.toInt()}", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w800, color: _accentPink));
                                            },
                                          ),
                                          if (isOffer) ...[
                                            const SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2.0),
                                              child: TweenAnimationBuilder<double>(
                                                duration: const Duration(milliseconds: 400),
                                                curve: Curves.easeOutQuart,
                                                tween: Tween<double>(begin: originalCurrentPrice.toDouble(), end: originalCurrentPrice.toDouble()),
                                                builder: (context, value, child) {
                                                  return Text("₹${value.toInt()}", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough));
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            if (item['desc'] != null && (item['desc'] ?? "").isNotEmpty) ...[
                              Text("DESCRIPTION", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2, color: Colors.grey.shade500)),
                              const SizedBox(height: 8),
                              Text(item['desc'] ?? "", style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
                              const SizedBox(height: 20),
                            ],

                            Text("DELIVERY", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2, color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 18, color: dTextColor),
                                const SizedBox(width: 8),
                                Text(displayDeliveryTime, style: GoogleFonts.inter(fontSize: 13, color: dTextColor, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 25),

                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 25),

                            Text("QUANTITY", style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                            const SizedBox(height: 15),

                            Row(
                              children: ["1 Unit", "2 Units", "5 Units"].map((pack) {
                                bool isSelected = selectedPack == pack;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedPack = pack;
                                        
                                        int multiplier = 1;
                                        if (pack == "2 Units") multiplier = 2;
                                        if (pack == "5 Units") multiplier = 5;

                                        currentPrice = calculatePrice(pack, basePrice) + (selectedFlavourPrice * multiplier);
                                        originalCurrentPrice = calculatePrice(pack, originalBasePrice) + (selectedFlavourPrice * multiplier);
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _accentPink.withOpacity(0.08) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isSelected ? _accentPink : Colors.grey.shade300, width: isSelected ? 2 : 1),
                                        boxShadow: isSelected ? [BoxShadow(color: _accentPink.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
                                      ),
                                      child: Center(
                                        child: Text(pack, style: GoogleFonts.inter(color: isSelected ? _accentPink : Colors.black87, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 15)),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 25),

                            if (availableFlavours.isNotEmpty) ...[
                              Text(
                                "SELECT FLAVOR",
                                style: GoogleFonts.inter(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: availableFlavours.entries.map((entry) {
                                  bool isSelected = selectedFlavourKey == entry.key;
                                  return GestureDetector(
                                    onTap: () => setModalState(() {
                                      selectedFlavourKey = entry.key;
                                      selectedFlavourPrice = entry.value;

                                      int multiplier = 1;
                                      if (selectedPack == "2 Units") multiplier = 2;
                                      if (selectedPack == "5 Units") multiplier = 5;

                                      currentPrice = calculatePrice(selectedPack, basePrice) + (selectedFlavourPrice * multiplier);
                                      originalCurrentPrice = calculatePrice(selectedPack, originalBasePrice) + (selectedFlavourPrice * multiplier);
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.black : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isSelected ? Colors.black : Colors.transparent),
                                      ),
                                      child: Text(
                                        "${entry.key} ${entry.value > 0 ? '(+₹${entry.value})' : ''}",
                                        style: GoogleFonts.inter(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 35),
                            ],
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
                      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPink, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Map<String, int> flavorsToPass = {};
                            if (selectedFlavourKey != null) {
                              flavorsToPass[selectedFlavourKey!] = selectedFlavourPrice;
                            }
                            _addToCartWithDetails(item, selectedPack, "Rs $currentPrice", flavorsToPass);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 20),
                              const SizedBox(width: 12),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                tween: Tween<double>(begin: currentPrice.toDouble(), end: currentPrice.toDouble()),
                                builder: (context, value, child) {
                                  return Text("ADD TO CART • ₹${value.toInt()}", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5));
                                },
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

  void _addToCartWithDetails(Map<String, String> item, String quantity, String finalPrice, Map<String, int> finalFlavourMap) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
      return; 
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress = prefs.getString('userAddress') ?? "No Address Selected";

    int priceInt = int.tryParse(finalPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    DateTime now = DateTime.now();
    DateTime estimatedDelivery;
    
    int dTime = int.tryParse(item['deliveryTime'] ?? '0') ?? 0;
    String dUnit = (item['deliveryUnit'] ?? 'Hours').toLowerCase();

    if (dTime > 0) {
      if (dUnit == 'days') {
        estimatedDelivery = now.add(Duration(days: dTime));
      } else if (dUnit == 'minutes' || dUnit == 'mins') {
        estimatedDelivery = now.add(Duration(minutes: dTime));
      } else {
        estimatedDelivery = now.add(Duration(hours: dTime));
      }

      String amPm = estimatedDelivery.hour >= 12 ? 'PM' : 'AM';
      int displayHour = estimatedDelivery.hour > 12 
          ? estimatedDelivery.hour - 12 
          : (estimatedDelivery.hour == 0 ? 12 : estimatedDelivery.hour);
      
      String formattedDate = "${estimatedDelivery.day.toString().padLeft(2, '0')}/${estimatedDelivery.month.toString().padLeft(2, '0')}";
      String formattedTime = "${displayHour.toString().padLeft(2, '0')}:${estimatedDelivery.minute.toString().padLeft(2, '0')} $amPm";
      
      item['delivery_label'] = "Expected by: $formattedDate $formattedTime";
    } else {
      estimatedDelivery = now; 
      item['delivery_label'] = "Standard Delivery";
    }

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'selected_shape': 'Standard',
      'selected_weight': quantity,
      'price': priceInt,
      'display_price': finalPrice,
      'quantity': 1,
      'cakeWriting': 'No writing',
      'flavours': jsonEncode(finalFlavourMap),
      'delivery_address': currentSavedAddress,
      'category': item['category'] ?? 'gifts',
      'added_at': ServerValue.timestamp,
      'deliveryTime': item['deliveryTime'] ?? '0',
      'deliveryUnit': item['deliveryUnit'] ?? 'Hours',
      'estimated_delivery_ms': estimatedDelivery.millisecondsSinceEpoch,
      'delivery_label': item['delivery_label'],
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
      await dbRef.push().set(cartItem);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent, elevation: 0, behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2500), width: MediaQuery.of(context).size.width > 600 ? 400 : null,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentPink.withOpacity(0.5)), boxShadow: [BoxShadow(color: _accentPink.withOpacity(0.2), blurRadius: 15, spreadRadius: -2)],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _accentPink, size: 24), const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Added to Basket", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("${item['name']} • ${item['delivery_label']}", style: GoogleFonts.inter(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
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
                    ? [const BoxShadow(color: Color.fromARGB(30, 0, 0, 0), blurRadius: 20, offset: Offset(0, 10), spreadRadius: 2)]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: barHeight,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    decoration: BoxDecoration(
                      color: showShadow ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { Navigator.popUntil(context, (route) => route.isFirst); },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    "BUTTER HEARTS GIFTS",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.oswald(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
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
          child: Icon(Icons.grid_view_rounded, color: Colors.white, size: size * 0.5),
        ),
        onSelected: (value) {
          if (value == 'cakes') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Cakepage()));
          } else if (value == 'cupcakes') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Cupcakepage()));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'cakes', child: Row(children: [const Icon(Icons.cake, color: Colors.white, size: 20), const SizedBox(width: 12), Text('Cakes', style: GoogleFonts.inter(color: Colors.white))])),
          PopupMenuItem(value: 'cupcakes', child: Row(children: [const Icon(Icons.cake, color: Colors.white, size: 20), const SizedBox(width: 12), Text('Cupcakes', style: GoogleFonts.inter(color: Colors.white))])),
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
} // <--- This final bracket safely closes the _GiftpageState class!