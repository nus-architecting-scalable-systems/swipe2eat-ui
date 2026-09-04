import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe2eat_ui/features/auth/screens/forgot_password_screen.dart';

void main() {
  group('ForgotPasswordScreen', () {
    Future<void> pumpScreen(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          routes: {
            '/sign-in': (_) => const Scaffold(body: Text('Sign In Route')),
          },
          home: const ForgotPasswordScreen(),
        ),
      );
    }

    testWidgets('shows reset request state by default', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Send Reset Code'), findsOneWidget);
      expect(find.text('Reset Code'), findsNothing);
    });

    testWidgets('prefills email when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'user@example.com'),
        ),
      );

      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('validates email before requesting a reset code', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets(
      'shows unsupported message because user service has no reset API',
      (tester) async {
        await pumpScreen(tester);

        await tester.enterText(
          find.byType(TextFormField).first,
          'user@example.com',
        );
        await tester.tap(find.text('Send Reset Code'));
        await tester.pumpAndSettle();

        expect(
          find.text('Password reset is not supported by the user service.'),
          findsOneWidget,
        );
        expect(find.text('Reset Your Password'), findsNothing);
      },
    );
  });
}
