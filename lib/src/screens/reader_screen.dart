import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../services/api_client.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiClient,
    required this.chapters,
    required this.initialIndex,
  });

  final ApiClient apiClient;
  final List<ChapterLite> chapters;
  final int initialIndex;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<ChapterDetail> _futureChapter;
  late int _currentIndex;

  ChapterLite get _chapter => widget.chapters[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex
        .clamp(0, widget.chapters.length - 1)
        .toInt();
    _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
  }

  void _openChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _currentIndex = index;
      _futureChapter = widget.apiClient.getChapterDetail(_chapter.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Previous chapter',
            onPressed: _currentIndex > 0
                ? () => _openChapter(_currentIndex - 1)
                : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            tooltip: 'Next chapter',
            onPressed: _currentIndex < widget.chapters.length - 1
                ? () => _openChapter(_currentIndex + 1)
                : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
      body: FutureBuilder<ChapterDetail>(
        future: _futureChapter,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF9DA8)),
                ),
              ),
            );
          }

          final chapter = snapshot.data;
          if (chapter == null || chapter.images.isEmpty) {
            return const Center(child: Text('No chapter images found.'));
          }

          return ListView.builder(
            key: ValueKey(chapter.id),
            padding: EdgeInsets.zero,
            itemCount: chapter.images.length + 1,
            itemBuilder: (context, index) {
              if (index == chapter.images.length) {
                return _ChapterFooter(
                  hasPrevious: _currentIndex > 0,
                  hasNext: _currentIndex < widget.chapters.length - 1,
                  onPrevious: () => _openChapter(_currentIndex - 1),
                  onNext: () => _openChapter(_currentIndex + 1),
                );
              }
              final imageUrl = chapter.images[index];
              return Image.network(
                imageUrl,
                fit: BoxFit.fitWidth,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return AspectRatio(
                    aspectRatio: 0.7,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: const Color(0xFF18121F),
                  child: Text('Cannot load page ${index + 1}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChapterFooter extends StatelessWidget {
  const _ChapterFooter({
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasPrevious ? onPrevious : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasNext ? onNext : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
