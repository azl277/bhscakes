
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions]

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAko_QyTrP0LlwxOQMxH30qBEzKNskz89c',
    appId: '1:548513843938:web:6d2dc0c4d4524bbeb8ecbb',
    messagingSenderId: '548513843938',
    projectId: 'bhscakes-c6d32',
    authDomain: 'bhscakes-c6d32.firebaseapp.com',
    storageBucket: 'bhscakes-c6d32.firebasestorage.app',
    measurementId: 'G-ZZX8MCGGC0',
    databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUQa0n7vtjPpCXsW84dkQHNEtcWC5jEVc',
    appId: '1:548513843938:android:221f60470b664403b8ecbb',
    messagingSenderId: '548513843938',
    projectId: 'bhscakes-c6d32',
    storageBucket: 'bhscakes-c6d32.firebasestorage.app',
     databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCVy25NYU-iOCFK9UyHtchCgdtOo2dY1jk',
    appId: '1:548513843938:ios:ebdc9040be59796fb8ecbb',
    messagingSenderId: '548513843938',
    projectId: 'bhscakes-c6d32',
    storageBucket: 'bhscakes-c6d32.firebasestorage.app',
    iosBundleId: 'com.example.project',
      databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
  );

  

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCVy25NYU-iOCFK9UyHtchCgdtOo2dY1jk',
    appId: '1:548513843938:ios:ebdc9040be59796fb8ecbb',
    messagingSenderId: '548513843938',
    projectId: 'bhscakes-c6d32',
    storageBucket: 'bhscakes-c6d32.firebasestorage.app',
    iosBundleId: 'com.example.project',
    databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAko_QyTrP0LlwxOQMxH30qBEzKNskz89c',
    appId: '1:548513843938:web:1e36710ff06bed5ab8ecbb',
    messagingSenderId: '548513843938',
    projectId: 'bhscakes-c6d32',
    authDomain: 'bhscakes-c6d32.firebaseapp.com',
    storageBucket: 'bhscakes-c6d32.firebasestorage.app',
    measurementId: 'G-J02C3PC16M',
    databaseURL: "https://bhscakes-app-default-rtdb.firebaseio.com/"
  );
}
