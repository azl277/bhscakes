import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; 
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentPage extends StatefulWidget {
  final double amount;
  final String orderId;
  final String userName;
  final String userPhone;
  final String userAddress;
  final List<dynamic> cartItems;
  
  // Accept Coordinates & Schedule
  final double? latitude;
  final double? longitude;
  final String deliverySchedule;

  // 🟢 Receiver details
  final String? receiverName;   
  final String? receiverPhone;

  const PaymentPage({
    super.key,
    required this.amount,
    required this.orderId,
    required this.userName,
    required this.userPhone,
    required this.userAddress,
    required this.cartItems,
    required this.deliverySchedule,
    this.latitude, 
    this.longitude, 
    this.receiverName,   // 🟢 Clean, single declaration
    this.receiverPhone,  // 🟢 Clean, single declaration
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {

  late Razorpay _razorpay;
  String _effectivePhone = ""; 
  
  double _distanceKm = 0.0;
  double _itemSubtotal = 0.0; 
  double _deliveryFee = 0.0;
  double _grandTotal = 0.0;

  // PREMIUM THEME COLORS
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _bgGrey = const Color(0xFFF5F7FA);
  final Color _textDark = const Color(0xFF2D3436);

  // SHOP COORDINATES
  final double shopLat = 10.216453;
  final double shopLng = 76.157615;

  @override
  void initState() {
    super.initState();
    
    // INITIALIZE DATA
    _calculateDeliveryDetails();
    
    _effectivePhone = widget.userPhone.isEmpty 
        ? (FirebaseAuth.instance.currentUser?.phoneNumber ?? "") 
        : widget.userPhone;

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // CRITICAL HELPER: Safely Extract Flavor Text
  String _getSafeFlavor(dynamic item) {
    dynamic val = item['flavor'] ?? item['flavours'];
    
    if (val == null) return "";

    if (val is String) {
      if (val.trim().startsWith("{")) {
        try {
          final Map<String, dynamic> map = jsonDecode(val);
          return map.keys.join(", ");
        } catch (e) {
          return val; 
        }
      }
      return val; 
    }

    if (val is Map) {
      return val.keys.join(", ");
    }

    return val.toString();
  }

  void _calculateDeliveryDetails() {
    setState(() {
      _itemSubtotal = widget.amount; 

      if (widget.latitude != null && widget.longitude != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          shopLat, shopLng, widget.latitude!, widget.longitude!
        );
        _distanceKm = distanceInMeters / 1000;

        // DELIVERY FEE LOGIC
        if (_itemSubtotal < 500) {
          _deliveryFee = _distanceKm * 10; 
        } else {
          _deliveryFee = 0.0; 
        }
      }
      
      _grandTotal = _itemSubtotal + _deliveryFee;
    });
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_S658dHJsKLfV7D', 
      'amount': (_grandTotal * 100).toInt(), 
      'name': 'Butter Hearts Cakes',
      'description': 'Order #${widget.orderId}',
      'prefill': {'contact': _effectivePhone, 'email': 'customer@butterhearts.com'},
      'theme': {'color': '#FF2E74'}
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // 🟢 THIS FUNCTION NOW HANDLES EVERYTHING
 // 🟢 THIS FUNCTION NOW HANDLES EVERYTHING SAFELY
  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // 1. Show un-dismissable loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74))),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String uid = user?.uid ?? "GUEST";

      // 🟢 Inherit the exact Master ID passed from the Cart page.
      final String customOrderId = widget.orderId;

      String finalName = widget.userName;
      if (finalName.isEmpty || finalName.toLowerCase() == 'guest') {
        finalName = user?.displayName ?? "Guest User"; 
      }

      String finalPhone = _effectivePhone.isNotEmpty ? _effectivePhone : (user?.phoneNumber ?? "");

      // 🟢 FIX: CRITICAL DATA SANITIZATION
      // Force every single field inside the cart items to be a safe, primitive string or int.
      // This prevents "Unhandled Exception: Invalid argument" crashes when pushing to Firestore.
     // 🟢 FIX: CRITICAL DATA SANITIZATION
      final List<Map<String, dynamic>> formattedItems = widget.cartItems.map((item) {
        
        String weightVal = (item['selected_weight'] ?? item['weight'] ?? '').toString();
        String shapeVal = (item['selected_shape'] ?? item['shape'] ?? 'Standard').toString();
        String writingVal = (item['cakeWriting'] ?? '').toString();
        String flavorVal = _getSafeFlavor(item);

        return {
          'name': item['name']?.toString() ?? 'Item',
          'image': item['image']?.toString() ?? '',
          'weight': weightVal, 
          'price': item['price']?.toString() ?? '0',
          'quantity': item['quantity'] ?? 1,
          'shape': shapeVal,
          'flavour': flavorVal, 
          'cakeWriting': writingVal, 
          'category': item['category']?.toString() ?? 'Cake', // 🟢 ADD THIS LINE! This saves it to Firebase!
        };
      }).toList();
      // 🟢 Prepare the exact Map structure for the Admin App
      final Map<String, dynamic> orderData = {
        'orderId': customOrderId,
        'paymentId': response.paymentId ?? "UNKNOWN_PAYMENT_ID",
        'userId': uid, 
        'userName': finalName,
        'userPhone': finalPhone,
        'userAddress': widget.userAddress, 
        'receiverName': widget.receiverName ?? "Same as Customer",
        'receiverPhone': widget.receiverPhone ?? "Same as Customer",
        'totalPrice': widget.amount, // Admin App expects a number
        'status': 'PAID', // 🟢 Admin App expects 'PAID', not 'Pending', to show the 'Start Baking' button.
        'latitude': widget.latitude ?? 0.0,
        'longitude': widget.longitude ?? 0.0,
        'deliverySchedule': widget.deliverySchedule, 
        'items': formattedItems,
        
      };

      // 🟢 2. SYNC TO CUSTOMER'S PERSONAL HISTORY (Realtime Database)
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('orders')
          .child(customOrderId)
          .set({
            ...orderData,
            'createdAt': ServerValue.timestamp, // Realtime DB uses ServerValue
          });

      // 🟢 3. SYNC TO ADMIN PANEL (Firestore Global Orders Collection)
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(customOrderId)
          .set({
            ...orderData,
            'userEmail': user?.email ?? "No Email",
            'createdAt': FieldValue.serverTimestamp(), // Firestore uses FieldValue
          });

      // 🟢 4. CLEAR THE USER'S CART (Since the order is now successfully placed)
      if (uid != "GUEST") {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(uid)
            .child('cart')
            .remove();
      }

      // 5. REMOVE LOADING SPINNER AND SHOW SUCCESS DIALOG
      if (mounted) {
        Navigator.pop(context); // Close loading spinner
        _showSuccessDialog(customOrderId); // Show success popup
      }

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading spinner on error
      debugPrint("💥 Sync Error Details: $e");
      _showErrorDialog("Payment successful, but order sync failed. Support ID: ${response.paymentId}");
    }
  }
  Widget _buildReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Column(
        children: [
          _buildSummaryRow("Item Subtotal", "₹${_itemSubtotal.toStringAsFixed(0)}"),
          const SizedBox(height: 12),
          _buildSummaryRow(
            "Delivery Fee", 
            _deliveryFee == 0 ? "FREE" : "₹${_deliveryFee.toStringAsFixed(0)}", 
            isGreen: _deliveryFee == 0
          ),
          
          if (_deliveryFee > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "(${_distanceKm.toStringAsFixed(1)} km × ₹10)",
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
            ),
            
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Payable", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15)),
              Text("₹${_grandTotal.toStringAsFixed(0)}",
                style: GoogleFonts.montserrat(color: _accentPink, fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }

  // 2. BOTTOM PAY BUTTON
  Widget _buildBottomPayButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: _startPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black, 
            minimumSize: const Size(double.infinity, 60), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                "PAY ₹${_grandTotal.toStringAsFixed(0)}", 
                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSummaryRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.montserrat(color: isGreen ? Colors.green : _textDark, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Text(title.toUpperCase(), style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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

  // --- DIALOGS ---

  void _showSuccessDialog(String newOrderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 20),
            Text("Order Placed!", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 5),
            Text("Order ID: #$newOrderId", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 10),
            Text("Your delicious order has been received.", textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  // 🟢 This correctly closes the dialog AND goes back to the home screen
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("BACK TO HOME", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("OK", style: GoogleFonts.montserrat(color: _accentPink, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}"), backgroundColor: Colors.redAccent)
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wallet: ${response.walletName}")));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: _bgGrey,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          "CHECKOUT", 
          style: GoogleFonts.montserrat(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // 1. CONTACT INFO
            _buildSectionHeader("Contact Info"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: _accentPink.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.perm_identity_rounded, color: _accentPink, size: 24),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.userName, style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              _effectivePhone, 
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                    child: Text("VERIFIED", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 2. DELIVERY ADDRESS
           // 2. DELIVERY ADDRESS
            _buildSectionHeader("Deliver To"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text("Delivery Address", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userAddress, 
                    style: GoogleFonts.inter(color: _textDark, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)
                  ),
                  
                  // 🟢 NEW: DISPLAY RECEIVER DETAILS
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.1))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Receiver: ${widget.receiverName ?? 'Same as Customer'}", 
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Only show the phone number if it's not "Same as Customer"
                        if (widget.receiverPhone != null && widget.receiverPhone != 'Same as Customer')
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 24),
                            child: Text(
                              "📞 ${widget.receiverPhone}", 
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.blueAccent.shade700, fontWeight: FontWeight.w500)
                            ),
                          )
                      ],
                    ),
                  ),

                  // Distance Indicator
                  if (_distanceKm > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentPink.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_bike_rounded, size: 14, color: _accentPink),
                          const SizedBox(width: 6),
                          Text(
                            "${_distanceKm.toStringAsFixed(1)} km from Butter Hearts Cakes",
                            style: GoogleFonts.inter(fontSize: 11, color: _accentPink, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 3. ORDER ITEMS
            _buildSectionHeader("Order Summary"),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                
                // SAFE EXTRACTION FOR UI
                final String flavor = _getSafeFlavor(item);
                final String cakeWriting = (item['cakeWriting'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 50, height: 50, child: _buildImage(item['image'] ?? '')),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13,color: const Color.fromARGB(255, 146, 0, 0))
                            ),
                            const SizedBox(height: 4),
                            
                            if ((item['weight'] ?? '').toString().isNotEmpty)
                              Text("Weight: ${item['weight']}", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                            
                            if ((item['shape'] ?? '').toString().isNotEmpty)
                                Text("Shape: ${item['shape']}", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600])),

                            // DISPLAY FLAVOR (SAFE)
                            if (flavor.isNotEmpty)
                              Text("Flavor: $flavor", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                            
                            // DISPLAY MESSAGE
                            if (cakeWriting.isNotEmpty && cakeWriting != "No writing")
                              Text("Msg: $cakeWriting", style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: _accentPink)),
                          ],
                        ),
                      ),
                      Text("₹${item['price']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14,color: Colors.blue)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // 4. BILLING RECEIPT
            _buildReceiptCard(), 
            const SizedBox(height: 100),
          ],
        ),
      ),

      // 5. FLOATING PAY BUTTON
      bottomNavigationBar: _buildBottomPayButton(),
    );
  }
}