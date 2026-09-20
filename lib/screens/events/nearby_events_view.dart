import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
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
  bool _isLoadingEvents = false;
  bool _isLoadingMore = false;
  bool _hasMoreEvents = true;
  String? _eventsError;
  DocumentSnapshot<Map<String, dynamic>>? _lastEventDocument;
  final List<Map<String, dynamic>> _events = [];

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
        await _reloadEvents();
      }
    } catch (_) {
      // Error Handling หากเกิดข้อผิดพลาดใดๆ (ไม่ได้เปิด GPS, ไม่ให้สิทธิ์)
      // ระบบจะไม่พัง แต่จะดึงข้อมูลของ "กรุงเทพมหานคร" มาแสดงแทน
      if (mounted) {
        setState(() {
          _currentProvince = _fallbackProvince;
          _isLoadingLocation = false;
        });
        await _reloadEvents();
      }
    }
  }

  Future<void> _reloadEvents() async {
    if (_currentProvince.isEmpty) return;
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
      _hasMoreEvents = true;
      _lastEventDocument = null;
      _events.clear();
    });
    await _loadMoreEvents();
    if (mounted) setState(() => _isLoadingEvents = false);
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMoreEvents || _currentProvince.isEmpty) return;
    setState(() {
      _isLoadingMore = true;
      _eventsError = null;
    });

    try {
      final page = await EventService.fetchPublishedEventsByProvincePage(
        provinceName: _currentProvince,
        startAfter: _lastEventDocument,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page.events);
        _lastEventDocument = page.lastDocument;
        _hasMoreEvents = page.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _eventsError = 'load-failed');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
                  : _buildEventsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_isLoadingEvents && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eventsError != null && _events.isEmpty) {
      return _buildEventsErrorState();
    }
    if (_events.isEmpty) {
      return _buildEmptyEventsState(_currentProvince);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      itemCount: _events.length + 1,
      itemBuilder: (context, index) {
        if (index == _events.length) {
          if (_hasMoreEvents) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMoreEvents();
            });
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 18);
        }
        return _EventCard(event: _events[index]);
      },
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

  Widget _buildEventsErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.cloud_off, size: 50, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'ยังโหลดข้อมูลอีเวนต์ไม่ได้ กรุณาลองใหม่อีกครั้งภายหลัง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
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
              AppCachedNetworkImage(
                imageUrl: thumbnailUrl,
                height: 150,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
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
