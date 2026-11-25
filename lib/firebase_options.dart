import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated from google-services.json & GoogleService-Info.plist
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAr1pzPJVpN4j92-cIvr20CASTTWWsw4_c',
    appId: '1:14840051021:android:8eafee54fe7fec440d3304',
    messagingSenderId: '14840051021',
    projectId: 'clap-in-d9245',
    storageBucket: 'clap-in-d9245.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZVrHPwpOrsH5W10UDB8L6Y93MDZK-XqU',
    appId: '1:14840051021:ios:aa7d29861ca5afdb0d3304',
    messagingSenderId: '14840051021',
    projectId: 'clap-in-d9245',
    storageBucket: 'clap-in-d9245.firebasestorage.app',
    iosBundleId: 'dev.clapin.elienoel',
  );
}
