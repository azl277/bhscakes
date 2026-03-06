// FILE: lib/my_app.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart'; // 🟢 Added for Push Notifications

// --- RELATIVE IMPORTS ---
import 'firstpage.dart';
import 'secondpage.dart'; 

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 1. Create a Global Navigator Key to control routing from the background
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  StreamSubscription<DocumentSnapshot>? _shopStatusSub;
  bool _wasStoreClosed = false;

  @override
  void initState() {
    super.initState();
    _listenToStoreStatus();
    _setupPushNotifications(); // 🟢 Initialize Notifications on app start
  }

  // 🟢 NEW: SETUP PUSH NOTIFICATIONS & SAVE DEVICE TOKEN
 // 🟢 DEBUG VERSION: SETUP PUSH NOTIFICATIONS
  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return; 

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    debugPrint("🚀 FCM: Requesting permissions...");
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint("🚀 FCM: Permission status: ${settings.authorizationStatus}");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🚀 FCM: Foreground Message Received!');
    });

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      debugPrint("🚀 FCM: Auth State Fired. User logged in? ${user != null}");
      
      if (user != null) {
        try {
          debugPrint("🚀 FCM: Attempting to fetch token from Google...");
          String? token = await messaging.getToken();
          
          debugPrint("🚀 FCM: Token generated! -> $token");
          
          if (token != null) {
            debugPrint("🚀 FCM: Saving token to Firestore for UID: ${user.uid}...");
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'fcmToken': token,
            }, SetOptions(merge: true)); 
            debugPrint("✅ FCM: Token successfully saved to database!");
          }

          messaging.onTokenRefresh.listen((newToken) {
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'fcmToken': newToken,
            }, SetOptions(merge: true));
          });
          
        } catch (e) {
          debugPrint("❌ FCM ERROR: Could not get token. Details: $e");
        }
      }
    });
  }
  void _listenToStoreStatus() {
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
        
        // If the store JUST changed from Open to Closed...
        if (isClosedNow && !_wasStoreClosed) {
          // Kick everyone out of their current page back to the root Home Screen
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
      // Attach the Global Key so it can manage your screens
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Butter Hearts Cakes',
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.pink, 
        brightness: Brightness.dark
      ),
      
      // Standard Auth check handles the login/home state natively
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