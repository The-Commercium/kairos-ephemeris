# kairos_ephemeris

Where the Sun, the Moon and the planets are, in pure Dart.

`kairos_ephemeris` computes apparent geocentric positions of the Sun, the Moon and the planets from Mercury to Pluto, the lunar nodes, house cusps, moon phases and the next new and full moon. It is plain Dart: no native code, no FFI, no data files and no network, so it runs the same on iOS, Android, macOS, Windows, Linux and the web. It is MIT licensed.

We wrote it for [Kairos](https://kai-ros.life), our app that draws the sky of any moment, and we check it on every release against the [Swiss Ephemeris](https://www.astro.com/swisseph/), the reference library in this field.

## Why it exists

Most apps that need planetary positions use the Swiss Ephemeris. It is excellent, but it is a C library: in a Flutter app it comes in through FFI on each native platform and WebAssembly on the web. It is also dual licensed: AGPL, which asks the whole app to be AGPL, or a paid professional licence from Astrodienst. We wanted a small engine in plain Dart with a permissive licence, and a test that tells us how far it is from the reference.

## Use

```yaml
dependencies:
  kairos_ephemeris: ^0.1.0
```

```dart
import 'package:kairos_ephemeris/kairos_ephemeris.dart';

final at = Instant.utc(DateTime.utc(2026, 10, 12, 12));

for (final p in positions(at)) {
  print('${p.body.name} ${p.lon.toStringAsFixed(4)}° ${p.retrograde ? 'retrograde' : ''}');
}

// Latitude north, longitude east of Greenwich (London here).
final houses = computeHouses(at, 51.5074, -0.1278, HouseSystem.placidus);
print('Ascendant ${houses.asc}, Midheaven ${houses.mc}');

final moon = Lunation.at(DateTime.utc(2026, 10, 12, 12));
print('${moon.phase.name}, ${(moon.lit * 100).round()}% lit, next full moon ${moon.nextFull}');
```

Longitudes are apparent, geocentric, tropical (ecliptic and equinox of date), in degrees. Speeds are in degrees per day, and a negative speed means retrograde motion. `example/main.dart` prints a full set.

## Accuracy

`test/ephemeris_test.dart` is the release gate. It compares the engine with the Swiss Ephemeris 2.10.03 (Moshier mode, apparent geocentric, tropical) at 400 random moments between 1850 and 2149, at random places between latitude 60° south and 65° north plus five fixed cities. Worst differences over all 400 cases, in arcminutes (one arcminute is 1/60 of a degree):

| Body | Longitude | Latitude |
|---|---|---|
| Sun | 0.160′ | 0.038′ |
| Moon (to 2025) | 0.081′ | 0.180′ |
| Mercury | 0.328′ | 0.160′ |
| Venus | 0.253′ | 0.144′ |
| Mars | 0.188′ | 0.189′ |
| Jupiter | 0.164′ | 0.195′ |
| Saturn | 0.207′ | 0.363′ |
| Uranus | 0.193′ | 0.306′ |
| Neptune | 0.345′ | 0.162′ |
| Pluto | 0.274′ | 0.070′ |
| Mean node | 0.008′ | |
| True node | 0.650′ | |
| Mean lunar apogee | 0.032′ | |

House cusps (Placidus, whole sign, equal), Ascendant and Midheaven: worst 0.091′. The retrograde flag matched the reference in every case.

**Dates after today.** Clocks follow the Earth's rotation, which slows irregularly, so the difference between atomic time and Earth time (Delta T) is measured for the past and only forecast for the future. This engine and the Swiss Ephemeris forecast it differently. The Moon moves fastest, so it shows the gap: up to 2025 the two agree within 0.08′, while by 2149 they differ by up to 2′. The test widens the Moon's limit with the years past 2025. Neither forecast is known to be right.

## Range and limits

- Dates from 1800 to 2199 (`ephemerisStart`, `ephemerisEnd`). Pluto is tabulated from 1799 to 2201.
- Geocentric only: no topocentric correction for the observer's position on the Earth.
- No asteroids, no fixed stars and no sidereal zodiacs.
- Placidus houses are undefined inside the polar circles; there the engine uses Porphyry and sets `Houses.fellBack`.
- Positions are good to well under an arcminute against the reference. That is ample for drawing and labelling the sky, but it is not meant for eclipse paths, occultations or navigation.

## How it works

- **Planets:** truncated VSOP87 series (Bretagnon and Francou), as published in [Astronomy Engine](https://github.com/cosinekitty/astronomy) by Don Cross, with light time, annual aberration, precession to the ecliptic of date (Meeus, *Astronomical Algorithms*, 21.5) and nutation (Meeus, chapter 22).
- **Moon:** the Montenbruck and Pfleger lunar theory, as ported by Astronomy Engine.
- **Pluto:** Astronomy Engine's gravity-simulated orbit, sampled every 20 days and interpolated.
- **Nodes and apogee:** mean elements from Meeus, chapter 47; the true node is the osculating node of the Moon's instantaneous orbit.
- **Time:** Delta T from the Espenak and Meeus polynomials.
- **Houses:** apparent sidereal time (IAU 1982 with the equation of the equinoxes), Placidus by iteration.

## Tools

- `tool/gen_tables.py` regenerates `lib/src/gen/` from the Python release of Astronomy Engine.
- `tool/make_reference.py` regenerates `test/reference.json`. It needs [pyswisseph](https://github.com/astrorigin/pyswisseph), which is AGPL licensed. It is a development tool only: nothing from the Swiss Ephemeris is part of this package or a dependency of it, and the reference file holds only the computed positions.

## Licence

MIT, see [LICENSE](LICENSE). The generated tables come from Astronomy Engine, also MIT; its notice is included in the same file.

Made by [Commercium](https://thecommercium.com), an independent app studio in London.
