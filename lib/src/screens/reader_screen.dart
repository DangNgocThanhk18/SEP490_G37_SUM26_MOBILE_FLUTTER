import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/chapter.dart';
import '../models/content_comment.dart';
import '../services/api_client.dart';
import '../services/app_preferences.dart';
import '../services/screen_capture_protection.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/content_comment_section.dart';
import '../widgets/in_app_notification.dart';
import 'premium_screen.dart';

abstract final class ReaderImageLoadingPolicy {
  static const int preloadAheadCount = 4;
  static const int preloadBehindCount = 2;
  static const int preloadAnchorStep = 2;

  static List<String> urlsToPreload(List<String> urls, int pageIndex) {
    if (urls.isEmpty || pageIndex < 0 || pageIndex >= urls.length) {
      return const [];
    }
    final result = <String>[];
    for (
      var index = pageIndex + 1;
      index < urls.length && result.length < preloadAheadCount;
      index++
    ) {
      result.add(urls[index]);
    }
    return result;
  }

  /// Keeps both scroll directions warm without retaining an entire chapter in
  /// decoded memory. Forward pages are prioritised while reading down; pages
  /// above the viewport are prioritised when the user scrolls back.
  static List<String> urlsAroundPage(
    List<String> urls,
    int pageIndex, {
    required bool movingBackwards,
  }) {
    if (urls.isEmpty || pageIndex < 0 || pageIndex >= urls.length) {
      return const [];
    }

    final ahead = urlsToPreload(urls, pageIndex);
    final behind = <String>[];
    for (
      var index = pageIndex - 1;
      index >= 0 && behind.length < preloadBehindCount;
      index--
    ) {
      behind.add(urls[index]);
    }
    return movingBackwards ? [...behind, ...ahead] : [...ahead, ...behind];
  }

  /// Once a visible page has been promoted for zoom, keep using that decoded
  /// variant. Downgrading on every Fit Width caused a second provider/cache key
  /// to replace the image and made repeated zooms appear to reload the page.
  static int cacheWidthForResolution({
    required int normalCacheWidth,
    required bool highResolutionRequested,
    required bool wasPromoted,
  }) {
    if (!highResolutionRequested && !wasPromoted) return normalCacheWidth;
    return (normalCacheWidth * 2).clamp(normalCacheWidth, 2048);
  }
}

@visibleForTesting
String? maskReaderWatermarkIdentifier(String? identifier) {
  final value = identifier?.trim();
  if (value == null || value.isEmpty) return null;

  final atIndex = value.lastIndexOf('@');
  if (atIndex > 0 && atIndex < value.length - 1) {
    final localPart = value.substring(0, atIndex);
    final domain = value.substring(atIndex + 1);
    return '${_maskReaderIdentityPart(localPart)}@$domain';
  }
  return _maskReaderIdentityPart(value);
}

String _maskReaderIdentityPart(String value) {
  final visibleLength = value.length >= 3 ? 3 : 1;
  return '${value.substring(0, visibleLength)}***';
}

@visibleForTesting
bool shouldShowReaderWatermark({required TargetPlatform platform}) =>
    platform == TargetPlatform.iOS;

bool get _shouldShowReaderWatermark =>
    shouldShowReaderWatermark(platform: defaultTargetPlatform);

abstract final class ReaderZoomPolicy {
  static const double minScale = 1;
  static const double maxScale = 4;
  static const double doubleTapScale = 2.5;
  static const double autoFitThreshold = 1.12;
  static const double highResolutionThreshold = 1.35;

  static double clampScale(double scale) =>
      scale.clamp(minScale, maxScale).toDouble();

  static bool shouldAutoFit(double scale) => scale <= autoFitThreshold;
}

class ReaderZoomSurface extends StatefulWidget {
  const ReaderZoomSurface({
    super.key,
    required this.child,
    required this.resetGeneration,
    required this.onScrollLockChanged,
    this.onHighResolutionChanged,
  });

  final Widget child;
  final int resetGeneration;
  final ValueChanged<bool> onScrollLockChanged;
  final ValueChanged<bool>? onHighResolutionChanged;

  @override
  State<ReaderZoomSurface> createState() => _ReaderZoomSurfaceState();
}

class _ReaderZoomSurfaceState extends State<ReaderZoomSurface>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  final Map<int, Offset> _pointers = {};
  late final AnimationController _animationController;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _translationAnimation;
  Size _viewportSize = Size.zero;
  double _scale = ReaderZoomPolicy.minScale;
  Offset _translation = Offset.zero;
  double? _pinchStartDistance;
  double? _pinchStartScale;
  Offset? _pinchSceneFocalPoint;
  Offset? _doubleTapPosition;
  double? _panZoomStartScale;
  Offset? _panZoomSceneFocalPoint;
  bool _scrollLocked = false;
  bool _highResolutionRequested = false;
  bool _viewportResetScheduled = false;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 220),
          )
          ..addListener(_handleAnimationTick)
          ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant ReaderZoomSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetGeneration != widget.resetGeneration) {
      _animateToFit();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleAnimationTick() {
    final scaleAnimation = _scaleAnimation;
    final translationAnimation = _translationAnimation;
    if (scaleAnimation == null || translationAnimation == null) return;
    _setTransform(
      scaleAnimation.value,
      translationAnimation.value,
      notifyScrollLock: false,
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _notifyScrollLock(_scale > ReaderZoomPolicy.minScale + 0.001);
    _notifyHighResolution(_scale >= ReaderZoomPolicy.highResolutionThreshold);
  }

  void _setTransform(
    double scale,
    Offset translation, {
    bool notifyScrollLock = true,
  }) {
    _scale = ReaderZoomPolicy.clampScale(scale);
    _translation = _clampTranslation(translation, _scale);
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(_translation.dx, _translation.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1);
    if (notifyScrollLock) {
      _notifyScrollLock(_scale > ReaderZoomPolicy.minScale + 0.001);
    }
  }

  Offset _clampTranslation(Offset translation, double scale) {
    if (_viewportSize.isEmpty || scale <= ReaderZoomPolicy.minScale) {
      return Offset.zero;
    }
    final minX = _viewportSize.width * (1 - scale);
    final minY = _viewportSize.height * (1 - scale);
    return Offset(
      translation.dx.clamp(minX, 0).toDouble(),
      translation.dy.clamp(minY, 0).toDouble(),
    );
  }

  void _notifyScrollLock(bool locked) {
    if (_scrollLocked == locked) return;
    _scrollLocked = locked;
    widget.onScrollLockChanged(locked);
  }

  void _notifyHighResolution(bool requested) {
    if (_highResolutionRequested == requested) return;
    _highResolutionRequested = requested;
    widget.onHighResolutionChanged?.call(requested);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _animationController.stop();
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length >= 2) {
      _beginPinch();
      _notifyScrollLock(true);
    }
  }

  void _beginPinch() {
    final points = _pointers.values.take(2).toList(growable: false);
    if (points.length < 2) return;
    final focalPoint = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    _pinchStartDistance = (points[0] - points[1]).distance.clamp(
      1,
      double.infinity,
    );
    _pinchStartScale = _scale;
    _pinchSceneFocalPoint = Offset(
      (focalPoint.dx - _translation.dx) / _scale,
      (focalPoint.dy - _translation.dy) / _scale,
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final previousPosition = _pointers[event.pointer];
    if (previousPosition == null) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2 &&
        _pinchStartDistance != null &&
        _pinchStartScale != null &&
        _pinchSceneFocalPoint != null) {
      final points = _pointers.values.take(2).toList(growable: false);
      final distance = (points[0] - points[1]).distance;
      final focalPoint = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
      final nextScale = ReaderZoomPolicy.clampScale(
        _pinchStartScale! * distance / _pinchStartDistance!,
      );
      final sceneFocalPoint = _pinchSceneFocalPoint!;
      _setTransform(
        nextScale,
        Offset(
          focalPoint.dx - sceneFocalPoint.dx * nextScale,
          focalPoint.dy - sceneFocalPoint.dy * nextScale,
        ),
        notifyScrollLock: false,
      );
      _notifyScrollLock(true);
      return;
    }

    if (_pointers.length == 1 && _scale > ReaderZoomPolicy.minScale + 0.001) {
      _setTransform(
        _scale,
        _translation + event.localPosition - previousPosition,
      );
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    final wasPinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (wasPinching) {
      _pinchStartDistance = null;
      _pinchStartScale = null;
      _pinchSceneFocalPoint = null;
      if (_pointers.length >= 2) _beginPinch();
    }

    if (_pointers.isNotEmpty) {
      _notifyScrollLock(true);
      return;
    }

    if (_scrollLocked && ReaderZoomPolicy.shouldAutoFit(_scale)) {
      _animateToFit();
    } else if (_scale > ReaderZoomPolicy.minScale + 0.001) {
      _notifyScrollLock(true);
      _notifyHighResolution(_scale >= ReaderZoomPolicy.highResolutionThreshold);
    }
  }

  void _handleDoubleTap() {
    if (_scale > ReaderZoomPolicy.minScale + 0.001) {
      _animateToFit();
      return;
    }
    final focalPoint = _doubleTapPosition ?? _viewportSize.center(Offset.zero);
    final targetScale = ReaderZoomPolicy.doubleTapScale;
    _notifyScrollLock(true);
    _animateTo(
      targetScale,
      Offset(
        focalPoint.dx - focalPoint.dx * targetScale,
        focalPoint.dy - focalPoint.dy * targetScale,
      ),
    );
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _animationController.stop();
    _panZoomStartScale = _scale;
    _panZoomSceneFocalPoint = Offset(
      (event.localPosition.dx - _translation.dx) / _scale,
      (event.localPosition.dy - _translation.dy) / _scale,
    );
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final startScale = _panZoomStartScale;
    final sceneFocalPoint = _panZoomSceneFocalPoint;
    if (startScale == null || sceneFocalPoint == null) return;
    final isScaleGesture = (event.scale - 1).abs() > 0.001;
    if (!isScaleGesture && _scale <= ReaderZoomPolicy.minScale + 0.001) {
      return;
    }

    final nextScale = ReaderZoomPolicy.clampScale(startScale * event.scale);
    final focalPoint = event.localPosition + event.localPan;
    _setTransform(
      nextScale,
      Offset(
        focalPoint.dx - sceneFocalPoint.dx * nextScale,
        focalPoint.dy - sceneFocalPoint.dy * nextScale,
      ),
      notifyScrollLock: false,
    );
    _notifyScrollLock(true);
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomStartScale = null;
    _panZoomSceneFocalPoint = null;
    if (_scrollLocked && ReaderZoomPolicy.shouldAutoFit(_scale)) {
      _animateToFit();
    } else {
      _notifyHighResolution(_scale >= ReaderZoomPolicy.highResolutionThreshold);
    }
  }

  void _animateToFit() {
    _notifyHighResolution(false);
    _animateTo(ReaderZoomPolicy.minScale, Offset.zero);
  }

  void _animateTo(double targetScale, Offset targetTranslation) {
    _animationController.stop();
    final curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: _scale,
      end: ReaderZoomPolicy.clampScale(targetScale),
    ).animate(curvedAnimation);
    _translationAnimation = Tween<Offset>(
      begin: _translation,
      end: _clampTranslation(targetTranslation, targetScale),
    ).animate(curvedAnimation);
    _animationController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nextViewportSize = constraints.biggest;
        if (_viewportSize != Size.zero &&
            _viewportSize != nextViewportSize &&
            _scale > ReaderZoomPolicy.minScale + 0.001 &&
            !_viewportResetScheduled) {
          _viewportResetScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _viewportResetScheduled = false;
            if (mounted) _animateToFit();
          });
        }
        _viewportSize = nextViewportSize;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              _doubleTapPosition = details.localPosition;
            },
            onDoubleTap: _handleDoubleTap,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerEnd,
              onPointerCancel: _handlePointerEnd,
              onPointerPanZoomStart: _handlePanZoomStart,
              onPointerPanZoomUpdate: _handlePanZoomUpdate,
              onPointerPanZoomEnd: _handlePanZoomEnd,
              child: AnimatedBuilder(
                animation: _transformationController,
                child: widget.child,
                builder: (context, child) => Transform(
                  key: const ValueKey('reader-zoom-transform'),
                  transform: _transformationController.value,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiClient,
    required this.chapters,
    required this.initialIndex,
    this.comicTitle,
    this.initialLanguage,
    this.preferences,
    this.viewerIdentifier,
  });

  final ApiClient apiClient;
  final List<ChapterLite> chapters;
  final int initialIndex;
  final String? comicTitle;
  final String? initialLanguage;
  final AppPreferences? preferences;
  final String? viewerIdentifier;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> _controlsVisibleNotifier = ValueNotifier<bool>(
    true,
  );
  late Future<ChapterDetail> _futureChapter;
  late Future<List<ChapterTranslation>> _futureTranslations;
  late int _currentIndex;
  double _lastOffset = 0;
  final Set<String> _activeImagePreloads = {};
  final Map<String, double> _pageAspectRatios = {};
  Set<int> _highResolutionPageIndexes = const {};
  bool _readerGestureLocked = false;
  ScrollHoldController? _scrollHoldController;
  int _zoomResetGeneration = 0;
  int _preloadAnchorPageIndex = -1;
  int _preloadGeneration = 0;
  Future<void> _preloadQueue = Future<void>.value();
  late String? _selectedLanguage; // null = original (no bubble overlay)
  bool _captureProtectionAcquired = false;

  ChapterLite get _chapter => widget.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex
        .clamp(0, widget.chapters.length - 1)
        .toInt();
    _selectedLanguage = widget.initialLanguage;
    _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
    _futureTranslations = widget.apiClient.getChapterTranslations(_chapter.id);
    _scrollController.addListener(_handleScroll);
    _captureProtectionAcquired = true;
    unawaited(ScreenCaptureProtection.acquire());
  }

  @override
  void dispose() {
    _preloadGeneration++;
    _releaseScrollHold();
    if (_captureProtectionAcquired) {
      _captureProtectionAcquired = false;
      unawaited(ScreenCaptureProtection.release());
    }
    _controlsVisibleNotifier.dispose();
    _progressNotifier.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastOffset;
    final max = _scrollController.position.maxScrollExtent;
    final nextProgress = max <= 0 ? 0.0 : (offset / max).clamp(0.0, 1.0);
    if (delta > 10 && _controlsVisibleNotifier.value) {
      _controlsVisibleNotifier.value = false;
    } else if (delta < -10 && !_controlsVisibleNotifier.value) {
      _controlsVisibleNotifier.value = true;
    }
    if ((nextProgress - _progressNotifier.value).abs() > 0.01 ||
        nextProgress == 0 ||
        nextProgress == 1) {
      _progressNotifier.value = nextProgress;
    }
    _lastOffset = offset;
  }

  void _openChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _readerGestureLocked = false;
      _highResolutionPageIndexes = const {};
      _zoomResetGeneration++;
      _currentIndex = index;
      _activeImagePreloads.clear();
      _pageAspectRatios.clear();
      _preloadAnchorPageIndex = -1;
      _preloadGeneration++;
      _preloadQueue = Future<void>.value();
      _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
      _futureTranslations = widget.apiClient.getChapterTranslations(
        _chapter.id,
      );
      _lastOffset = 0;
    });
    _releaseScrollHold();
    _controlsVisibleNotifier.value = true;
    _progressNotifier.value = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _handleReaderZoomLock(bool locked) {
    if (_readerGestureLocked == locked) return;
    if (locked && _scrollController.hasClients) {
      _scrollHoldController?.cancel();
      _scrollHoldController = _scrollController.position.hold(() {
        _scrollHoldController = null;
      });
    }
    setState(() {
      _readerGestureLocked = locked;
    });
    if (locked) _controlsVisibleNotifier.value = false;
    if (!locked) _releaseScrollHold();
  }

  void _releaseScrollHold() {
    final holdController = _scrollHoldController;
    _scrollHoldController = null;
    holdController?.cancel();
  }

  void _handleHighResolutionChanged(bool enabled, List<String> imageUrls) {
    final nextIndexes = enabled
        ? _visiblePageIndexes(imageUrls)
        : const <int>{};
    if (_highResolutionPageIndexes.length == nextIndexes.length &&
        _highResolutionPageIndexes.containsAll(nextIndexes)) {
      return;
    }
    setState(() => _highResolutionPageIndexes = nextIndexes);
  }

  Set<int> _visiblePageIndexes(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const {};
    final screenSize = MediaQuery.sizeOf(context);
    final pageWidth = screenSize.width.clamp(0.0, 680.0);
    final viewportTop = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final viewportBottom = viewportTop + screenSize.height;
    var pageTop = 68.0;
    final result = <int>{};
    for (var index = 0; index < imageUrls.length; index++) {
      final ratio = _pageAspectRatios[imageUrls[index]] ?? 0.68;
      final pageHeight = pageWidth / ratio;
      final pageBottom = pageTop + pageHeight;
      if (pageBottom >= viewportTop && pageTop <= viewportBottom) {
        result.add(index);
      }
      if (pageTop > viewportBottom) break;
      pageTop = pageBottom;
    }
    return result;
  }

  void _resetReaderZoom() {
    setState(() => _zoomResetGeneration++);
  }

  void _preloadNearbyPages(List<String> urls, int pageIndex) {
    final previousAnchor = _preloadAnchorPageIndex;
    if (previousAnchor >= 0 &&
        (pageIndex - previousAnchor).abs() <
            ReaderImageLoadingPolicy.preloadAnchorStep) {
      return;
    }
    final movingBackwards = previousAnchor >= 0 && pageIndex < previousAnchor;
    _preloadAnchorPageIndex = pageIndex;
    final targets = ReaderImageLoadingPolicy.urlsAroundPage(
      urls,
      pageIndex,
      movingBackwards: movingBackwards,
    ).where(_activeImagePreloads.add).toList(growable: false);
    if (targets.isEmpty) return;

    final generation = _preloadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadQueue = _preloadQueue.then(
        (_) => _precachePagesSequentially(targets, generation),
      );
    });
  }

  Future<void> _precachePagesSequentially(
    List<String> urls,
    int generation,
  ) async {
    for (final url in urls) {
      if (!mounted || generation != _preloadGeneration) return;
      try {
        await precacheImage(
          _readerImageProvider(url, context),
          context,
          onError: (_, _) {},
        );
      } catch (_) {
        // Do not permanently mark failures; a later nearby window may retry
        // after connectivity recovers.
      } finally {
        _activeImagePreloads.remove(url);
      }
    }
  }

  /// Persist language khi user đổi trong reader; cũng notify detail screen
  /// khi pop qua _restoreReadingLanguage().
  void _onLanguageSelected(String? lang) {
    setState(() {
      _readerGestureLocked = false;
      _highResolutionPageIndexes = const {};
      _zoomResetGeneration++;
      _selectedLanguage = lang;
    });
    _releaseScrollHold();
    widget.preferences?.writePreferredReadingLanguage(lang).catchError((_) {});
  }

  /// Mở BottomSheet chọn ngôn ngữ đọc — đẹp hơn popup menu.
  void _showLanguageSheet(List<ChapterTranslation> translations) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LanguageBottomSheet(
        translations: translations,
        selectedLanguage: _selectedLanguage,
        onSelected: (lang) {
          Navigator.pop(ctx);
          _onLanguageSelected(lang);
        },
      ),
    );
  }

  void _showChapterComments() {
    _controlsVisibleNotifier.value = true;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, scrollController) => Material(
          color: context.cvColors.surfaceRaised,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(
                          'Chapter {number} discussion',
                          values: {'number': _chapter.chapterNumber},
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Close'),
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ContentCommentSection(
                    apiClient: widget.apiClient,
                    target: ContentCommentTarget.chapter,
                    targetId: _chapter.id,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPremium() async {
    final user = widget.apiClient.currentUser;
    if (user == null) {
      InAppNotifications.show(
        context,
        type: InAppNotificationType.information,
        title: context.tr('Information'),
        message: context.tr('Sign in to upgrade and unlock Premium chapters.'),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(apiClient: widget.apiClient, user: user),
      ),
    );
    if (!mounted) return;
    try {
      await widget.apiClient.getMe();
      if (mounted) {
        setState(() {
          _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
        });
      }
    } catch (_) {
      // Returning to the Reader must remain possible if profile refresh fails.
    }
  }

  Future<void> _backToTop() async {
    if (!_scrollController.hasClients) return;
    if (_readerGestureLocked) {
      _resetReaderZoom();
      await Future<void>.delayed(const Duration(milliseconds: 230));
      if (!mounted || !_scrollController.hasClients) return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.cvColors;
    final isDark = theme.brightness == Brightness.dark;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return PopScope(
      canPop: !_readerGestureLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _readerGestureLocked) _resetReaderZoom();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle.copyWith(
          statusBarColor: tokens.readerBackground,
          systemNavigationBarColor: tokens.readerBackground,
        ),
        child: Scaffold(
          backgroundColor: tokens.readerBackground,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _controlsVisibleNotifier.value =
                !_controlsVisibleNotifier.value,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FutureBuilder<ChapterDetail>(
                    future: _futureChapter,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ApiErrorState(
                          error: snapshot.error!,
                          onRetry: () => setState(
                            () => _futureChapter = widget.apiClient
                                .getChapterDetail(_chapter.id),
                          ),
                        );
                      }
                      final chapter = snapshot.data;
                      if (chapter == null || chapter.images.isEmpty) {
                        final isPremiumLocked =
                            _chapter.isPremium &&
                            !(widget.apiClient.currentUser?.premiumActive ??
                                false);
                        if (isPremiumLocked) {
                          return _PremiumChapterGate(
                            onUpgrade: _openPremium,
                            signedIn: widget.apiClient.hasToken,
                          );
                        }
                        return EmptyState(
                          icon: Icons.broken_image_outlined,
                          message: context.tr(
                            'No chapter pages were returned by the backend.',
                          ),
                        );
                      }
                      return FutureBuilder<List<ChapterTranslation>>(
                        future: _futureTranslations,
                        builder: (context, translationsSnapshot) {
                          final translations =
                              translationsSnapshot.data ??
                              const <ChapterTranslation>[];
                          ChapterTranslation? activeTranslation;
                          if (_selectedLanguage != null) {
                            for (final t in translations) {
                              if (t.languageCode == _selectedLanguage) {
                                activeTranslation = t;
                                break;
                              }
                            }
                          }
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: ReaderZoomSurface(
                                key: ValueKey(
                                  'reader-continuous-zoom-${chapter.id}-${_selectedLanguage ?? 'original'}',
                                ),
                                resetGeneration: _zoomResetGeneration,
                                onScrollLockChanged: _handleReaderZoomLock,
                                onHighResolutionChanged: (enabled) =>
                                    _handleHighResolutionChanged(
                                      enabled,
                                      chapter.images,
                                    ),
                                child: ListView.builder(
                                  key: ValueKey(
                                    '${chapter.id}-${_selectedLanguage ?? 'original'}',
                                  ),
                                  controller: _scrollController,
                                  physics: _readerGestureLocked
                                      ? const NeverScrollableScrollPhysics()
                                      : null,
                                  scrollCacheExtent:
                                      const ScrollCacheExtent.viewport(2),
                                  padding: const EdgeInsets.only(
                                    top: 68,
                                    bottom: 100,
                                  ),
                                  itemCount: chapter.images.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == chapter.images.length) {
                                      return IgnorePointer(
                                        ignoring: _readerGestureLocked,
                                        child: AnimatedOpacity(
                                          opacity: _readerGestureLocked ? 0 : 1,
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          child: _ReaderEnd(
                                            hasPrevious: _currentIndex > 0,
                                            hasNext:
                                                _currentIndex <
                                                widget.chapters.length - 1,
                                            onPrevious: () =>
                                                _openChapter(_currentIndex - 1),
                                            onNext: () =>
                                                _openChapter(_currentIndex + 1),
                                            onBackToTop: _backToTop,
                                            onComments: _showChapterComments,
                                          ),
                                        ),
                                      );
                                    }
                                    final bubbles =
                                        activeTranslation?.bubblesForPage(
                                          index + 1,
                                        ) ??
                                        const <BubbleSelection>[];
                                    final imageUrl = chapter.images[index];
                                    _preloadNearbyPages(chapter.images, index);
                                    return _BubbleOverlayImage(
                                      key: ValueKey(imageUrl),
                                      imageUrl: imageUrl,
                                      bubbles: bubbles,
                                      initialAspectRatio:
                                          _pageAspectRatios[imageUrl],
                                      useHighResolution:
                                          _highResolutionPageIndexes.contains(
                                            index,
                                          ),
                                      onAspectRatioResolved: (ratio) {
                                        _pageAspectRatios[imageUrl] = ratio;
                                      },
                                      placeholderColor: tokens.surfaceSubtle,
                                      errorLabel: context.tr(
                                        'Cannot load page {page}',
                                        values: {'page': index + 1},
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_shouldShowReaderWatermark)
                  Positioned.fill(
                    child: _ReaderCopyrightWatermark(
                      identifier: widget.viewerIdentifier,
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _controlsVisibleNotifier,
                    child: _ReaderTopBar(
                      comicTitle:
                          widget.comicTitle ?? context.tr('ComiVerse Reader'),
                      chapter: _chapter,
                      chapters: widget.chapters,
                      currentIndex: _currentIndex,
                      onBack: () => Navigator.pop(context),
                      onChapterSelected: _openChapter,
                      translationsFuture: _futureTranslations,
                      selectedLanguage: _selectedLanguage,
                      onLanguageSelected: _onLanguageSelected,
                      onShowLanguageSheet: _showLanguageSheet,
                      onFitToWidth: _resetReaderZoom,
                    ),
                    builder: (context, visible, child) => AnimatedSlide(
                      offset: visible ? Offset.zero : const Offset(0, -1.2),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _controlsVisibleNotifier,
                    builder: (context, visible, _) => AnimatedSlide(
                      offset: visible ? Offset.zero : const Offset(0, 1.2),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _progressNotifier,
                        builder: (context, progress, _) => _ReaderBottomBar(
                          progress: progress,
                          hasPrevious: _currentIndex > 0,
                          hasNext: _currentIndex < widget.chapters.length - 1,
                          onPrevious: () => _openChapter(_currentIndex - 1),
                          onNext: () => _openChapter(_currentIndex + 1),
                          onBackToTop: _backToTop,
                          onComments: _showChapterComments,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumChapterGate extends StatelessWidget {
  const _PremiumChapterGate({required this.onUpgrade, required this.signedIn});

  final VoidCallback onUpgrade;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 92, 20, 116),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  context.cvColors.surfaceRaised,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('Premium chapter'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      'Upgrade your plan to unlock this chapter and continue reading.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onUpgrade,
                      icon: Icon(
                        signedIn
                            ? Icons.workspace_premium_rounded
                            : Icons.login_rounded,
                      ),
                      label: Text(
                        context.tr(signedIn ? 'View Premium plans' : 'Sign in'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderCopyrightWatermark extends StatelessWidget {
  const _ReaderCopyrightWatermark({required this.identifier});

  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final maskedIdentifier = maskReaderWatermarkIdentifier(identifier);
    final label = maskedIdentifier == null
        ? '© ComiVerse'
        : '© ComiVerse • $maskedIdentifier';
    const alignments = <Alignment>[
      Alignment(-0.94, -0.68),
      Alignment(0.94, 0),
      Alignment(-0.94, 0.68),
    ];

    return IgnorePointer(
      key: const ValueKey('reader-copyright-watermark'),
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final alignment in alignments)
                      Align(
                        alignment: alignment,
                        child: Transform.rotate(
                          angle: -0.08,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.05),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.35,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  offset: const Offset(0.5, 0.5),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.comicTitle,
    required this.chapter,
    required this.chapters,
    required this.currentIndex,
    required this.onBack,
    required this.onChapterSelected,
    required this.translationsFuture,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.onShowLanguageSheet,
    required this.onFitToWidth,
  });

  final String comicTitle;
  final ChapterLite chapter;
  final List<ChapterLite> chapters;
  final int currentIndex;
  final VoidCallback onBack;
  final ValueChanged<int> onChapterSelected;
  final Future<List<ChapterTranslation>> translationsFuture;
  final String? selectedLanguage;
  final ValueChanged<String?> onLanguageSelected;
  final ValueChanged<List<ChapterTranslation>> onShowLanguageSheet;
  final VoidCallback onFitToWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cvColors.surfaceRaised.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              IconButton(
                tooltip: context.tr('Back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      comicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: currentIndex,
                        isDense: true,
                        isExpanded: true,
                        alignment: Alignment.center,
                        items: [
                          for (var index = 0; index < chapters.length; index++)
                            DropdownMenuItem(
                              value: index,
                              child: Text(
                                context.tr(
                                  'Ch. {number}: {title}',
                                  values: {
                                    'number': chapters[index].chapterNumber,
                                    'title': chapters[index].title,
                                  },
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) onChapterSelected(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Language badge + menu button
              FutureBuilder<List<ChapterTranslation>>(
                future: translationsFuture,
                builder: (context, snapshot) {
                  final translations = snapshot.data ?? const [];
                  final languages = translations
                      .map((t) => t.languageCode)
                      .toList();
                  final hasTranslations = languages.isNotEmpty;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Language badge — hiển thị khi đang chọn bản dịch
                      if (hasTranslations)
                        GestureDetector(
                          onTap: () => onShowLanguageSheet(translations),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selectedLanguage != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate_rounded,
                                  size: 13,
                                  color: selectedLanguage != null
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  selectedLanguage != null
                                      ? _shortLangLabel(selectedLanguage!)
                                      : context.tr('Original'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selectedLanguage != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Popup menu
                      PopupMenuButton<String>(
                        tooltip: context.tr('Reader options'),
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (value) {
                          if (value == 'lang_picker') {
                            onShowLanguageSheet(translations);
                          } else if (value == 'fit') {
                            onFitToWidth();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'vertical',
                            enabled: false,
                            child: Row(
                              children: [
                                const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(context.tr('Vertical scroll')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'fit',
                            child: Row(
                              children: [
                                const Icon(Icons.fit_screen_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(context.tr('Fit to width')),
                              ],
                            ),
                          ),
                          if (hasTranslations) ...[
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'lang_picker',
                              child: Row(
                                children: [
                                  const Icon(Icons.translate_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(context.tr('Reading language')),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortLangLabel(String code) {
    return switch (code.toLowerCase()) {
      'vi' => 'VI',
      'en' => 'EN',
      'jp' || 'ja' => 'JP',
      'ko' => 'KO',
      'zh' => 'ZH',
      'fr' => 'FR',
      'de' => 'DE',
      'es' => 'ES',
      _ => code.toUpperCase(),
    };
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.progress,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onBackToTop,
    required this.onComments,
  });

  final double progress;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackToTop;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cvColors.surfaceRaised.withValues(alpha: 0.97),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress),
            SizedBox(
              height: 88,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ReaderControl(
                    icon: Icons.skip_previous_rounded,
                    label: context.tr('Previous'),
                    onTap: hasPrevious ? onPrevious : null,
                  ),
                  _ReaderControl(
                    icon: Icons.forum_outlined,
                    label: context.tr('Comments'),
                    onTap: onComments,
                  ),
                  _ReaderControl(
                    icon: Icons.vertical_align_top_rounded,
                    label: context.tr('Top'),
                    onTap: onBackToTop,
                  ),
                  _ReaderControl(
                    icon: Icons.skip_next_rounded,
                    label: context.tr('Next'),
                    onTap: hasNext ? onNext : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderControl extends StatelessWidget {
  const _ReaderControl({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: SizedBox(
        width: 72,
        height: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onTap == null ? Theme.of(context).disabledColor : null,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderEnd extends StatelessWidget {
  const _ReaderEnd({
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onBackToTop,
    required this.onComments,
  });

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackToTop;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.cvColors.readerBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
        child: Column(
          children: [
            Text(
              context.tr('End of chapter'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onComments,
                icon: const Icon(Icons.forum_outlined),
                label: Text(context.tr('Join the chapter discussion')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasPrevious ? onPrevious : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(context.tr('Previous')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasNext ? onNext : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(context.tr('Next')),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: onBackToTop,
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: Text(context.tr('Back to Top')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a page image at its correct aspect ratio (so bubble positions
/// don't drift), with an optional translated-bubble overlay drawn on top.
/// Mirrors ComicPageCanvas.jsx on the web: the wrapping box is always
/// sized to the image's real aspect ratio, so percent-based bubble
/// coordinates map 1:1 with no letterboxing.
class _BubbleOverlayImage extends StatefulWidget {
  const _BubbleOverlayImage({
    super.key,
    required this.imageUrl,
    required this.bubbles,
    required this.initialAspectRatio,
    required this.useHighResolution,
    required this.onAspectRatioResolved,
    required this.placeholderColor,
    required this.errorLabel,
  });

  final String imageUrl;
  final List<BubbleSelection> bubbles;
  final double? initialAspectRatio;
  final bool useHighResolution;
  final ValueChanged<double> onAspectRatioResolved;
  final Color placeholderColor;
  final String errorLabel;

  @override
  State<_BubbleOverlayImage> createState() => _BubbleOverlayImageState();
}

class _BubbleOverlayImageState extends State<_BubbleOverlayImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider<Object>? _provider;
  int? _cacheWidth;
  int? _providerCacheWidth;
  double? _aspectRatio;
  bool _hasError = false;
  bool _hasDisplayedImage = false;
  bool _usingHighResolution = false;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.initialAspectRatio;
    _usingHighResolution = widget.useHighResolution;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cacheWidth = _readerImageCacheWidth(context);
    if (_provider == null || cacheWidth != _cacheWidth) {
      _cacheWidth = cacheWidth;
      final targetWidth = ReaderImageLoadingPolicy.cacheWidthForResolution(
        normalCacheWidth: cacheWidth,
        highResolutionRequested: _usingHighResolution,
        wasPromoted: _usingHighResolution,
      );
      _resolveImage(
        CachedNetworkImageProvider(widget.imageUrl, maxWidth: targetWidth),
        targetWidth,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _BubbleOverlayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = widget.initialAspectRatio;
      _hasError = false;
      _hasDisplayedImage = false;
      _usingHighResolution = widget.useHighResolution;
      final cacheWidth = _cacheWidth;
      final targetWidth = cacheWidth == null
          ? null
          : ReaderImageLoadingPolicy.cacheWidthForResolution(
              normalCacheWidth: cacheWidth,
              highResolutionRequested: widget.useHighResolution,
              wasPromoted: false,
            );
      _resolveImage(
        CachedNetworkImageProvider(widget.imageUrl, maxWidth: targetWidth),
        targetWidth,
      );
    } else if (oldWidget.useHighResolution != widget.useHighResolution) {
      _switchImageResolution(widget.useHighResolution);
    }
  }

  void _switchImageResolution(bool useHighResolution) {
    final normalCacheWidth = _cacheWidth;
    if (normalCacheWidth == null) return;
    final targetWidth = ReaderImageLoadingPolicy.cacheWidthForResolution(
      normalCacheWidth: normalCacheWidth,
      highResolutionRequested: useHighResolution,
      wasPromoted: _usingHighResolution,
    );
    final remainsPromoted = useHighResolution || _usingHighResolution;
    if (_providerCacheWidth == targetWidth) {
      _usingHighResolution = remainsPromoted;
      return;
    }

    // Promotion is intentionally monotonic for this mounted page. Keeping the
    // sharper provider avoids a normal -> zoomed -> normal provider swap every
    // time the reader returns to Fit Width.
    _usingHighResolution = remainsPromoted;

    _resolveImage(
      CachedNetworkImageProvider(widget.imageUrl, maxWidth: targetWidth),
      targetWidth,
    );
  }

  void _resolveImage(ImageProvider<Object> provider, int? providerCacheWidth) {
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!mounted || !identical(_provider, provider)) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0) {
          final ratio = w / h;
          widget.onAspectRatioResolved(ratio);
          final ratioChanged =
              _aspectRatio == null || (_aspectRatio! - ratio).abs() > 0.0001;
          if (!ratioChanged) return;
          if (synchronousCall) {
            _aspectRatio = ratio;
          } else {
            setState(() => _aspectRatio = ratio);
          }
        }
      },
      onError: (error, stackTrace) {
        if (!mounted || !identical(_provider, provider)) return;
        final normalCacheWidth = _cacheWidth;
        if (normalCacheWidth != null &&
            providerCacheWidth != normalCacheWidth) {
          setState(() {
            _usingHighResolution = false;
            _resolveImage(
              CachedNetworkImageProvider(
                widget.imageUrl,
                maxWidth: normalCacheWidth,
              ),
              normalCacheWidth,
            );
          });
          return;
        }
        setState(() => _hasError = true);
      },
    );
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _provider = provider;
    _providerCacheWidth = providerCacheWidth;
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: 0.68,
        child: ColoredBox(
          color: widget.placeholderColor,
          child: Center(child: Text(widget.errorLabel)),
        ),
      );
    }
    if (_aspectRatio == null) {
      return AspectRatio(
        aspectRatio: 0.68,
        child: ColoredBox(
          color: widget.placeholderColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _aspectRatio!,
      child: Semantics(
        label: context.tr('Comic page. Pinch or double tap to zoom.'),
        image: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: widget.placeholderColor),
            if (_provider != null)
              Image(
                key: ValueKey('reader-page-image-${widget.imageUrl}'),
                image: _provider!,
                fit: BoxFit.cover,
                filterQuality: _usingHighResolution
                    ? FilterQuality.medium
                    : FilterQuality.low,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    _hasDisplayedImage = true;
                  }
                  // After the first frame, gaplessPlayback retains that frame
                  // while the one-time zoomed variant is decoded. This avoids
                  // flashing a spinner over an already visible comic page.
                  if (_hasDisplayedImage) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            if (widget.bubbles.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      for (final bubble in widget.bubbles)
                        _buildBubble(
                          bubble,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BubbleSelection bubble, double width, double height) {
    final box = bubble.boundingBox;
    final left = box.x / 100 * width;
    final top = box.y / 100 * height;
    final w = box.width / 100 * width;
    final h = box.height / 100 * height;
    // fontSize is stored as a percentage of the page's displayed height.
    final fontSizePx = (bubble.fontSize ?? 1.2) / 100 * height;

    Widget content = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _parseHexColor(bubble.textBgColor) ?? Colors.white,
        borderRadius: BorderRadius.circular(
          bubble.shape == 'ellipse' ? 9999 : 4,
        ),
      ),
      child: Text(
        bubble.translation ?? '',
        textAlign: _parseTextAlign(bubble.textAlign),
        style: TextStyle(
          color: _parseHexColor(bubble.textColor) ?? Colors.black,
          fontSize: fontSizePx > 4 ? fontSizePx : 4,
          fontWeight: bubble.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: bubble.isItalic ? FontStyle.italic : FontStyle.normal,
          height: 1.15,
        ),
      ),
    );

    if (bubble.shape == 'polygon' && bubble.points.length >= 3) {
      content = ClipPath(
        clipper: _PolygonClipper(bubble.points, box),
        child: content,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: content,
    );
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final intValue = int.tryParse(value, radix: 16);
    return intValue == null ? null : Color(intValue);
  }

  TextAlign _parseTextAlign(String? value) {
    switch (value) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }
}

int _readerImageCacheWidth(BuildContext context) {
  final logicalWidth = MediaQuery.sizeOf(context).width.clamp(320.0, 680.0);
  final physicalWidth = logicalWidth * MediaQuery.devicePixelRatioOf(context);
  return physicalWidth.ceil().clamp(480, 2048);
}

ImageProvider<Object> _readerImageProvider(String url, BuildContext context) =>
    CachedNetworkImageProvider(url, maxWidth: _readerImageCacheWidth(context));

/// Clips a bubble's rectangular container down to its actual freeform
/// polygon outline, using the bubble's own points relative to its
/// bounding box (both in percent-of-image space) — mirrors the clip-path
/// trick used in ComicPageCanvas.jsx on the web.
class _PolygonClipper extends CustomClipper<Path> {
  const _PolygonClipper(this.points, this.box);

  final List<BubblePoint> points;
  final BubbleBoundingBox box;

  @override
  Path getClip(Size size) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final relX = box.width > 0 ? (points[i].x - box.x) / box.width : 0.0;
      final relY = box.height > 0 ? (points[i].y - box.y) / box.height : 0.0;
      final dx = relX * size.width;
      final dy = relY * size.height;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PolygonClipper oldClipper) {
    return oldClipper.points != points || oldClipper.box != box;
  }
}

/// Bottom sheet đẹp để chọn ngôn ngữ đọc trong reader.
/// Hiển thị "Original" + danh sách ngôn ngữ dịch có sẵn với emoji cờ.
/// Ngôn ngữ đang chọn được highlight màu primary với checkmark.
class _LanguageBottomSheet extends StatelessWidget {
  const _LanguageBottomSheet({
    required this.translations,
    required this.selectedLanguage,
    required this.onSelected,
  });

  final List<ChapterTranslation> translations;
  final String? selectedLanguage;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.cvColors;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Reading Language'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        context.tr(
                          '{count} translations available',
                          values: {'count': translations.length},
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Original option
          _LanguageOption(
            icon: '📖',
            label: context.tr('Original'),
            sublabel: context.tr('No translation overlay'),
            isSelected: selectedLanguage == null,
            onTap: () => onSelected(null),
          ),
          // Translation options
          for (final t in translations)
            _LanguageOption(
              icon: _langFlag(t.languageCode),
              label: _langLabel(t.languageCode),
              sublabel: '${t.pages.length} ${context.tr('pages translated')}',
              isSelected: selectedLanguage == t.languageCode,
              onTap: () => onSelected(t.languageCode),
            ),
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  String _langFlag(String code) {
    return switch (code.toLowerCase()) {
      'vi' => '🇻🇳',
      'en' => '🇬🇧',
      'jp' || 'ja' => '🇯🇵',
      'ko' => '🇰🇷',
      'zh' => '🇨🇳',
      'fr' => '🇫🇷',
      'de' => '🇩🇪',
      'es' => '🇪🇸',
      _ => '🌐',
    };
  }

  String _langLabel(String code) {
    return switch (code.toLowerCase()) {
      'vi' => 'Tiếng Việt',
      'en' => 'English',
      'jp' || 'ja' => 'Japanese',
      'ko' => 'Korean',
      'zh' => 'Chinese',
      'fr' => 'French',
      'de' => 'German',
      'es' => 'Spanish',
      _ => code.toUpperCase(),
    };
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? scheme.primary : null,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22)
            else
              Icon(
                Icons.radio_button_unchecked_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
