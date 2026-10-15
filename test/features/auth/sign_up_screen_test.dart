import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe2eat_ui/features/auth/screens/sign_up_screen.dart';

void main() {
  group('SignUpScreen Widget', () {
    testWidgets('renders the signup form fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Gender'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(InputDecorator, 'Date of Birth'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'City'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        findsOneWidget,
      );
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('username field uses text keyboard type', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      final usernameField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Username'),
          matching: find.byType(TextField),
        ),
      );

      expect(usernameField.keyboardType, TextInputType.text);
    });

    testWidgets('password fields are obscured by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      final passwordField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(TextField),
        ),
      );
      final confirmPasswordField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Confirm Password'),
          matching: find.byType(TextField),
        ),
      );

      expect(passwordField.obscureText, true);
      expect(confirmPasswordField.obscureText, true);
    });

    testWidgets('allows entering name and username', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'jane123',
      );

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('jane123'), findsOneWidget);
    });

    testWidgets(
      'shows validation errors for missing gender and date of birth',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'),
          'Jane Doe',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Username'),
          'jane123',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Singapore').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'Password123!',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'Password123!',
        );

        await tester.ensureVisible(find.text('Sign Up'));
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();

        expect(find.text('Please select your gender'), findsOneWidget);
        expect(find.text('Please select your date of birth'), findsOneWidget);
      },
    );

    testWidgets('selecting date of birth does not validate untouched fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      final dateOfBirthField = find
          .widgetWithText(InputDecorator, 'Select your date of birth')
          .last;
      await tester.ensureVisible(dateOfBirthField);
      await tester.tap(dateOfBirthField);
      await tester.pumpAndSettle();

      final today = DateTime.now();
      await tester.tap(find.text('${today.day}').last);
      await tester.pumpAndSettle();

      expect(find.text('Please select a city'), findsNothing);
      expect(find.text('Password is required'), findsNothing);
      expect(find.text('Please confirm your password'), findsNothing);
    });

    testWidgets('selecting a city clears its validation error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a city'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Singapore').last);
      await tester.pumpAndSettle();

      expect(find.text('Please select a city'), findsNothing);
    });
  });
}
