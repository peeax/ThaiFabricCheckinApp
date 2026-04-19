import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants.dart';

class AuthService {
  AuthService._();

  static Future<void> login(String email, String password) async {
    try {
      await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e, s) {
      AppLog.error('Login failed', e, s);
      rethrow;
    }
  }

  static Future<void> register(String email, String password) async {
    try {
      await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
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

class UserService {
  UserService._();

  static Future<void> createProfile({
    required String uid,
    required String username,
    required DateTime birthday,
  }) async {
    try {
      await firestoreDB.collection('users').doc(uid).set({
        'username': username,
        'birthday': birthday,
        'stampCount': 0,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
      await firestoreDB.collection('users').doc(uid).update({
        'username': username,
        if (birthday != null) 'birthday': birthday,
      });
    } catch (e, s) {
      AppLog.error('Update profile failed', e, s);
      rethrow;
    }
  }
}

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

    return Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 15));
  }

  static Future<String> getProvinceNameFromCoordinates(double lat, double lng) async {
    await setLocaleIdentifier('th_TH');
    final placemarks = await placemarkFromCoordinates(lat, lng);
    String provinceName = placemarks.first.administrativeArea ?? 'ไม่สามารถระบุจังหวัดได้';
    return provinceName.replaceAll('จังหวัด', '').trim();
  }
}

class CheckInService {
  CheckInService._();

  static Future<Map<String, dynamic>> checkIn({required String uid, required String provinceName}) async {
    try {
      final provinceDoc = await firestoreDB.collection('provinces').doc(provinceName).get();
      if (!provinceDoc.exists) throw Exception('ยังไม่เปิดให้เช็คอินที่จังหวัดนี้');

      final provinceData = provinceDoc.data()!;

      await firestoreDB.runTransaction((transaction) async {
        final checkInRef = firestoreDB.collection('users').doc(uid).collection('checkins').doc(provinceName);
        final existingCheckIn = await transaction.get(checkInRef);

        if (existingCheckIn.exists) throw Exception('เช็คอินจังหวัดนี้เรียบร้อยแล้ว');

        transaction.set(checkInRef, {...provinceData, 'at': FieldValue.serverTimestamp()});
        transaction.update(firestoreDB.collection('users').doc(uid), {
          'stampCount': FieldValue.increment(1),
        });
      });

      return provinceData;
    } catch (e, s) {
      AppLog.error('Check-in transaction failed', e, s);
      rethrow;
    }
  }
}

class AdminService {
  AdminService._();

  static Future<void> syncProvincesFromJson() async {
    try {
      final rawJson = await rootBundle.loadString('assets/data/provinces.json');
      final provinceMap = json.decode(rawJson) as Map<String, dynamic>;
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
            batch.set(docRef.collection('otopProducts').doc('otop_$i'), Map<String, dynamic>.from(otopProducts[i] as Map));
          }
        }
        if (attractions != null) {
          for (int i = 0; i < attractions.length; i++) {
            batch.set(docRef.collection('attractions').doc('attr_$i'), Map<String, dynamic>.from(attractions[i] as Map));
          }
        }
      }
      await batch.commit();
    } catch (e, s) {
      AppLog.error('Sync provinces failed', e, s);
      rethrow;
    }
  }
}

class TatApiService {
  TatApiService._();

  static const String _baseHost = 'tatdataapi.io';
  static const String _placesPath = '/api/v2/places';
  static const String _eventsPath = '/api/v2/events';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _cacheDuration = Duration(minutes: 5);
  static final Map<String, List<dynamic>> _attractionsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  static String get _apiKey => dotenv.env['TAT_API_KEY'] ?? '';
  static Map<String, String> get _requestHeaders => {'x-api-key': _apiKey, 'Accept-Language': 'th'};

  static Future<List<dynamic>> fetchAttractionsByProvince(String provinceName) async {
    final keyword = _normalizeProvinceName(provinceName);
    final cachedAt = _cacheTimestamps[keyword];
    if (cachedAt != null && DateTime.now().difference(cachedAt) <= _cacheDuration) {
      return _attractionsCache[keyword] ?? [];
    }

    try {
      final uri = Uri.https(_baseHost, _placesPath, {'keyword': keyword, 'limit': '20'});
      final response = await http.get(uri, headers: _requestHeaders).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final places = (body['data'] as List?) ?? [];
        _attractionsCache[keyword] = places;
        _cacheTimestamps[keyword] = DateTime.now();
        return places;
      }
      throw Exception('TAT API error: ${response.statusCode}');
    } catch (e, s) {
      AppLog.error('Fetch attractions failed', e, s);
      throw Exception('ไม่สามารถโหลดข้อมูลสถานที่ท่องเที่ยวได้');
    }
  }

  static Future<List<dynamic>> fetchEventsByProvince(String provinceName) async {
    final keyword = _normalizeProvinceName(provinceName);
    try {
      final uri = Uri.https(_baseHost, _eventsPath, {'keyword': keyword, 'limit': '30'});
      final response = await http.get(uri, headers: _requestHeaders).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return (body['data'] as List?) ?? [];
      }
      throw Exception('TAT API error: ${response.statusCode}');
    } catch (e, s) {
      AppLog.error('Fetch events failed', e, s);
      throw Exception('ไม่สามารถโหลดข้อมูลอีเวนต์ได้');
    }
  }

  static String _normalizeProvinceName(String name) => name.replaceAll('จังหวัด', '').replaceAll('จ.', '').trim();
}