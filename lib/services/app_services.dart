import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/constants.dart';

final FirebaseFunctions cloudFunctions = FirebaseFunctions.instanceFor(
  region: 'asia-southeast1',
);

/// ชั้นของ Service (Service Layer) สำหรับจัดการ Firebase Auth
/// ช่วยให้ง่ายต่อการนำไปเขียน Unit Test
class AuthService {
  AuthService._();

  static Future<void> login(String email, String password) async {
    try {
      await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, s) {
      AppLog.error('Login failed', e, s);
      rethrow;
    }
  }

  static Future<void> register(String email, String password) async {
    try {
      await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, s) {
      AppLog.error('Registration failed', e, s);
      rethrow;
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e, s) {
      AppLog.error('Password reset failed', e, s);
      rethrow;
    }
  }
}

/// Service สำหรับจัดการข้อมูลผู้ใช้ (CRUD Operations บน Firestore)
class UserService {
  UserService._();

  static Future<void> createProfile({
    required String uid,
    required String username,
    required DateTime birthday,
  }) async {
    try {
      final batch = firestoreDB.batch();
      final userRef = firestoreDB.collection('users').doc(uid);
      final leaderboardRef = firestoreDB
          .collection('leaderboardProfiles')
          .doc(uid);
      batch.set(userRef, {
        'username': username,
        'birthday': birthday,
        'stampCount': 0,
        // Kept during the custom-claim migration; security rules ignore it.
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(leaderboardRef, {
        'username': username,
        'stampCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e, s) {
      AppLog.error('Create profile failed', e, s);
      rethrow;
    }
  }

  static Future<void> updateProfile({
    required String uid,
    required String username,
    DateTime? birthday,
  }) async {
    try {
      final batch = firestoreDB.batch();
      batch.update(firestoreDB.collection('users').doc(uid), {
        'username': username,
        if (birthday != null) 'birthday': birthday,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        firestoreDB.collection('leaderboardProfiles').doc(uid),
        {'username': username, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e, s) {
      AppLog.error('Update profile failed', e, s);
      rethrow;
    }
  }
}

/// Service จัดการเรื่องตำแหน่ง (GPS และ Geocoding)
class LocationService {
  LocationService._();

  static Future<Position> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('ไม่อนุญาตการเข้าถึงตำแหน่ง');
    }
    // ดึงพิกัดพร้อมตั้งเวลา Timeout ป้องกันแอพค้างหากอับสัญญาณ GPS
    return Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 15),
    );
  }

  static Future<String> getProvinceNameFromCoordinates(
    double lat,
    double lng,
  ) async {
    await setLocaleIdentifier('th_TH');
    final placemarks = await placemarkFromCoordinates(lat, lng);
    String provinceName =
        placemarks.first.administrativeArea ?? 'ไม่สามารถระบุจังหวัดได้';
    return provinceName.replaceAll('จังหวัด', '').trim();
  }
}

/// Service สำหรับจัดการการเช็คอิน
class CheckInService {
  CheckInService._();

  static Future<Map<String, dynamic>> checkIn({
    required String provinceName,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool isMocked,
  }) async {
    try {
      final callable = cloudFunctions.httpsCallable('checkInProvince');
      final result = await callable.call<Map<String, dynamic>>({
        'provinceName': provinceName,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'isMocked': isMocked,
      });
      final payload = Map<String, dynamic>.from(result.data);
      return Map<String, dynamic>.from(payload['province'] as Map);
    } on FirebaseFunctionsException catch (e, s) {
      AppLog.error('Server check-in failed', e, s);
      throw Exception(_checkInErrorMessage(e.code));
    } catch (e, s) {
      AppLog.error('Check-in transaction failed', e, s);
      rethrow;
    }
  }

  static String _checkInErrorMessage(String code) => switch (code) {
    'already-exists' => 'เช็คอินจังหวัดนี้เรียบร้อยแล้ว',
    'failed-precondition' => 'ตำแหน่งไม่ตรงกับจังหวัดหรือความแม่นยำไม่เพียงพอ',
    'resource-exhausted' => 'ลองเช็คอินถี่เกินไป กรุณารอสักครู่',
    'unauthenticated' => 'กรุณาเข้าสู่ระบบอีกครั้ง',
    _ => 'ไม่สามารถเช็คอินได้ กรุณาลองใหม่',
  };
}

class AdminService {
  AdminService._();

  static Future<List<String>> loadProvinceNames() async {
    final rawJson = await rootBundle.loadString('assets/data/provinces.json');
    final provinceMap = json.decode(rawJson) as Map<String, dynamic>;
    return provinceMap.keys.toList()..sort();
  }

  /// ฟังก์ชันซิงค์ข้อมูล Mock Data (JSON) ขึ้น Firestore
  static Future<void> syncProvincesFromJson() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/provinces.json');
      final provinceMap = json.decode(rawJson) as Map<String, dynamic>;
      // ใช้ Batch Write เพื่ออัปโหลดข้อมูลทีละมากๆ ใน Request เดียว (ช่วยลดค่าใช้จ่าย Firestore Reads/Writes)
      final batch = firestoreDB.batch();

      for (final entry in provinceMap.entries) {
        final provinceId = entry.key;
        final data = Map<String, dynamic>.from(entry.value as Map);
        final otopProducts = data.remove('otopProducts') as List?;
        final attractions = data.remove('attractions') as List?;
        final docRef = firestoreDB.collection('provinces').doc(provinceId);

        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));

        if (otopProducts != null) {
          for (int i = 0; i < otopProducts.length; i++) {
            batch.set(
              docRef.collection('otopProducts').doc('otop_$i'),
              Map<String, dynamic>.from(otopProducts[i] as Map),
            );
          }
        }
        if (attractions != null) {
          for (int i = 0; i < attractions.length; i++) {
            batch.set(
              docRef.collection('attractions').doc('attr_$i'),
              Map<String, dynamic>.from(attractions[i] as Map),
            );
          }
        }
      }
      await batch.commit(); // ประมวลผลและส่งขึ้นฐานข้อมูล
    } catch (e, s) {
      AppLog.error('Sync provinces failed', e, s);
      rethrow;
    }
  }
}

/// Service สำหรับอ่านอีเวนต์ที่เผยแพร่แล้วจาก Firestore
class EventPage {
  const EventPage({
    required this.events,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> events;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class EventService {
  EventService._();

  static const int defaultPageSize = 25;

  static Future<EventPage> fetchAdminEventsPage({
    required String status,
    String? province,
    int limit = defaultPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = firestoreDB
        .collection('events')
        .where('status', isEqualTo: status);

    if (province != null && province.isNotEmpty) {
      query = query.where('province', isEqualTo: province);
    }

    query = query.orderBy('startDate', descending: true).limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.get();
    final events = snapshot.docs
        .map((doc) => _normalizeEventData(doc.id, doc.data()))
        .toList();

    return EventPage(
      events: events,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  static Future<void> saveEvent({
    String? eventId,
    required Map<String, dynamic> data,
    required String previousStatus,
  }) async {
    final user = firebaseAuth.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบอีกครั้ง');

    final ref = eventId == null
        ? firestoreDB.collection('events').doc()
        : firestoreDB.collection('events').doc(eventId);
    final status = data['status']?.toString() ?? 'draft';
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
      if (eventId == null) 'createdAt': FieldValue.serverTimestamp(),
      if (eventId == null) 'createdBy': user.uid,
      if (status == 'published' && previousStatus != 'published')
        'publishedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(payload, SetOptions(merge: eventId != null));
  }

  static Future<void> updateEventStatus(String eventId, String status) async {
    final user = firebaseAuth.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบอีกครั้ง');

    await firestoreDB.collection('events').doc(eventId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
      if (status == 'published') 'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<EventPage> fetchPublishedEventsByProvincePage({
    required String provinceName,
    int limit = defaultPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final normalizedProvince = _normalizeProvinceName(provinceName);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _dateKey(today);

    try {
      Query<Map<String, dynamic>> query = firestoreDB
          .collection('events')
          .where('status', isEqualTo: 'published')
          .where('province', isEqualTo: normalizedProvince)
          .where('startDate', isGreaterThanOrEqualTo: todayKey)
          .orderBy('startDate')
          .limit(limit);

      if (startAfter != null) query = query.startAfterDocument(startAfter);

      final snapshot = await query.get();
      final eventMap = <String, Map<String, dynamic>>{};

      if (startAfter == null) {
        final ongoingSnapshot = await firestoreDB
            .collection('events')
            .where('status', isEqualTo: 'published')
            .where('province', isEqualTo: normalizedProvince)
            .where('startDate', isLessThan: todayKey)
            .orderBy('startDate', descending: true)
            .limit(10)
            .get();

        for (final doc in ongoingSnapshot.docs) {
          final event = _normalizeEventData(doc.id, doc.data());
          if (_isActiveEvent(event, todayKey)) eventMap[doc.id] = event;
        }
      }

      for (final doc in snapshot.docs) {
        eventMap[doc.id] = _normalizeEventData(doc.id, doc.data());
      }

      final events = eventMap.values.toList()
        ..sort(
          (a, b) =>
              a['startDate'].toString().compareTo(b['startDate'].toString()),
        );

      return EventPage(
        events: events,
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e, s) {
      AppLog.error('Fetch Firestore events failed', e, s);
      throw Exception('ไม่สามารถโหลดข้อมูลอีเวนต์ได้');
    }
  }

  static bool _isActiveEvent(Map<String, dynamic> event, String todayKey) {
    final endDate = event['endDate']?.toString() ?? '';
    if (endDate.isEmpty) return true;
    return endDate.compareTo(todayKey) >= 0;
  }

  static Map<String, dynamic> _normalizeEventData(
    String id,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] ?? data['name'] ?? '';
    final description = data['description'] ?? data['introduction'] ?? '';
    final imageUrl = data['imageUrl'] ?? data['thumbnailUrl'] ?? '';
    final locationName = data['locationName'] ?? data['location'] ?? '';

    return {
      ...data,
      'id': id,
      'name': title.toString(),
      'introduction': description.toString(),
      'thumbnailUrl': imageUrl.toString(),
      'locationName': locationName.toString(),
      'startDate': _formatEventDateValue(data['startDate']),
      'endDate': _formatEventDateValue(data['endDate']),
      'updatedAt': _formatEventDateValue(data['updatedAt']),
      'status': (data['status'] ?? '').toString(),
      'sourceUrl': (data['sourceUrl'] ?? '').toString(),
      'sourceName': (data['sourceName'] ?? '').toString(),
    };
  }

  static String _formatEventDateValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) return _dateKey(value.toDate());
    if (value is DateTime) return _dateKey(value);
    return value.toString();
  }

  static String _normalizeProvinceName(String name) =>
      name.replaceAll('จังหวัด', '').replaceAll('จ.', '').trim();

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class ImporterMonitoringService {
  ImporterMonitoringService._();

  static Future<List<Map<String, dynamic>>> fetchSources() async {
    final snapshot = await firestoreDB
        .collection('eventSources')
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchRecentRuns({
    int limit = 20,
  }) async {
    final snapshot = await firestoreDB
        .collection('importRuns')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  static Future<void> setSourceEnabled(String sourceId, bool enabled) async {
    await firestoreDB.collection('eventSources').doc(sourceId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AttractionService {
  AttractionService._();

  static Future<List<dynamic>> fetchAttractionsByProvince(
    String provinceName,
  ) async {
    try {
      final callable = cloudFunctions.httpsCallable('fetchAttractions');
      final result = await callable.call<Map<String, dynamic>>({
        'provinceName': provinceName,
      });
      return List<dynamic>.from(result.data['items'] as List? ?? const []);
    } catch (e, s) {
      AppLog.error('Fetch attractions failed', e, s);
      throw Exception('ไม่สามารถโหลดข้อมูลสถานที่ท่องเที่ยวได้');
    }
  }
}
