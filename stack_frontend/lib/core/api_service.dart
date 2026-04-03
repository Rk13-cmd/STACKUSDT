import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3001/api';

  final Map<String, String> _headers = {'Content-Type': 'application/json'};

  void setAuthToken(String token) {
    _headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _headers.remove('Authorization');
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Connection failed: $e'};
    }
  }
}

final apiService = ApiService();
