import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project/otppage.dart';

import 'OtpPage.dart' hide OtpPage;
import 'package:shared_preferences/shared_preferences.dart';

class Loginpage2 extends StatefulWidget {
  const Loginpage2({super.key});

  @override
  State<Loginpage2> createState() => _Loginpage2State();
}

class _Loginpage2State extends State<Loginpage2> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLogin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final phoneRaw = _phoneController.text.trim();
    final phone = "+91$phoneRaw";
    String name = "";
    if (!_isLogin) {
      name = _nameController.text.trim();
    }
    setState(() => _isLoading = true);
    try {
      print("🔍 Checking Databases for $phone...");
      final QuerySnapshot firestoreResult = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      final DataSnapshot rtdbSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .orderByChild('phone')
          .equalTo(phone)
          .get();
      final bool userExists =
          firestoreResult.docs.isNotEmpty || rtdbSnapshot.exists;
      print("✅ Sync Check: User exists: $userExists");

      if (!_isLogin && userExists) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Number already registered. Please Login.");
        return;
      }

      if (_isLogin && !userExists) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Account not found. Please Register first.");
        return;
      }
      if (!_isLogin) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);
      }
      print("🚀 Requesting OTP from Firebase...");
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("✅ Auto-verification completed (Android)");
          setState(() => _isLoading = false);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          print("🚨 AUTH ERROR: ${e.code} - ${e.message}");

          String msg = e.message ?? "Verification Failed";
          if (e.code == 'invalid-phone-number') msg = "Invalid Mobile Number";
          if (e.code == 'app-not-authorized')
            msg = "App Not Authorized (Check SHA-1 Key)";
          if (e.code == 'too-many-requests')
            msg = "Too many attempts. Try again later.";
          if (e.code == 'network-request-failed')
            msg = "Network Error. Check Internet/Permissions.";

          _showErrorSnackBar(msg);
        },
        codeSent: (String verificationId, int? resendToken) {
          print("✅ OTP Sent! ID: $verificationId");
          setState(() => _isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(
                verificationId: verificationId,
                phoneNumber: phone,
                userName: _isLogin ? "" : name,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      print("💥 SYNC ERROR: $e");
      String errorMsg = "An unexpected error occurred.";
      if (e.toString().contains("permission-denied")) {
        errorMsg = "Database Permission Denied (Check Firebase Rules)";
      } else if (e.toString().contains("network_error")) {
        errorMsg = "Connection failed. Check Internet.";
      }
      _showErrorSnackBar(errorMsg);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDA008A).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                "assets/aaaa.jpg",
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.6),
                colorBlendMode: BlendMode.darken,
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const ClampingScrollPhysics(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: size.width > 600 ? 450 : double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 30 : 45,
                        horizontal: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Butter Hearts Cakes",
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isSmallScreen ? 32 : 25,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _isLogin ? "WELCOME BACK" : "CREATE ACCOUNT",
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 25 : 40),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildToggleButton("Login", true),
                                  _buildToggleButton("Register", false),
                                ],
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 25 : 35),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              child: _isLogin
                                  ? const SizedBox.shrink()
                                  : Column(
                                      children: [
                                        _buildModernField(
                                          controller: _nameController,
                                          hint: "Full Name",
                                          icon: Icons.person_outline_rounded,
                                          inputType: TextInputType.name,
                                          action: TextInputAction.next,
                                          autofill: [AutofillHints.name],
                                          validator: (val) {
                                            if (!_isLogin &&
                                                (val == null || val.isEmpty)) {
                                              return "Please enter your name";
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                            ),
                            _buildModernField(
                              controller: _phoneController,
                              hint: "Mobile Number",
                              icon: Icons.phone_iphone_rounded,
                              isPhone: true,
                              inputType: TextInputType.phone,
                              action: TextInputAction.done,
                              autofill: [AutofillHints.telephoneNumber],
                              validator: (val) => (val!.length < 10)
                                  ? "Enter valid number"
                                  : null,
                            ),
                            SizedBox(height: isSmallScreen ? 30 : 45),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDA008A),
                                  foregroundColor: Colors.white,
                                  elevation: 10,
                                  shadowColor: const Color(
                                    0xFFDA008A,
                                  ).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  splashFactory: _isLoading
                                      ? NoSplash.splashFactory
                                      : null,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _isLogin
                                                ? "GET OTP"
                                                : "REGISTER NOW",
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isLoginBtn) {
    final bool isSelected = _isLogin == isLoginBtn;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isLogin = isLoginBtn;
            _formKey.currentState?.reset();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDA008A) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFDA008A).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            text,
            style: GoogleFonts.montserrat(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType inputType,
    required TextInputAction action,
    required Iterable<String> autofill,
    bool isPhone = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      textInputAction: action,
      autofillHints: autofill,
      maxLength: isPhone ? 10 : null,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: const Color(0xFFDA008A),
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly] : [],
      decoration: InputDecoration(
        counterText: "",
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              if (isPhone) ...[
                const SizedBox(width: 12),
                Text(
                  "+91",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ],
            ],
          ),
        ),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDA008A)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: GoogleFonts.montserrat(
          color: Colors.pinkAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
