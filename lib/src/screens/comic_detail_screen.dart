import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/content_comment.dart';
import '../services/api_client.dart';
import '../services/app_preferences.dart';
import '../services/offline_download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/content_comment_section.dart';
import '../widgets/in_app_notification.dart';
import 'reader_screen.dart';

class ComicDetailScreen extends StatefulWidget {
  const ComicDetailScreen({
    super.key,
    required this.apiClient,
    required this.comic,
    this.preferences,
    this.viewerIdentifier,
    this.offlineDownloads,
  });

  final ApiClient apiClient;
  final Comic comic;
  final AppPreferences? preferences;
  final String? viewerIdentifier;
  final OfflineDownloadService? offlineDownloads;

  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  late Future<_ComicDetailData> _future;
  ComicRating? _rating;
  bool _saved = false;
  bool _liked = false;
  bool _actionBusy = false;
  bool _ratingBusy = false;
  bool _showFullSummary = false;
  int _tab = 0;
  String? _selectedLanguage; // null = original (no bubble overlay)
  String? _resolvedComicId;

  bool get _canDownloadOffline =>
      widget.apiClient.currentUser?.premiumActive == true;

  @override
  void initState() {
    super.initState();
    final initialIdentifier = widget.comic.id.trim();
    if (ApiClient.isUuidIdentifier(initialIdentifier)) {
      _resolvedComicId = initialIdentifier;
    }
    _future = _load();
    _restoreReadingLanguage();
  }

  Future<void> _restoreReadingLanguage() async {
    try {
      final lang = await widget.preferences?.readPreferredReadingLanguage();
      if (mounted && lang != null) {
        setState(() => _selectedLanguage = lang);
      }
    } catch (_) {}
  }

  Future<_ComicDetailData> _load() async {
    final detailFuture = widget.apiClient.getComicDetail(widget.comic.id);
    final comicIdFuture = _resolvedComicId == null
        ? detailFuture.then(_rememberResolvedComicId)
        : Future.value(_resolvedComicId!);
    final results = await Future.wait<Object?>([
      detailFuture,
      comicIdFuture.then(widget.apiClient.getChapters),
      if (widget.apiClient.hasToken)
        comicIdFuture.then(widget.apiClient.getReadChapterIds)
      else
        Future.value(const <String>{}),
      if (widget.apiClient.hasToken)
        comicIdFuture.then(widget.apiClient.checkSaved)
      else
        Future.value(false),
      if (widget.apiClient.hasToken)
        comicIdFuture.then(widget.apiClient.checkLiked)
      else
        Future.value(false),
      comicIdFuture.then(_loadRating),
    ]);
    _saved = results[3] as bool;
    _liked = results[4] as bool;
    final comic = results[0] as Comic;
    final comicId = _rememberResolvedComicId(comic);
    final rating =
        (results[5] as ComicRating?) ??
        ComicRating(
          comicId: comic.id,
          ratingAverage: comic.ratingAverage ?? 0,
          ratingCount: comic.ratingCount ?? 0,
        );
    _rating = rating;
    List<String> languages = const [];
    try {
      languages = await widget.apiClient.getComicTranslationLanguages(comicId);
    } catch (_) {
      // Non-fatal — the reader just falls back to "Original" only.
    }
    return _ComicDetailData(
      comic: comic,
      chapters: results[1] as List<ChapterLite>,
      readChapterIds: results[2] as Set<String>,
      languages: languages,
      rating: rating,
    );
  }

  String _rememberResolvedComicId(Comic comic) {
    final comicId = comic.id.trim();
    if (comicId.isEmpty) {
      throw const ApiException('Comic detail does not contain its ID.');
    }
    _resolvedComicId = comicId;
    return comicId;
  }

  Future<ComicRating?> _loadRating(String comicId) async {
    if (!widget.apiClient.hasToken) return null;
    try {
      return await widget.apiClient.getComicRating(comicId);
    } catch (_) {
      return null;
    }
  }

  void _reload() {
    setState(() {
      _rating = null;
      _future = _load();
    });
  }

  void _onLanguageChanged(String? lang) {
    setState(() => _selectedLanguage = lang);
    // Persist silently — lỗi không chặn UI
    widget.preferences?.writePreferredReadingLanguage(lang).catchError((_) {});
  }

  Future<void> _toggleSave() async {
    if (!widget.apiClient.hasToken) return _requestSignIn();
    final comicId = _resolvedComicId;
    if (comicId == null) return;
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final saved = await widget.apiClient.toggleSaved(comicId);
      if (mounted) setState(() => _saved = saved);
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleLike() async {
    if (!widget.apiClient.hasToken) return _requestSignIn();
    final comicId = _resolvedComicId;
    if (comicId == null) return;
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final liked = await widget.apiClient.toggleLiked(comicId);
      if (mounted) setState(() => _liked = liked);
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _rateComic(int score) async {
    if (!widget.apiClient.hasToken) {
      _showMessage(
        context.tr('Sign in to rate this comic.'),
        type: InAppNotificationType.information,
      );
      return;
    }
    final comicId = _resolvedComicId;
    if (comicId == null) return;
    if (_ratingBusy) return;
    setState(() => _ratingBusy = true);
    try {
      final updated = await widget.apiClient.rateComic(comicId, score);
      if (!mounted) return;
      setState(() => _rating = updated);
      _showMessage(
        context.tr(
          'Rated {score} stars successfully.',
          values: {'score': score},
        ),
        type: InAppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  Future<void> _removeRating() async {
    if (!widget.apiClient.hasToken || _rating?.userScore == null) return;
    final comicId = _resolvedComicId;
    if (comicId == null) return;
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Remove your rating?'),
      message: context.tr(
        'Are you sure you want to remove your rating for this comic?',
      ),
      confirmLabel: context.tr('Remove rating'),
      cancelLabel: context.tr('Keep rating'),
      icon: Icons.star_border_rounded,
      destructive: true,
      barrierDismissible: false,
    );
    if (!confirmed || !mounted || _ratingBusy) return;

    setState(() => _ratingBusy = true);
    try {
      final updated = await widget.apiClient.deleteComicRating(comicId);
      if (!mounted) return;
      setState(() => _rating = updated);
      _showMessage(
        context.tr('Your rating has been removed.'),
        type: InAppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  void _requestSignIn() {
    _showMessage(
      context.tr('Sign in to sync this action with your library.'),
      type: InAppNotificationType.information,
    );
  }

  void _showMessage(
    String message, {
    InAppNotificationType type = InAppNotificationType.error,
  }) {
    if (!mounted) return;
    InAppNotifications.show(
      context,
      type: type,
      title: context.tr(switch (type) {
        InAppNotificationType.success => 'Success',
        InAppNotificationType.error => 'Error',
        InAppNotificationType.warning => 'Warning',
        InAppNotificationType.information => 'Information',
      }),
      message: message,
    );
  }

  Future<void> _share(Comic comic) async {
    await Clipboard.setData(
      ClipboardData(text: 'ComiVerse · ${comic.title}\nComic ID: ${comic.id}'),
    );
    if (!mounted) return;
    _showMessage(
      context.tr('Comic link copied.'),
      type: InAppNotificationType.success,
    );
  }

  void _openReader(List<ChapterLite> chapters, int index) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              apiClient: widget.apiClient,
              chapters: chapters,
              initialIndex: index,
              comicTitle: widget.comic.title,
              initialLanguage: _selectedLanguage,
              preferences: widget.preferences,
              viewerIdentifier: widget.viewerIdentifier,
              offlineDownloads: widget.offlineDownloads,
            ),
          ),
        )
        .then((_) {
          if (widget.apiClient.hasToken && mounted) {
            _reload();
          }
          // Sync lại ngôn ngữ nếu user đổi trong reader
          _restoreReadingLanguage();
        });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: FutureBuilder<_ComicDetailData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final comic = data?.comic ?? widget.comic;
          final chapters = data?.chapters ?? const <ChapterLite>[];
          final canUseComicActions =
              _resolvedComicId != null &&
              snapshot.connectionState != ConnectionState.waiting &&
              !snapshot.hasError;
          final rating =
              _rating ??
              data?.rating ??
              ComicRating(
                comicId: comic.id,
                ratingAverage: comic.ratingAverage ?? 0,
                ratingCount: comic.ratingCount ?? 0,
              );
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 390,
                pinned: true,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'share') _share(comic);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'share',
                        child: Text(context.tr('Share comic')),
                      ),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _DetailHero(comic: comic),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comic.title,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            children: [
                              Text(
                                context.tr(
                                  'By {author}',
                                  values: {
                                    'author':
                                        comic.authorName ??
                                        context.tr('Unknown author'),
                                  },
                                ),
                              ),
                              Text('· ${_statusLabel(context, comic.status)}'),
                              if (comic.viewCount != null)
                                Text(
                                  context.tr(
                                    '· {count} views',
                                    values: {
                                      'count': compactNumber(comic.viewCount!),
                                    },
                                  ),
                                ),
                              if (comic.chapterCount != null)
                                Text(
                                  context.tr(
                                    '· {count} chapters',
                                    values: {'count': comic.chapterCount},
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: comic.genres.map((genre) {
                              return Chip(label: Text(genre));
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: PrimaryGradientButton(
                                  label: context.tr('Read Now'),
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: chapters.isEmpty
                                      ? null
                                      : () => _openReader(chapters, 0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _actionBusy || !canUseComicActions
                                      ? null
                                      : _toggleSave,
                                  icon: Icon(
                                    _saved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_outline_rounded,
                                  ),
                                  label: Text(
                                    context.tr(_saved ? 'Saved' : 'Save'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ActionItem(
                                icon: _liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_outline_rounded,
                                label: context.tr(_liked ? 'Liked' : 'Like'),
                                selected: _liked,
                                onTap: canUseComicActions && !_actionBusy
                                    ? _toggleLike
                                    : null,
                              ),
                              _ActionItem(
                                icon: Icons.share_outlined,
                                label: context.tr('Share'),
                                onTap: () => _share(comic),
                              ),
                              _ActionItem(
                                icon: _canDownloadOffline
                                    ? Icons.download_outlined
                                    : Icons.lock_outline_rounded,
                                label: context.tr('Download'),
                                disabledTooltip: context.tr(
                                  'An active Premium plan is required for offline downloads.',
                                ),
                                onTap: _canDownloadOffline
                                    ? () => _showDownloadPicker(
                                        comic,
                                        chapters,
                                        data?.languages ?? const [],
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 14),
                          _ComicRatingSection(
                            rating: rating,
                            busy:
                                _ratingBusy ||
                                snapshot.connectionState ==
                                    ConnectionState.waiting,
                            onRate: _rateComic,
                            onRemove: rating.userScore == null
                                ? null
                                : _removeRating,
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 14),
                          Text(
                            comic.summary?.trim().isNotEmpty == true
                                ? comic.summary!
                                : context.tr(
                                    'No synopsis has been published yet.',
                                  ),
                            maxLines: _showFullSummary ? null : 3,
                            overflow: _showFullSummary
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if ((comic.summary?.length ?? 0) > 140)
                            TextButton(
                              onPressed: () => setState(
                                () => _showFullSummary = !_showFullSummary,
                              ),
                              child: Text(
                                context.tr(
                                  _showFullSummary ? 'Show Less' : 'Read More',
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              for (var index = 0; index < 2; index++)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _tab = index),
                                    child: Container(
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            width: 2,
                                            color: _tab == index
                                                ? scheme.primary
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        context.tr(
                                          index == 0 ? 'Chapters' : 'Comments',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _tab == index
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ApiErrorState(
                    error: snapshot.error!,
                    onRetry: _reload,
                  ),
                )
              else if (_tab == 1)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ContentCommentSection(
                          apiClient: widget.apiClient,
                          target: ContentCommentTarget.comic,
                          targetId: comic.id,
                        ),
                      ),
                    ),
                  ),
                )
              else if (chapters.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.menu_book_outlined,
                    message: context.tr('No published chapters yet.'),
                  ),
                )
              else ...[
                if ((data?.languages ?? const []).isNotEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _TranslationChipRow(
                          languages: data!.languages,
                          selected: _selectedLanguage,
                          onChanged: _onLanguageChanged,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  sliver: SliverList.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return _ChapterRow(
                        chapter: chapter,
                        isRead: data!.readChapterIds.contains(chapter.id),
                        onTap: () => _openReader(chapters, index),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDownloadPicker(
    Comic comic,
    List<ChapterLite> chapters,
    List<String> translationLanguages,
  ) async {
    if (!_canDownloadOffline) {
      _showMessage(
        context.tr('An active Premium plan is required for offline downloads.'),
        type: InAppNotificationType.information,
      );
      return;
    }
    final service = widget.offlineDownloads;
    if (service == null || !await service.isSupported) {
      if (!mounted) return;
      _showMessage(
        context.tr(
          'Secure offline downloads are available in the configured Android and iOS apps.',
        ),
        type: InAppNotificationType.information,
      );
      return;
    }
    if (!widget.apiClient.hasToken) {
      _requestSignIn();
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DownloadChapterSheet(
        chapters: chapters,
        comicTitle: comic.title,
        service: service,
        translationLanguages: translationLanguages,
      ),
    );
  }
}

class _DownloadChapterSheet extends StatefulWidget {
  const _DownloadChapterSheet({
    required this.chapters,
    required this.comicTitle,
    required this.service,
    required this.translationLanguages,
  });

  final List<ChapterLite> chapters;
  final String comicTitle;
  final OfflineDownloadService service;
  final List<String> translationLanguages;

  @override
  State<_DownloadChapterSheet> createState() => _DownloadChapterSheetState();
}

class _DownloadChapterSheetState extends State<_DownloadChapterSheet> {
  final Set<String> _downloaded = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
  }

  Future<void> _loadDownloaded() async {
    for (final chapter in widget.chapters) {
      if (await widget.service.hasDownload(chapter.id)) {
        _downloaded.add(chapter.id);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _download(ChapterLite chapter) async {
    if (_busy.contains(chapter.id)) return;
    setState(() => _busy.add(chapter.id));
    try {
      await widget.service.downloadChapter(
        chapter: chapter,
        comicTitle: widget.comicTitle,
      );
      if (!mounted) return;
      setState(() => _downloaded.add(chapter.id));
      InAppNotifications.success(
        context,
        title: context.tr('Download complete'),
        message: context.tr(
          'Chapter {number} is ready offline with its available translations.',
          values: {'number': chapter.chapterNumber},
        ),
      );
    } catch (error) {
      if (!mounted) return;
      InAppNotifications.error(
        context,
        title: context.tr('Download failed'),
        message: context.localizedError(error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(chapter.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Download chapters'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Premium is verified by the server. Offline access must be renewed every 7 days.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.translate_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Each download includes the original pages and every approved translation available for that chapter.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.translationLanguages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.tr('Published languages in this comic'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.image_outlined, size: 17),
                          label: Text(context.tr('Original')),
                        ),
                        for (final language in widget.translationLanguages)
                          Chip(
                            avatar: const Icon(
                              Icons.translate_rounded,
                              size: 17,
                            ),
                            label: Text(_offlineLanguageLabel(language)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = widget.chapters[index];
                  final downloaded = _downloaded.contains(chapter.id);
                  final busy = _busy.contains(chapter.id);
                  return ListTile(
                    title: Text(chapter.title),
                    subtitle: Text(
                      context.tr(
                        'Chapter {number}',
                        values: {'number': chapter.chapterNumber},
                      ),
                    ),
                    trailing: busy
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: context.tr(
                              downloaded ? 'Download again' : 'Download',
                            ),
                            onPressed: () => _download(chapter),
                            icon: Icon(
                              downloaded
                                  ? Icons.offline_pin_rounded
                                  : Icons.download_rounded,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _offlineLanguageLabel(String code) {
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

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ComicCoverImage(url: comic.imageUrl),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xF207040D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComicRatingSection extends StatelessWidget {
  const _ComicRatingSection({
    required this.rating,
    required this.busy,
    required this.onRate,
    required this.onRemove,
  });

  final ComicRating rating;
  final bool busy;
  final ValueChanged<int> onRate;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.cvColors;
    final selectedScore = rating.userScore ?? 0;
    final ratingLabel = rating.ratingCount == 1
        ? '/ 5 ({count} rating)'
        : '/ 5 ({count} ratings)';

    return Semantics(
      container: true,
      label: context.tr('Comic rating'),
      child: Container(
        key: const ValueKey('comic-rating-section'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: tokens.rating, size: 25),
                    const SizedBox(width: 5),
                    Text(
                      rating.ratingAverage.toStringAsFixed(1),
                      key: const ValueKey('comic-rating-average'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  context.tr(
                    ratingLabel,
                    values: {'count': rating.ratingCount},
                  ),
                  key: const ValueKey('comic-rating-count'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (rating.userScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.rating.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.tr(
                        'Your rating: {score}/5',
                        values: {'score': rating.userScore},
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 2,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var score = 1; score <= 5; score++)
                  Tooltip(
                    message: context.tr(
                      score == 1 ? 'Rate {score} star' : 'Rate {score} stars',
                      values: {'score': score},
                    ),
                    child: Semantics(
                      button: true,
                      selected: score <= selectedScore,
                      label: context.tr(
                        score == 1 ? 'Rate {score} star' : 'Rate {score} stars',
                        values: {'score': score},
                      ),
                      child: IconButton(
                        key: ValueKey('comic-rating-star-$score'),
                        onPressed: busy ? null : () => onRate(score),
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 34,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          score <= selectedScore
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: score <= selectedScore
                              ? tokens.rating
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                SizedBox.square(
                  dimension: 18,
                  child: busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              context.tr(
                selectedScore > 0
                    ? '(Selected {score} stars)'
                    : '(Tap a star to rate)',
                values: {'score': selectedScore},
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: const ValueKey('remove-comic-rating'),
                onPressed: busy ? null : onRemove,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.tr('Remove my rating')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.disabledTooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? disabledTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final action = Semantics(
      button: true,
      enabled: onTap != null,
      label: onTap == null && disabledTooltip != null
          ? '$label. $disabledTooltip'
          : label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: SizedBox(
          width: 82,
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
    return disabledTooltip == null || onTap != null
        ? action
        : Tooltip(message: disabledTooltip!, child: action);
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.isRead,
    required this.onTap,
  });

  final ChapterLite chapter;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isRead
          ? context.cvColors.surfaceSubtle
          : context.cvColors.surfaceRaised,
      child: ListTile(
        minTileHeight: 76,
        onTap: onTap,
        leading: Container(
          width: 58,
          height: 48,
          decoration: BoxDecoration(
            color: context.cvColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            chapter.isPremium
                ? Icons.lock_outline_rounded
                : Icons.menu_book_rounded,
            color: chapter.isPremium
                ? context.cvColors.warning
                : scheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chapter.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: context.cvColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    color: context.cvColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${_formatDate(context, chapter.createdAt)}'
          '${chapter.viewCount == null ? '' : context.tr(' · {count} views', values: {'count': compactNumber(chapter.viewCount!)})}',
        ),
        trailing: isRead
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return context.tr(
        'Chapter {number}',
        values: {'number': chapter.chapterNumber},
      );
    }
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

String _statusLabel(BuildContext context, String? status) {
  final normalized = status?.trim().toUpperCase();
  return switch (normalized) {
    'ONGOING' => context.tr('Ongoing'),
    'COMPLETED' => context.tr('Completed'),
    'PUBLISHED' => context.tr('Published'),
    null || '' => context.tr('Published'),
    _ => status!,
  };
}

class _ComicDetailData {
  const _ComicDetailData({
    required this.comic,
    required this.chapters,
    required this.readChapterIds,
    required this.languages,
    required this.rating,
  });

  final Comic comic;
  final List<ChapterLite> chapters;
  final Set<String> readChapterIds;
  final List<String> languages;
  final ComicRating rating;
}

/// Translation chip row hiển thị bên trên danh sách chapter.
/// Mirrors language switcher trên web ComicDetail.jsx.
/// Khi comic có bản dịch, hiển thị chip "Original" + từng ngôn ngữ đã dịch.
/// Chip được chọn sẽ highlight màu primary với icon translate.
class _TranslationChipRow extends StatelessWidget {
  const _TranslationChipRow({
    required this.languages,
    required this.selected,
    required this.onChanged,
  });

  final List<String> languages;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.cvColors;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                context.tr('Available Translations'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${languages.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Chip "Original"
                _LangChip(
                  label: context.tr('Original'),
                  isSelected: selected == null,
                  icon: Icons.image_outlined,
                  onTap: () => onChanged(null),
                ),
                const SizedBox(width: 8),
                for (final lang in languages) ...[
                  _LangChip(
                    label: _langLabel(lang),
                    isSelected: selected == lang,
                    icon: Icons.translate_rounded,
                    onTap: () => onChanged(lang),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: scheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  context.tr(
                    'Reading: {lang}',
                    values: {'lang': _langLabel(selected!)},
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _langLabel(String code) {
    return switch (code.toLowerCase()) {
      'vi' => '🇻🇳 Tiếng Việt',
      'en' => '🇬🇧 English',
      'jp' || 'ja' => '🇯🇵 Japanese',
      'ko' => '🇰🇷 Korean',
      'zh' => '🇨🇳 Chinese',
      'fr' => '🇫🇷 French',
      'de' => '🇩🇪 German',
      'es' => '🇪🇸 Spanish',
      _ => code.toUpperCase(),
    };
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
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
