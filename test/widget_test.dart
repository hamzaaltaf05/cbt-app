// Smoke test: renders the app's authentication entry point (the login screen)
// and verifies the core form is built. We pump LoginScreen directly — rather
// than MyApp — so the test has no dependency on a live Supabase session or
// network, keeping it fast and deterministic under `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cbt_app/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders its authentication form',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // The sign-in heading appears in the app bar and on the submit button.
    expect(find.text('Sign In'), findsWidgets);

    // Email and password fields are present in the default sign-in mode.
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Core input affordances.
    expect(find.byIcon(Icons.email), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    // The toggle to switch between sign-in and sign-up.
    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });
}
