import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../events/event_detail_screen.dart';
import 'event_form_screen.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  String _status = 'draft';
  String _query = '';
  String? _province;

  bool get _isAdmin => appState.userData?['isAdmin'] == true;

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('คุณไม่มีสิทธิ์เข้าถึงหน้านี้')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.darkPurple,
        title: const Text(
          'จัดการอีเวนต์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มอีเวนต์',
        backgroundColor: AppColors.darkPurple,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        child: const Icon(Symbols.add),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: EventService.watchAdminEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Symbols.cloud_off,
                message: 'โหลดรายการอีเวนต์ไม่สำเร็จ',
              );
            }

            final allEvents = snapshot.data ?? [];
            final provinces =
                allEvents
                    .map((event) => event['province']?.toString() ?? '')
                    .where((province) => province.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final events = allEvents.where((event) {
              final matchesStatus = event['status'] == _status;
              final matchesProvince =
                  _province == null || event['province'] == _province;
              final keyword = _query.trim().toLowerCase();
              final matchesQuery =
                  keyword.isEmpty ||
                  (event['name']?.toString().toLowerCase() ?? '').contains(
                    keyword,
                  ) ||
                  (event['locationName']?.toString().toLowerCase() ?? '')
                      .contains(keyword);
              return matchesStatus && matchesProvince && matchesQuery;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 12, 25, 8),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'draft',
                              label: Text('ฉบับร่าง'),
                            ),
                            ButtonSegment(
                              value: 'published',
                              label: Text('เผยแพร่'),
                            ),
                            ButtonSegment(
                              value: 'archived',
                              label: Text('เก็บถาวร'),
                            ),
                          ],
                          selected: {_status},
                          onSelectionChanged: (selection) =>
                              setState(() => _status = selection.first),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: _inputDecoration(
                          hint: 'ค้นหาชื่องานหรือสถานที่',
                          icon: Symbols.search,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _province,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          hint: 'ทุกจังหวัด',
                          icon: Symbols.location_on,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('ทุกจังหวัด'),
                          ),
                          ...provinces.map(
                            (province) => DropdownMenuItem<String?>(
                              value: province,
                              child: Text(province),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _province = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: events.isEmpty
                      ? _MessageState(
                          icon: Symbols.event_busy,
                          message: 'ยังไม่มีอีเวนต์ในสถานะนี้',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(25, 10, 25, 90),
                          itemCount: events.length,
                          itemBuilder: (context, index) => _AdminEventRow(
                            event: events[index],
                            onPreview: () => _openPreview(events[index]),
                            onEdit: () => _openForm(events[index]),
                            onStatusChanged: (status) =>
                                _changeStatus(events[index], status),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.darkPurple),
      ),
    );
  }

  Future<void> _openForm([Map<String, dynamic>? event]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: event)),
    );
  }

  void _openPreview(Map<String, dynamic> event) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventData: event)),
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> event, String status) async {
    if (status == 'archived') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เก็บอีเวนต์นี้ถาวร?'),
          content: const Text('อีเวนต์จะไม่แสดงต่อผู้ใช้ แต่ข้อมูลจะยังอยู่'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('เก็บถาวร'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await EventService.updateEventStatus(event['id'] as String, status);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตสถานะเรียบร้อยแล้ว')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตสถานะไม่สำเร็จ')));
    }
  }
}

class _AdminEventRow extends StatelessWidget {
  const _AdminEventRow({
    required this.event,
    required this.onPreview,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> event;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event['thumbnailUrl']?.toString() ?? '';
    final status = event['status']?.toString() ?? 'draft';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 65,
              height: 65,
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: AppColors.darkPurple,
                      child: Icon(Symbols.event, color: Colors.white),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.darkPurple,
                        child: Icon(Symbols.broken_image, color: Colors.white),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPreview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name']?.toString() ?? 'ไม่มีชื่องาน',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event['province'] ?? '-'} • ${_formatDate(event['startDate'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mediumPurple,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'จัดการอีเวนต์',
            onSelected: (value) {
              if (value == 'preview') return onPreview();
              if (value == 'edit') return onEdit();
              onStatusChanged(value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'preview', child: Text('ดูตัวอย่าง')),
              if (status != 'archived')
                const PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
              if (status == 'draft')
                const PopupMenuItem(value: 'published', child: Text('เผยแพร่')),
              if (status == 'published')
                const PopupMenuItem(
                  value: 'draft',
                  child: Text('ยกเลิกเผยแพร่'),
                ),
              if (status != 'archived')
                const PopupMenuItem(value: 'archived', child: Text('เก็บถาวร')),
              if (status == 'archived')
                const PopupMenuItem(
                  value: 'draft',
                  child: Text('คืนเป็นฉบับร่าง'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? 'ไม่ระบุวันที่'
        : DateFormat('dd/MM/yyyy').format(date);
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
