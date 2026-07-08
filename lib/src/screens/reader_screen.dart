import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../services/api_client.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiClient,
    required this.chapter,
  });

  final ApiClient apiClient;
  final ChapterLite chapter;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<ChapterDetail> _futureChapter;

  @override
  void initState() {
    super.initState();
    _futureChapter = widget.apiClient.getChapterDetail(widget.chapter.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.chapter.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            padding: EdgeInsets.zero,
            itemCount: chapter.images.length,
            itemBuilder: (context, index) {
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
