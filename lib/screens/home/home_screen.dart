import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import 'check_in_view.dart';
import '../stamps/stamps_view.dart';
import '../leaderboard/leaderboard_view.dart';
import '../events/nearby_events_view.dart';
import '../profile/profile_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CheckInView(onChangeTab: (index) => setState(() => _selectedTabIndex = index)),
      const StampsView(),
      const LeaderboardView(),
      const NearbyEventsView(),
      const ProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedTabIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.darkPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Symbols.home), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Symbols.grid_4x4), label: 'แสตมป์'),
          BottomNavigationBarItem(icon: Icon(Symbols.trophy), label: 'อันดับ'),
          BottomNavigationBarItem(icon: Icon(Symbols.event), label: 'อีเวนต์'),
          BottomNavigationBarItem(icon: Icon(Symbols.account_circle), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}