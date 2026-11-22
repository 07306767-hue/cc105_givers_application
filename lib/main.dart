import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'auth/auth_service.dart';
import 'auth/login_screen.dart';
import 'firebase_bootstrap.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/givents_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await connectFirebaseEmulators();
  await GiventsRemoteConfigService.instance.initialize();
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  runApp(const GiventsApp());
}

class GiventsApp extends StatelessWidget {
  const GiventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Givents',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) return const LoginScreen();
          return FutureBuilder<GiventsRole>(
            future: GiventsAuthService().roleForUid(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.hasError) {
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }
              if (!roleSnapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return RoleBasedAppShell(role: roleSnapshot.data!);
            },
          );
        },
      ),
    );
  }
}
