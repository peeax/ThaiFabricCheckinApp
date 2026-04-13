import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// ธีมสี ฟอนต์
// ---------------------------------------------------------------------------
const Color darkPurple = Color(0xFF13084C);
const Color mediumPurple = Color(0xFF383257);
const Color errorRed = Color(0xFFAB0000);
const Color lightBackground = Color(0xFFFFFFFF);
const String appFont = 'Anuphan';

// ---------------------------------------------------------------------------
// Firebase instances
// ---------------------------------------------------------------------------
final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
final FirebaseFirestore firestoreDB = FirebaseFirestore.instance;