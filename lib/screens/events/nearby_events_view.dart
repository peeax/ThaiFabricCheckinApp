import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import 'event_detail_screen.dart';

class NearbyEventsView extends StatefulWidget {
  const NearbyEventsView({super.key});

  @override
  State<NearbyEventsView> createState() => _NearbyEventsViewState();
}

class _NearbyEventsViewState extends State<NearbyEventsView>
    with WidgetsBindingObserver {
  // Fallback State: จังหวัดเริ่มต้นในกรณีที่ผู้ใช้ไม่อนุญาตให้เข้าถึง GPS หรือระบบหาพิกัดไม่สำเร็จ
  static const String _fallbackProvince = 'กรุงเทพมหานคร';

  String _currentProvince = '';
  bool _isLoadingLocation = true; // State สำหรับจัดการ UX ระหว่างรอค้นหาพิกัด

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentProvince(); // เริ่มต้นค้นหาตำแหน่งทันทีที่โหลดหน้าจอนี้
  }

  @override
  void dispose() {
    // Memory Management ถอด Observer ออกทุกครั้งเมื่อปิดหน้าจอ เพื่อคืนหน่วยความจำและป้องกัน Memory Leak
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // หากผู้ใช้สลับหน้าจอไปเปิด GPS ใน Setting แล้วกลับมาที่แอป (AppLifecycleState.resumed)
    // ระบบจะสั่งรีเฟรชเพื่อดึงพิกัดใหม่ให้อัตโนมัติ (Reactive Location Fetching)
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _isLoadingLocation = true);
      _loadCurrentProvince();
    }
  }

  /// ฟังก์ชันค้นหาและระบุจังหวัดปัจจุบันของผู้ใช้งาน
  Future<void> _loadCurrentProvince() async {
    try {
      // ตรวจสอบว่าเปิด GPS ที่ตัวเครื่องแล้วหรือยัง
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS disabled');

      // ตรวจสอบสิทธิ์การเข้าถึงตำแหน่ง
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      //หากผู้ใช้ปฏิเสธสิทธิ์ ให้โยน Exception เพื่อสลับไปใช้ค่า _fallbackProvince
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permission denied');
      }

      //ป้องกันแอปแครช
      if (!mounted) return;
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;

      // แปลงพิกัด (Reverse Geocoding) เป็นชื่อจังหวัด
      final province = await LocationService.getProvinceNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentProvince = province;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      // Error Handling หากเกิดข้อผิดพลาดใดๆ (ไม่ได้เปิด GPS, ไม่ให้สิทธิ์)
      // ระบบจะไม่พัง แต่จะดึงข้อมูลของ "กรุงเทพมหานคร" มาแสดงแทน
      if (mounted) {
        setState(() {
          _currentProvince = _fallbackProvince;
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// คัดกรองเฉพาะอีเวนต์ที่ กำลังจัด หรือ ยังไม่หมดเวลา
  List<dynamic> _filterActiveEvents(List<dynamic> events) {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return events.where((event) {
      final endDateStr = event['endDate'] as String?;
      if (endDateStr == null) return true;

      try {
        final endDate = DateTime.parse(endDateStr).toLocal();
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return !endDateOnly.isBefore(todayDateOnly);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  /// Data Filtering คัดกรองเฉพาะอีเวนต์ที่ ผ่านมาแล้ว
  List<dynamic> _filterPastEvents(List<dynamic> events) {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return events.where((event) {
      final endDateStr = event['endDate'] as String?;
      if (endDateStr == null) return false;

      try {
        final endDate = DateTime.parse(endDateStr).toLocal();
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return endDateOnly.isBefore(todayDateOnly);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'อีเวนต์ที่น่าสนใจช่วงนี้',
                    style: TextStyle(
                      color: AppColors.darkPurple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoadingLocation
                        ? 'กำลังค้นหาพิกัด...'
                        : 'กำลังจัดขึ้นใกล้คุณ (จังหวัด$_currentProvince)',
                    style: const TextStyle(
                      color: AppColors.mediumPurple,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingLocation
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<dynamic>>(
                      future: TatApiService.fetchEventsByProvince(
                        _currentProvince,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _buildEmptyEventsState(_currentProvince);
                        }

                        final allEvents = snapshot.data!;
                        final activeEvents = _filterActiveEvents(allEvents);
                        final pastEvents = _filterPastEvents(allEvents);

                        if (activeEvents.isEmpty && pastEvents.isEmpty) {
                          return _buildEmptyEventsState(_currentProvince);
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          children: [
                            if (activeEvents.isEmpty)
                              _buildEmptyEventsState(_currentProvince)
                            else
                              ...activeEvents.map(
                                (event) => _EventCard(
                                  event: event as Map<String, dynamic>,
                                ),
                              ),

                            if (pastEvents.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 25, bottom: 15),
                                child: Text(
                                  'อีเวนต์ที่ผ่านมา',
                                  style: TextStyle(
                                    color: AppColors.darkPurple,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...pastEvents.map(
                                (event) => Opacity(
                                  opacity: 0.6,
                                  child: _EventCard(
                                    event: event as Map<String, dynamic>,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEventsState(String province) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.event_busy, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            'ไม่มีอีเวนต์จัดขึ้นใน จังหวัด$province ช่วงนี้',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final name = event['name'] as String? ?? 'ไม่มีชื่องาน';
    final introduction = event['introduction'] as String? ?? 'ไม่มีรายละเอียด';
    final thumbnailUrl = event['thumbnailUrl'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(eventData: event),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                // ใช้ Image.network จัดการโหลดรูปภาพจากอินเทอร์เน็ต พร้อมดักจับ Error
                child: Image.network(
                  thumbnailUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 150, color: AppColors.darkPurple),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkPurple,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    introduction,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
