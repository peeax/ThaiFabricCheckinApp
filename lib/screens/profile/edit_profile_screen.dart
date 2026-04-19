import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();
  DateTime? _birthday;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // ดึงข้อมูลเดิมของผู้ใช้จาก appState มาแสดงในฟอร์ม 
    // เพื่อให้ผู้ใช้ไม่ต้องพิมพ์ใหม่ทั้งหมด
    final data = appState.userData ?? {};
    _usernameController.text = data['username'] as String? ?? '';
    // ข้อมูลวันที่ใน Firestore ถูกเก็บเป็นรูปแบบ 'Timestamp' 
    // เราต้องแปลงให้กลับมาเป็น 'DateTime' ของภาษา Dart ก่อนนำไปใช้งานในแอป
    if (data['birthday'] != null) {
      _birthday = (data['birthday'] as Timestamp).toDate();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  /// ฟังก์ชันสำหรับบันทึกการแก้ไข
  Future<void> _saveChanges() async {
    // ใช้ .trim() ตัดช่องว่างหัว-ท้าย ป้องกันผู้ใช้เผลอกด Spacebar
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกชื่อ');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      // เรียกใช้ Service Layer (Separation of Concerns) เพื่อพูดคุยกับ Firebase
      await UserService.updateProfile(
        uid: firebaseAuth.currentUser!.uid,
        username: username,
        birthday: _birthday, // ถ้าผู้ใช้ไม่แก้ ค่านี้ก็จะเป็นค่าเดิมที่ดึงมาตอน initState
      );
      // เมื่ออัปเดตสำเร็จ ให้ปิดหน้านี้และย้อนกลับไปหน้า Profile
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'บันทึกไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthdayDisplayText = _birthday != null ? DateFormat('dd/MM/yyyy').format(_birthday!) : 'เลือกวันเดือนปีเกิด';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Symbols.arrow_back_ios_new, color: AppColors.darkPurple),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('แก้ไขข้อมูลส่วนตัว', style: TextStyle(color: AppColors.darkPurple, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              const Text('ชื่อผู้ใช้*', style: TextStyle(color: AppColors.darkPurple, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              AppTextField(controller: _usernameController, hint: 'กรอกชื่อ'),
              const SizedBox(height: 20),
              const Text('วันเดือนปีเกิด (ค.ศ.)', style: TextStyle(color: AppColors.darkPurple, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DatePickerField(
                label: birthdayDisplayText,
                hasValue: _birthday != null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthday ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthday = picked);
                },
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorMessage, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
                ),
              const Spacer(),
              AppButton(label: 'บันทึก', isLoading: _isSaving, onTap: _saveChanges),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}