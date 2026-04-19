import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../core/constants.dart';
import '../screens/stamps/stamp_detail_screen.dart';

/* ========================================================= 
   Shared Widgets Repository
   รวม Custom Components ที่ใช้ซ้ำในหลายๆ หน้าจอ 
========================================================= */

/// ปุ่มกดจัดการสถานะ Disable และ Loading
class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, this.onTap, this.isLoading = false});
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading || onTap == null;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: ShapeDecoration(
          color: isDisabled ? Colors.grey : AppColors.darkPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        alignment: Alignment.center,
        // สลับ UI อัตโนมัติระหว่างข้อความ กับ โหลด Progres
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

/// ช่องกรอกข้อความอเนกประสงค์ (Reusable Text Field)
class AppTextField extends StatefulWidget {
  const AppTextField({super.key, required this.controller, required this.hint, this.isPassword = false, this.keyboardType = TextInputType.text, this.enabled = true});
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _isObscured;
  @override
  void initState() {
    super.initState();
    _isObscured = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        // เปลี่ยนสีเส้นขอบและพื้นหลังเพื่อแสดงสถานะว่า Field นี้ถูก Disable อยู่หรือไม่
        border: Border.all(color: widget.enabled ? AppColors.darkPurple : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(5),
        color: widget.enabled ? AppColors.lightBackground : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: widget.controller,
        obscureText: _isObscured,
        keyboardType: widget.keyboardType,
        enabled: widget.enabled,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.black38),
          // Conditional Rendering: วาดไอคอนรูปลูกตาเฉพาะเมื่อ Field นี้เป็นช่องใส่รหัสผ่าน
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: AppColors.darkPurple, size: 20),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                )
              : null,
        ),
      ),
    );
  }
}

/// วิดเจ็ตปุ่มเรียกปฏิทิน
class DatePickerField extends StatelessWidget {
  const DatePickerField({super.key, required this.label, required this.hasValue, required this.onTap});
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: AppColors.darkPurple), borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: hasValue ? Colors.black87 : Colors.black38)),
            const Icon(Symbols.calendar_month, color: AppColors.darkPurple, size: 18),
          ],
        ),
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  const NavButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: AppColors.darkPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(label),
    );
  }
}

/// การ์ดแสดงสถิติตัวเลข (Stat Card) สำหรับหน้าโปรไฟล์
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 80,
      decoration: BoxDecoration(color: AppColors.darkPurple, borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

/// กรอบ Layout ย่อยสำหรับจัดกลุ่มข้อมูลในหน้าโปรไฟล์ (Section Layout Component)
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.title, required this.children, this.showEditButton = false, this.onEditTap});
  final String title;
  final List<Widget> children;
  final bool showEditButton;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple, fontSize: 16)),
              if (showEditButton)
                GestureDetector(onTap: onEditTap, child: const Text('แก้ไข', style: TextStyle(fontSize: 12, color: AppColors.darkPurple))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoItem extends StatelessWidget {
  const ProfileInfoItem({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkPurple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// วิดเจ็ตปกสถานที่พร้อม Gradient และ Text ฝังตัว
class ProvinceCoverImage extends StatelessWidget {
  const ProvinceCoverImage({super.key, required this.coverUrl, required this.nameTH, required this.nameEn});
  final String coverUrl;
  final String nameTH;
  final String nameEn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        coverUrl.isNotEmpty
            ? Image.network(coverUrl, height: 300, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 300, color: AppColors.darkPurple))
            : Container(height: 300, color: AppColors.darkPurple),
        Container(height: 300, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black87]))),
        Positioned(
          bottom: 20,
          left: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nameTH, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1)),
              Text(nameEn, style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// การ์ดแสตมป์สำหรับหน้ารายการ (List Item Component)
class StampCard extends StatelessWidget {
  const StampCard({super.key, required this.provinceId, required this.provinceData, required this.isUnlocked});
  final String provinceId;
  final Map<String, dynamic> provinceData;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final imageUrl = provinceData['stampImageUrl'] as String? ?? '';
    final nameTH = provinceData['nameTH'] as String? ?? provinceId;
    final patternName = provinceData['stampPatternName'] as String? ?? '';

    return GestureDetector(
      // หากยังไม่ถูกปลดล็อก จะไม่สามารถกดเข้าไปดูรายละเอียดได้
      onTap: isUnlocked ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StampDetailScreen(provinceId: provinceId, provinceData: provinceData))) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.lightBackground, border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            // แยก Logic ภาพ Thumbnail ไปไว้ใน Sub-widget เพื่อให้โค้ดส่วนนี้อ่านง่ายขึ้น
            _StampThumbnail(imageUrl: imageUrl, isUnlocked: isUnlocked),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameTH, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkPurple)),
                  const SizedBox(height: 4),
                  // แสดงข้อความตามสถานะการปลดล็อก (Dynamic UI Text)
                  Text(isUnlocked ? patternName : 'ยังไม่ได้เช็คอิน', style: const TextStyle(fontSize: 12, color: AppColors.mediumPurple), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Symbols.arrow_forward_ios, size: 18, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

/// วิดเจ็ตจัดการรูปแสตมป์ขนาดย่อ พร้อมเอฟเฟกต์เบลอ
class _StampThumbnail extends StatelessWidget {
  const _StampThumbnail({required this.imageUrl, required this.isUnlocked});
  final String imageUrl;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 65,
        height: 65,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: isUnlocked ? 0 : 6, sigmaY: isUnlocked ? 0 : 6),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, width: 65, height: 65, color: isUnlocked ? null : Colors.black.withAlpha(51), colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const Icon(Symbols.stars, color: AppColors.darkPurple))
                  : Container(color: Colors.grey.shade300),
            ),
            // ไอคอนแม่กุญแจด้านบน หากยังไม่ปลดล็อก
            if (!isUnlocked) const Icon(Symbols.lock, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}

/// การ์ดสำหรับแสดงข้อมูลบนหน้าอันดับ
class LeaderboardCard extends StatelessWidget {
  const LeaderboardCard({super.key, required this.rank, required this.username, required this.stampCount, required this.isMyAccount});
  final int rank;
  final String username;
  final int stampCount;
  final bool isMyAccount;

  //ถ้วยรางวัลทองเงินทองแดง
  Color _trophyColor() => switch (rank) { 1 => Colors.amber, 2 => Colors.grey, 3 => const Color(0xFFCD7F32), _ => Colors.transparent };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.lightBackground, borderRadius: BorderRadius.circular(15), border: Border.all(color: isMyAccount ? AppColors.darkPurple : AppColors.border)),
      child: Row(
        children: [
          SizedBox(width: 35, child: rank <= 3 ? Icon(Symbols.trophy, color: _trophyColor(), size: 24) : Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple))),
          const SizedBox(width: 10),
          Expanded(child: Text(isMyAccount ? '$username (คุณ)' : username, style: TextStyle(fontWeight: isMyAccount ? FontWeight.bold : FontWeight.normal, color: AppColors.darkPurple))),
          Text('$stampCount แสตมป์', style: const TextStyle(color: AppColors.mediumPurple, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}