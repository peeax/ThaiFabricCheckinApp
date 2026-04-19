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
    // ใช้ Future.delayed เพื่อหน่วงเวลาให้หน้า Splash Screen แสดงผลเป็นเวลา 2 วินาที
    Future.delayed(const Duration(seconds: 2), _navigateToAuth);
  }

  void _navigateToAuth() {
    if (!mounted) return;
    // เพื่อทำลายหน้า Splash Screen ทิ้งและนำหน้า AuthWrapper มาแทนที่ใน Navigation Stack
    // ป้องกันปัญหา UX ที่ผู้ใช้กดปุ่มย้อนกลับ (Back Button ของ Android) แล้วเด้งกลับมาเจอหน้า Splash อีกรอบ
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ขยาย Container ให้เต็มหน้าจอทั้งความกว้างและความสูง (Full-screen UI)
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.darkPurple, AppColors.mediumPurple])),
        child: Center(child: Image.asset('assets/images/logo_black.png', width: 220)),
      ),
    );
  }
}