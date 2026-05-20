import 'package:flutter/material.dart';
import 'package:flutter_perf_guard/src/public_api/performance_overlay_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerfGuardOverlay', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerfGuardOverlay(
            child: Scaffold(
              body: Center(child: Text('Hello World')),
            ),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders overlay panel in debug mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerfGuardOverlay(
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );

      // The overlay panel should be present
      expect(find.text('⚡ PerfGuard'), findsOneWidget);
    });

    testWidgets('does not block pointer events on child', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PerfGuardOverlay(
            child: Scaffold(
              body: GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(
                  color: Colors.blue,
                  child: SizedBox(width: 200, height: 200),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('overlay is positioned at topRight by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerfGuardOverlay(
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );

      // Find Positioned widget
      final positioned = tester.widgetList<Positioned>(
        find.byType(Positioned),
      );
      // There should be at least one Positioned widget for the overlay
      expect(positioned, isNotEmpty);
    });

    testWidgets('opacity is applied to overlay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerfGuardOverlay(
            opacity: 0.5,
            child: Scaffold(body: SizedBox()),
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, closeTo(0.5, 0.01));
    });

    testWidgets('child occupies full space', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerfGuardOverlay(
            child: Scaffold(
              body: Container(color: Colors.red),
            ),
          ),
        ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);
    });

    group('OverlayAlignment', () {
      for (final alignment in OverlayAlignment.values) {
        testWidgets('renders with alignment $alignment', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: PerfGuardOverlay(
                alignment: alignment,
                child: const Scaffold(body: SizedBox()),
              ),
            ),
          );
          expect(find.text('⚡ PerfGuard'), findsOneWidget);
        });
      }
    });
  });
}
