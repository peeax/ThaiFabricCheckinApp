import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../widgets/shared_widgets.dart';

class StampsView extends StatefulWidget {
  const StampsView({super.key});
  @override
  State<StampsView> createState() => _StampsViewState();
}

class _StampsViewState extends State<StampsView> {
  String _filterMode = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late final StampsManager _stampsManager;

  @override
  void initState() {
    super.initState();
    _stampsManager = StampsManager(uid: firebaseAuth.currentUser?.uid ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stampsManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final data = appState.userData ?? {};
        final stampCount = data['stampCount'] as int? ?? 0;
        final isAdmin = data['isAdmin'] as bool? ?? false;

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 70),
                const Text('คลังแสตมป์', style: TextStyle(color: AppColors.darkPurple, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('สะสมแล้ว $stampCount/${AppStrings.totalProvinces} จังหวัด', style: const TextStyle(color: AppColors.mediumPurple, fontSize: 14)),
                const SizedBox(height: 20),
                _SearchField(
                  controller: _searchController,
                  query: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                const SizedBox(height: 15),
                _FilterDropdown(value: _filterMode, onChanged: (value) => setState(() => _filterMode = value)),
                const SizedBox(height: 20),
                _StampListHeader(stampCount: stampCount),
                const SizedBox(height: 15),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _stampsManager,
                    builder: (context, _) {
                      if (_stampsManager.isLoading) return const Center(child: CircularProgressIndicator());
                      final filteredProvinces = _applyFilters(_stampsManager, isAdmin);
                      if (filteredProvinces.isEmpty) return const Center(child: Text('ไม่พบจังหวัดที่ตรงกัน', style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: filteredProvinces.length,
                        itemBuilder: (_, index) {
                          final province = filteredProvinces[index];
                          final provinceId = province['id'] as String;
                          final isUnlocked = _stampsManager.unlockedProvinceIds.contains(provinceId) || isAdmin;
                          return StampCard(provinceId: provinceId, provinceData: province, isUnlocked: isUnlocked);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilters(StampsManager manager, bool isAdmin) {
    return manager.allProvinces.where((province) {
      final name = province['nameTH'] as String? ?? province['id'] as String;
      final provinceId = province['id'] as String;
      final isUnlocked = manager.unlockedProvinceIds.contains(provinceId) || isAdmin;

      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) return false;
      if (_filterMode == 'collected' && !isUnlocked) return false;
      if (_filterMode == 'not_collected' && isUnlocked) return false;
      return true;
    }).toList();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.query, required this.onChanged, required this.onClear});
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(15), color: AppColors.lightBackground),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          const Icon(Symbols.search, color: Colors.grey, size: 22),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: controller, onChanged: onChanged, style: const TextStyle(color: AppColors.darkPurple, fontSize: 14), decoration: const InputDecoration(hintText: 'ค้นหาชื่อจังหวัด...', hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none))),
          if (query.isNotEmpty) GestureDetector(onTap: onClear, child: const Icon(Symbols.close, color: Colors.grey, size: 20)),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  static const Map<String, String> _filterLabels = {'all': 'ทุกจังหวัด', 'collected': 'จังหวัดที่สะสมแล้ว', 'not_collected': 'ยังไม่ได้สะสม'};

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => _filterLabels.entries.map((entry) => PopupMenuItem<String>(value: entry.key, child: Text(entry.value))).toList(),
      child: Container(
        width: double.infinity,
        height: 45,
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_filterLabels[value] ?? 'ทุกจังหวัด', style: const TextStyle(color: AppColors.darkPurple)),
            const Icon(Symbols.keyboard_arrow_down, color: AppColors.darkPurple),
          ],
        ),
      ),
    );
  }
}

class _StampListHeader extends StatelessWidget {
  const _StampListHeader({required this.stampCount});
  final int stampCount;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ทั้งหมด', style: TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold)),
            Text('$stampCount/${AppStrings.totalProvinces}', style: const TextStyle(color: AppColors.darkPurple)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(width: double.infinity, height: 1, color: Colors.grey.shade300),
            Container(width: 55, height: 3, decoration: BoxDecoration(color: AppColors.darkPurple, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ],
    );
  }
}