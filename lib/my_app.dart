// FILE: lib/my_app.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- RELATIVE IMPORTS ---
import 'firstpage.dart';
import 'secondpage.dart'; 

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 🟢 1. Create a Global Navigator Key to control routing from the background
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  StreamSubscription<DocumentSnapshot>? _shopStatusSub;
  bool _wasStoreClosed = false;

  @override
  void initState() {
    super.initState();
    
    // 🟢 2. Background Listener for the Kill Switch
    _shopStatusSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('store_status')
        .snapshots()
        .listen((snapshot) {
          
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        bool isOpen = data['isOpen'] ?? true;
        DateTime? resumeAt = data['resumeAt'] != null ? (data['resumeAt'] as Timestamp).toDate() : null;
        
        bool isClosedNow = !isOpen && (resumeAt == null || resumeAt.isAfter(DateTime.now()));
        
        // 🟢 3. If the store JUST changed from Open to Closed...
        if (isClosedNow && !_wasStoreClosed) {
          // Kick everyone out of their current page (Cart, Menu, etc.) 
          // back to the root Home Screen (Secondpage) where the Blur Overlay is.
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        
        _wasStoreClosed = isClosedNow;
      }
    });
  }

  @override
  void dispose() {
    _shopStatusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🟢 4. Attach the Global Key so it can manage your screens
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Butter Hearts Cakes',
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.pink, 
        brightness: Brightness.dark
      ),
      
      // 🟢 5. Standard Auth check handles the login/home state natively
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } 
          
          if (authSnapshot.hasData) {
            return const Secondpage(); 
          }

          return const Firstpage();
        },
      ),
    );
  }
}