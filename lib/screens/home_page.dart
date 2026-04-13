import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // 2. ตัวแปรสำหรับ GPS & Maps
  String _currentProvince = "กำลังระบุตำแหน่ง...";
  bool _isLoading = true;
  LatLng _currentLatLng = const LatLng(13.7563, 100.5018); // Default: กทม.
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // --- ฟังก์ชันดึงตำแหน่ง GPS ---
  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLatLng));

      await setLocaleIdentifier("th_TH");
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _currentProvince = placemarks[0].administrativeArea ?? "ไม่พบจังหวัด";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentProvince = "ระบุพิกัดไม่ได้";
        _isLoading = false;
      });
    }
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
              _buildLocationCard(),
              const SizedBox(height: 25),
              _buildRecentStampsSection(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('สวัสดีคุณ P', style: TextStyle(color: Color(0xFF13084C), fontSize: 20, fontWeight: FontWeight.w500, fontFamily: 'Anuphan')),
            Text('สะสมแสตมป์วันนี้กันเถอะ!', style: TextStyle(color: Color(0xFF13084C), fontSize: 14, fontFamily: 'Anuphan')),
          ],
        ),
        const CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://placehold.co/42x43.png')),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.5),
      ),
      child: Column(
        children: [
          // ส่วน Mini Map
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            child: SizedBox(
              height: 150,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15),
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF13084C)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ตำแหน่งปัจจุบัน', style: TextStyle(color: Color(0xFF13084C), fontSize: 14, fontFamily: 'Anuphan')),
                        Text(_currentProvince, style: const TextStyle(color: Color(0x9B13084C), fontSize: 14, fontFamily: 'Anuphan')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      // Logic เช็คอิน
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13084C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isLoading ? 'กำลังโหลด...' : 'เช็คอินที่ $_currentProvince', 
                      style: const TextStyle(color: Colors.white, fontFamily: 'Anuphan')),
                  ),
                ),
              ],
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
        const Text('สะสมล่าสุด', style: TextStyle(color: Color(0xFF13084C), fontSize: 14, fontFamily: 'Anuphan')),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(6, (index) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network('https://placehold.co/65x65.png', width: 65, height: 65, fit: BoxFit.cover),
              ),
            )),
          ),
        ),
      ],
    );
  }

  
}