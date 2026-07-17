import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chapter.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiClient,
    required this.chapters,
    required this.initialIndex,
    this.comicTitle,
  });

  final ApiClient apiClient;
  final List<ChapterLite> chapters;
  final int initialIndex;
  final String? comicTitle;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  late Future<ChapterDetail> _futureChapter;
  late int _currentIndex;
  bool _showControls = true;
  double _lastOffset = 0;
  double _progress = 0;

  ChapterLite get _chapter => widget.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex
        .clamp(0, widget.chapters.length - 1)
        .toInt();
    _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
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
      _showControls = true;
      _progress = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
                      return const EmptyState(
                        icon: Icons.broken_image_outlined,
                        message:
                            'No chapter pages were returned by the backend.',
                      );
                    }
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.builder(
                          key: ValueKey(chapter.id),
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 68, bottom: 100),
                          itemCount: chapter.images.length + 1,
                          itemBuilder: (context, index) {
                            if (index == chapter.images.length) {
                              return _ReaderEnd(
                                hasPrevious: _currentIndex > 0,
                                hasNext:
                                    _currentIndex < widget.chapters.length - 1,
                                onPrevious: () =>
                                    _openChapter(_currentIndex - 1),
                                onNext: () => _openChapter(_currentIndex + 1),
                                onBackToTop: _backToTop,
                              );
                            }
                            return Image.network(
                              chapter.images[index],
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
                              filterQuality: FilterQuality.medium,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return AspectRatio(
                                  aspectRatio: 0.68,
                                  child: ColoredBox(
                                    color: tokens.surfaceSubtle,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            progress.expectedTotalBytes == null
                                            ? null
                                            : progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => AspectRatio(
                                aspectRatio: 0.68,
                                child: ColoredBox(
                                  color: tokens.surfaceSubtle,
                                  child: Center(
                                    child: Text(
                                      'Cannot load page ${index + 1}',
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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
                  comicTitle: widget.comicTitle ?? 'ComiVerse Reader',
                  chapter: _chapter,
                  chapters: widget.chapters,
                  currentIndex: _currentIndex,
                  onBack: () => Navigator.pop(context),
                  onChapterSelected: _openChapter,
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
  });

  final String comicTitle;
  final ChapterLite chapter;
  final List<ChapterLite> chapters;
  final int currentIndex;
  final VoidCallback onBack;
  final ValueChanged<int> onChapterSelected;

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
                tooltip: 'Back',
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
                                'Ch. ${chapters[index].chapterNumber}: ${chapters[index].title}',
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
              PopupMenuButton<String>(
                tooltip: 'Reader options',
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'vertical',
                    child: Text('Vertical scroll'),
                  ),
                  PopupMenuItem(value: 'fit', child: Text('Fit to width')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                    label: 'Previous',
                    onTap: hasPrevious ? onPrevious : null,
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Back to top',
                    onPressed: onBackToTop,
                    icon: const Icon(Icons.vertical_align_top_rounded),
                  ),
                  _ReaderControl(
                    icon: Icons.skip_next_rounded,
                    label: 'Next',
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
              'End of chapter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasPrevious ? onPrevious : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: hasNext ? onNext : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: onBackToTop,
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: const Text('Back to Top'),
            ),
          ],
        ),
      ),
    );
  }
}
