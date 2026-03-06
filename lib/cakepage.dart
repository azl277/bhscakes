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
import 'package:google_fonts/google_fonts.dart';

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:project/customisepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Loginpage2.dart';
import 'cartpage1.dart';
import 'cupcakepage.dart';
import 'popsiclepage.dart';

List<Map<String, dynamic>> cartList = [];
ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);
List<Map<String, String>> wishlist = [];

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class AddOnCard extends StatefulWidget {
  final Map<String, String> item;

  final VoidCallback onCartUpdated;
  const AddOnCard({super.key, required this.item, required this.onCartUpdated});

  @override
  State<AddOnCard> createState() => _AddOnCardState();
}

class _AddOnCardState extends State<AddOnCard> {
  final Color _accentPink = const Color(0xFFFF2E74);

  int get quantity =>
      cartList.where((e) => e['name'] == widget.item['name']).length;

  Future<void> _updateQuantity(int delta) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
      'users/${user.uid}/cart',
    );

    try {
      if (delta > 0) {
        if (quantity < 10) {
          int priceInt =
              int.tryParse(
                widget.item['price']!.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;

          await dbRef.push().set({
            'name': widget.item['name'],
            'image': widget.item['image'],
            'price': priceInt,
            'display_price': widget.item['price'],
            'quantity': 1,
            'category': 'AddOn',
            'added_at': ServerValue.timestamp,
          });
        }
      } else {
        if (quantity > 0) {
          final snapshot = await dbRef
              .orderByChild('name')
              .equalTo(widget.item['name'])
              .limitToLast(1)
              .get();

          if (snapshot.exists) {
            Map<dynamic, dynamic> children = snapshot.value as Map;
            String keyToDelete = children.keys.first;
            await dbRef.child(keyToDelete).remove();
          }
        }
      }
      widget.onCartUpdated();
    } catch (e) {
      debugPrint("Error updating AddOn: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
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
                child: Image.asset(widget.item['image']!, fit: BoxFit.contain),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Text(
                  widget.item['name']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.item['price']!,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accentPink,
                  ),
                ),
                const SizedBox(height: 8),
                if (quantity == 0)
                  InkWell(
                    onTap: () => _updateQuantity(1),
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
                          onTap: () => _updateQuantity(-1),
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
                          onTap: () => _updateQuantity(1),
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
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
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
                    if (isLoggedIn && cartCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        "$cartCount",
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
                                builder: (context) => Loginpage2(),
                              ),
                            );
                            if (mounted)
                              setState(() => _isLoginPromptOpen = false);
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

class Cakepage extends StatefulWidget {
  const Cakepage({super.key});

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
  final Map<String, String> _categoryThumbnails = {};
  PageController? _pageController;
  int _currentPage = 0;
  Timer? _timer;
  Timer? _highlightTimer;

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

  Widget _buildMetallicButton({
    required String label,
    required String imagePath,
    required Color baseColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade100,
              baseColor.withOpacity(0.15),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),

          border: Border.all(color: Colors.white, width: 1.5),

          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 5,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -2),
              child: Image.asset(
                imagePath,
                height: 90,
                width: 90,
                fit: BoxFit.contain,
                errorBuilder: (c, o, s) =>
                    Icon(Icons.cake, color: baseColor, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: baseColor.withOpacity(0.8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _activateCartListener();

    _initController(false);

    _preloadThumbnails();
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

    _categoryStreams['addons'] = productRef
        .where('category', whereIn: ['Addons', 'addons', 'Add On', 'add on'])
        .snapshots();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 300) {
        if (!_showShadow.value) _showShadow.value = true;
      } else {
        if (_showShadow.value) _showShadow.value = false;
      }
    });
    _preloadThumbnails();
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

      for (String cat in categories) {
        String? url = await _getCategoryThumbnail(cat);
        if (url != null && url.isNotEmpty && mounted) {
          setState(() {
            _categoryThumbnails[cat] = url;
          });
        }
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
    } else if (_pageController!.viewportFraction != viewport) {
      _pageController!.dispose();
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
      stream: FirebaseFirestore.instance
          .collection('product_categories')
          .where('type', isEqualTo: 'products')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var sortedDocs = snapshot.data!.docs.toList();
        sortedDocs.sort((a, b) {
          Timestamp? tA = (a.data() as Map)['createdAt'] as Timestamp?;
          Timestamp? tB = (b.data() as Map)['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tA.compareTo(tB);
        });

        List<Map<String, dynamic>> quickCategories = sortedDocs.map((doc) {
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

        if (quickCategories.isNotEmpty) {
          quickCategories.insert(1, {
            "title": "Cupcakes",
            "type": "Cupcakes",
            "isRoute": true,
          });
        } else {
          quickCategories.add({
            "title": "Cupcakes",
            "type": "Cupcakes",
            "isRoute": true,
          });
        }

        return Container(
          height: isSticky ? 120 : 85,
          margin: EdgeInsets.zero,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: quickCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final cat = quickCategories[index];
              final String catType = cat['type'];

              return GestureDetector(
                onTap: () {
                  if (cat['isRoute'] == true) {
                    if (cat['title'] == 'Cupcakes') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Cupcakepage()),
                      );
                    }
                  } else {
                    final GlobalKey? key = cat['key'];
                    if (key != null && key.currentContext != null) {
                      Scrollable.ensureVisible(
                        key.currentContext!,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: isSticky ? 90 : 60,
                      width: isSticky ? 90 : 60,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27.5),
                        child: _categoryThumbnails.containsKey(catType)
                            ? buildImage(
                                _categoryThumbnails[catType]!,
                                radius: 27.5,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.cake_rounded,
                                  color: Color(0xFFFF2E74),
                                  size: 30,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: isSticky ? 10 : 6),
                    Text(
                      cat['title'],
                      style: GoogleFonts.inter(
                        fontSize: isSticky ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildValentineMiniCard(Map<String, String> item) {
    return Container(
      width: 95,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(item['image']!, height: 40, fit: BoxFit.contain),
          ),
          const SizedBox(height: 4),

          Text(
            item['name']!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),

          Text(
            item['price']!,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 9),
          ),
          const SizedBox(height: 6),

          GestureDetector(
            onTap: () {
              String target = item['target'] ?? '';
              if (target == 'Cupcake') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Cupcakepage()),
                );
              } else if (target == 'section_cakes') {
                if (_cakesKey.currentContext != null) {
                  Scrollable.ensureVisible(_cakesKey.currentContext!);
                }
              } else {
                _scrollToProduct(target);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4F8B),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4F8B).withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Order",
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

  Future<void> _toggleWishlist(Map<String, String> item) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    final wishlistRef = FirebaseFirestore.instance.collection('wishlist');

    final query = await wishlistRef
        .where('userEmail', isEqualTo: user.email)
        .where('name', isEqualTo: item['name'])
        .get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              "Removed from Wishlist",
              style: GoogleFonts.inter(color: Colors.white),
            ),
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    } else {
      await wishlistRef.add({
        'userEmail': user.email,
        'name': item['name'],
        'price': item['price'],
        'image': item['image'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _accentPink,
            content: Text(
              "Added to Wishlist ❤️",
              style: GoogleFonts.inter(color: Colors.white),
            ),
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }

  void _toggleLike(Map<String, String> item) {
    setState(() {
      final isLiked = wishlist.any(
        (element) => element['name'] == item['name'],
      );
      if (isLiked) {
        wishlist.removeWhere((element) => element['name'] == item['name']);
      } else {
        wishlist.add(item);
      }
    });
  }

  void _showCustomizeModal(
    Map<String, String> item,
    Map<String, dynamic> availability,
    Map<String, int> availableFlavours,
  ) {
    List<String> sizes = [];
    if (availability['halfKg'] != false) sizes.add('0.5 Kg');
    if (availability['oneKg'] != false) sizes.add('1 Kg');
    if (availability['oneHalfKg'] != false) sizes.add('1.5 Kg');
    if (availability['twoKg'] != false) sizes.add('2 Kg');
    if (availability['twoHalfKg'] != false) sizes.add('2.5 Kg');
    if (availability['threeKg'] != false) sizes.add('3 Kg');

    if (sizes.isEmpty) {
      sizes = ['0.5 Kg', '1 Kg', '1.5 Kg', '2 Kg', '2.5 Kg', '3 Kg'];
    }

    List<String> shapes = [];
    if (availability['round'] != false) shapes.add('Round');
    if (availability['square'] != false) shapes.add('Square');
    if (availability['heart'] != false) shapes.add('Heart');
    if (shapes.isEmpty) shapes.addAll(['Round', 'Square', 'Heart']);

    final TextEditingController cakeWritingController = TextEditingController();

    String priceString = (item['isOffer'] == 'true')
        ? item['offerPrice']!
        : item['price']!;
    int basePrice =
        int.tryParse(priceString.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    String selectedShape = shapes.first;
    String selectedWeight = sizes.contains("1 Kg") ? "1 Kg" : sizes.first;
    String? selectedFlavourKey = availableFlavours.isNotEmpty
        ? availableFlavours.keys.first
        : null;
    int selectedFlavourPrice = availableFlavours.isNotEmpty
        ? availableFlavours.values.first
        : 0;

    final Widget cachedCakeImage = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 100,
        width: 100,
        child: buildImage(item['image']!),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        int currentPrice = basePrice + selectedFlavourPrice;

        return StatefulBuilder(
          builder: (context, setModalState) {
            double multiplier = 1.0;
            switch (selectedWeight) {
              case '0.5 Kg':
                multiplier = 0.5;
                break;
              case '1 Kg':
                multiplier = 1.0;
                break;
              case '1.5 Kg':
                multiplier = 1.5;
                break;
              case '2 Kg':
                multiplier = 2.0;
                break;
              case '2.5 Kg':
                multiplier = 2.5;
                break;
              case '3 Kg':
                multiplier = 3.0;
                break;
              default:
                multiplier = 1.0;
            }

            currentPrice =
                (basePrice * multiplier).toInt() + selectedFlavourPrice;
            if (selectedShape == "Heart") currentPrice += 50;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
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
                                cachedCakeImage,
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']!,
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

                                      TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        curve: Curves.easeOutQuart,
                                        tween: Tween<double>(
                                          begin: currentPrice.toDouble(),
                                          end: currentPrice.toDouble(),
                                        ),
                                        builder: (context, value, child) {
                                          return Text(
                                            "Rs ${value.toInt()}",
                                            style: GoogleFonts.montserrat(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: _accentPink,
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 8),

                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          "In Stock",
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            if (item['desc'] != null &&
                                item['desc']!.isNotEmpty) ...[
                              Text(
                                "DESCRIPTION",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['desc']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            const Divider(),
                            const SizedBox(height: 20),

                            Text(
                              "Select Shape",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: shapes.map((shape) {
                                bool isSelected = selectedShape == shape;
                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => selectedShape = shape,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentPink
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accentPink
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      shape,
                                      style: GoogleFonts.inter(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 25),

                            Text(
                              "Select Weight",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: sizes.map((weight) {
                                bool isSelected = selectedWeight == weight;
                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => selectedWeight = weight,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentPink
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accentPink
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      weight,
                                      style: GoogleFonts.inter(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 25),

                            if (availableFlavours.isNotEmpty) ...[
                              Text(
                                "Select Flavor",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _accentPink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: availableFlavours.entries.map((
                                  entry,
                                ) {
                                  bool isSelected =
                                      selectedFlavourKey == entry.key;
                                  return GestureDetector(
                                    onTap: () => setModalState(() {
                                      selectedFlavourKey = entry.key;
                                      selectedFlavourPrice = entry.value;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Text(
                                        "${entry.key} ${entry.value > 0 ? '(+₹${entry.value})' : ''}",
                                        style: GoogleFonts.inter(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 25),
                            ],

                            Text(
                              "Message on Cake",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: cakeWritingController,
                              maxLength: 30,
                              decoration: InputDecoration(
                                hintText: "Happy Birthday Name...",
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: _accentPink,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 80),
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

                            Map<String, int> flavors = {};
                            if (selectedFlavourKey != null)
                              flavors[selectedFlavourKey!] =
                                  selectedFlavourPrice;

                            _addToCartWithDetails(
                              item,
                              selectedShape,
                              selectedWeight,
                              currentPrice,
                              flavors,
                              cakeWritingController.text,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),

                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                tween: Tween<double>(
                                  begin: currentPrice.toDouble(),
                                  end: currentPrice.toDouble(),
                                ),
                                builder: (context, value, child) {
                                  return Text(
                                    "ADD TO CART  •  ₹${value.toInt()}",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  );
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

  Widget _buildAddOnsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: 'addons')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final products = snapshot.data!.docs;

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
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final data = products[index].data() as Map<String, dynamic>;

                  final addonItem = {
                    "name": data['name']?.toString() ?? "",
                    "price": data['price']?.toString() ?? "Rs 0",
                    "image": data['image']?.toString() ?? "",
                  };

                  return AddOnCard(
                    item: addonItem,
                    onCartUpdated: () {
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildAddOnCard(Map<String, String> item) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),

        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: buildImage(item['image']!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  item['name']!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['price']!,
                  style: GoogleFonts.montserrat(
                    color: _accentPink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildMiniAddOnCard(Map<String, String> item, {GlobalKey? itemKey}) {
    return Container(
      key: itemKey,
      width: 140,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 49, 0, 0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: buildImage(item['image'] ?? ''),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['price'] ?? 'Rs 0',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _accentPink,
                  ),
                ),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () => _showAddOnModal(item),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        "ADD",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _accentPink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOnModal(Map<String, String> item) {
    int quantity = 1;
    int basePrice =
        int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
      _showLoginRequiredDialog();
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
      _showLoginRequiredDialog();
      return;
    }

    int priceInt =
        int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': priceInt,
      'display_price': item['price'],
      'quantity': 1,
      'category': 'AddOn',
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
                      _buildTopBanner(isMobile),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),

                SliverPersistentHeader(
                  pinned: true,
                  delegate: CategoryHeaderDelegate(
                    showAppBar: _showAppBar,
                    child: _buildQuickCategories(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('product_categories')
                        .where('type', isEqualTo: 'products')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        );

                      var sortedDocs = snapshot.data!.docs.toList();
                      sortedDocs.sort((a, b) {
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

                          ...sortedDocs.map((doc) {
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

  Widget _buildTopBanner(bool isMobile) {
    return Container(
      height: isMobile ? 260 : 240,
      width: double.infinity,

      padding: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 148, 4, 251),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: const Alignment(-0.75, -0.2),
            child: Image.asset('assets/shop2.gif', height: isMobile ? 140 : 90),
          ),
          Align(
            alignment: const Alignment(0.75, 0.0),
            child: Image.asset('assets/shop1.gif', height: isMobile ? 110 : 90),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    String category, {
    GlobalKey? key,
  }) {
    final stream = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: category)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final double width = MediaQuery.of(context).size.width;
        final int crossAxisCount = width < 600 ? 2 : 4;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCategorySkeleton(title, crossAxisCount);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();

        final products = snapshot.data!.docs;

        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
              child: Row(
                children: [
                  Container(
                    height: 20,
                    width: 4,
                    decoration: BoxDecoration(
                      color: _accentPink,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  final doc = products[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String name = data['name']?.toString() ?? 'Unknown';

                  final Map<String, dynamic> rawFlavours =
                      data['flavours'] is Map
                      ? data['flavours'] as Map<String, dynamic>
                      : {};
                  final Map<String, int> flavours = rawFlavours.map(
                    (key, value) =>
                        MapEntry(key, int.tryParse(value.toString()) ?? 0),
                  );
                  final Map<String, dynamic> availability =
                      data['availability'] is Map
                      ? data['availability'] as Map<String, dynamic>
                      : {};

                  if (name.isNotEmpty && !_productKeys.containsKey(name)) {
                    _productKeys[name] = GlobalKey();
                  }

                  final Map<String, String> cakeItem = {
                    'id': doc.id,
                    'name': name,
                    'category': data['category']?.toString() ?? 'Cake',
                    'image': data['image']?.toString() ?? '',
                    'price': data['price']?.toString() ?? 'Rs 0',
                    'desc': data['desc']?.toString() ?? '',
                    'isAvailable': (data['isAvailable'] ?? true).toString(),
                    'isOffer': (data['isOffer'] ?? false).toString(),
                    'offerPrice': data['offerPrice']?.toString() ?? '',
                  };

                  return _buildCompactCakeCard(
                    cakeItem,
                    availability,
                    flavours,
                    itemKey: _productKeys[name],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMiniCategorySkeleton(title);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final products = snapshot.data!.docs;

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
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final data = products[index].data() as Map<String, dynamic>;
                  final String name = data['name']?.toString() ?? '';
                  if (name.isNotEmpty && !_productKeys.containsKey(name)) {
                    _productKeys[name] = GlobalKey();
                  }

                  final item = {
                    'name': name,
                    'price': data['price']?.toString() ?? 'Rs 0',
                    'image': data['image']?.toString() ?? '',
                    'category': data['category']?.toString() ?? 'AddOn',
                  };

                  return _buildMiniAddOnCard(item, itemKey: _productKeys[name]);
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildCategorySkeleton(String title, int crossAxisCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              childAspectRatio: 0.72,
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
    );
  }

  Widget _buildMiniCategorySkeleton(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: SkeletonShimmer(
            width: 120,
            height: 24,
            borderRadius: 5,
            baseColor: Colors.white24,
            highlightColor: Colors.white54,
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              return Container(
                width: 140,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 49, 0, 0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SkeletonShimmer(
                          width: double.infinity,
                          borderRadius: 15,
                          baseColor: Colors.white12,
                          highlightColor: Colors.white24,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 12),
                      child: Column(
                        children: [
                          SkeletonShimmer(
                            width: 90,
                            height: 14,
                            borderRadius: 4,
                            baseColor: Colors.white12,
                            highlightColor: Colors.white24,
                          ),
                          SizedBox(height: 8),
                          SkeletonShimmer(
                            width: 50,
                            height: 14,
                            borderRadius: 4,
                            baseColor: Colors.white12,
                            highlightColor: Colors.white24,
                          ),
                          SizedBox(height: 12),
                          SkeletonShimmer(
                            width: double.infinity,
                            height: 26,
                            borderRadius: 20,
                            baseColor: Colors.white12,
                            highlightColor: Colors.white24,
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
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCompactCakeCard(
    Map<String, String> item,
    Map<String, dynamic> availability,
    Map<String, int> flavours, {
    GlobalKey? itemKey,
  }) {
    bool isAvailable = item['isAvailable'] != 'false';
    bool isOffer = item['isOffer'] == 'true';
    String offerPrice = item['offerPrice'] ?? '';

    final user = FirebaseAuth.instance.currentUser;

    return MouseRegion(
      cursor: isAvailable
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isAvailable
            ? () => _showCustomizeModal(item, availability, flavours)
            : null,
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
                              ? buildImage(item['image']!)
                              : ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ]),
                                  child: buildImage(item['image']!),
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
                      top: 8,
                      right: 8,
                      child: StreamBuilder(
                        stream: user != null
                            ? FirebaseDatabase.instance
                                  .ref()
                                  .child('users/${user.uid}/wishlist')
                                  .orderByChild('name')
                                  .equalTo(item['name'])
                                  .onValue
                            : null,
                        builder:
                            (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                              bool liked =
                                  snapshot.hasData &&
                                  snapshot.data!.snapshot.exists;

                              return GestureDetector(
                                onTap: () => _toggleRealtimeWishlist(item),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: liked ? Colors.red : Colors.grey,
                                    size: 16,
                                  ),
                                ),
                              );
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
                      item['name']!,
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
                                  item['price']!,
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
                                  item['price']!,
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
      ),
    );
  }

  Widget _buildElegantGlassAppBar(bool isMobile) {
    final double barHeight = isMobile ? 60.0 : 70.0;
    final double iconSize = isMobile ? 36.0 : 40.0;
    final double horizontalPadding = isMobile ? 12.0 : 24.0;
    final double fontSize = isMobile ? 16.0 : 18.0;

    return Positioned(
      top: isMobile ? 10 : 20,
      left: 0,
      right: 0,
      child: Center(
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
                          BoxShadow(
                            color: const Color.fromARGB(30, 0, 0, 0),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
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
      ),
    );
  }

  Widget _buildGlassActionButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 40.0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
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
        ],
      ),
    );
  }

  Widget _buildCartBadge() {
    double targetWidth = (!isLoggedIn && _isLoginPromptOpen)
        ? 130.0
        : (cartList.isNotEmpty && isLoggedIn ? 75.0 : 52.0);

    return GestureDetector(
      onTap: () async {
        if (isLoggedIn) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Cartpage1()),
          );
          setState(() {});
        } else {
          setState(() {
            _isLoginPromptOpen = !_isLoginPromptOpen;
          });
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
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Loginpage2()),
                        );
                        if (mounted) {
                          setState(() {
                            _isLoginPromptOpen = false;
                          });
                        }
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
  }

  Widget _buildNavText(String text, bool isActive) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: isActive ? _accentPink : Colors.white70,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 14,
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildProductDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      color: const Color.fromARGB(88, 153, 153, 153),
      elevation: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      onSelected: (value) {
        if (value == 'Cupcake')
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Cupcakepage()),
          );
        else if (value == 'popsicle')
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Popsiclepage()),
          );
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'Cupcake',
          child: Row(
            children: [
              Icon(Icons.cake, color: _accentPink, size: 20),
              const SizedBox(width: 12),
              Text('Cakes', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'popsicle',
          child: Row(
            children: [
              const Icon(Icons.icecream, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Popsicles', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(
          Icons.grid_view_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _toggleRealtimeWishlist(Map<String, String> item) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    final DatabaseReference wishlistRef = FirebaseDatabase.instance.ref().child(
      'users/${user.uid}/wishlist',
    );

    try {
      final snapshot = await wishlistRef
          .orderByChild('name')
          .equalTo(item['name'])
          .get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map;
        String keyToDelete = data.keys.first;
        await wishlistRef.child(keyToDelete).remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Removed from Wishlist"),
              backgroundColor: Colors.black87,
            ),
          );
        }
      } else {
        await wishlistRef.push().set({
          'name': item['name'],
          'image': item['image'],
          'price': item['price'],
          'desc': item['desc'],
          'added_at': ServerValue.timestamp,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Added to Wishlist ❤️"),
              backgroundColor: _accentPink,
            ),
          );
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint("Wishlist Error: $e");
    }
  }

  bool _isInWishlist(String productName) {
    return wishlist.any((element) => element['name'] == productName);
  }
}

class SkeletonShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 15,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.baseColor ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final ValueNotifier<bool> showAppBar;

  CategoryHeaderDelegate({required this.child, required this.showAppBar});

  @override
  double get minExtent => 95.0;
  @override
  double get maxExtent => 95.0;

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
