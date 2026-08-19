import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/comic.dart';
import '../services/api_client.dart';
import '../services/offline_download_service.dart';
import '../widgets/common_widgets.dart';
import 'comic_detail_screen.dart';
import 'ranking_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.apiClient,
    this.offlineDownloads,
  });

  final ApiClient apiClient;
  final OfflineDownloadService? offlineDownloads;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final List<Comic> _comics = [];
  List<GenreOption> _genres = const [];
  final Set<String> _selectedGenreIds = {};
  Timer? _searchDebounce;
  String _query = '';
  String? _status;
  String _sort = 'Default';
  String? _nextCursor;
  String? _nextReferenceId;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final genres = await widget.apiClient.getGenres();
      if (mounted) setState(() => _genres = genres);
    } catch (_) {
      // Explore remains usable even if the optional genre list is unavailable.
    }
    await _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    widget.apiClient.invalidateCatalogCache();
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _nextCursor = null;
      _nextReferenceId = null;
      _hasMore = false;
    });
    try {
      final page = await widget.apiClient.exploreComics(
        search: _query,
        genreIds: _selectedGenreIds,
        publicationStatus: _status,
        sortBy: _sort,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _comics
          ..clear()
          ..addAll(page.comics);
        _nextCursor = page.nextCursor;
        _nextReferenceId = page.nextReferenceId;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.apiClient.exploreComics(
        search: _query,
        cursor: _nextCursor,
        referenceId: _nextReferenceId,
        genreIds: _selectedGenreIds,
        publicationStatus: _status,
        sortBy: _sort,
      );
      if (!mounted || generation != _generation) return;
      final knownIds = _comics.map((comic) => comic.id).toSet();
      setState(() {
        _comics.addAll(page.comics.where((comic) => knownIds.add(comic.id)));
        _nextCursor = page.nextCursor;
        _nextReferenceId = page.nextReferenceId;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _error = _comics.isEmpty ? error : null;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadMore());
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final nextQuery = value.trim();
      if (nextQuery == _query) return;
      setState(() => _query = nextQuery);
      unawaited(_reload());
    });
  }

  List<Comic> get _visibleComics => _comics;

  Future<void> _showFilters() async {
    var selectedGenres = Set<String>.from(_selectedGenreIds);
    var status = _status;
    var sort = _sort;
    final result = await showModalBottomSheet<_ExploreFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Filters'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('Genre'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('All')),
                      selected: selectedGenres.isEmpty,
                      onSelected: (_) => setModalState(selectedGenres.clear),
                    ),
                    for (final genre in _genres)
                      ChoiceChip(
                        label: Text(genre.name),
                        selected: selectedGenres.contains(genre.id),
                        onSelected: (selected) => setModalState(() {
                          if (selected) {
                            selectedGenres.add(genre.id);
                          } else {
                            selectedGenres.remove(genre.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('Status'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('All')),
                      selected: status == null,
                      onSelected: (_) => setModalState(() => status = null),
                    ),
                    for (final item in const ['ONGOING', 'COMPLETED'])
                      ChoiceChip(
                        label: Text(_statusLabel(context, item)),
                        selected: status == item,
                        onSelected: (_) => setModalState(() => status = item),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: sort,
                  decoration: InputDecoration(labelText: context.tr('Sort by')),
                  items: [
                    for (final option in _sortOptions)
                      DropdownMenuItem(
                        value: option,
                        child: Text(_sortLabel(context, option)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setModalState(() => sort = value);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _ExploreFilters(
                        genreIds: selectedGenres,
                        status: status,
                        sort: sort,
                      ),
                    ),
                    child: Text(context.tr('Show results')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    _selectedGenreIds
      ..clear()
      ..addAll(result.genreIds);
    _status = result.status;
    _sort = result.sort;
    await _reload();
  }

  void _toggleQuickGenre(GenreOption genre) {
    setState(() {
      if (!_selectedGenreIds.add(genre.id)) _selectedGenreIds.remove(genre.id);
    });
    unawaited(_reload());
  }

  void _clearGenres() {
    if (_selectedGenreIds.isEmpty) return;
    _selectedGenreIds.clear();
    unawaited(_reload());
  }

  void _openComic(Comic comic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComicDetailScreen(
          apiClient: widget.apiClient,
          comic: comic,
          offlineDownloads: widget.offlineDownloads,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final comics = _visibleComics;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Explore')),
        actions: [
          IconButton(
            tooltip: context.tr('Ranking'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RankingScreen(
                  apiClient: widget.apiClient,
                  offlineDownloads: widget.offlineDownloads,
                ),
              ),
            ),
            icon: const Icon(Icons.leaderboard_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey('explore-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'Search comics, authors, genres...',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.tr('Clear'),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                    unawaited(_reload());
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: context.tr('Filters'),
                      onPressed: _showFilters,
                      icon: Badge(
                        isLabelVisible:
                            _selectedGenreIds.isNotEmpty ||
                            _status != null ||
                            _sort != 'Default',
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_genres.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(context.tr('All')),
                          selected: _selectedGenreIds.isEmpty,
                          onSelected: (_) => _clearGenres(),
                        ),
                      ),
                      for (final genre in _genres.take(8))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(genre.name),
                            selected: _selectedGenreIds.contains(genre.id),
                            onSelected: (_) => _toggleQuickGenre(genre),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _comics.isEmpty)
              SliverFillRemaining(
                child: ApiErrorState(error: _error!, onRetry: _reload),
              )
            else if (comics.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  message: context.tr('No comics match these filters.'),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 820
                        ? 5
                        : width >= 600
                        ? 4
                        : width >= 430
                        ? 3
                        : 2;
                    return SliverGrid.builder(
                      itemCount: comics.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.50,
                      ),
                      itemBuilder: (context, index) {
                        final comic = comics[index];
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 72,
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : _hasMore
                        ? TextButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text(context.tr('Load more')),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _sortOptions = [
    'Default',
    'Recently Added',
    'Recently Updated',
    'Total Views',
    'Most Liked',
    'Most Followed',
    'Most Bookmarked',
  ];

  String _statusLabel(BuildContext context, String status) => switch (status) {
    'ONGOING' => context.tr('Ongoing'),
    'COMPLETED' => context.tr('Completed'),
    _ => status,
  };

  String _sortLabel(BuildContext context, String sort) => switch (sort) {
    'Default' => context.tr('Default'),
    'Recently Added' => context.tr('Recently added'),
    'Recently Updated' => context.tr('Recently updated'),
    'Total Views' => context.tr('Most viewed'),
    'Most Liked' => context.tr('Most liked'),
    'Most Followed' => context.tr('Most followed'),
    'Most Bookmarked' => context.tr('Most bookmarked'),
    _ => sort,
  };
}

class _ExploreFilters {
  const _ExploreFilters({
    required this.genreIds,
    required this.status,
    required this.sort,
  });

  final Set<String> genreIds;
  final String? status;
  final String sort;
}
