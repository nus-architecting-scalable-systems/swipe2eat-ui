import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/chat/models/chat_message.dart';
import 'package:swipe2eat_ui/features/chat/services/chat_service.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('ChatService.sendMessage', () {
    late HttpTestOverrides httpOverrides;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    test(
      'returns a not-logged-in bot message when user id is unavailable',
      () async {
        final reply = await ChatService.sendMessage('hello');

        expect(reply.sender, MessageSender.bot);
        expect(reply.text, 'Unable to send message: not logged in.');
        expect(httpOverrides.requests, isEmpty);
      },
    );

    test('posts chat payload and parses reply recommendations', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      httpOverrides.addResponse(
        method: 'POST',
        url: ApiConfig.llmChatUrl,
        response: StubHttpResponse.json({
          'reply': 'Try the laksa.',
          'recommendations': [
            {
              'name': 'Laksa',
              'price': 8.9,
              'spice_level': 3,
              'cuisine': 'Malay',
              'reasons': ['Matches your spice preference'],
            },
          ],
        }),
      );

      final reply = await ChatService.sendMessage('What should I eat?');

      expect(reply.text, 'Try the laksa.');
      expect(reply.recommendations, hasLength(1));
      expect(reply.recommendations.single.name, 'Laksa');

      final request = httpOverrides.requests.single;
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(request.headers['content-type'], 'application/json');
      expect(
        jsonDecode(request.body),
        equals({'message': 'What should I eat?', 'user_id': 'user-123'}),
      );
    });

    test(
      'returns a retry message when backend replies with non-200 status',
      () async {
        await TokenStorage.saveTokens(
          idToken: 'id-token',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          userId: 'user-123',
        );

        httpOverrides.addResponse(
          method: 'POST',
          url: ApiConfig.llmChatUrl,
          response: const StubHttpResponse(statusCode: 502, body: '{}'),
        );

        final reply = await ChatService.sendMessage('Ping');

        expect(reply.text, 'Something went wrong (502). Please try again.');
      },
    );

    test(
      'returns a connection failure message on request exceptions',
      () async {
        await TokenStorage.saveTokens(
          idToken: 'id-token',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          userId: 'user-123',
        );

        final reply = await ChatService.sendMessage('Ping');

        expect(
          reply.text,
          'Could not reach the AI service. Please check your connection.',
        );
      },
    );
  });
}
