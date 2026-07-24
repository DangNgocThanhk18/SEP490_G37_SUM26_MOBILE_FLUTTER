import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/comic.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import 'comic_detail_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String _timeframe = 'day';
  late Future<List<Comic>> _future = _load();

  Future<List<Comic>> _load() =>
      widget.apiClient.getLeaderboard(timeframe: _timeframe);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Ranking'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'day', label: Text(context.tr('Daily'))),
                  ButtonSegment(
                    value: 'week',
                    label: Text(context.tr('Weekly')),
                  ),
                  ButtonSegment(
                    value: 'month',
                    label: Text(context.tr('Monthly')),
                  ),
                ],
                selected: {_timeframe},
                onSelectionChanged: (value) {
                  _timeframe = value.first;
                  _reload();
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Comic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ApiErrorState(
                    error: snapshot.error!,
                    onRetry: _reload,
                  );
                }
                final comics = snapshot.data ?? const [];
                if (comics.isEmpty) {
                  return EmptyState(
                    icon: Icons.leaderboard_outlined,
                    message: context.tr('Ranking data is not available yet.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: comics.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final comic = comics[index];
                      return ComicListRow(
                        comic: comic,
                        leading: SizedBox(
                          width: 32,
                          child: Text(
                            '#${index + 1}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: index < 3
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              index.isEven
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.remove_rounded,
                              color: index.isEven
                                  ? Colors.green
                                  : scheme.outline,
                            ),
                            if (comic.ratingAverage != null)
                              Text(comic.ratingAverage!.toStringAsFixed(1)),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ComicDetailScreen(
                              apiClient: widget.apiClient,
                              comic: comic,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
