// Generates the PRANA Android launcher icons at all five densities.
//
//   dart run tool/generate_launcher_icons.dart
//
// Draws the brand mark — a soft breath ring with a heartbeat pulse — in mint
// on a deep-forest rounded disc, matching the in-app PranaLogo and splash. Uses
// the pure-Dart `image` package already in the lock file; no native tooling,
// no flutter_launcher_icons dependency.

import 'dart:io';
import 'dart:math' as math;

// `image` is a transitive dependency (pulled in via the pdf package). This is a
// one-off build-time script, not shipped app code, so relying on it is fine.
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;

// Brand palette (same values as lib/core/constants/app_colors.dart).
const _forestDark = 0xFF1E3D34; // primaryDark  (disc top)
const _forestDeep = 0xFF152B25; // slightly deeper (disc bottom)
const _mint = 0xFFA8C8A0; // accent (pulse)
const _ringLight = 0xFFFFFFFF; // ring highlight

// density -> icon px (standard Android launcher sizes)
const _sizes = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

int _a(int argb) => (argb >> 24) & 0xFF;
int _r(int argb) => (argb >> 16) & 0xFF;
int _g(int argb) => (argb >> 8) & 0xFF;
int _b(int argb) => argb & 0xFF;

img.Color _c(int argb, [double alpha = 1.0]) => img.ColorRgba8(
      _r(argb),
      _g(argb),
      _b(argb),
      (_a(argb) * alpha).round().clamp(0, 255),
    );

void main() async {
  const master = 512; // render large, downscale per density for clean edges
  final canvas = _renderIcon(master);

  final root = Directory('android/app/src/main/res');
  for (final entry in _sizes.entries) {
    final resized = img.copyResize(
      canvas,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final dir = Directory('${root.path}/mipmap-${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/ic_launcher.png');
    file.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('Wrote ${file.path} (${entry.value}x${entry.value})');
  }
  stdout.writeln('Done.');
}

img.Image _renderIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0)); // transparent

  final cx = size / 2.0;
  final cy = size / 2.0;
  final radius = size * 0.5; // full-bleed disc (Android masks to its own shape)

  // ── Rounded disc with a vertical forest gradient ──
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x + 0.5 - cx;
      final dy = y + 0.5 - cy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > radius) continue;
      // vertical lerp forestDark -> forestDeep
      final t = y / size;
      final rr = (_r(_forestDark) * (1 - t) + _r(_forestDeep) * t).round();
      final gg = (_g(_forestDark) * (1 - t) + _g(_forestDeep) * t).round();
      final bb = (_b(_forestDark) * (1 - t) + _b(_forestDeep) * t).round();
      // Anti-alias the disc edge over ~1.5px.
      final edge = (radius - dist).clamp(0.0, 1.5) / 1.5;
      image.setPixel(x, y, img.ColorRgba8(rr, gg, bb, (255 * edge).round()));
    }
  }

  // ── Breath ring (open arc) ──
  final ringR = size * 0.30;
  final ringW = size * 0.055;
  _drawArc(image, cx, cy, ringR, ringW,
      startRad: math.pi * 0.62,
      sweepRad: math.pi * 1.76,
      color: _ringLight,
      alpha: 0.85);

  // Inner thin accent arc.
  _drawArc(image, cx, cy, ringR - ringW * 1.1, ringW * 0.5,
      startRad: math.pi * 0.72,
      sweepRad: math.pi * 1.56,
      color: _mint,
      alpha: 0.9);

  // ── Heartbeat pulse across the middle ──
  final w = size.toDouble();
  final midY = cy;
  final pts = <List<double>>[
    [w * 0.22, midY],
    [w * 0.36, midY],
    [w * 0.41, midY - w * 0.05],
    [w * 0.47, midY + w * 0.17],
    [w * 0.54, midY - w * 0.26],
    [w * 0.61, midY + w * 0.07],
    [w * 0.66, midY],
    [w * 0.78, midY],
  ];
  final pulseW = size * 0.05;
  for (var i = 0; i < pts.length - 1; i++) {
    _thickLine(image, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1],
        pulseW, _mint);
  }

  return image;
}

/// Stroke an arc by stamping small discs along it (simple, artifact-free at
/// icon resolution).
void _drawArc(
  img.Image image,
  double cx,
  double cy,
  double r,
  double strokeW, {
  required double startRad,
  required double sweepRad,
  required int color,
  double alpha = 1.0,
}) {
  final steps = (sweepRad * r).clamp(24, 4000).round();
  final half = strokeW / 2.0;
  for (var i = 0; i <= steps; i++) {
    final a = startRad + sweepRad * (i / steps);
    final px = cx + math.cos(a) * r;
    final py = cy + math.sin(a) * r;
    _disc(image, px, py, half, color, alpha);
  }
}

/// Thick anti-aliased line via disc stamping along the segment.
void _thickLine(img.Image image, double x0, double y0, double x1, double y1,
    double strokeW, int color) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len = math.sqrt(dx * dx + dy * dy);
  final steps = len.clamp(1, 4000).round();
  final half = strokeW / 2.0;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    _disc(image, x0 + dx * t, y0 + dy * t, half, color, 1.0);
  }
}

/// Alpha-composite a filled, edge-antialiased disc onto the image.
void _disc(img.Image image, double cx, double cy, double radius, int color,
    double alpha) {
  final minX = (cx - radius - 1).floor().clamp(0, image.width - 1);
  final maxX = (cx + radius + 1).ceil().clamp(0, image.width - 1);
  final minY = (cy - radius - 1).floor().clamp(0, image.height - 1);
  final maxY = (cy + radius + 1).ceil().clamp(0, image.height - 1);
  final src = _c(color, alpha);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final d = math.sqrt(math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2));
      final cover = (radius - d).clamp(0.0, 1.0); // 1px AA edge
      if (cover <= 0) continue;
      final s = img.ColorRgba8(src.r.toInt(), src.g.toInt(), src.b.toInt(),
          (src.a * cover).round());
      image.setPixel(x, y, _over(s, image.getPixel(x, y)));
    }
  }
}

/// Straight-alpha "source over" composite.
img.Color _over(img.Color s, img.Color d) {
  final sa = s.a / 255.0;
  final da = d.a / 255.0;
  final outA = sa + da * (1 - sa);
  if (outA <= 0) return img.ColorRgba8(0, 0, 0, 0);
  int ch(num sc, num dc) =>
      ((sc * sa + dc * da * (1 - sa)) / outA).round().clamp(0, 255);
  return img.ColorRgba8(
    ch(s.r, d.r),
    ch(s.g, d.g),
    ch(s.b, d.b),
    (outA * 255).round(),
  );
}
