import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<({String title, String body})> _faqs = [
    (title: 'วิธีการเช็คอินเพื่อสะสมแสตมป์?', body: 'เมื่อคุณเดินทางไปถึงจังหวัดใด ๆ แอปจะตรวจจับตำแหน่งของคุณโดยอัตโนมัติผ่าน GPS จากนั้นกดปุ่ม \'เช็คอิน\' ที่หน้าหลักเพื่อรับแสตมป์ลายผ้าประจำจังหวัดนั้น'),
    (title: 'ทำไมแอพตรวจไม่พบตำแหน่งของฉัน?', body: 'ตรวจสอบว่าคุณได้เปิดใช้งาน GPS และอนุญาตให้แอปเข้าถึงตำแหน่งแล้ว'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Symbols.arrow_back_ios_new, color: AppColors.darkPurple)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          children: [
            const Text('ช่วยเหลือ', style: TextStyle(color: AppColors.darkPurple, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text('คำถามที่พบบ่อย', style: TextStyle(color: AppColors.darkPurple, fontSize: 16)),
            const SizedBox(height: 25),
            for (final faq in _faqs) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(faq.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple, fontSize: 14)),
                    const SizedBox(height: 10),
                    Text(faq.body, style: const TextStyle(color: AppColors.mediumPurple, fontSize: 14, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
          ],
        ),
      ),
    );
  }
}