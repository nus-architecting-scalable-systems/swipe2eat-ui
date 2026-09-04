import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class UserAuthService {
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String password,
    required String name,
    String? city,
    String? gender,
    DateTime? dateOfBirth,
    http.Client? client,
  }) {
    return _postJson(
      '/register',
      {
        'username': username,
        'password': password,
        'name': name,
        'city': ?city,
        'gender': ?gender,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth.toIso8601String().split('T').first,
      },
      client: client,
      successMessage: 'Account created successfully.',
    );
  }

  static Future<Map<String, dynamic>> signIn({
    required String username,
    required String password,
    http.Client? client,
  }) {
    return _postJson(
      '/login',
      {'username': username, 'password': password},
      client: client,
      requireAccessToken: true,
      successMessage: 'Signed in successfully.',
    );
  }

  static Future<Map<String, dynamic>> refreshSession({
    required String refreshToken,
    http.Client? client,
  }) {
    return Future.value({
      'success': false,
      'error': 'Session refresh is not supported by the user service.',
    });
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
    http.Client? client,
  }) {
    return Future.value({
      'success': false,
      'error': 'Password reset is not supported by the user service.',
    });
  }

  static Future<Map<String, dynamic>> confirmForgotPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
    http.Client? client,
  }) {
    return Future.value({
      'success': false,
      'error': 'Password reset is not supported by the user service.',
    });
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    http.Client? client,
    bool requireAccessToken = false,
    required String successMessage,
  }) async {
    http.Client? ownedClient;

    try {
      final effectiveClient = client ?? (ownedClient = http.Client());
      final response = await effectiveClient
          .post(
            Uri.parse('${ApiConfig.userBaseUrl}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final responseBody = _decodeJsonObject(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final authFields = _extractAuthFields(responseBody);
        if (requireAccessToken &&
            (authFields['accessToken'] as String?)?.isNotEmpty != true) {
          return {
            'success': false,
            'error': 'Authentication response did not include an access token.',
          };
        }

        return {
          'success': true,
          'message': _extractMessage(responseBody) ?? successMessage,
          ...authFields,
        };
      }

      return {
        'success': false,
        'error': _extractError(responseBody, response.statusCode),
        'statusCode': response.statusCode,
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Please try again.',
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'Network error. Please check your connection and try again.',
      };
    } finally {
      ownedClient?.close();
    }
  }

  static Map<String, dynamic> _decodeJsonObject(String body) {
    if (body.trim().isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  static Map<String, dynamic> _extractAuthFields(Map<String, dynamic> body) {
    final maps = _candidateMaps(body);
    final accessToken = _firstString(maps, const [
      'accessToken',
      'access_token',
      'token',
      'jwt',
      'authToken',
    ]);
    final idToken =
        _firstString(maps, const ['idToken', 'id_token', 'identityToken']) ??
        accessToken;
    final refreshToken = _firstString(maps, const [
      'refreshToken',
      'refresh_token',
    ]);
    final expiresIn = _firstNum(maps, const ['expiresIn', 'expires_in']);
    final userId = _firstString(maps, const ['userId', 'userid', 'id', 'sub']);
    final username = _firstString(maps, const ['username', 'email']);

    return {
      'idToken': ?idToken,
      'accessToken': ?accessToken,
      'refreshToken': ?refreshToken,
      'expiresIn': ?expiresIn,
      'userId': ?userId,
      'username': ?username,
      'email': ?username,
    };
  }

  static List<Map<String, dynamic>> _candidateMaps(Map<String, dynamic> body) {
    final maps = <Map<String, dynamic>>[body];
    for (var index = 0; index < maps.length; index++) {
      final map = maps[index];
      for (final key in const ['data', 'auth', 'session', 'tokens', 'user']) {
        final value = map[key];
        if (value is Map<String, dynamic>) {
          maps.add(value);
        } else if (value is Map) {
          maps.add(value.map((key, value) => MapEntry(key.toString(), value)));
        }
      }
    }
    return maps;
  }

  static String? _firstString(
    List<Map<String, dynamic>> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  static num? _firstNum(List<Map<String, dynamic>> maps, List<String> keys) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key];
        if (value is num) {
          return value;
        }
        if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return null;
  }

  static String? _extractMessage(Map<String, dynamic> body) {
    return _firstString([body], const ['message', 'detail']);
  }

  static String _extractError(Map<String, dynamic> body, int statusCode) {
    return _firstString(_candidateMaps(body), const [
          'error',
          'message',
          'detail',
          'error_description',
        ]) ??
        'Request failed with status $statusCode.';
  }
}
