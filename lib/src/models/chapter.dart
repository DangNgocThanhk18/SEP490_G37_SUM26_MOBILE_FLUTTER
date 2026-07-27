import 'dart:convert';

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

/// A single point of a freeform (polygon) bubble outline, stored as a
/// percentage of the page image's displayed width/height — same basis
/// used throughout the web translator/review workspaces.
class BubblePoint {
  const BubblePoint(this.x, this.y);

  final double x;
  final double y;

  factory BubblePoint.fromJson(Map<String, dynamic> json) {
    return BubblePoint(_asDouble(json['x']), _asDouble(json['y']));
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// A simple percent-based bounding box (x/y/width/height, all 0-100).
class BubbleBoundingBox {
  const BubbleBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// One translated speech bubble, as drawn by a translator and approved by
/// their team Leader. Coordinates/fontSize are all percentages of the
/// page's displayed size, matching the web reader/translate workspaces.
class BubbleSelection {
  const BubbleSelection({
    required this.id,
    required this.shape,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.points = const [],
    this.translation,
    this.textColor,
    this.textBgColor,
    this.fontSize,
    this.isBold = false,
    this.isItalic = false,
    this.textAlign,
    this.fontFamily,
  });

  final String id;
  final String shape; // 'rect' | 'ellipse' | 'polygon'
  final double x;
  final double y;
  final double width;
  final double height;
  final List<BubblePoint> points; // only populated for shape == 'polygon'
  final String? translation;
  final String? textColor;
  final String? textBgColor;
  final double? fontSize; // percent of the page's displayed height
  final bool isBold;
  final bool isItalic;
  final String? textAlign; // 'left' | 'center' | 'right'
  final String? fontFamily;

  /// Bounding box in percent-of-image coordinates. For polygons this is
  /// derived from the min/max of all points — mirrors getBoundingBox() on
  /// the web.
  BubbleBoundingBox get boundingBox {
    if (shape == 'polygon' && points.isNotEmpty) {
      final xs = points.map((p) => p.x);
      final ys = points.map((p) => p.y);
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);
      return BubbleBoundingBox(
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
      );
    }
    return BubbleBoundingBox(x: x, y: y, width: width, height: height);
  }

  factory BubbleSelection.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = rawPoints is List
        ? rawPoints
        .whereType<Map<String, dynamic>>()
        .map(BubblePoint.fromJson)
        .toList()
        : <BubblePoint>[];
    return BubbleSelection(
      id: (json['id'] ?? '').toString(),
      shape: (json['shape'] ?? 'rect').toString(),
      x: _asDouble(json['x']),
      y: _asDouble(json['y']),
      width: _asDouble(json['width']),
      height: _asDouble(json['height']),
      points: points,
      translation: json['translation']?.toString(),
      textColor: json['textColor']?.toString(),
      textBgColor: json['textBgColor']?.toString(),
      fontSize: json['fontSize'] == null ? null : _asDouble(json['fontSize']),
      isBold: json['isBold'] == true,
      isItalic: json['isItalic'] == true,
      textAlign: json['textAlign']?.toString(),
      fontFamily: json['fontFamily']?.toString(),
    );
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TranslatedPage {
  const TranslatedPage({
    required this.pageNumber,
    required this.imageUrl,
    required this.bubbles,
  });

  final int pageNumber;
  final String imageUrl;
  final List<BubbleSelection> bubbles;

  factory TranslatedPage.fromJson(Map<String, dynamic> json) {
    var bubbles = <BubbleSelection>[];
    final rawBubbles = json['bubbles'];
    if (rawBubbles is String && rawBubbles.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBubbles);
        List<dynamic> selections;
        if (decoded is List) {
          selections = decoded;
        } else if (decoded is Map && decoded['selections'] is List) {
          selections = decoded['selections'] as List;
        } else {
          selections = const [];
        }
        bubbles = selections
            .whereType<Map<String, dynamic>>()
            .map(BubbleSelection.fromJson)
            .toList();
      } catch (_) {
        bubbles = const [];
      }
    }
    return TranslatedPage(
      pageNumber: int.tryParse((json['pageNumber'] ?? '0').toString()) ?? 0,
      imageUrl: (json['imageUrl'] ?? '').toString(),
      bubbles: bubbles,
    );
  }
}

class ChapterTranslation {
  const ChapterTranslation({
    required this.id,
    required this.languageCode,
    required this.pages,
  });

  final String id;
  final String languageCode;
  final List<TranslatedPage> pages;

  factory ChapterTranslation.fromJson(Map<String, dynamic> json) {
    var pages = <TranslatedPage>[];
    final rawPagesBubbles = json['pagesBubbles'];
    if (rawPagesBubbles is String && rawPagesBubbles.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPagesBubbles);
        if (decoded is List) {
          pages = decoded
              .whereType<Map<String, dynamic>>()
              .map(TranslatedPage.fromJson)
              .toList();
        }
      } catch (_) {
        pages = const [];
      }
    }
    return ChapterTranslation(
      id: (json['id'] ?? '').toString(),
      languageCode: (json['languageCode'] ?? '').toString(),
      pages: pages,
    );
  }

  List<BubbleSelection> bubblesForPage(int pageNumber) {
    for (final page in pages) {
      if (page.pageNumber == pageNumber) return page.bubbles;
    }
    return const [];
  }
}