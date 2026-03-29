import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentProvince = "กำลังระบุตำแหน่ง...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoading = true);

    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. ตรวจสอบว่าเปิด GPS หรือไม่
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus("กรุณาเปิด GPS");
        return;
      }

      // 2. ตรวจสอบสิทธิ์
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateStatus("สิทธิ์ถูกปฏิเสธ");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateStatus("กรุณาเปิดสิทธิ์ในตั้งค่า");
        return;
      }

      // 3. ดึงพิกัด
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // ตั้งค่าความแม่นยำที่นี่
        ),
      );

      // 4. แปลงพิกัดเป็นจังหวัด (แก้ไข Error localeIdentifier)
      // ตั้งค่าภาษาไทยแยกออกมาก่อนเรียกใช้ฟังก์ชัน
      await setLocaleIdentifier("th_TH");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // ใช้ administrativeArea สำหรับจังหวัด
          _currentProvince = place.administrativeArea ?? "ไม่พบชื่อจังหวัด";
          _isLoading = false;
        });
      }
    } catch (e) {
      _updateStatus("ระบุพิกัดไม่ได้");
      debugPrint("Error: $e");
    }
  }

  void _updateStatus(String msg) {
    setState(() {
      _currentProvince = msg;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

  // --- UI Methods ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'สวัสดีคุณ P',
              style: TextStyle(
                color: Color(0xFF13084C),
                fontSize: 20,
                fontWeight: FontWeight.w500,
                fontFamily: 'Anuphan',
              ),
            ),
            Text(
              'สะสมแสตมป์วันนี้กันเถอะ!',
              style: TextStyle(
                color: Color(0xFF13084C),
                fontSize: 14,
                fontFamily: 'Anuphan',
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 20,
          // เพิ่ม .png เพื่อแก้ ImageCodecException
          backgroundImage: NetworkImage('https://placehold.co/42x43.png'),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13084C),
        borderRadius: BorderRadius.circular(31),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'ไปมาแล้ว',
                style: TextStyle(color: Colors.white, fontFamily: 'Anuphan'),
              ),
              Text(
                '9/77',
                style: TextStyle(color: Colors.white, fontFamily: 'Anuphan'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 9 / 77,
              backgroundColor: const Color(0x7F7065A7),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF13084C)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ตำแหน่งปัจจุบัน',
                    style: TextStyle(
                      color: Color(0xFF13084C),
                      fontSize: 14,
                      fontFamily: 'Anuphan',
                    ),
                  ),
                  Text(
                    _currentProvince,
                    style: const TextStyle(
                      color: Color(0x9B13084C),
                      fontSize: 14,
                      fontFamily: 'Anuphan',
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
              onPressed: _isLoading
                  ? null
                  : () {
                      // ตัวอย่าง: กดแล้วไปหน้า StampBook
                      Navigator.pushNamed(context, '/StampBook');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13084C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                _isLoading
                    ? 'กำลังค้นหาตำแหน่ง...'
                    : 'เช็คอินที่ $_currentProvince',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Anuphan',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStampsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สะสมล่าสุด',
          style: TextStyle(color: Color(0xFF13084C), fontFamily: 'Anuphan'),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              6,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  // เพิ่ม .png เพื่อแก้ ImageCodecException
                  child: Image.network(
                    'https://placehold.co/65x65.png',
                    width: 65,
                    height: 65,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF13084C),
      unselectedItemColor: const Color(0xFFD9D9D9),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(icon: Icon(Symbols.home), label: ''),
        BottomNavigationBarItem(icon: Icon(Symbols.grid_4x4), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
      ],
    );
  }
}
