import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magray_orchards/widgets/app_loading_indicator.dart';

void main() {
  group('AppLoadingIndicator Widget & Animation Tests', () {
    testWidgets('renders default orchardGlow loading indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLoadingIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Advance animation frame
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
    });

    testWidgets('renders all 4 animation styles without errors', (tester) async {
      for (final style in LoadingAnimationStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppLoadingIndicator(
                  style: style,
                  size: 40,
                  color: Colors.green,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(AppLoadingIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));
      }
    });

    testWidgets('AppLoadingIndicator.small renders compact size for buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null,
              child: AppLoadingIndicator.small(color: Colors.white),
            ),
          ),
        ),
      );

      final indicator = tester.widget<AppLoadingIndicator>(find.byType(AppLoadingIndicator));
      expect(indicator.size, 18.0);
      expect(indicator.strokeWidth, 2.0);
      expect(indicator.color, Colors.white);
      expect(indicator.showCenterLeaf, false);
    });

    testWidgets('AppLoadingIndicator.large renders with glowing leaf core', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLoadingIndicator.large(color: Colors.green),
            ),
          ),
        ),
      );

      final indicator = tester.widget<AppLoadingIndicator>(find.byType(AppLoadingIndicator));
      expect(indicator.size, 52.0);
      expect(indicator.showCenterLeaf, true);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('dynamic defaultStyle updates globally', (tester) async {
      AppLoadingIndicator.defaultStyle = LoadingAnimationStyle.dualOrbit;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLoadingIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));

      // Reset to recommended default
      AppLoadingIndicator.defaultStyle = LoadingAnimationStyle.orchardGlow;
    });
  });
}
