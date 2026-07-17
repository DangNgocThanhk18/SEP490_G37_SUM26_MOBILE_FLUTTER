import 'package:flutter/material.dart';

import '../models/comic.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'comic_detail_screen.dart';
import 'ranking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onOpenExplore,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onOpenExplore;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<_HomeData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      widget.apiClient.getTopViewed(size: 8),
      widget.apiClient.getRecommendations(size: 10),
      widget.apiClient.getRecentlyUpdated(size: 8),
      if (widget.apiClient.hasToken)
        widget.apiClient.getReadingHistory()
      else
        Future.value(const <Comic>[]),
    ]);
    return _HomeData(
      trending: results[0],
      recommended: results[1],
      updated: results[2],
      history: results[3],
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _openComic(Comic comic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ComicDetailScreen(apiClient: widget.apiClient, comic: comic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaledRailExtra = ((textScale - 1) * 64).clamp(0, 64).toDouble();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.brandPurple, context.cvColors.brandPink],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'ComiVerse',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Explore comics',
            onPressed: widget.onOpenExplore,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: widget.isDarkMode ? 'Use light mode' : 'Use dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundImage: _avatarProvider(widget.user?.avatarUrl),
              child: _avatarProvider(widget.user?.avatarUrl) == null
                  ? Text((widget.user?.displayName ?? 'G')[0].toUpperCase())
                  : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _HomeSkeleton();
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: ApiErrorState(
                      error: snapshot.error!,
                      onRetry: _refresh,
                    ),
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            final featured =
                data.trending.firstOrNull ??
                data.recommended.firstOrNull ??
                data.updated.firstOrNull;
            if (featured == null) {
              return ListView(
                children: const [
                  SizedBox(
                    height: 500,
                    child: EmptyState(
                      icon: Icons.auto_stories_outlined,
                      message: 'No published comics yet.',
                    ),
                  ),
                ],
              );
            }
            return ListView(
              key: const PageStorageKey('home-scroll'),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _FeaturedComic(
                    comic: featured,
                    onTap: () => _openComic(featured),
                  ),
                ),
                if (data.history.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    child: const SectionHeader(title: 'Continue Reading'),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: data.history.take(5).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final comic = data.history[index];
                        return _ContinueCard(
                          comic: comic,
                          onTap: () => _openComic(comic),
                        );
                      },
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: SectionHeader(
                    title: 'Recommended for You',
                    actionLabel: 'View all',
                    onAction: widget.onOpenExplore,
                  ),
                ),
                SizedBox(
                  // Cover (3:4), two title lines, and metadata need more than
                  // 230dp on smaller devices and with Android text scaling.
                  height: 252 + scaledRailExtra,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: data.recommended.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final comic = data.recommended[index];
                      return ComicCoverCard(
                        comic: comic,
                        onTap: () => _openComic(comic),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
                  child: SectionHeader(
                    title: 'Trending Now',
                    icon: Icons.trending_up_rounded,
                    actionLabel: 'Ranking',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RankingScreen(apiClient: widget.apiClient),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.trending.take(5).length; i++)
                        ComicListRow(
                          comic: data.trending[i],
                          leading: SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: i == 0
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          onTap: () => _openComic(data.trending[i]),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                  child: const SectionHeader(title: 'New Updates'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760
                          ? 4
                          : constraints.maxWidth >= 520
                          ? 3
                          : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.updated.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          // The card contains a 3:4 cover plus two title lines
                          // and metadata. A taller cell prevents overflow at
                          // 320dp and with Android font scaling.
                          childAspectRatio: 0.50,
                        ),
                        itemBuilder: (context, index) {
                          final comic = data.updated[index];
                          return ComicCoverCard(
                            comic: comic,
                            width: double.infinity,
                            showChapter: true,
                            onTap: () => _openComic(comic),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  ImageProvider<Object>? _avatarProvider(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return NetworkImage(url);
  }
}

class _FeaturedComic extends StatelessWidget {
  const _FeaturedComic({required this.comic, required this.onTap});

  final Comic comic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseHeight = constraints.maxWidth >= 700
            ? 300.0
            : (constraints.maxWidth / 1.05).clamp(340.0, 420.0);
        final scaledExtra = ((textScale - 1) * 100).clamp(0, 80).toDouble();
        return SizedBox(
          height: baseHeight + scaledExtra,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ComicCoverImage(url: comic.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xF207040D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.2, 0.85],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: comic.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              genre.toUpperCase(),
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        comic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 17,
                            color: context.cvColors.rating,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            comic.ratingAverage?.toStringAsFixed(1) ?? 'New',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (comic.chapterCount != null) ...[
                            const Text(
                              '  ·  ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              '${comic.chapterCount} chapters',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                      if (comic.summary?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          comic.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryGradientButton(
                          label: comic.latestChapterNumber == null
                              ? 'View Comic'
                              : 'Read Chapter ${comic.latestChapterNumber}',
                          icon: Icons.menu_book_rounded,
                          onPressed: onTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.comic, required this.onTap});

  final Comic comic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 70,
                    height: 110,
                    child: ComicCoverImage(url: comic.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        comic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comic.latestChapterNumber == null
                            ? 'Continue reading'
                            : 'Latest: Ch. ${comic.latestChapterNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(value: 0.45),
                    ],
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

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 1.05,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.cvColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.trending,
    required this.recommended,
    required this.updated,
    required this.history,
  });

  final List<Comic> trending;
  final List<Comic> recommended;
  final List<Comic> updated;
  final List<Comic> history;
}
