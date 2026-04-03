import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _userId;
  String? _userEmail;
  String? _token;
  bool _isLoading = false;
  String? _error;

  String? get userId => _userId;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userId != null;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  double get balance {
    return double.tryParse(_userProfile?['usdt_balance']?.toString() ?? '0') ??
        0;
  }

  String get username {
    return _userProfile?['username'] ?? _userEmail ?? 'User';
  }

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _userId = session.user.id;
      _userEmail = session.user.email;
      _token = session.accessToken;
      apiService.setAuthToken(_token!);
      _loadUserProfile(_userId!);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await apiService.get('/auth/profile/$userId');
      if (response['success'] == true) {
        _userProfile = response['user'];
        notifyListeners();
      }
    } catch (e) {
      // Profile load failed, continue anyway
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response['success'] == true) {
        _token = response['token'];
        _userId = response['user']['id'];
        _userEmail = response['user']['email'];
        _userProfile = response['user'];
        if (_token != null) {
          apiService.setAuthToken(_token!);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['error'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.post('/auth/register', {
        'email': email,
        'password': password,
        'username': username,
      });

      if (response['success'] == true) {
        _userProfile = response['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['error'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await apiService.post('/auth/logout', {'token': _token});
      }
    } catch (e) {
      // Ignore logout errors
    }
    _userId = null;
    _userEmail = null;
    _token = null;
    _userProfile = null;
    apiService.clearAuthToken();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_userId != null) {
      await _loadUserProfile(_userId!);
    }
  }
}
