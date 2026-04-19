import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'auth_screen.dart';

class IntroduceScreen extends StatelessWidget {
  const IntroduceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/logo_white.png',
                  width: 61,
                  height: 70,
                ),
              ),
              const SizedBox(height: 30),
              // ตกแต่งด้วย Gradient
              Container(
                height: 236,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.darkPurple, AppColors.mediumPurple],
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.asset(
                    'assets/images/FabricIntro_image.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // ดึงชื่อจาก AppStrings
              const Text(
                '" ${AppStrings.appTitle} "',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkPurple,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'แอปพลิเคชันเช็คอินท่องเที่ยว 77 จังหวัด ของประเทศไทย ที่ผสานแนวคิดการเดินทาง เข้ากับอัตลักษณ์ทางวัฒนธรรม ผ่านการสะสมแสตมป์ลายผ้าไหมไทยประจำจังหวัด',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkPurple,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'เข้าใช้งานด้วยอีเมล',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
