import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/chapter.dart';
import '../services/api_client.dart';
import '../services/app_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiClient,
    required this.chapters,
    required this.initialIndex,
    this.comicTitle,
    this.initialLanguage,
    this.preferences,
  });

  final ApiClient apiClient;
  final List<ChapterLite> chapters;
  final int initialIndex;
  final String? comicTitle;
  final String? initialLanguage;
  final AppPreferences? preferences;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  late Future<ChapterDetail> _futureChapter;
  late Future<List<ChapterTranslation>> _futureTranslations;
  late int _currentIndex;
  bool _showControls = true;
  double _lastOffset = 0;
  double _progress = 0;
  late String? _selectedLanguage; // null = original (no bubble overlay)

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
  }

  @override
  void dispose() {
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
    if (delta > 10 && _showControls) {
      setState(() => _showControls = false);
    } else if (delta < -10 && !_showControls) {
      setState(() => _showControls = true);
    } else if ((nextProgress - _progress).abs() > 0.01) {
      setState(() => _progress = nextProgress);
    }
    _lastOffset = offset;
  }

  void _openChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _currentIndex = index;
      _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
      _futureTranslations = widget.apiClient.getChapterTranslations(
        _chapter.id,
      );
      _showControls = true;
      _progress = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Persist language khi user đổi trong reader; cũng notify detail screen
  /// khi pop qua _restoreReadingLanguage().
  void _onLanguageSelected(String? lang) {
    setState(() => _selectedLanguage = lang);
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

  Future<void> _backToTop() async {
    if (!_scrollController.hasClients) return;
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: tokens.readerBackground,
        systemNavigationBarColor: tokens.readerBackground,
      ),
      child: Scaffold(
        backgroundColor: tokens.readerBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _showControls = !_showControls),
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
                            child: ListView.builder(
                              key: ValueKey(
                                '${chapter.id}-${_selectedLanguage ?? 'original'}',
                              ),
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                top: 68,
                                bottom: 100,
                              ),
                              itemCount: chapter.images.length + 1,
                              itemBuilder: (context, index) {
                                if (index == chapter.images.length) {
                                  return _ReaderEnd(
                                    hasPrevious: _currentIndex > 0,
                                    hasNext:
                                    _currentIndex <
                                        widget.chapters.length - 1,
                                    onPrevious: () =>
                                        _openChapter(_currentIndex - 1),
                                    onNext: () =>
                                        _openChapter(_currentIndex + 1),
                                    onBackToTop: _backToTop,
                                  );
                                }
                                final bubbles =
                                    activeTranslation?.bubblesForPage(
                                      index + 1,
                                    ) ??
                                        const <BubbleSelection>[];
                                return _BubbleOverlayImage(
                                  imageUrl: chapter.images[index],
                                  bubbles: bubbles,
                                  placeholderColor: tokens.surfaceSubtle,
                                  errorLabel: context.tr(
                                    'Cannot load page {page}',
                                    values: {'page': index + 1},
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
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
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                bottom: _showControls ? 0 : -120,
                left: 0,
                right: 0,
                child: _ReaderBottomBar(
                  progress: _progress,
                  hasPrevious: _currentIndex > 0,
                  hasNext: _currentIndex < widget.chapters.length - 1,
                  onPrevious: () => _openChapter(_currentIndex - 1),
                  onNext: () => _openChapter(_currentIndex + 1),
                  onBackToTop: _backToTop,
                ),
              ),
            ],
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
                  final languages = translations.map((t) => t.languageCode).toList();
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
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'vertical',
                            child: Text(context.tr('Vertical scroll')),
                          ),
                          PopupMenuItem(
                            value: 'fit',
                            child: Text(context.tr('Fit to width')),
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
  });

  final double progress;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackToTop;

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
                  IconButton.filledTonal(
                    tooltip: context.tr('Back to top'),
                    onPressed: onBackToTop,
                    icon: const Icon(Icons.vertical_align_top_rounded),
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
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
  });

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackToTop;

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
    required this.imageUrl,
    required this.bubbles,
    required this.placeholderColor,
    required this.errorLabel,
  });

  final String imageUrl;
  final List<BubbleSelection> bubbles;
  final Color placeholderColor;
  final String errorLabel;

  @override
  State<_BubbleOverlayImage> createState() => _BubbleOverlayImageState();
}

class _BubbleOverlayImageState extends State<_BubbleOverlayImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _BubbleOverlayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = null;
      _hasError = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
          (info, _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h > 0) {
          setState(() => _aspectRatio = w / h);
        }
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _hasError = true);
      },
    );
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
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

    return Positioned(left: left, top: top, width: w, height: h, child: content);
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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