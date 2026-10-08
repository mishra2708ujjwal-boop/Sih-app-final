import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Spacing, radius and elevation tokens for PRANA.
///
/// Every padding / gap / corner in the app resolves to one of these so the
/// layout rhythm stays consistent instead of drifting per-screen.
class AppSpacing {
  AppSpacing._();

  // ─── Spacing scale ────────────────────────────────────────────────────────
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard horizontal page inset.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: md);

  /// Standard padding inside a card. Roomier than the old 16 — the rounder
  /// corners need more breathing room or content crowds the curve.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Padding for a compact card (grid tiles, list rows).
  static const EdgeInsets cardTight = EdgeInsets.all(md);

  /// Bottom padding that clears the custom nav bar (nav height + breathing room).
  static const double navClearance = 112;

  // ─── Vertical gaps ────────────────────────────────────────────────────────
  static const Widget gapXxs = SizedBox(height: xxs);
  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);
  static const Widget gapXxl = SizedBox(height: xxl);

  // ─── Horizontal gaps ──────────────────────────────────────────────────────
  static const Widget hGapXxs = SizedBox(width: xxs);
  static const Widget hGapXs = SizedBox(width: xs);
  static const Widget hGapSm = SizedBox(width: sm);
  static const Widget hGapMd = SizedBox(width: md);
  static const Widget hGapLg = SizedBox(width: lg);
}

/// Corner radius tokens.
///
/// Noticeably rounder than the previous scale. The reference language is
/// pill-and-pebble: chips are fully round, cards are 24–30, and nothing has a
/// corner tight enough to read as a dialog.
class AppRadius {
  AppRadius._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double xxl = 36;
  static const double pill = 999;

  static final BorderRadius brXs = BorderRadius.circular(xs);
  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brXl = BorderRadius.circular(xl);
  static final BorderRadius brXxl = BorderRadius.circular(xxl);
  static final BorderRadius brPill = BorderRadius.circular(pill);
}

/// Shadow presets. Soft, warm and low-contrast — the UI reads as layered paper
/// on linen, not as floating Material chips.
class AppShadows {
  AppShadows._();

  /// Resting card elevation. Barely there; the border does most of the work.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ];

  /// Hero / emphasised surfaces.
  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.07),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  /// The floating nav bar and bottom action pills, which sit *over* content
  /// and need a wider, softer spread to separate from it.
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.10),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  /// Coloured glow for accent surfaces (SOS button, active gauge).
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.30),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];
}
