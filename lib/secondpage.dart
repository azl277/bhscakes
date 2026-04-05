import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:project/cakepage.dart';
import 'package:project/location.dart';

import 'package:project/orderpage.dart';
import 'package:project/giftpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:project/cartpage1.dart';
import 'package:project/cakepage.dart' as cake;
import 'package:project/cupcakepage.dart';
import 'package:project/customisepage.dart';
import 'package:project/giftpage.dart' as popsicle;
import 'package:project/Profilepage2.dart';
import 'package:project/Loginpage2.dart';

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class Secondpage extends StatefulWidget {
  const Secondpage({super.key});

  @override
  State<Secondpage> createState() => _SecondpageState();
}

class _SecondpageState extends State<Secondpage> with TickerProviderStateMixin {
  PageController? _pageController;
  Timer? _timer;
  String userName = "Guest";
  String userAddress = "Select Location";
  
  int _currentIndex = 1000; 
  bool _showGpsFields = false;
  bool _isProfileExpanded = false;

  AnimationController? _bounceController;
  Animation<double>? _bounceAnimation;
  double _dragOffset = 0.0;
  int? _draggedCardIndex;
  bool _isAnimatingRelease = false;
  bool _isHoldingSlider = false; 

  final String allowedCity = "Kochi";
  final Color _accentPink = const Color.fromARGB(255, 218, 0, 138);
  final Color _bgBlack = const Color(0xFF050505);

  final List<String> cakeImages = [
    "assets/cake1.jpg",
    "assets/cupcake1.jpg",
    "assets/GIFTS.jpg"
  ];

  final List<String> cakeNames = ["Cakes", "Cup Cakes", "Gifts"];

  static const int _initialPage = 1000;
  final TextEditingController _manualAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startAutoSlider();
    
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), 
    );
    
    _bounceAnimation = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _bounceController!, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _triggerBounceCycle();
    });
  }

  Future<void> _triggerBounceCycle() async {
    bool isDraggingVertically = _draggedCardIndex != null;
    bool isSlidingHorizontally = false;
    
    if (_pageController?.hasClients == true) {
      isSlidingHorizontally = _pageController?.position.isScrollingNotifier.value ?? false;
    }

    if (!isDraggingVertically && !isSlidingHorizontally && _bounceController != null) {
      if (!_bounceController!.isAnimating) {
        await _bounceController!.forward(); 
        await Future.delayed(const Duration(milliseconds: 150)); 
        await _bounceController!.reverse(); 
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    _manualAddressController.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  Future<void> _navigateFromCard(int index, String heroTag) async {
    Widget targetPage;
    try {
      switch (cakeNames[index]) {
        case "Cakes":
          targetPage = Cakepage(heroTag: heroTag);
          break;
        case "Cup Cakes":
          targetPage = Cupcakepage(heroTag: heroTag);
          break;
        case "Gifts":
          targetPage = Giftpage(heroTag: heroTag);
          break;
        default:
          targetPage = Giftpage(heroTag: heroTag);
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => targetPage),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Navigation Error: $e");
    }
  }

  int _getRealIndex(int index) {
    return index % cakeImages.length;
  }

  Widget _scaledUI(Widget child, double scale) {
    return AnimatedScale(
      scale: scale,
      duration: Duration(milliseconds: _isAnimatingRelease ? 800 : 0),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    _initController(isMobile);

    double pageScale = 1.0;
    if (_draggedCardIndex != null && _dragOffset < 0) {
      pageScale = (1.0 - (_dragOffset.abs() / 2500)).clamp(0.85, 1.0);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('store_status')
          .snapshots(),
      builder: (context, statusSnapshot) {
        bool isStoreClosed = false;
        String busyMessage = "We are currently busy baking delicious treats!";
        DateTime? resumeTime;

        if (statusSnapshot.hasData && statusSnapshot.data?.exists == true) {
          final data = statusSnapshot.data?.data() as Map<String, dynamic>?;
          if (data != null) {
            bool isOpen = data['isOpen'] ?? true;
            resumeTime = data['resumeAt'] != null
                ? (data['resumeAt'] as Timestamp).toDate()
                : null;

            if (!isOpen &&
                (resumeTime == null || resumeTime.isAfter(DateTime.now()))) {
              isStoreClosed = true;
              busyMessage = data['message'] ?? busyMessage;
            }
          }
        }

        return Scaffold(
          backgroundColor: _bgBlack,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              ScrollConfiguration(
                behavior: DesktopScrollBehavior(),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    _buildBackground(size), 
                    SafeArea(
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none, 
                        physics: _isHoldingSlider || _draggedCardIndex != null 
                            ? const NeverScrollableScrollPhysics() 
                            : const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _scaledUI(_buildGlassAppBar(isMobile), pageScale),
                            
                            const SizedBox(height: 20), 
                            _scaledUI(_buildHeaderText(isMobile), pageScale),
                            const SizedBox(height: 30), 
                            
                            _buildSliderSection(isMobile, size, pageScale),
                            
                            const SizedBox(height: 0),
                            _scaledUI(_buildPageIndicator(), pageScale),
                            const SizedBox(height: 35),
                            _scaledUI(_buildFooterText(isMobile), pageScale),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!isStoreClosed)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _scaledUI(const LiveOrderTracker(), pageScale),
                      ),
                    ),
                  ),
                ),

              if (isStoreClosed) _buildBusyOverlay(busyMessage, resumeTime),

              if (isStoreClosed)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _scaledUI(const LiveOrderTracker(), pageScale),
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

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(cakeImages.length, (index) {
        int realIndex = _getRealIndex(_currentIndex);
        bool isActive = realIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 8,
          decoration: BoxDecoration(
            color: isActive ? _accentPink : Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildSliderSection(bool isMobile, Size size, double globalPageScale) {
    double height = isMobile ? 400 : 380.0;
    double width = size.width;

    return SizedBox(
      height: height,
      width: width,
      child: Listener(
        onPointerDown: (_) {
          if (!_isHoldingSlider) setState(() => _isHoldingSlider = true);
        },
        onPointerUp: (_) {
          if (_isHoldingSlider) setState(() => _isHoldingSlider = false);
        },
        onPointerCancel: (_) {
          if (_isHoldingSlider) setState(() => _isHoldingSlider = false);
        },
        child: PageView.builder(
          clipBehavior: Clip.none, 
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            
            if (index % 2 == 0) {
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted && _currentIndex == index) {
                  _triggerBounceCycle();
                }
              });
            }
          },
          itemBuilder: (context, index) {
            final realIndex = _getRealIndex(index);
            bool isBeingDragged = _draggedCardIndex == realIndex;

            if (_pageController == null) return const SizedBox.shrink();

            return AnimatedBuilder(
              animation: _pageController ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                double carouselScale = 1.0;
                
                if (_pageController?.hasClients == true && _pageController?.position.haveDimensions == true) {
                  double currentPage = _pageController?.page ?? _currentIndex.toDouble();
                  carouselScale = currentPage - index;
                  carouselScale = (1 - (carouselScale.abs() * 0.15)).clamp(0.8, 1.0);
                }
                
                double finalScale = isBeingDragged ? carouselScale : (carouselScale * globalPageScale);

                return Center(
                  child: AnimatedScale(
                    scale: finalScale,
                    duration: Duration(milliseconds: _isAnimatingRelease ? 800 : 0),
                    curve: Curves.easeOutCubic,
                    child: child,
                  ),
                );
              },
              child: _buildSliderCard(realIndex, index, isMobile),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliderCard(int realIndex, int actualIndex, bool isMobile) {
    return AnimatedBuilder(
      animation: _bounceController!,
      builder: (context, child) {
        bool isBeingDragged = _draggedCardIndex == realIndex;
        double bounceOffset = 0.0; 
        double currentDrag = isBeingDragged ? _dragOffset : 0.0;
        double totalOffset = currentDrag + bounceOffset;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  await _navigateFromCard(realIndex, 'featured_cake_$actualIndex');
                },
                onVerticalDragStart: (details) {
                  setState(() {
                    _draggedCardIndex = realIndex;
                    _dragOffset = 0.0;
                    _isAnimatingRelease = false;
                  });
                },
                onVerticalDragUpdate: (details) {
                  if (_draggedCardIndex == realIndex) {
                    setState(() {
                      _dragOffset += details.primaryDelta ?? 0;
                      if (_dragOffset > 0) _dragOffset = 0; 
                    });
                  }
                },
                onVerticalDragEnd: (details) async {
                  setState(() {
                    _isAnimatingRelease = true; 
                  });

                  if (_dragOffset < -120 || (details.primaryVelocity != null && details.primaryVelocity! < -300)) {
                    setState(() {
                      _dragOffset = -MediaQuery.of(context).size.height;
                    });

                    await Future.delayed(const Duration(milliseconds: 300)); 
                    await _navigateFromCard(realIndex, 'featured_cake_$actualIndex');

                    if (mounted) {
                      setState(() {
                        _dragOffset = 0.0;
                        _draggedCardIndex = null;
                        _isAnimatingRelease = false;
                      });
                    }
                  } else {
                    setState(() {
                      _dragOffset = 0.0;
                      _draggedCardIndex = null;
                    });
                  }
                },
                child: AnimatedContainer(
                  height: isMobile ? 350 : 500,
                  duration: Duration(milliseconds: _isAnimatingRelease ? 300 : 0), 
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, totalOffset, 0),
                  margin: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'featured_cake_$actualIndex',
                          child: Image.asset(cakeImages[realIndex], fit: BoxFit.cover),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.2),
                                  Colors.black.withOpacity(0.85),
                                ],
                                stops: const [0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(isMobile ? 25.0 : 20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                cakeNames[realIndex].toUpperCase(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontSize: isMobile ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 0.0),
                              Container(
                                width: 30.0,
                                height: 3.0,
                                decoration: BoxDecoration(
                                  color: _accentPink,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accentPink.withOpacity(0.5),
                                      blurRadius: 10,
                                    )
                                  ]
                                ),
                              ),
                              const SizedBox(height: 10), 
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _initController(bool isMobile) {
    double targetFraction = isMobile ? 0.78 : 0.33; 
    if (_pageController == null ||
        _pageController?.viewportFraction != targetFraction) {
      _pageController?.dispose();
      _pageController = PageController(
        viewportFraction: targetFraction,
        initialPage: _initialPage,
      );
    }
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pageController?.hasClients == true) {
        _pageController?.nextPage(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }

  Widget _buildGlassAppBar(bool isMobile) {
    final double targetFontSize = _isProfileExpanded
        ? (isMobile ? 12.0 : 13.0)
        : (isMobile ? 15.0 : 18.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 30,
            vertical: isMobile ? 10 : 15,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 10 : 8, 
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              style: GoogleFonts.oswald(
                                fontSize: targetFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                shadows: [
                                  const Shadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Text(
                                "BUTTER HEARTS CAKES",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          Row(
                            children: [
                              Flexible(child: _buildLocationPill(isMobile)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: SizedBox(
                            width: (isMobile && _isProfileExpanded) ? 0.0 : null,
                            child: (isMobile && _isProfileExpanded)
                                ? const SizedBox.shrink()
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildCartIconWithBadge(isMobile),
                                      SizedBox(width: isMobile ? 12 : 24),
                                    ],
                                  ),
                          ),
                        ),
                        _buildAnimatedProfileButton(isMobile),
                      ],
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

  Widget _buildLocationPill(bool isMobile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null || userAddress == "Select Location") {
            _showSnackBar("Locating you...");
            _fetchLiveLocationForAppBar();
          } else {
            _showLocationDetailsDialog();
          }
        },
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: _accentPink, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  userAddress == "Select Location" ? "Set Location" : userAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartIconWithBadge(bool isMobile) {
    int count = 0;
    try {
      count = cake.cartList.length;
    } catch (e) {
      count = 0;
    }

    final double iconSize = _isProfileExpanded ? (isMobile ? 18.0 : 22.0) : (isMobile ? 18.0 : 20.0);
    final double padding = _isProfileExpanded ? (isMobile ? 6.0 : 10.0) : (isMobile ? 10.0 : 14.0);
    final double badgeSize = isMobile ? 16.0 : 19.0;
    final double fontSize = isMobile ? 9.0 : 11.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            final User? user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              if (!_isProfileExpanded) {
                setState(() => _isProfileExpanded = true);
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _isProfileExpanded) {
                    setState(() => _isProfileExpanded = false);
                  }
                });
              }
            } else {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Cartpage1(initialAddress: userAddress),
                ),
              );
              if (result != null && result is String) {
                setState(() {
                  userAddress = result;
                  _manualAddressController.text = result;
                });
              }
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: isMobile ? null : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -2.0,
                  right: -2.0,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accentPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _accentPink.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedProfileButton(bool isMobile) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    final double height = _isProfileExpanded ? (isMobile ? 35.0 : 42.0) : (isMobile ? 35.0 : 45.0);
    final double collapsedWidth = height;
    final double expandedWidth = isMobile ? 120.0 : 160.0;
    final double avatarSize = _isProfileExpanded ? (isMobile ? 24.0 : 30.0) : (isMobile ? 25.0 : 32.0);
    final double iconSize = _isProfileExpanded ? (isMobile ? 16.0 : 20.0) : (isMobile ? 20.0 : 22.0);
    final double fontSize = isMobile ? 10.0 : 12.0;
    final double paddingGap = isMobile ? 8.0 : 12.0;

    double containerWidth = _isProfileExpanded ? expandedWidth : collapsedWidth;

    return GestureDetector(
      onTap: () async {
        if (!_isProfileExpanded) {
          setState(() => _isProfileExpanded = true);
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted && _isProfileExpanded) {
              setState(() => _isProfileExpanded = false);
            }
          });
        } else {
          if (isLoggedIn) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Profilepage2()),
            );
            _loadUserData();
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Loginpage2()),
            );
            _loadUserData();
          }
          if (mounted) setState(() => _isProfileExpanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: containerWidth,
        height: height,
        decoration: BoxDecoration(
          color: _isProfileExpanded
              ? (isLoggedIn ? Colors.white.withOpacity(0.2) : const Color(0xFFDA008A).withOpacity(0.8))
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: _isProfileExpanded ? Colors.white54 : Colors.white24,
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minWidth: containerWidth),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    backgroundImage: (isLoggedIn && user?.photoURL != null) ? NetworkImage(user?.photoURL ?? '') : null,
                    child: (isLoggedIn && user?.photoURL != null)
                        ? null
                        : Icon(
                            isLoggedIn ? Icons.person_2_sharp : Icons.person_2_outlined,
                            color: Colors.white,
                            size: iconSize,
                          ),
                  ),
                ),
                if (_isProfileExpanded) ...[
                  SizedBox(width: paddingGap),
                  _buildLiveUserNameText(fontSize, Colors.white),
                  SizedBox(width: paddingGap),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveUserNameText(double fontSize, Color color) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Text(
        "LOGIN",
        style: GoogleFonts.montserrat(fontSize: fontSize, color: color, fontWeight: FontWeight.bold),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        String nameToShow = "BAKER";
        if (snapshot.hasData && snapshot.data?.exists == true) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data != null && data['username'] != null && data['username'].toString().isNotEmpty) {
            nameToShow = data['username'];
          }
        } else if (user.displayName != null) {
          nameToShow = user.displayName ?? "BAKER";
        }
        nameToShow = nameToShow.split(' ')[0].toUpperCase();
        return Text(
          nameToShow,
          style: GoogleFonts.montserrat(color: color, fontWeight: FontWeight.bold, fontSize: fontSize),
        );
      },
    );
  }

  Widget _buildHeaderText(bool isMobile) {
    return Column(
      children: [
        const SizedBox(height: 0),
        Text(
          "Baked with Love,",
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 16 : 18, 
            color: Colors.white70, 
            fontStyle: FontStyle.italic
          ),
        ),
        Text(
          "Served with Heart",
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 22 : 32, 
            fontWeight: FontWeight.bold, 
            color: Colors.white, 
            letterSpacing: 1
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(Size size) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/aaaa.jpg",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: const Color.fromARGB(255, 163, 163, 163).withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterText(bool isMobile) {
    return Column(
      children: [
        Text(
          "\"Celebrate every moment \n with Butter Hearts Cakes.\"",
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white60, 
            fontSize: isMobile ? 14 : 15, 
            height: 1.5
          ),
        ),
      ],
    );
  }

  Widget _buildBusyOverlay(String message, DateTime? resumeTime) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentPink.withOpacity(0.1),
                      border: Border.all(color: _accentPink.withOpacity(0.3), width: 2),
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: _accentPink, size: 50),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "WE ARE BUSY BAKING",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 50),
                  if (resumeTime != null) ...[
                    Text("OPENING AT", style: GoogleFonts.montserrat(color: _accentPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    const SizedBox(height: 10),
                    Text(DateFormat('hh:mm a').format(resumeTime), style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white12)),
                      child: Text("TEMPORARILY CLOSED", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 80),
                  Opacity(
                    opacity: 0.5,
                    child: Text("BUTTER HEARTS CAKES", style: GoogleFonts.oswald(color: Colors.white, fontSize: 12, letterSpacing: 4)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    String loadedName = prefs.getString('username') ?? "User";
    String savedLocalAddress = prefs.getString('userAddress') ?? "";

    if (mounted) {
      setState(() {
        userName = user == null ? "Guest" : loadedName;
        userAddress = savedLocalAddress.isNotEmpty ? savedLocalAddress : "Locating...";
      });
    }

    bool foundSavedAddress = false;

    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          String area = data['area'] ?? '';
          if (mounted) {
            setState(() {
              userAddress = area.isNotEmpty ? area : (data['fullAddress'] ?? "Select Location");
              _manualAddressController.text = userAddress;
            });
          }
          foundSavedAddress = true;
        }
      } catch (e) {
        debugPrint("Error fetching address: $e");
      }
    }

    if (!foundSavedAddress) {
      await _fetchLiveLocationForAppBar();
    }
  }

  Future<void> _fetchLiveLocationForAppBar() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => userAddress = "Select Location");
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => userAddress = "Select Location");
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => userAddress = "Select Location");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (!kIsWeb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String finalAreaName = "";
          if (place.subLocality?.isNotEmpty == true) {
            finalAreaName = place.subLocality ?? "";
          } else if (place.locality?.isNotEmpty == true) {
            finalAreaName = place.locality ?? "";
          } else if (place.administrativeArea?.isNotEmpty == true) {
            finalAreaName = place.administrativeArea ?? "";
          }
          
          String pinCode = place.postalCode ?? "";
          String displayLocation = finalAreaName;
          if (displayLocation.isNotEmpty && pinCode.isNotEmpty) {
            displayLocation = "$displayLocation, $pinCode";
          } else if (displayLocation.isEmpty && pinCode.isNotEmpty) {
            displayLocation = "PIN: $pinCode";
          }

          if (displayLocation.isNotEmpty && mounted) {
            setState(() {
              userAddress = displayLocation;
              _manualAddressController.text = displayLocation;
            });
            final prefs = await SharedPreferences.getInstance();
            prefs.setString('userAddress', displayLocation);
          }
        }
      }
    } catch (e) {
      debugPrint("Auto-location failed: $e");
      if (mounted) setState(() => userAddress = "Select Location");
    }
  }

  void _showLocationDetailsDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Please login to manage addresses");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text(
                "SAVED ADDRESSES",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('addresses')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF2E74),
                        ),
                      );
                    }
                    if (!snapshot.hasData || (snapshot.data?.docs.isEmpty ?? true)) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            "No saved addresses yet.",
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 30),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = (doc.data() as Map<String, dynamic>?) ?? {};

                        String label = data['label'] ?? 'Other';
                        IconData labelIcon = Icons.location_on_rounded;
                        if (label == 'Home') labelIcon = Icons.home_rounded;
                        if (label == 'Work') labelIcon = Icons.work_rounded;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  Navigator.pop(context);
                                  setState(() {
                                    String area = data['area'] ?? '';
                                    userAddress = area.isNotEmpty ? area : (data['fullAddress'] ?? "");
                                    _manualAddressController.text = userAddress;
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  prefs.setString('userAddress', userAddress);
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(labelIcon, color: Colors.black87),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  label.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  data['receiverName'] ?? 'Name',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            data['fullAddress'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 22),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('addresses')
                                    .doc(doc?.id ?? '')
                                    .delete();
                                _loadUserData();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 40),
              Text(
                "ADD NEW ADDRESS",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildLocationActionBtn(
                      "Current\nLocation",
                      Icons.my_location_rounded,
                      Colors.blueAccent,
                      () {
                        Navigator.pop(context);
                        _fetchLiveLocationForAppBar(); 
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLocationActionBtn(
                      "Select on\nMap",
                      Icons.map_outlined,
                      Colors.orangeAccent,
                      () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LocationPage()),
                        );
                        if (result != null && result is Map) {
                          setState(() {
                            userAddress = result['address']?.split(',').last.trim() ?? "Location Set";
                            _manualAddressController.text = userAddress;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setString('userAddress', userAddress);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat()),
        backgroundColor: _accentPink,
      ),
    );
  }
}

class LiveOrderTracker extends StatefulWidget {
  const LiveOrderTracker({super.key});

  @override
  State<LiveOrderTracker> createState() => _LiveOrderTrackerState();
}

class _LiveOrderTrackerState extends State<LiveOrderTracker> with SingleTickerProviderStateMixin {
  Stream<QuerySnapshot>? _orderStream;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _orderStream = FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)  
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots();
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_orderStream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("TRACKER ERROR: ${snapshot.error}");
          return const SizedBox.shrink();
        }
        
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || (snapshot.data?.docs.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data?.docs.first;
        final data = doc?.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        
        String status = data['status'] ?? '';

        List<String> activeStatuses = ['Pending', 'PAID', 'COD', 'Confirmed', 'Baking', 'Preparing', 'Out for Delivery'];
        if (!activeStatuses.contains(status)) return const SizedBox.shrink();

        Color statusColor = const Color(0xFFFF2E74);
        IconData statusIcon = Icons.auto_awesome_rounded;
        String message = "Processing your order...";
        double progress = 0.3;

        if (status == 'Pending' || status == 'PAID' || status == 'COD' || status == 'Confirmed') {
          statusColor = const Color(0xFF00FFC2);
          statusIcon = Icons.receipt_long_rounded;
          message = "Order Received";
          progress = 0.2;
        } else if (status == 'Baking' || status == 'Preparing') {
          statusColor = const Color(0xFFFFB800);
          statusIcon = Icons.outdoor_grill_rounded;
          message = "Baking with love...";
          progress = 0.5;
        } else if (status == 'Out for Delivery') {
          statusColor = const Color(0xFFFF2E74);
          statusIcon = Icons.delivery_dining_rounded;
          message = "Your cake is on the way!";
          progress = 0.8;
        }

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121212).withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        FadeTransition(
                          opacity: Tween(begin: 0.4, end: 1.0).animate(_pulseController),
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: statusColor, blurRadius: 6)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "LIVE TRACKING",
                          style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                    Text(
                      "#${data['orderId']?.toString().split('-').last ?? '...'}",
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: statusColor, minHeight: 3.0),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingOrderPage(orderId: doc?.id ?? ''))),
                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}