import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'data/app_services.dart';
import 'firebase_options.dart';
export 'app.dart' show JVApp, LoginPage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  try {
    await Firebase.initializeApp(
      options: emulator
          ? const FirebaseOptions(
              apiKey: 'demo-key',
              appId: '1:123:web:demo',
              messagingSenderId: '123',
              projectId: 'demo-jv',
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'mora2',
    );
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    if (emulator) {
      firestore.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      functions.useFunctionsEmulator(host, 5001);
    } else {
      const key = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
      if (kIsWeb && key.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(key),
        );
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
        );
      }
    }
    appServices = AppServices(
      auth: FirebaseAuth.instance,
      firestore: firestore,
      functions: functions,
    );
    runApp(const JVApp());
  } catch (error, stack) {
    debugPrint('No se pudo iniciar la aplicación: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se pudo iniciar JV Líderes. Revisa tu conexión y vuelve a abrir la aplicación.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
