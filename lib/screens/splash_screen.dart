import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'auth/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _navigateToAuth);
  }

  void _navigateToAuth() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.darkPurple, AppColors.mediumPurple])),
        child: Center(child: Image.asset('assets/images/logo_black.png', width: 220)),
      ),
    );
  }
}