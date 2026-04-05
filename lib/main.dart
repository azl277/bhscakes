import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'my_app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
        databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/",
      ),
    );
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    try {
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
            databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/",
          ),
        );
      }
      
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (e) {
        await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      }
    } catch (firebaseError, stack) {
      runApp(_buildCrashScreen("FIREBASE CRASH:\n$firebaseError", stack));
      return;
    }

    if (!kIsWeb) {
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
      }
    }

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );

  } catch (e, stack) {
    runApp(_buildCrashScreen("GENERAL CRASH:\n$e", stack));
  }
}

Widget _buildCrashScreen(String errorText, StackTrace stack) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: Colors.blue.shade900,
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Text(
            "$errorText\n\n$stack",
            style: const TextStyle(color: Colors.yellow, fontSize: 12),
          ),
        ),
      ),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      try {
        final brightness = WidgetsBinding.instance?.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
      } catch (e) {
        return false; // Safe fallback
      }
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}