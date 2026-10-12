// The Moon's phase and the next new and full moons, from the same ephemeris as the chart.
import 'dart:math' as math;

import 'ephemeris.dart';

enum MoonPhase { newMoon, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent }

class Lunation {
  Lunation._(this.elongation, this.nextNew, this.nextFull);

  /// Moon minus Sun, degrees [0, 360).
  final double elongation;
  final DateTime nextNew, nextFull;

  /// Share of the disc that is lit, 0..1.
  double get lit => (1 - math.cos(elongation * deg)) / 2;
  bool get waxing => elongation < 180;
  MoonPhase get phase => MoonPhase.values[((elongation + 22.5) % 360 / 45).floor()];

  factory Lunation.at(DateTime utc) =>
      Lunation._(moonSunElongation(Instant.utc(utc)), nextElongation(utc, 0), nextElongation(utc, 180));
}

/// The first moment after [from] when the Moon stands [target] degrees from the Sun.
/// Day steps find the crossing, bisection pins it within a few seconds.
DateTime nextElongation(DateTime from, double target) {
  double f(DateTime t) => angleDiff(moonSunElongation(Instant.utc(t)), target);
  var a = from, fa = f(a);
  for (var i = 0; i < 35; i++) {
    final b = a.add(const Duration(days: 1));
    final fb = f(b);
    if (fa < 0 && fb >= 0 && fb - fa < 90) {
      var lo = a, hi = b;
      for (var k = 0; k < 16; k++) {
        final mid = lo.add(Duration(microseconds: hi.difference(lo).inMicroseconds ~/ 2));
        if (f(mid) < 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }
    a = b;
    fa = fb;
  }
  return a;
}
