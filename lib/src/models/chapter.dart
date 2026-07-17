class ChapterLite {
  const ChapterLite({
    required this.id,
    required this.comicId,
    required this.chapterNumber,
    required this.title,
    this.viewCount,
    this.isPremium = false,
    this.createdAt,
  });

  final String id;
  final String comicId;
  final String chapterNumber;
  final String title;
  final int? viewCount;
  final bool isPremium;
  final DateTime? createdAt;

  factory ChapterLite.fromJson(Map<String, dynamic> json) {
    final number = (json['chapterNumber'] ?? json['num'] ?? '').toString();
    return ChapterLite(
      id: (json['id'] ?? '').toString(),
      comicId: (json['comicId'] ?? '').toString(),
      chapterNumber: number,
      title: (json['title'] ?? 'Chapter $number').toString(),
      viewCount: _asInt(json['viewCount']),
      isPremium: json['isPremium'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class ChapterDetail {
  const ChapterDetail({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.images,
  });

  final String id;
  final String title;
  final String chapterNumber;
  final List<String> images;

  factory ChapterDetail.fromJson(Map<String, dynamic> json) {
    final number = (json['chapterNumber'] ?? json['num'] ?? '').toString();
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages
            .map((item) => item.toString())
            .where((url) => url.trim().isNotEmpty)
            .toList()
        : <String>[];

    return ChapterDetail(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Chapter $number').toString(),
      chapterNumber: number,
      images: images,
    );
  }
}
