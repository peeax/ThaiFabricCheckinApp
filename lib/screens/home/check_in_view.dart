import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
import '../stamps/stamp_detail_screen.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({super.key, required this.onChangeTab});
  final ValueChanged<int> onChangeTab;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(13.7563, 100.5018);
  String _detectedProvince = 'กำลังระบุตำแหน่ง...';
  bool _isCheckingIn = false;
  bool _hasLocationPermission = false;
  Key _mapKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _detectedProvince = 'กรุณาเปิด GPS ในเครื่อง');
        return;
      }
      var permission = await Geolocator.checkPermission();
      bool isFirstTimeGrant = false;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        isFirstTimeGrant = true;
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _detectedProvince = 'ไม่อนุญาตการเข้าถึงตำแหน่ง');
        return;
      }
      if (mounted) {
        setState(() {
          _hasLocationPermission = true;
          if (isFirstTimeGrant) _mapKey = UniqueKey();
        });
      }
      if (!mounted) return;
      await _loadCurrentLocation();
    } catch (e) {
      if (mounted) setState(() => _detectedProvince = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _loadCurrentLocation() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (!mounted) return;
      try {
        final position = await LocationService.getCurrentPosition();
        if (!mounted) return;
        final province = await LocationService.getProvinceNameFromCoordinates(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _detectedProvince = province;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
        }
        return;
      } catch (e) {
        AppLog.debug('_loadCurrentLocation attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          if (!mounted) return;
        } else {
          if (mounted) setState(() => _detectedProvince = e.toString().replaceFirst('Exception: ', 'ไม่สามารถระบุตำแหน่งได้'));
        }
      }
    }
  }

  Future<void> _performCheckIn() async {
    final uid = firebaseAuth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => _isCheckingIn = true);
    try {
      final provinceData = await CheckInService.checkIn(uid: uid, provinceName: _detectedProvince);
      if (mounted) _showCheckInSuccessDialog(_detectedProvince, provinceData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.mediumPurple));
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  void _showCheckInSuccessDialog(String provinceId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.celebration, color: AppColors.darkPurple, size: 40),
              const SizedBox(height: 15),
              const Text('เช็คอินสำเร็จ!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
              const Text('คุณได้รับแสตมป์ประจำจังหวัด', style: TextStyle(fontSize: 14, color: AppColors.darkPurple)),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(data['stampImageUrl'] as String? ?? '', width: 180, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Symbols.grid_4x4, size: 100, color: AppColors.darkPurple)),
              ),
              const SizedBox(height: 15),
              Text(data['nameTH'] as String? ?? provinceId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
              Text(data['stampPatternName'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.darkPurple)),
              const SizedBox(height: 25),
              AppButton(
                label: 'ดูรายละเอียด',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StampDetailScreen(provinceId: provinceId, provinceData: data)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final data = appState.userData ?? {};
        final stampCount = data['stampCount'] as int? ?? 0;
        final username = data['username'] as String? ?? '';
        final dayName = _thaiDayName(DateTime.now().weekday);
        final uid = firebaseAuth.currentUser?.uid ?? '';

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 70),
                _CheckInHeader(dayName: dayName, username: username, onProfileTap: () => widget.onChangeTab(4)),
                const SizedBox(height: 25),
                _StampProgressCard(stampCount: stampCount),
                const SizedBox(height: 25),
                _MapCheckInCard(
                  key: _mapKey,
                  position: _currentPosition,
                  provinceName: _detectedProvince,
                  isCheckingIn: _isCheckingIn,
                  hasPermission: _hasLocationPermission,
                  onMapCreated: (controller) => _mapController = controller,
                  onCheckIn: _performCheckIn,
                ),
                const SizedBox(height: 25),
                _RecentStampsSection(uid: uid, onViewAll: () => widget.onChangeTab(1)),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  String _thaiDayName(int weekday) => const ['', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'][weekday];
}

class _CheckInHeader extends StatelessWidget {
  const _CheckInHeader({required this.dayName, required this.username, required this.onProfileTap});
  final String dayName;
  final String username;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สวัสดี${dayName}คุณ $username', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
            const Text('สะสมแสตมป์วันนี้กันเถอะ!', style: TextStyle(fontSize: 14, color: AppColors.darkPurple)),
          ],
        ),
        GestureDetector(onTap: onProfileTap, child: const CircleAvatar(radius: 25, backgroundImage: AssetImage('assets/images/default_profile.png'), backgroundColor: Colors.transparent)),
      ],
    );
  }
}

class _StampProgressCard extends StatelessWidget {
  const _StampProgressCard({required this.stampCount});
  final int stampCount;
  @override
  Widget build(BuildContext context) {
    final progress = (stampCount / AppStrings.totalProvinces).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: AppColors.darkPurple, borderRadius: BorderRadius.circular(35)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ไปมาแล้ว', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('$stampCount / ${AppStrings.totalProvinces}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _MapCheckInCard extends StatelessWidget {
  const _MapCheckInCard({super.key, required this.position, required this.provinceName, required this.isCheckingIn, required this.onMapCreated, required this.onCheckIn, this.hasPermission = false});
  final LatLng position;
  final String provinceName;
  final bool isCheckingIn;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onCheckIn;
  final bool hasPermission;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), child: GoogleMap(initialCameraPosition: CameraPosition(target: position, zoom: 14), onMapCreated: onMapCreated, myLocationEnabled: true, zoomControlsEnabled: false))),
          Padding(padding: const EdgeInsets.all(15), child: AppButton(label: 'เช็คอินที่ $provinceName', isLoading: isCheckingIn, onTap: onCheckIn)),
        ],
      ),
    );
  }
}

class _RecentStampsSection extends StatelessWidget {
  const _RecentStampsSection({required this.uid, required this.onViewAll});
  final String uid;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('สะสมล่าสุด', style: TextStyle(fontSize: 14, color: AppColors.darkPurple)),
            TextButton(onPressed: onViewAll, child: const Text('ดูทั้งหมด', style: TextStyle(fontSize: 14, color: AppColors.darkPurple))),
          ],
        ),
        SizedBox(
          height: 80,
          child: StreamBuilder<QuerySnapshot>(
            stream: firestoreDB.collection('users').doc(uid).collection('checkins').orderBy('at', descending: true).limit(5).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('ยังไม่มีแสตมป์', style: TextStyle(color: Colors.grey)));
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (_, index) {
                  final doc = snapshot.data!.docs[index];
                  final provinceData = doc.data() as Map<String, dynamic>;
                  final provinceId = doc.id;
                  final stampImageUrl = provinceData['stampImageUrl'] as String? ?? '';
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StampDetailScreen(provinceId: provinceId, provinceData: provinceData))),
                    child: _RecentStampThumbnail(imageUrl: stampImageUrl),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentStampThumbnail extends StatelessWidget {
  const _RecentStampThumbnail({required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 80,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.grey.shade200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Symbols.image, color: Colors.grey)) : const Icon(Symbols.image, color: Colors.grey),
      ),
    );
  }
}