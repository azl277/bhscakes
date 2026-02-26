import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isWaitingForVerification = false;

  // STEP 1: Create Account & Send Verification Link
  Future<void> _handleSignup() async {
    String email = _emailController.text.trim();
    String name = _nameController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isNotEmpty && email.endsWith("@gmail.com") && password.length >= 6) {
      try {
        // Create User in Firebase
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Send Verification Link to the user's email
        await userCredential.user!.sendEmailVerification();

        setState(() {
          _isWaitingForVerification = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification link sent! Please check your Gmail.")),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "An error occurred")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields correctly (Password: min 6 chars)")),
      );
    }
  }

  // STEP 2: Check if the user has clicked the link in their email
  Future<void> _checkVerificationStatus() async {
    User? user = _auth.currentUser;
    await user?.reload(); // Refresh user data from Firebase

    if (user != null && user.emailVerified) {
      // Save user details locally for the Profile Page
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _nameController.text.trim());
      await prefs.setString("email", _emailController.text.trim());
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email Verified! Welcome to Butter Hearts Cakes.")),
        );
        Navigator.pop(context, true); // Go back to Home/SecondPage
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email not verified yet. Tap the link in your email.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/aaaa.jpg"), fit: BoxFit.cover),
            ),
          ),
          // Glass Blur Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset("assets/logo.png", height: 80),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(60),
                        bottomRight: Radius.circular(60),
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isWaitingForVerification ? _buildVerifyUI() : _buildSignupUI(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupUI() {
    return Column(
      key: const ValueKey("SignupFields"),
      children: [
        _buildTextField(_nameController, "Full Name", Icons.person),
        const SizedBox(height: 15),
        _buildTextField(_emailController, "Gmail Address", Icons.email),
        const SizedBox(height: 15),
        _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
        const SizedBox(height: 30),
        _buildActionButton("SIGN UP", _handleSignup),
      ],
    );
  }

  Widget _buildVerifyUI() {
    return Column(
      key: const ValueKey("VerifyStatus"),
      children: [
        const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 50),
        const SizedBox(height: 15),
        Text("Check Your Email", style: GoogleFonts.fahkwang(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          "We've sent a link to your Gmail. Click it, then tap the button below.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 25),
        _buildActionButton("I HAVE VERIFIED", _checkVerificationStatus),
        TextButton(
          onPressed: () => setState(() => _isWaitingForVerification = false),
          child: const Text("Go Back", style: TextStyle(color: Colors.white60, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 180,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }
}