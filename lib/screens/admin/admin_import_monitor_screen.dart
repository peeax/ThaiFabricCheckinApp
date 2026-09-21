import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';

class AdminImportMonitorScreen extends StatefulWidget {
  const AdminImportMonitorScreen({super.key});

  @override
  State<AdminImportMonitorScreen> createState() =>
      _AdminImportMonitorScreenState();
}

class _AdminImportMonitorScreenState extends State<AdminImportMonitorScreen> {
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _runs = [];
  final Set<String> _updatingSources = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!appState.isAdmin) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ImporterMonitoringService.fetchSources(),
        ImporterMonitoringService.fetchRecentRuns(),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = results[0];
        _runs = results[1];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSource(Map<String, dynamic> source, bool enabled) async {
    final sourceId = source['id']?.toString() ?? '';
    if (sourceId.isEmpty || _updatingSources.contains(sourceId)) return;
    setState(() => _updatingSources.add(sourceId));
    try {
      await ImporterMonitoringService.setSourceEnabled(sourceId, enabled);
      if (!mounted) return;
      setState(() => source['enabled'] = enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะแหล่งข้อมูลได้')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingSources.remove(sourceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.isAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('คุณไม่มีสิทธิ์เข้าถึงหน้านี้')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        title: const Text(
          'สถานะนำเข้าอีเวนต์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _isLoading ? null : _reload,
            icon: const Icon(Symbols.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _runs.isEmpty && _sources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _runs.isEmpty && _sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.cloud_off, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('ไม่สามารถโหลดสถานะตัวนำเข้าได้'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Symbols.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    final latestRun = _runs.isEmpty ? null : _runs.first;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (latestRun != null) _LatestRunSummary(run: latestRun),
          const SizedBox(height: 24),
          const Text(
            'แหล่งข้อมูล',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (_sources.isEmpty)
            const _EmptyPanel(message: 'ยังไม่มีข้อมูลแหล่งนำเข้า')
          else
            ..._sources.map(
              (source) => _SourceTile(
                source: source,
                updating: _updatingSources.contains(source['id']),
                onChanged: (enabled) => _toggleSource(source, enabled),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'ประวัติการทำงาน',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (_runs.isEmpty)
            const _EmptyPanel(message: 'ยังไม่มีประวัติการนำเข้า')
          else
            ..._runs.map((run) => _RunTile(run: run)),
        ],
      ),
    );
  }
}

class _LatestRunSummary extends StatelessWidget {
  const _LatestRunSummary({required this.run});

  final Map<String, dynamic> run;

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? 'unknown';
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(status), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(_formatTimestamp(run['startedAt'])),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Metric(label: 'พบ', value: run['found']),
              _Metric(label: 'สร้าง', value: run['created']),
              _Metric(label: 'อัปเดต', value: run['updated']),
              _Metric(label: 'ปฏิเสธ', value: run['rejected']),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.updating,
    required this.onChanged,
  });

  final Map<String, dynamic> source;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final failures = source['consecutiveFailures'] as num? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(
            failures > 0 ? Symbols.warning : Symbols.database,
            color: failures > 0
                ? Colors.orange.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source['name']?.toString() ?? source['id'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  failures > 0
                      ? 'ล้มเหลวต่อเนื่อง $failures ครั้ง'
                      : 'สำเร็จล่าสุด ${_formatTimestamp(source['lastSuccessAt'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (updating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(value: source['enabled'] != false, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final Map<String, dynamic> run;

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? 'unknown';
    final color = _statusColor(status);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(_statusIcon(status), color: color),
      title: Text('${run['group'] ?? 'all'} · ${_statusLabel(status)}'),
      subtitle: Text(
        '${_formatTimestamp(run['startedAt'])} · พบ ${run['found'] ?? 0} · สร้าง ${run['created'] ?? 0}',
      ),
      trailing: run['dryRun'] == true
          ? const Tooltip(
              message: 'รอบทดสอบ ไม่เขียนฐานข้อมูล',
              child: Icon(Symbols.science, color: Colors.blueGrey),
            )
          : null,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '${value ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w700),
        children: [
          TextSpan(
            text: ' $label',
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _formatTimestamp(dynamic value) {
  if (value is! Timestamp) return 'ยังไม่เคย';
  return DateFormat('dd/MM/yy HH:mm').format(value.toDate().toLocal());
}

Color _statusColor(String status) => switch (status) {
  'success' => Colors.green.shade700,
  'warning' => Colors.orange.shade800,
  'failed' => Colors.red.shade700,
  'running' => Colors.blue.shade700,
  _ => Colors.grey.shade700,
};

IconData _statusIcon(String status) => switch (status) {
  'success' => Symbols.check_circle,
  'warning' => Symbols.warning,
  'failed' => Symbols.error,
  'running' => Symbols.sync,
  _ => Symbols.help,
};

String _statusLabel(String status) => switch (status) {
  'success' => 'ทำงานสำเร็จ',
  'warning' => 'สำเร็จพร้อมคำเตือน',
  'failed' => 'ทำงานล้มเหลว',
  'running' => 'กำลังทำงาน',
  _ => 'ไม่ทราบสถานะ',
};
