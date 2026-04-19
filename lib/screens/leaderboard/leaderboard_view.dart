import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../core/app_state.dart';
import '../../widgets/shared_widgets.dart';

class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = firebaseAuth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('อันดับ', style: TextStyle(color: AppColors.darkPurple, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Top 10 ผู้สะสมแสตมป์มากที่สุด', style: TextStyle(color: AppColors.mediumPurple, fontSize: 14)),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: appState,
                builder: (context, _) {
                  final stampCount = appState.userData?['stampCount'] as int? ?? 0;
                  return _MyStampBanner(stampCount: stampCount);
                },
              ),
              const SizedBox(height: 25),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestoreDB.collection('users').orderBy('stampCount', descending: true).limit(10).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (_, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return LeaderboardCard(
                          rank: index + 1,
                          username: data['username'] as String? ?? 'ไม่ระบุชื่อ',
                          stampCount: data['stampCount'] as int? ?? 0,
                          isMyAccount: doc.id == uid,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyStampBanner extends StatelessWidget {
  const _MyStampBanner({required this.stampCount});
  final int stampCount;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.darkPurple, borderRadius: BorderRadius.circular(25)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('สะสมแล้ว', style: TextStyle(color: Colors.white, fontSize: 16)),
          Text('$stampCount / ${AppStrings.totalProvinces} แสตมป์', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}