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
import 'package:project/location.dart';
import 'package:project/orderpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:geocoding/geocoding.dart';   // Import Geocoding

// Your imports...
import 'package:project/cartpage1.dart';
import 'package:project/cakepage.dart' as cake;
import 'package:project/cupcakepage.dart';
import 'package:project/customisepage.dart';
import 'package:project/popsiclepage.dart' as popsicle;
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

class _SecondpageState extends State<Secondpage> {
  PageController? _pageController;
  Timer? _timer;
  String userName = "Guest";
  String userAddress = "Select Location"; // Default address text
  int _currentIndex = 0;
  bool _showGpsFields = false;
  bool _isProfileExpanded = false;

Widget _buildAnimatedProfileButton(bool isMobile) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

    // 🟢 DYNAMIC SIZING LOGIC
    final double height = _isProfileExpanded 
        ? (isMobile ? 35.0 : 42.0) 
        : (isMobile ? 35.0 : 50.0);

    final double collapsedWidth = height; 
    final double expandedWidth = isMobile ? 120.0 : 160.0; // Slightly wider to fit names

    final double avatarSize = _isProfileExpanded 
        ? (isMobile ? 24.0 : 30.0) 
        : (isMobile ? 25.0 : 38.0);
        
    final double iconSize = _isProfileExpanded 
        ? (isMobile ? 16.0 : 20.0) 
        : (isMobile ? 20.0 : 24.0);

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
            // 🟢 Wait for return, then reload
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const Profilepage2()));
            _loadUserData(); 
          } else {
            // 🟢 Wait for return, then reload
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const Loginpage2()));
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
            width: 1.5
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
                // 1. AVATAR
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: avatarSize, 
                  height: avatarSize, 
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    backgroundImage: (isLoggedIn && user?.photoURL != null)
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: (isLoggedIn && user?.photoURL != null)
                        ? null
                        : Icon(
                            isLoggedIn ? Icons.person_2_sharp : Icons.person_2_outlined, 
                            color: Colors.white,
                            size: iconSize 
                          ),
                  ),
                ),

                // 2. LIVE NAME TEXT
                if (_isProfileExpanded) ...[
                  SizedBox(width: paddingGap),
                  // 🟢 THIS IS THE FIX: Uses the live stream widget
                  _buildLiveUserNameText(fontSize, Colors.white),
                  SizedBox(width: paddingGap),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 LIVE NAME WIDGET (Listens to Firebase)
 Widget _buildLiveUserNameText(double fontSize, Color color) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) return Text("LOGIN", style: GoogleFonts.montserrat(fontSize: fontSize, color: color, fontWeight: FontWeight.bold));

  return StreamBuilder<DocumentSnapshot>(
    // 🟢 This stream listens to the database 24/7
    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
    builder: (context, snapshot) {
      String nameToShow = "BAKER";

      if (snapshot.hasData && snapshot.data!.exists) {
        final data = snapshot.data!.data() as Map<String, dynamic>;
        // 🟢 Read 'username' field specifically
        if (data['username'] != null && data['username'].toString().isNotEmpty) {
          nameToShow = data['username'];
        }
      } else if (user.displayName != null) {
        nameToShow = user.displayName!;
      }

      // Format to show only the first name in Uppercase
      nameToShow = nameToShow.split(' ')[0].toUpperCase();

      return Text(
        nameToShow,
        style: GoogleFonts.montserrat(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      );
    },
  );
}
  final String allowedCity = "Kochi"; 
  
  // Theme Colors
  final Color _accentPink = const Color.fromARGB(255, 218, 0, 138);
  final Color _bgBlack = const Color(0xFF050505);

  final List<String> cakeImages = [
    "assets/cake.jpg", 
    "assets/cupcake.jpg",
    // "assets/cakepop.jpg",
    "assets/customise.jpg",
  ];

  final List<String> cakeNames = [
    "Cakes",
    "Cup Cakes",
    // "Popsicles & Cakesicles",
    "Customise Your Cake",
  ];

  static const int _initialPage = 1000;
  final TextEditingController _manualAddressController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _homeController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    _startAutoSlider();
    
    // Trigger the location prompt after the page builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
    
    });
  }

  // --- Location Logic ---

 // ---------------------------------------------------------------------------
  // 2. FETCH CURRENT LOCATION & CHECK DELIVERY ZONE BY DISTANCE
  // ---------------------------------------------------------------------------
  Future<void> _determinePosition() async {
    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74))));

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context);
        _showSnackBar("Please enable Location Services (GPS)");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Navigator.pop(context);
          _showSnackBar("Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Navigator.pop(context);
        _showSnackBar("Location permissions permanently denied");
        return;
      }

      // Fetch Position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // 🟢 DISTANCE CHECK (Replaces the broken text matching!)
      double shopLat = 9.9312; // Update to your exact shop lat if needed
      double shopLng = 76.2673; // Update to your exact shop lng if needed
      double maxRadius = 15000; // Default 15 km
      
      // Attempt to pull exact radius from Firebase
      try {
        final doc = await FirebaseFirestore.instance.collection('settings').doc('delivery_zone').get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          shopLat = (doc.data()!['lat'] as num).toDouble();
          shopLng = (doc.data()!['lng'] as num).toDouble();
          maxRadius = (doc.data()!['radius'] as num).toDouble();
        }
      } catch (e) {
        debugPrint("Failed to fetch custom zone, using default 15km.");
      }

      // Calculate distance mathematically
      double distanceInMeters = Geolocator.distanceBetween(shopLat, shopLng, position.latitude, position.longitude);

      if (distanceInMeters > maxRadius) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [const Icon(Icons.block_flipped, color: Colors.redAccent, size: 28), const SizedBox(width: 10), Text("Out of Zone", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: Colors.black))]),
              content: Text("Sorry, your location is ${(distanceInMeters / 1000).toStringAsFixed(1)} km away. We only deliver within ${(maxRadius / 1000).toStringAsFixed(0)} km.", style: GoogleFonts.inter(color: Colors.black87)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: GoogleFonts.inter(color: const Color(0xFFFF2E74), fontWeight: FontWeight.bold)))],
            )
          );
        }
        return; 
      }

      // 🟢 IN ZONE: Decode Address
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
      Navigator.pop(context); // Close loading
      
      // Trigger the bottom sheet
      _showAddressDetailsEntrySheet(detectedArea, lat: position.latitude, lng: position.longitude);

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Failed to get location.");
      }
    }
  }
  void _showGpsDetailsInput(String baseAddress) {
  final TextEditingController houseController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "COMPLETE YOUR ADDRESS",
                  style: GoogleFonts.montserrat(
                    color: _accentPink,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  baseAddress,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),
                
                // Field 1: House / Flat No.
                _buildTransparentField(houseController, "House / Flat No.", Icons.home_work_outlined),
                const SizedBox(height: 12),
                
                // Field 2: Area / Road
                _buildTransparentField(areaController, "Area / Road / Colony", Icons.add_road_rounded),
                const SizedBox(height: 12),
                
                // Field 3: Landmark (Optional)
                _buildTransparentField(landmarkController, "Landmark (Optional)", Icons.assistant_photo_outlined),
                
                const SizedBox(height: 25),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () async {
                      if (houseController.text.isEmpty || areaController.text.isEmpty) {
                        _showSnackBar("Please fill House and Area details");
                        return;
                      }
                      
                      final String finalAddress = 
                          "${houseController.text}, ${areaController.text}, ${landmarkController.text.isNotEmpty ? landmarkController.text + ', ' : ''} $baseAddress";

                      setState(() {
                        userAddress = finalAddress;
                        _manualAddressController.text = finalAddress;
                      });

                      // Optional: Save to Firebase for the user
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            
                            .collection('addresses')
                            .add({
                          'fullAddress': finalAddress,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      }

                      Navigator.pop(context);
                      _showSnackBar("Location confirmed!");
                    },
                    child: const Text("CONFIRM ADDRESS", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

 Future<void> _getAddressFromLatLng(Position position) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude);

    Placemark place = placemarks[0];
    // Create a base string from GPS data (locality and district)
    String gpsDetectedBase = "${place.locality}, ${place.subAdministrativeArea}";

    // Check if serviceable (Kochi)
    if (gpsDetectedBase.contains(allowedCity)) {
      // 🟢 SUCCESS: Open the 3-field input container
      if (Navigator.canPop(context)) Navigator.pop(context); // Close loading if open
      _showGpsDetailsInput(gpsDetectedBase); 
    } else {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showErrorDialog("Sorry! We currently no servies on your location.");
    }
  } catch (e) {
    debugPrint("Geocoding failed: $e");
  }
}
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.montserrat()), backgroundColor: _accentPink),
    );
  }

 

// Helper widget for detail fields
Widget _buildTransparentField(TextEditingController controller, String hint, IconData icon) {
  return TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        content: Text(
          message, 
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: Colors.white)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white54)),
          )
        ],
      )
    );
  }
void _showGpsAddressInputDialog(String baseAddress) {
  final TextEditingController houseController = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CONFIRM ADDRESS",
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  baseAddress,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: houseController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "House / Flat / Landmark",
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      final fullAddress =
                          "${houseController.text}, $baseAddress";

                      setState(() {
                        userAddress = fullAddress;
                        _manualAddressController.text = fullAddress;
                      });

                      Navigator.pop(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "CONFIRM ADDRESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}


// Place this INSIDE _SecondpageState class  

// ---------------------------------------------------------------------------
  // 1. SAVED ADDRESSES & OPTIONS BOTTOM SHEET
  // ---------------------------------------------------------------------------
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              
              Text("SAVED ADDRESSES", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1)),
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
                                // 🟢 Delete from Firebase
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('addresses').doc(doc.id).delete();
                                // 🟢 Refresh User Data immediately so if empty, it triggers live GPS
                                _loadUserData();
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
                        userAddress = result['address']?.split(',').last.trim() ?? "Location Set";
                        _manualAddressController.text = userAddress;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setString('userAddress', userAddress);
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
                                userAddress = areaCtrl.text.trim();
                                // Note: In Cartpage1, make sure to also update _selectedLat, _selectedLng here if needed
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

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
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
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _accentPink.withOpacity(0.5))),
        ),
      ),
    );
  }
  Widget _buildGlassAddressTile({
    required String address,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.pinkAccent.withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.pinkAccent.withOpacity(0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.history,
              color: isSelected ? Colors.pinkAccent : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget 2: The Action Button ---
  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: color.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: color.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
// --- Helper for the Glassmorphism List Item ---

  void _initController(bool isMobile) {
    double targetFraction = isMobile ? 0.8 : 0.6;
    if (_pageController == null || _pageController!.viewportFraction != targetFraction) {
      _pageController?.dispose();
      _pageController = PageController(
        viewportFraction: targetFraction,
        initialPage: _initialPage,
      );
    }
  }

  void _startAutoSlider() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.nextPage(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }
Future<void> _loadUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    String loadedName = prefs.getString('username') ?? "User";

    if (mounted) {
      setState(() {
        userName = user == null ? "Guest" : loadedName;
        userAddress = "Locating..."; 
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

    // 2. LIVE GPS FETCH (If no saved addresses exist)
    if (!foundSavedAddress) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw 'GPS Disabled';

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) throw 'Permission Denied';
        }
        if (permission == LocationPermission.deniedForever) throw 'Permission Denied Forever';

        Position? position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 5));

        if (!kIsWeb) {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            String finalAreaName = place.subLocality ?? place.locality ?? place.administrativeArea ?? "";
            
            if (finalAreaName.isNotEmpty) {
              if (mounted) setState(() { 
                userAddress = finalAreaName; 
                _manualAddressController.text = finalAreaName;
              });
              return; 
            }
          }
        }
      } catch (e) {
        debugPrint("Auto-location failed: $e");
      }

      // 3. FINAL FALLBACK
      if (mounted) {
        setState(() {
          userAddress = "Select Location"; 
        });
      }
    }
  }
  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }

  int _getRealIndex(int index) {
    return index % cakeImages.length;
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.1), 
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.0), width: 1),
    );
  }

 @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;

    _initController(isMobile);

    return StreamBuilder<DocumentSnapshot>(
      // 🟢 Monitor Shop Status
      stream: FirebaseFirestore.instance.collection('settings').doc('store_status').snapshots(),
      builder: (context, statusSnapshot) {
        bool isStoreClosed = false;
        String busyMessage = "We are currently busy baking delicious treats!";
        DateTime? resumeTime;

        if (statusSnapshot.hasData && statusSnapshot.data!.exists) {
          final data = statusSnapshot.data!.data() as Map<String, dynamic>;
          bool isOpen = data['isOpen'] ?? true;
          resumeTime = data['resumeAt'] != null ? (data['resumeAt'] as Timestamp).toDate() : null;
          
          if (!isOpen && (resumeTime == null || resumeTime.isAfter(DateTime.now()))) {
            isStoreClosed = true;
            busyMessage = data['message'] ?? busyMessage;
          }
        }

        return Scaffold(
          backgroundColor: _bgBlack,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 1. Normal Home Content
              ScrollConfiguration(
                behavior: DesktopScrollBehavior(),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    _buildBackground(size),
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildGlassAppBar(isMobile),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  const SizedBox(height: 40),
                                  _buildHeaderText(),
                                  const SizedBox(height: 55),
                                  _buildSliderSection(isMobile, size),
                                  const SizedBox(height: 50),
                                  _buildFooterText(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Tracker for Normal Mode
              if (!isStoreClosed) 
                const Positioned(bottom: 20, left: 20, right: 20, child: LiveOrderTracker()),

              // 3. 🟢 FULL SCREEN BUSY OVERLAY
              if (isStoreClosed) _buildBusyOverlay(busyMessage, resumeTime),

              // 4. 🟢 Tracker for Busy Mode (Floats over the blur)
              if (isStoreClosed) 
                const Positioned(bottom: 40, left: 20, right: 20, child: LiveOrderTracker()),
            ],
          ),
        );
      },
    );
  }
  Widget _buildBusyOverlay(String message, DateTime? resumeTime) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Frosted glass effect
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with pulsing glow
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentPink.withOpacity(0.1),
                      border: Border.all(color: _accentPink.withOpacity(0.3), width: 2),
                    ),
                    child: Icon(Icons. restaurant_menu_rounded, color: _accentPink, size: 50),
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
                  
                  // Countdown or "Check back later"
                  if (resumeTime != null) ...[
                    Text("OPENING AT", style: GoogleFonts.montserrat(color: _accentPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    const SizedBox(height: 10),
                    Text(
                      DateFormat('hh:mm a').format(resumeTime),
                      style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text("TEMPORARILY CLOSED", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ],
                  
                  const SizedBox(height: 80),
                  // Small logo at bottom
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
  Widget _buildFooterText() {
    return Column(
      children: [
        Text(
       "\"Celebrate every moment \n with Butter Hearts Cakes.\"",
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(color: Colors.white70, fontSize: 14),
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
                  Colors.black.withOpacity(0.5), 
                  Colors.black.withOpacity(0.0), 
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.0)
                ],
                stops: const [0.0, 0.5, 0.85, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(color: const Color.fromARGB(255, 163, 163, 163).withOpacity(0.1)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🟢 PREMIUM GLASS APP BAR (Full Code)
  // ---------------------------------------------------------------------------
Widget _buildGlassAppBar(bool isMobile) {
  // 🟢 SMOOTH ANIMATION LOGIC
  // If expanded (Guest clicking Location/Cart OR anyone clicking Profile), shrink text.
  final double targetFontSize = _isProfileExpanded
      ? (isMobile ? 12.0 : 16.0) // Small Size (Shrunk)
      : (isMobile ? 15.0 : 24.0); // Normal Size (Big)

  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 30,
          vertical: isMobile ? 10 : 20,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 10 : 16),
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
                    color: Colors.white.withOpacity(0.12), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- LEFT SIDE: LOGO & LOCATION ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          // 🟢 1. ANIMATED TEXT STYLE WRAPPER
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300), // Same speed as button
                            curve: Curves.easeOutBack, // Same bounce effect
                            style: GoogleFonts.oswald(
                              fontSize: targetFontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              shadows: [
                                const Shadow(
                                    color: Colors.black45, blurRadius: 10)
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
                            Flexible(
                              child: _buildLocationPill(isMobile),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- RIGHT SIDE: ACTIONS ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🟢 2. SMOOTH CART HIDE (Mobile Only)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack, // Matches text animation
                        child: SizedBox(
                          // If Mobile AND Expanded -> Width becomes 0
                          width: (isMobile && _isProfileExpanded)
                              ? 0.0
                              : null,
                          child: (isMobile && _isProfileExpanded)
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCartIconWithBadge(isMobile),
                                    SizedBox(
                                        width: isMobile ? 12 : 24), // Gap
                                  ],
                                ),
                        ),
                      ),

                      // Profile Button (Always Visible)
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
          if (user == null) {
            if (!_isProfileExpanded) {
              setState(() {
                _isProfileExpanded = true;
              });
              Future.delayed(const Duration(seconds: 3), () {
                 if (mounted && _isProfileExpanded) {
                   setState(() => _isProfileExpanded = false);
                 }
              });
            }
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
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
Widget _buildCartIconWithBadge(bool isMobile) {
  int count = 0;
  try { count = cake.cartList.length; } catch (e) { count = 0; }

  // 🟢 DYNAMIC SIZING LOGIC
  // If expanded: Shrink to 18.0 (Mobile) / 22.0 (Web)
  // If normal:   Keep at 22.0 (Mobile) / 26.0 (Web)
  final double iconSize = _isProfileExpanded 
      ? (isMobile ? 18.0 : 22.0) 
      : (isMobile ? 18.0 : 20.0);

  final double padding = _isProfileExpanded 
      ? (isMobile ? 6.0 : 10.0) 
      : (isMobile ? 10.0 : 14.0);
      
  final double badgeSize = isMobile ? 16.0 : 19.0;
  final double fontSize  = isMobile ? 9.0 : 11.0;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300), // Smooth resize animation
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
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => Cartpage1(initialAddress: userAddress)));
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
                border: isMobile 
                    ? null 
                    : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Icon(
                Icons.shopping_bag_outlined, 
                color: Colors.white, 
                size: iconSize // 🟢 Animated Size
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
                      BoxShadow(color: _accentPink.withOpacity(0.5), blurRadius: 8)
                    ],
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: fontSize, 
                      fontWeight: FontWeight.bold
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
  Widget _profileDropdown(bool isMobile) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        ),
      ),
      child: PopupMenuButton<String>(
        elevation: 20,
        offset: const Offset(0, 50),
        tooltip: "Account",
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ),
        onSelected: (value) async {
          final User? user = FirebaseAuth.instance.currentUser;
          if (value == 'login') {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => Loginpage2()));
            _loadUserData();
          } else if (value == 'profile') {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => const Profilepage2()));
             _loadUserData();
         // ... inside _profileDropdown ...
        } else if (value == 'logout') {
            await FirebaseAuth.instance.signOut();
            final SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.remove('username');
            
            setState(() {
              userName = "Guest";
              userAddress = "Select Location"; // 🟢 Clear Address
            });
            
            try {
              cake.cartList.clear(); // 🟢 Clear Cart
            } catch (e) {}

            _showSnackBar("Logged out successfully");
          }
        // ...
        },
        itemBuilder: (context) {
          final User? user = FirebaseAuth.instance.currentUser;
          return [
            if (user == null)
              _buildPopupItem('login', Icons.login_rounded, "Login", Colors.white),
            
            if (user != null) ...[
              // Header (Non-clickable info)
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(user.email ?? "", style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
                    const Divider(color: Colors.white12, height: 20),
                  ],
                ),
              ),
              _buildPopupItem('profile', Icons.person_outline_rounded, "My Profile", Colors.white),
              _buildPopupItem('logout', Icons.logout_rounded, "Logout", _accentPink),
            ]
          ];
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
  // New Widget for Location in AppBar
Widget _buildLocationWidget(bool isMobile) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () {
        // --- ADDED AUTH CHECK HERE ---
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _showSnackBar("Please login to set your delivery location");
          // Optional: Navigate to login page automatically
          // Navigator.push(context, MaterialPageRoute(builder: (context) => Loginpage2()));
        } else {
          _showLocationDetailsDialog();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black45,
              child: Icon(Icons.location_on_outlined, color: Colors.white, size: 16),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  userAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
            ]
          ],
        ),
      ),
    ),
  );
}
  Widget _buildHeaderText() {
    return Column(
      children: [
        const SizedBox(height: 0),
        Text(
          "Baked with Love,",
          style: GoogleFonts.playfairDisplay( 
            fontSize: 16, 
            color: Colors.white70,
            fontStyle: FontStyle.italic
          ),
        ),
        Text(
          "Served with Heart",
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
        
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSection(bool isMobile, Size size) {
    double height = isMobile ? 350 : 500;
    double width = isMobile ? size.width : 900; 

    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final realIndex = _getRealIndex(index);
              return AnimatedBuilder(
                animation: _pageController!,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController!.position.haveDimensions) {
                    value = _pageController!.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.85, 1.0);
                  }
                  return Center(
                    child: Transform.scale(
                      scale: value,
                      child: child
                    ),
                  );
                },
                child: _buildSliderCard(realIndex, isMobile),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderCard(int index, bool isMobile) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: isMobile ? double.infinity : 600, 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.0),
              blurRadius: 25,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(cakeImages[index], fit: BoxFit.cover),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color.fromARGB(255, 0, 0, 0).withOpacity(0.0),
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.0),
                      ],
                      stops: const [0.5, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      cakeNames[index].toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      width: 50.0, height: 3.0,
                      decoration: BoxDecoration(color: _accentPink, borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 25),
                    _buildExploreButton(index),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreButton(int index) {
    return GestureDetector(
      onTap: () async {
        Widget targetPage;
        try {
          switch (cakeNames[index]) {
            case "Cakes":
              targetPage = const cake.Cakepage();
              break;
            case "Cup Cakes":
              targetPage = const Cupcakepage();
              break;
         
             
            default:
              targetPage = const Customisepage();
          }
          await Navigator.push(context, MaterialPageRoute(builder: (_) => targetPage));
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint("Navigation Error: $e");
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        decoration: BoxDecoration(
          color: _accentPink,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Explore",
              style: GoogleFonts.montserrat(
                color: Colors.white, 
                fontSize: 12, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }


 void _handleCoordinateResult(LatLng result) {
  _getAddressFromLatLng(Position(
    latitude: result.latitude,
    longitude: result.longitude,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  ));
}
}Widget _buildActionButton({
  required IconData icon, 
  required String label, 
  required Color color, 
  required VoidCallback onTap
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    splashColor: color.withOpacity(0.1),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: color.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
  
}
// ------------------------------------------
// 🟢 ISOLATED LIVE ORDER TRACKER (Bypasses Firebase Index limits!)
// ------------------------------------------
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
      // 🟢 THE TRICK: We removed the .where('status') filter from the database query!
      // This forces Firestore to use the exact Index you already have in your screenshot.
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
          print("🚨 FIREBASE ERROR: ${snapshot.error}");
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        String status = data['status'] ?? '';

        // 🟢 THE TRICK PART 2: We filter the status locally in the app instead!
        List<String> activeStatuses = ['Pending', 'PAID', 'Confirmed', 'Baking', 'Preparing', 'Out for Delivery'];
        if (!activeStatuses.contains(status)) {
          // If the order is 'Delivered' or 'Cancelled', we hide the widget.
          return const SizedBox.shrink(); 
        }

        Color statusColor = const Color(0xFFFF2E74); 
        IconData statusIcon = Icons.auto_awesome_rounded;
        String message = "Processing your order...";
        double progress = 0.3;

        if (status == 'Pending' || status == 'PAID' || status == 'Confirmed') {
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))
              ],
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
                              color: statusColor, 
                              shape: BoxShape.circle, 
                              boxShadow: [BoxShadow(color: statusColor, blurRadius: 6)]
                            )
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text("LIVE TRACKING", 
                          style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      ],
                    ),
                    Text("#${data['orderId']?.toString().split('-').last ?? '...'}", 
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
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
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingOrderPage(orderId: doc.id))),
                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 18),
                    )
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
