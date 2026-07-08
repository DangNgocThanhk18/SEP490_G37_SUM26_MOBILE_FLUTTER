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
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onSignOut;

  @override
  State<ComicsScreen> createState() => _ComicsScreenState();
}

class _ComicsScreenState extends State<ComicsScreen> {
  late Future<List<Comic>> _futureComics;

  @override
  void initState() {
    super.initState();
    _futureComics = widget.apiClient.getComics();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureComics = widget.apiClient.getComics();
    });
    await _futureComics;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ComiVerse'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  user.displayName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            tooltip: user == null ? 'Back to login' : 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
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

            final comics = snapshot.data ?? const [];
            if (comics.isEmpty) {
              return _ErrorState(
                message: 'No comics found from backend.',
                onRetry: _refresh,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: comics.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HeaderCard(user: user);
                }
                final comic = comics[index - 1];
                return _ComicListTile(
                  comic: comic,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ComicDetailScreen(
                          apiClient: widget.apiClient,
                          comic: comic,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF221335), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user == null ? 'Read as guest' : 'Hi, ${user!.displayName}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse published comics from the Spring Boot backend and open chapters directly on Android.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
          ),
        ],
      ),
    );
  }
}

class _ComicListTile extends StatelessWidget {
  const _ComicListTile({
    required this.comic,
    required this.onTap,
  });

  final Comic comic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12101B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (comic.status != null) _MetaChip(label: comic.status!),
                      if (comic.latestChapterNumber != null)
                        _MetaChip(label: 'Ch ${comic.latestChapterNumber}'),
                      if (comic.ratingAverage != null)
                        _MetaChip(
                          label: comic.ratingAverage!.toStringAsFixed(1),
                          icon: Icons.star_rounded,
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
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFA855F7).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFFFBBF24)),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF21182E),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off_rounded, size: 58, color: Color(0xFFFF9DA8)),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
