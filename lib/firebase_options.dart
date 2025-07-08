import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCp1wlOYpr7d9Gp5bGhubEJZfYcgJPG-K0',
    appId: '1:834531859075:web:your-web-app-id',
    messagingSenderId: '834531859075',
    projectId: 'replywise-7d363',
    authDomain: 'replywise-7d363.firebaseapp.com',
    storageBucket: 'replywise-7d363.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCp1wlOYpr7d9Gp5bGhubEJZfYcgJPG-K0',
    appId: '1:834531859075:android:6bd3b9c52c9ef6eb5619b6',
    messagingSenderId: '834531859075',
    projectId: 'replywise-7d363',
    storageBucket: 'replywise-7d363.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCp1wlOYpr7d9Gp5bGhubEJZfYcgJPG-K0',
    appId: '1:834531859075:ios:your-ios-app-id',
    messagingSenderId: '834531859075',
    projectId: 'replywise-7d363',
    storageBucket: 'replywise-7d363.firebasestorage.app',
    iosBundleId: 'com.app.replywise',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCp1wlOYpr7d9Gp5bGhubEJZfYcgJPG-K0',
    appId: '1:834531859075:macos:your-macos-app-id',
    messagingSenderId: '834531859075',
    projectId: 'replywise-7d363',
    storageBucket: 'replywise-7d363.firebasestorage.app',
    iosBundleId: 'com.app.replywise',
  );
}
