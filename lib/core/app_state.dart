import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';

class AppStateManager extends ChangeNotifier {
  User? currentUser;
  Map<String, dynamic>? userData;
  bool isInitialized = false;

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  void initialize() {
    firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    currentUser = user;
    _userDocSubscription?.cancel();

    if (user == null) {
      userData = null;
      isInitialized = true;
      notifyListeners();
      return;
    }

    isInitialized = false;
    notifyListeners();

    _userDocSubscription = firestoreDB
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          _onUserDocUpdated,
          onError: (Object e, StackTrace s) =>
              AppLog.error('User document stream error', e, s),
        );
  }

  void _onUserDocUpdated(DocumentSnapshot doc) {
    userData = doc.exists ? doc.data() as Map<String, dynamic>? : null;
    isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}

class StampsManager extends ChangeNotifier {
  StampsManager({required this.uid}) {
    _initStreams();
  }

  final String uid;
  List<Map<String, dynamic>> allProvinces = [];
  Set<String> unlockedProvinceIds = {};
  bool isLoading = true;

  StreamSubscription<QuerySnapshot>? _provincesSubscription;
  StreamSubscription<QuerySnapshot>? _checkinsSubscription;

  void _initStreams() {
    _provincesSubscription = firestoreDB
        .collection('provinces')
        .orderBy('nameTH')
        .snapshots()
        .listen(
          _onProvincesUpdated,
          onError: (Object e, StackTrace s) => AppLog.error('Provinces stream error', e, s),
        );

    _checkinsSubscription = firestoreDB
        .collection('users')
        .doc(uid)
        .collection('checkins')
        .snapshots()
        .listen(
          _onCheckinsUpdated,
          onError: (Object e, StackTrace s) => AppLog.error('Checkins stream error', e, s),
        );
  }

  void _onProvincesUpdated(QuerySnapshot snapshot) {
    allProvinces = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
    _markLoadingComplete();
  }

  void _onCheckinsUpdated(QuerySnapshot snapshot) {
    unlockedProvinceIds = snapshot.docs.map((doc) => doc.id).toSet();
    _markLoadingComplete();
  }

  void _markLoadingComplete() {
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _provincesSubscription?.cancel();
    _checkinsSubscription?.cancel();
    super.dispose();
  }
}

final appState = AppStateManager();