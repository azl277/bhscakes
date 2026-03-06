import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:project/cakepage.dart';
import 'package:project/cartpage1.dart';
import 'package:project/Loginpage2.dart';

List<Map<String, dynamic>> cartList = [];
ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class Cupcakepage extends StatefulWidget {
  const Cupcakepage({super.key});

  @override
  State<Cupcakepage> createState() => _CupcakepageState();
}

class _CupcakepageState extends State<Cupcakepage> {
  final ValueNotifier<bool> _showAppBar = ValueNotifier(true);
  final ValueNotifier<bool> _showShadow = ValueNotifier(false);
  bool _isStatusBarDark = false;
  bool _isLoginPromptOpen = false;

  StreamSubscription<DatabaseEvent>? _cartSubscription;

  final Map<String, GlobalKey> _productKeys = {};
  final Map<String, String> _categoryThumbnails = {};

  late ScrollController _scrollController;
  final Color _accentPink = const Color(0xFFFF2E74);

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
    super.dispose();
  }

  Future<void> _preloadThumbnails() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('product_categories')
          .where('type', isEqualTo: 'cupcakes')
          .get();
      List<String> categories = snap.docs
          .map((doc) => doc['name'].toString())
          .toList();

      categories.insert(0, 'Cakes');

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

  Future<String?> _getCategoryThumbnail(String categoryType) async {
    try {
      if (categoryType.toLowerCase() == 'cakes') {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .limit(1)
            .get();
        if (doc.docs.isNotEmpty) return doc.docs.first['image']?.toString();
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('cupcakes')
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

  void _onScroll() {
    if (_scrollController.offset > 300) {
      if (!_showShadow.value) _showShadow.value = true;
    } else {
      if (_showShadow.value) _showShadow.value = false;
    }

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

  void _activateCartListener() {
    final user = FirebaseAuth.instance.currentUser;
    _cartSubscription?.cancel();

    if (user == null) {
      if (mounted)
        setState(() {
          cartList.clear();
          cartCountNotifier.value = 0;
        });
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

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Login Required",
          style: GoogleFonts.playfairDisplay(color: Colors.white),
        ),
        content: Text(
          "Please login to add items to your cart or wishlist.",
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Loginpage2()),
              );
              if (mounted) setState(() {});
            },
            child: const Text(
              "Login",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Removed from Wishlist"),
              backgroundColor: Colors.black87,
            ),
          );
      } else {
        await wishlistRef.push().set({
          'name': item['name'],
          'image': item['image'],
          'price': item['price'],
          'added_at': ServerValue.timestamp,
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Added to Wishlist ❤️"),
              backgroundColor: Color(0xFFFF2E74),
            ),
          );
      }
      setState(() {});
    } catch (e) {
      debugPrint("Wishlist Error: $e");
    }
  }

  Widget _buildQuickCategories({bool isSticky = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('product_categories')
          .where('type', isEqualTo: 'cupcakes')
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
          if (!_productKeys.containsKey(catName))
            _productKeys[catName] = GlobalKey();
          return {
            "title": catName,
            "type": catName,
            "isRoute": false,
            "key": _productKeys[catName],
          };
        }).toList();

        quickCategories.insert(0, {
          "title": "Cakes",
          "type": "Cakes",
          "isRoute": true,
        });

        return Container(
          height: isSticky ? 100 : 85,
          margin: EdgeInsets.zero,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: quickCategories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final cat = quickCategories[index];
              final String catType = cat['type'];

              return GestureDetector(
                onTap: () {
                  if (cat['isRoute'] == true) {
                    if (cat['title'] == 'Cakes') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Cakepage()),
                      );
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

                child: SizedBox(
                  width: isSticky ? 70 : 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: isSticky ? 60 : 50,
                        width: isSticky ? 60 : 50,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: _categoryThumbnails.containsKey(catType)
                              ? buildImage(
                                  _categoryThumbnails[catType]!,
                                  radius: 35,
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.cake_rounded,
                                    color: Color(0xFFFF2E74),
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: isSticky ? 8 : 6),
                      Text(
                        cat['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: isSticky ? 11 : 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategorySection(
    String title,
    String category, {
    GlobalKey? key,
  }) {
    final stream = FirebaseFirestore.instance
        .collection('cupcakes')
        .where('category', isEqualTo: category)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final double width = MediaQuery.of(context).size.width;
        int crossAxisCount = width > 1200
            ? 5
            : width > 900
            ? 4
            : width > 600
            ? 3
            : 2;
        double childAspectRatio = width > 1200
            ? 0.85
            : width > 900
            ? 0.80
            : width > 600
            ? 0.75
            : width < 360
            ? 0.65
            : 0.72;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCategorySkeleton(
            title,
            crossAxisCount,
            childAspectRatio,
          );
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
                      fontSize: 24,
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
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final doc = products[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String name = data['name']?.toString() ?? 'Unknown';

                  final Map<String, String> cupcakeItem = {
                    'id': doc.id,
                    'name': name,
                    'category': data['category']?.toString() ?? 'Cupcakes',
                    'image': data['image']?.toString() ?? '',
                    'price': data['price']?.toString() ?? 'Rs 0',
                    'desc': data['desc']?.toString() ?? '',
                    'isAvailable': (data['isAvailable'] ?? true).toString(),
                    'isOffer': (data['isOffer'] ?? false).toString(),
                    'offerPrice': data['offerPrice']?.toString() ?? '',
                  };

                  return _buildCompactCupcakeCard(cupcakeItem);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildCompactCupcakeCard(Map<String, String> item) {
    bool isAvailable = item['isAvailable'] != 'false';
    bool isOffer = item['isOffer'] == 'true';
    String offerPrice = item['offerPrice'] ?? '';

    final user = FirebaseAuth.instance.currentUser;

    return MouseRegion(
      cursor: isAvailable
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isAvailable ? () => _showCustomizeModal(item) : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Center(
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['name']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isAvailable
                            ? Colors.black87
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['desc'] ?? "Delicious cupcake",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 10),

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
                                    fontSize: 13,
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
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? _accentPink
                                : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            boxShadow: isAvailable
                                ? [
                                    BoxShadow(
                                      color: _accentPink.withOpacity(0.3),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            isAvailable
                                ? Icons.add
                                : Icons.remove_shopping_cart_rounded,
                            color: isAvailable
                                ? Colors.white
                                : Colors.grey.shade400,
                            size: 18,
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

  void _showCustomizeModal(Map<String, String> item) {
    bool isOffer = item['isOffer'] == 'true';
    String activePriceString =
        (isOffer &&
            item['offerPrice'] != null &&
            item['offerPrice']!.isNotEmpty)
        ? item['offerPrice']!
        : item['price']!;

    int basePrice =
        int.tryParse(activePriceString.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int originalBasePrice =
        int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ??
        basePrice;

    final Widget cachedCupcakeImage = Container(
      height: 95,
      width: 95,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Hero(
        tag: "${item['name']}_modal_${item['id']}",
        child: buildImage(item['image']!),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        String selectedPack = "6 Pc";
        int currentPrice = basePrice * 2;
        int originalCurrentPrice = originalBasePrice * 2;

        return StatefulBuilder(
          builder: (context, setModalState) {
            int calculatePrice(String pack, int base) {
              if (pack == "3 Pc") return base;
              if (pack == "6 Pc") return base * 2;
              if (pack == "12 Pc") return base * 4;
              return base;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 500
                    : double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 15),
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
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
                                cachedCupcakeImage,
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']!,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
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
                                                "₹${value.toInt()}",
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  color: _accentPink,
                                                ),
                                              );
                                            },
                                          ),
                                          if (isOffer) ...[
                                            const SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2.0,
                                              ),
                                              child: TweenAnimationBuilder<double>(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeOutQuart,
                                                tween: Tween<double>(
                                                  begin: originalCurrentPrice
                                                      .toDouble(),
                                                  end: originalCurrentPrice
                                                      .toDouble(),
                                                ),
                                                builder: (context, value, child) {
                                                  return Text(
                                                    "₹${value.toInt()}",
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                        ),
                                                  );
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

                            if (item['desc'] != null &&
                                item['desc']!.isNotEmpty) ...[
                              Text(
                                "DESCRIPTION",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['desc']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 25),

                            Text(
                              "SELECT BOX SIZE",
                              style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 15),

                            Row(
                              children: ["3 Pc", "6 Pc", "12 Pc"].map((pack) {
                                bool isSelected = selectedPack == pack;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedPack = pack;
                                        currentPrice = calculatePrice(
                                          pack,
                                          basePrice,
                                        );
                                        originalCurrentPrice = calculatePrice(
                                          pack,
                                          originalBasePrice,
                                        );
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _accentPink.withOpacity(0.08)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? _accentPink
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _accentPink
                                                      .withOpacity(0.1),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          pack,
                                          style: GoogleFonts.inter(
                                            color: isSelected
                                                ? _accentPink
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 35),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
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
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _addToCartWithDetails(
                              item,
                              selectedPack,
                              "Rs $currentPrice",
                            );
                            Navigator.pop(context);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 20),
                              const SizedBox(width: 12),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                tween: Tween<double>(
                                  begin: currentPrice.toDouble(),
                                  end: currentPrice.toDouble(),
                                ),
                                builder: (context, value, child) {
                                  return Text(
                                    "ADD TO CART • ₹${value.toInt()}",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
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

  void _addToCartWithDetails(
    Map<String, String> item,
    String quantity,
    String finalPrice,
  ) async {
    if (!isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    int priceInt =
        int.tryParse(finalPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'selected_shape': 'Standard',
      'selected_weight': quantity,
      'price': priceInt,
      'display_price': finalPrice,
      'quantity': 1,
      'cakeWriting': 'No writing',
      'flavours': '{}',
      'delivery_address': currentSavedAddress,
      'category': item['category'] ?? 'Cupcake',
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/${user!.uid}/cart',
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
                          "${item['name']} ($quantity)",
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

  Widget _buildTopBackground(bool isMobile) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 0, 46, 139),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(1, 0.4),
            child: Image.asset(
              'assets/cc.gif',
              height: isMobile ? 170 : 130,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.cake, color: Colors.white24, size: 80),
            ),
          ),
          Align(
            alignment: const Alignment(-1, 0.4),
            child: Image.asset(
              'assets/n.gif',
              height: isMobile ? 100 : 130,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.cake, color: Colors.white24, size: 80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySkeleton(
    String title,
    int crossAxisCount,
    double childAspectRatio,
  ) {
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
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
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
          if (value == 'cakes')
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Cakepage()),
            );
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'cakes',
            child: Row(
              children: [
                const Icon(Icons.cake, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Cakes', style: GoogleFonts.inter(color: Colors.white)),
              ],
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      extendBodyBehindAppBar: false,
      body: ScrollConfiguration(
        behavior: DesktopScrollBehavior(),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: SafeArea(
                top: false,
                bottom: false,
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.horizontal)
                      return false;
                    if (notification.direction == ScrollDirection.reverse) {
                      if (_showAppBar.value) _showAppBar.value = false;
                    } else if (notification.direction ==
                        ScrollDirection.forward) {
                      if (!_showAppBar.value) _showAppBar.value = true;
                    }
                    return true;
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: isMobile
                        ? const BouncingScrollPhysics()
                        : const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            _buildTopBackground(isMobile),
                            const SizedBox(height: 35),
                            Padding(
                              padding: EdgeInsets.only(
                                top: isMobile ? 110 : 130,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SliverPersistentHeader(
                        pinned: true,
                        delegate: CategoryHeaderDelegate(
                          showAppBar: _showAppBar,
                          child: _buildQuickCategories(isSticky: true),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 10)),

                      SliverToBoxAdapter(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('product_categories')
                              .where('type', isEqualTo: 'cupcakes')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
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
              ),
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
      ),
    );
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
        setState(() => _isLoginPromptOpen = false);
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
              setState(() => _isLoginPromptOpen = !_isLoginPromptOpen);
              if (_isLoginPromptOpen) _startAutoCloseTimer();
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
