import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../widgets/shared_widgets.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productData});
  final Map<String, dynamic> productData;

  @override
  Widget build(BuildContext context) {
    // firebase
    final name = productData['name'] as String? ?? 'สินค้า OTOP';
    final desc = productData['desc'] as String? ?? 'ไม่มีรายละเอียดสินค้า';
    final location =
        productData['location'] as String? ?? 'ไม่ระบุสถานที่จำหน่าย';
    final link = productData['link'] as String? ?? '';
    final imageUrl = productData['imageUrl'] as String? ?? '';
    final tel = productData['Tel'] as String? ?? '-';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Symbols.arrow_back_ios_new, size: 24),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 350,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(height: 350, color: AppColors.darkPurple),
                      )
                    : Container(
                        height: 350,
                        width: double.infinity,
                        color: AppColors.darkPurple,
                        child: const Center(
                          child: Icon(
                            Symbols.shopping_bag,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                      ),
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
                          fontSize: 22,
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
                              location,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 2,
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
                    'รายละเอียดสินค้า',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'สถานที่จำหน่าย',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    location,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'เบอร์ติดต่อ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tel,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  //ถ้ามีลิ้งให้แสดงปุ่ม
                  if (link.isNotEmpty && link.startsWith('http'))
                    AppButton(
                      label: 'ไปยังหน้าร้านค้าออนไลน์',
                      onTap: () async {
                        final uri = Uri.parse(link);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
