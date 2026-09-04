import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe2eat_ui/features/auth/screens/forgot_password_screen.dart';
import 'package:swipe2eat_ui/features/auth/screens/sign_in_screen.dart';

void main() {
  group('SignInScreen Widget', () {
    testWidgets('displays Sign In title in AppBar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('has username input field', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('has password input field', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('password field is obscured', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // The second TextField should be the password field
      final passwordField = tester.widget<TextField>(textFields.at(1));
      expect(passwordField.obscureText, true);
    });

    testWidgets('username field is not obscured', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      final textFields = find.byType(TextField);
      final usernameField = tester.widget<TextField>(textFields.at(0));
      expect(usernameField.obscureText, false);
    });

    testWidgets('can enter username text', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      final usernameField = find.byType(TextField).first;
      await tester.enterText(usernameField, 'test123');

      expect(find.text('test123'), findsOneWidget);
    });

    testWidgets('can enter password text', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      final passwordField = find.byType(TextField).at(1);
      await tester.enterText(passwordField, 'password123');

      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('username field uses text keyboard type', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      final textFields = find.byType(TextField);
      final usernameField = tester.widget<TextField>(textFields.at(0));
      expect(usernameField.keyboardType, TextInputType.text);
    });

    testWidgets('has proper layout structure', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('displays with proper spacing', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: SignInScreen()));

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('forgot password link opens forgot password screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignInScreen()));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });
}
