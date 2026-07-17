import 'package:flutter/material.dart';

import '../models/comic.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import 'comic_detail_screen.dart';

class ComicsScreen extends StatefulWidget {
  const ComicsScreen({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onSignOut,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onSignOut;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<ComicsScreen> createState() => _ComicsScreenState();
}

class _ComicsScreenState extends State<ComicsScreen> {
  late Future<List<Comic>> _futureComics;
  int _sectionIndex = 0;
  int _libraryTab = 0;
  String _timeframe = 'day';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _futureComics = widget.apiClient.getComics();
  }

  Future<List<Comic>> _loadCurrentSection() {
    return switch (_sectionIndex) {
      0 => widget.apiClient.getComics(),
      1 => widget.apiClient.getLeaderboard(timeframe: _timeframe),
      _ when !widget.apiClient.hasToken => Future.value(const <Comic>[]),
      _ when _libraryTab == 1 => widget.apiClient.getLikedComics(),
      _ when _libraryTab == 2 => widget.apiClient.getReadingHistory(),
      _ => widget.apiClient.getSavedComics(),
    };
  }

  void _reload() {
    setState(() {
      _futureComics = _loadCurrentSection();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _futureComics;
  }

  void _selectSection(int index) {
    if (_sectionIndex == index) return;
    _sectionIndex = index;
    _query = '';
    _reload();
  }

  List<Comic> _filtered(List<Comic> comics) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return comics;
    return comics.where((comic) {
      return comic.title.toLowerCase().contains(query) ||
          (comic.authorName?.toLowerCase().contains(query) ?? false) ||
          comic.genres.any((genre) => genre.toLowerCase().contains(query));
    }).toList();
  }

  String get _title => switch (_sectionIndex) {
        0 => 'Explore',
        1 => 'Ranking',
        _ => 'Library',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Use light mode' : 'Use dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: widget.user?.avatarUrl == null
                  ? null
                  : NetworkImage(widget.user!.avatarUrl!),
              child: widget.user?.avatarUrl == null
                  ? Text(
                      (widget.user?.displayName ?? 'G')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 13),
                    )
                  : null,
            ),
            onSelected: (value) {
              if (value == 'signout') widget.onSignOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(widget.user?.displayName ?? 'Guest reader'),
                  subtitle: Text(widget.user?.email ?? 'Public session'),
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(
                    widget.user == null ? 'Back to sign in' : 'Sign out',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _sectionIndex == 2 && !widget.apiClient.hasToken
          ? _GuestLibrary(onBackToLogin: widget.onSignOut)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Comic>>(
                future: _futureComics,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final comics = _filtered(snapshot.data ?? const []);
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: comics.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildHeader(context, comics.length);
                      final comic = comics[index - 1];
                      return _ComicListTile(
                        comic: comic,
                        rank: _sectionIndex == 1 ? index : null,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ComicDetailScreen(
                                apiClient: widget.apiClient,
                                comic: comic,
                              ),
                            ),
                          );
                          if (_sectionIndex == 2 && mounted) _reload();
                        },
                      );
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sectionIndex,
        onDestinationSelected: _selectSection,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int resultCount) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer,
                  scheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (_sectionIndex) {
                    0 => widget.user == null
                        ? 'Discover as guest'
                        : 'Hi, ${widget.user!.displayName}',
                    1 => 'Top comics',
                    _ => switch (_libraryTab) {
                        1 => 'Your liked comics',
                        2 => 'Reading history',
                        _ => 'Your saved comics',
                      },
                  },
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$resultCount titles from the ComiVerse catalog',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_sectionIndex == 1)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('Day')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_timeframe},
            onSelectionChanged: (selection) {
              _timeframe = selection.first;
              _reload();
            },
          ),
        if (_sectionIndex == 2)
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Saved'),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Liked'),
              ),
              ButtonSegment(
                value: 2,
                label: Text('History'),
              ),
            ],
            selected: {_libraryTab},
            onSelectionChanged: (selection) {
              _libraryTab = selection.first;
              _reload();
            },
          ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('search-$_sectionIndex-$_libraryTab'),
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search comics, authors, genres...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        if (resultCount == 0) ...[
          const SizedBox(height: 64),
          Icon(Icons.auto_stories_outlined, size: 54, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            _query.isEmpty ? 'No comics here yet.' : 'No matching comics.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _ComicListTile extends StatelessWidget {
  const _ComicListTile({
    required this.comic,
    required this.onTap,
    this.rank,
  });

  final Comic comic;
  final VoidCallback onTap;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (rank != null) ...[
                SizedBox(
                  width: 34,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rank! <= 3 ? scheme.primary : scheme.outline,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              _CoverImage(url: comic.imageUrl, width: 82, height: 112),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comic.authorName ?? 'Unknown author',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (comic.latestChapterNumber != null)
                          _MetaChip(label: 'Ch ${comic.latestChapterNumber}'),
                        if (comic.ratingAverage != null)
                          _MetaChip(
                            label: comic.ratingAverage!.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                          ),
                        if (comic.viewCount != null)
                          _MetaChip(
                            label: _compactNumber(comic.viewCount!),
                            icon: Icons.visibility_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static String _compactNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 3),
          ],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    required this.width,
    required this.height,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        color: scheme.surfaceContainerHighest,
        child: url == null
            ? const Icon(Icons.auto_stories_rounded)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}

class _GuestLibrary extends StatelessWidget {
  const _GuestLibrary({required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 64),
            const SizedBox(height: 18),
            const Text(
              'Sign in to open your library',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Saved and liked comics are synced with your ComiVerse account.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onBackToLogin, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.cloud_off_rounded, size: 58, color: scheme.error),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
