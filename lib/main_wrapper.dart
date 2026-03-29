import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'pages/home_page.dart';
import 'pages/stamp_book.dart';
import 'pages/top_reward.dart';
import 'pages/account_info.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  // ลิสต์ของหน้าที่จะแสดง
  final List<Widget> _pages = [
    const HomePage(),
    const StampBook(), 
    const TopReward(),
    const Accountinfo(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages, // เก็บ State ของทุกหน้าไว้ ไม่ให้โหลดใหม่
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF13084C),
        unselectedItemColor: const Color(0xFFD9D9D9),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Symbols.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Symbols.grid_4x4), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}