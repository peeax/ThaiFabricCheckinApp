import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

/// แสดงรายละเอียดสถานที่ท่องเที่ยว
class AttractionDetailScreen extends StatelessWidget {
  const AttractionDetailScreen({super.key, required this.placeData});
  final Map<String, dynamic> placeData;

  /// ไปให้ Google Maps ดูพิกัด lati longti
  Future<void> _openInGoogleMaps(String lat, String lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ดึงข้อมูลจาก Map จาก Api ใช้เครื่องหมาย `?` เพื่อป้องกัน Null Pointer Exception
    // และใช้ `??` (Null-coalescing) เพื่อกำหนดค่าเริ่มต้น (Fallback value) เสมอ หากข้อมูลจาก API ขาดหาย
    final lat = placeData['latitude']?.toString() ?? '';
    final lng = placeData['longitude']?.toString() ?? '';
    final name = placeData['name'] as String? ?? 'สถานที่ท่องเที่ยว';
    final introduction =
        placeData['introduction'] as String? ??
        'ไม่มีข้อมูลรายละเอียดเพิ่มเติมสำหรับสถานที่นี้';

    // รูปภาพจาก TAT API มักมาเป็น Array (List) จึงต้องตรวจสอบ Type ก่อน
    // เพื่อป้องกันแอปแครชกรณีที่ API ส่งข้อมูลกลับมาผิดรูปแบบ
    final thumbnailUrl =
        (placeData['thumbnailUrl'] is List &&
            (placeData['thumbnailUrl'] as List).isNotEmpty)
        ? placeData['thumbnailUrl'][0] as String
        : '';
    final address = placeData['location']?['address'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      // UI สวย ๆ
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ใช้ Stack เพื่อซ้อน Widget ทับกัน (รูปภาพ -> ไล่สี Gradient -> ข้อความ)
            Stack(
              children: [
                thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        height: 350,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        //หากโหลดรูปไม่ขึ้น (เช่น เน็ตหลุด หรือลิงก์เสีย) ให้แสดงสีทึบ
                        errorBuilder: (_, __, ___) =>
                            Container(height: 350, color: AppColors.darkPurple),
                      )
                    : Container(height: 350, color: AppColors.darkPurple),
                Container(
                  height: 350,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black26,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Symbols.location_on,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 2, // จำกัดจำนวนบรรทัด
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายละเอียด',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    introduction,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // ปุ่มเปิดแผนที่จะทำงานได้ (Enabled) ก็ต่อเมื่อมีข้อมูล Lat/Lng เท่านั้น
                  // หากไม่มีพิกัด ปุ่มจะกลายเป็นสีเทาอัตโนมัติ ป้องกันไม่ให้ผู้ใช้กดแล้วไม่เกิดอะไรขึ้น
                  ElevatedButton.icon(
                    onPressed: (lat.isNotEmpty && lng.isNotEmpty)
                        ? () => _openInGoogleMaps(lat, lng)
                        : null,
                    icon: const Icon(Symbols.map),
                    label: const Text(
                      'ดูแผนที่การเดินทาง',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: AppColors.darkPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
