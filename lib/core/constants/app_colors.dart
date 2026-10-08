import 'package:flutter/material.dart';

/// Semantic Design System Palette for PRANA.
///
/// The canvas is warm linen rather than clinical white: a health companion you
/// live with all day should read as paper, not as a monitor. Brand accents are
/// forest green through sage mint — calm, and it lets the risk spectrum
/// (ochre → orange → red) own "something needs attention" without competing.
///
/// Contrast note: every colour used for *text* on [background] or [surface]
/// clears 4.5:1. The lighter sage tones ([accent], [mintDeep]) are fill-only —
/// never put body copy on them.
class AppColors {
  AppColors._();

  // ─── Brand: forest green → sage mint ──────────────────────────────────────
  static const Color primary = Color(0xFF2F5D50);
  static const Color primaryLight = Color(0xFF4E8267);
  static const Color primaryDark = Color(0xFF1E3D34);
  static const Color primaryContainer = Color(0xFFD9E8CE);
  static const Color onPrimary = Colors.white;

  /// Sage mint. Fill and illustration only — too light for text.
  static const Color accent = Color(0xFFA8C8A0);

  /// Mint wash for hero cards and selected chips.
  static const Color mint = Color(0xFFD9E8CE);

  /// The deeper edge of the mint ramp, for gradients and sparkline strokes.
  static const Color mintDeep = Color(0xFF8FB585);

  // ─── Canvas & surfaces ────────────────────────────────────────────────────
  static const Color background = Color(0xFFF2EEE6);   // warm linen
  static const Color surface = Color(0xFFFDFBF7);       // off-white card
  static const Color surfaceElevated = Color(0xFFFFFEFB);
  static const Color surfaceSubtle = Color(0xFFF5F1E8);
  static const Color surfaceMuted = Color(0xFFFAF7F0);
  static const Color surfaceHero = Color(0xFFF7F3EA);
  static const Color surfaceDark = Color(0xFF22261F);   // ink surface: pill buttons, mono

  /// Recessed wells — search fields, chart backdrops, progress tracks.
  static const Color surfaceWell = Color(0xFFEAE5DA);

  /// Shadow base — warm near-black so elevation reads as soft paper lift.
  static const Color shadow = Color(0xFF2A2A20);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const List<Color> gradientPrimary = [
    Color(0xFF2F5D50),
    Color(0xFF4E8267),
  ];
  static const List<Color> gradientCritical = [
    Color(0xFFDC2626),
    Color(0xFFEF4444),
  ];
  static const List<Color> gradientDark = [
    Color(0xFF2A2E26),
    Color(0xFF181B15),
  ];

  /// Mint hero wash — the calm "everything is fine" surface.
  static const List<Color> gradientMint = [
    Color(0xFFDFEDD4),
    Color(0xFFBFD9AE),
  ];

  /// Warm cream wash for large feature cards on the linen canvas.
  static const List<Color> gradientCream = [
    Color(0xFFFDFBF7),
    Color(0xFFF3EDE0),
  ];

  // ─── Typography ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1C2118);   // near-black, green cast
  static const Color textSecondary = Color(0xFF6F6F62);
  static const Color textTertiary = Color(0xFF9C9A8E);
  static const Color textInverse = Color(0xFFFFFFFF);

  // ─── Borders & dividers ───────────────────────────────────────────────────
  static const Color border = Color(0xFFE5DFD2);
  static const Color borderLight = Color(0xFFEFEAE0);
  static const Color borderDark = Color(0xFF3A4034);

  // ─── Semantic risk spectrum ───────────────────────────────────────────────
  // Safe deliberately shares the brand's green family: the app's resting state
  // and its "you're fine" state should feel like the same thing.
  static const Color riskSafe = Color(0xFF43855A);
  static const Color riskSafeBg = Color(0xFFE9F1E4);
  static const Color riskModerate = Color(0xFFD99518);
  static const Color riskModerateBg = Color(0xFFFBF2DF);
  static const Color riskHigh = Color(0xFFF97316);
  static const Color riskHighBg = Color(0xFFFCEBDD);
  static const Color riskCritical = Color(0xFFEF4444);
  static const Color riskCriticalBg = Color(0xFFFBE7E4);

  // ─── Biometric domain accents ─────────────────────────────────────────────
  // Saturated glyph colour + a very soft pastel chip behind it.
  static const Color heartRate = Color(0xFFE11D48);
  static const Color heartRateBg = Color(0xFFFDEAEE);
  static const Color spo2 = Color(0xFF2D7A99);
  static const Color spo2Bg = Color(0xFFE5EFF3);
  static const Color temperature = Color(0xFFC87137);
  static const Color temperatureBg = Color(0xFFF9EDE1);
  static const Color activity = Color(0xFF4F8A3F);
  static const Color activityBg = Color(0xFFECF2E1);
  static const Color sleep = Color(0xFF6B5CA5);
  static const Color sleepBg = Color(0xFFEEEBF7);

  // ─── Environmental metrics ────────────────────────────────────────────────
  static const Color aqi = Color(0xFF7A5EA8);
  static const Color aqiBg = Color(0xFFEDE9F6);
  static const Color humidity = Color(0xFF2E8C9E);
  static const Color humidityBg = Color(0xFFE3F1F3);
  static const Color heatIndex = Color(0xFFD9662B);
  static const Color heatIndexBg = Color(0xFFFAEBE1);

  // ─── Status & connectivity ────────────────────────────────────────────────
  static const Color online = Color(0xFF43855A);
  static const Color offline = Color(0xFF9C9A8E);
  static const Color syncing = Color(0xFF2D7A99);
  static const Color bleConnected = Color(0xFF2D7A99);
  static const Color bleScanning = Color(0xFF7A5EA8);
}
