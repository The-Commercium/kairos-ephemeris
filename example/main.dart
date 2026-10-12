import 'package:kairos_ephemeris/kairos_ephemeris.dart';

void main() {
  final at = Instant.utc(DateTime.utc(2026, 10, 12, 12));

  for (final p in positions(at)) {
    final r = p.retrograde ? ' (retrograde)' : '';
    print('${p.body.name.padRight(9)} ${p.lon.toStringAsFixed(4)}°$r');
  }

  // London: latitude north, longitude east of Greenwich.
  final h = computeHouses(at, 51.5074, -0.1278, HouseSystem.placidus);
  print('Ascendant ${h.asc.toStringAsFixed(4)}°, Midheaven ${h.mc.toStringAsFixed(4)}°');

  final moon = Lunation.at(DateTime.utc(2026, 10, 12, 12));
  print('Moon ${moon.phase.name}, ${(moon.lit * 100).round()}% lit, next full ${moon.nextFull}');
}
