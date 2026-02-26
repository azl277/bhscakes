import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/Loginpage2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isLoading = false;
  final TextEditingController _confirmController = TextEditingController();
  final String _confirmationKeyword = "DELETE";

  // ---------------------------------------------------------------------------
  // 🔴 CORE DELETE LOGIC (This is the function you were looking for)
  // ---------------------------------------------------------------------------
  Future<void> _deleteAccount() async {
    // 1. Input Validation
    if (_confirmController.text.trim() != _confirmationKeyword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type DELETE exactly to confirm."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _navigateToLogin();
        return;
      }

      final String uid = user.uid;

      // 🟢 2. DELETE ORDERS FROM CLOUD FIRESTORE
      // We query all orders belonging to this user
      final QuerySnapshot orderSnapshots = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .get();

      // Use Batch Write for efficiency
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in orderSnapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit(); 

      // 🟢 3. DELETE ORDERS FROM REALTIME DATABASE
      // Query RTDB orders where userId matches
      final DatabaseReference rtdbOrdersRef = FirebaseDatabase.instance.ref().child('orders');
      final DataSnapshot rtdbSnap = await rtdbOrdersRef.orderByChild('userId').equalTo(uid).get();

      if (rtdbSnap.exists) {
        // Loop through the results and delete them one by one
        Map<dynamic, dynamic> values = rtdbSnap.value as Map<dynamic, dynamic>;
        for (var key in values.keys) {
          await rtdbOrdersRef.child(key).remove();
        }
      }

      // 🟢 4. DELETE USER PROFILES & WISHLIST
      // Realtime Database Profile
      await FirebaseDatabase.instance.ref().child('users').child(uid).remove();
      
      // Cloud Firestore Profile
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      
      // Delete Wishlist
      final wishlistSnap = await FirebaseFirestore.instance
          .collection('wishlist')
          .where('userEmail', isEqualTo: user.email)
          .get();
      
      WriteBatch wishlistBatch = FirebaseFirestore.instance.batch();
      for (var doc in wishlistSnap.docs) {
        wishlistBatch.delete(doc.reference);
      }
      await wishlistBatch.commit();

      // 5. DELETE AUTH ACCOUNT
      await user.delete();

      // 6. CLEANUP LOCAL STORAGE
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 7. SUCCESS
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account and all data deleted successfully."))
        );
        _navigateToLogin();
      }

    } on FirebaseAuthException catch (e) {
      // 🔴 SECURITY CHECK: User needs to re-login
      if (e.code == 'requires-recent-login') {
        if (mounted) _showReauthDialog();
      } else {
        _showError("Firebase Error: ${e.message}");
      }
    } catch (e) {
      _showError("Unexpected Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Loginpage2()),
      (Route<dynamic> route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showReauthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Security Verification"),
        content: const Text("For your security, deleting an account requires a recent login. Please log out and log in again to verify your identity."),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) _navigateToLogin();
            }, 
            child: const Text("Logout & Verify", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎨 UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5), // Very light red tint
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              "Are you sure?",
              style: GoogleFonts.fahkwang(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "This action is permanent. You will lose all your orders, wishlist items, saved addresses, and profile data immediately.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 40),

            // Confirmation Input
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Type \"$_confirmationKeyword\" to confirm:",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: _confirmationKeyword,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Permanently Delete Account", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
              ),
            ),

            const SizedBox(height: 20),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Nevermind, keep my account", style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}