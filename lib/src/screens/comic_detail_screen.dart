import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chapter.dart';
import '../models/comic.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'reader_screen.dart';

class ComicDetailScreen extends StatefulWidget {
  const ComicDetailScreen({
    super.key,
    required this.apiClient,
    required this.comic,
  });

  final ApiClient apiClient;
  final Comic comic;

  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  late Future<_ComicDetailData> _future = _load();
  bool _saved = false;
  bool _liked = false;
  bool _actionBusy = false;
  bool _showFullSummary = false;
  int _tab = 0;

  Future<_ComicDetailData> _load() async {
    final results = await Future.wait([
      widget.apiClient.getComicDetail(widget.comic.id),
      widget.apiClient.getChapters(widget.comic.id),
      if (widget.apiClient.hasToken)
        widget.apiClient.getReadChapterIds(widget.comic.id)
      else
        Future.value(const <String>{}),
      if (widget.apiClient.hasToken)
        widget.apiClient.checkSaved(widget.comic.id)
      else
        Future.value(false),
      if (widget.apiClient.hasToken)
        widget.apiClient.checkLiked(widget.comic.id)
      else
        Future.value(false),
    ]);
    _saved = results[3] as bool;
    _liked = results[4] as bool;
    return _ComicDetailData(
      comic: results[0] as Comic,
      chapters: results[1] as List<ChapterLite>,
      readChapterIds: results[2] as Set<String>,
    );
  }

  Future<void> _toggleSave() async {
    if (!widget.apiClient.hasToken) return _requestSignIn();
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final saved = await widget.apiClient.toggleSaved(widget.comic.id);
      if (mounted) setState(() => _saved = saved);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleLike() async {
    if (!widget.apiClient.hasToken) return _requestSignIn();
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final liked = await widget.apiClient.toggleLiked(widget.comic.id);
      if (mounted) setState(() => _liked = liked);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _requestSignIn() {
    _showMessage('Sign in to sync this action with your library.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(Comic comic) async {
    await Clipboard.setData(
      ClipboardData(text: 'ComiVerse · ${comic.title}\nComic ID: ${comic.id}'),
    );
    _showMessage('Comic link copied.');
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
            ),
          ),
        )
        .then((_) {
          if (widget.apiClient.hasToken && mounted) {
            setState(() => _future = _load());
          }
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'share', child: Text('Share comic')),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comic.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                              ),
                              if (comic.ratingAverage != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.cvColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: context.cvColors.rating,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        comic.ratingAverage!.toStringAsFixed(1),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            children: [
                              Text(
                                'By ${comic.authorName ?? 'Unknown author'}',
                              ),
                              Text('· ${comic.status ?? 'Published'}'),
                              if (comic.viewCount != null)
                                Text(
                                  '· ${compactNumber(comic.viewCount!)} views',
                                ),
                              if (comic.chapterCount != null)
                                Text('· ${comic.chapterCount} chapters'),
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
                                  label: 'Read Now',
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: chapters.isEmpty
                                      ? null
                                      : () => _openReader(chapters, 0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _actionBusy ? null : _toggleSave,
                                  icon: Icon(
                                    _saved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_outline_rounded,
                                  ),
                                  label: Text(_saved ? 'Saved' : 'Save'),
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
                                label: _liked ? 'Liked' : 'Like',
                                selected: _liked,
                                onTap: _toggleLike,
                              ),
                              _ActionItem(
                                icon: Icons.share_outlined,
                                label: 'Share',
                                onTap: () => _share(comic),
                              ),
                              _ActionItem(
                                icon: Icons.download_outlined,
                                label: 'Download',
                                onTap: () => _showMessage(
                                  'Offline downloads are available with Premium.',
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 14),
                          Text(
                            comic.summary?.trim().isNotEmpty == true
                                ? comic.summary!
                                : 'No synopsis has been published yet.',
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
                                _showFullSummary ? 'Show Less' : 'Read More',
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
                                        index == 0 ? 'Chapters' : 'Comments',
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
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ApiErrorState(
                    error: snapshot.error!,
                    onRetry: () => setState(() => _future = _load()),
                  ),
                )
              else if (_tab == 1)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    message:
                        'Comments are not available from the current backend API.',
                  ),
                )
              else if (chapters.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.menu_book_outlined,
                    message: 'No published chapters yet.',
                  ),
                )
              else
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
          );
        },
      ),
    );
  }
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

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
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
    );
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
          '${_formatDate(chapter.createdAt)}'
          '${chapter.viewCount == null ? '' : ' · ${compactNumber(chapter.viewCount!)} views'}',
        ),
        trailing: isRead
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chapter ${chapter.chapterNumber}';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ComicDetailData {
  const _ComicDetailData({
    required this.comic,
    required this.chapters,
    required this.readChapterIds,
  });

  final Comic comic;
  final List<ChapterLite> chapters;
  final Set<String> readChapterIds;
}
