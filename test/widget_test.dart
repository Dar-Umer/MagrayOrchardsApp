import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:magray_orchards/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MagrayOrchardsApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
