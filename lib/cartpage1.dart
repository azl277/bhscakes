import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Assuming these exist in your project
import 'package:project/cakepage.dart'; 
import 'package:project/paymet.dart'; 
import 'package:project/location.dart'; 

class Cartpage1 extends StatefulWidget {
  final String? initialAddress; 
  const Cartpage1({super.key, this.initialAddress});

  @override
  State<Cartpage1> createState() => _Cartpage1State();
}

class _Cartpage1State extends State<Cartpage1> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 🟢 EXTENDED LOCATION DATA
  String userName = "Guest";
  String userPhone = "";
  String userAddress = "";
  String? receiverName;
  String? receiverPhone;
  String? googleMapsLink;
  double? _selectedLat;
  double? _selectedLng;
  bool isLoadingLocation = false;

  // Scheduling Data
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  // Design Constants
  final Color accentPink = const Color(0xFFFF2E74);
  final double kPadding = 20.0;
  
  Stream<DatabaseEvent>? _cartStream;
  final Map<String, Uint8List> _memoryImageCache = {};

  // --- Coupon Data ---
  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;
  String _couponError = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    if (currentUser != null) {
      _cartStream = FirebaseDatabase.instance
          .ref()
          .child('users/${currentUser!.uid}/cart')
          .onValue;
    }
      
    if (widget.initialAddress != null) {
      userAddress = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- DELETE LOGIC ---
  void _deleteItem(String itemKey) async {
    if (currentUser == null) return;
    HapticFeedback.mediumImpact();
    await FirebaseDatabase.instance
        .ref()
        .child('users/${currentUser!.uid}/cart/$itemKey')
        .remove();
  }

  Future<void> _clearCart() async {
    if (currentUser == null) return;
    await FirebaseDatabase.instance
        .ref()
        .child('users/${currentUser!.uid}/cart')
        .remove();
    setState(() {}); 
  }

  // --- HELPERS ---
  String formatFlavours(dynamic flavoursJson) {
    if (flavoursJson == null || flavoursJson.toString().isEmpty || flavoursJson == "{}" || flavoursJson == "[]") return "";
    try {
      if (flavoursJson is Map) return flavoursJson.keys.join(", ");
      if (flavoursJson is String && flavoursJson.trim().startsWith('{')) {
        final Map<String, dynamic> map = jsonDecode(flavoursJson);
        return map.keys.join(", ");
      }
      return flavoursJson.toString();
    } catch (e) {
      return flavoursJson.toString().replaceAll(RegExp(r'[{}"\]\[]'), '');
    }
  }

  double _getRawDistance() {
    if (_selectedLat == null || _selectedLng == null) return 0.0;
    const double shopLat = 10.216229; // Default 
    const double shopLng = 76.157549;
    return Geolocator.distanceBetween(shopLat, shopLng, _selectedLat!, _selectedLng!) / 1000;
  }

  String _getDistanceKm() {
    double dist = _getRawDistance();
    if (dist == 0) return "";
    return "${dist.toStringAsFixed(1)} km away";
  }

  double _calculateDeliveryFee(double subtotal) {
    if (subtotal >= 500 || _selectedLat == null) return 0.0;
    return _getRawDistance() * 10; 
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      String priceString = item['price'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
      total += double.tryParse(priceString) ?? 0;
    }
    return total;
  }

  Future<void> _loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    String loadedName = prefs.getString('username') ?? "User";

    if (mounted) {
      setState(() {
        userName = user == null ? "Guest" : loadedName;
        userAddress = ""; 
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
          if (mounted) {
            setState(() { 
              userAddress = (data['fullAddress'] ?? ""); 
              _selectedLat = data['latitude'];
              _selectedLng = data['longitude'];
              receiverPhone = data['receiverPhone'];
              receiverName = data['receiverName'];
              googleMapsLink = data['googleMapsLink'];
            });
          }
          foundSavedAddress = true;
        }
      } catch (e) {
        debugPrint("Error fetching address: $e");
      }
    }

    if (!foundSavedAddress && prefs.containsKey('userAddress')) {
      String cachedAddr = prefs.getString('userAddress')!;
      if (cachedAddr.isNotEmpty && cachedAddr != "Select Location" && cachedAddr != "Locating...") {
        if (mounted) {
          setState(() { 
            userAddress = cachedAddr; 
            if (prefs.containsKey('userLat')) {
              _selectedLat = prefs.getDouble('userLat');
              _selectedLng = prefs.getDouble('userLng');
            }
          });
        }
        foundSavedAddress = true;
      }
    }

    if (!foundSavedAddress) {
      if (mounted) {
        setState(() {
          userAddress = ""; 
        });
      }
    }
  }

  Future<void> _determinePosition() async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
            child: CircularProgressIndicator(color: accentPink),
          ),
        ),
      )
    );

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permission denied';
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      double shopLat = 10.216229; 
      double shopLng = 76.157549; 
      double maxRadius = 15000.0; 
      
      try {
        final doc = await FirebaseFirestore.instance.collection('settings').doc('delivery_zone').get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['lat'] != null) shopLat = (data['lat'] as num).toDouble();
          if (data['lng'] != null) shopLng = (data['lng'] as num).toDouble();
          if (data['radius'] != null) maxRadius = (data['radius'] as num).toDouble();
        }
      } catch (e) {
        debugPrint("Failed to fetch radius from Firebase.");
      }

      double distanceInMeters = Geolocator.distanceBetween(shopLat, shopLng, position.latitude, position.longitude);

      if (distanceInMeters > maxRadius) {
        if (mounted) {
          Navigator.pop(context); 
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white, width: 2)),
              title: Row(
                children: [
                  const Icon(Icons.block_flipped, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 10),
                  Text("Out of Zone", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              content: Text(
                "Sorry, your current location is ${(distanceInMeters / 1000).toStringAsFixed(1)} km away. We currently only deliver within ${(maxRadius / 1000).toStringAsFixed(0)} km.",
                style: GoogleFonts.inter(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK", style: GoogleFonts.inter(color: accentPink, fontWeight: FontWeight.bold)),
                )
              ],
            )
          );
        }
        return; 
      }

      String detectedArea = "";
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            List<String> parts = [];
            if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
            if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
            detectedArea = parts.join(", ");
          }
        } catch (e) { print(e); }
      }
      
      if (!mounted) return;
      Navigator.pop(context); 
      _showAddressDetailsEntrySheet(detectedArea, lat: position.latitude, lng: position.longitude);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to get location. Please check your GPS or permissions.")));
      }
    } 
  }

  Future<void> _selectDeliveryDate() async {
    final now = DateTime.now();
    final bool isAfterCutoff = now.hour >= 14;
    final DateTime initialDate = isAfterCutoff 
        ? now.add(const Duration(days: 1)) 
        : now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: accentPink),
            dialogBackgroundColor: Colors.white.withOpacity(0.95),
            
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null; 
      });
      _selectDeliveryTime(picked);
    }
  }

  Future<void> _selectDeliveryTime(DateTime date) async {
    final now = DateTime.now();
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: "SELECT TIME (10 AM - 6 PM)",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: accentPink),
            dialogBackgroundColor: Colors.white.withOpacity(0.95),
            
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.hour < 10 || picked.hour >= 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Delivery available between 10 AM and 6 PM only", style: GoogleFonts.inter(color: Colors.white)), 
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
        return;
      }

      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        final DateTime selectedDateTime = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
        if (selectedDateTime.isBefore(now.add(const Duration(hours: 3)))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please allow at least 3-4 hours for preparation", style: GoogleFonts.inter(color: Colors.white)), 
              backgroundColor: Colors.black87,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
          return;
        }
      }

      setState(() => selectedTime = picked);
    }
  }
Future<void> _applyCoupon(double currentSubtotal) async {
    String code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = "";
    });

    try {
      // 1. Fetch code from Firestore
      var doc = await FirebaseFirestore.instance.collection('coupons').doc(code).get();

      if (!doc.exists) {
        setState(() => _couponError = "Invalid coupon code");
      } else {
        var data = doc.data()!;
        DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
        int minPurchase = data['minPurchase'] ?? 0;
        bool isActive = data['isActive'] ?? false;
        bool isUsed = data['isUsed'] ?? false;

        // 2. Validate status
        if (!isActive || isUsed) {
          setState(() => _couponError = "This coupon is no longer available");
        } 
        // 3. Check Expiry
        else if (DateTime.now().isAfter(expiry)) {
          setState(() => _couponError = "This coupon has expired");
        } 
        // 4. Check Min Purchase
        else if (currentSubtotal < minPurchase) {
          setState(() => _couponError = "Min purchase ₹$minPurchase required");
        } 
        else {
          // Success!
          setState(() {
            _appliedCoupon = data;
            _couponError = "";
          });
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      setState(() => _couponError = "Check your connection");
    } finally {
      setState(() => _isValidatingCoupon = false);
    }
  }
  Widget _buildCouponSection(double subtotal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _couponError.isNotEmpty ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Enter Coupon Code",
                    hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              _isValidatingCoupon
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () => _applyCoupon(subtotal),
                      child: Text("APPLY", style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: accentPink)),
                    ),
            ],
          ),
          if (_couponError.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Text(_couponError, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
          if (_appliedCoupon != null)
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 14),
                const SizedBox(width: 5),
                Text("₹${_appliedCoupon!['discountAmount']} Off Applied!", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                  onPressed: () => setState(() => _appliedCoupon = null),
                )
              ],
            ),
        ],
      ),
    );
  }
  // --- GLASSMORPHISM HELPER ---
  Widget _buildGlassContainer({required Widget child, double radius = 24, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, Border? border}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(radius),
              border: border ?? Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
              ]
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF0F5), 
              Color(0xFFFDE4EC), 
              Color(0xFFFFF3E0)
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: StreamBuilder<DatabaseEvent>(
          stream: _cartStream,
          builder: (context, snapshot) {
            
            // 🟢 SKELETON CHECK
            bool isCartLoading = snapshot.connectionState == ConnectionState.waiting;

            List<Map<String, dynamic>> itemsList = [];
            List<String> itemKeys = [];

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              data.forEach((key, value) {
                itemsList.add(Map<String, dynamic>.from(value));
                itemKeys.add(key.toString());
              });
            }

            return Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),

                    // 🟢 1. SHOW SKELETON CARDS IF LOADING
                    if (isCartLoading)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(kPadding, 20, kPadding, 270), 
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildSkeletonCartCard(),
                            childCount: 4, // Show 4 skeleton items
                          ),
                        ),
                      )

                    // 2. SHOW EMPTY STATE IF NOT LOADING AND EMPTY
                    else if (itemsList.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    
                    // 3. SHOW REAL ITEMS
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(kPadding, 20, kPadding, 270), 
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = itemsList[index];
                              final key = itemKeys[index];
                              return Dismissible(
                                key: Key(key), 
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteItem(key),
                                background: _buildDeleteBackground(),
                                child: _buildCartCard(item, key),
                              );
                            },
                            childCount: itemsList.length,
                          ),
                        ),
                      ),  
                  ],
                ),

                // 🟢 SKELETON CHECKOUT PANEL
                if (isCartLoading)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _buildSkeletonCheckoutPanel(), 
                  )
                else if (itemsList.isNotEmpty)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: _buildCheckoutPanel(itemsList), 
                  ),

                if (isLoadingLocation)
                  _buildLoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🟢 SKELETON WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildSkeletonCartCard() {
    return PulsingSkeleton(
      child: _buildGlassContainer(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake Image
            Container(
              width: 75, height: 75, 
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14), 
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  // Fake Title
                  Container(height: 12, width: 140, decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12.0),
                  // Fake Attribute Pills
                  Wrap(
                    spacing: 4.0, runSpacing: 4.0,
                    children: [
                      Container(height: 20, width: 55, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(6))),
                      Container(height: 20, width: 70, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Fake Price
                  Container(height: 14, width: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
            // Fake Close Button
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCheckoutPanel() {
    return PulsingSkeleton(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 260, // Fixed height approximating the real panel
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake Address/Date block
                  Container(height: 70, width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16))),
                  const SizedBox(height: 20),
                  // Fake Price rows
                  Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Container(height: 14, width: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  // Fake Checkout Button
                  Container(height: 52, width: double.infinity, decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: const Color(0xFFFF4B4B).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.white.withOpacity(0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildGlassContainer(
          radius: 50,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text("BASKET", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 2, color: Colors.black87)),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), 
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.3), width: 1))
            )
          )
        )
      ),
    );
  }

  // 🟢 SMALLER CART CARDS
  Widget _buildCartCard(Map<String, dynamic> item, String itemKey) {
    String flavourText = formatFlavours(item['flavours']);
    String cakeWriting = (item['cakeWriting'] ?? '').toString();
    String weight = (item['selected_weight'] ?? item['weight'] ?? "N/A").toString();
    String shape = (item['selected_shape'] ?? item['shape'] ?? "Standard").toString();

    return _buildGlassContainer(
      margin: const EdgeInsets.only(bottom: 12), // Reduced margin
      padding: const EdgeInsets.all(10), // Reduced padding inside card
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 75, height: 75, // 🟢 Reduced image size from 95x95
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14), 
              color: Colors.white.withOpacity(0.6),
              border: Border.all(color: Colors.white.withOpacity(0.9))
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12), 
              child: buildImage(item['image'] ?? ""),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 2),
                Text(
                  item['name'].toString().toUpperCase(), 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis, 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, height: 1.2, color: Colors.black87) // 🟢 Smaller font
                ),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: 4.0, runSpacing: 4.0, // 🟢 Tighter wrap
                  children: [
                    if(weight != "N/A") _attributePill(Icons.scale_rounded, weight),
                    if(shape != "Standard") _attributePill(Icons.interests_rounded, shape),
                    if (cakeWriting.isNotEmpty) _attributePill(Icons.edit_note_rounded, "Msg: $cakeWriting"),
                    if (flavourText.isNotEmpty) _attributePill(Icons.local_dining_rounded, flavourText),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['display_price'] ?? "₹ ${item['price']}", 
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: accentPink) // 🟢 Smaller price font
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteItem(itemKey), 
            child: Container(
              padding: const EdgeInsets.all(6), // 🟢 Smaller hit box for the X button
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.grey[700]), // 🟢 Smaller icon
            ),
          )
        ],
      ),
    );
  }

  // 🟢 SMALLER ATTRIBUTE PILLS
  Widget _attributePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // 🟢 Reduced pill padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: Colors.white.withOpacity(0.9))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.black87), // 🟢 Smaller icon
          const SizedBox(width: 3),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black87))), // 🟢 Smaller font
        ],
      ),
    );
  }

  // --- COMPACT CHECKOUT PANEL ---
 // 🟢 REPLACEMENT: Updated Checkout Panel with Coupon Logic
  Widget _buildCheckoutPanel(List<Map<String, dynamic>> items) {
    double subtotal = _calculateTotal(items);
    double deliveryFee = _calculateDeliveryFee(subtotal);
    
    // Calculate Discount
    double discount = 0.0;
    if (_appliedCoupon != null) {
      discount = (_appliedCoupon!['discountAmount'] as num).toDouble();
    }
    
    double finalTotal = (subtotal + deliveryFee) - discount;
    bool hasAddress = userAddress.isNotEmpty && userAddress != "Select Location" && userAddress != "Locating...";

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 25, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Address & Schedule Card
                  _buildAddressScheduleCard(hasAddress),

                  // 🟢 NEW: Coupon Section
                  _buildCouponSection(subtotal),

                  // Price Breakdown
                  _buildPriceRow("Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
                  
                  if (discount > 0)
                    _buildPriceRow("Coupon Discount", "-₹${discount.toStringAsFixed(0)}", color: Colors.green, isBold: true),
                  
                  const SizedBox(height: 6),
                  _buildPriceRow("Delivery Fee", deliveryFee == 0 ? "FREE" : "₹${deliveryFee.toStringAsFixed(0)}", color: deliveryFee == 0 ? Colors.green : Colors.black87, isBold: deliveryFee == 0),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10), 
                    child: Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.3))
                  ),
                  _buildPriceRow("Total Amount", "₹${finalTotal.toStringAsFixed(0)}", isTotal: true),

                  const SizedBox(height: 16),

                  // Checkout Button
                  Container(
                    width: double.infinity, 
                    height: 52, 
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: accentPink.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !hasAddress ? Colors.black87 : accentPink, 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async { 
                        if (!hasAddress) { 
                          _showLocationOptionsDialog();
                          return;
                        }

                        String schedule = (selectedDate != null && selectedTime != null)
                            ? "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year} ${selectedTime!.format(context)}"
                            : "ASAP";

                        List<Map<String, dynamic>> processedCartItems = items.map((item) {
                          String rawFlavour = (item['flavours'] ?? item['flavor'] ?? '').toString();
                          return {
                            'name': item['name'],
                            'price': item['price'],
                            'image': item['image'],
                            'weight': item['selected_weight'] ?? item['weight'] ?? "Standard",
                            'shape': item['selected_shape'] ?? item['shape'] ?? "Round",
                            'cakeWriting': item['cakeWriting'] ?? "No Message",
                            'flavor': rawFlavour,  
                            'flavours': rawFlavour, 
                            'quantity': item['quantity'] ?? 1,
                            'category': item['category'] ?? 'Cake',
                          };
                        }).toList();

                        final String theMasterOrderId = "BHS-${DateTime.now().millisecondsSinceEpoch}";

                        await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => PaymentPage(
                            amount: finalTotal,
                            orderId: theMasterOrderId, 
                            userName: userName,
                            userPhone: userPhone,
                            userAddress: userAddress,
                            latitude: _selectedLat,
                            longitude: _selectedLng,
                            cartItems: processedCartItems,
                            deliverySchedule: schedule, 
                            receiverName: receiverName ?? userName, 
                            receiverPhone: receiverPhone ?? userPhone,
                            // 🟢 Pass the coupon code to mark as used on success
                            appliedCoupon: _appliedCoupon != null ? _appliedCoupon!['code'] : null,
                          ))
                        );
                      },
                      child: Text(
                        !hasAddress ? "SELECT ADDRESS" : "PROCEED TO PAY", 
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 13)
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 REPLACEMENT: Helper for Price Rows
  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: isTotal ? Colors.black87 : Colors.grey[800], fontSize: isTotal ? 16 : 13, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600)),
        Text(value, style: GoogleFonts.montserrat(color: color ?? (isTotal ? Colors.black : Colors.black87), fontSize: isTotal ? 20 : 14, fontWeight: isBold || isTotal ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  // 🟢 REPLACEMENT: Address Card Helper
  Widget _buildAddressScheduleCard(bool hasAddress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: !hasAddress ? accentPink.withOpacity(0.4) : Colors.white.withOpacity(0.8))
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _showLocationOptionsDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(!hasAddress ? Icons.add_location_alt_rounded : Icons.location_on_rounded, color: !hasAddress ? accentPink : Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(!hasAddress ? "Add Delivery Address" : userAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold))),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[600])
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
          InkWell(
            onTap: _selectDeliveryDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: selectedDate == null ? Colors.grey[600] : Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(selectedDate == null ? "Standard delivery: 3-4 hours" : "Scheduled: ${selectedDate!.day}/${selectedDate!.month}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[600])
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showLocationOptionsDialog() {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to manage addresses")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
              border: Border.all(color: Colors.white, width: 2)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 25),
                
                Text("SAVED ADDRESSES", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1)),
                const SizedBox(height: 15),
                
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .collection('addresses')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: accentPink));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text("No saved addresses yet.", style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const Divider(height: 30),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          String label = data['label'] ?? 'Other';
                          IconData labelIcon = Icons.location_on_rounded;
                          if (label == 'Home') labelIcon = Icons.home_rounded;
                          if (label == 'Work') labelIcon = Icons.work_rounded;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context); 
                                    setState(() {
                                      userAddress = data['fullAddress'] ?? "";
                                      _selectedLat = data['latitude'];
                                      _selectedLng = data['longitude'];
                                      receiverPhone = data['receiverPhone'];
                                      receiverName = data['receiverName'];
                                      googleMapsLink = data['googleMapsLink'];
                                    });
                                  },
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
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
                                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(data['receiverName'] ?? 'Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(data['fullAddress'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                                  await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('addresses').doc(doc.id).delete();
                                },
                              )
                            ],
                          );
                        },
                      );
                    }
                  ),
                ),

                const Divider(height: 40),

                Text("ADD NEW ADDRESS", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildLocationActionBtn("Current\nLocation", Icons.my_location_rounded, Colors.blueAccent, () { Navigator.pop(context); _determinePosition(); })),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLocationActionBtn("Select on\nMap", Icons.map_outlined, Colors.orangeAccent, () async { 
                      Navigator.pop(context);
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationPage()));
                      if (result != null && result is Map) {
                        setState(() {
                          userAddress = result['address'] ?? "";
                          _selectedLat = result['lat'];
                          _selectedLng = result['lng'];
                          receiverPhone = result['phone'];
                          receiverName = result['name'];
                          googleMapsLink = result['link'];
                        });
                      }
                    })),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildLocationActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [Icon(icon, color: color, size: 30), const SizedBox(height: 12), Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, height: 1.3, color: Colors.black87))]),
      ),
    );
  }

  void _showAddressDetailsEntrySheet(String detectedArea, {double? lat, double? lng}) {
    final TextEditingController areaCtrl = TextEditingController(text: detectedArea);
    final TextEditingController houseCtrl = TextEditingController();
    final TextEditingController landmarkCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    String selectedLabel = "Home";

    void onPhoneChangedLocal(StateSetter setStateLocal) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userPhone = user.phoneNumber ?? "";
        String userName = user.displayName ?? (user.email?.split('@')[0] ?? "");
        
        String enteredPhone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');
        String registeredPhone = userPhone.replaceAll(RegExp(r'[^0-9+]'), '');

        if (registeredPhone.isNotEmpty) {
          bool isSameNumber = (enteredPhone == registeredPhone) || (enteredPhone.length >= 10 && registeredPhone.endsWith(enteredPhone));
          if (isSameNumber) {
            if (nameCtrl.text != userName) nameCtrl.text = userName;
          } else {
            if (nameCtrl.text == userName) nameCtrl.clear();
          }
        }
      }
      setStateLocal(() {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateLocal) {
            phoneCtrl.addListener(() => onPhoneChangedLocal(setStateLocal));

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95), 
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                    border: Border.all(color: Colors.white, width: 2)
                  ),
                  padding: const EdgeInsets.all(24),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                          const SizedBox(height: 25),
                          Text("COMPLETE ADDRESS", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                          const SizedBox(height: 25),
                          
                          Row(
                            children: [
                              Expanded(child: _buildInput(houseCtrl, "House / Flat No.", Icons.home_filled)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildInput(areaCtrl, "Area / Street", Icons.map_outlined)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInput(landmarkCtrl, "Landmark (Optional)", Icons.flag_outlined),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildInput(phoneCtrl, "Receiver's Number", Icons.phone_rounded, keyboardType: TextInputType.phone),
                              ),
                              const SizedBox(width: 10),
                              
                              if (phoneCtrl.text.isEmpty)
                                Expanded(
                                  flex: 4,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
                                        phoneCtrl.text = user.phoneNumber!; 
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No phone number linked to this login account.")));
                                      }
                                    },
                                    icon: const Icon(Icons.person, size: 16),
                                    label: Text("Same", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: accentPink,
                                      backgroundColor: accentPink.withOpacity(0.1),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                )
                              else
                                Expanded(flex: 5, child: _buildInput(nameCtrl, "Receiver's Name", Icons.person_outline_rounded)),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Text("SAVE AS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildLabelChipSheet("Home", Icons.home_rounded, selectedLabel, (lbl) => setStateLocal(() => selectedLabel = lbl))),
                              const SizedBox(width: 10),
                              Expanded(child: _buildLabelChipSheet("Work", Icons.work_rounded, selectedLabel, (lbl) => setStateLocal(() => selectedLabel = lbl))),
                              const SizedBox(width: 10),
                              Expanded(child: _buildLabelChipSheet("Other", Icons.location_on_rounded, selectedLabel, (lbl) => setStateLocal(() => selectedLabel = lbl))),
                            ],
                          ),

                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity, height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0
                              ),
                              onPressed: () async {
                                if (areaCtrl.text.isEmpty || houseCtrl.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill House No. and Area", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87));
                                  return;
                                }
                                if (phoneCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill Receiver details", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87));
                                  return;
                                }

                                String finalAddr = "${houseCtrl.text.trim()}, ${areaCtrl.text.trim()}";
                                if (landmarkCtrl.text.isNotEmpty) finalAddr += " near ${landmarkCtrl.text.trim()}";
                                final String googleMapsLink = "https://www.google.com/maps/search/?api=1&query=${lat ?? 0},${lng ?? 0}";

                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('addresses').add({
                                    'userEmail': user.email,
                                    'fullAddress': finalAddr, 
                                    'house': houseCtrl.text.trim(),
                                    'area': areaCtrl.text.trim(),
                                    'landmark': landmarkCtrl.text.trim(),
                                    'receiverPhone': phoneCtrl.text.trim(),
                                    'receiverName': nameCtrl.text.trim(),
                                    'label': selectedLabel,
                                    'latitude': lat,
                                    'longitude': lng,
                                    'googleMapsLink': googleMapsLink, 
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'type': 'Current Location'
                                  });
                                }

                             setState(() {
                                  userAddress = finalAddr; 
                                  receiverName = nameCtrl.text.trim();
                                  receiverPhone = phoneCtrl.text.trim();
                                  _selectedLat = lat;
                                  _selectedLng = lng;
                                });
                                final prefs = await SharedPreferences.getInstance();
                                prefs.setString('userAddress', userAddress);

                                Navigator.pop(context); 
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Address saved successfully!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                              },
                              child: Text("SAVE ADDRESS", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
  Widget _buildLabelChipSheet(String label, IconData icon, String currentSelection, Function(String) onSelect) {
    bool isSelected = currentSelection == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[800])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildGlassContainer(
            radius: 100,
            padding: const EdgeInsets.all(35),
            child: Icon(Icons.shopping_bag_outlined, size: 70, color: accentPink.withOpacity(0.5)),
          ),
          const SizedBox(height: 30),
          Text("Your basket is empty", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 8),
          Text("Add some delicious treats!", style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14)),
          const SizedBox(height: 35),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentPink,
              backgroundColor: Colors.white.withOpacity(0.5),
              side: BorderSide(color: accentPink.withOpacity(0.5), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            ),
            onPressed: () => Navigator.pop(context), 
            child: Text("GO TO MENU", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: accentPink, letterSpacing: 1))
          ),
        ],
      ),
    );
  }

  Widget buildImage(String imageString, {double radius = 18}) {
    Widget image;

    try {
      if (imageString.startsWith('assets/')) {
        image = Image.asset(imageString, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true);
      } else if (imageString.startsWith('http')) {
        image = Image.network(imageString, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true);
      } else {
        Uint8List imageBytes;
        if (_memoryImageCache.containsKey(imageString)) {
          imageBytes = _memoryImageCache[imageString]!;
        } else {
          imageBytes = base64Decode(imageString);
          _memoryImageCache[imageString] = imageBytes;
        }

        image = Image.memory(imageBytes, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true);
      }
    } catch (e) {
      image = const Icon(Icons.broken_image, color: Colors.black26);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20), 
          hintText: hint, 
          hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontWeight: FontWeight.w500), 
          filled: true, 
          fillColor: Colors.transparent, 
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accentPink.withOpacity(0.5))),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 CUSTOM PULSING SKELETON WIDGET
// ---------------------------------------------------------------------------
class PulsingSkeleton extends StatefulWidget {
  final Widget child;
  const PulsingSkeleton({super.key, required this.child});

  @override
  State<PulsingSkeleton> createState() => _PulsingSkeletonState();
}

class _PulsingSkeletonState extends State<PulsingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1000)
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
      opacity: Tween<double>(begin: 0.3, end: 0.8).animate(_controller),
      child: widget.child,
    );
  }
}