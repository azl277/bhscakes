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

// --- PAGE IMPORTS ---
import 'package:project/cakepage.dart'; 
import 'package:project/cartpage1.dart';
import 'package:project/Loginpage2.dart';


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
  final MenuController _menuController = MenuController();
  Timer? _menuTimer;

  // 🟢 App Bar & Status Bar State (Synced with Cakepage)
  final ValueNotifier<bool> _showAppBar = ValueNotifier(true);
  final ValueNotifier<bool> _showShadow = ValueNotifier(false);
  bool _isStatusBarDark = false;
  
  Stream<QuerySnapshot>? _cupcakesStream;
  StreamSubscription<DatabaseEvent>? _cartSubscription;

  Widget _buildTopBackground() {
    return Container(
      height: 420, 
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7C0C31),
            Color(0xFF7C0C31), 
            Color(0xFF7C0C31),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
    );
  }
  
  PageController? _pageController;
  int _currentPage = 0;
  Timer? _timer;
  
  late ScrollController _scrollController;
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _bgBlack = const Color(0xFF050505);

  final List<Map<String, String>> highlightCakes = [
    {"name": "Cupcakes", "image": "assets/cupcake1.png"},
  ];

  @override
  void initState() {
    super.initState();
    _cupcakesStream = FirebaseFirestore.instance.collection('cupcakes').snapshots();
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // 🟢 INITIALIZE STATUS BAR (Transparent with Light Icons)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _activateCartListener(); 
    _startAutoSlider();
  }

  // 🟢 EXACT CAKEPAGE SCROLL LISTENER
  void _onScroll() {
    // 1. Shadow logic
    if (_scrollController.offset > 300) {
      if (!_showShadow.value) _showShadow.value = true;
    } else {
      if (_showShadow.value) _showShadow.value = false;
    }

    // 2. Status Bar logic (Transitions to dark icons when scrolling into the white area)
    bool shouldBeDark = _scrollController.offset > 360;
    if (shouldBeDark != _isStatusBarDark) {
      _isStatusBarDark = shouldBeDark;
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: shouldBeDark ? Brightness.dark : Brightness.light,
      ));
    }
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

  void _initController(bool isMobile) {
    double viewport = isMobile ? 0.85 : 0.5;
    if (_pageController == null || _pageController!.viewportFraction != viewport) {
      _pageController?.dispose();
      _pageController = PageController(initialPage: 0, viewportFraction: viewport);
    }
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < highlightCakes.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController != null && _pageController!.hasClients) {
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
    if (_scrollController.hasClients) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    _cartSubscription?.cancel(); 
    _showAppBar.dispose();
    _showShadow.dispose();
    super.dispose();
  }

  Widget buildImage(String imageString) {
    try {
      if (imageString.startsWith('assets/')) {
        return Image.asset(imageString, fit: BoxFit.cover);
      } else if (imageString.startsWith('http')) {
        return Image.network(imageString, fit: BoxFit.cover, cacheWidth: 300); 
      } else {
        return Image.memory(
          base64Decode(imageString),
          fit: BoxFit.cover,
          cacheWidth: 300, 
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24),
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
        title: Text("Login Required", style: GoogleFonts.playfairDisplay(color: Colors.white)),
        content: Text("Please login to add items to your cart.", style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentPink),
            onPressed: () async {
               Navigator.pop(context); 
               await Navigator.push(context, MaterialPageRoute(builder: (context)=> Loginpage2()));
               if(mounted) setState((){}); 
            }, 
            child: const Text("Login", style: TextStyle(color: Colors.white)),
          )
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
    final DatabaseReference wishlistRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/wishlist');
    try {
      final snapshot = await wishlistRef.orderByChild('name').equalTo(item['name']).get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map;
        String keyToDelete = data.keys.first;
        await wishlistRef.child(keyToDelete).remove();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed from Wishlist"), backgroundColor: Colors.black87));
      } else {
        await wishlistRef.push().set({
          'name': item['name'],
          'image': item['image'],
          'price': item['price'],
          'added_at': ServerValue.timestamp,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Added to Wishlist ❤️"), backgroundColor: Color(0xFFFF2E74)));
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
        String selectedPack = "3 Pc"; 
        int basePrice = int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int currentPrice = basePrice; 

        return StatefulBuilder(
          builder: (context, setModalState) {
            int calculatePrice(String pack) {
              double multiplier = 1.0;
              if (pack == "6 Pc") multiplier = 2.0;
              if (pack == "12 Pc") multiplier = 4.0;
              return (basePrice * multiplier).toInt();
            }

            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width > 600 ? 500 : double.infinity,
                height: 480,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(30)),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            color: Colors.black38,
                            height: 80, width: 80,
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
                                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 5),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  "Rs $currentPrice",
                                  key: ValueKey(currentPrice),
                                  style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700, color: _accentPink),
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

                    Text("Select Pack Quantity", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: ["3 Pc", "6 Pc", "12 Pc"].map((pack) {
                        bool isSelected = selectedPack == pack;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedPack = pack;
                              currentPrice = calculatePrice(pack);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _accentPink : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? _accentPink : Colors.white24
                              ),
                            ),
                            child: Text(
                              pack,
                              style: GoogleFonts.inter(
                                color: isSelected ? Colors.white : Colors.white60,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentPink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 10,
                        ),
                        onPressed: () {
                          _addToCartWithDetails(item, selectedPack, "Rs $currentPrice");
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Add to Cart - Rs $currentPrice",
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _addToCartWithDetails(Map<String, String> item, String quantity, String finalPrice) async {
    if(!isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress = prefs.getString('userAddress') ?? "No Address Selected";

    int priceInt = int.tryParse(finalPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
      'category': 'Cupcake',
      'category': item['category'] ?? 'Cake',
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user!.uid}/cart');
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
                   BoxShadow(color: _accentPink.withOpacity(0.2), blurRadius: 15, spreadRadius: -2)
                ]
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
                        Text("Added to Basket", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(
                          "${item['name']} ($quantity)",
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
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
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      extendBodyBehindAppBar: false, // 🟢 MATCHES CAKEPAGE
      body: ScrollConfiguration(
        behavior: DesktopScrollBehavior(),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              // 🟢 CRITICAL: top: false allows background to go UNDER the status bar!
              child: SafeArea(
                top: false, 
                bottom: false,
                child: NotificationListener<UserScrollNotification>(
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
                    physics: isMobile ? const BouncingScrollPhysics() : const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            _buildTopBackground(),
                            Padding(
                              // Ensure content doesn't collide with the notch
                              padding: EdgeInsets.only(top: isMobile ? 110 : 130), 
                              child: _buildHighlightSlider(isMobile),
                            ),
                          ],
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 30)),

                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Cupcakes Menu",
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color.fromARGB(255, 255, 18, 77),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 25)),

                      SliverToBoxAdapter(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _cupcakesStream,
                          builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
                            if (streamSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: CircularProgressIndicator(color: Colors.pink)
                                )
                              );
                            }
                            if (!streamSnapshot.hasData || streamSnapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: Text("No cupcakes available", style: TextStyle(color: Colors.grey))
                                )
                              );
                            }

                            final cakesData = streamSnapshot.data!.docs;
                            
                            int crossAxisCount = isMobile ? 2 : 4; 

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true, 
                                physics: const NeverScrollableScrollPhysics(), 
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: cakesData.length,
                                itemBuilder: (context, index) {
                                  Map<String, dynamic> data = cakesData[index].data() as Map<String, dynamic>;
                                  
                               Map<String, String> cakeItem = {
                                    "id": cakesData[index].id,
                                    "name": data['name']?.toString() ?? "Cupcake",
                                    "category": data['category']?.toString() ?? "Cupcake", // 🟢 Passed category from Firebase
                                    "price": data['price']?.toString() ?? "Rs 0",
                                    "desc": data['desc']?.toString() ?? "Tasty",
                                    "image": data['image']?.toString() ?? "",
                                    "isAvailable": (data['isAvailable'] ?? true).toString(),
                                    "isOffer": (data['isOffer'] ?? false).toString(),
                                    "offerPrice": data['offerPrice']?.toString() ?? "",
                                  };

                                  return _buildCompactCakeCard(cakeItem);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🟢 ELEGANT APP BAR (Fully Synced with Cakepage)
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
                }
              ),
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
      cursor: isAvailable ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isAvailable ? () => _showCustomizeModal(item) : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Opacity(
                        opacity: isAvailable ? 1.0 : 0.6, 
                        child: Hero(
                          tag: "${item['name']}_grid_${item['id']}",
                          child: isAvailable 
                            ? buildImage(item['image']!)
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white38, width: 1),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_accentPink, Colors.pinkAccent]),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: _accentPink.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
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
                          ? FirebaseDatabase.instance.ref().child('users/${user.uid}/wishlist').orderByChild('name').equalTo(item['name']).onValue 
                          : null,
                        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                          bool liked = snapshot.hasData && snapshot.data!.snapshot.exists;
                          
                          return GestureDetector(
                            onTap: () => _toggleRealtimeWishlist(item),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                color: liked ? Colors.red : Colors.grey,
                                size: 16,
                              ),
                            ),
                          );
                        }
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
                        color: isAvailable ? Colors.black87 : Colors.grey.shade500
                      )
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['desc'] ?? "Delicious cupcake", 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)
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
                                    fontWeight: FontWeight.w600
                                  )
                                ),
                                Text(
                                  "Rs $offerPrice", 
                                  style: GoogleFonts.montserrat(
                                    color: Colors.green.shade600, 
                                    fontWeight: FontWeight.w800, 
                                    fontSize: 14
                                  )
                                ),
                              ] else ...[
                                Text(
                                  item['price']!, 
                                  style: GoogleFonts.montserrat(
                                    color: isAvailable ? _accentPink : Colors.grey.shade400, 
                                    fontWeight: FontWeight.w800, 
                                    fontSize: 13
                                  )
                                ),
                              ]
                            ],
                          ),
                        ),
                        
                        Container(
                          height: 28, width: 28,
                          decoration: BoxDecoration(
                            color: isAvailable ? _accentPink : Colors.grey.shade300, 
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            isAvailable ? Icons.add : Icons.remove_shopping_cart_rounded, 
                            color: Colors.white, 
                            size: 16
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

  Widget _buildHighlightSlider(bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double sliderHeight = isMobile ? 280 : 340;
    final double cardWidth = isMobile ? screenWidth * 0.85 : screenWidth * 0.45;

    return SizedBox(
      height: sliderHeight,
      width: isMobile ? screenWidth : 1000,
      child: PageView.builder(
        controller: _pageController,
        itemCount: highlightCakes.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController!,
            builder: (context, child) {
              double value = 1.0;

              if (_pageController!.position.haveDimensions) {
                value = (_pageController!.page ?? 0) - index;
                value = (1 - (value.abs() * 0.25)).clamp(0.85, 1.0);
              }

              return Center(
                child: SizedBox(
                  height: sliderHeight * Curves.easeOut.transform(value),
                  width: cardWidth * Curves.easeOut.transform(value),
                  child: child,
                ),
              );
            },
            child: _buildSliderCard(highlightCakes[index]),
          );
        },
      ),
    );
  }

  Widget _buildSliderCard(Map<String, String> item) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(255, 124, 12, 49),Color.fromARGB(255, 124, 12, 49)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.0), blurRadius: 20, offset: const Offset(0, 15))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30), 
          child: Stack(
            children: [
              Positioned(top: -25, left: 0, right: 0, child: Center(child: Opacity(opacity: 0.7, child: Image.asset("assets/strawberry.png", width: 80, height: 80, errorBuilder: (c,e,s)=>const SizedBox())))),
              Positioned(top: 15, left: -40, child: Opacity(opacity: 0.7, child: Image.asset("assets/chocolate.png", width: 130, height: 130, errorBuilder: (c,e,s)=>const SizedBox()))),
              Positioned(bottom: -30, left: 40, child: Opacity(opacity: 0.7, child: Image.asset("assets/whitechocolate.png", width: 100, height: 100, errorBuilder: (c,e,s)=>const SizedBox()))),

              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(70, 20, 0, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 15),
                          Text(
                            item['name']!,
                            style: GoogleFonts.imperialScript(fontSize: 53, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1, shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 15)]),
                          ),
                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Hero(
                        tag: "${item['name']}_slider",
                        child: Image.asset(item['image']!, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.cake, size: 40, color: Colors.white24)),
                      ),
                    ),
                  ),
                ],
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
                        )
                      ]
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
                              Navigator.popUntil(context, (route) => route.isFirst);
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
          child: Icon(Icons.grid_view_rounded, color: Colors.white, size: size * 0.5),
        ),
        onSelected: (value) {
          if (value == 'cakes') Navigator.push(context, MaterialPageRoute(builder: (_) => const Cakepage()));
          
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'cakes',
            child: Row(
              children: [
                const Icon(Icons.cake, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Cakes', style: GoogleFonts.inter(color: Colors.white))
              ],
            ),
          ),
    
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 PERFECTED CART BADGE WIDGET
// ---------------------------------------------------------------------------
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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const Cartpage1()));
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
            )
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
                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),

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
                        await Navigator.push(context, MaterialPageRoute(builder: (context)=> Loginpage2()));
                        if(mounted) setState(() => _isLoginPromptOpen = false);
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
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}