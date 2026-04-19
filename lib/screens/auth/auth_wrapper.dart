import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../home/home_screen.dart';
import 'introduce_screen.dart';
import 'personal_info_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.isInitialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (appState.currentUser == null) return const IntroduceScreen();
        if (appState.userData == null) return const PersonalInfoScreen();
        return const HomeScreen();
      },
    );
  }
}