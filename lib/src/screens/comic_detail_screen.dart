import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/comic.dart';
import '../services/api_client.dart';
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
  late Future<_ComicDetailData> _futureData;
  bool _isSaved = false;
  bool _isLiked = false;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _futureData = _loadData();
  }

  Future<_ComicDetailData> _loadData() async {
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
    _isSaved = results[3] as bool;
    _isLiked = results[4] as bool;
    return _ComicDetailData(
      comic: results[0] as Comic,
      chapters: results[1] as List<ChapterLite>,
      readChapterIds: results[2] as Set<String>,
    );
  }

  Future<void> _toggleSaved() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final value = await widget.apiClient.toggleSaved(widget.comic.id);
      if (mounted) setState(() => _isSaved = value);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleLiked() async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final value = await widget.apiClient.toggleLiked(widget.comic.id);
      if (mounted) setState(() => _isLiked = value);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ComicDetailData>(
        future: _futureData,
        builder: (context, snapshot) {
          final fallbackComic = widget.comic;
          final comic = snapshot.data?.comic ?? fallbackComic;
          final chapters = snapshot.data?.chapters ?? const <ChapterLite>[];
          final readChapterIds =
              snapshot.data?.readChapterIds ?? const <String>{};
          final scheme = Theme.of(context).colorScheme;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _HeroCover(comic: comic),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (comic.status != null) _Pill(comic.status!),
                          ...comic.genres.take(4).map(_Pill.new),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (widget.apiClient.hasToken) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _actionBusy ? null : _toggleSaved,
                                icon: Icon(
                                  _isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                ),
                                label: Text(_isSaved ? 'Saved' : 'Save'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _actionBusy ? null : _toggleLiked,
                                icon: Icon(
                                  _isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                ),
                                label: Text(_isLiked ? 'Liked' : 'Like'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        comic.summary?.trim().isNotEmpty == true
                            ? comic.summary!
                            : 'No synopsis yet.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Chapters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            snapshot.error.toString(),
                            style: const TextStyle(color: Color(0xFFFF9DA8)),
                          ),
                        )
                      else if (chapters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'No published chapters yet.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      else
                        ListView.separated(
                          padding: const EdgeInsets.only(top: 12),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: chapters.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            final hasBeenRead =
                                readChapterIds.contains(chapter.id);
                            return ListTile(
                              tileColor: scheme.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: scheme.outlineVariant),
                              ),
                              title: Text(chapter.title),
                              subtitle: Text(
                                'Chapter ${chapter.chapterNumber}'
                                '${chapter.viewCount == null ? '' : ' - ${chapter.viewCount} views'}',
                              ),
                              leading: hasBeenRead
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: scheme.primary,
                                    )
                                  : null,
                              trailing: chapter.isPremium
                                  ? const Icon(Icons.workspace_premium_rounded)
                                  : const Icon(Icons.menu_book_rounded),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReaderScreen(
                                      apiClient: widget.apiClient,
                                      chapters: chapters,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                                if (widget.apiClient.hasToken && mounted) {
                                  setState(() => _futureData = _loadData());
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final imageUrl = comic.imageUrl;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: scheme.surfaceContainerHighest),
          )
        else
          Container(color: scheme.surfaceContainerHighest),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, scheme.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
