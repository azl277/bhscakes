import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cartpage1.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  final Color _primaryColor = const Color(0xFFFF2E74);
  final Color _textDark = const Color(0xFF1A1A1A);
  final Color _textMuted = const Color(0xFF8E8E93);
  final Color _bgLight = const Color(0xFFF9FAFB);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        body: Center(
          child: Text(
            "Please login to view your wishlist",
            style: GoogleFonts.inter(color: _textMuted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textDark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "MY WISHLIST",
          style: GoogleFonts.montserrat(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}/wishlist')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Something went wrong",
                style: GoogleFonts.inter(color: _textMuted),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
            return _buildEmptyState();
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final List<Map<String, dynamic>> wishlistItems = [];

          data.forEach((key, value) {
            final item = Map<String, dynamic>.from(value);
            item['key'] = key;
            wishlistItems.add(item);
          });

          wishlistItems.sort(
            (a, b) => (b['added_at'] ?? 0).compareTo(a['added_at'] ?? 0),
          );

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 100,
            ),
            itemCount: wishlistItems.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = wishlistItems[index];
              return _buildDismissibleCard(context, item, user.uid);
            },
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCartButton(context, user.uid),
    );
  }

  Widget _buildFloatingCartButton(BuildContext context, String uid) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref().child('users/$uid/cart').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        int cartCount = data.length;

        if (cartCount == 0) return const SizedBox.shrink();

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _textDark.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              backgroundColor: _textDark,
              elevation: 0,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Cartpage1()),
              ),
              icon: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                "View Cart ($cartCount)",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDismissibleCard(
    BuildContext context,
    Map<String, dynamic> item,
    String uid,
  ) {
    final String itemKey = item['key']?.toString() ?? UniqueKey().toString();

    return Dismissible(
      key: Key(itemKey),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) async {
        await _removeFromWishlist(itemKey, uid);
      },
      child: _buildPremiumWishlistCard(context, item, uid, itemKey),
    );
  }

  Widget _buildPremiumWishlistCard(
    BuildContext context,
    Map<String, dynamic> item,
    String uid,
    String itemKey,
  ) {
    String name = item['name']?.toString() ?? "Unknown Treat";
    String price = item['price']?.toString() ?? "0";

    String rawDesc = item['desc']?.toString() ?? "";
    String rawDescription = item['description']?.toString() ?? "";
    String finalDesc = "A freshly baked treat made with love.";
    if (rawDesc.trim().isNotEmpty) {
      finalDesc = rawDesc;
    } else if (rawDescription.trim().isNotEmpty) {
      finalDesc = rawDescription;
    }

    String? imageUrl = (item['image'] ?? item['imageUrl'] ?? item['img'])
        ?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImage(imageUrl),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: SizedBox(
              height: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _textDark,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (itemKey.isNotEmpty)
                            _removeFromWishlist(itemKey, uid);
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    finalDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          price.startsWith('Rs') ? price : "₹$price",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      InkWell(
                        onTap: () => _handleAddToCartClick(context, item, uid),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _textDark,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: _textDark.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_shopping_cart_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "ADD",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddToCartClick(
    BuildContext context,
    Map<String, dynamic> item,
    String uid,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: _primaryColor)),
    );

    try {
      String itemName = item['name']?.toString().trim() ?? '';

      var query = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: itemName)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('cupcakes')
            .where('name', isEqualTo: itemName)
            .limit(1)
            .get();
      }

      if (context.mounted) Navigator.pop(context);

      Map<String, String> stringItem = {
        'name': itemName,
        'price': item['price']?.toString() ?? '0',
        'image': item['image']?.toString() ?? '',
        'desc':
            item['desc']?.toString() ?? item['description']?.toString() ?? '',
        'isOffer': 'false',
        'offerPrice': '',
        'category': item['category']?.toString() ?? '',
      };

      Map<String, dynamic> availability = {};
      Map<String, int> flavours = {};
      bool foundInCupcakesCollection = false;

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        foundInCupcakesCollection =
            query.docs.first.reference.parent.id == 'cupcakes';

        stringItem['category'] =
            data['category']?.toString() ?? stringItem['category']!;
        stringItem['desc'] =
            data['desc']?.toString() ??
            data['description']?.toString() ??
            stringItem['desc']!;
        stringItem['isOffer'] = (data['isOffer'] ?? false).toString();
        stringItem['offerPrice'] = data['offerPrice']?.toString() ?? '';

        final Map<String, dynamic> rawFlavours = data['flavours'] is Map
            ? data['flavours'] as Map<String, dynamic>
            : {};
        flavours = rawFlavours.map(
          (k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0),
        );
        availability = data['availability'] is Map
            ? data['availability'] as Map<String, dynamic>
            : {};
      }

      if (!context.mounted) return;

      String checkName = stringItem['name']!.toLowerCase();
      String checkCat = stringItem['category']!.toLowerCase().replaceAll(
        ' ',
        '',
      );

      bool isCupcake =
          checkCat.contains('cupcake') ||
          checkName.contains('cupcake') ||
          foundInCupcakesCollection;
      bool isAddon =
          checkCat.contains('addon') ||
          checkCat.contains('popsicle') ||
          checkName.contains('popsicle');

      if (isCupcake) {
        _showCupcakeModal(context, stringItem, uid);
      } else if (isAddon) {
        _showAddOnModal(context, stringItem, uid);
      } else {
        _showCustomizeModal(context, stringItem, availability, flavours, uid);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Fetch Error: $e");
    }
  }

  void _showCupcakeModal(
    BuildContext context,
    Map<String, String> item,
    String uid,
  ) {
    List<String> packSizes = ['3 pc', '6 pc', '12 pc'];
    String selectedPack = packSizes.first;

    int basePrice =
        int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int multiplier = 1;
            if (selectedPack == '6 pc') multiplier = 2;
            if (selectedPack == '12 pc') multiplier = 4;

            int currentPrice = basePrice * multiplier;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 420,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: SizedBox(
                                    height: 100,
                                    width: 100,
                                    child: _buildImage(item['image']),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "₹$currentPrice",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            Text(
                              "Select Box Size",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: packSizes.map((pack) {
                                bool isSelected = selectedPack == pack;
                                return GestureDetector(
                                  onTap: () =>
                                      setModalState(() => selectedPack = pack),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primaryColor
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      pack,
                                      style: GoogleFonts.inter(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addCupcakeToCart(
                              context,
                              item,
                              selectedPack,
                              currentPrice,
                              uid,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "ADD TO CART  •  ₹$currentPrice",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomizeModal(
    BuildContext context,
    Map<String, String> item,
    Map<String, dynamic> availability,
    Map<String, int> availableFlavours,
    String uid,
  ) {
    List<String> sizes = [];
    if (availability['halfKg'] != false) sizes.add('0.5 Kg');
    if (availability['oneKg'] != false) sizes.add('1 Kg');
    if (availability['oneHalfKg'] != false) sizes.add('1.5 Kg');
    if (availability['twoKg'] != false) sizes.add('2 Kg');
    if (availability['twoHalfKg'] != false) sizes.add('2.5 Kg');
    if (availability['threeKg'] != false) sizes.add('3 Kg');

    if (sizes.isEmpty) {
      sizes = ['0.5 Kg', '1 Kg', '1.5 Kg', '2 Kg', '2.5 Kg', '3 Kg'];
    }

    List<String> shapes = [];
    if (availability['round'] != false) shapes.add('Round');
    if (availability['square'] != false) shapes.add('Square');
    if (availability['heart'] != false) shapes.add('Heart');
    if (shapes.isEmpty) shapes.addAll(['Round', 'Square', 'Heart']);

    final TextEditingController cakeWritingController = TextEditingController();

    bool isOffer = item['isOffer'] == 'true';
    String activePriceString =
        (isOffer &&
            item['offerPrice'] != null &&
            item['offerPrice']!.isNotEmpty)
        ? item['offerPrice']!
        : item['price'] ?? '0';

    int basePrice =
        int.tryParse(activePriceString.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int originalBasePrice =
        int.tryParse(
          (item['price'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        basePrice;

    String selectedShape = shapes.first;
    String selectedWeight = sizes.contains("1 Kg") ? "1 Kg" : sizes.first;
    String? selectedFlavourKey = availableFlavours.isNotEmpty
        ? availableFlavours.keys.first
        : null;
    int selectedFlavourPrice = availableFlavours.isNotEmpty
        ? availableFlavours.values.first
        : 0;

    final Widget cachedCakeImage = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        color: const Color(0xFFF9F9F9),
        height: 100,
        width: 100,
        padding: const EdgeInsets.all(8),
        child: Hero(
          tag: "${item['name']}_modal_${item['id']}",
          child: _buildImage(item['image']!),
        ),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        int currentPrice = basePrice + selectedFlavourPrice;
        int originalCurrentPrice = originalBasePrice + selectedFlavourPrice;

        return StatefulBuilder(
          builder: (context, setModalState) {
            double multiplier = 1.0;
            switch (selectedWeight) {
              case '0.5 Kg':
                multiplier = 0.5;
                break;
              case '1 Kg':
                multiplier = 1.0;
                break;
              case '1.5 Kg':
                multiplier = 1.5;
                break;
              case '2 Kg':
                multiplier = 2.0;
                break;
              case '2.5 Kg':
                multiplier = 2.5;
                break;
              case '3 Kg':
                multiplier = 3.0;
                break;
              default:
                multiplier = 1.0;
            }

            currentPrice =
                (basePrice * multiplier).toInt() + selectedFlavourPrice;
            originalCurrentPrice =
                (originalBasePrice * multiplier).toInt() + selectedFlavourPrice;

            if (selectedShape == "Heart") {
              currentPrice += 50;
              originalCurrentPrice += 50;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 500
                    : double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                cachedCakeImage,
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']!,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            duration: const Duration(
                                              milliseconds: 400,
                                            ),
                                            curve: Curves.easeOutQuart,
                                            tween: Tween<double>(
                                              begin: currentPrice.toDouble(),
                                              end: currentPrice.toDouble(),
                                            ),
                                            builder: (context, value, child) {
                                              return Text(
                                                "₹${value.toInt()}",
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: _primaryColor,
                                                ),
                                              );
                                            },
                                          ),

                                          if (isOffer) ...[
                                            const SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2.0,
                                              ),
                                              child: TweenAnimationBuilder<double>(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                curve: Curves.easeOutQuart,
                                                tween: Tween<double>(
                                                  begin: originalCurrentPrice
                                                      .toDouble(),
                                                  end: originalCurrentPrice
                                                      .toDouble(),
                                                ),
                                                builder: (context, value, child) {
                                                  return Text(
                                                    "₹${value.toInt()}",
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                        ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            if (item['desc'] != null &&
                                item['desc']!.isNotEmpty) ...[
                              Text(
                                "DESCRIPTION",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['desc']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 25),

                            Text(
                              "SELECT SHAPE",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: shapes.map((shape) {
                                bool isSelected = selectedShape == shape;
                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => selectedShape = shape,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primaryColor.withOpacity(0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: _primaryColor
                                                    .withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      shape,
                                      style: GoogleFonts.inter(
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 25),

                            Text(
                              "SELECT WEIGHT",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: sizes.map((weight) {
                                bool isSelected = selectedWeight == weight;
                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => selectedWeight = weight,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primaryColor.withOpacity(0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: _primaryColor
                                                    .withOpacity(0.1),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      weight,
                                      style: GoogleFonts.inter(
                                        color: isSelected
                                            ? _primaryColor
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 25),

                            if (availableFlavours.isNotEmpty) ...[
                              Text(
                                "SELECT FLAVOR",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: availableFlavours.entries.map((
                                  entry,
                                ) {
                                  bool isSelected =
                                      selectedFlavourKey == entry.key;
                                  return GestureDetector(
                                    onTap: () => setModalState(() {
                                      selectedFlavourKey = entry.key;
                                      selectedFlavourPrice = entry.value;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _textDark
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? _textDark
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Text(
                                        "${entry.key} ${entry.value > 0 ? '(+₹${entry.value})' : ''}",
                                        style: GoogleFonts.inter(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 25),
                            ],

                            Text(
                              "MESSAGE ON CAKE",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: cakeWritingController,
                              maxLength: 30,
                              decoration: InputDecoration(
                                hintText: "e.g. Happy Birthday Name...",
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: _primaryColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);

                            Map<String, int> flavors = {};
                            if (selectedFlavourKey != null)
                              flavors[selectedFlavourKey!] =
                                  selectedFlavourPrice;

                            _addToCartWithDetails(
                              context,
                              item,
                              selectedShape,
                              selectedWeight,
                              currentPrice,
                              flavors,
                              cakeWritingController.text,
                              uid,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),

                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                                tween: Tween<double>(
                                  begin: currentPrice.toDouble(),
                                  end: currentPrice.toDouble(),
                                ),
                                builder: (context, value, child) {
                                  return Text(
                                    "ADD TO CART  •  ₹${value.toInt()}",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddOnModal(
    BuildContext context,
    Map<String, String> item,
    String uid,
  ) {
    int quantity = 1;
    int basePrice =
        int.tryParse(item['price']!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int currentPrice = basePrice * quantity;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 380,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: SizedBox(
                                    height: 100,
                                    width: 100,
                                    child: _buildImage(item['image']),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? '',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "₹$basePrice",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Text(
                              "Select Quantity",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (quantity > 1)
                                        setModalState(() => quantity--);
                                    },
                                  ),
                                  Text(
                                    "$quantity",
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      if (quantity < 50)
                                        setModalState(() => quantity++);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addAddonToCart(
                              context,
                              item,
                              quantity,
                              currentPrice,
                              uid,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "ADD TO CART  •  ₹$currentPrice",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeFromWishlist(String itemKey, String uid) async {
    await FirebaseDatabase.instance
        .ref()
        .child('users/$uid/wishlist/$itemKey')
        .remove();
  }

  void _addToCartWithDetails(
    BuildContext context,
    Map<String, String> item,
    String shape,
    String weight,
    int price,
    Map<String, int> finalFlavourMap,
    String writing,
    String uid,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'selected_shape': shape,
      'selected_weight': weight,
      'price': price,
      'display_price': "Rs $price",
      'quantity': 1,
      'flavours': jsonEncode(finalFlavourMap),
      'cakeWriting': writing.isEmpty ? "No Message" : writing,
      'delivery_address': currentSavedAddress,
      'category': 'Cake',
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/$uid/cart',
      );
      await dbRef.push().set(cartItem);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added ${item['name']} to cart!"),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      debugPrint("Cart Sync Error: $e");
    }
  }

  Future<void> _addAddonToCart(
    BuildContext context,
    Map<String, String> item,
    int quantity,
    int totalPrice,
    String uid,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': totalPrice,
      'display_price': "Rs $totalPrice",
      'quantity': quantity,
      'category': item['category'] ?? 'AddOn',
      'delivery_address': currentSavedAddress,
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/$uid/cart',
      );
      await dbRef.push().set(cartItem);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added ${item['name']} to cart!"),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding addon: $e");
    }
  }

  Future<void> _addCupcakeToCart(
    BuildContext context,
    Map<String, String> item,
    String packSize,
    int totalPrice,
    String uid,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentSavedAddress =
        prefs.getString('userAddress') ?? "No Address Selected";

    Map<String, dynamic> cartItem = {
      'name': item['name'],
      'image': item['image'],
      'price': totalPrice,
      'display_price': "Rs $totalPrice",
      'quantity': 1,
      'selected_weight': packSize,
      'category': item['category'] ?? 'Cupcake',
      'delivery_address': currentSavedAddress,
      'added_at': ServerValue.timestamp,
    };

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child(
        'users/$uid/cart',
      );
      await dbRef.push().set(cartItem);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  "Added to cart! ($packSize)",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding cupcake: $e");
    }
  }

  Widget _buildImage(String? imageString) {
    if (imageString == null || imageString.trim().isEmpty) {
      return Container(
        color: Colors.transparent,
        child: Center(
          child: Icon(
            Icons.cake_rounded,
            color: Colors.grey.shade400,
            size: 40,
          ),
        ),
      );
    }
    try {
      if (imageString.startsWith('assets/')) {
        return Image.asset(
          imageString,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (c, e, s) =>
              Icon(Icons.broken_image, color: Colors.grey.shade400),
        );
      } else if (imageString.startsWith('http')) {
        return Image.network(
          imageString,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (c, e, s) =>
              Icon(Icons.broken_image, color: Colors.grey.shade400),
        );
      } else {
        return Image.memory(
          base64Decode(imageString),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (c, e, s) =>
              Icon(Icons.broken_image, color: Colors.grey.shade400),
        );
      }
    } catch (e) {
      return Icon(Icons.broken_image, color: Colors.grey.shade400);
    }
  }

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 60,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            "WISHLIST IS EMPTY",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              color: _textDark,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Looks like you haven't saved any\nsweet treats yet.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
