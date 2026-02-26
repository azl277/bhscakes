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

import 'dart:async'; // 🟢 REQUIRED for StreamSubscription
import 'package:firebase_database/firebase_database.dart'; // REQUIRED for DatabaseEvent
import 'package:project/customisepage.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'Loginpage2.dart'; 
import 'cartpage1.dart';
import 'cupcakepage.dart';
import 'popsiclepage.dart';

List<Map<String, dynamic>> cartList = [];

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
  
  final VoidCallback onCartUpdated; // callback to update the badge

  const AddOnCard({
    super.key,
    required this.item,
    required this.onCartUpdated,
  });

  @override
  State<AddOnCard> createState() => _AddOnCardState();
}


class _AddOnCardState extends State<AddOnCard> {
  final Color _accentPink = const Color(0xFFFF2E74);
  
  // Calculate quantity based on how many times this item appears in the global cartList
  int get quantity => cartList.where((e) => e['name'] == widget.item['name']).length;

  Future<void> _updateQuantity(int delta) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Show login dialog (reuse the one from Cakepage if accessible, or show simple alert)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login first"))
      );
      return;
    }

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');

    try {
      if (delta > 0) {
        // --- ADD ITEM ---
        if (quantity < 10) { // Limit max add-ons if needed
          // Clean price string to int
          int priceInt = int.tryParse(widget.item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
        // --- REMOVE ITEM ---
        if (quantity > 0) {
          // Find the LAST entry of this item to remove (LIFO)
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
      
      // Trigger parent update
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Image Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                // Assuming `buildImage` is globally accessible or passed down
                // If buildImage is inside _CakepageState, you might need to copy it here or make it static
                child: Image.asset(widget.item['image']!, fit: BoxFit.contain), 
              ),
            ),
          ),
          
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Text(
                  widget.item['name']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.item['price']!,
                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w700, color: _accentPink),
                ),
                const SizedBox(height: 8),
                
                // Add/Remove Controls
                if (quantity == 0)
                  InkWell(
                    onTap: () => _updateQuantity(1),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accentPink.withOpacity(0.5))
                      ),
                      child: Center(
                        child: Text("ADD", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
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
                          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.remove, size: 14, color: Colors.white)),
                        ),
                        Text("$quantity", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        InkWell(
                          onTap: () => _updateQuantity(1),
                          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.add, size: 14, color: Colors.white)),
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
class CartBadge extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const CartBadge({super.key, required this.onLoginSuccess});

  @override
  State<CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends State<CartBadge> {

  
  bool _isLoginPromptOpen = false;
  final Color _accentPink = const Color(0xFFFF2E74);
  
  // 🟢 1. Timer variable to handle auto-close
  Timer? _autoCloseTimer;

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  // 🟢 2. Helper function to start/reset the timer
  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel(); // Cancel any existing timer
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
    _autoCloseTimer?.cancel(); // 🟢 3. Clean up timer on dispose
   
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
          
          // 🟢 4. Start timer when opened
          if (_isLoginPromptOpen) {
            _startAutoCloseTimer();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        height: 40,
        width: targetWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _accentPink,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _accentPink.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
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
                      _autoCloseTimer?.cancel(); // Cancel timer if they click login
                      await Navigator.push(context, MaterialPageRoute(builder: (context)=> Loginpage2()));
                      if(mounted) setState(() => _isLoginPromptOpen = false);
                      widget.onLoginSuccess();
                    },
                    child: Text(
                      "Login",
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


  // 🟢 1. Add this variable to manage the listener
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

PageController? _pageController;
  int _currentPage = 0;
  Timer? _timer;
  Timer? _highlightTimer;

Future<void> _scrollToProduct(String productName) async {
  final key = _productKeys[productName];

  if (key != null && key.currentContext != null) {
    // Only perform the scroll
    await Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutQuart,
      alignment: 0.5, 
    );
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not find $productName")),
      );
    }
  }
}
  Widget _buildMetallicButton({
    required String label, 
    required String imagePath, 
    required Color baseColor, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42, // 🟢 Made Smaller (was 50)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25), // Pill shape
          // 🟢 METALLIC GRADIENT EFFECT
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,              // High gloss start
              Colors.grey.shade100,      // Silver mid
              baseColor.withOpacity(0.15), // Tint of color at end
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
          // 🟢 SHINY BORDER
          border: Border.all(
            color: Colors.white, 
            width: 1.5 // Thin shiny rim
          ),
          // 🟢 DEPTH SHADOW
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 5,
              offset: const Offset(-2, -2), // Highlight reflection
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🟢 PNG IMAGE
              Transform.translate(
              offset: const Offset(0, -2),
              child: Image.asset(
                imagePath,
                height: 90, // Small icon size
                width: 90,
                fit: BoxFit.contain,
                errorBuilder: (c, o, s) => Icon(Icons.cake, color: baseColor, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: baseColor.withOpacity(0.8), // Darker text for metallic look
                fontWeight: FontWeight.w700,
                fontSize: 12, // 🟢 Smaller Font
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
      return Transform.scale(
        scale: scale,
        child: child,
        
      );
      
    },
    // child: _buildSliderTag(tag),
    
  );
  
}
// 🟢 REPLACEMENT: Paste this INSIDE _CakepageState class
  void _activateCartListener() {
    final user = FirebaseAuth.instance.currentUser;
    
    // 1. Cancel previous listener to prevent data leaks or duplicates
    _cartSubscription?.cancel(); 

    // 2. If no user, clear cart and stop
    if (user == null) {
      if (mounted) setState(() => cartList.clear());
      return;
    }

    // 3. Listen to the NEW user's cart
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
 
  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    
    // 🟢 3. Add the Scroll Listener
    _scrollController.addListener(_onScroll);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Makes the bar blend into your background
    statusBarIconBrightness: Brightness.light,
    ));
    _activateCartListener();
    _startAutoSlider();
    _initController(false);
    _scrollController.addListener(_onScroll);

    // 🟢 FIX 1: ROBUST QUERIES (Catches 'Cakes', 'cakes', 'Cake', etc.)
    final productRef = FirebaseFirestore.instance.collection('products');

    _categoryStreams['Cakes'] = productRef
        .where('category', whereIn: ['Cakes', 'cakes', 'Cake', 'cake'])
        .snapshots();

    _categoryStreams['birthday'] = productRef
        .where('category', whereIn: ['Birthday', 'birthday', 'Birthday Cake', 'birthday cake'])
        .snapshots();

    _categoryStreams['wedding'] = productRef
        .where('category', whereIn: ['Wedding', 'wedding', 'Wedding Cake', 'wedding cake'])
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
  }

  final List<TextStyle Function({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
})> sliderFonts = [
  GoogleFonts.playfairDisplay,
  GoogleFonts.oswald,
  GoogleFonts.dancingScript,
];

final List<Map<String, String>> valentineMiniProducts = [
  {
    "name": "mini heart cake",
    "price": "Rs 250",
    "image": "assets/heartcake.webp",
    "target": "BLACK FOREST",
    
  },
  {
    "name": "Red rose",
    "price": "Rs 60",
    "image": "assets/redrose.jpg",
    "target": "Cake",
  },
  {
    "name": "Chocolate",
    "price": "Rs 70",
    "image": "assets/chocolate1.webp",
    "target": "CHOCOLATE",
  },
];



final List<Map<String, dynamic>> highlightCakes = [
  
    {
    "name": "Celebrate ",
     "subTitle1": "Valentine's day",
     "subTitle2": "with",
     "subTitle3": "Butter hearts cakes",
       "subTitle4": "redvelvet just 499",
    "desc": "Fresh & Fruity",
    "image": "assets/heart.png",
    "price": "Rs 620",
    "tag": "",
    "font": GoogleFonts.poiretOne,
    "subtitleFont1": GoogleFonts.arizonia,
    "subtitleFont2": GoogleFonts.parisienne,
    "subtitleFont3": GoogleFonts.cookie,  
    "fontSize": 15.0,
    "isValentine": true, // ✅ ADD THIS
    "fontColor": Color.fromARGB(255, 255, 255, 255),
    "gradient": const LinearGradient(
      colors: [ const Color.fromARGB(255, 124, 12, 49),  const Color.fromARGB(255, 124, 12, 49),],
    ),
  },
 
  

];



// Widget _buildSliderTag(String tag) {
//   Color bgColor;

//   switch (tag) {
//     case "":
//       bgColor = Colors.greenAccent;
//       break;
//     case "":
//       bgColor = Colors.orangeAccent;
//       break;
//     case "":
//       bgColor = Colors.redAccent;
//       break;
//     default:
//       bgColor = Colors.white;
//   }

//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//     decoration: BoxDecoration(
//       borderRadius: BorderRadius.circular(20),
//       color: bgColor.withOpacity(0.15),
//       border: Border.all(color: bgColor.withOpacity(0.8)),
//       boxShadow: [
//         BoxShadow(
//           color: bgColor.withOpacity(0.4),
//           blurRadius: 10,
//         ),
//       ],
//     ),
//     child: Text(
//       tag,
//       style: GoogleFonts.inter(
//         fontSize: 11,
//         fontWeight: FontWeight.bold,
//         color: bgColor,
//         letterSpacing: 1,
//       ),
//     ),
//   );
// }

void _initController(bool isMobile) {
    double viewport = isMobile ? 1.0 : 0.6;
    if (_pageController == null) {
      _pageController = PageController(initialPage: 0, viewportFraction: viewport); // 🟢 FIXED
      _currentPage = 0;
    } else if (_pageController!.viewportFraction != viewport) {
      _pageController!.dispose();
      _pageController = PageController(initialPage: _currentPage, viewportFraction: viewport);
    }
  }
void _startAutoSlider() {
    if (highlightCakes.length <= 1) return; // 🟢 FIXED: Stops slider if only 1 card exists

    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_pageController?.hasClients ?? false) {
        _currentPage++;
        _pageController!.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

@override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    
    // 🟢 5. Safely dispose controller
    if (_scrollController.hasClients) {
      _scrollController.removeListener(_onScroll);
    }
    _scrollController.dispose();
    
    super.dispose();
  }

void _onScroll() {
  // If we scroll past 360 pixels (approaching the white section)
  bool shouldBeDark = _scrollController.offset > 360;

  // Only update if the status has changed (prevents lag)
  if (shouldBeDark != _isStatusBarDark) {
    _isStatusBarDark = shouldBeDark;
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // If dark mode (white bg), use Dark Icons. Else use Light Icons.
      statusBarIconBrightness: shouldBeDark ? Brightness.dark : Brightness.light,
    ));
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


// 🟢 MINI HORIZONTAL CATEGORY – ADD ONS

Widget _buildValentineMiniCard(Map<String, String> item) {
  return Container(
    width: 95, 
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 🟢 1. Image (Now Rounded)
        ClipRRect(
          borderRadius: BorderRadius.circular(10), // Curved edges
          child: Image.asset(
            item['image']!,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 4),
        
        // 2. Name
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
        
        // 3. Price
        Text(
          item['price']!,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 6),

        // 4. Button
        GestureDetector(
          onTap: () {
            String target = item['target'] ?? '';
            if (target == 'Cupcake') {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const Cupcakepage()));
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
                )
              ],
            ),
            child: Center(
              child: Text(
                "Order", 
                style: GoogleFonts.inter(
                  fontSize: 9, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
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

  
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: image,
  );
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
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text("Removed from Wishlist", style: GoogleFonts.inter(color: Colors.white)), duration: const Duration(milliseconds: 1000))
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
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: _accentPink, content: Text("Added to Wishlist ❤️", style: GoogleFonts.inter(color: Colors.white)), duration: const Duration(milliseconds: 1000))
      );
    }
  }
}
  void _toggleLike(Map<String, String> item) {
    setState(() {
      final isLiked = wishlist.any((element) => element['name'] == item['name']);
      if (isLiked) {
        wishlist.removeWhere((element) => element['name'] == item['name']);
      } else {
        wishlist.add(item);
      }
    });
  }
// 🟢 REPLACEMENT: Replace your existing _showCustomizeModal with this improved version
// 🟢 REPLACEMENT: Perfect Weight Logic (0.5 -> 3.0) with Dynamic Pricing
void _showCustomizeModal(
  Map<String, String> item,
  Map<String, dynamic> availability,
  Map<String, int> availableFlavours,
) {
  // 1. Build Weight List
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

  // 2. Shapes
  List<String> shapes = [];
  if (availability['round'] != false) shapes.add('Round');
  if (availability['square'] != false) shapes.add('Square');
  if (availability['heart'] != false) shapes.add('Heart');
  if (shapes.isEmpty) shapes.addAll(['Round', 'Square', 'Heart']);

  final TextEditingController cakeWritingController = TextEditingController();

  // Price Parsing
  String priceString = (item['isOffer'] == 'true') ? item['offerPrice']! : item['price']!;
  int basePrice = int.tryParse(priceString.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  // Defaults
  String selectedShape = shapes.first;
  String selectedWeight = sizes.contains("1 Kg") ? "1 Kg" : sizes.first;
  String? selectedFlavourKey = availableFlavours.isNotEmpty ? availableFlavours.keys.first : null;
  int selectedFlavourPrice = availableFlavours.isNotEmpty ? availableFlavours.values.first : 0;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          
          // Price Calculation Logic
          double multiplier = 1.0;
          switch (selectedWeight) {
            case '0.5 Kg': multiplier = 0.5; break;
            case '1 Kg':   multiplier = 1.0; break;
            case '1.5 Kg': multiplier = 1.5; break;
            case '2 Kg':   multiplier = 2.0; break;
            case '2.5 Kg': multiplier = 2.5; break;
            case '3 Kg':   multiplier = 3.0; break;
            default:       multiplier = 1.0;
          }

          int currentPrice = (basePrice * multiplier).toInt() + selectedFlavourPrice;
          if (selectedShape == "Heart") currentPrice += 50; 

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85, // Slightly taller
              decoration: const BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(35))
              ),
              child: Column(
                children: [
                  // --- Drag Handle ---
                  const SizedBox(height: 12),
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
                  
                  // --- Scrollable Content ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header (Image & Name & Price)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15), 
                                child: SizedBox(height: 100, width: 100, child: buildImage(item['image']!))
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name']!, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 177, 25, 25),height: 1.1,)),
                                    const SizedBox(height: 8),
                                    Text("Rs $currentPrice", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: _accentPink)),
                                    const SizedBox(height: 8),
                                    // Status tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                      child: Text("In Stock", style: GoogleFonts.inter(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),

                          // 🟢 2. DESCRIPTION SECTION (Added Here)
                          if (item['desc'] != null && item['desc']!.isNotEmpty) ...[
                            Text(
                              "DESCRIPTION", 
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['desc']!,
                              style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Divider(),
                          const SizedBox(height: 20),

                          // 3. Shape Selection
                          Text("Select Shape", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16,color: Colors.black)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12, runSpacing: 12,
                            children: shapes.map((shape) {
                              bool isSelected = selectedShape == shape;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedShape = shape),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _accentPink : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? _accentPink : Colors.grey.shade300),
                                   
                                  ),
                                  child: Text(shape, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 25),

                          // 4. Weight Selection
                          Text("Select Weight", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16,color: Colors.black)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12, runSpacing: 12,
                            children: sizes.map((weight) {
                              bool isSelected = selectedWeight == weight;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedWeight = weight),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _accentPink : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? _accentPink : Colors.grey.shade300),
                                    
                                  ),
                                  child: Text(weight, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 25),

                          // 5. Flavor Selection
                          if (availableFlavours.isNotEmpty) ...[
                            Text("Select Flavor", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16,color: _accentPink)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: availableFlavours.entries.map((entry) {
                                bool isSelected = selectedFlavourKey == entry.key;
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    selectedFlavourKey = entry.key;
                                    selectedFlavourPrice = entry.value;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.black : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? Colors.black : Colors.transparent),
                                    ),
                                    child: Text(
                                      "${entry.key} ${entry.value > 0 ? '(+₹${entry.value})' : ''}",
                                      style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 25),
                          ],

                          // 6. Message Field
                          Text("Message on Cake", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16,color: Colors.black)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: cakeWritingController,
                            maxLength: 30,
                            decoration: InputDecoration(
                              hintText: "Happy Birthday Name...",
                              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _accentPink, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 80), 
                        ],
                      ),
                    ),
                  ),

                  // --- Bottom Action Bar ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05), offset: const Offset(0, -5))]
                    ),
                    child: SizedBox(
                      width: double.infinity, 
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentPink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
                        ),
                        onPressed: () {
                          Navigator.pop(context); 
                          
                          Map<String, int> flavors = {};
                          if(selectedFlavourKey != null) flavors[selectedFlavourKey!] = selectedFlavourPrice;

                          _addToCartWithDetails(
                            item, 
                            selectedShape, 
                            selectedWeight, 
                            currentPrice, 
                            flavors, 
                            cakeWritingController.text
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                            const SizedBox(width: 10),
                            Text("ADD TO CART  •  ₹$currentPrice", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  )
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
            height: 200, // Adjusted height for the cards
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

                // 🟢 USE THE NEW WIDGET HERE
                return AddOnCard(
                  item: addonItem,
                  onCartUpdated: () {
                    setState(() {}); // Refresh Cakepage to update Badge count
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
        border: Border.all(color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.05)),
        boxShadow: [BoxShadow(color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color:  const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3), borderRadius: BorderRadius.circular(15)),
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
                  style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  item['price']!,
                  style: GoogleFonts.montserrat(color: _accentPink, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 // 🟢 REPLACEMENT: Save to Firebase Firestore
 // 🟢 REPLACEMENT: Robust Save to Firebase with Debugging
 // 🟢 FIXED: Save to Realtime Database (Not Firestore)
 // 🟢 LOCAL ONLY: No Database required
void _addToCartWithDetails(Map<String, String> item, String shape, String weight, int price, Map<String, int> finalFlavourMap, String writing) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Loginpage2()));
    return;
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String currentSavedAddress = prefs.getString('userAddress') ?? "No Address Selected";

  // 🟢 FIXED: Encode the Map to JSON so CartPage and PaymentPage parse it perfectly for the Admin!
  Map<String, dynamic> cartItem = {
    'name': item['name'],
    'image': item['image'],
    'selected_shape': shape,
    'selected_weight': weight,
    'price': price,
    'display_price': "Rs $price", 
    'quantity': 1,
    'flavours': jsonEncode(finalFlavourMap), // 👈 This is the fix.
    'cakeWriting': writing.isEmpty ? "No Message" : writing,
    'delivery_address': currentSavedAddress, 
    'category': 'Cake',
    'added_at': ServerValue.timestamp,
  };

  try {
    DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
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
                        "${item['name']} ($weight)",
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
Widget _buildMiniCategorySection(String title, String category, {required GlobalKey<State<StatefulWidget>> key}) {
  final stream = _categoryStreams[category] ?? 
      FirebaseFirestore.instance.collection('products').where('category', isEqualTo: category).snapshots();

  return StreamBuilder<QuerySnapshot>(
    stream: stream, 
    builder: (context, snapshot) {
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
              style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 0, 0)),
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

                // 🟢 PASSED CATEGORY HERE
                final item = {
                  'name': name,
                  'price': data['price']?.toString() ?? 'Rs 0',
                  'image': data['image']?.toString() ?? '',
                  'category': data['category']?.toString() ?? 'AddOn', 
                };

                return _buildMiniAddOnCard(
                  item,
                  itemKey: _productKeys[name], 
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

Widget _buildMiniAddOnCard(Map<String, String> item, {GlobalKey? itemKey}) {
  return Container(
    key: itemKey,
    width: 140,
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 49, 0, 0), // Dark background
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
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
                style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const SizedBox(height: 4),
              Text(
                item['price'] ?? 'Rs 0', 
                style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: _accentPink)
              ),
              const SizedBox(height: 10),

              // 🟢 TRIGGERS THE NEW ADD-ON MODAL
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
                        color: _accentPink
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
// 🟢 NEW: Simplified Modal just for Add-ons (Quantity Only)
  void _showAddOnModal(Map<String, String> item) {
    int quantity = 1;
    int basePrice = int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int currentPrice = basePrice * quantity;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 380,
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35))
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header (Image & Name)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15), 
                                  child: SizedBox(height: 100, width: 100, child: buildImage(item['image'] ?? ''))
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? '', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 177, 25, 25), height: 1.1)),
                                      const SizedBox(height: 8),
                                      Text("Rs $basePrice", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700, color: _accentPink)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            
                            // Quantity Selector
                            Text("Select Quantity", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                            const SizedBox(height: 15),
                            
                            Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300)
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.black87),
                                    onPressed: () {
                                      if (quantity > 1) setModalState(() => quantity--);
                                    },
                                  ),
                                  Text("$quantity", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Colors.black87),
                                    onPressed: () {
                                      if (quantity < 50) setModalState(() => quantity++);
                                    },
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    // Add To Cart Button
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05), offset: const Offset(0, -5))]
                      ),
                      child: SizedBox(
                        width: double.infinity, 
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
                          ),
                          onPressed: () {
                            Navigator.pop(context); 
                            _addAddonToCart(item, quantity, currentPrice);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                              const SizedBox(width: 10),
                              Text("ADD TO CART  •  ₹$currentPrice", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // 🟢 NEW: Handles adding the exact quantity to Firebase without Cake properties
  Future<void> _addAddonToCart(Map<String, String> item, int quantity, int totalPrice) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress = prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': totalPrice, 
      'display_price': "Rs $totalPrice",
      'quantity': quantity,
      'category': item['category'] ?? 'AddOn', // Correctly tags it
      'delivery_address': currentSavedAddress,
      'added_at': ServerValue.timestamp,
      // No shape, weight, flavour, or message needed!
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
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
                          "${item['name']} (Qty: $quantity)",
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
      debugPrint("Error adding addon: $e");
    }
  }
Future<void> _addToCartSimple(Map<String, String> item) async {
  final user = FirebaseAuth.instance.currentUser;

  // 1. Check Login
  if (user == null) {
    _showLoginRequiredDialog(); // Reuse your existing dialog logic
    return;
  }

  // 2. Parse Price (Remove 'Rs ' and convert to Integer)
  int priceInt = int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  // 3. Prepare Data
  Map<String, dynamic> cartItem = {
    'name': item['name'],
    'image': item['image'],
    'price': priceInt, // Store as int for calculations in CartPage
    'display_price': item['price'],
    'quantity': 1, 
    'category': 'AddOn',
    'added_at': ServerValue.timestamp,
  };

  try {
    // 4. Write to Firebase
    DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
    await dbRef.push().set(cartItem);

    // 5. Success Feedback
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
                    // 🟢 1. IGNORE HORIZONTAL SCROLLS
                    // If the scroll is horizontal (like Add Ons or Slider), do nothing.
                    if (notification.metrics.axis == Axis.horizontal) return false;

                    // 🟢 2. Vertical Scroll Logic
                    if (notification.direction == ScrollDirection.reverse) {
                      // Scrolling Down -> Hide
                      if (_showAppBar.value) _showAppBar.value = false;
                    } else if (notification.direction == ScrollDirection.forward) {
                      // Scrolling Up -> Show
                      if (!_showAppBar.value) _showAppBar.value = true;
                    }
                    return true; 
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: isMobile
                        ? const BouncingScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: Stack( 
                      children: [
                        // 1. TOP RED BACKGROUND
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 480, 
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 124, 12, 49),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20), 
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                          ),
                        ),

                        // 2. BOTTOM LIGHT PINK BACKGROUND (Curved Top)
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.only(top: 460), 
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 148, 184).withOpacity(0), 
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20), 
                                topRight: Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, -10),
                                )
                              ],
                            ),
                          ),
                        ),

                        // 3. SCROLLABLE CONTENT
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 100), 
                            _buildHighlightSlider(isMobile),
                            
                            const SizedBox(height: 30), 
                            _buildMiniCategorySection("Add Ons", "addons", key: _addOnsKey),
                            
                            const SizedBox(height: 20),
                            _buildCategorySection("Cakes", "Cakes", key: _cakesKey),
                            _buildCategorySection("Birthday Cakes", "birthday", key: _birthdayKey),
                            _buildCategorySection("Wedding Cakes", "wedding", key: _weddingKey),
                            
                            const SizedBox(height: 100), 
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // 4. FLOATING APP BAR
            Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _showAppBar,
                builder: (_, visible, __) {
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
Widget _buildCategorySection(String title, String category, {GlobalKey? key}) {
  Stream<QuerySnapshot> stream;
  if (_categoryStreams.containsKey(category)) {
    stream = _categoryStreams[category]!;
  } else {
    stream = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: category)
        .snapshots();
  }

  return StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const SizedBox.shrink();
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF2E74))),
        );
      }
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

      final products = snapshot.data!.docs;
      
      // 🟢 UI FIX: Dynamic Grid Count based on width
      final double width = MediaQuery.of(context).size.width;
      final int crossAxisCount = width < 600 ? 2 : 4; 

      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
            child: Row(
              children: [
                Container(
                  height: 20, width: 4,
                  decoration: BoxDecoration(
                    color: _accentPink,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20, // Slightly smaller for compactness
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), // Reduced outer padding
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12, // 🟢 Tighter spacing
                crossAxisSpacing: 12,
                // 🟢 OPTIMIZED RATIO: 0.72 fits image + text perfectly on mobile
                childAspectRatio: 0.72, 
              ),
              itemBuilder: (context, index) {
                final doc = products[index];
                final data = doc.data() as Map<String, dynamic>;
                final String name = data['name']?.toString() ?? 'Unknown';

                final Map<String, dynamic> rawFlavours =
                    data['flavours'] is Map ? data['flavours'] as Map<String, dynamic> : {};
                final Map<String, int> flavours = rawFlavours.map(
                    (key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0));
                
                final Map<String, dynamic> availability = 
                    data['availability'] is Map ? data['availability'] as Map<String, dynamic> : {};

                if (name.isNotEmpty && !_productKeys.containsKey(name)) {
                  _productKeys[name] = GlobalKey();
                }

           // 🟢 LOOK FOR THIS BLOCK IN CAKEPAGE.DART (Around line 520)
                final Map<String, String> cakeItem = {
                  'id': doc.id,
                  'name': name,
                  'category': data['category']?.toString() ?? 'Cake',
                  'image': data['image']?.toString() ?? '',
                  'price': data['price']?.toString() ?? 'Rs 0',
                  
                  // 🚨 THE ULTIMATE CATCH-ALL FIX:
                  // Replace "YOUR_EXACT_FIREBASE_WORD" if you found a different word in Step 1!
                  'desc': data['desc']?.toString() ?? 
                          data['description']?.toString() ?? 
                          data['details']?.toString() ?? 
                          data['info']?.toString() ?? 
                          data['subtitle']?.toString() ?? 
                          'No description found in database', // Temporary text so we know if it fails
                  
                  'isAvailable': (data['isAvailable'] ?? true).toString(),
                  'isOffer': (data['isOffer'] ?? false).toString(),
                  'offerPrice': data['offerPrice']?.toString() ?? '',
                };
                
                // 🐛 DEBUG PRINT: This will print the data to your terminal so you can see it!
                debugPrint("CAKE ADDED: ${cakeItem['name']} | DESC: ${cakeItem['desc']}");
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
 Widget _buildHighlightSlider(bool isMobile) {
    final Size size = MediaQuery.of(context).size;
    final double sliderHeight = isMobile ? 370.0 : 450.0;
    
    return SizedBox(
      height: sliderHeight,
      width: size.width,
      child: PageView.builder(
        controller: _pageController,
        itemCount: highlightCakes.length, // 🟢 FIXED: Limit to actual cards
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController!,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController!.position.haveDimensions) {
                value = _pageController!.page! - index;
                value = (1 - (value.abs() * 0.04)).clamp(0.96, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * sliderHeight,
                  width: Curves.easeOut.transform(value) * size.width,
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
 Widget _buildSliderCard(Map<String, dynamic> item) {
  final font = (item['font'] ?? GoogleFonts.playfairDisplay) as TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color});
  final subtitleFont1 = (item['subtitleFont1'] ?? GoogleFonts.inter) as TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color});
  final subtitleFont2 = (item['subtitleFont2'] ?? GoogleFonts.inter) as TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color});
  final subtitleFont3 = (item['subtitleFont3'] ?? GoogleFonts.inter) as TextStyle Function({double? fontSize, FontWeight? fontWeight, Color? color});
  final bool isValentine = item['isValentine'] == true;

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: isValentine
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromARGB(255, 124, 12, 49), Color.fromARGB(255, 124, 12, 49), Color.fromARGB(255, 124, 12, 49)])
            : (item['gradient'] as LinearGradient?) ?? const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF111111)]),
      
        border: Border.all(color: const Color.fromARGB(255, 124, 12, 49), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),  
        child: Stack(
          children: [
            if (item['tag'] != null && item['tag'].toString().isNotEmpty)
              Positioned(top: 18.0, left: 18.0, child: _buildPulsingTag(item['tag'].toString())),
            
            if (isValentine)
              Positioned(
                bottom: 15.0, 
                left: 0.0, 
                right: 0.0,
                child: SizedBox(
                  height: 135.0, 
                  child: ListView( 
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: valentineMiniProducts.map((item) {
                       return Padding(
                         padding: const EdgeInsets.only(right: 10.0), 
                         child: _buildValentineMiniCard(item)
                       );
                    }).toList(),
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10.0),
                        isValentine
                            ? Transform.translate(
                                offset: const Offset(55.0, -65.0),
                                child: Text(item['name'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: font(fontSize: item['fontSize'] ?? 10.0, fontWeight: FontWeight.bold, color: item['fontColor'] ?? Colors.white)),
                              )
                            : Text(item['name'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: font(fontSize: item['fontSize'] ?? 15.0, fontWeight: FontWeight.bold, color: item['fontColor'] ?? Colors.white)),
                        
                        if (item['subTitle1'] != null)
                          Transform.translate(offset: isValentine ? const Offset(20, -75) : Offset.zero, child: Text(item['subTitle1'], style: subtitleFont1(fontSize: 21.0, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(1)))),
                        
                        const SizedBox(height: 0.0),
                        if (item['subTitle2'] != null)
                          Transform.translate(offset: isValentine ? const Offset(85, -80) : Offset.zero, child: Text(item['subTitle2'], style: subtitleFont2(fontSize: 20.0, fontWeight: FontWeight.w500, color: Colors.white70))),
                        
                        if (item['subTitle3'] != null)
                          Transform.translate(offset: isValentine ? const Offset(-5, -100) : Offset.zero, child: Text(item['subTitle3'], style: subtitleFont3(fontSize: 29.0, fontWeight: FontWeight.w500, color: Colors.white))),
                        
                        const SizedBox(height: 25.0),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: isValentine ? const EdgeInsets.fromLTRB(10, 0, 20, 200) : const EdgeInsets.all(12.0),
                    child: Hero(
                      tag: "${item['name']}_slider", 
                      // 🟢 WRAPPED IMAGE IN CLIPRRECT
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0), 
                        child: Image.asset(item['image'] ?? '', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.cake, size: 40.0, color: Colors.white24))
                      ),
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
Widget _buildCompactCakeCard(
  Map<String, String> item,
  Map<String, dynamic> availability,
  Map<String, int> flavours, {
  GlobalKey? itemKey,
}) {
  // 🟢 Parse availability and offer status
  bool isAvailable = item['isAvailable'] != 'false';
  bool isOffer = item['isOffer'] == 'true';
  String offerPrice = item['offerPrice'] ?? '';
  
  final user = FirebaseAuth.instance.currentUser;

  return MouseRegion(
    // Change cursor if sold out
    cursor: isAvailable ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
    child: GestureDetector(
      // Disable tap if sold out
      onTap: isAvailable ? () => _showCustomizeModal(item, availability, flavours) : null,
      child: Container(
        key: itemKey,
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
            // ----------------------------------------
            // 1️⃣ IMAGE SECTION (With Tags & Greyscale)
            // ----------------------------------------
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
                      opacity: isAvailable ? 1.0 : 0.6, // Dim if sold out
                      child: Hero(
                        tag: "${item['name']}_grid_${item['id']}",
                        // 🟢 GREYSCALE FILTER FOR SOLD OUT
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

                  // 🔴 SOLD OUT OVERLAY
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

                  // 🟢 OFFER BADGE (Top Left)
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
                  
                  // 🟢 WISHLIST HEART BUTTON (Top Right)
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
            
            // ----------------------------------------
            // 2️⃣ DETAILS SECTION (Pricing & Name)
            // ----------------------------------------
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
                    item['desc'] ?? "Delicious cake", 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 🟢 PRICING LOGIC
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isOffer && isAvailable) ...[
                              // Old Price Strikethrough
                              Text(
                                item['price']!, 
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey.shade400, 
                                  fontSize: 10, 
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w600
                                )
                              ),
                              // New Offer Price
                              Text(
                                "Rs $offerPrice", 
                                style: GoogleFonts.montserrat(
                                  color: Colors.green.shade600, 
                                  fontWeight: FontWeight.w800, 
                                  fontSize: 14
                                )
                              ),
                            ] else ...[
                              // Standard Price
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
                      
                      // 🟢 ADD BUTTON (Greyed out if sold out)
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
Widget _buildElegantGlassAppBar(bool isMobile) {
  // 🟢 Mobile Sizing Constants
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
                        // --- LEFT: CLICKABLE LOGO ---
                        Expanded( 
                          child: GestureDetector( // 🟢 1. Made Clickable
                            onTap: () {
                              // Navigate to Home
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // SizedBox(width: 12), // Uncomment if you want left padding inside the bar
                                
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

                        // --- RIGHT: BUTTONS (Home button removed) ---
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🟢 2. Home Button Removed Here
                            
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
// --- HELPER 1: Updated Glass Action Button ---
Widget _buildGlassActionButton({
  required IconData icon, 
  required VoidCallback onTap, 
  double size = 40.0 // 🟢 Added size parameter
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
        child: Icon(icon, color: Colors.white, size: size * 0.5), // Icon scales with button
      ),
    ),
  );
}

// --- HELPER 2: Updated Glass Menu Dropdown ---
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
        // The Trigger Button
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
        // Menu Items
        onSelected: (value) {
          if (value == 'cupcakes') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const Cupcakepage()));
          } 
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'cupcakes',
            child: Row(
              children: [
                const Icon(Icons.cake, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Cupcakes', style: GoogleFonts.inter(color: Colors.white))
              ],
            ),
          ),
      
        ],
      ),
    );
  }
Widget _buildCartBadge() {
  // Determine target width
  // If not logged in & open: 130.0 (Safe width for text)
  // If logged in & has items: 75.0
  // Default (Icon only): 52.0
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
      }
    },
    // 🟢 LAG FIX: Static Container holds the shadow so it doesn't repaint every frame
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
      // The actual animating part
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
        // 🟢 OVERFLOW FIX: ScrollView swallows the overflow error during animation
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(), // User can't scroll it manually
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),

              // Logged In: Item Count
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

              // Not Logged In: Login Button
              if (!isLoggedIn && _isLoginPromptOpen) ...[
                const SizedBox(width: 8),
                // Text fades in
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isLoginPromptOpen ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context)=> Loginpage2()));
                      if(mounted) {
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
              ]
            ],
          ),
        ),
      ),
    ),
  );
}
  // Helper for Desktop Nav Links
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

  // Helper for Glass Buttons
  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap}) {
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

  // Enhanced Cart Badge
 

  Widget _buildProductDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45), color: const Color.fromARGB(88, 153, 153, 153), elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      onSelected: (value) {
        if (value == 'Cupcake') Navigator.push(context, MaterialPageRoute(builder: (_) => const Cupcakepage()));
        else if (value == 'popsicle') Navigator.push(context, MaterialPageRoute(builder: (_) => const Popsiclepage()));
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'Cupcake', child: Row(children: [Icon(Icons.cake, color: _accentPink, size: 20), const SizedBox(width: 12), Text('Cakes', style: GoogleFonts.inter(color: Colors.white))])),
        PopupMenuItem(value: 'popsicle', child: Row(children: [const Icon(Icons.icecream, color: Colors.white, size: 20), const SizedBox(width: 12), Text('Popsicles', style: GoogleFonts.inter(color: Colors.white))])),
      ],
            child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
      ),
    );
  }
// 🟢 2. Add this function to Sync Cart with Firebase
 
// 🟢 1. Toggle Wishlist Logic for Realtime Database
// 🟢 1. Toggle Wishlist Logic for Realtime Database
Future<void> _toggleRealtimeWishlist(Map<String, String> item) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    _showLoginRequiredDialog();
    return;
  }

  // Path: users/uid/wishlist
  final DatabaseReference wishlistRef = FirebaseDatabase.instance
      .ref()
      .child('users/${user.uid}/wishlist');

  try {
    // Check if item already exists in wishlist
    final snapshot = await wishlistRef
        .orderByChild('name')
        .equalTo(item['name'])
        .get();

    if (snapshot.exists) {
      // REMOVE: If it exists, find the key and delete it
      Map<dynamic, dynamic> data = snapshot.value as Map;
      String keyToDelete = data.keys.first;
      await wishlistRef.child(keyToDelete).remove();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from Wishlist"), backgroundColor: Colors.black87)
        );
      }
    } else {
      // 🟢 THE FIX: ADD DESC TO FIREBASE PUSH
    await wishlistRef.push().set({
        'name': item['name'],
        'image': item['image'],
        'price': item['price'],
        'desc': item['desc'], // 🟢 NO FAKE TEXT HERE EITHER
        'added_at': ServerValue.timestamp,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Added to Wishlist ❤️"), backgroundColor: _accentPink)
        );
      }
    }
    setState(() {}); // Refresh UI to update heart color
  } catch (e) {
    debugPrint("Wishlist Error: $e");
  }
}

// 🟢 2. Helper to check if item is in wishlist (for UI color)
bool _isInWishlist(String productName) {
  // This assumes you might want to sync a local list or just check Realtime DB.
  // For instant UI feedback, we check the global cartList or a similar local sync.
  // Alternatively, use a StreamBuilder in the card (see step 2).
  return wishlist.any((element) => element['name'] == productName);
}

}

