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
  final double? latitude;
  final double? longitude;
  final String deliverySchedule;
  final String? receiverName;
  final String? receiverPhone;
  final String? appliedCoupon;

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
    this.receiverName,
    this.receiverPhone,
    this.appliedCoupon,
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
  double _discount = 0.0;
  double _grandTotal = 0.0;

  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _bgPremium = const Color(0xFFFAFAFA);
  final Color _surfaceWhite = Colors.white;
  final Color _textPrimary = const Color(0xFF111111);
  final Color _textSecondary = const Color(0xFF757575);

  final double shopLat = 10.216453;
  final double shopLng = 76.157615;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
    _effectivePhone = widget.userPhone.isEmpty
        ? (FirebaseAuth.instance.currentUser?.phoneNumber ?? "")
        : widget.userPhone;

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _calculateTotals() {
    setState(() {
      _grandTotal = widget.amount.ceilToDouble();

      double tempSubtotal = 0;
      for (var item in widget.cartItems) {
        String priceString = item['price'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        tempSubtotal += double.tryParse(priceString) ?? 0;
      }
      _itemSubtotal = tempSubtotal;

      if (widget.latitude != null && widget.longitude != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          shopLat,
          shopLng,
          widget.latitude!,
          widget.longitude!,
        );
        _distanceKm = distanceInMeters / 1000;
        _deliveryFee = (_itemSubtotal < 500)
            ? (_distanceKm * 10).ceilToDouble()
            : 0.0;
      }

      _discount = (_itemSubtotal + _deliveryFee) - _grandTotal;
      if (_discount < 0) _discount = 0;
    });
  }

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
    if (val is Map) return val.keys.join(", ");
    return val.toString();
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_S658dHJsKLfV7D',
      'amount': (_grandTotal * 100).toInt(),
      'name': 'Butter Hearts Cakes',
      'description':
          'Order #${widget.orderId.substring(widget.orderId.length - 6)}',
      'prefill': {
        'contact': _effectivePhone,
        'email':
            FirebaseAuth.instance.currentUser?.email ??
            'customer@butterhearts.com',
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(
            color: Color(0xFFFF2E74),
            strokeWidth: 2,
          ),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String uid = user?.uid ?? "GUEST";
      final String customOrderId = widget.orderId;

      String finalName = widget.userName;
      if (finalName.isEmpty || finalName.toLowerCase() == 'guest') {
        finalName = user?.displayName ?? "Guest User";
      }
      String finalPhone = _effectivePhone.isNotEmpty
          ? _effectivePhone
          : (user?.phoneNumber ?? "");

      if (widget.appliedCoupon != null) {
        await FirebaseFirestore.instance
            .collection('coupons')
            .doc(widget.appliedCoupon)
            .update({
              'isUsed': true,
              'usedBy': user?.email ?? finalPhone,
              'usedAt': FieldValue.serverTimestamp(),
            });
      }

      final List<Map<String, dynamic>> formattedItems = widget.cartItems.map((
        item,
      ) {
        return {
          'name': item['name']?.toString() ?? 'Item',
          'image': item['image']?.toString() ?? '',
          'weight': (item['selected_weight'] ?? item['weight'] ?? '')
              .toString(),
          'price': item['price']?.toString() ?? '0',
          'quantity': item['quantity'] ?? 1,
          'shape': (item['selected_shape'] ?? item['shape'] ?? 'Standard')
              .toString(),
          'flavour': _getSafeFlavor(item),
          'cakeWriting': (item['cakeWriting'] ?? '').toString(),
          'category': item['category']?.toString() ?? 'Cake',
        };
      }).toList();

      final Map<String, dynamic> orderData = {
        'orderId': customOrderId,
        'paymentId': response.paymentId ?? "UNKNOWN_PAYMENT_ID",
        'userId': uid,
        'userName': finalName,
        'userPhone': finalPhone,
        'userAddress': widget.userAddress,
        'receiverName': widget.receiverName ?? "Same as Customer",
        'receiverPhone': widget.receiverPhone ?? "Same as Customer",
        'totalPrice': _grandTotal,
        'status': 'PAID',
        'couponUsed': widget.appliedCoupon,
        'latitude': widget.latitude ?? 0.0,
        'longitude': widget.longitude ?? 0.0,
        'deliverySchedule': widget.deliverySchedule,
        'items': formattedItems,
        'itemSubtotal': _itemSubtotal,
        'deliveryFee': _deliveryFee,
        'discountAmount': _discount,
      };

      await FirebaseDatabase.instance
          .ref()
          .child('users/$uid/orders/$customOrderId')
          .set({...orderData, 'createdAt': ServerValue.timestamp});

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(customOrderId)
          .set({
            ...orderData,
            'userEmail': user?.email ?? "No Email",
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (uid != "GUEST") {
        await FirebaseDatabase.instance.ref().child('users/$uid/cart').remove();
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(customOrderId);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog(
        "Payment successful, but order sync failed. Support ID: ${response.paymentId}",
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Payment Failed: ${response.message}"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Wallet Selected: ${response.walletName}"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPremium,
      appBar: AppBar(
        backgroundColor: _bgPremium,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Checkout",
          style: GoogleFonts.playfairDisplay(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("DELIVERY DETAILS"),
                _buildPremiumCard(
                  child: Column(
                    children: [
                      _buildPremiumInfoRow(
                        Icons.person_outline_rounded,
                        "Receiver",
                        widget.receiverName ?? widget.userName,
                      ),
                      _buildDivider(),
                      if (widget.receiverPhone != null &&
                          widget.receiverPhone != "Same as Customer") ...[
                        _buildPremiumInfoRow(
                          Icons.phone_outlined,
                          "Contact",
                          widget.receiverPhone!,
                        ),
                        _buildDivider(),
                      ],
                      _buildPremiumInfoRow(
                        Icons.location_on_outlined,
                        "Address",
                        widget.userAddress,
                        isAddress: true,
                      ),
                      _buildDivider(),
                      _buildPremiumInfoRow(
                        Icons.access_time_rounded,
                        "Schedule",
                        widget.deliverySchedule,
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                _buildSectionTitle("ORDER SUMMARY"),
                _buildPremiumCard(
                  child: Column(
                    children: [
                      ...widget.cartItems.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var item = entry.value;
                        return Column(
                          children: [
                            _buildPremiumItemRow(item),
                            if (idx != widget.cartItems.length - 1)
                              _buildDivider(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                _buildSectionTitle("PAYMENT"),
                _buildPremiumReceipt(),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPremiumBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildPremiumCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
    );
  }

  Widget _buildPremiumInfoRow(
    IconData icon,
    String title,
    String value, {
    bool isAddress = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: isAddress
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.orange.shade50 : _bgPremium,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isHighlight ? Colors.orange.shade700 : _textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _textPrimary,
                    height: 1.4,
                    fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumItemRow(Map<String, dynamic> item) {
    String flavor = _getSafeFlavor(item);
    String cakeWriting = (item['cakeWriting'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: _bgPremium,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: _buildImage(item['image'] ?? ''),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                if ((item['weight'] ?? '').toString().isNotEmpty ||
                    flavor.isNotEmpty)
                  Text(
                    "${item['weight'] ?? ''} ${(item['weight'] != null && flavor.isNotEmpty) ? '•' : ''} $flavor",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                if (cakeWriting.isNotEmpty && cakeWriting != "No writing")
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '"$cakeWriting"',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _accentPink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${item['price']}",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Qty: ${item['quantity'] ?? 1}",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumReceipt() {
    return _buildPremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _receiptRow(
              "Item Subtotal",
              "₹${_itemSubtotal.toStringAsFixed(0)}",
            ),
            const SizedBox(height: 12),
            _receiptRow(
              "Delivery Fee",
              _deliveryFee == 0
                  ? "FREE"
                  : "₹${_deliveryFee.toStringAsFixed(0)}",
              isHighlight: _deliveryFee == 0,
            ),

            if (_discount > 0) ...[
              const SizedBox(height: 12),
              _receiptRow(
                "Coupon Discount",
                "-₹${_discount.toStringAsFixed(0)}",
                isHighlight: true,
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Total",
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  "₹${_grandTotal.toStringAsFixed(0)}",
                  style: GoogleFonts.montserrat(
                    color: _accentPink,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            color: isHighlight ? Colors.green.shade600 : _textPrimary,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
          child: ElevatedButton(
            onPressed: _startPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _textPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Proceed to Pay",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageString) {
    try {
      if (imageString.isEmpty)
        return Icon(Icons.cake, color: Colors.grey.shade300, size: 20);
      if (imageString.startsWith('assets/'))
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(imageString, fit: BoxFit.cover),
        );
      if (imageString.startsWith('http'))
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(imageString, fit: BoxFit.cover),
        );
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(base64Decode(imageString), fit: BoxFit.cover),
      );
    } catch (e) {
      return Icon(Icons.broken_image, color: Colors.grey.shade300, size: 20);
    }
  }

  void _showSuccessDialog(String newOrderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Payment Successful",
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Order #${newOrderId.substring(newOrderId.length - 6)}",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Your order has been received and is being processed.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: Text(
                  "BACK TO HOME",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
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
        title: const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 40,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Dismiss",
                style: GoogleFonts.inter(
                  color: _accentPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
