// FILE: lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// IMPORT YOUR NEW FILE HERE
import 'my_app.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- CONNECTING TO YOUR NEW FIREBASE PROJECT (bhscakes-app) ---
  // Fix: Check if Firebase is already running before initializing it
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAoAP9AUAt4c6oNPamw6XdfD6fLhB-t1Cc",
        authDomain: "bhscakes-app.firebaseapp.com",
        projectId: "bhscakes-app",
        storageBucket: "bhscakes-app.firebasestorage.app",
        messagingSenderId: "627320925052",
        appId: "1:627320925052:web:b9833433f5bdb4a89252f9",
        measurementId: "G-4P3RV9P4XC",
        databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
      ),
    );
  }

runApp(
    // You MUST wrap the app in this for ThemeProvider to work!
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // This is the specific getter the UI looks for
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}