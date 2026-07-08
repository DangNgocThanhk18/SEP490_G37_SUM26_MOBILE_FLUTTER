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

  @override
  void initState() {
    super.initState();
    _futureData = _loadData();
  }

  Future<_ComicDetailData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getComicDetail(widget.comic.id),
      widget.apiClient.getChapters(widget.comic.id),
    ]);
    return _ComicDetailData(
      comic: results[0] as Comic,
      chapters: results[1] as List<ChapterLite>,
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
                      Text(
                        comic.summary?.trim().isNotEmpty == true
                            ? comic.summary!
                            : 'No synopsis yet.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
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
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
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
                            return ListTile(
                              tileColor: const Color(0xFF12101B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Colors.white10),
                              ),
                              title: Text(chapter.title),
                              subtitle: Text(
                                'Chapter ${chapter.chapterNumber}'
                                '${chapter.viewCount == null ? '' : ' - ${chapter.viewCount} views'}',
                              ),
                              trailing: chapter.isPremium
                                  ? const Icon(Icons.workspace_premium_rounded)
                                  : const Icon(Icons.menu_book_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReaderScreen(
                                      apiClient: widget.apiClient,
                                      chapter: chapter,
                                    ),
                                  ),
                                );
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
  });

  final Comic comic;
  final List<ChapterLite> chapters;
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.comic});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    final imageUrl = comic.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF21182E)),
          )
        else
          Container(color: const Color(0xFF21182E)),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFF080511)],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFA855F7).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
