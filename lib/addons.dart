import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cakepage.dart'; 
import 'cartpage1.dart';

class Addonspage extends StatefulWidget {
  const Addonspage({super.key});

  @override
  State<Addonspage> createState() => _AddonspageState();
}

class _AddonspageState extends State<Addonspage> {
  final Color _accentPink = const Color(0xFFFF2E74);
  final Map<String, Uint8List> _memoryImageCache = {};

  Future<void> _addAddonToCart(Map<String, dynamic> addonData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to add items to your cart.")),
      );
      return;
    }

    HapticFeedback.lightImpact();

    final DatabaseReference cartRef = FirebaseDatabase.instance.ref().child('users/${user.uid}/cart');
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
      'category': addonData['category'] ?? 'Addon',
      'deliveryTime': 0, // Addons usually ship instantly with the main order
      'deliveryUnit': 'Hours',
      'addedAt': ServerValue.timestamp,
    };

    try {
      await cartRef.child(newKey).set(cartItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text("${addonData['name']} added!", style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
              ],
            ),
            action: SnackBarAction(
              label: "VIEW CART",
              textColor: _accentPink,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const Cartpage1()));
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding addon to cart: $e");
    }
  }

  Widget _buildImage(String imageString) {
    if (imageString.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.stars_rounded, color: Colors.grey.shade300, size: 40),
      );
    }
    try {
      if (imageString.startsWith('assets/')) {
        return Image.asset(imageString, fit: BoxFit.cover);
      } else if (imageString.startsWith('http')) {
        return Image.network(imageString, fit: BoxFit.cover);
      } else {
        Uint8List imageBytes;
        if (_memoryImageCache.containsKey(imageString)) {
         imageBytes = _memoryImageCache[imageString] ?? Uint8List(0);
        } else {
          imageBytes = base64Decode(imageString);
          _memoryImageCache[imageString] = imageBytes;
        }
        return Image.memory(imageBytes, fit: BoxFit.cover);
      }
    } catch (e) {
      return Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade300, size: 40),
      );
    }
  }

  Widget _buildModernAddonCard(Map<String, dynamic> data) {
    String name = data['name']?.toString() ?? 'Special Addon';
    String rawPrice = data['price']?.toString() ?? '0';
    String imageString = data['image']?.toString() ?? data['imageUrl']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: _buildImage(imageString),
              ),
            ),
          ),
          
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.2,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Price",
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₹$rawPrice",
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, color: _accentPink),
                          ),
                        ],
                      ),
                      
                      GestureDetector(
                        onTap: () => _addAddonToCart(data),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentPink,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: _accentPink.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 18),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Perfect Pairings", 
          style: GoogleFonts.playfairDisplay(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: CartBadge(onLoginSuccess: () {}),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('category', whereIn: [
              'addon', 'addons', 'Addon', 'Addons', 
              'Add-ons', 'Add-on', 'add-ons', 'add-on', 
              'Add-On', 'Add-Ons'
            ])
            .snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _accentPink));
          }
          
          if (!snapshot.hasData || (snapshot.data?.docs.isEmpty ?? true)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                    child: Icon(Icons.card_giftcard_rounded, size: 50, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 24),
                  Text("No extras available yet", style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text("Add them from your Admin Panel.", style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            );
          }

       if (!snapshot.hasData || snapshot.data == null) {
  return const CircularProgressIndicator(); 
}
final addons = snapshot.data?.docs; // Now this is 100% safe
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Text(
                    "Make your gift extra special",
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, 
                    mainAxisExtent: 260, 
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = (addons?[index].data() as Map<String, dynamic>?) ?? {};
                      return _buildModernAddonCard(data);
                    },
                    childCount: addons?.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}