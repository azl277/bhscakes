import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final Color _accentPink = const Color(0xFFFF2E74);
  final Color _premiumBlack = const Color(0xFF1A1A1A);

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SAVED ADDRESSES",
          style: GoogleFonts.fahkwang(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        backgroundColor: _accentPink,
        elevation: 4,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text(
          "Add New",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('addresses')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _accentPink));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading addresses",
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: snapshot.data!.docs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildAddressCard(data, doc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> data, String docId) {
    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        FirebaseFirestore.instance.collection('addresses').doc(docId).delete();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentPink.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: _accentPink,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['tag'] ?? "Home",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _premiumBlack,
                        ),
                      ),

                      InkWell(
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('addresses')
                              .doc(docId)
                              .delete();
                        },
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['address'] ?? "",
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "PIN: ${data['pincode']}",
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 14, color: _accentPink),
                      const SizedBox(width: 5),
                      Text(
                        data['phone'] ?? "",
                        style: GoogleFonts.inter(
                          color: _premiumBlack,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_location_alt_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "NO ADDRESSES YET",
            style: GoogleFonts.fahkwang(
              fontWeight: FontWeight.bold,
              color: Colors.black26,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Add a location for faster checkout!",
            style: TextStyle(color: Colors.black26),
          ),
        ],
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    _nameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _pincodeController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          25,
          25,
          25,
          MediaQuery.of(context).viewInsets.bottom + 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Add New Address",
              style: GoogleFonts.fahkwang(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),

            _buildTextField(
              _nameController,
              "Label (e.g. Home, Office)",
              Icons.bookmark_border,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              _addressController,
              "Full Address (House No, Street)",
              Icons.home_outlined,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _pincodeController,
                    "Pincode",
                    Icons.pin_drop_outlined,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTextField(
                    _phoneController,
                    "Phone Number",
                    Icons.phone_outlined,
                    isNumber: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (_addressController.text.isNotEmpty && user != null) {
                    await FirebaseFirestore.instance
                        .collection('addresses')
                        .add({
                          'userId': user!.uid,
                          'tag': _nameController.text.isEmpty
                              ? "Home"
                              : _nameController.text,
                          'address': _addressController.text,
                          'pincode': _pincodeController.text,
                          'phone': _phoneController.text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Address Saved Successfully!"),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "SAVE ADDRESS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: _premiumBlack,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _accentPink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}
