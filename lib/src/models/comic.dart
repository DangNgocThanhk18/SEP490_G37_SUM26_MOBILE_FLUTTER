class Comic {
  const Comic({
    required this.id,
    required this.title,
    this.summary,
    this.authorName,
    this.cover,
    this.thumbnail,
    this.status,
    this.latestChapterNumber,
    this.viewCount,
    this.ratingAverage,
    this.likeCount,
    this.saveCount,
    this.chapterCount,
    this.lastChapterUpdatedAt,
    this.genres = const [],
  });

  final String id;
  final String title;
  final String? summary;
  final String? authorName;
  final String? cover;
  final String? thumbnail;
  final String? status;
  final String? latestChapterNumber;
  final int? viewCount;
  final double? ratingAverage;
  final int? likeCount;
  final int? saveCount;
  final int? chapterCount;
  final DateTime? lastChapterUpdatedAt;
  final List<String> genres;

  String? get imageUrl {
    final candidate = thumbnail?.trim().isNotEmpty == true ? thumbnail : cover;
    return candidate?.trim().isNotEmpty == true ? candidate : null;
  }

  factory Comic.fromJson(Map<String, dynamic> json) {
    return Comic(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled comic').toString(),
      summary: json['summary']?.toString(),
      authorName: json['authorName']?.toString(),
      cover: json['cover']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      status: json['status']?.toString(),
      latestChapterNumber: json['latestChapterNumber']?.toString(),
      viewCount: _asInt(json['viewCount']),
      ratingAverage: _asDouble(json['ratingAverage']),
      likeCount: _asInt(json['likeCount']),
      saveCount: _asInt(json['saveCount']),
      chapterCount: _asInt(json['chapterCount']),
      lastChapterUpdatedAt: DateTime.tryParse(
        (json['lastChapterUpdatedAt'] ?? '').toString(),
      ),
      genres: _parseGenres(json['genres']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static List<String> _parseGenres(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return (item['name'] ?? item['title'] ?? '').toString();
          }
          return item.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }
}
