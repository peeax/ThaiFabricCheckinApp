import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../widgets/shared_widgets.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventData});
  final Map<String, dynamic> eventData;

  // เพิ่มฟังก์ชันเปิดแผนที่
  Future<void> _openInGoogleMaps(String lat, String lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = eventData['name'] as String? ?? 'ไม่มีชื่องาน';
    final introduction =
        eventData['introduction'] as String? ?? 'ไม่มีรายละเอียด';
    final thumbnailUrl =
        (eventData['thumbnailUrl'] != null &&
            (eventData['thumbnailUrl'] as String).isNotEmpty)
        ? eventData['thumbnailUrl'] as String
        : '';
    final startDateText = _formatEventDate(eventData['startDate'] as String?);
    final endDateText = _formatEventDate(eventData['endDate'] as String?);

    // ประกาศตัวแปร lat, lng เพื่อนำไปใช้เปิดแผนที่
    final lat = eventData['latitude']?.toString() ?? '';
    final lng = eventData['longitude']?.toString() ?? '';
    final hasCoordinates = lat.isNotEmpty && lng.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'รายละเอียดอีเวนต์',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Symbols.arrow_back_ios_new,
            color: AppColors.darkPurple,
            size: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnailUrl.isNotEmpty)
              Image.network(
                thumbnailUrl,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                // แก้ Warning การใช้ _, __, ___
                errorBuilder: (context, error, stackTrace) =>
                    Container(height: 250, color: AppColors.darkPurple),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (startDateText.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Symbols.calendar_today,
                          size: 18,
                          color: AppColors.mediumPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'วันที่: $startDateText - $endDateText',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumPurple,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'รายละเอียดกิจกรรม',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.darkPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    introduction,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkPurple,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (hasCoordinates)
                    AppButton(
                      label: 'เปิดแผนที่ไปร่วมงาน',
                      onTap: () => _openInGoogleMaps(
                        lat,
                        lng,
                      ), // เรียกใช้งานฟังก์ชันที่สร้างไว้ด้านบน
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventDate(String? dateString) {
    if (dateString == null) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString));
    } catch (_) {
      return '';
    }
  }
}
