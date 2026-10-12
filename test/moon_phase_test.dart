import 'package:test/test.dart';
import 'package:kairos_ephemeris/kairos_ephemeris.dart';

void main() {
  test('new moon of the 2024-04-08 total solar eclipse (18:21 UTC)', () {
    final t = nextElongation(DateTime.utc(2024, 4, 1), 0);
    expect(t.difference(DateTime.utc(2024, 4, 8, 18, 21)).inMinutes.abs(), lessThanOrEqualTo(3));
  });

  test('full moon of the 2025-03-14 total lunar eclipse (06:55 UTC)', () {
    final t = nextElongation(DateTime.utc(2025, 3, 1), 180);
    expect(t.difference(DateTime.utc(2025, 3, 14, 6, 55)).inMinutes.abs(), lessThanOrEqualTo(3));
  });

  test('lunations are 29.2 to 29.9 days and land on the target', () {
    var t = DateTime.utc(1900, 1, 1);
    for (var i = 0; i < 40; i++) {
      final next = nextElongation(t.add(const Duration(hours: 1)), 0);
      if (i > 0) {
        final days = next.difference(t).inMinutes / 1440;
        expect(days, inInclusiveRange(29.2, 29.9));
      }
      expect(angleDiff(moonSunElongation(Instant.utc(next)), 0).abs(), lessThan(0.01));
      t = next;
    }
  });

  test('phase names follow the elongation', () {
    final l = Lunation.at(DateTime.utc(2025, 3, 14, 6, 55));
    expect(l.phase, MoonPhase.full);
    expect(l.lit, greaterThan(0.99));
  });
}
