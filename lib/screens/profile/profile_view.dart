import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../services/app_services.dart';
import '../../widgets/shared_widgets.dart';
import 'edit_profile_screen.dart';
import 'faq_screen.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _isSyncing = false;

  Future<void> _syncProvinces() async {
    setState(() => _isSyncing = true);
    try {
      await AdminService.syncProvincesFromJson();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ซิงค์ข้อมูลสำเร็จ!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final data = appState.userData ?? {};
          final stampCount = data['stampCount'] as int? ?? 0;
          final username = data['username'] as String? ?? '';
          final isAdmin = data['isAdmin'] as bool? ?? false;
          final email = firebaseAuth.currentUser?.email ?? '-';
          final achievementPercent = ((stampCount / AppStrings.totalProvinces) * 100).toInt();
          final birthdayText = _formatBirthday(data['birthday']);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),
                const CircleAvatar(radius: 50, backgroundImage: AssetImage('assets/images/default_profile.png'), backgroundColor: Colors.transparent),
                const SizedBox(height: 15),
                Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatCard(value: '$stampCount', label: 'แสตมป์'),
                      StatCard(value: '$achievementPercent%', label: 'ความสำเร็จ'),
                      FutureBuilder<AggregateQuerySnapshot>(
                        future: firestoreDB.collection('users').where('stampCount', isGreaterThan: stampCount).count().get(),
                        builder: (_, snapshot) {
                          final rank = snapshot.hasData ? '${(snapshot.data!.count ?? 0) + 1}' : '...';
                          return StatCard(value: rank, label: 'อันดับ');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ProfileSection(
                  title: 'ข้อมูลส่วนตัว',
                  showEditButton: true,
                  onEditTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
                  children: [
                    ProfileInfoItem(label: 'ชื่อผู้ใช้', value: username),
                    ProfileInfoItem(label: 'อีเมล', value: email),
                    ProfileInfoItem(label: 'วันเดือนปีเกิด', value: birthdayText),
                  ],
                ),
                ProfileSection(
                  title: 'ช่วยเหลือ',
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('คำถามที่พบบ่อย'), Icon(Symbols.chevron_right)]),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 25), child: AppButton(label: 'ออกจากระบบ', onTap: () => firebaseAuth.signOut())),
                if (isAdmin) ...[
                  const SizedBox(height: 15),
                  _isSyncing
                      ? const CircularProgressIndicator()
                      : TextButton.icon(onPressed: _syncProvinces, icon: const Icon(Symbols.sync, size: 14), label: const Text('Admin: Sync ข้อมูลจังหวัด', style: TextStyle(fontSize: 11, color: Colors.grey))),
                ],
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatBirthday(dynamic birthdayField) {
    if (birthdayField == null) return 'ไม่ระบุ';
    return DateFormat('dd/MM/yyyy').format((birthdayField as Timestamp).toDate());
  }
}