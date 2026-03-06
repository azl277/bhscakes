import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
