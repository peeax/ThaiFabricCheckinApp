import 'package:flutter/material.dart';
import 'main_wrapper.dart'; // import wrapper เข้ามา

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thai Fabric Checkin',
      debugShowCheckedModeBanner: false,
      home: const MainWrapper(), // ใช้ Wrapper เป็นหน้าหลัก
    );
  }
}