import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/prana_logo.dart';

/// The launch landing. Opens on pure black — matching the native window
/// background so there is no flash — then ignites: a ring of light blooms, the
/// logo draws its heartbeat, the PRANA wordmark rises letter by letter, and the
/// tagline fades in. After the sequence it calls [onDone] to hand off to
/// onboarding or the main shell.
///
/// Everything is drawn (no image asset) so it stays crisp at any resolution and
/// carries the exact brand palette.
class SplashScreen extends StatefulWidget {
  /// Where to go when the animation finishes (route name).
  final String nextRoute;

  const SplashScreen({super.key, required this.nextRoute});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  // Sub-timeline slices of the single intro controller (0..1).
  late final Animation<double> _bgGlow; // black -> deep forest bloom
  late final Animation<double> _ringBloom; // expanding light ring
  late final Animation<double> _logoDraw; // logo fade + scale
  late final Animation<double> _wordmark; // letters rise
  late final Animation<double> _tagline; // subtitle fade
  late final Animation<double> _fadeOut; // whole scene lifts on exit

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    Animation<double> slice(double a, double b, [Curve c = Curves.easeOut]) =>
        CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: c));

    _bgGlow = slice(0.00, 0.30, Curves.easeInOut);
    _ringBloom = slice(0.10, 0.55, Curves.easeOutCubic);
    _logoDraw = slice(0.18, 0.52, Curves.easeOutBack);
    _wordmark = slice(0.42, 0.74, Curves.easeOutCubic);
    _tagline = slice(0.66, 0.86, Curves.easeOut);
    _fadeOut = slice(0.90, 1.00, Curves.easeIn);

    _intro.forward();
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the system bars dark so the black edges are seamless.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: GestureDetector(
        // Let an impatient presenter tap to skip straight in.
        onTap: _go,
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final bg = Color.lerp(
              Colors.black,
              AppColors.primaryDark,
              _bgGlow.value * 0.9,
            )!;
            return Opacity(
              opacity: 1.0 - _fadeOut.value,
              child: Transform.translate(
                offset: Offset(0, -_fadeOut.value * 40),
                child: Scaffold(
                  backgroundColor: bg,
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Radial vignette that warms the black into forest.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.15),
                            radius: 1.1,
                            colors: [
                              AppColors.primary.withValues(
                                  alpha: 0.42 * _bgGlow.value),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),

                      // Blooming light ring behind the logo.
                      Center(
                        child: CustomPaint(
                          size: const Size.square(320),
                          painter: _BloomPainter(_ringBloom.value),
                        ),
                      ),

                      // Foreground stack: logo, wordmark, tagline.
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLogo(),
                            const SizedBox(height: 34),
                            _buildWordmark(),
                            const SizedBox(height: 16),
                            _buildTagline(),
                          ],
                        ),
                      ),

                      // Bottom credit line, fades with the tagline.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 44,
                        child: Opacity(
                          opacity: _tagline.value,
                          child: Column(
                            children: [
                              Text(
                                'OFFLINE-FIRST · ON-DEVICE AI',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.accent
                                      .withValues(alpha: 0.65),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final t = _logoDraw.value;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.7 + t * 0.3,
        child: PranaLogo(
          size: 132,
          color: Colors.white,
          pulseColor: AppColors.accent,
          animate: true,
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    const letters = ['P', 'R', 'A', 'N', 'A'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          _WordmarkLetter(
            letter: letters[i],
            // Each letter follows the wordmark phase, staggered.
            progress: _stagger(_wordmark.value, i, letters.length),
          ),
      ],
    );
  }

  Widget _buildTagline() {
    return Opacity(
      opacity: _tagline.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _tagline.value) * 8),
        child: Text(
          'Your breath. Your pulse. Watched over.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  /// Maps an overall 0..1 into a per-item 0..1 with a staggered start.
  double _stagger(double v, int i, int count) {
    final span = 1.0 / count;
    final start = i * span * 0.7; // overlap so it flows, not marches
    final local = ((v - start) / (1 - start)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }
}

/// One rising, fading wordmark glyph.
class _WordmarkLetter extends StatelessWidget {
  final String letter;
  final double progress;

  const _WordmarkLetter({required this.letter, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * 22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding ring of light that blooms out from the logo and fades at its edge.
class _BloomPainter extends CustomPainter {
  final double t; // 0..1

  _BloomPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Primary expanding ring.
    final r = maxR * (0.2 + t * 0.9);
    final fade = (1.0 - t).clamp(0.0, 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.accent.withValues(alpha: 0.5 * fade);
    canvas.drawCircle(c, r, ring);

    // A second, slower ring for depth.
    final r2 = maxR * (0.1 + t * 0.6);
    canvas.drawCircle(
      c,
      r2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.28 * fade),
    );

    // Soft glow disc pulsing under the logo.
    final glowR = maxR * (0.28 + math.sin(t * math.pi) * 0.12);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.35 * t),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );
  }

  @override
  bool shouldRepaint(covariant _BloomPainter old) => old.t != t;
}
