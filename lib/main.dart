import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/constants.dart';
import 'screens/intro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AewMaiApp());
}

class AewMaiApp extends StatelessWidget {
  const AewMaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'แอ่วไหม',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: darkPurple),
        fontFamily: appFont,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: darkPurple,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}