import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../home/home_screen.dart';
import 'introduce_screen.dart';
import 'personal_info_screen.dart';

/// คลาส AuthWrapper ทำหน้าที่เป็น Reactive Router

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        
        // Asynchronous Loading State
        if (!appState.isInitialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // ผู้ใช้งานยังไม่ได้ล็อกอิน (หรือเพิ่งกด Log out ไป)
        // ระบบจะนำทางไปยังหน้า Intro / Login เพื่อให้เข้าสู่ระบบก่อน
        if (appState.currentUser == null) return const IntroduceScreen();
        
        // กรณีที่ผู้ใช้ผ่านการสร้างบัญชี Firebase Auth มาแล้ว (currentUser != null) 
        // แต่ปิดแอปไปก่อนที่จะกรอกข้อมูลโปรไฟล์ลงใน Firestore (userData == null)
        // ระบบจะบังคับให้ผู้ใช้กลับมาหน้า PersonalInfoScreen เสมอ เพื่อป้องกันปัญหาข้อมูลในระบบไม่สมบูรณ์ 
        if (appState.userData == null) return const PersonalInfoScreen();

        // ผู้ใช้มีทั้งบัญชี Auth และข้อมูลโปรไฟล์ใน Firestore ครบถ้วน ระบบจะอนุญาตให้เข้าสู่หน้าหลักของแอปพลิเคชัน
        return const HomeScreen();
      },
    );
  }
}