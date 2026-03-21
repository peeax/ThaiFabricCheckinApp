import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 70),
              _buildHeader(),
              const SizedBox(height: 15),
              _buildProgressCard(),
              const SizedBox(height: 15),
              _buildLocationCard(),
              const SizedBox(height: 25),
              _buildRecentStampsSection(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'สวัสดีคุณ P',
              style: TextStyle(
                color: Color(0xFF13084C),
                fontSize: 20,
                fontFamily: 'Anuphan',
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'สะสมแสตมป์วันนี้กันเถอะ!',
              style: TextStyle(
                color: Color(0xFF13084C),
                fontSize: 14,
                fontFamily: 'Anuphan',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage('https://placehold.co/42x43'),
        ),
      ],
    );
  }

  // ─── Progress Card ────────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    const int current = 9;
    const int total = 77;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13084C),
        borderRadius: BorderRadius.circular(31),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'ไปมาแล้ว',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Anuphan',
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                '$current/$total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Anuphan',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 6,
              backgroundColor: const Color(0x7F7065A7),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location Card ────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, size: 16, color: Color(0xFF13084C)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ตำแหน่งปัจจุบัน',
                    style: TextStyle(
                      color: Color(0xFF13084C),
                      fontSize: 14,
                      fontFamily: 'Anuphan',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    'เชียงใหม่',
                    style: TextStyle(
                      color: Color(0x9B13084C),
                      fontSize: 14,
                      fontFamily: 'Anuphan',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13084C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'เช็คอินที่ เชียงใหม่',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Anuphan',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recent Stamps Section ────────────────────────────────────────────────

  Widget _buildRecentStampsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'สะสมล่าสุด',
              style: TextStyle(
                color: Color(0xFF13084C),
                fontSize: 14,
                fontFamily: 'Anuphan',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'ดูทั้งหมด',
                style: TextStyle(
                  color: Color(0xFF13084C),
                  fontSize: 14,
                  fontFamily: 'Anuphan',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 16,
            children: List.generate(6, (index) => _buildStampItem()),
          ),
        ),
      ],
    );
  }

  Widget _buildStampItem() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.network(
        'https://placehold.co/65x65',
        width: 65,
        height: 65,
        fit: BoxFit.cover,
      ),
    );
  }

  // ─── Bottom Navigation Bar ────────────────────────────────────────────────

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF13084C),
      unselectedItemColor: const Color(0xFFD9D9D9),
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Symbols.home), label: ''),
        BottomNavigationBarItem(icon: Icon(Symbols.grid_4x4), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
      ],
    );
  }
}