import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../widgets/shared_widgets.dart';
import '../shared_places/sub_list_screen.dart';

class StampDetailScreen extends StatelessWidget {
  const StampDetailScreen({super.key, required this.provinceId, required this.provinceData});
  final String provinceId;
  final Map<String, dynamic> provinceData;

  @override
  Widget build(BuildContext context) {
    final coverUrl = provinceData['coverImageUrl'] as String? ?? '';
    final stampUrl = provinceData['stampImageUrl'] as String? ?? '';
    final nameTH = provinceData['nameTH'] as String? ?? provinceId;
    final nameEn = provinceData['nameEn'] as String? ?? '';
    final patternName = provinceData['stampPatternName'] as String? ?? 'ลายแสตมป์';
    final description = provinceData['stampDescription'] as String? ?? 'ไม่มีรายละเอียด';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Symbols.arrow_back_ios_new, size: 24)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProvinceCoverImage(coverUrl: coverUrl, nameTH: nameTH, nameEn: nameEn),
            Transform.translate(
              offset: const Offset(0, -15),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(width: 5, height: 24, decoration: BoxDecoration(color: const Color(0xFFC0AEE0), borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          Text(patternName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: stampUrl.isNotEmpty
                            ? Image.network(stampUrl, height: 180, errorBuilder: (_, __, ___) => const Icon(Symbols.stars, size: 100, color: AppColors.darkPurple))
                            : const Icon(Symbols.stars, size: 100, color: AppColors.darkPurple),
                      ),
                      const SizedBox(height: 20),
                      Text(description, style: const TextStyle(fontSize: 16, height: 1.6)),
                      const SizedBox(height: 30),
                      NavButton(
                        label: 'สถานที่ท่องเที่ยวแนะนำ',
                        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubListScreen(provinceId: provinceId, collectionName: 'attractions', pageTitle: 'สถานที่ท่องเที่ยวแนะนำ'))),
                      ),
                      const SizedBox(height: 12),
                      NavButton(
                        label: 'เยี่ยมชมสินค้า OTOP',
                        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubListScreen(provinceId: provinceId, collectionName: 'otopProducts', pageTitle: 'เยี่ยมชมสินค้า OTOP', otopData: provinceData['otopProducts'] as List?))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}