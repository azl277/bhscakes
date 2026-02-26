import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
 // Ensure this matches your actual map picker file name

class OngoingOrderPage extends StatefulWidget {
  final String orderId;

  const OngoingOrderPage({super.key, required this.orderId});

  @override
  State<OngoingOrderPage> createState() => _OngoingOrderPageState();
}

class _OngoingOrderPageState extends State<OngoingOrderPage> {
  // --- PREMIUM PALETTE ---
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _darkPink = const Color(0xFFC2185B);
  final Color _premiumBlack = const Color(0xFF1A1A1A);
  final Color _bgGrey = const Color(0xFFF4F5F9);
  final Color _successGreen = const Color(0xFF00C853);

  // --- HELPERS ---
 // --- HELPERS ---
  String _getFlavourText(dynamic flavours) {
    if (flavours == null || flavours.toString().trim().isEmpty || flavours.toString() == '{}') {
      return ""; 
    }
    
    // If it's already a clean string and not a JSON map, just return it
    String raw = flavours.toString().trim();
    if (!raw.startsWith('{')) {
      return raw;
    }

    try {
      if (flavours is String) {
        final Map<String, dynamic> map = jsonDecode(flavours);
        return map.isEmpty ? "" : map.keys.join(", ");
      }
      if (flavours is Map) {
        return flavours.isEmpty ? "" : flavours.keys.join(", ");
      }
    } catch (e) {
      // Fallback: strip common JSON characters if decoding fails
      return raw.replaceAll(RegExp(r'[{}"\]\[]'), '').trim();
    }
    
    return "";
  }
  int _getCurrentStep(String status) {
    status = status.toLowerCase();
    if (status.contains('paid') || status.contains('pending')) return 0;
    if (status.contains('baking') || status.contains('preparing')) return 1;
    if (status.contains('out') || status.contains('way')) return 2;
    if (status.contains('delivered') || status.contains('completed')) return 3;
    return 0;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    return DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _accentPink));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState();
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final items = orderData['items'] as List<dynamic>? ?? [];
          final status = orderData['status'] ?? "Pending";
          final String address = orderData['userAddress'] ?? "Pickup at Store";
          
          // 🟢 EXTRACT RECEIVER DETAILS
          final String receiverName = orderData['receiverName']?.toString() ?? 'Same as Customer';
          final String receiverPhone = orderData['receiverPhone']?.toString() ?? 'Same as Customer';
          
          // Time Logic (15 min lock)
          Timestamp? createdAt = orderData['createdAt'] as Timestamp?;
          bool isWithin15Mins = false;
          if (createdAt != null) {
            final int diff = DateTime.now().difference(createdAt.toDate()).inMinutes;
            isWithin15Mins = diff < 15;
          }

          bool isCancelled = status.toString().toLowerCase() == 'cancelled';
          int currentStep = _getCurrentStep(status);
          bool isEditable = (currentStep == 0) && !isCancelled && isWithin15Mins;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Dynamic App Bar
              _buildSliverAppBar(status, isCancelled, orderData['orderId'] ?? widget.orderId, createdAt),

              // 2. Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A. Status Timeline
                      if (!isCancelled) _buildGlassTimeline(currentStep),
                      if (isCancelled) _buildCancelledBanner(),
                      
                      const SizedBox(height: 25),

                      // B. Lock Timer / Editable Banner
                      if (isEditable)
                        _buildEditableBanner()
                      else if (!isCancelled && currentStep == 0)
                        _buildLockedBanner(),

                      const SizedBox(height: 30),

                      // C. Order Details Header
                      Text("ORDER DETAILS", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
                      const SizedBox(height: 15),

                      // D. Items List (Detailed)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 15),
                        itemBuilder: (context, index) {
                          return _buildDetailedItemCard(items[index], index, isEditable, items);
                        },
                      ),

                      const SizedBox(height: 30),

                      // E. Delivery & Billing Grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildInfoCard(Icons.location_on_rounded, "Delivery To", address, isEditable: isEditable, onTapEdit: () => _editAddress(address))),
                          const SizedBox(width: 15),
                          Expanded(child: _buildInfoCard(Icons.receipt_long_rounded, "Total Paid", "₹${orderData['totalPrice'] ?? '0'}")),
                        ],
                      ),
                      
                      const SizedBox(height: 15),
                      
                      // 🟢 NEW: Editable Receiver Info Card (Full Width)
                      Container(
                        width: double.infinity,
                        child: _buildInfoCard(
                          Icons.person_pin_circle_rounded, 
                          "Receiver Details", 
                          receiverPhone == 'Same as Customer' ? receiverName : "$receiverName\n$receiverPhone", 
                          isEditable: isEditable, 
                          onTapEdit: () => _editReceiverDetails(receiverName, receiverPhone)
                        ),
                      ),

                      const SizedBox(height: 30),

                      // F. Need Help
                      _buildHelpSection(),
                      
                      const SizedBox(height: 40),
                      
                      // G. Cancel Button
                      if (isEditable) 
                        Center(child: _buildCancelButton()),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildSliverAppBar(String status, bool isCancelled, String displayId, Timestamp? time) {
    Color statusColor = isCancelled ? Colors.red : (status == 'Delivered' ? _successGreen : _accentPink);
    
    return SliverAppBar(
      expandedHeight: 220,
      backgroundColor: _premiumBlack,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          isCancelled ? "ORDER CANCELLED" : status.toUpperCase(),
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white, letterSpacing: 1),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Dark Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_premiumBlack, const Color(0xFF2C2C2C)],
                ),
              ),
            ),
            // Pattern Overlay (Optional aesthetic)
            Positioned(
              right: -50, top: -50,
              child: Icon(Icons.cake_rounded, size: 200, color: Colors.white.withOpacity(0.05)),
            ),
            
            // Order Info Overlay
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      "#$displayId",
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(time),
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTimeline(int currentStep) {
    final steps = [
      {'label': 'Placed', 'icon': Icons.receipt_long},
      {'label': 'Baking', 'icon': Icons.outdoor_grill_rounded}, 
      {'label': 'On Way', 'icon': Icons.delivery_dining},
      {'label': 'Enjoy!', 'icon': Icons.celebration},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          bool isActive = index <= currentStep;
          bool isCurrent = index == currentStep;
          
          return Expanded(
            child: Column(
              children: [
                // Icon Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? _accentPink : Colors.grey[100],
                    shape: BoxShape.circle,
                    boxShadow: isCurrent ? [BoxShadow(color: _accentPink.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)] : [],
                  ),
                  child: Icon(
                    steps[index]['icon'] as IconData,
                    color: isActive ? Colors.white : Colors.grey[400],
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[index]['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? _premiumBlack : Colors.grey[400],
                  ),
                ),
                // Connector Line (except for last item)
                if (index < steps.length - 1)
                  Transform.translate(
                    offset: const Offset(35, -35), 
                    child: Container(
                      height: 2,
                      width: 30, 
                      color: index < currentStep ? _accentPink : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

Widget _buildDetailedItemCard(Map<String, dynamic> item, int index, bool isEditable, List allItems) {
   // 🟢 Checks for 'flavour', 'flavor', and 'flavours' to ensure it finds the data
String flavor = _getFlavourText(item['flavour'] ?? item['flavor'] ?? item['flavours']);
    String shape = (item['shape'] ?? "").toString();
    String weight = (item['weight'] ?? "").toString();
    String writing = (item['cakeWriting'] ?? "").toString();
    String quantity = (item['quantity'] ?? 1).toString();
    
    // 🟢 SMART CHECK: Strictly rely on the Category from the database!
    String category = (item['category'] ?? "").toString().toLowerCase().trim();
    
    // Check if the database says this is an Add-on or a Cupcake
    bool isNonCakeItem = category == 'cupcake' || 
                         category == 'addon' || 
                         category == 'addons' || 
                         category == 'add on' || 
                         category == 'popsicle';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 80, width: 80,
                    color: _bgGrey,
                    child: _buildImage(item['image']),
                  ),
                ),
                const SizedBox(width: 15),
                
                // 2. Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? "Delicious Item", style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      // Tags Row
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          if (weight.isNotEmpty && weight != "N/A") 
                            _buildTag(weight, isNonCakeItem ? Icons.numbers_rounded : Icons.scale_rounded),
                          
                          // Hide shape if it's a non-cake item or if shape is empty
                          if (!isNonCakeItem && shape.isNotEmpty && shape != 'Standard' && shape != 'N/A') 
                            _buildTag(shape, Icons.interests_rounded),
                            
                          // Hide flavor if it's a non-cake item or if flavor is empty
                          if (!isNonCakeItem && flavor.isNotEmpty && flavor != 'N/A') 
                            _buildTag(flavor, Icons.local_dining_rounded, isHighlight: true),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 3. Price & Qty
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${item['price']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: _premiumBlack)),
                    const SizedBox(height: 4),
                    Text("Qty: $quantity", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          
          // 4. Message Section (Editable) - 🟢 STRICTLY ONLY FOR CAKES
          if (!isNonCakeItem)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: _accentPink.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: _accentPink.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: _accentPink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      writing.isEmpty || writing == "No message" || writing == "No writing" ? "No message on cake" : "\"$writing\"",
                      style: GoogleFonts.dancingScript(fontSize: 16, fontWeight: FontWeight.bold, color: _premiumBlack),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isEditable)
                    GestureDetector(
                      onTap: () => _editCakeWriting(index, writing, allItems),
                      child: Text("EDIT", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _accentPink)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildTag(String text, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight ? _accentPink.withOpacity(0.1) : _bgGrey,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isHighlight ? _accentPink.withOpacity(0.2) : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: isHighlight ? _accentPink : Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isHighlight ? _darkPink : Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value, {bool isEditable = false, VoidCallback? onTapEdit}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: Colors.grey[400]),
              if (isEditable)
                GestureDetector(
                  onTap: onTapEdit,
                  child: Icon(Icons.edit, size: 14, color: _accentPink),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 13, color: _premiumBlack, fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_premiumBlack, const Color(0xFF2C2C2C)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Need Help?", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text("Call our support team", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _launchURL("tel:+919037084037"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _premiumBlack, shape: const StadiumBorder()),
            child: const Text("CALL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildEditableBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You can edit the address and message for the next few minutes.",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Modifications locked. Your order is being processed.",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Text("This order was cancelled.", style: GoogleFonts.inter(color: Colors.red[800], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton.icon(
      onPressed: _showCancelDialog,
      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
      label: Text("Cancel Order", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Colors.red.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text("Order details not available", style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? imageString) {
    try {
      if (imageString == null || imageString.isEmpty) return const Icon(Icons.cake, color: Colors.grey);
      if (imageString.startsWith('assets/')) return Image.asset(imageString, fit: BoxFit.cover);
      return Image.memory(base64Decode(imageString), fit: BoxFit.cover);
    } catch (_) { return const Icon(Icons.broken_image, color: Colors.grey); }
  }

  // --- ACTIONS ---

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cancel Order?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text("This action cannot be undone.", style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); _performCancellation(); },
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancellation() async {
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({'status': 'Cancelled'});
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref().child('users').child(user.uid).child('orders').child(widget.orderId).update({'status': 'Cancelled'});
    }

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Cancelled"), backgroundColor: Colors.red));
  }

 void _editAddress(String currentAddress) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text("CHANGE DELIVERY LOCATION", style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
            ),
            
            _buildLocationOptionTile(
              icon: Icons.my_location_rounded,
              title: "Current Location",
              subtitle: "Using high-accuracy GPS",
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _determinePosition();
              },
            ),
            _buildLocationOptionTile(
              icon: Icons.map_outlined,
              title: "Select on Map",
              subtitle: "Pin your exact doorstep",
              color: Colors.orange,
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationPage()));
                if (result != null && result is Map) {
                   _showAddressEntryForm(result['address'], result['lat'], result['lng']);
                }
              },
            ),
            
            const Divider(height: 40, indent: 25, endIndent: 25),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("RECENTLY USED", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500])),
              ),
            ),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('addresses')
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) return Center(child: Text("No saved addresses", style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)));
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.history_rounded, size: 20, color: Colors.grey),
                        title: Text(data['fullAddress'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _updateDatabaseAddress(data['fullAddress']);
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
  // 🟢 STEP 2: GPS COORDINATES
  Future<void> _determinePosition() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74))));
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String area = p.isNotEmpty ? "${p[0].subLocality}, ${p[0].locality}" : "Unknown Area";
      Navigator.pop(context);
      _showAddressEntryForm(area, pos.latitude, pos.longitude);
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar("Could not fetch location", Colors.red);
    }
  }

  // 🟢 STEP 3: THE FINAL DETAILS FORM
  void _showAddressEntryForm(String area, double lat, double lng) {
    final houseCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("COMPLETE ADDRESS", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              TextField(
                controller: houseCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.home_outlined, color: _accentPink),
                  hintText: "House / Flat No / Landmark",
                  filled: true,
                  fillColor: _bgGrey,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Text("Area: $area", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _premiumBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    if (houseCtrl.text.isEmpty) return;
                    String full = "${houseCtrl.text}, $area";
                    _updateDatabaseAddress(full);
                    Navigator.pop(context);
                  },
                  child: const Text("UPDATE ORDER ADDRESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 🟢 HELPER: THE OPTION TILE UI
  Widget _buildLocationOptionTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
        child: Icon(icon, color: color, size: 20)
      ),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
  Future<void> _handleGpsLocationUpdate() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Location services are disabled.", Colors.red);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permissions are denied.", Colors.red);
        return;
      }
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74))),
    );

    try {
      Position position = await Geolocator.getCurrentPosition();
      
      // Convert Coordinates to Address
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      
      String newAddress = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
      
      Navigator.pop(context); // Close loading
      await _updateDatabaseAddress(newAddress); // Save to Firebase
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar("Error getting location: $e", Colors.red);
    }
  }

  // 🟢 2. MAP PICKER LOGIC
  Future<void> _openMapPicker() async {
    // Navigate to your existing LocationPickerPage
    // Assuming it returns a result String (the address)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPage()),
    );

    if (result != null && result is String) {
      await _updateDatabaseAddress(result);
    }
  }

  // Helper for messages
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // 🟢 NEW: Edit Receiver Bottom Sheet
  void _editReceiverDetails(String currentName, String currentPhone) {
    TextEditingController nameCtrl = TextEditingController(text: currentName == 'Same as Customer' ? '' : currentName);
    TextEditingController phoneCtrl = TextEditingController(text: currentPhone == 'Same as Customer' ? '' : currentPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 25, left: 25, right: 25),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Receiver", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.inter(),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                filled: true, fillColor: _bgGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: "Receiver Name",
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                filled: true, fillColor: _bgGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: "Receiver Phone",
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _premiumBlack, 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                      'receiverName': nameCtrl.text.trim(),
                      'receiverPhone': phoneCtrl.text.trim(),
                    });
                    
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseDatabase.instance.ref()
                            .child('users').child(user.uid)
                            .child('orders').child(widget.orderId).update({
                              'receiverName': nameCtrl.text.trim(),
                              'receiverPhone': phoneCtrl.text.trim(),
                            });
                      }
                    } catch (e) {
                      debugPrint("RTDB Sync error: $e");
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Receiver details updated!"), backgroundColor: Colors.green)
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill in both fields"), backgroundColor: Colors.red)
                    );
                  }
                },
                child: const Text("Save Details", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _editCakeWriting(int index, String currentText, List<dynamic> allItems) {
    TextEditingController controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cake Message", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller, 
          maxLength: 30, 
          decoration: const InputDecoration(hintText: "Happy Birthday...", counterText: ""),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentPink, foregroundColor: Colors.white),
            onPressed: () async {
              allItems[index]['cakeWriting'] = controller.text;
              await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({'items': allItems});
              
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseDatabase.instance.ref().child('users').child(user.uid).child('orders').child(widget.orderId).child('items').child(index.toString()).update({'cakeWriting': controller.text});
              }
              if(mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Error: $e"); }
  }
  Widget _buildQuickActionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: _accentPink.withOpacity(0.1), child: Icon(icon, color: _accentPink, size: 20)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressTile(String address) {
    return GestureDetector(
      onTap: () => _updateDatabaseAddress(address),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.grey, size: 20),
            const SizedBox(width: 15),
            Expanded(child: Text(address, style: GoogleFonts.inter(fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSavedAddresses() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text("No saved addresses found.", style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
    );
  }
  Future<void> _updateDatabaseAddress(String newAddress) async {
    try {
      // 1. Update Firestore (for Admin)
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'userAddress': newAddress,
      });

      // 2. Update Realtime Database (for Customer History)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref()
            .child('users').child(user.uid)
            .child('orders').child(widget.orderId)
            .update({'userAddress': newAddress});
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address updated successfully!"), backgroundColor: Colors.green)
      );
    } catch (e) {
      debugPrint("Address update error: $e");
    }
  }
}