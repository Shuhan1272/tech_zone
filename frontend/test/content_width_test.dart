// The grids and the category strip used to measure themselves with a
// LayoutBuilder. That rebuilds their subtree from inside the layout phase,
// and those subtrees are full of InkWells and buttons: when the pointer left
// one during a relayout, MouseTracker called setState on it, LayoutBuilder
// deferred the rebuild to the next frame, and if navigation had removed the
// subtree by then the deferred rebuild landed on detached render objects and
// brought the frame down.
//
// They now compute their width with Responsive.contentWidth instead. These
// tests hold that arithmetic to what PageContainer actually lays out, which
// is the one thing the swap could get wrong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techzone/core/utils/responsive.dart';
import 'package:techzone/widgets/product_card.dart';

/// Lays out a [PageContainer] at [width] and returns both the width its child
/// really receives and the width [Responsive.contentWidth] predicts.
Future<({double actual, double predicted})> _measure(
  WidgetTester tester,
  double width,
) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late double predicted;
  final key = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              predicted = Responsive.contentWidth(context);
              // Fills whatever width PageContainer offers, which is the
              // number under test.
              return PageContainer(
                child: SizedBox(key: key, height: 10, width: double.infinity),
              );
            },
          ),
        ),
      ),
    ),
  );

  return (actual: tester.getSize(find.byKey(key)).width, predicted: predicted);
}

void main() {
  for (final width in <double>[360, 390, 640, 800, 1024, 1280, 1440, 1920]) {
    testWidgets('contentWidth matches PageContainer at ${width.toInt()}px', (
      tester,
    ) async {
      final result = await _measure(tester, width);

      expect(
        result.predicted,
        moreOrLessEquals(result.actual, epsilon: 0.01),
        reason:
            'the grids size themselves from contentWidth, so it has to equal '
            'the width PageContainer really hands them',
      );
    });
  }

  testWidgets('contentWidth stops growing past the content cap', (
    tester,
  ) async {
    final wide = await _measure(tester, 2560);
    expect(
      wide.predicted,
      lessThanOrEqualTo(Responsive.maxContentWidth),
      reason: 'content is capped, however wide the window is',
    );
  });

  testWidgets('the product grid builds without a LayoutBuilder', (
    tester,
  ) async {
    // Structural guard: putting one back here is what brought the frame down.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PageContainer(child: ProductGrid(products: [], columns: 5)),
          ),
        ),
      ),
    );

    expect(find.byType(ProductGrid), findsOneWidget);
    expect(find.byType(LayoutBuilder), findsNothing);
  });
}
