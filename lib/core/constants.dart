import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Singleton instances ของ Firebase services
final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
final FirebaseFirestore firestoreDB = FirebaseFirestore.instance;

class AppColors {
  AppColors._();
  static const Color darkPurple = Color(0xFF13084C);
  static const Color mediumPurple = Color(0xFF383257);
  static const Color errorRed = Color(0xFFAB0000);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD9D9D9);
  static const Color borderLight = Color(0xFFE0E0E0);
}

class AppStrings {
  AppStrings._();
  static const String fontFamily = 'Anuphan';
  static const String appTitle = 'แอ่วไหม';
  static const int totalProvinces = 77;
}

class AppLog {
  AppLog._();
  static void debug(String message) => developer.log(message, name: 'APP_DEBUG');
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      developer.log(
        message,
        name: 'APP_ERROR',
        error: error,
        stackTrace: stackTrace,
      );
}