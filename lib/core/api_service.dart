import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TatApiService {
  TatApiService._(); // ป้องกันการสร้าง instance (static class)

  static String _getApiToken() => dotenv.env['TAT_API_KEY'] ?? '';

  static Future<List<Map<String, dynamic>>> fetchAttractions(
    String provinceName,
  ) async {
    final String cleanProvinceName = provinceName
        .replaceAll('จังหวัด', '')
        .replaceAll('จ.', '')
        .trim();

    final Uri url = Uri.https(
      'tatdataapi.io',
      '/api/v2/places',
      {'keyword': cleanProvinceName, 'limit': '30'},
    );

    final http.Response response = await http.get(
      url,
      headers: {
        'x-api-key': _getApiToken(),
        'Accept-Language': 'th',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decodedData =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> dataList = decodedData['data'] as List? ?? [];

      return dataList.cast<Map<String, dynamic>>();
    } else if (response.statusCode == 401) {
      throw Exception('API Key ขัดข้อง (Error 401)');
    } else {
      throw Exception('เซิร์ฟเวอร์ตอบกลับ: ${response.statusCode}');
    }
  }
}