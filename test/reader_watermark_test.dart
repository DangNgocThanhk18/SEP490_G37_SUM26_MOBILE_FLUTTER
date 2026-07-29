import 'package:comiverse_mobile/src/screens/reader_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reader watermark is only retained on iOS', () {
    expect(
      shouldShowReaderWatermark(platform: TargetPlatform.android),
      isFalse,
    );
    expect(shouldShowReaderWatermark(platform: TargetPlatform.iOS), isTrue);
    expect(
      shouldShowReaderWatermark(platform: TargetPlatform.windows),
      isFalse,
    );
  });

  test('viewer identity is masked before it reaches the watermark', () {
    expect(
      maskReaderWatermarkIdentifier('aduha@gmail.com'),
      'adu***@gmail.com',
    );
    expect(maskReaderWatermarkIdentifier('reader123'), 'rea***');
    expect(maskReaderWatermarkIdentifier('ab'), 'a***');
    expect(maskReaderWatermarkIdentifier('  '), isNull);
  });
}
