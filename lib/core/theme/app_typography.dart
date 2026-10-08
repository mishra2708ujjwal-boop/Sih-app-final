import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Typography system for PRANA.
///
/// The reference language is a geometric sans with tight tracking and very
/// large display numerals. No font asset is bundled and the app is offline-only
/// (so a runtime font fetch is out), which means this leans on the platform
/// face — Roboto on Android — and gets the character from *size, weight and
/// letter-spacing* instead of from a typeface.
///
/// Every style carries an explicit `height` so vertical rhythm is predictable
/// when styles are mixed inside a Column. Supporting sizes stay at 12px or
/// above — below that, readings become hard to scan on a phone held at arm's
/// length, which is exactly the situation this app is used in.
class AppTypography {
  AppTypography._();

  // ─── Display: the hero numeral on a detail screen ─────────────────────────

  /// The single biggest thing on a screen — a spot reading like "121/80".
  /// Tabular so a changing value doesn't shift its own layout.
  static const TextStyle displayHuge = TextStyle(
    fontSize: 60,
    fontWeight: FontWeight.w700,
    letterSpacing: -3.0,
    color: AppColors.textPrimary,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.0,
    color: AppColors.textPrimary,
    height: 1.05,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  // ─── Headlines ────────────────────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    height: 1.28,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.4,
  );

  // ─── Labels ───────────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  /// All-caps section eyebrow. The reference uses these above section titles.
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  // ─── Metrics ──────────────────────────────────────────────────────────────

  /// The large reading on a hero card — one step down from [displayHuge].
  static const TextStyle metricHero = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.8,
    color: AppColors.textPrimary,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Tabular figures for live metric values, so digits don't jitter as the
  /// reading changes.
  static const TextStyle metricValue = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
    height: 1.05,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Compact tabular value for grid tiles and list rows.
  static const TextStyle metricSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The unit that trails a metric ("BPM", "°C", "%").
  static const TextStyle metricUnit = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: AppColors.textTertiary,
    height: 1.2,
  );

  /// Monospace style for the Demo Lab tensor dumps.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textInverse,
  );
}
