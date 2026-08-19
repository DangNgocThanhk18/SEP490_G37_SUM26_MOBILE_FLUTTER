import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preloads the next two comic pages without going out of range', () {
    final urls = List.generate(8, (index) => 'page-${index + 1}');

    expect(ReaderImageLoadingPolicy.urlsToPreload(urls, 0), [
      'page-2',
      'page-3',
    ]);
    expect(ReaderImageLoadingPolicy.urlsToPreload(urls, 6), ['page-8']);
    expect(ReaderImageLoadingPolicy.urlsToPreload(urls, 7), isEmpty);
    expect(ReaderImageLoadingPolicy.urlsToPreload(urls, -1), isEmpty);
  });

  test('preloads nearby pages in the active scroll direction first', () {
    final urls = List.generate(10, (index) => 'page-${index + 1}');

    expect(
      ReaderImageLoadingPolicy.urlsAroundPage(urls, 4, movingBackwards: false),
      ['page-6', 'page-7', 'page-4'],
    );
    expect(
      ReaderImageLoadingPolicy.urlsAroundPage(urls, 4, movingBackwards: true),
      ['page-4', 'page-6', 'page-7'],
    );
  });

  test('a zoomed image cache width is promoted once and never downgraded', () {
    const normalWidth = 900;

    final initial = ReaderImageLoadingPolicy.cacheWidthForResolution(
      normalCacheWidth: normalWidth,
      highResolutionRequested: false,
      wasPromoted: false,
    );
    final zoomed = ReaderImageLoadingPolicy.cacheWidthForResolution(
      normalCacheWidth: normalWidth,
      highResolutionRequested: true,
      wasPromoted: false,
    );
    final fittedAgain = ReaderImageLoadingPolicy.cacheWidthForResolution(
      normalCacheWidth: normalWidth,
      highResolutionRequested: false,
      wasPromoted: true,
    );

    expect(initial, normalWidth);
    expect(zoomed, 1800);
    expect(fittedAgain, zoomed);
    expect(
      ReaderImageLoadingPolicy.cacheWidthForResolution(
        normalCacheWidth: 1400,
        highResolutionRequested: true,
        wasPromoted: false,
      ),
      2048,
    );
  });

  test('zoom policy clamps scale and snaps near-fit values back to 1x', () {
    expect(ReaderZoomPolicy.clampScale(0.4), 1);
    expect(ReaderZoomPolicy.clampScale(2.8), 2.8);
    expect(ReaderZoomPolicy.clampScale(8), 4);
    expect(ReaderZoomPolicy.shouldAutoFit(1.1), isTrue);
    expect(ReaderZoomPolicy.shouldAutoFit(1.2), isFalse);
  });

  testWidgets('one transform scales every visible comic page fragment', (
    tester,
  ) async {
    final scrollController = ScrollController(initialScrollOffset: 100);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 400,
            child: ReaderZoomSurface(
              resetGeneration: 0,
              onScrollLockChanged: (_) {},
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: const [
                  SizedBox(
                    key: ValueKey('comic-page-1'),
                    height: 200,
                    child: ColoredBox(color: Colors.red),
                  ),
                  SizedBox(
                    key: ValueKey('comic-page-2'),
                    height: 200,
                    child: ColoredBox(color: Colors.green),
                  ),
                  SizedBox(
                    key: ValueKey('comic-page-3'),
                    height: 200,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byType(ReaderZoomSurface);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();

    final firstRect = tester.getRect(
      find.byKey(const ValueKey('comic-page-1')),
    );
    final secondRect = tester.getRect(
      find.byKey(const ValueKey('comic-page-2')),
    );
    final thirdRect = tester.getRect(
      find.byKey(const ValueKey('comic-page-3')),
    );
    final expectedHeight = 200 * ReaderZoomPolicy.doubleTapScale;
    expect(firstRect.height, closeTo(expectedHeight, 0.01));
    expect(secondRect.height, closeTo(expectedHeight, 0.01));
    expect(thirdRect.height, closeTo(expectedHeight, 0.01));
    expect(firstRect.bottom, closeTo(secondRect.top, 0.01));
    expect(secondRect.bottom, closeTo(thirdRect.top, 0.01));
    expect(scrollController.offset, closeTo(100, 0.01));
  });

  testWidgets('double tap zooms the reader and Fit Width resets it', (
    tester,
  ) async {
    var resetGeneration = 0;
    var scrollLocked = false;

    Widget app() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            height: 320,
            child: ReaderZoomSurface(
              resetGeneration: resetGeneration,
              onScrollLockChanged: (locked) => scrollLocked = locked,
              child: const ColoredBox(color: Colors.purple),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app());
    final surface = find.byType(ReaderZoomSurface);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();

    var transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(
      transform.transform.getMaxScaleOnAxis(),
      closeTo(ReaderZoomPolicy.doubleTapScale, 0.01),
    );
    expect(scrollLocked, isTrue);

    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();
    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(scrollLocked, isFalse);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(scrollLocked, isTrue);

    resetGeneration++;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(scrollLocked, isFalse);
  });

  testWidgets('two-finger pinch zooms without exceeding the 4x limit', (
    tester,
  ) async {
    var scrollLocked = false;
    var highResolutionRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 320,
              child: ReaderZoomSurface(
                resetGeneration: 0,
                onScrollLockChanged: (locked) => scrollLocked = locked,
                onHighResolutionChanged: (requested) {
                  highResolutionRequested = requested;
                },
                child: const ColoredBox(color: Colors.purple),
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ReaderZoomSurface));
    final firstFinger = await tester.startGesture(
      center - const Offset(24, 0),
      pointer: 1,
    );
    final secondFinger = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 2,
    );
    await firstFinger.moveTo(center - const Offset(180, 0));
    await secondFinger.moveTo(center + const Offset(180, 0));
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(4, 0.01));
    expect(scrollLocked, isTrue);
    expect(highResolutionRequested, isFalse);

    await firstFinger.up();
    await secondFinger.up();
    await tester.pump();
    expect(highResolutionRequested, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('pinching back near 1x automatically restores Fit Width', (
    tester,
  ) async {
    var scrollLocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 320,
              child: ReaderZoomSurface(
                resetGeneration: 0,
                onScrollLockChanged: (locked) => scrollLocked = locked,
                child: const ColoredBox(color: Colors.purple),
              ),
            ),
          ),
        ),
      ),
    );

    final surface = find.byType(ReaderZoomSurface);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(scrollLocked, isTrue);

    final center = tester.getCenter(surface);
    final firstFinger = await tester.startGesture(
      center - const Offset(60, 0),
      pointer: 3,
    );
    final secondFinger = await tester.startGesture(
      center + const Offset(60, 0),
      pointer: 4,
    );
    await firstFinger.moveTo(center - const Offset(26, 0));
    await secondFinger.moveTo(center + const Offset(26, 0));
    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(scrollLocked, isFalse);
  });

  testWidgets('one finger scrolls at 1x but pans only the reader when zoomed', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var scrollLocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ReaderZoomSurface(
            resetGeneration: 0,
            onScrollLockChanged: (locked) {
              setState(() => scrollLocked = locked);
            },
            child: ListView(
              controller: scrollController,
              physics: scrollLocked
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: const [
                SizedBox(height: 500, child: ColoredBox(color: Colors.purple)),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );

    final surface = find.byType(ReaderZoomSurface);
    await tester.drag(surface, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(0));
    expect(scrollLocked, isFalse);

    scrollController.jumpTo(0);
    await tester.pump();
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(scrollLocked, isTrue);

    final offsetBeforePan = scrollController.offset;
    await tester.drag(surface, const Offset(0, -180));
    await tester.pump();
    expect(scrollController.offset, closeTo(offsetBeforePan, 0.01));
    expect(scrollLocked, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('trackpad pinch zooms the page on Web and desktop', (
    tester,
  ) async {
    var scrollLocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 320,
            child: ReaderZoomSurface(
              resetGeneration: 0,
              onScrollLockChanged: (locked) => scrollLocked = locked,
              child: const ColoredBox(color: Colors.purple),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ReaderZoomSurface));
    final pointer = TestPointer(7, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(center));
    await tester.sendEventToBinding(pointer.panZoomUpdate(center, scale: 2));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(2, 0.01));
    expect(scrollLocked, isTrue);

    final zoomOutPointer = TestPointer(8, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(zoomOutPointer.panZoomStart(center));
    await tester.sendEventToBinding(
      zoomOutPointer.panZoomUpdate(center, scale: 0.54),
    );
    await tester.sendEventToBinding(zoomOutPointer.panZoomEnd());
    await tester.pumpAndSettle();

    final fittedTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(fittedTransform.transform.getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(scrollLocked, isFalse);
  });

  testWidgets('panning a zoomed page never exposes blank space', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 320,
            child: ReaderZoomSurface(
              resetGeneration: 0,
              onScrollLockChanged: (_) {},
              child: const ColoredBox(color: Colors.purple),
            ),
          ),
        ),
      ),
    );

    final surface = find.byType(ReaderZoomSurface);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();

    await tester.drag(surface, const Offset(1000, 1000));
    await tester.pump();
    var transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.storage[12], closeTo(0, 0.01));
    expect(transform.transform.storage[13], closeTo(0, 0.01));

    await tester.drag(surface, const Offset(-1000, -1000));
    await tester.pump();
    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    final scale = ReaderZoomPolicy.doubleTapScale;
    expect(transform.transform.storage[12], closeTo(240 * (1 - scale), 0.01));
    expect(transform.transform.storage[13], closeTo(320 * (1 - scale), 0.01));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('viewport resize resets a zoomed page to Fit Width', (
    tester,
  ) async {
    var width = 240.0;
    var scrollLocked = false;

    Widget app() => MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          height: 320,
          child: ReaderZoomSurface(
            key: const ValueKey('resizable-reader-page'),
            resetGeneration: 0,
            onScrollLockChanged: (locked) => scrollLocked = locked,
            child: const ColoredBox(color: Colors.purple),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app());
    final surface = find.byType(ReaderZoomSurface);
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(scrollLocked, isTrue);

    width = 300;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1, 0.01));
    expect(scrollLocked, isFalse);
  });

  testWidgets('two-finger pinch locks vertical reader scrolling', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var scrollLocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ReaderZoomSurface(
            resetGeneration: 0,
            onScrollLockChanged: (locked) {
              setState(() => scrollLocked = locked);
            },
            child: ListView(
              controller: scrollController,
              physics: scrollLocked
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: const [
                SizedBox(height: 500, child: ColoredBox(color: Colors.purple)),
                SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ReaderZoomSurface));
    final firstFinger = await tester.startGesture(
      center - const Offset(24, 0),
      pointer: 11,
    );
    final secondFinger = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 12,
    );
    await tester.pump();
    expect(scrollLocked, isTrue);
    final lockedOffset = scrollController.offset;

    await firstFinger.moveTo(center - const Offset(100, 80));
    await secondFinger.moveTo(center + const Offset(100, 80));
    await tester.pump();
    expect(scrollController.offset, closeTo(lockedOffset, 0.01));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('reader-zoom-transform')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1));

    await firstFinger.up();
    await secondFinger.up();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a second finger stops a reader drag already in progress', (
    tester,
  ) async {
    final scrollController = ScrollController();
    ScrollHoldController? holdController;
    addTearDown(() {
      holdController?.cancel();
      scrollController.dispose();
    });
    var scrollLocked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => ReaderZoomSurface(
            resetGeneration: 0,
            onScrollLockChanged: (locked) {
              if (locked && scrollController.hasClients) {
                holdController?.cancel();
                holdController = scrollController.position.hold(() {
                  holdController = null;
                });
              } else if (!locked) {
                holdController?.cancel();
                holdController = null;
              }
              setState(() => scrollLocked = locked);
            },
            child: ListView(
              controller: scrollController,
              physics: scrollLocked
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: const [SizedBox(height: 1600)],
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ReaderZoomSurface));
    final firstFinger = await tester.startGesture(center, pointer: 21);
    await firstFinger.moveTo(center - const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 16));
    await firstFinger.moveTo(center - const Offset(0, 100));
    await tester.pump();
    expect(scrollController.offset, greaterThan(0));

    final secondFinger = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 22,
    );
    await tester.pump();
    expect(scrollLocked, isTrue);
    final lockedOffset = scrollController.offset;

    await firstFinger.moveTo(center - const Offset(80, 100));
    await secondFinger.moveTo(center + const Offset(80, 0));
    await tester.pump();
    expect(scrollController.offset, closeTo(lockedOffset, 0.01));

    await firstFinger.up();
    await secondFinger.up();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
