import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing and retrieving authentication tokens.
class TokenStorage {
  static const String _idTokenKey = 'auth.idToken';
  static const String _accessTokenKey = 'auth.accessToken';
  static const String _refreshTokenKey = 'auth.refreshToken';
  static const String _idTokenExpiresAtKey = 'auth.idTokenExpiresAt';
  static const String _accessTokenExpiresAtKey = 'auth.accessTokenExpiresAt';
  static const String _userIdKey = 'auth.userId';
  static const String _emailKey = 'auth.email';
  static const Map<String, String> _legacyKeys = {
    _idTokenKey: 'cognito.idToken',
    _accessTokenKey: 'cognito.accessToken',
    _refreshTokenKey: 'cognito.refreshToken',
    _idTokenExpiresAtKey: 'cognito.idTokenExpiresAt',
    _accessTokenExpiresAtKey: 'cognito.accessTokenExpiresAt',
    _userIdKey: 'cognito.userId',
    _emailKey: 'cognito.email',
  };
  static const String _userCreatedFlagKey = 'user.backendCreated';

  /// Save authentication tokens after successful sign in
  static Future<void> saveTokens({
    required String idToken,
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
    String? userId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, idToken);
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
    await _saveTokenExpiries(
      prefs: prefs,
      idToken: idToken,
      accessToken: accessToken,
      expiresIn: expiresIn,
    );

    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }

    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
  }

  /// Update the active session tokens while preserving existing user metadata.
  static Future<void> updateTokens({
    required String idToken,
    required String accessToken,
    int? expiresIn,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, idToken);
    await prefs.setString(_accessTokenKey, accessToken);
    await _saveTokenExpiries(
      prefs: prefs,
      idToken: idToken,
      accessToken: accessToken,
      expiresIn: expiresIn,
    );

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  /// Get the ID token (used for API authentication)
  static Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _getString(prefs, _idTokenKey);
  }

  /// Get the access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _getString(prefs, _accessTokenKey);
  }

  /// Get the refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _getString(prefs, _refreshTokenKey);
  }

  static Future<DateTime?> getIdTokenExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseExpiresAt(_getString(prefs, _idTokenExpiresAtKey));
  }

  static Future<DateTime?> getAccessTokenExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseExpiresAt(_getString(prefs, _accessTokenExpiresAtKey));
  }

  /// Get the stored user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return _getString(prefs, _userIdKey);
  }

  /// Get the stored email
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return _getString(prefs, _emailKey);
  }

  /// Check if user is logged in (has valid tokens)
  static Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    final expiresAt =
        await getAccessTokenExpiresAt() ??
        extractExpiresAtFromToken(accessToken);
    if (expiresAt == null) {
      return true;
    }

    return expiresAt.isAfter(DateTime.now());
  }

  /// Clear all stored tokens (logout)
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _getString(prefs, _userIdKey);
    for (final key in [
      _idTokenKey,
      _accessTokenKey,
      _refreshTokenKey,
      _idTokenExpiresAtKey,
      _accessTokenExpiresAtKey,
      _userIdKey,
      _emailKey,
      ..._legacyKeys.values,
    ]) {
      await prefs.remove(key);
    }

    if (userId != null) {
      await prefs.remove('$_userCreatedFlagKey.$userId');
    }
  }

  /// Get authorization header value for API requests
  /// Returns Bearer token or null if not logged in
  static Future<String?> getAuthorizationHeader() async {
    final accessToken = await getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      return 'Bearer $accessToken';
    }
    return null;
  }

  static Future<String?> getAccessTokenAuthorizationHeader() async {
    final accessToken = await getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      return 'Bearer $accessToken';
    }
    return null;
  }

  /// Extract userId (sub claim) from a JWT.
  /// Returns null if token is invalid or userId cannot be extracted
  static String? extractUserIdFromToken(String idToken) {
    try {
      // JWT format: header.payload.signature
      final parts = idToken.split('.');
      if (parts.length != 3) {
        return null;
      }

      // Decode the payload (second part)
      final payload = parts[1];

      // Add padding if needed for base64 decoding
      var normalized = base64Url.normalize(payload);
      var decoded = utf8.decode(base64Url.decode(normalized));

      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      return payloadMap['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  static DateTime? extractExpiresAtFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payloadMap['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveTokenExpiries({
    required SharedPreferences prefs,
    required String idToken,
    required String accessToken,
    int? expiresIn,
  }) async {
    final fallbackExpiry = expiresIn != null && expiresIn > 0
        ? DateTime.now().add(Duration(seconds: expiresIn))
        : null;

    final idTokenExpiry = extractExpiresAtFromToken(idToken) ?? fallbackExpiry;
    final accessTokenExpiry =
        extractExpiresAtFromToken(accessToken) ?? fallbackExpiry;

    if (idTokenExpiry != null) {
      await prefs.setString(
        _idTokenExpiresAtKey,
        idTokenExpiry.toIso8601String(),
      );
    }
    if (accessTokenExpiry != null) {
      await prefs.setString(
        _accessTokenExpiresAtKey,
        accessTokenExpiry.toIso8601String(),
      );
    }
  }

  static DateTime? _parseExpiresAt(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static String? _getString(SharedPreferences prefs, String key) {
    return prefs.getString(key) ?? prefs.getString(_legacyKeys[key] ?? '');
  }
}
