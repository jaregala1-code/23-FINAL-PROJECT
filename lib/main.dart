// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/location_provider.dart';
import 'providers/pantry_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'providers/chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Core auth ─────────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => UserAuthProvider()),

        // ── Milestone providers ───────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => PantryProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Wire UserAuthProvider → UserProvider + LocationProvider so that
          // after login the milestone widgets have data without a second tap.
          context.read<UserAuthProvider>().onUserLoaded = (uid) {
            context.read<UserProvider>().loadUser(uid);
            context.read<LocationProvider>().loadFromFirestore(uid);
          };
          return MaterialApp(
            title: 'ELBites',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
