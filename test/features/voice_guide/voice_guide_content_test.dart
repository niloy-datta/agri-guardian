import 'package:flutter_test/flutter_test.dart';

import 'package:agri_guardian/features/voice_guide/domain/voice_guide_content.dart';

void main() {
  group('guideForPath', () {
    test('finds the home, tab and focused-screen guides', () {
      expect(guideForPath('/')?.title, 'হোম পাতা');
      expect(guideForPath('/fields')?.title, 'আমার জমি');
      expect(guideForPath('/scan')?.title, 'ফসল স্ক্যান');
      expect(guideForPath('/ai-assistant')?.title, 'কৃষি সহকারী');
    });

    test('matches a dynamic field-details route by any id', () {
      expect(guideForPath('/field-details/abc-123')?.title, 'জমির বিস্তারিত');
    });

    test('returns null for a route with no guide', () {
      expect(guideForPath('/no-such-page'), isNull);
    });

    test('every guide has at least one spoken line', () {
      for (final guide in screenGuides) {
        expect(guide.lines, isNotEmpty, reason: guide.title);
      }
    });
  });

  group('tourGuides', () {
    test('visits only concrete paths that resolve back to their own guide', () {
      expect(tourGuides, isNotEmpty);
      for (final guide in tourGuides) {
        expect(
          guideForPath(guide.navPath!),
          same(guide),
          reason: 'tour path ${guide.navPath} should map to ${guide.title}',
        );
      }
    });
  });
}
