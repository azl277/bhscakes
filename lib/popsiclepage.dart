import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:project/cakepage.dart';
import 'package:project/cartpage1.dart';
import 'package:project/Loginpage2.dart';
import 'package:project/cupcakepage.dart' hide cartList;

class DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class Popsiclepage extends StatefulWidget {
  const Popsiclepage({super.key});

  @override
  State<Popsiclepage> createState() => _PopsiclepageState();
}

class _PopsiclepageState extends State<Popsiclepage> {
  final ValueNotifier<bool> _isAppBarVisible = ValueNotifier(true);
  final ValueNotifier<bool> _showShadow = ValueNotifier(false);
  double _lastScrollOffset = 0;

  Stream<QuerySnapshot>? _popsiclesStream;
  Stream<QuerySnapshot>? _sliderStream;
  StreamSubscription<DatabaseEvent>? _cartSubscription;

  PageController? _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final ScrollController _scrollController = ScrollController();
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _bgBlack = const Color(0xFF050505);

  @override
  void initState() {
    super.initState();

    _popsiclesStream = FirebaseFirestore.instance
        .collection('popsicles')
        .snapshots();
    _sliderStream = FirebaseFirestore.instance
        .collection('popsicle_slider')
        .snapshots();

    _activateCartListener();
    _startAutoSlider();
    _scrollController.addListener(_scrollListener);
  }

  void _activateCartListener() {
    final user = FirebaseAuth.instance.currentUser;
    _cartSubscription?.cancel();

    if (user == null) {
      if (mounted) setState(() => cartList.clear());
      return;
    }

    final ref = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');

    _cartSubscription = ref.onValue.listen((event) {
      if (mounted) {
        setState(() {
          cartList.clear();
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              cartList.add(Map<String, dynamic>.from(value));
            });
          }
        });
      }
    });
  }

  void _scrollListener() {
    double currentOffset = _scrollController.offset;
    if (currentOffset < 0) return;

    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      if (_isAppBarVisible.value) _isAppBarVisible.value = false;
    } else if (currentOffset < _lastScrollOffset) {
      if (!_isAppBarVisible.value) _isAppBarVisible.value = true;
    }
    _showShadow.value = currentOffset > 10;
    _lastScrollOffset = currentOffset;
  }

  void _initController(bool isMobile) {
    double viewport = isMobile ? 0.85 : 0.5;
    if (_pageController == null ||
        _pageController!.viewportFraction != viewport) {
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: 0,
        viewportFraction: viewport,
      );
    }
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController != null && _pageController!.hasClients) {
        _currentPage++;
        _pageController!.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    _scrollController.dispose();
    _cartSubscription?.cancel();
    _isAppBarVisible.dispose();
    _showShadow.dispose();
    super.dispose();
  }

  Widget buildImage(String imageString) {
    try {
      if (imageString.startsWith('assets/')) {
        return Image.asset(imageString, fit: BoxFit.contain);
      } else if (imageString.startsWith('http')) {
        return Image.network(imageString, fit: BoxFit.contain, cacheWidth: 300);
      } else {
        return Image.memory(
          base64Decode(imageString),
          fit: BoxFit.contain,
          cacheWidth: 300,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.white24),
        );
      }
    } catch (e) {
      return const Icon(Icons.error, color: Colors.red);
    }
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
            SnackBar(
              content: const Text("Added to Wishlist ❤️"),
              backgroundColor: Color(0xFFFF2E74),
            ),
          );
      }
      setState(() {});
    } catch (e) {
      debugPrint("Wishlist Error: $e");
    }
  }

  void _showCustomizeModal(Map<String, String> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        String selectedPack = "Box of 1";

        bool hasOffer = item['isOffer'] == 'true';
        String priceString = hasOffer ? item['offerPrice']! : item['price']!;
        int basePrice =
            int.tryParse(priceString.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int currentPrice = basePrice;

        return StatefulBuilder(
          builder: (context, setModalState) {
            int calculatePrice(String pack) {
              int multiplier = 1;
              if (pack == "Box of 4") multiplier = 4;
              if (pack == "Box of 8") multiplier = 8;
              if (pack == "Box of 12") multiplier = 12;
              return basePrice * multiplier;
            }

            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 500
                    : double.infinity,
                height: 480,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                    bottom: Radius.circular(30),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            color: Colors.black38,
                            height: 80,
                            width: 80,
                            padding: const EdgeInsets.all(8),
                            child: buildImage(item['image']!),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name']!,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  "Rs $currentPrice",
                                  key: ValueKey(currentPrice),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _accentPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 20),

                    Text(
                      "Choose Pack Size",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          ["Box of 1", "Box of 4", "Box of 8", "Box of 12"].map(
                            (pack) {
                              bool isSelected = selectedPack == pack;
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedPack = pack;
                                    currentPrice = calculatePrice(pack);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _accentPink
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? _accentPink
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Text(
                                    pack,
                                    style: GoogleFonts.inter(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white60,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentPink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                        ),
                        onPressed: () {
                          _addToCartWithDetails(
                            item,
                            selectedPack,
                            "Rs $currentPrice",
                          );
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Add to Cart - Rs $currentPrice",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      'category': 'Popsicle',
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;
    _initController(isMobile);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: _bgBlack,
      extendBodyBehindAppBar: true,
      body: ScrollConfiguration(
        behavior: DesktopScrollBehavior(),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: Image.asset(
                "assets/aaaa.jpg",
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.95),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),

            SafeArea(
              bottom: false,
              child: CustomScrollView(
                controller: _scrollController,
                physics: isMobile
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 280,
                      width: isMobile
                          ? MediaQuery.of(context).size.width
                          : 1000,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _sliderStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return Center(
                              child: CircularProgressIndicator(
                                color: _accentPink,
                              ),
                            );
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text(
                                "Add Slider Items in Admin",
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return PageView.builder(
                            controller: _pageController,
                            itemBuilder: (context, index) {
                              final dataIndex = index % docs.length;
                              final data =
                                  docs[dataIndex].data()
                                      as Map<String, dynamic>;

                              Map<String, String> item = {
                                "name": data['name'] ?? "Special Pop",
                                "desc": data['desc'] ?? "Refreshing",
                                "price": data['price']?.toString() ?? "Rs 0",
                                "image": data['image'] ?? "",
                                "isOffer": (data['isOffer'] ?? false)
                                    .toString(),
                                "offerPrice":
                                    data['offerPrice']?.toString() ?? "",
                              };

                              return AnimatedBuilder(
                                animation: _pageController!,
                                builder: (context, child) {
                                  double value = 1.0;
                                  if (_pageController!
                                      .position
                                      .haveDimensions) {
                                    value =
                                        (_pageController!.page ?? 0) - index;
                                    value = (1 - (value.abs() * 0.20)).clamp(
                                      0.85,
                                      1.0,
                                    );
                                  }
                                  return Center(
                                    child: Transform.scale(
                                      scale: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildNormalSliderCard(item),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),

                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 35, 20, 0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(45),
                              topRight: Radius.circular(45),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Gourmet Popsicles",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),

                              StreamBuilder<QuerySnapshot>(
                                stream: _popsiclesStream,
                                builder: (context, snapshot) {
                                  int count = snapshot.hasData
                                      ? snapshot.data!.docs.length
                                      : 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _accentPink.withOpacity(0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      color: _accentPink.withOpacity(0.1),
                                    ),
                                    child: Text(
                                      "$count FLAVORS",
                                      style: GoogleFonts.inter(
                                        color: _accentPink,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _popsiclesStream,
                            builder:
                                (
                                  context,
                                  AsyncSnapshot<QuerySnapshot> streamSnapshot,
                                ) {
                                  if (streamSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40.0),
                                        child: CircularProgressIndicator(
                                          color: Colors.pink,
                                        ),
                                      ),
                                    );
                                  }
                                  if (!streamSnapshot.hasData ||
                                      streamSnapshot.data!.docs.isEmpty) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40.0),
                                        child: Text(
                                          "No popsicles available",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    );
                                  }

                                  final itemsData = streamSnapshot.data!.docs;
                                  int crossAxisCount = isMobile ? 2 : 4;

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      25,
                                      20,
                                      100,
                                    ),
                                    child: GridView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            crossAxisSpacing: 18,
                                            mainAxisSpacing: 18,
                                            childAspectRatio: 0.72,
                                          ),
                                      itemCount: itemsData.length,
                                      itemBuilder: (context, index) {
                                        Map<String, dynamic> data =
                                            itemsData[index].data()
                                                as Map<String, dynamic>;

                                        Map<String, String> item = {
                                          "id": itemsData[index].id,
                                          "name":
                                              data['name']?.toString() ??
                                              "Popsicle",
                                          "price":
                                              data['price']?.toString() ??
                                              "Rs 0",
                                          "desc":
                                              data['desc']?.toString() ??
                                              "Tasty",
                                          "image":
                                              data['image']?.toString() ?? "",
                                          "isAvailable":
                                              (data['isAvailable'] ?? true)
                                                  .toString(),
                                          "isOffer": (data['isOffer'] ?? false)
                                              .toString(),
                                          "offerPrice":
                                              data['offerPrice']?.toString() ??
                                              "",
                                        };

                                        return _buildCompactCakeCard(item);
                                      },
                                    ),
                                  );
                                },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: isMobile ? 10 : 25,
              left: 0,
              right: 0,
              child: SafeArea(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isAppBarVisible,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalSliderCard(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(opacity: 0.15, child: buildImage(item['image']!)),
            ),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      top: 20,
                      bottom: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item['desc']!.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _accentPink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['name']!,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPink,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => _showCustomizeModal(item),
                          child: const Text(
                            "Order Now",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Hero(
                      tag: "${item['name']}_slider",
                      child: buildImage(item['image']!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCompactCakeCard(Map<String, String> item) {
    bool isAvailable = item['isAvailable'] != 'false';
    bool isOffer = item['isOffer'] == 'true';
    String offerPrice = item['offerPrice'] ?? '';

    final user = FirebaseAuth.instance.currentUser;

    return MouseRegion(
      cursor: isAvailable
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Opacity(
                        opacity: isAvailable ? 1.0 : 0.4,
                        child: Hero(
                          tag: "${item['name']}_grid_${item['id']}",
                          child: buildImage(item['image']!),
                        ),
                      ),
                    ),
                  ),

                  if (!isAvailable)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          "SOLD OUT",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                  if (isAvailable && isOffer)
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "OFFER",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: InkWell(
                      onTap: isAvailable
                          ? () => _showCustomizeModal(item)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.white : Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(Icons.add, color: _bgBlack, size: 20),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 15,
                    right: 15,
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
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: liked ? _accentPink : Colors.white70,
                                  size: 18,
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
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isAvailable ? Colors.white : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['desc']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (isAvailable && isOffer)
                    Row(
                      children: [
                        Text(
                          item['price']!,
                          style: GoogleFonts.montserrat(
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Rs $offerPrice",
                          style: GoogleFonts.montserrat(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      item['price']!,
                      style: GoogleFonts.montserrat(
                        color: _accentPink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        shadows: [
                          Shadow(
                            color: _accentPink.withOpacity(0.5),
                            blurRadius: 10,
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
          else if (value == 'cupcakes')
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Cupcakepage()),
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
                          MaterialPageRoute(builder: (context) => Loginpage2()),
                        );
                        if (mounted) setState(() => _isLoginPromptOpen = false);
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
  }
}
