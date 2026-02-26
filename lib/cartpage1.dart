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
import 'package:project/cakepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  final Color bgGrey = const Color(0xFFF8F9FA);
  final double kPadding = 20.0;
  
  Stream<DatabaseEvent>? _cartStream;

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
    const double shopLat = 9.9312; // Default Kochi
    const double shopLng = 76.2673;
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
        userAddress = ""; // 🟢 Start completely empty
      });
    }

    bool foundSavedAddress = false;

    // 1. FIREBASE CHECK
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

    // 2. CACHE CHECK
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

    // 3. FINAL FALLBACK IF NOTHING FOUND
    if (!foundSavedAddress) {
      if (mounted) {
        setState(() {
          userAddress = ""; // 🟢 Guarantees the "Add Delivery Address" UI triggers
        });
      }
    }
  }
  Future<void> _selectAddress(String address, {double? lat, double? lng}) async {
    setState(() {
      userAddress = address;
      _selectedLat = lat;
      _selectedLng = lng;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userAddress', address);
    if (lat != null && lng != null) {
      await prefs.setDouble('userLat', lat);
      await prefs.setDouble('userLng', lng);
    }
  }

  // 🟢 CURRENT LOCATION LOGIC WITH ZONE CHECK
  // ---------------------------------------------------------------------------
  // 🟢 CURRENT LOCATION LOGIC (FIXED DOUBLE LOADING)
  // ---------------------------------------------------------------------------
  Future<void> _determinePosition() async {
    // 🟢 SHOW ONLY ONE LOADING OVERLAY (The Dialog)
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74)))
    );

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permission denied';
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // 1. SET HARD FALLBACKS (Ensure these are your exact shop coordinates)
      double shopLat = 9.9312; 
      double shopLng = 76.2673; 
      double maxRadius = 15000.0; // 15 km in meters
      
      // 2. SAFELY FETCH FIREBASE ZONE SETTINGS
      try {
        final doc = await FirebaseFirestore.instance.collection('settings').doc('delivery_zone').get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['lat'] != null) shopLat = (data['lat'] as num).toDouble();
          if (data['lng'] != null) shopLng = (data['lng'] as num).toDouble();
          if (data['radius'] != null) maxRadius = (data['radius'] as num).toDouble();
        }
      } catch (e) {
        debugPrint("Failed to fetch radius from Firebase. Using hardcoded defaults: $e");
      }

      // 3. CALCULATE DISTANCE (in meters)
      double distanceInMeters = Geolocator.distanceBetween(shopLat, shopLng, position.latitude, position.longitude);

      // 4. SHOW ERROR IF OUT OF ZONE
      if (distanceInMeters > maxRadius) {
        if (mounted) {
          Navigator.pop(context); // 🟢 Close the loading dialog
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.block_flipped, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 10),
                  Text("Out of Zone", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              content: Text(
                "Sorry, your current location is ${(distanceInMeters / 1000).toStringAsFixed(1)} km away. We currently only deliver within ${(maxRadius / 1000).toStringAsFixed(0)} km.",
                style: GoogleFonts.inter(color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK", style: GoogleFonts.inter(color: const Color(0xFFFF2E74), fontWeight: FontWeight.bold)),
                )
              ],
            )
          );
        }
        return; 
      }

      // 5. IF IN ZONE, PROCEED TO DECODE ADDRESS
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
      Navigator.pop(context); // 🟢 Close the loading dialog
      _showAddressDetailsEntrySheet(detectedArea, lat: position.latitude, lng: position.longitude);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 🟢 Close the loading dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to get location. Please check your GPS or permissions.")));
      }
    } 
  }
  // --- SCHEDULING LOGIC ---
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
      helpText: "SELECT TIME (9 AM - 6 PM)",
    );

    if (picked != null) {
      if (picked.hour < 9 || picked.hour >= 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Delivery available between 9 AM and 6 PM only", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87)
        );
        return;
      }

      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        final DateTime selectedDateTime = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
        if (selectedDateTime.isBefore(now.add(const Duration(hours: 3)))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please allow at least 3-4 hours for preparation", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87)
          );
          return;
        }
      }

      setState(() => selectedTime = picked);
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      extendBody: true,
      body: StreamBuilder<DatabaseEvent>(
        stream: _cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accentPink));
          }

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
                  if (itemsList.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(kPadding, 20, kPadding, 380),
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

              if (itemsList.isNotEmpty)
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
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B),
        borderRadius: BorderRadius.circular(24), 
      ),
      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white.withOpacity(0.85),
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text("MY BASKET", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.5, color: Colors.black)),
      flexibleSpace: ClipRect(
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.transparent))
      ),
    );
  }

  Widget _buildCartCard(Map<String, dynamic> item, String itemKey) {
    String flavourText = formatFlavours(item['flavours']);
    String cakeWriting = (item['cakeWriting'] ?? '').toString();
    String weight = (item['selected_weight'] ?? item['weight'] ?? "N/A").toString();
    String shape = (item['selected_shape'] ?? item['shape'] ?? "Standard").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 95, height: 95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18), 
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16), 
              child: _buildImage(item['image'] ?? ""),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Text(item['name'].toString().toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 13, height: 1.3, color: Colors.black87)),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 6.0, runSpacing: 6.0,
                  children: [
                    if(weight != "N/A") _attributePill(Icons.scale_rounded, weight),
                    if(shape != "Standard") _attributePill(Icons.interests_rounded, shape),
                    if (cakeWriting.isNotEmpty) _attributePill(Icons.edit_note_rounded, "Msg: $cakeWriting"),
                    if (flavourText.isNotEmpty) _attributePill(Icons.local_dining_rounded, flavourText),
                  ],
                ),
                const SizedBox(height: 12),
                Text(item['display_price'] ?? "₹ ${item['price']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: accentPink)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteItem(itemKey), 
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[500]),
            ),
          )
        ],
      ),
    );
  }

  Widget _attributePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  // --- CHECKOUT PANEL ---
 // --- CHECKOUT PANEL ---
  Widget _buildCheckoutPanel(List<Map<String, dynamic>> items) {
    double subtotal = _calculateTotal(items);
    double deliveryFee = _calculateDeliveryFee(subtotal);
    double finalTotal = subtotal + deliveryFee;

    // 🟢 UI FLAG: Check if address is valid
    bool hasAddress = userAddress.isNotEmpty && userAddress != "Select Location" && userAddress != "Locating...";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 20, 25, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 📅 OPTIONAL DELIVERY SCHEDULE
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _selectDeliveryDate();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedDate == null ? Colors.grey[50] : const Color(0xFFF4FFF6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selectedDate == null ? Colors.grey[200]! : Colors.green.withOpacity(0.3)
                    )
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          shape: BoxShape.circle,
                          boxShadow: [if (selectedDate != null) BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 8)]
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded, 
                          color: selectedDate == null ? Colors.grey[400] : Colors.green, 
                          size: 20
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Delivery Schedule (Optional)", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              selectedDate == null 
                                ? "Standard delivery: 3-4 hours" 
                                : "${selectedDate!.day}/${selectedDate!.month} at ${selectedTime?.format(context) ?? 'Select Time'}",
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: selectedDate == null ? Colors.grey[600] : Colors.black87)
                            ),
                          ],
                        ),
                      ),
                      if (selectedDate != null) 
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18), 
                          color: Colors.grey[500],
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() { selectedDate = null; selectedTime = null; })
                        )
                      else 
                        Icon(Icons.add_circle_outline_rounded, size: 20, color: accentPink),
                    ],
                  ),
                ),
              ),

              // 📍 ADDRESS BAR (🟢 Cleaned up empty state logic)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showLocationOptionsDialog();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: !hasAddress ? const Color(0xFFFFF0F5) : const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: !hasAddress ? accentPink.withOpacity(0.3) : Colors.transparent)
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: (!hasAddress ? accentPink : Colors.blueAccent).withOpacity(0.1), blurRadius: 8)]
                        ),
                        child: Icon(!hasAddress ? Icons.add_location_alt_rounded : Icons.location_on_rounded, color: !hasAddress ? accentPink : Colors.blueAccent, size: 20),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(!hasAddress ? "Add Delivery Address" : "Delivering to:", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(!hasAddress ? "Tap to locate or enter" : userAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                            
                            // DISPLAY RECEIVER NAME & PHONE (Only if address exists)
                            if (hasAddress && receiverName != null && receiverPhone != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("$receiverName • $receiverPhone", style: GoogleFonts.inter(fontSize: 11, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w600)),
                              ),

                            // DISPLAY DISTANCE (Only if address exists)
                            if (hasAddress && _selectedLat != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_getDistanceKm(), style: GoogleFonts.inter(fontSize: 11, color: accentPink, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400])
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
              if (subtotal < 500 && subtotal > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: accentPink.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: accentPink.withOpacity(0.15))),
                  child: Row(
                    children: [
                      Icon(Icons.redeem_rounded, size: 18, color: accentPink),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Add ₹${(500 - subtotal).toStringAsFixed(0)} more for FREE delivery!", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: accentPink))),
                    ],
                  ),
                ),

              _buildPriceRow("Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
              const SizedBox(height: 12),
              _buildPriceRow("Delivery Fee", deliveryFee == 0 ? "FREE" : "₹${deliveryFee.toStringAsFixed(0)}", color: deliveryFee == 0 ? Colors.green : Colors.black87, isBold: deliveryFee == 0),

              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, thickness: 1)),
              _buildPriceRow("Total Amount", "₹${finalTotal.toStringAsFixed(0)}", isTotal: true),

              const SizedBox(height: 25),

              Container(
                width: double.infinity, 
                height: 60,
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: () async { 
                    if (!hasAddress) { 
                      _showLocationOptionsDialog();
                      return;
                    }

                    String schedule = "ASAP";
                    if (selectedDate != null && selectedTime != null) {
                      schedule = "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year} ${selectedTime!.format(context)}";
                    }

                    List<Map<String, dynamic>> processedCartItems = items.map((item) {
                      String rawFlavour = (item['flavours'] ?? item['flavor'] ?? '').toString();
                      String finalRName = receiverName ?? "";
                    String finalRPhone = receiverPhone ?? "";

                    // 2. Check if they are empty, or if the user literally typed "Same"
                    if (finalRName.isEmpty || finalRName.toLowerCase() == "same" || finalRName == userName) {
                      finalRName = "Same as Customer";
                    }
                    if (finalRPhone.isEmpty || finalRPhone.toLowerCase() == "same" || finalRPhone == userPhone) {
                      finalRPhone = "Same as Customer";
                    }

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

                    final user = FirebaseAuth.instance.currentUser;
                    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
                    String userSuffix = (user != null && user.uid.length > 4) 
                        ? user.uid.substring(user.uid.length - 4).toUpperCase() 
                        : "GST";
                    String randomNum = (100 + DateTime.now().microsecond % 900).toString();
                    
                    final String theMasterOrderId = "BHS-$timeStamp-$userSuffix-$randomNum";

                    // 🟢 NEW: DETERMINE RECEIVER DETAILS
                    // Check if receiver details are provided, otherwise mark them as "Same as Customer"
                    String rName = (receiverName != null && receiverName!.isNotEmpty) ? receiverName! : "Same as Customer";
                    String rPhone = (receiverPhone != null && receiverPhone!.isNotEmpty) ? receiverPhone! : "Same as Customer";

                    // If they literally typed "Same" into the name or phone field (which you allow via the 'Same' button)
                    if (rName.toLowerCase() == "same" || rName == userName) {
                      rName = "Same as Customer";
                    }
                    if (rPhone.toLowerCase() == "same" || rPhone == userPhone) {
                       rPhone = "Same as Customer";
                    }

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
                        // 🟢 NEW: Pass to Payment Page
                        receiverName: rName, 
                        receiverPhone: rPhone,
                      ))
                    );
                  },
                  child: Text(
                    !hasAddress ? "SELECT ADDRESS" : "PROCEED TO PAY", 
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 14)
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: isTotal ? Colors.black87 : Colors.grey[600], fontSize: isTotal ? 15 : 14, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500)),
        Text(value, style: GoogleFonts.montserrat(color: color ?? (isTotal ? Colors.black : Colors.black87), fontSize: isTotal ? 22 : 15, fontWeight: isBold || isTotal ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🟢 LOCATION OPTIONS DIALOG
  // ---------------------------------------------------------------------------
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              
              // 1. SAVED ADDRESSES SECTION
              Text("SAVED ADDRESSES", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1)),
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
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text("No saved addresses yet.", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w500))),
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
                                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
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
                                          Text(data['fullAddress'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
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

              // 2. ADD NEW ADDRESS OPTIONS
              Text("ADD NEW ADDRESS", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1)),
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
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
        child: Column(children: [Icon(icon, color: color, size: 30), const SizedBox(height: 12), Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, height: 1.3, color: Colors.black87))]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🟢 IN-LINE CURRENT LOCATION FORM ENTRY
  // ---------------------------------------------------------------------------
 // ---------------------------------------------------------------------------
  // 🟢 IN-LINE CURRENT LOCATION FORM ENTRY (FIXED OVERFLOW)
  // ---------------------------------------------------------------------------
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

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  top: false,
                  // 🟢 THIS SINGLE CHILD SCROLL VIEW FIXES THE KEYBOARD OVERFLOW
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
                                    foregroundColor: const Color(0xFFFF2E74),
                                    backgroundColor: const Color(0xFFFF2E74).withOpacity(0.1),
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
                        Text("SAVE AS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600])),
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
                          width: double.infinity, height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
                                // 🟢 FIXED: Actually update the screen with the newly typed data!
                                userAddress = finalAddr; 
                                receiverName = nameCtrl.text.trim();
                                receiverPhone = phoneCtrl.text.trim();
                                _selectedLat = lat;
                                _selectedLng = lng;
                              });
                              final prefs = await SharedPreferences.getInstance();
                              prefs.setString('userAddress', userAddress);

                              Navigator.pop(context); // Close sheet
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
          color: isSelected ? Colors.black87 : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[700])),
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
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)]),
            child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          Text("Your basket is empty", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text("Add some delicious treats!", style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 35),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentPink,
              side: BorderSide(color: accentPink.withOpacity(0.5), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            onPressed: () => Navigator.pop(context), 
            child: Text("GO TO MENU", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, color: accentPink, letterSpacing: 1))
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageString) {
    try {
      if (imageString.isEmpty) return const Icon(Icons.cake, color: Colors.grey);
      if (imageString.startsWith('assets/')) return Image.asset(imageString, fit: BoxFit.cover);
      if (imageString.startsWith('http')) return Image.network(imageString, fit: BoxFit.cover);
      return Image.memory(base64Decode(imageString), fit: BoxFit.cover);
    } catch (e) { return const Icon(Icons.broken_image, color: Colors.grey); }
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20), 
          hintText: hint, 
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontWeight: FontWeight.w500), 
          filled: true, 
          fillColor: Colors.grey[50], 
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accentPink.withOpacity(0.5))),
        ),
      ),
    );
  }
}