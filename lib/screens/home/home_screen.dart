import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import 'check_in_view.dart';
import '../stamps/stamps_view.dart';
import '../leaderboard/leaderboard_view.dart';
import '../events/nearby_events_view.dart';
import '../profile/profile_view.dart';

/// Bottom Navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // สถานะเก็บ Index ของแท็บที่กำลังเปิดอยู่ (เริ่มต้นที่ 0 คือหน้าหลัก)
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CheckInView(
        onChangeTab: (index) => setState(() => _selectedTabIndex = index),
      ),
      const StampsView(),
      const LeaderboardView(),
      const NearbyEventsView(),
      const ProfileView(),
    ];

    return Scaffold(
      // ใช้ IndexedStack ระบบจะ Render วิดเจ็ตทั้งหมดเก็บไว้ใน Memoryช่วยให้ผู้ใช้สลับแท็บไปมาได้เร็ว
      body: IndexedStack(index: _selectedTabIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.darkPurple,
        unselectedItemColor: Colors.grey,

        // กำหนดไอคอนและข้อความของแต่ละแท็บ
        items: const [
          BottomNavigationBarItem(icon: Icon(Symbols.home), label: 'หน้าหลัก'),
          BottomNavigationBarItem(
            icon: Icon(Symbols.grid_4x4),
            label: 'แสตมป์',
          ),
          BottomNavigationBarItem(icon: Icon(Symbols.trophy), label: 'อันดับ'),
          BottomNavigationBarItem(icon: Icon(Symbols.event), label: 'อีเวนต์'),
          BottomNavigationBarItem(
            icon: Icon(Symbols.account_circle),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
