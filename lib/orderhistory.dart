import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; 

// 🟢 IMPORT YOUR TRACKING PAGE
import 'package:project/orderpage.dart'; 

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  // --- 🎨 PREMIUM THEME COLORS ---
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _textDark = const Color(0xFF2D3142);
  final Color _bgLight = const Color(0xFFF7F8FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "MY ORDERS",
          style: GoogleFonts.montserrat(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _accentPink));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Unable to load orders.\nError: ${snapshot.error}", textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final orders = snapshot.data!.docs;

          return ListView.separated(
            itemCount: orders.length,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;
              return _buildPremiumOrderCard(orderData, orderId);
            },
          );
        },
      ),
    );
  }

  // --- 🟢 PREMIUM ORDER CARD ---
  Widget _buildPremiumOrderCard(Map<String, dynamic> order, String docId) {
    // 1. Data Parsing
    final Timestamp? timestamp = order['createdAt'];
    final String dateStr = timestamp != null 
        ? DateFormat('MMM dd, yyyy  •  hh:mm a').format(timestamp.toDate()) 
        : "Recently Placed";
        
    final String status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final List items = order['items'] is List ? order['items'] : [];
    
    // Get first item image for thumbnail
    String? firstItemImage;
    String firstItemName = "Unknown Item";
    if (items.isNotEmpty) {
      firstItemImage = items[0]['image'];
      firstItemName = items[0]['name'] ?? "Special Cake";
    }

    // 2. Status Color Logic
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (status) {
      case 'DELIVERED':
        statusColor = Colors.green.shade700;
        statusBg = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'CANCELLED':
        statusColor = Colors.red.shade700;
        statusBg = Colors.red.shade50;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'OUT FOR DELIVERY':
        statusColor = Colors.blue.shade700;
        statusBg = Colors.blue.shade50;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'BAKING':
      case 'PREPARING':
        statusColor = Colors.orange.shade700;
        statusBg = Colors.orange.shade50;
        statusIcon = Icons.outdoor_grill_rounded;
        break;
      default:
        statusColor = _accentPink;
        statusBg = _accentPink.withOpacity(0.1);
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => OngoingOrderPage(orderId: docId))
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP ROW: Order ID & Date ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #${docId.substring(0, 6).toUpperCase()}",
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.grey.shade500, letterSpacing: 1.0),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                ),
                
                // --- MIDDLE ROW: Image, Name, Price ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Image Box
                    Container(
                      height: 75, 
                      width: 75,
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(firstItemImage),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItemName,
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items.length > 1 ? "+ ${items.length - 1} more items" : "1 item",
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹${order['totalPrice'] ?? '0'}",
                            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w800, color: _accentPink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // --- BOTTOM ROW: Status Badge & Action Button ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            status, 
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5)
                          ),
                        ],
                      ),
                    ),
                    
                    // Track Button
                    Row(
                      children: [
                        Text(
                          status == 'DELIVERED' ? "View Receipt" : "Track Order",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _textDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                        )
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 🟢 IMAGE HANDLER ---
  Widget _buildImage(String? imageString) {
    if (imageString == null || imageString.isEmpty) {
      return Icon(Icons.cake_rounded, color: Colors.grey.shade300, size: 30);
    }
    try {
      if (imageString.startsWith('assets/')) {
        return Image.asset(imageString, fit: BoxFit.contain);
      }
      if (imageString.startsWith('http')) {
        return Image.network(imageString, fit: BoxFit.contain);
      }
      return Image.memory(base64Decode(imageString), fit: BoxFit.contain);
    } catch (e) {
      return Icon(Icons.broken_image_rounded, color: Colors.grey.shade300, size: 30);
    }
  }

  // --- 🟢 EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: Colors.white, 
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, spreadRadius: 5)]
            ),
            child: Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            "No Orders Yet", 
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: _textDark, fontSize: 24)
          ),
          const SizedBox(height: 10),
          Text(
            "Your delicious journey starts soon!\nPlace an order to see it here.", 
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14, height: 1.5)
          ),
        ],
      ),
    );
  }
}