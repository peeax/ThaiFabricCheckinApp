import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
import 'auth_wrapper.dart';
import 'introduce_screen.dart';

/// ใช้ Enum เป็น State Machine เพื่อควบคุมขั้นตอนการทำงานของหน้าจอ
enum _AuthStep { enterEmail, login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // จัดการข้อมูลใน TextField
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // กำหนดสถานะเริ่มต้นให้ผู้ใช้กรอกแค่อีเมลก่อน
  _AuthStep _currentStep = _AuthStep.enterEmail;
  bool _isLoading = false;
  String _errorMessage = '';

  // ใช้ Array เก็บข้อความตามลำดับของ Enum เพื่อลดการใช้ if-else ซ้ำซ้อนในส่วนของ UI
  static const _stepTitles = [
    'เข้าสู่ระบบ / สร้างบัญชี',
    'รหัสผ่านของคุณ',
    'สร้างบัญชีกับเรา',
  ];
  static const _actionLabels = ['ถัดไป', 'เข้าสู่ระบบ', 'สร้างบัญชี'];

  @override
  void dispose() {
    // ป้องกันปัญหา Memory Leak โดยการเคลียร์ Controller ออกจากหน่วยความจำ
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setError(String message) => setState(() => _errorMessage = message);
  void _clearError() => setState(() => _errorMessage = '');

  /// ใช้เพื่อดูว่าอีเมลนี้มีในระบบหรือยัง
  Future<void> _checkEmailAndAdvance() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !EmailValidator.validate(email)) {
      _setError('รูปแบบอีเมลไม่ถูกต้อง');
      return;
    }
    _clearError();
    setState(() => _isLoading = true);

    try {
      // ใช้รหัสผ่านหลอก (Dummy Password) ลองเข้าระบบ เพื่อดักจับ Error Code จาก Firebase
      await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: '__password__',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // ถ้าไม่พบผู้ใช้ หรือ รหัสข้อมูลไม่ถูกต้อง (เพราะใช้พาสเวิร์ดหลอก) แปลว่าเป็นอีเมลใหม่ ให้พาไปหน้า Register
      final isNewAccount =
          e.code == 'user-not-found' || e.code == 'invalid-credential';
      setState(
        () =>
            _currentStep = isNewAccount ? _AuthStep.register : _AuthStep.login,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ฟังก์ชันจัดการการกดยืนยันฟอร์ม (Submit)
  Future<void> _submit() async {
    _clearError();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_currentStep == _AuthStep.register) {
      if (password.length < 8) {
        _setError('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร');
        return;
      }
      if (password != _confirmPasswordController.text) {
        _setError('รหัสผ่านไม่ตรงกัน');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // เรียกใช้ Service Layer (Separation of Concerns) ทำให้โค้ด UI ไม่ต้องผูกติดกับ Firebase ตรงๆ
      if (_currentStep == _AuthStep.login) {
        await AuthService.login(email, password);
      } else {
        await AuthService.register(email, password);
      }
      // เมื่อสำเร็จ จะเปลี่ยนหน้า (Routing) ไปยัง AuthWrapper
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _setError(_mapFirebaseAuthError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ฟังก์ชันส่งลิงก์รีเซ็ตรหัสผ่าน
  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!EmailValidator.validate(email)) {
      _setError('กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      _showPasswordResetDialog(email);
    } catch (_) {
      if (mounted) _setError('เกิดข้อผิดพลาด กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // แสดงแจ้งเตือนเมื่อส่งอีเมลรีเซ็ตรหัสผ่านสำเร็จ
  void _showPasswordResetDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ส่งอีเมลสำเร็จ'),
        content: Text('ลิงก์รีเซ็ตรหัสผ่านถูกส่งไปที่ $email แล้ว'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (_currentStep != _AuthStep.enterEmail) {
      setState(() {
        _currentStep = _AuthStep.enterEmail;
        _clearError();
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const IntroduceScreen()),
      );
    }
  }

  String _mapFirebaseAuthError(String code) => switch (code) {
    'wrong-password' ||
    'invalid-credential' => 'รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่',
    'too-many-requests' => 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
    'network-request-failed' => 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',
    _ => 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง',
  };

  @override
  Widget build(BuildContext context) {
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
              GestureDetector(
                onTap: _goBack,
                child: const Icon(
                  Symbols.arrow_back_ios_new,
                  color: AppColors.darkPurple,
                  size: 24,
                ),
              ),
              const SizedBox(height: 40),
              // ดึงข้อความตามสถานะ Enum ปัจจุบัน
              Text(
                _stepTitles[_currentStep.index],
                style: const TextStyle(
                  color: AppColors.darkPurple,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              // TextField สำหรับกรอกอีเมล
              AppTextField(
                controller: _emailController,
                hint: 'กรอกอีเมล',
                keyboardType: TextInputType.emailAddress,
                enabled: _currentStep == _AuthStep.enterEmail,
              ),
              // Conditional Rendering: แสดงช่องกรอกพาสเวิร์ด ก็ต่อเมื่อผ่านขั้นตอนกรอกอีเมลมาแล้ว
              if (_currentStep != _AuthStep.enterEmail) ...[
                const SizedBox(height: 15),
                AppTextField(
                  controller: _passwordController,
                  hint: 'กรอกรหัสผ่าน',
                  isPassword: true,
                ),
              ],
              // Conditional Rendering: แสดงช่องยืนยันพาสเวิร์ด เฉพาะตอนที่กำลังจะสมัครสมาชิกใหม่
              if (_currentStep == _AuthStep.register) ...[
                const SizedBox(height: 15),
                AppTextField(
                  controller: _confirmPasswordController,
                  hint: 'กรอกยืนยันรหัสผ่าน',
                  isPassword: true,
                ),
              ],
              const SizedBox(height: 10),
              // แสดงข้อความ Error หากมี
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 12,
                  ),
                ),
              // แสดงปุ่มลืมรหัสผ่าน เฉพาะตอนที่อยู่ในสถานะ Login
              if (_currentStep == _AuthStep.login)
                GestureDetector(
                  onTap: _sendPasswordReset,
                  child: const Text(
                    'ลืมรหัสผ่าน?',
                    style: TextStyle(
                      color: AppColors.darkPurple,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              const Spacer(), // ดันปุ่ม Submit ให้ชิดขอบล่างของจอเสมอ
              AppButton(
                label: _actionLabels[_currentStep.index],
                isLoading: _isLoading,
                onTap: _currentStep == _AuthStep.enterEmail
                    ? _checkEmailAndAdvance
                    : _submit,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
