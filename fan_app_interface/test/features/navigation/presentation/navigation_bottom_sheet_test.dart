import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fan_app_interface/l10n/app_localizations.dart';
import 'package:fan_app_interface/features/map/data/models/poi_model.dart';
import 'package:fan_app_interface/features/navigation/presentation/widgets/navigation_bottom_sheet.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: Scaffold(body: child),
  );
}

POIModel _testPoi() => POIModel(
      id: 'poi-1',
      name: 'Test Destination',
      category: 'restroom',
      x: 0,
      y: 0,
      level: 0,
    );

/// Returns the height of the SizedBox that wraps the DecoratedBox — that is
/// the one whose `height` is driven by the height tween (Fix 4). Other
/// SizedBoxes in the tree have null or fixed heights for spacing.
double _animatedHeight(WidgetTester tester) {
  final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
  for (final s in boxes) {
    if (s.height != null && (s.height == 110 ||
        (s.height! > 110 && s.height! < 281))) {
      return s.height!;
    }
  }
  fail('No animated SizedBox found (height in [110..280])');
}

void main() {
  group('NavigationBottomSheet', () {
    testWidgets('renders collapsed content with provided info', (tester) async {
      await tester.pumpWidget(_wrap(
        NavigationBottomSheet(
          arrivalTime: '12:34',
          remainingTime: '5 min',
          remainingDistance: '40 m',
          destination: _testPoi(),
          onEndRoute: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('40 m'), findsOneWidget);
      // Destination label only shown in expanded mode.
      expect(find.text('Test Destination'), findsNothing);
    });

    testWidgets('height tween animates from 110 to 280 on expand',
        (tester) async {
      bool expanded = false;
      await tester.pumpWidget(_wrap(
        NavigationBottomSheet(
          arrivalTime: '12:34',
          remainingTime: '5 min',
          remainingDistance: '40 m',
          destination: _testPoi(),
          onEndRoute: () {},
          onExpansionChanged: (e) => expanded = e,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_animatedHeight(tester), 110);

      // Trigger expansion via the State directly using the public widget API:
      // a vertical drag upward simulates the user pulling the sheet up.
      final sheet = find.byType(NavigationBottomSheet);
      await tester.drag(sheet, const Offset(0, -60));
      await tester.pump(); // start animation

      // Mid-animation height must be strictly between begin and end values —
      // this proves the height tween is actually running (Fix 4 keeps the
      // tween as the only thing in the AnimatedBuilder).
      await tester.pump(const Duration(milliseconds: 150));
      final mid = _animatedHeight(tester);
      expect(mid, greaterThan(110));
      expect(mid, lessThan(280));

      await tester.pumpAndSettle();
      expect(_animatedHeight(tester), 280);
      expect(expanded, isTrue);

      // Expanded state must expose destination name.
      expect(find.text('Test Destination'), findsOneWidget);
    });

    testWidgets('decoration container is reused across animation frames '
        '(Fix 4 regression lock: DecoratedBox must live outside the '
        'AnimatedBuilder.builder closure)', (tester) async {
      await tester.pumpWidget(_wrap(
        NavigationBottomSheet(
          arrivalTime: '12:34',
          remainingTime: '5 min',
          remainingDistance: '40 m',
          destination: _testPoi(),
          onEndRoute: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // Capture the DecoratedBox element identity before animation.
      final decoratedBefore = tester.element(find.byType(DecoratedBox).first);

      // Drive the height tween for several frames.
      await tester.drag(find.byType(NavigationBottomSheet), const Offset(0, -60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final decoratedMid = tester.element(find.byType(DecoratedBox).first);
      await tester.pump(const Duration(milliseconds: 50));
      final decoratedLate = tester.element(find.byType(DecoratedBox).first);

      // The Element identity must be preserved frame-to-frame. If a future
      // change pulls DecoratedBox back inside AnimatedBuilder.builder, a new
      // Element would be created every frame and these identities would
      // diverge.
      expect(identical(decoratedBefore, decoratedMid), isTrue,
          reason: 'DecoratedBox Element must be reused across animation frames');
      expect(identical(decoratedMid, decoratedLate), isTrue);

      await tester.pumpAndSettle();
    });
  });
}
