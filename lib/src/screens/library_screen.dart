import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/comic.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';
import 'comic_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.apiClient,
    required this.isGuest,
    required this.onSignIn,
    required this.onExplore,
  });

  final ApiClient apiClient;
  final bool isGuest;
  final VoidCallback onSignIn;
  final VoidCallback onExplore;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  int _tab = 0;
  String _sort = 'recent';
  String? _genre;
  late Future<List<Comic>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Comic>> _load() {
    if (widget.isGuest) return Future.value(const []);
    return switch (_tab) {
      1 => widget.apiClient.getLikedComics(),
      2 => widget.apiClient.getReadingHistory(),
      _ => widget.apiClient.getSavedComics(),
    };
  }

  void _reload() => setState(() => _future = _load());

  List<Comic> _sorted(List<Comic> source) {
    final result = source
        .where(
          (comic) =>
              _genre == null || comic.genres.any((item) => item == _genre),
        )
        .toList();
    if (_sort == 'title') {
      result.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sort == 'updated') {
      result.sort(
        (a, b) => (b.lastChapterUpdatedAt ?? DateTime(1970)).compareTo(
          a.lastChapterUpdatedAt ?? DateTime(1970),
        ),
      );
    }
    return result;
  }

  Future<void> _remove(Comic comic) async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Remove comic?'),
      message: _tab == 2
          ? context.tr(
              'Remove “{title}” from your reading history?',
              values: {'title': comic.title},
            )
          : context.tr(
              'Remove “{title}” from this library list?',
              values: {'title': comic.title},
            ),
      confirmLabel: context.tr('Remove'),
      cancelLabel: context.tr('Cancel'),
      destructive: true,
      icon: Icons.delete_outline_rounded,
      barrierDismissible: false,
    );
    if (!confirmed) return;
    try {
      if (_tab == 0) {
        await widget.apiClient.toggleSaved(comic.id);
      } else if (_tab == 1) {
        await widget.apiClient.toggleLiked(comic.id);
      } else {
        await widget.apiClient.deleteReadingHistory(comic.id);
      }
      if (mounted) {
        InAppNotifications.success(
          context,
          title: context.tr('Success'),
          message: context.tr('Removed from library.'),
        );
        _reload();
      }
    } catch (error) {
      if (mounted) {
        InAppNotifications.error(
          context,
          title: context.tr('Error'),
          message: context.localizedError(error),
        );
      }
    }
  }

  void _openComic(Comic comic) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                ComicDetailScreen(apiClient: widget.apiClient, comic: comic),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('Library'))),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          message: context.tr(
            'Sign in to sync saved comics, favorites, and reading history.',
          ),
          actionLabel: context.tr('Sign in'),
          onAction: widget.onSignIn,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Library')),
        actions: [
          IconButton(
            tooltip: context.tr('Explore comics'),
            onPressed: widget.onExplore,
            icon: const Icon(Icons.search_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              for (var index = 0; index < 3; index++)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _tab = index;
                      _genre = null;
                      _reload();
                    },
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2,
                            color: _tab == index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        context.tr(
                          const ['Saved', 'Favorites', 'History'][index],
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _tab == index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<Comic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final source = snapshot.data ?? const [];
          final comics = _sorted(source);
          final genres = source.expand((comic) => comic.genres).toSet().take(8);
          if (source.isEmpty) {
            return EmptyState(
              icon: _tab == 2
                  ? Icons.history_rounded
                  : _tab == 1
                  ? Icons.favorite_outline_rounded
                  : Icons.bookmark_outline_rounded,
              message: context.tr('This library section is empty.'),
              actionLabel: context.tr('Explore comics'),
              onAction: widget.onExplore,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              key: PageStorageKey('library-scroll-$_tab'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: context.tr(
                        _tab == 2 ? 'Continue Reading' : 'Your Collection',
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 64,
                                height: 92,
                                child: ComicCoverImage(
                                  url: source.first.imageUrl,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source.first.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    source.first.latestChapterNumber == null
                                        ? context.tr('Ready to read')
                                        : context.tr(
                                            'Latest chapter {number}',
                                            values: {
                                              'number': source
                                                  .first
                                                  .latestChapterNumber,
                                            },
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  const LinearProgressIndicator(value: 0.45),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filled(
                              tooltip: context.tr('Continue reading'),
                              onPressed: () => _openComic(source.first),
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 70,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(context.tr('All')),
                            selected: _genre == null,
                            onSelected: (_) => setState(() => _genre = null),
                          ),
                        ),
                        for (final genre in genres)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(genre),
                              selected: _genre == genre,
                              onSelected: (_) => setState(() => _genre = genre),
                            ),
                          ),
                        const SizedBox(width: 6),
                        DropdownButton<String>(
                          value: _sort,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(
                              value: 'recent',
                              child: Text(context.tr('Recent')),
                            ),
                            DropdownMenuItem(
                              value: 'title',
                              child: Text(context.tr('Title')),
                            ),
                            DropdownMenuItem(
                              value: 'updated',
                              child: Text(context.tr('Updated')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sort = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (comics.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      message: context.tr('No comics match this filter.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.crossAxisExtent >= 820
                            ? 5
                            : constraints.crossAxisExtent >= 600
                            ? 4
                            : constraints.crossAxisExtent >= 430
                            ? 3
                            : 2;
                        return SliverGrid.builder(
                          itemCount: comics.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.50,
                              ),
                          itemBuilder: (context, index) {
                            final comic = comics[index];
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: ComicCoverCard(
                                    comic: comic,
                                    width: double.infinity,
                                    showChapter: true,
                                    onTap: () => _openComic(comic),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton.filledTonal(
                                    tooltip: context.tr('Remove from library'),
                                    onPressed: () => _remove(comic),
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
