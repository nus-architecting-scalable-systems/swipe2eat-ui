import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launches to sign-in and supports basic auth navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
  });
}
