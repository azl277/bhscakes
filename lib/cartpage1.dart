import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 

import 'package:project/location.dart'; 

class Cartpage1 extends StatefulWidget {
  final String? initialAddress;
  const Cartpage1({super.key, this.initialAddress});

  @override
  State<Cartpage1> createState() => _Cartpage1State();
}

class _Cartpage1State extends State<Cartpage1> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String userName = "Guest";
  String userPhone = "";
  String userAddress = "";
  String? receiverName;
  String? receiverPhone;
  String? googleMapsLink;
  double? _selectedLat;
  double? _selectedLng;
  
  double _baseDistanceFee = 0.0; 
  List<Map<String, dynamic>> _deliveryZones = []; 
  
  bool isLoadingLocation = false;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final Color accentPink = const Color(0xFFFF2E74);
  final Color bgLight = const Color(0xFFF8F9FA);
  final double kPadding = 20.0;

  Stream<DatabaseEvent>? _cartStream;
  Stream<QuerySnapshot>? _addonsStream;
  
  final Map<String, Uint8List> _memoryImageCache = {};

  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  bool _isValidatingCoupon = false;
  String _couponError = "";

  int globalDeliveryMin = 3;
  int globalDeliveryMax = 4;
  String globalDeliveryUnit = "Hours";
  int globalSlotWindow = 1;
  
  int freeDeliveryThreshold = 500;
  double smallCartFeeAmount = 40.0; 
  double lateNightPremiumAmount = 50.0; 
  
  double globalChargePerKm = 10.0; 

  double gstPercentage = 0.0;
  int packingCharge = 0;
  int platformFee = 0;

  LatLng _shopLocation = const LatLng(10.216229, 76.157549);
  TimeOfDay storeStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay storeEndTime = const TimeOfDay(hour: 21, minute: 0); 
  bool isStoreOpenToday = true;
  
  bool isAfterHoursEnabled = false;
  List<dynamic> afterHoursSlots = [];

  late Razorpay _razorpay;
  String _selectedPaymentMethod = 'ONLINE'; 
  
  double _pendingFinalTotal = 0.0;
  String _pendingOrderId = "";
  String _pendingScheduleStr = "";
  List<Map<String, dynamic>> _pendingProcessedItems = [];
  
  double _pendingTotalDeliveryFee = 0.0; 
  double _pendingSmallCartFee = 0.0;
  double _pendingDistanceFee = 0.0;
  double _pendingLateNightFee = 0.0;
  
  double _pendingSubtotal = 0.0;
  double _pendingDiscount = 0.0;

  double _getRawDistance() {
    if (_selectedLat == null || _selectedLng == null) return 0.0;

    double distanceInMeters = Geolocator.distanceBetween(
      _shopLocation.latitude, 
      _shopLocation.longitude, 
      _selectedLat ?? 0.0, 
      _selectedLng ?? 0.0
    );

    double distKm = distanceInMeters / 1000;
    
    if (distKm > 0 && distKm < 1.0) {
      return 1.0;
    }

    return distKm; 
  }

  double calculateLiveDistanceFee() {
    if (_selectedLat == null || _selectedLng == null) return 0.0;

    double distKm = _getRawDistance();
    LatLng userPos = LatLng(_selectedLat ?? 0.0, _selectedLng ?? 0.0);
    
    double activeRate = globalChargePerKm;
    double activeFreeRadius = 0.0;

    for (var zone in _deliveryZones) {
      if (_isPointInPolygon(userPos, zone['polygon'])) {
        activeRate = (zone['chargePerKm'] as num).toDouble();
        activeFreeRadius = (zone['freeRadiusKm'] as num).toDouble();
        break;
      }
    }

    if (distKm <= activeFreeRadius) return 0.0;
    return (distKm - activeFreeRadius) * activeRate;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();

    if (currentUser != null) {
      _cartStream = FirebaseDatabase.instance.ref().child('users/${currentUser?.uid}/cart').onValue;
    }
    
    _addonsStream = FirebaseFirestore.instance.collection('addons').snapshots();

    if (widget.initialAddress != null) {
      userAddress = widget.initialAddress ?? "";
    }

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _deleteItem(String itemKey) async {
    if (currentUser == null) return;
    HapticFeedback.mediumImpact();
    await FirebaseDatabase.instance.ref().child('users/${currentUser?.uid}/cart/$itemKey').remove();
  }

  Future<void> _addAddonToCart(Map<String, dynamic> addonData) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to add items.")));
      return;
    }

    HapticFeedback.lightImpact();

    final DatabaseReference cartRef = FirebaseDatabase.instance.ref().child('users/${currentUser?.uid}/cart');
    
    String newKey = cartRef.push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    String rawPrice = addonData['price']?.toString() ?? '0';
    double price = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    Map<String, dynamic> cartItem = {
      'id': addonData['id'] ?? newKey,
      'name': addonData['name'] ?? 'Addon',
      'price': price,
      'display_price': "₹$price",
      'image': addonData['image'] ?? addonData['imageUrl'] ?? '',
      'quantity': 1,
      'category': 'Addon',
      'deliveryTime': 0, 
      'deliveryUnit': 'Hours',
      'addedAt': ServerValue.timestamp,
    };

    try {
      await cartRef.child(newKey).set(cartItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${addonData['name']} added to cart!"), 
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          )
        );
      }
    } catch (e) {
      debugPrint("Error adding addon: $e");
    }
  }

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

  bool hasAddress() {
    return userAddress.isNotEmpty && 
           userAddress != "Select Location" && 
           userAddress != "Locating..." && 
           _selectedLat != null && 
           _selectedLng != null;
  }

  Map<String, dynamic>? _getActiveAfterHoursSlot(DateTime targetTime) {
    if (!isAfterHoursEnabled || afterHoursSlots.isEmpty) return null;
    DateTime storeOpenDT = DateTime(targetTime.year, targetTime.month, targetTime.day, storeStartTime.hour, storeStartTime.minute);

    for (var slot in afterHoursSlots) {
      TimeOfDay startTOD = _parseTimeString(slot['startTime']);
      TimeOfDay endTOD = _parseTimeString(slot['endTime']);
      
      DateTime startDT = DateTime(targetTime.year, targetTime.month, targetTime.day, startTOD.hour, startTOD.minute);
      DateTime endDT = DateTime(targetTime.year, targetTime.month, targetTime.day, endTOD.hour, endTOD.minute);
      
      if (startDT.isBefore(storeOpenDT)) startDT = startDT.add(const Duration(days: 1));
      if (endDT.isBefore(startDT) || endDT.isAtSameMomentAs(startDT)) endDT = endDT.add(const Duration(days: 1));
      
      if ((targetTime.isAfter(startDT) || targetTime.isAtSameMomentAs(startDT)) && 
          (targetTime.isBefore(endDT) || targetTime.isAtSameMomentAs(endDT))) {
        return slot as Map<String, dynamic>;
      }
    }
    return null;
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      String priceString = (item['price']?.toString() ?? '0').replaceAll(RegExp(r'[^0-9.]'), '');
      total += double.tryParse(priceString) ?? 0;
    }
    return total;
  }

  int _getEarliestMins(List<Map<String, dynamic>> items) {
    int baseMinInMins = (globalDeliveryUnit == 'Hours') ? globalDeliveryMin * 60 : globalDeliveryMin;
    int highestMins = 0;
    for (var item in items) {
      int dt = int.tryParse(item['deliveryTime']?.toString() ?? '0') ?? 0;
      String unit = (item['deliveryUnit'] ?? 'Hours').toString().toLowerCase();
      int itemMins = dt > 0 ? ((unit == 'days') ? dt * 24 * 60 : (unit == 'minutes' || unit == 'mins') ? dt : dt * 60) : baseMinInMins;
      if (itemMins > highestMins) highestMins = itemMins;
    }
    return highestMins;
  }

  String _getDeliveryLabelText(List<Map<String, dynamic>> items) {
    int baseMinInMins = (globalDeliveryUnit == 'Hours') ? globalDeliveryMin * 60 : globalDeliveryMin;
    int highestMins = 0;
    bool hasStandardItem = false;

    for (var item in items) {
      int dt = int.tryParse(item['deliveryTime']?.toString() ?? '0') ?? 0;
      String unit = (item['deliveryUnit'] ?? 'Hours').toString().toLowerCase();
      if (dt == 0) {
        hasStandardItem = true;
        if (baseMinInMins > highestMins) highestMins = baseMinInMins;
      } else {
        int itemMins = (unit == 'days') ? dt * 24 * 60 : (unit == 'minutes' || unit == 'mins') ? dt : dt * 60;
        if (itemMins > highestMins) highestMins = itemMins;
      }
    }
    
    if (highestMins == baseMinInMins && hasStandardItem) {
      return "Delivery in $globalDeliveryMin to $globalDeliveryMax $globalDeliveryUnit" ;
    } else {
      int d = highestMins ~/ (24 * 60);
      int h = (highestMins % (24 * 60)) ~/ 60;
      int m = highestMins % 60;
      if (d > 0) return "Delivery in $d to ${d + 1} Days";
      else if (h > 0) return "Delivery in $h to ${h + 1} Hours";
      else return "Delivery in $m Mins";
    }
  }

  DateTime _getEarliestValidDeliveryTime(int totalMinMins) {
    final now = DateTime.now();
    DateTime projectedTime = now.add(Duration(minutes: totalMinMins));

    DateTime storeOpenDT = DateTime(now.year, now.month, now.day, storeStartTime.hour, storeStartTime.minute);
    DateTime storeCloseDT = DateTime(now.year, now.month, now.day, storeEndTime.hour, storeEndTime.minute);

    if (storeCloseDT.isBefore(storeOpenDT) || storeCloseDT.isAtSameMomentAs(storeOpenDT)) storeCloseDT = storeCloseDT.add(const Duration(days: 1));

    if (!isStoreOpenToday) return storeOpenDT.add(const Duration(days: 1)).add(Duration(minutes: totalMinMins));

    if ((projectedTime.isAfter(storeOpenDT) || projectedTime.isAtSameMomentAs(storeOpenDT)) && 
        (projectedTime.isBefore(storeCloseDT) || projectedTime.isAtSameMomentAs(storeCloseDT))) {
      return projectedTime; 
    }

    if (projectedTime.isBefore(storeOpenDT)) return storeOpenDT.add(Duration(minutes: totalMinMins));

    if (isAfterHoursEnabled && afterHoursSlots.isNotEmpty) {
      var activeSlot = _getActiveAfterHoursSlot(projectedTime);
      if (activeSlot != null) return projectedTime; 

      DateTime? nextSlotStart;
      for (var slot in afterHoursSlots) {
        TimeOfDay startTOD = _parseTimeString(slot['startTime']);
        DateTime slotStartDT = DateTime(now.year, now.month, now.day, startTOD.hour, startTOD.minute);
        if (slotStartDT.isBefore(storeOpenDT)) slotStartDT = slotStartDT.add(const Duration(days: 1));
        if (slotStartDT.isAfter(projectedTime)) {
          if (nextSlotStart == null || slotStartDT.isBefore(nextSlotStart)) nextSlotStart = slotStartDT;
        }
      }
      if (nextSlotStart != null) return nextSlotStart; 
    }

    int minsWorkedToday = 0;
    if (now.isAfter(storeOpenDT) && now.isBefore(storeCloseDT)) minsWorkedToday = storeCloseDT.difference(now).inMinutes;
    int minsLeftForTomorrow = totalMinMins - minsWorkedToday;
    if (minsLeftForTomorrow < 0) minsLeftForTomorrow = 0;
    return storeOpenDT.add(const Duration(days: 1)).add(Duration(minutes: minsLeftForTomorrow));
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try { return TimeOfDay.fromDateTime(DateFormat('h:mm a').parse(timeStr.trim())); } 
    catch (e) {
      try { return TimeOfDay.fromDateTime(DateFormat.jm().parse(timeStr.trim())); } 
      catch (e2) { return const TimeOfDay(hour: 9, minute: 0); }
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool isInside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < point.latitude && polygon[j].latitude >= point.latitude ||
          polygon[j].latitude < point.latitude && polygon[i].latitude >= point.latitude) &&
          (polygon[i].longitude <= point.longitude || polygon[j].longitude <= point.longitude)) {
        if (polygon[i].longitude + (point.latitude - polygon[i].latitude) / 
            (polygon[j].latitude - polygon[i].latitude) * (polygon[j].longitude - polygon[i].longitude) < point.longitude) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }

  Future<void> _loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    if (mounted) {
      setState(() {
        userName = prefs.getString('username') ?? (user?.displayName ?? "Guest");
        userAddress = "";
        userPhone = prefs.getString('phone') ?? (user?.phoneNumber ?? "");
      });
    }

    try {
      final settingsSnap = await FirebaseFirestore.instance.collection('settings').doc('store_status').get();
      if (settingsSnap.exists && settingsSnap.data() != null) {
        final data = (settingsSnap.data() as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(() {
            globalDeliveryMin = data['stdDeliveryMin'] ?? 3;
            globalDeliveryMax = data['stdDeliveryMax'] ?? 4;
            globalDeliveryUnit = data['stdDeliveryUnit'] ?? "Hours";
            globalSlotWindow = data['slotDurationHours'] ?? 1;
            isStoreOpenToday = data['isOpen'] ?? true;
            
            freeDeliveryThreshold = data['freeDeliveryThreshold'] ?? 500;
            smallCartFeeAmount = (data['smallCartFee'] as num?)?.toDouble() ?? 40.0;
            lateNightPremiumAmount = (data['lateNightPremium'] as num?)?.toDouble() ?? 50.0;
            
            globalChargePerKm = (data['standardDeliveryRatePerKm'] as num?)?.toDouble() ?? 10.0;
            
            gstPercentage = (data['gstPercentage'] as num?)?.toDouble() ?? 0.0;
            packingCharge = (data['packingCharge'] as num?)?.toInt() ?? 0;
            platformFee = (data['platformFee'] as num?)?.toInt() ?? 0;
            storeStartTime = _parseTimeString(data['deliveryStartTime'] ?? "09:00 AM");
            storeEndTime = _parseTimeString(data['deliveryEndTime'] ?? "09:00 PM");
            isAfterHoursEnabled = data['isAfterHoursEnabled'] ?? false;
            afterHoursSlots = data['afterHoursSlots'] ?? [];
          });
        }
      }
      final shopDoc = await FirebaseFirestore.instance.collection('settings').doc('shop_info').get();
      if (shopDoc.exists && shopDoc.data() != null) {
        if (mounted) {
          setState(() {
            _shopLocation = LatLng(
              (shopDoc['lat'] as num?)?.toDouble() ?? 10.216229, 
              (shopDoc['lng'] as num?)?.toDouble() ?? 76.157549
            );
          });
        }
      }
      final zoneDocs = await FirebaseFirestore.instance.collection('delivery_zones').get();
      List<Map<String, dynamic>> loadedZones = [];
      for (var doc in zoneDocs.docs) {
        final data = doc.data();
        if (data.containsKey('points')) {
          List<dynamic> pts = data['points'] ?? [];
          List<LatLng> polygonPts = pts.map((p) => LatLng(p['lat'], p['lng'])).toList();
          loadedZones.add({
            'name': data['name'] ?? 'Custom Zone',
            'polygon': polygonPts,
            'freeRadiusKm': (data['freeDeliveryRadius'] as num?)?.toDouble() ?? 0.0,
            'chargePerKm': (data['chargePerKm'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }
      _deliveryZones = loadedZones;

    } catch (e) {}

    bool foundSavedAddress = false;
    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance.collection('users').doc(user?.uid ?? "GUEST").collection('addresses').orderBy('createdAt', descending: true).limit(1).get();
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
      } catch (e) {}
    }

    if (!foundSavedAddress && prefs.containsKey('userAddress')) {
      String cachedAddr = prefs.getString('userAddress') ?? "";
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
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled. Please turn on GPS.")));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
            child: CircularProgressIndicator(color: accentPink),
          ),
        ),
      ),
    );

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng userPos = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      Navigator.pop(context); 

      bool foundZone = false;
      Map<String, dynamic>? matchedZone;

      for (var zone in _deliveryZones) {
        if (_isPointInPolygon(userPos, zone['polygon'])) {
          foundZone = true;
          matchedZone = zone;
          break;
        }
      }

      if (!foundZone || matchedZone == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.block_flipped, color: Colors.redAccent, size: 28),
                const SizedBox(width: 10),
                Text("Out of Zone", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
            content: Text("Sorry, your current location is outside our delivery borders.", style: GoogleFonts.inter(color: Colors.black87)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: GoogleFonts.inter(color: accentPink, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      double distanceMeters = Geolocator.distanceBetween(_shopLocation.latitude, _shopLocation.longitude, userPos.latitude, userPos.longitude);
      double distanceKm = distanceMeters / 1000;
      double fee = 0.0;
      if (distanceKm > matchedZone['freeRadiusKm']) {
        fee = (distanceKm - matchedZone['freeRadiusKm']) * matchedZone['chargePerKm'];
      }

      String detectedArea = "Unknown Area";
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            List<String> parts = [];
            if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality ?? '');
            if (place.locality?.isNotEmpty == true) parts.add(place.locality ?? '');
            if (parts.isNotEmpty) detectedArea = parts.join(", ");
          }
        } catch (e) {}
      }

      _showAddressDetailsEntrySheet(detectedArea, lat: userPos.latitude, lng: userPos.longitude, fee: fee, zoneName: matchedZone['name']);
      
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to get location. Check your GPS.")));
      }
    }
  }

  Future<void> _selectDeliveryDate(int totalMinMins) async {
    DateTime earliestAllowed = _getEarliestValidDeliveryTime(totalMinMins);
    DateTime firstValidDate = DateTime(earliestAllowed.year, earliestAllowed.month, earliestAllowed.day);
    DateTime lastValidDate = firstValidDate.add(const Duration(days: 14));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstValidDate,
      firstDate: firstValidDate, 
      lastDate: lastValidDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: accentPink),
            dialogBackgroundColor: Colors.white,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null; 
      });
      _selectDeliveryTime(picked, totalMinMins, earliestAllowed);
    }
  }

  Future<void> _selectDeliveryTime(DateTime pickedDate, int totalMinMins, DateTime earliestAllowed) async {
    DateTime storeOpenForPickedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, storeStartTime.hour, storeStartTime.minute);
    
    DateTime minTimeForSlot;
    if (pickedDate.year == earliestAllowed.year && pickedDate.month == earliestAllowed.month && pickedDate.day == earliestAllowed.day) {
      minTimeForSlot = earliestAllowed;
    } else {
      minTimeForSlot = storeOpenForPickedDate.isAfter(earliestAllowed) ? storeOpenForPickedDate : earliestAllowed;
    }

    TimeOfDay initialTime = TimeOfDay.fromDateTime(minTimeForSlot);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: "Select Time",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: accentPink),
            dialogBackgroundColor: Colors.white,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      DateTime selectedDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, picked.hour, picked.minute);
      if (picked.hour < storeStartTime.hour) selectedDT = selectedDT.add(const Duration(days: 1));

      DateTime openTimeDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, storeStartTime.hour, storeStartTime.minute);
      DateTime closeTimeDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, storeEndTime.hour, storeEndTime.minute);

      if (closeTimeDT.isBefore(openTimeDT) || closeTimeDT.isAtSameMomentAs(openTimeDT)) {
        closeTimeDT = closeTimeDT.add(const Duration(days: 1));
      }

      bool isInsideAfterHours = false;
      if (isAfterHoursEnabled && afterHoursSlots.isNotEmpty) {
        for (var slot in afterHoursSlots) {
           TimeOfDay startTOD = _parseTimeString(slot['startTime']);
           TimeOfDay endTOD = _parseTimeString(slot['endTime']);
           
           DateTime slotStartDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, startTOD.hour, startTOD.minute);
           DateTime slotEndDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, endTOD.hour, endTOD.minute);
           
           if (slotStartDT.isBefore(openTimeDT)) slotStartDT = slotStartDT.add(const Duration(days: 1));
           if (slotEndDT.isBefore(slotStartDT)) slotEndDT = slotEndDT.add(const Duration(days: 1));
           
           if (slotEndDT.isAfter(closeTimeDT)) closeTimeDT = slotEndDT;

           if ((selectedDT.isAfter(slotStartDT) || selectedDT.isAtSameMomentAs(slotStartDT)) &&
               (selectedDT.isBefore(slotEndDT) || selectedDT.isAtSameMomentAs(slotEndDT))) {
             isInsideAfterHours = true;
           }
        }
      }

      if (selectedDT.isAfter(closeTimeDT) || selectedDT.isBefore(openTimeDT)) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time during open/after-hours.")));
         return;
      }

      DateTime standardCloseDT = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, storeEndTime.hour, storeEndTime.minute);
      if (standardCloseDT.isBefore(openTimeDT) || standardCloseDT.isAtSameMomentAs(openTimeDT)) {
        standardCloseDT = standardCloseDT.add(const Duration(days: 1));
      }
      
      bool isInsideStandardHours = (selectedDT.isAfter(openTimeDT) || selectedDT.isAtSameMomentAs(openTimeDT)) && 
                                   (selectedDT.isBefore(standardCloseDT) || selectedDT.isAtSameMomentAs(standardCloseDT));

      if (!isInsideStandardHours && !isInsideAfterHours) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected time is during a closed gap period.")));
         return;
      }

      if (selectedDT.isBefore(minTimeForSlot)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Earliest available slot is ${DateFormat('h:mm a').format(minTimeForSlot)}")));
        return;
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
      var doc = await FirebaseFirestore.instance.collection('coupons').doc(code).get();
      Map<String, dynamic>? data;

      if (doc.exists) {
        data = doc.data();
      } else {
        var welcomeDoc = await FirebaseFirestore.instance.collection('settings').doc('welcome_coupon').get();
        if (welcomeDoc.exists) {
          var welcomeData = welcomeDoc.data() ?? {};
          if ((welcomeData['code'] ?? '').toString().toUpperCase() == code) {
            data = welcomeData;
            data['isWelcome'] = true; 
          }
        }
      }

      if (data == null) {
        setState(() => _couponError = "Invalid coupon code");
        return;
      }

      int minPurchase = (data['minPurchase'] as num?)?.toInt() ?? 0;
      bool isActive = data['isActive'] ?? false;
      bool isWelcome = data['isWelcome'] == true;

      DateTime expiry = DateTime.now().add(const Duration(days: 365)); 
      if (data['expiryDate'] != null && data['expiryDate'] is Timestamp) {
        expiry = (data['expiryDate'] as Timestamp).toDate();
      }

      bool isUsedUp = false;
      if (!isWelcome) {
        int limit = (data['usageLimit'] as num?)?.toInt() ?? 1;
        int count = (data['usageCount'] as num?)?.toInt() ?? 0;
        isUsedUp = (limit > 0 && count >= limit) || (data['isUsed'] == true);
      }

      if (!isActive || isUsedUp) {
        setState(() => _couponError = "This coupon is fully claimed or inactive");
      } else if (DateTime.now().isAfter(expiry)) {
        setState(() => _couponError = "This coupon has expired");
      } else if (currentSubtotal < minPurchase) {
        setState(() => _couponError = "Min purchase ₹$minPurchase required");
      } else {
        if (isWelcome && currentUser != null) {
          final orderSnap = await FirebaseDatabase.instance.ref().child('users/${currentUser?.uid}/orders').limitToFirst(1).get();
          if (orderSnap.exists) {
            setState(() {
              _couponError = "Valid for first-time orders only.";
              _isValidatingCoupon = false;
            });
            return;
          }
        }

        setState(() {
          _appliedCoupon = data;
          _couponError = "";
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() => _couponError = "Unable to verify coupon");
    } finally {
      setState(() => _isValidatingCoupon = false);
    }
  }

  void _startPayment() {
    String effectivePhone = userPhone.isEmpty ? (currentUser?.phoneNumber ?? "9999999999") : userPhone;
    var options = {
      'key': 'rzp_test_S658dHJsKLfV7D',
      'amount': (_pendingFinalTotal * 100).toInt(),
      'name': 'Butter Hearts Cakes',
      'description': 'Order #${_pendingOrderId.substring(_pendingOrderId.length >= 6 ? _pendingOrderId.length - 6 : 0)}',
      'prefill': {
        'contact': effectivePhone,
        'email': currentUser?.email ?? 'customer@butterhearts.com',
      },
      'theme': {'color': '#111111'},
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Payment Initiation Error: $e');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    await _finalizeOrder(
      paymentId: response.paymentId ?? "UNKNOWN_PAYMENT_ID",
      paymentStatus: "PAID",
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog("Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Wallet Selected: ${response.walletName}"), behavior: SnackBarBehavior.floating),
    );
  }

  void _showCODConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        title: Text(
          "Confirm Order",
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.black87),
        ),
        content: Text(
          "Place order for ₹${_pendingFinalTotal.toStringAsFixed(0)} via Cash on Delivery?",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx); 
              _finalizeOrder(paymentId: "CASH_ON_DELIVERY", paymentStatus: "COD");
            },
            child: Text("Confirm", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeOrder({required String paymentId, required String paymentStatus}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: CircularProgressIndicator(color: accentPink, strokeWidth: 2),
        ),
      ),
    );

    try {
      final String uid = currentUser?.uid ?? "GUEST";
      String finalName = userName.isEmpty || userName.toLowerCase() == 'guest' ? (currentUser?.displayName ?? "Guest User") : userName;
      String finalPhone = userPhone.isEmpty ? (currentUser?.phoneNumber ?? "") : userPhone;

      if (_appliedCoupon != null) {
        await FirebaseFirestore.instance.collection('coupons').doc(_appliedCoupon?['code']).update({
          'isUsed': true,
          'usedBy': currentUser?.email ?? finalPhone,
          'usedAt': FieldValue.serverTimestamp(),
        });
      }

      double gstAmount = (_pendingSubtotal * gstPercentage) / 100;

      final Map<String, dynamic> orderData = {
        'orderId': _pendingOrderId,
        'paymentId': paymentId,
        'userId': uid,
        'userName': finalName,
        'userPhone': finalPhone,
        'userAddress': userAddress,
        'receiverName': receiverName ?? finalName,
        'receiverPhone': receiverPhone ?? finalPhone,
        'totalPrice': _pendingFinalTotal,
        'status': paymentStatus, 
        'couponUsed': _appliedCoupon?['code'],
        'latitude': _selectedLat ?? 0.0,
        'longitude': _selectedLng ?? 0.0,
        'deliverySchedule': _pendingScheduleStr,
        'items': _pendingProcessedItems,
        'itemSubtotal': _pendingSubtotal,
        
        'deliveryFee': _pendingTotalDeliveryFee,
        'smallCartFee': _pendingSmallCartFee,
        'distanceFee': _pendingDistanceFee,
        'lateNightFee': _pendingLateNightFee,
        
        'discountAmount': _pendingDiscount,
        'gstAmount': gstAmount,
        'packingCharge': packingCharge,
        'platformFee': platformFee,
      };

      await FirebaseDatabase.instance.ref().child('users/$uid/orders/$_pendingOrderId').set({...orderData, 'createdAt': ServerValue.timestamp});
      await FirebaseFirestore.instance.collection('orders').doc(_pendingOrderId).set({...orderData, 'userEmail': currentUser?.email ?? "No Email", 'createdAt': FieldValue.serverTimestamp()});

      if (uid != "GUEST") {
        await FirebaseDatabase.instance.ref().child('users/$uid/cart').remove();
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSuccessDialog(_pendingOrderId, paymentStatus);
        
        Future.delayed(const Duration(milliseconds: 500), () {
        
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog("Order processing failed. Support ID: $paymentId");
    }
  }


  void _showSuccessDialog(String newOrderId, String status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              status == "COD" ? "Order Confirmed" : "Payment Successful",
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Order #${newOrderId.substring(newOrderId.length >= 6 ? newOrderId.length - 6 : 0)}",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            Text(
              status == "COD" 
                  ? "Your order has been placed and will be paid on delivery."
                  : "Your order has been received and is being processed.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: Text("BACK TO HOME", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
        content: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.black87, fontSize: 13, height: 1.5)),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Dismiss", style: GoogleFonts.inter(color: accentPink, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePayAction(
      double finalTotal, 
      List<Map<String, dynamic>> items, 
      double subtotal, 
      double smallCartFee, 
      double distanceFee, 
      double lateNightFee, 
      double discount) async {
      
    if (!hasAddress()) {
      _showLocationOptionsDialog();
      return;
    }

    int minMins = _getEarliestMins(items);
    DateTime earliestDelivery = _getEarliestValidDeliveryTime(minMins);
    
    final now = DateTime.now();
    DateTime todayOpen = DateTime(now.year, now.month, now.day, storeStartTime.hour, storeStartTime.minute);
    DateTime nextMorningOpen = todayOpen;
    if (now.isAfter(todayOpen) || now.isAtSameMomentAs(todayOpen)) {
      nextMorningOpen = todayOpen.add(const Duration(days: 1));
    }
    bool isDeliveryPossibleTonight = earliestDelivery.isBefore(nextMorningOpen) && isStoreOpenToday;

    if (!isDeliveryPossibleTonight && (selectedDate == null || selectedTime == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Delivery is unavailable right now. Please tap the calendar icon to schedule."))
        );
        return; 
    }

    String scheduleStr = "";
    
    // THE FIX: Created safe fallback variables so we never use '!'
    if (selectedDate != null && selectedTime != null) {
      final safeDate = selectedDate ?? DateTime.now();
      final safeTime = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
      
      DateTime startDT = DateTime(
        safeDate.year, safeDate.month, safeDate.day,
        safeTime.hour, safeTime.minute,
      );
      DateTime endDT = startDT.add(Duration(hours: globalSlotWindow));
      String startStr = DateFormat('h:mm a').format(startDT);
      String endStr = DateFormat('h:mm a').format(endDT);
      scheduleStr = "Scheduled: ${safeDate.day}/${safeDate.month} between $startStr to $endStr";
    } else {
      scheduleStr = _getDeliveryLabelText(items);
    }

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

    _pendingFinalTotal = finalTotal;
    _pendingOrderId = "BHS-${DateTime.now().millisecondsSinceEpoch}";
    _pendingScheduleStr = scheduleStr;
    _pendingProcessedItems = processedCartItems;
    
    _pendingSmallCartFee = smallCartFee;
    _pendingDistanceFee = distanceFee;
    _pendingLateNightFee = lateNightFee;
    _pendingTotalDeliveryFee = smallCartFee + distanceFee + lateNightFee;

    _pendingSubtotal = subtotal;
    _pendingDiscount = discount;

    if (_selectedPaymentMethod == 'ONLINE') {
      _startPayment();
    } else {
      _showCODConfirmationDialog();
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCouponSection(double subtotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("OFFERS"),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: accentPink, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "Apply Coupon Code",
                          hintStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_couponError, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (_appliedCoupon != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 32),
                        const Icon(Icons.verified, color: Colors.green, size: 14),
                        const SizedBox(width: 5),
                        Text("₹${_appliedCoupon?['discountAmount']} Off Applied!", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                          onPressed: () => setState(() => _appliedCoupon = null),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddonsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _addonsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data?.docs.isEmpty ?? true)) {
          return const SizedBox(); 
        }

        final addons = snapshot.data?.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: kPadding),
              child: _buildSectionTitle("FREQUENTLY BOUGHT TOGETHER"),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: kPadding, vertical: 8),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: (addons?.length ?? 0),
                itemBuilder: (context, index) {
                  final data = (addons?[index].data() as Map<String, dynamic>?) ?? {};
                  String imageUrl = data['image'] ?? data['imageUrl'] ?? '';
                  String name = data['name'] ?? 'Addon';
                  String rawPrice = data['price']?.toString() ?? '0';
                  
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              color: Colors.white,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: buildImage(imageUrl),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name, 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "₹$rawPrice", 
                                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12, color: accentPink),
                                    ),
                                    GestureDetector(
                                      onTap: () => _addAddonToCart(data),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: accentPink.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.add, size: 16, color: accentPink),
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: bgLight,
      body: StreamBuilder<DatabaseEvent>(
        stream: _cartStream,
        builder: (context, snapshot) {
          bool isCartLoading = snapshot.connectionState == ConnectionState.waiting;

          List<Map<String, dynamic>> itemsList = [];
          List<String> itemKeys = [];

          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
            final rawData = snapshot.data?.snapshot.value;
            if (rawData is Map) {
              rawData.forEach((key, value) {
                itemsList.add(Map<String, dynamic>.from(value));
                itemKeys.add(key.toString());
              });
            } else if (rawData is List) {
              for (int i = 0; i < rawData.length; i++) {
                if (rawData[i] != null) {
                  itemsList.add(Map<String, dynamic>.from(rawData[i]));
                  itemKeys.add(i.toString());
                }
              }
            }
          }

          double subtotal = _calculateTotal(itemsList);
          bool hasAddr = hasAddress();

          DateTime targetTime;
          
          // THE FIX: Created safe fallback variables so we never use '!'
          if (selectedDate != null && selectedTime != null) {
            final safeDate = selectedDate ?? DateTime.now();
            final safeTime = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
            targetTime = DateTime(safeDate.year, safeDate.month, safeDate.day, safeTime.hour, safeTime.minute);
          } else {
            targetTime = _getEarliestValidDeliveryTime(_getEarliestMins(itemsList));
          }

          bool isLateNight = _getActiveAfterHoursSlot(targetTime) != null;
          bool isCartOverThreshold = subtotal >= freeDeliveryThreshold;

          double appliedSmallCartFee = (!isCartOverThreshold && itemsList.isNotEmpty && hasAddr) ? smallCartFeeAmount : 0.0;
          double appliedLateNightFee = isLateNight && hasAddr ? lateNightPremiumAmount : 0.0;
          double appliedDistanceFee = (hasAddr && !isCartOverThreshold) ? calculateLiveDistanceFee() : 0.0;

          double totalDeliveryCharges = appliedSmallCartFee + appliedDistanceFee + appliedLateNightFee;

          double discount = 0.0;
          if (_appliedCoupon != null) {
            discount = (_appliedCoupon?['discountAmount'] as num?)?.toDouble() ?? 0.0;
          }

          double gstAmount = (subtotal * gstPercentage) / 100;
          double extraFeesTotal = gstAmount + packingCharge + platformFee;
          double finalTotal = (subtotal + totalDeliveryCharges + extraFeesTotal) - discount;

          double diffForFreeDelivery = freeDeliveryThreshold - subtotal;
          bool showFreeDeliveryPrompt = diffForFreeDelivery > 0 && itemsList.isNotEmpty;

          return Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildSliverAppBar(),

                      if (isCartLoading)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(kPadding, 20, kPadding, 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) => _buildSkeletonCartCard(), childCount: 4),
                          ),
                        )
                      else if (itemsList.isEmpty)
                        SliverFillRemaining(child: _buildEmptyState())
                      else ...[
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(kPadding, 20, kPadding, 10),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              final item = itemsList[index];
                              final key = itemKeys[index];
                              return Dismissible(
                                key: Key(key),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteItem(key),
                                background: _buildDeleteBackground(),
                                child: _buildCartCard(item, key),
                              );
                            }, childCount: itemsList.length),
                          ),
                        ),
                        
                        SliverToBoxAdapter(
                          child: _buildAddonsSection(),
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: kPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                _buildAddressScheduleCard(hasAddr, itemsList),
                                _buildCouponSection(subtotal),
                                
                                _buildPriceBreakdown(
                                  subtotal: subtotal,
                                  discount: discount,
                                  smallCartFee: appliedSmallCartFee,
                                  distanceFee: appliedDistanceFee,
                                  lateNightFee: appliedLateNightFee,
                                  showFreeDeliveryPrompt: showFreeDeliveryPrompt,
                                  diffForFreeDelivery: diffForFreeDelivery,
                                  finalTotal: finalTotal,
                                  gstAmount: gstAmount,        
                                  gstPercent: gstPercentage,  
                                  packing: packingCharge,     
                                  platform: platformFee,      
                                ),
                                const SizedBox(height: 250), 
                              ],
                            ),
                          ),
                        ),
                      ], 
                    ]
                  ), 
                ), 
              ), 
              
              if (isCartLoading)
                Positioned(
                  bottom: 0, left: 0, right: 0, 
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildSkeletonCheckoutPanel(),
                    ),
                  ),
                ),

              if (!isCartLoading && itemsList.isNotEmpty)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildStickyBottomBar(
                        items: itemsList,
                        hasAddress: hasAddr,
                        finalTotal: finalTotal,
                        subtotal: subtotal,
                        smallCartFee: appliedSmallCartFee,
                        distanceFee: appliedDistanceFee,
                        lateNightFee: appliedLateNightFee,
                        discount: discount,
                      ),
                    ),
                  ),
                ),

              if (isLoadingLocation) _buildLoadingOverlay(),
            ], 
          ); 
        }, 
      ), 
    ); 
  } 

  Widget _buildAddressScheduleCard(bool hasAddress, List<Map<String, dynamic>> items) {
    int minMins = _getEarliestMins(items); 
    String scheduleTextLabel = _getDeliveryLabelText(items); 

    Color timeColor = Colors.blue.shade700; 
    if (minMins > 0 && minMins <= 60) timeColor = Colors.green.shade700;   
    else if (minMins > 300) timeColor = Colors.red.shade700;     

    DateTime earliestDelivery = _getEarliestValidDeliveryTime(minMins);
    final now = DateTime.now();
    
    DateTime todayOpen = DateTime(now.year, now.month, now.day, storeStartTime.hour, storeStartTime.minute);
    DateTime nextMorningOpen = todayOpen;
    if (now.isAfter(todayOpen) || now.isAtSameMomentAs(todayOpen)) {
      nextMorningOpen = todayOpen.add(const Duration(days: 1));
    }
    bool isDeliveryPossibleTonight = earliestDelivery.isBefore(nextMorningOpen) && isStoreOpenToday;

    Widget scheduleWidget;

    // THE FIX: Created safe fallback variables so we never use '!'
    if (selectedDate != null && selectedTime != null) {
      final safeDate = selectedDate ?? DateTime.now();
      final safeTime = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
      
      DateTime start = DateTime(safeDate.year, safeDate.month, safeDate.day, safeTime.hour, safeTime.minute);
      DateTime end = start.add(Duration(hours: globalSlotWindow));
      scheduleWidget = Text(
        "Scheduled: ${safeDate.day}/${safeDate.month} between ${DateFormat('h:mm a').format(start)} to ${DateFormat('h:mm a').format(end)}",
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      );
    } else {
      if (isDeliveryPossibleTonight) {
        if (now.isBefore(todayOpen)) {
          scheduleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Store opens at ${storeStartTime.format(context)}", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange[800])),
              const SizedBox(height: 2),
              Text(scheduleTextLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: timeColor)),
            ],
          );
        } else {
          var activeSlot = _getActiveAfterHoursSlot(earliestDelivery);
          if (activeSlot != null) {
             scheduleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("After Hours Premium Applies", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                const SizedBox(height: 2),
                Text(scheduleTextLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: timeColor)),
              ],
            );
          } else {
            scheduleWidget = Text(scheduleTextLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: timeColor));
          }
        }
      } else {
        scheduleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scheduleTextLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, color: Colors.grey)),
            const SizedBox(height: 2),
            Text("Too late for today. Tap to schedule.", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("DELIVERY DETAILS"),
        _buildCard(
          child: Column(
            children: [
              InkWell(
                onTap: _showLocationOptionsDialog,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: !hasAddress ? accentPink.withOpacity(0.1) : Colors.blue.shade50, shape: BoxShape.circle),
                        child: Icon(
                          !hasAddress ? Icons.add_location_alt_rounded : Icons.location_on_rounded,
                          color: !hasAddress ? accentPink : Colors.blueAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !hasAddress ? "Add Delivery Address" : "Deliver to",
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              !hasAddress ? "Tap to add location" : userAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100, indent: 60),
              InkWell(
                onTap: () => _selectDeliveryDate(minMins),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                        child: Icon(
                          Icons.access_time_rounded,
                          color: (!isDeliveryPossibleTonight && selectedDate == null) ? Colors.red.shade500 : (selectedDate == null ? timeColor : Colors.green),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Delivery Time", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            scheduleWidget,
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPriceBreakdown({
    required double subtotal,
    required double discount,
    required double smallCartFee,
    required double distanceFee,
    required double lateNightFee,
    required bool showFreeDeliveryPrompt,
    required double diffForFreeDelivery,
    required double finalTotal,
    required double gstAmount,
    required double gstPercent,
    required int packing,
    required int platform,
  }) {
    double otherPaymentsTotal = gstAmount + packing + platform;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("BILL DETAILS"),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildPriceRow("Item Total", "₹${subtotal.toStringAsFixed(0)}"),
                
                if (discount > 0) ...[
                  const SizedBox(height: 12),
                  _buildPriceRow("Coupon Discount", "-₹${discount.toStringAsFixed(0)}", 
                    color: Colors.green.shade700, isBold: true),
                ],

                if (otherPaymentsTotal > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("GST and Other Payments", style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showGstInfoDialog(gstAmount, packing, platform),
                            child: Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      Text("₹${otherPaymentsTotal.toStringAsFixed(0)}", style: GoogleFonts.montserrat(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                if (smallCartFee > 0) ...[
                  const SizedBox(height: 12),
                  _buildPriceRow("Small Order Fee", "₹${smallCartFee.toStringAsFixed(0)}"),
                ],

                if (distanceFee > 0) ...[
                  const SizedBox(height: 12),
                  _buildPriceRow("Distance Fee (${_getRawDistance().toStringAsFixed(1)} KM)", "₹${distanceFee.toStringAsFixed(0)}"),
                ],

                if (lateNightFee > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Late Night Premium", style: GoogleFonts.inter(color: Colors.purple.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showLateNightInfoDialog(),
                            child: Icon(Icons.info_outline_rounded, size: 14, color: Colors.purple.shade300),
                          ),
                        ],
                      ),
                      Text("₹${lateNightFee.toStringAsFixed(0)}", style: GoogleFonts.montserrat(color: Colors.purple.shade700, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],

                if (showFreeDeliveryPrompt)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.orange.shade800, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Add ₹${diffForFreeDelivery.toStringAsFixed(0)} more for FREE standard delivery!", style: GoogleFonts.inter(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ),

                _buildPriceRow("Grand Total", "₹${finalTotal.toStringAsFixed(0)}", isTotal: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLateNightInfoDialog() {
    DateTime now = DateTime.now();
    int prepMins = _getEarliestMins([]); 
    DateTime arrivalStart = now.add(Duration(minutes: prepMins)); 
    DateTime arrivalEnd = arrivalStart.add(const Duration(hours: 1));

    String openStr = DateFormat('h:mm a').format(DateTime(2026, 1, 1, storeStartTime.hour, storeStartTime.minute));
    String closeStr = DateFormat('h:mm a').format(DateTime(2026, 1, 1, storeEndTime.hour, storeEndTime.minute));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Late Night Delivery", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBullet("Shop Hours", "$openStr - $closeStr"),
            _infoBullet("Estimated Arrival", "${DateFormat('h:mm a').format(arrivalStart)} to ${DateFormat('h:mm a').format(arrivalEnd)}"),
            _infoBullet("Premium Rate", "₹$globalChargePerKm per KM"),
            const SizedBox(height: 12),
            Text("Extra charges apply because your selected delivery time falls outside our standard operating hours.", 
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Got it", style: TextStyle(color: accentPink, fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  void _showGstInfoDialog(double gst, int packing, int platform) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Fee Breakdown", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _feeRow("Goods & Service Tax", gst),
            _feeRow("Packing & Handling", packing.toDouble()),
            _feeRow("Platform Service Fee", platform.toDouble()),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text("₹${(gst + packing + platform).toStringAsFixed(1)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: accentPink)),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Close", style: TextStyle(color: Colors.black87)))
        ],
      ),
    );
  }

  Widget _infoBullet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: "$label: ", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
        TextSpan(text: value, style: GoogleFonts.inter(color: accentPink, fontWeight: FontWeight.w600)),
      ])),
    );
  }

  Widget _feeRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
          Text("₹${value.toStringAsFixed(1)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: isTotal ? Colors.black87 : Colors.grey.shade600,
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            color: color ?? (isTotal ? Colors.black : Colors.black87),
            fontSize: isTotal ? 20 : 13,
            fontWeight: isBold || isTotal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar({
    required List<Map<String, dynamic>> items,
    required bool hasAddress,
    required double finalTotal,
    required double subtotal,
    required double smallCartFee,
    required double distanceFee,
    required double lateNightFee,
    required double discount,
  }) {
    
    String buttonText;
    if (!hasAddress) {
      buttonText = "SELECT ADDRESS";
    } else if (_selectedPaymentMethod == 'COD') {
      buttonText = "CONFIRM ₹${finalTotal.toStringAsFixed(0)}";
    } else {
      buttonText = "PAY ₹${finalTotal.toStringAsFixed(0)} NOW";
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _buildPaymentToggleItem("ONLINE", Icons.bolt_rounded, "Pay Online"),
                _buildPaymentToggleItem("COD", Icons.handshake_rounded, "Cash on Delivery"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: !hasAddress ? Colors.grey.shade900 : accentPink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              onPressed: () => _handlePayAction(finalTotal, items, subtotal, smallCartFee, distanceFee, lateNightFee, discount),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  buttonText,
                  key: ValueKey(buttonText),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentToggleItem(String code, IconData icon, String label) {
    bool isSelected = _selectedPaymentMethod == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedPaymentMethod = code);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? accentPink : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: isSelected ? Colors.black87 : Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Checkout",
        style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B),
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildSkeletonCartCard() {
    return PulsingSkeleton(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 75, height: 75, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  Container(height: 12, width: 140, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12.0),
                  Container(height: 20, width: 100, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 14),
                  Container(height: 14, width: 60, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCheckoutPanel() {
    return PulsingSkeleton(
      child: Container(
        height: 200,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      ),
    );
  }

 Widget _buildCartCard(Map<String, dynamic> item, String itemKey) {
    String flavourText = formatFlavours(item['flavours']);
    String cakeWriting = (item['cakeWriting'] ?? '').toString();
    String weight = (item['selected_weight'] ?? item['weight'] ?? "N/A").toString();
    String shape = (item['selected_shape'] ?? item['shape'] ?? "Standard").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildImage(item['image'] ?? ""),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 2),
                Text(
                  item['name'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    if (weight != "N/A") _attributePill(Icons.scale_rounded, weight),
                    if (shape != "Standard") _attributePill(Icons.interests_rounded, shape),
                    if (cakeWriting.isNotEmpty && cakeWriting != "No Message")
                      _attributePill(Icons.edit_note_rounded, "Msg: $cakeWriting"),
                    if (flavourText.isNotEmpty)
                      _attributePill(Icons.local_dining_rounded, flavourText),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['display_price'] ?? "₹ ${item['price']}",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: accentPink,
                      ),
                    ),
                    Text(
                      "Qty: ${item['quantity'] ?? 1}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_left_rounded, 
                  color: Colors.red.shade200, 
                  size: 20
                ),
                Text(
                  "SWIPE",
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade200,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  void _showAddressDetailsEntrySheet(String detectedArea, {double? lat, double? lng, required double fee, required String zoneName}) {
    final TextEditingController areaCtrl = TextEditingController(text: detectedArea);
    final TextEditingController houseCtrl = TextEditingController();
    final TextEditingController landmarkCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    String selectedLabel = "Home";

    StateSetter? sheetSetState;

    void onPhoneChanged() {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userPhone = user.phoneNumber ?? "";
        String uName = user.displayName ?? (user.email?.split('@')[0] ?? "");
        String enteredPhone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');
        String registeredPhone = userPhone.replaceAll(RegExp(r'[^0-9+]'), '');

        if (registeredPhone.isNotEmpty) {
          bool isSameNumber = (enteredPhone == registeredPhone) || (enteredPhone.length >= 10 && registeredPhone.endsWith(enteredPhone));
          if (isSameNumber) {
            if (nameCtrl.text != uName) nameCtrl.text = uName;
          } else {
            if (nameCtrl.text == uName) nameCtrl.clear();
          }
        }
      }
      if (sheetSetState != null) sheetSetState!((){});
    }

    phoneCtrl.addListener(onPhoneChanged);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateLocal) {
            sheetSetState = setStateLocal;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(35)), border: Border.all(color: Colors.white, width: 2)),
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
                                  Expanded(flex: 5, child: _buildInput(phoneCtrl, "Receiver's Number", Icons.phone_rounded, keyboardType: TextInputType.phone)),
                                  const SizedBox(width: 10),
                                  if (phoneCtrl.text.isEmpty)
                                    Expanded(
                                      flex: 4,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user != null && (user.phoneNumber?.isNotEmpty ?? false)) {
                                            phoneCtrl.text = user.phoneNumber ?? '';
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
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
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
                                    
                                    final String finalMapsLink = "http://googleusercontent.com/maps.google.com/?q=${lat ?? 0},${lng ?? 0}";
                                    
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
                                        'googleMapsLink': finalMapsLink,
                                        'createdAt': FieldValue.serverTimestamp(),
                                        'type': 'Current Location',
                                        'deliveryFee': fee, 
                                        'zoneName': zoneName,
                                      });
                                    }

                                    setState(() {
                                      userAddress = finalAddr;
                                      receiverName = nameCtrl.text.trim();
                                      receiverPhone = phoneCtrl.text.trim();
                                      _selectedLat = lat;
                                      _selectedLng = lng;
                                      _baseDistanceFee = fee;
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
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => phoneCtrl.removeListener(onPhoneChanged));
  }

  Widget _buildLabelChipSheet(String label, IconData icon, String currentSelection, void Function(String) onSelect) {
    bool isSelected = currentSelection == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade800)),
          ],
        ),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    Text("SAVED ADDRESSES", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.5)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid ?? 'GUEST').collection('addresses').orderBy('createdAt', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: accentPink));
                          final docs = snapshot.data?.docs;
                          if (!snapshot.hasData || (docs?.isEmpty ?? true)) return Center(child: Text("No saved addresses yet.", style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w500)));

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: (docs?.length ?? 0),
                            separatorBuilder: (context, index) => const Divider(height: 30),
                            itemBuilder: (context, index) {
                              final doc = docs?[index];
                              final data = (doc?.data() as Map<String, dynamic>?) ?? {};
                              String label = data['label'] ?? 'Other';
                              IconData labelIcon = label == 'Home' ? Icons.home_rounded : (label == 'Work' ? Icons.work_rounded : Icons.location_on_rounded);

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
                                          _baseDistanceFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                                        });
                                      },
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
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
                                                    Expanded(child: Text(data['receiverName'] ?? 'Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
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
                                    onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(currentUser?.uid ?? 'GUEST').collection('addresses').doc(doc?.id ?? '').delete(); },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 40),
                    Text("ADD NEW ADDRESS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.5)),
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
                              _determinePosition(); 
                            }
                          )
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildLocationActionBtn(
                            "Select on\nMap", 
                            Icons.map_outlined, 
                            Colors.orangeAccent, 
                            () async {
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
                                  _baseDistanceFee = (result['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                                });
                              }
                            }
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
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
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, height: 1.3, color: Colors.black87)),
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
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 30),
          Text("Your basket is empty", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 22, color: Colors.black87)),
          const SizedBox(height: 8),
          Text("Add some delicious treats!", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 35),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text("BROWSE MENU", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100, 
        borderRadius: BorderRadius.circular(12)
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 18),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget buildImage(String imageString, {double radius = 18}) {
    Widget image;
    try {
      if (imageString.startsWith('assets/')) image = Image.asset(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true);
      else if (imageString.startsWith('http')) image = Image.network(imageString, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true);
      else {
        Uint8List imageBytes;
        if (_memoryImageCache.containsKey(imageString)) imageBytes = _memoryImageCache[imageString] ?? Uint8List(0);
        else {
          imageBytes = base64Decode(imageString);
          _memoryImageCache[imageString] = imageBytes;
        }
        image = Image.memory(imageBytes, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true);
      }
    } catch (e) {
      image = const Icon(Icons.broken_image, color: Colors.black26);
    }
    return image;
  }

  Widget _attributePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: Tween<double>(begin: 0.3, end: 0.8).animate(_controller), child: widget.child);
  }
}