import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import 'attraction_detail_screen.dart';
import 'product_detail_screen.dart';

class SubListScreen extends StatelessWidget {
  const SubListScreen({super.key, required this.provinceId, required this.collectionName, required this.pageTitle, this.otopData});

  final String provinceId;
  final String collectionName;
  final String pageTitle;
  final List<dynamic>? otopData;

  Future<List<dynamic>> _fetchItems() async {
    if (collectionName == 'otopProducts' && otopData != null) return otopData!;
    if (collectionName == 'attractions') return TatApiService.fetchAttractionsByProvince(provinceId);

    final snapshot = await firestoreDB.collection('provinces').doc(provinceId).collection(collectionName).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Symbols.arrow_back_ios_new, color: AppColors.darkPurple, size: 24)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(width: 5, height: 24, decoration: BoxDecoration(color: const Color(0xFFC0AEE0), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Text(pageTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล', style: TextStyle(color: Colors.grey)));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('ไม่พบข้อมูล'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (_, index) => _PlaceCard(item: snapshot.data![index] as Map<String, dynamic>, collectionName: collectionName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.item, required this.collectionName});
  final Map<String, dynamic> item;
  final String collectionName;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'ไม่มีชื่อสถานที่';
    final description = item['desc'] as String? ?? item['introduction'] as String? ?? item['location']?['address'] as String? ?? 'ไม่มีรายละเอียด';
    final thumbnailList = item['thumbnailUrl'];
    final thumbnailUrl = (thumbnailList is List && thumbnailList.isNotEmpty) ? thumbnailList[0] as String : '';

    return GestureDetector(
      onTap: () {
        if (collectionName == 'otopProducts') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productData: item)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AttractionDetailScreen(placeData: item)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.borderLight)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumbnailUrl.isNotEmpty
                  ? Image.network(thumbnailUrl, width: 65, height: 65, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkPurple), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Symbols.arrow_forward_ios, size: 18, color: Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 65,
      height: 65,
      color: Colors.grey.shade200,
      child: Icon(collectionName == 'otopProducts' ? Symbols.shopping_bag : Symbols.image, color: Colors.grey),
    );
  }
}