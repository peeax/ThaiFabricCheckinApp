import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
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
  final List<Map<String, dynamic>> _events = [];
  List<String> _provinces = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  bool get _isAdmin => appState.isAdmin;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final provinces = await AdminService.loadProvinceNames();
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (_) {
      if (mounted) setState(() => _provinces = []);
    }
    await _reloadEvents();
  }

  Future<void> _reloadEvents() async {
    if (!_isAdmin) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _hasMore = true;
      _lastDocument = null;
      _events.clear();
    });
    await _loadMoreEvents();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadError = null;
    });

    try {
      final page = await EventService.fetchAdminEventsPage(
        status: _status,
        province: _province,
        startAfter: _lastDocument,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page.events);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'load-failed');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

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
        child: Column(
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
                        ButtonSegment(value: 'draft', label: Text('ฉบับร่าง')),
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
                      onSelectionChanged: (selection) {
                        setState(() => _status = selection.first);
                        _reloadEvents();
                      },
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
                      ..._provinces.map(
                        (province) => DropdownMenuItem<String?>(
                          value: province,
                          child: Text(province),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _province = value);
                      _reloadEvents();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList() {
    if (_isLoading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _events.isEmpty) {
      return _MessageState(
        icon: Symbols.cloud_off,
        message: 'โหลดรายการอีเวนต์ไม่สำเร็จ',
      );
    }

    final visibleEvents = _events.where(_matchesKeyword).toList();
    if (visibleEvents.isEmpty) {
      return _MessageState(
        icon: Symbols.event_busy,
        message: 'ยังไม่มีอีเวนต์ในหน้านี้',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 90),
      itemCount: visibleEvents.length + 1,
      itemBuilder: (context, index) {
        if (index == visibleEvents.length) {
          if (!_hasMore) return const SizedBox(height: 8);
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 18),
            child: OutlinedButton(
              onPressed: _isLoadingMore ? null : _loadMoreEvents,
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('โหลดเพิ่ม'),
            ),
          );
        }
        final event = visibleEvents[index];
        return _AdminEventRow(
          event: event,
          onPreview: () => _openPreview(event),
          onEdit: () => _openForm(event),
          onStatusChanged: (status) => _changeStatus(event, status),
        );
      },
    );
  }

  bool _matchesKeyword(Map<String, dynamic> event) {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return true;
    return (event['name']?.toString().toLowerCase() ?? '').contains(keyword) ||
        (event['locationName']?.toString().toLowerCase() ?? '').contains(
          keyword,
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
    await _reloadEvents();
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
      await _reloadEvents();
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
                  : AppCachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 65,
                      width: 65,
                      borderRadius: BorderRadius.circular(12),
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
