import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Firebase is only set up for Android and Web.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBG-5cF77bHShnh57VXPp56RyKf9LlLsmM',
    appId: '1:374362788587:web:e62317854ea9628dbae4ae',
    messagingSenderId: '374362788587',
    projectId: 'kingdom-wars-b293a',
    authDomain: 'kingdom-wars-b293a.firebaseapp.com',
    storageBucket: 'kingdom-wars-b293a.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcRINyeb-gxU_eWFcGlnHdcuYzvjlWk6c',
    appId: '1:374362788587:android:fe17decea8ee7784bae4ae',
    messagingSenderId: '374362788587',
    projectId: 'kingdom-wars-b293a',
    storageBucket: 'kingdom-wars-b293a.firebasestorage.app',
  );
}
