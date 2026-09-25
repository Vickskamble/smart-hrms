import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pump();
  }

  testWidgets('app boots to the login screen on mobile', (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.text('WorkForce Command'), findsOneWidget);
    expect(find.text('HR Management Platform'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('app renders the desktop branding panel without overflow',
      (tester) async {
    await pumpApp(tester, const Size(1280, 800));

    expect(find.text('WorkForce\nCommand'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}