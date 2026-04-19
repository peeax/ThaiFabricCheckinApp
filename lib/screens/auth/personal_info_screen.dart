import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _usernameController = TextEditingController();
  DateTime? _birthday;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void dispose() { _usernameController.dispose(); super.dispose(); }

  String? _validateBirthday(DateTime date) {
    final age = DateTime.now().year - date.year;
    if (age < 3) return 'ผู้ใช้ต้องอายุไม่น้อยกว่า 3 ปี';
    if (age > 120) return 'วันเกิดไม่ถูกต้อง';
    return null;
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null) {
      setState(() { _birthday = picked; _errorMessage = _validateBirthday(picked) ?? ''; });
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) { setState(() => _errorMessage = 'กรุณากรอกชื่อ'); return; }
    if (_birthday == null) { setState(() => _errorMessage = 'กรุณาเลือกวันเกิด'); return; }
    final birthdayError = _validateBirthday(_birthday!);
    if (birthdayError != null) { setState(() => _errorMessage = birthdayError); return; }

    setState(() { _isSaving = true; _errorMessage = ''; });

    try {
      await UserService.createProfile(uid: firebaseAuth.currentUser!.uid, username: username, birthday: _birthday!);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'บันทึกข้อมูลไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthdayDisplayText = _birthday != null ? DateFormat('dd/MM/yyyy').format(_birthday!) : 'เลือกวันเดือนปีเกิด';
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              GestureDetector(onTap: () => firebaseAuth.signOut(), child: const Icon(Symbols.arrow_back_ios_new, color: AppColors.darkPurple, size: 24)),
              const SizedBox(height: 40),
              const Text('ข้อมูลส่วนตัว', style: TextStyle(color: AppColors.darkPurple, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              AppTextField(controller: _usernameController, hint: 'กรอกชื่อ'),
              const SizedBox(height: 15),
              DatePickerField(label: birthdayDisplayText, hasValue: _birthday != null, onTap: _pickBirthday),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
              ],
              const Spacer(),
              AppButton(label: 'ถัดไป', isLoading: _isSaving, onTap: _saveProfile),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}