// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/pantry_provider.dart';
import 'providers/user_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => UserAuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => PantryProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Builder(
        builder: (context) {
          context.read<UserAuthProvider>().onUserLoaded = (uid) async {
            final userProvider = context.read<UserProvider>();
            await userProvider.loadUser(uid);
            if (!context.mounted) return;
            context.read<LocationProvider>().loadFromFirestore(uid);
            context.read<PantryProvider>().setCurrentUser(userProvider.user);
            context.read<NotificationProvider>().bindUser(uid);
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
