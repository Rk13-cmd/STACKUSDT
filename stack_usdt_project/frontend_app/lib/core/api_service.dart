import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class GameSessionResponse {
  final String sessionId;
  final String userId;
  final double usdtBalance;
  final DateTime startedAt;

  GameSessionResponse({
    required this.sessionId,
    required this.userId,
    required this.usdtBalance,
    required this.startedAt,
  });

  factory GameSessionResponse.fromJson(Map<String, dynamic> json) {
    return GameSessionResponse(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      usdtBalance: (json['usdt_balance'] as num).toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
    );
  }
}

class GameResultResponse {
  final String sessionId;
  final double usdtBalance;
  final int linesCleared;
  final double payout;
  final bool isValid;
  final String? validationMessage;

  GameResultResponse({
    required this.sessionId,
    required this.usdtBalance,
    required this.linesCleared,
    required this.payout,
    required this.isValid,
    this.validationMessage,
  });

  factory GameResultResponse.fromJson(Map<String, dynamic> json) {
    return GameResultResponse(
      sessionId: json['session_id'] as String,
      usdtBalance: (json['usdt_balance'] as num).toDouble(),
      linesCleared: json['lines_cleared'] as int,
      payout: (json['payout'] as num).toDouble(),
      isValid: json['is_valid'] as bool,
      validationMessage: json['validation_message'] as String?,
    );
  }
}

class WithdrawalResponse {
  final bool success;
  final String transactionId;
  final double amount;
  final String message;

  WithdrawalResponse({
    required this.success,
    required this.transactionId,
    required this.amount,
    required this.message,
  });

  factory WithdrawalResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalResponse(
      success: json['success'] as bool,
      transactionId: json['transaction_id'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      message: json['message'] as String,
    );
  }
}

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      String message;
      try {
        final body = json.decode(response.body);
        message = body['message'] ?? body['error'] ?? 'Unknown error';
      } catch (_) {
        message = 'Server error: ${response.statusCode}';
      }
      throw ApiException(message, response.statusCode);
    }
  }

  Future<GameSessionResponse> initGameSession(String userId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/start-game'),
        headers: _headers,
        body: json.encode({'user_id': userId}),
      );

      final data = await _handleResponse(response);
      return GameSessionResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to connect: ${e.toString()}');
    }
  }

  Future<GameResultResponse> submitGameResults({
    required String sessionId,
    required int linesCleared,
    required int playTimeSeconds,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/end-game'),
        headers: _headers,
        body: json.encode({
          'session_id': sessionId,
          'lines_cleared': linesCleared,
          'play_time_seconds': playTimeSeconds,
        }),
      );

      final data = await _handleResponse(response);
      return GameResultResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to submit results: ${e.toString()}');
    }
  }

  Future<WithdrawalResponse> requestUsdtWithdrawal({
    required String userId,
    required double amount,
    required String walletAddress,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/withdraw'),
        headers: _headers,
        body: json.encode({
          'user_id': userId,
          'amount': amount,
          'wallet_address': walletAddress,
        }),
      );

      final data = await _handleResponse(response);
      return WithdrawalResponse.fromJson(data);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to request withdrawal: ${e.toString()}');
    }
  }

  void dispose() {
    _client.close();
  }
}
