import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
import '../events/event_detail_screen.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final Map<String, dynamic>? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _sourceNameController;
  late final TextEditingController _sourceUrlController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  List<String> _provinces = [];
  String? _province;
  DateTime? _startDate;
  DateTime? _endDate;
  late String _status;
  late String _previousStatus;
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event ?? {};
    _titleController = TextEditingController(text: event['name']?.toString());
    _descriptionController = TextEditingController(
      text: event['introduction']?.toString(),
    );
    _locationController = TextEditingController(
      text: event['locationName']?.toString(),
    );
    _imageUrlController = TextEditingController(
      text: event['thumbnailUrl']?.toString(),
    );
    _sourceNameController = TextEditingController(
      text: event['sourceName']?.toString(),
    );
    _sourceUrlController = TextEditingController(
      text: event['sourceUrl']?.toString(),
    );
    _latitudeController = TextEditingController(
      text: event['latitude']?.toString(),
    );
    _longitudeController = TextEditingController(
      text: event['longitude']?.toString(),
    );
    _province = event['province']?.toString();
    _startDate = DateTime.tryParse(event['startDate']?.toString() ?? '');
    _endDate = DateTime.tryParse(event['endDate']?.toString() ?? '');
    _status = event['status'] == 'published' ? 'published' : 'draft';
    _previousStatus = event['status']?.toString() ?? '';
    _loadProvinces();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    _sourceNameController.dispose();
    _sourceUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    final provinces = await AdminService.loadProvinceNames();
    if (_province != null && !provinces.contains(_province)) {
      provinces.add(_province!);
      provinces.sort();
    }
    if (mounted) setState(() => _provinces = provinces);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.darkPurple,
        title: Text(
          _isEditing ? 'แก้ไขอีเวนต์' : 'เพิ่มอีเวนต์',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(25, 16, 25, 40),
            children: [
              _label('สถานะ'),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'draft', label: Text('ฉบับร่าง')),
                    ButtonSegment(value: 'published', label: Text('เผยแพร่')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) =>
                      setState(() => _status = selection.first),
                ),
              ),
              const SizedBox(height: 20),
              _label('ชื่องาน*'),
              _field(
                controller: _titleController,
                hint: 'ระบุชื่ออีเวนต์',
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              _label('จังหวัด*'),
              DropdownButtonFormField<String>(
                initialValue: _province,
                isExpanded: true,
                decoration: _decoration('เลือกจังหวัด'),
                items: _provinces
                    .map(
                      (province) => DropdownMenuItem(
                        value: province,
                        child: Text(province),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _province = value),
                validator: (value) =>
                    value == null ? 'กรุณาเลือกจังหวัด' : null,
              ),
              const SizedBox(height: 16),
              _label('สถานที่จัดงาน*'),
              _field(
                controller: _locationController,
                hint: 'ระบุสถานที่จัดงาน',
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              _label('วันที่เริ่ม*'),
              DatePickerField(
                label: _formatDate(_startDate) ?? 'เลือกวันที่เริ่ม',
                hasValue: _startDate != null,
                onTap: () => _pickDate(isStartDate: true),
              ),
              const SizedBox(height: 16),
              _label('วันที่สิ้นสุด*'),
              DatePickerField(
                label: _formatDate(_endDate) ?? 'เลือกวันที่สิ้นสุด',
                hasValue: _endDate != null,
                onTap: () => _pickDate(isStartDate: false),
              ),
              const SizedBox(height: 16),
              _label('รายละเอียด*'),
              _field(
                controller: _descriptionController,
                hint: 'ระบุรายละเอียดกิจกรรม',
                maxLines: 6,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              _label('URL รูปภาพ'),
              _field(
                controller: _imageUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
                validator: _optionalUrlValidator,
                onChanged: (_) => setState(() {}),
              ),
              if (_isHttpUrl(_imageUrlController.text)) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    _imageUrlController.text.trim(),
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 100,
                      alignment: Alignment.center,
                      color: Colors.grey.shade100,
                      child: const Text('ไม่สามารถแสดงตัวอย่างรูปได้'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _label('ชื่อแหล่งข้อมูล'),
              _field(
                controller: _sourceNameController,
                hint: 'เช่น ททท. สำนักงานกาญจนบุรี',
              ),
              const SizedBox(height: 16),
              _label('URL แหล่งข้อมูล'),
              _field(
                controller: _sourceUrlController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
                validator: _optionalUrlValidator,
              ),
              const SizedBox(height: 16),
              _label('พิกัดสถานที่ (ไม่บังคับ)'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _latitudeController,
                      hint: 'ละติจูด',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _longitudeController,
                      hint: 'ลองจิจูด',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Symbols.visibility),
                label: const Text('ดูตัวอย่าง'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: AppColors.darkPurple,
                  side: const BorderSide(color: AppColors.darkPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: _status == 'published'
                    ? 'บันทึกและเผยแพร่'
                    : 'บันทึกฉบับร่าง',
                isLoading: _isSaving,
                onTap: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.darkPurple,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: _decoration(hint),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.darkPurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.darkPurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty ? 'กรุณากรอกข้อมูล' : null;
  }

  String? _optionalUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _isHttpUrl(value)
        ? null
        : 'กรุณาระบุ URL ที่ขึ้นต้นด้วย http หรือ https';
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStartDate) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = selected;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Map<String, dynamic>? _buildEventData({bool showErrors = true}) {
    if (!_formKey.currentState!.validate()) return null;
    if (_startDate == null || _endDate == null) {
      if (showErrors) _showMessage('กรุณาเลือกวันที่เริ่มและวันที่สิ้นสุด');
      return null;
    }
    if (_endDate!.isBefore(_startDate!)) {
      if (showErrors) _showMessage('วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม');
      return null;
    }

    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isEmpty != longitudeText.isEmpty) ||
        (latitudeText.isNotEmpty && (latitude == null || longitude == null)) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      if (showErrors) _showMessage('กรุณาระบุพิกัดให้ถูกต้องทั้งสองช่อง');
      return null;
    }

    return {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'province': _province,
      'locationName': _locationController.text.trim(),
      'startDate': Timestamp.fromDate(_startDate!),
      'endDate': Timestamp.fromDate(_endDate!),
      'imageUrl': _imageUrlController.text.trim(),
      'sourceName': _sourceNameController.text.trim(),
      'sourceUrl': _sourceUrlController.text.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'status': _status,
    };
  }

  void _preview() {
    final data = _buildEventData();
    if (data == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventData: {
            ...data,
            'name': data['title'],
            'introduction': data['description'],
            'thumbnailUrl': data['imageUrl'],
            'startDate': _startDate!.toIso8601String(),
            'endDate': _endDate!.toIso8601String(),
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final data = _buildEventData();
    if (data == null) return;
    setState(() => _isSaving = true);
    try {
      await EventService.saveEvent(
        eventId: widget.event?['id'] as String?,
        data: data,
        previousStatus: _previousStatus,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกอีเวนต์เรียบร้อยแล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('บันทึกอีเวนต์ไม่สำเร็จ กรุณาลองอีกครั้ง');
      setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
