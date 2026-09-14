import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/services/token_storage.dart';
import '../config/api_config.dart';
import 'authenticated_http_client.dart';

/// Service for managing user operations with the backend
class UserService {
  static const String _userCreatedFlagKey = 'user.backendCreated';

  /// Creates or syncs a user in the backend after authentication.
  ///
  /// Backend-owned username/password registration creates the user through
  /// `POST /user/register`; the old `POST /user/create-user` sync endpoint no
  /// longer exists. This method now only records that an authenticated user has
  /// already been provisioned, so legacy callers do not hit a removed endpoint.
  static Future<bool> createUserInBackend() async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final userCreatedKey = '$_userCreatedFlagKey.$userId';
      final alreadyCreated = prefs.getBool(userCreatedKey) ?? false;

      if (alreadyCreated) {
        return true;
      }

      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      await prefs.setBool(userCreatedKey, true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logs out the currently signed-in user in the backend.
  /// Uses the access token so the backend can invalidate the session.
  ///
  /// Returns true if the backend logout succeeds.
  static Future<bool> logoutCurrentUser({http.Client? client}) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.trim().isEmpty) {
        return false;
      }

      final response = await _sendLogoutRequest(
        accessToken: accessToken,
        client: client,
      );
      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> _sendLogoutRequest({
    required String accessToken,
    http.Client? client,
  }) async {
    http.Client? ownedClient;

    try {
      final effectiveClient = client ?? (ownedClient = http.Client());
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final uri = Uri.parse('${ApiConfig.userBaseUrl}/logout');
      return await effectiveClient
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      rethrow;
    } finally {
      ownedClient?.close();
    }
  }

  /// Fetches the current user's profile from the backend.
  /// Returns a map with user fields (name, city, gender, dateOfBirth) or null on failure.
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = await TokenStorage.getUserId();
      final accessToken = await TokenStorage.getAccessToken();
      final idToken = await TokenStorage.getIdToken();
      if (userId == null || accessToken == null || idToken == null) return null;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Id-Token': idToken,
      };

      final uri = Uri.parse('${ApiConfig.userBaseUrl}/$userId');
      final response = await AuthenticatedHttpClient.get(
        uri,
        headers: headers,
        tokenType: AuthTokenType.accessToken,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Updates the current user's profile (name, city, gender, dateOfBirth).
  /// Returns true on success.
  static Future<bool> updateUserProfile({
    String? name,
    String? city,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      final idToken = await TokenStorage.getIdToken();
      if (accessToken == null || idToken == null) return false;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Id-Token': idToken,
      };

      final body = jsonEncode({
        'name': ?name,
        'city': ?city,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
      });

      final uri = Uri.parse('${ApiConfig.userBaseUrl}/me');
      final response = await AuthenticatedHttpClient.put(
        uri,
        headers: headers,
        body: body,
        tokenType: AuthTokenType.accessToken,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Clears the user created flag (useful on logout)
  static Future<void> clearUserCreatedFlag({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? await TokenStorage.getUserId();
    if (effectiveUserId != null) {
      final userCreatedKey = '$_userCreatedFlagKey.$effectiveUserId';
      await prefs.remove(userCreatedKey);
    }
  }

  /// Deletes the currently signed-in user from backend.
  /// Uses the stored userId as path parameter.
  ///
  /// Returns true if the backend deletion succeeds.
  /// Treats an already-missing backend user as a successful delete.
  static Future<bool> deleteCurrentUserInBackend({http.Client? client}) async {
    http.Client? ownedClient;

    try {
      final effectiveClient = client ?? (ownedClient = http.Client());
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        return false;
      }

      final accessToken = await TokenStorage.getAccessToken();
      final idToken = await TokenStorage.getIdToken();
      if (accessToken == null ||
          accessToken.isEmpty ||
          idToken == null ||
          idToken.isEmpty) {
        return false;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Id-Token': idToken,
      };

      final uri = Uri.parse('${ApiConfig.userBaseUrl}/$userId');
      final response = await AuthenticatedHttpClient.delete(
        uri,
        headers: headers,
        tokenType: AuthTokenType.accessToken,
        client: effectiveClient,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (_) {
      return false;
    } finally {
      ownedClient?.close();
    }
  }
}
