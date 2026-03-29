import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart'; // อย่าลืม import ตัวนี้ด้วยครับ

class StampBook extends StatefulWidget {
  const StampBook({super.key});

  @override
  State<StampBook> createState() => _StampBookState();
}

class _StampBookState extends State<StampBook> {
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'สมุดสะสมแสตมป์',
          style: TextStyle(color: Color(0xFF13084C), fontFamily: 'Anuphan'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'หน้านี้จะแสดงรายการแสตมป์ของคุณ',
          style: TextStyle(fontSize: 18, fontFamily: 'Anuphan'),
        ),
      ),
      // 3. เพิ่มแถบเมนูด้านล่าง
    );
  }

 
}