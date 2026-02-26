import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/Loginpage2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// 🟢 PAGE IMPORTS
import 'package:project/orderhistory.dart';
import 'package:project/savedlocation.dart';
import 'package:project/settings.dart';
import 'package:project/whishlistpage.dart';
import 'package:project/location.dart';

class Profilepage2 extends StatefulWidget {
  const Profilepage2({super.key});

  @override
  State<Profilepage2> createState() => _Profilepage2State();
}

class _Profilepage2State extends State<Profilepage2> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  // --- 🎨 NEW DASHBOARD THEME COLORS ---
  final Color _primaryColor = const Color(0xFFFF5757);
  final Color _gradientEnd = const Color(0xFFFF8B8B);
  final Color _textDark = const Color(0xFF2D3142);
  final Color _bgLight = const Color(0xFFF7F8FA);

  // --- 📍 LOCATION STATE ---
  String _userAddress = "Loading location...";
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _refreshUser();
    _loadUserAddress();
  }

  Future<void> _refreshUser() async {
    await currentUser?.reload();
    if (mounted) setState(() {});
  }

  // 🟢 SYNCED LOGIC
  Future<void> _loadUserAddress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    bool foundSavedAddress = false;

    if (currentUser != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          if (mounted) {
            setState(() {
              _userAddress = data['fullAddress'] ?? "No Address Set";
              _selectedLat = data['latitude'];
              _selectedLng = data['longitude'];
            });
          }
          foundSavedAddress = true;
        }
      } catch (e) {
        debugPrint("Address fetch error: $e");
      }
    }

    if (!foundSavedAddress && prefs.containsKey('userAddress')) {
      String? cachedAddr = prefs.getString('userAddress');
      if (cachedAddr != null && cachedAddr.isNotEmpty) {
        if (mounted) setState(() => _userAddress = cachedAddr);
        foundSavedAddress = true;
      }
    }

    if (!foundSavedAddress && mounted) {
      setState(() => _userAddress = "Tap to set delivery address");
    }
  }

  // ---------------------------------------------------------------------------
  // 🟢 LOCATION LOGIC 
  // ---------------------------------------------------------------------------

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text("DELIVERY ADDRESS", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5, color: _textDark)),
            ),
            _buildLocationOptionTile(
              icon: Icons.my_location_rounded,
              title: "Use Current Location",
              subtitle: "Enable GPS for accuracy",
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(context);
                _determinePosition();
              },
            ),
            _buildLocationOptionTile(
              icon: Icons.map_outlined,
              title: "Select via Map",
              subtitle: "Pinpoint your exact spot",
              color: _primaryColor,
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationPage()));
                if (result != null && result is Map) {
                  _updateLocalAddress(result['address'], result['lat'], result['lng']);
                }
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10), child: Divider(height: 30, color: Color(0xFFEEEEEE))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("RECENTLY SAVED", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('addresses').limit(3).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return Center(child: Text("No saved places yet.", style: GoogleFonts.inter(color: Colors.grey)));
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.history_rounded, size: 20, color: Colors.grey)),
                        title: Text(data['fullAddress'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                        onTap: () {
                          _updateLocalAddress(data['fullAddress'], data['latitude'], data['longitude']);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _determinePosition() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: _primaryColor)));
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double shopLat = 10.216453, shopLng = 76.157615; 
      double dist = Geolocator.distanceBetween(shopLat, shopLng, pos.latitude, pos.longitude);
      
      if (dist > 15000) {
        Navigator.pop(context);
        _showError("Out of Zone", "We currently only deliver within 15km of our bakery.");
        return;
      }

      List<Placemark> p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String area = p.isNotEmpty ? "${p[0].subLocality}, ${p[0].locality}" : "Unknown Area";
      Navigator.pop(context);
      _showAddressEntryForm(area, pos.latitude, pos.longitude);
    } catch (e) {
      Navigator.pop(context);
      _showError("Location Error", "Could not fetch your location. Please ensure GPS is enabled.");
    }
  }

  void _showAddressEntryForm(String area, double lat, double lng) {
    final houseCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setST) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                Text("ADDRESS DETAILS", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 24),
                _buildTextField(houseCtrl, "House/Flat No. & Building", Icons.home_work_outlined),
                const SizedBox(height: 16),
                _buildTextField(nameCtrl, "Receiver's Name", Icons.person_outline_rounded),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(phoneCtrl, "Phone Number", Icons.phone_outlined, keyboard: TextInputType.phone)),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(backgroundColor: _primaryColor.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () { phoneCtrl.text = currentUser?.phoneNumber ?? ""; setST(() {}); }, 
                      child: Text("Self", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _primaryColor))
                    )
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _textDark, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () async {
                      if (houseCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                      String full = "${houseCtrl.text}, $area";
                      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('addresses').add({
                        'fullAddress': full, 'latitude': lat, 'longitude': lng, 'receiverName': nameCtrl.text, 'receiverPhone': phoneCtrl.text, 'createdAt': FieldValue.serverTimestamp(),
                      });
                      _updateLocalAddress(full, lat, lng);
                      Navigator.pop(context);
                    },
                    child: Text("SAVE & CONTINUE", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _updateLocalAddress(String addr, double? lat, double? lng) async {
    setState(() {
      _userAddress = addr;
      _selectedLat = lat;
      _selectedLng = lng;
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('userAddress', addr);
  }

  // --- UI WIDGETS ---

  Widget _buildLocationOptionTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
      trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.black54)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
        labelText: hint,
        labelStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
      ),
    );
  }

  void _showError(String title, String msg) {
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)), 
        content: Text(msg, style: GoogleFonts.inter()), 
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)))]
      )
    );
  }

  // --- NAME EDIT DIALOG ---
  void _showEditNameDialog(BuildContext context, String currentName) {
    final TextEditingController nameCtrl = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Name", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
          content: TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Enter your full name",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _primaryColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(context); // Close dialog
                  await _updateUserName(nameCtrl.text.trim());
                }
              },
              child: Text("Save", style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- UPDATE NAME FUNCTION ---
  Future<void> _updateUserName(String newName) async {
    if (currentUser == null) return;
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: _primaryColor)));
      
      // Update Firebase Auth Profile
      await currentUser!.updateDisplayName(newName);
      
      // Update Firestore Record
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'username': newName,
        'name': newName,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // Remove loading circle
        _refreshUser(); // Refresh UI
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError("Update Failed", "Could not save your new name. Please try again.");
    }
  }

  // --- LOGOUT CONFIRMATION DIALOG ---
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Sign Out", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: _textDark)),
          content: Text("Are you sure you want to sign out of your account?", style: GoogleFonts.inter(color: Colors.grey[700])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {
                Navigator.pop(context); // Close the dialog first
                _handleLogout(context); // Then trigger the logout
              },
              child: Text("Sign Out", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return Scaffold(body: Center(child: CircularProgressIndicator(color: _primaryColor)));

    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
          builder: (context, snapshot) {
            String displayName = currentUser?.displayName ?? "Guest Baker";
            String phoneNumber = currentUser?.phoneNumber ?? "No linked phone number";
            
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              displayName = data['username'] ?? data['name'] ?? displayName;
              if (data.containsKey('phoneNumber') && data['phoneNumber'].toString().isNotEmpty) {
                phoneNumber = data['phoneNumber'];
              }
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DASHBOARD HEADER (UPDATED)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: _textDark,
                        child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "?", 
                          style: GoogleFonts.playfairDisplay(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: _textDark)),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showEditNameDialog(context, displayName),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                    child: Icon(Icons.edit_rounded, size: 14, color: _primaryColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(phoneNumber, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                        style: IconButton.styleFrom(backgroundColor: Colors.white, shadowColor: Colors.black12, elevation: 2),
                        icon: const Icon(Icons.settings_outlined, color: Colors.black87),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 2. HERO LOCATION CARD
                  GestureDetector(
                    onTap: _showLocationOptions,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_primaryColor, _gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text("DELIVERING TO", style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(_userAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 36),
                  Text("YOUR ACCOUNT", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.5)),
                  const SizedBox(height: 16),

                  // 3. MENU GRID
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildGridCard(Icons.shopping_bag_outlined, "My Orders", Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryPage()))),
                      _buildGridCard(Icons.favorite_border_rounded, "Wishlist", Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage()))),
                      _buildGridCard(Icons.tune_rounded, "Customisation", Colors.orangeAccent, () { 
                        /* Add customisation page route here */ 
                      }),
                      _buildGridCard(Icons.more_horiz_rounded, "More", Colors.green, () { 
                        /* Add more/settings route here */ 
                      }),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 4. LOGOUT BUTTON
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white,
                        shadowColor: Colors.black.withOpacity(0.05),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                      onPressed: () => _showLogoutConfirmation(context),
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: Text("Sign Out", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridCard(IconData icon, String title, Color iconColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: _textDark)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Loginpage2()), (r) => false);
    }
  }
}