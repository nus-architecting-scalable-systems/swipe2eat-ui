import 'package:http/http.dart' as http;

import '../../features/auth/services/auth_session.dart';
import '../../features/auth/services/token_storage.dart';

enum AuthTokenType { none, idToken, accessToken }

class AuthenticatedHttpClient {
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    AuthTokenType tokenType = AuthTokenType.idToken,
    http.Client? client,
    http.Client? authClient,
    Duration? timeout,
  }) {
    return _send(
      method: 'GET',
      uri: uri,
      headers: headers,
      tokenType: tokenType,
      client: client,
      authClient: authClient,
      timeout: timeout,
    );
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    AuthTokenType tokenType = AuthTokenType.idToken,
    http.Client? client,
    http.Client? authClient,
    Duration? timeout,
  }) {
    return _send(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
      tokenType: tokenType,
      client: client,
      authClient: authClient,
      timeout: timeout,
    );
  }

  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    AuthTokenType tokenType = AuthTokenType.idToken,
    http.Client? client,
    http.Client? authClient,
    Duration? timeout,
  }) {
    return _send(
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
      tokenType: tokenType,
      client: client,
      authClient: authClient,
      timeout: timeout,
    );
  }

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    AuthTokenType tokenType = AuthTokenType.idToken,
    http.Client? client,
    http.Client? authClient,
    Duration? timeout,
  }) {
    return _send(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      tokenType: tokenType,
      client: client,
      authClient: authClient,
      timeout: timeout,
    );
  }

  static Future<http.Response> _send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    required AuthTokenType tokenType,
    http.Client? client,
    http.Client? authClient,
    Duration? timeout,
  }) async {
    String? initialAuthHeader;
    if (tokenType != AuthTokenType.none) {
      initialAuthHeader = await _authorizationHeader(tokenType);
      if (initialAuthHeader != null) {
        final fresh = await AuthSession.ensureFreshSession(
          authClient: authClient,
        );
        if (!fresh) {
          return http.Response('Session expired', 401);
        }
      }
    }

    final response = await _sendOnce(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      tokenType: tokenType,
      client: client,
      timeout: timeout,
    );

    if (response.statusCode != 401 ||
        tokenType == AuthTokenType.none ||
        initialAuthHeader == null) {
      return response;
    }

    final refreshed = await AuthSession.ensureFreshSession(
      forceRefresh: true,
      authClient: authClient,
    );
    if (!refreshed) {
      return response;
    }

    return _sendOnce(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      tokenType: tokenType,
      client: client,
      timeout: timeout,
    );
  }

  static Future<http.Response> _sendOnce({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    required AuthTokenType tokenType,
    http.Client? client,
    Duration? timeout,
  }) async {
    final effectiveHeaders = <String, String>{...?headers};
    final authHeader = await _authorizationHeader(tokenType);
    if (authHeader != null) {
      effectiveHeaders['Authorization'] = authHeader;
    }

    final effectiveClient = client;
    final future = switch (method) {
      'GET' =>
        effectiveClient != null
            ? effectiveClient.get(uri, headers: effectiveHeaders)
            : http.get(uri, headers: effectiveHeaders),
      'POST' =>
        effectiveClient != null
            ? effectiveClient.post(uri, headers: effectiveHeaders, body: body)
            : http.post(uri, headers: effectiveHeaders, body: body),
      'PUT' =>
        effectiveClient != null
            ? effectiveClient.put(uri, headers: effectiveHeaders, body: body)
            : http.put(uri, headers: effectiveHeaders, body: body),
      'DELETE' =>
        effectiveClient != null
            ? effectiveClient.delete(uri, headers: effectiveHeaders)
            : http.delete(uri, headers: effectiveHeaders),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };

    if (timeout == null) {
      return future;
    }
    return future.timeout(timeout);
  }

  static Future<String?> _authorizationHeader(AuthTokenType tokenType) {
    return switch (tokenType) {
      AuthTokenType.none => Future<String?>.value(),
      AuthTokenType.idToken => TokenStorage.getAuthorizationHeader(),
      AuthTokenType.accessToken =>
        TokenStorage.getAccessTokenAuthorizationHeader(),
    };
  }
}
