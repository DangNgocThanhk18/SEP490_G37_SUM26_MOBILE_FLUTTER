import 'package:flutter/material.dart';

import '../models/comic.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import 'comic_detail_screen.dart';
import 'ranking_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Comic>> _future;
  String _query = '';
  String? _genre;
  String? _status;
  String _sort = 'default';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.getComics();
  }

  void _reload() => setState(() => _future = widget.apiClient.getComics());

  List<Comic> _applyFilters(List<Comic> source) {
    final query = _query.trim().toLowerCase();
    final results = source.where((comic) {
      final matchesQuery = query.isEmpty ||
          comic.title.toLowerCase().contains(query) ||
          (comic.authorName?.toLowerCase().contains(query) ?? false) ||
          comic.genres.any((item) => item.toLowerCase().contains(query));
      final matchesGenre =
          _genre == null || comic.genres.any((item) => item == _genre);
      final matchesStatus = _status == null || comic.status == _status;
      return matchesQuery && matchesGenre && matchesStatus;
    }).toList();
    switch (_sort) {
      case 'rating':
        results.sort(
          (a, b) => (b.ratingAverage ?? 0).compareTo(a.ratingAverage ?? 0),
        );
      case 'views':
        results.sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
      case 'updated':
        results.sort(
          (a, b) => (b.lastChapterUpdatedAt ?? DateTime(1970)).compareTo(
            a.lastChapterUpdatedAt ?? DateTime(1970),
          ),
        );
    }
    return results;
  }

  Future<void> _showFilters(List<Comic> comics) async {
    final genres = comics.expand((comic) => comic.genres).toSet().toList()..sort();
    var genre = _genre;
    var status = _status;
    var sort = _sort;
    final result = await showModalBottomSheet<_ExploreFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 20),
                    Text('Genre', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: genre == null,
                          onSelected: (_) => setModalState(() => genre = null),
                        ),
                        for (final item in genres)
                          ChoiceChip(
                            label: Text(item),
                            selected: genre == item,
                            onSelected: (_) => setModalState(() => genre = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: status == null,
                          onSelected: (_) => setModalState(() => status = null),
                        ),
                        for (final item in const ['ONGOING', 'COMPLETED'])
                          ChoiceChip(
                            label: Text(item.toLowerCase()),
                            selected: status == item,
                            onSelected: (_) => setModalState(() => status = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: sort,
                      decoration: const InputDecoration(labelText: 'Sort by'),
                      items: const [
                        DropdownMenuItem(value: 'default', child: Text('Default')),
                        DropdownMenuItem(value: 'rating', child: Text('Top rated')),
                        DropdownMenuItem(value: 'views', child: Text('Most viewed')),
                        DropdownMenuItem(value: 'updated', child: Text('Recently updated')),
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
                          _ExploreFilters(genre: genre, status: status, sort: sort),
                        ),
                        child: const Text('Show results'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        _genre = result.genre;
        _status = result.status;
        _sort = result.sort;
      });
    }
  }

  void _openComic(Comic comic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComicDetailScreen(apiClient: widget.apiClient, comic: comic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Ranking',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RankingScreen(apiClient: widget.apiClient),
              ),
            ),
            icon: const Icon(Icons.leaderboard_outlined),
          ),
        ],
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
          final comics = _applyFilters(source);
          final genres = source.expand((comic) => comic.genres).toSet().take(8);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              key: const PageStorageKey('explore-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() => _query = value),
                            decoration: const InputDecoration(
                              hintText: 'Search comics, authors, genres...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: () => _showFilters(source),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
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
                            label: const Text('All'),
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
                      ],
                    ),
                  ),
                ),
                if (_genre != null || _status != null || _sort != 'default')
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_genre != null)
                            InputChip(
                              label: Text(_genre!),
                              onDeleted: () => setState(() => _genre = null),
                            ),
                          if (_status != null)
                            InputChip(
                              label: Text(_status!.toLowerCase()),
                              onDeleted: () => setState(() => _status = null),
                            ),
                          if (_sort != 'default')
                            InputChip(
                              label: Text(_sort),
                              onDeleted: () => setState(() => _sort = 'default'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (comics.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      message: 'No comics match these filters.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
                            childAspectRatio: 0.63,
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExploreFilters {
  const _ExploreFilters({required this.genre, required this.status, required this.sort});

  final String? genre;
  final String? status;
  final String sort;
}
