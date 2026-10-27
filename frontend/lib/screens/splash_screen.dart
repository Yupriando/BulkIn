import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/brand.dart';

/// Splash animasi: logo muncul, garis grafik tergambar naik, lalu nama & tagline.
/// Sambil animasi berjalan, [init] (Supabase, format tanggal) dijalankan; setelah keduanya selesai
/// pindah ke [next] dengan transisi fade.
class SplashScreen extends StatefulWidget {
  final Future<void> Function() init;
  final Widget Function() next;
  const SplashScreen({super.key, required this.init, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  Object? _error;
  bool _waiting = false;

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  late final _badgeScale = _interval(0.0, 0.35, Curves.elasticOut);
  late final _badgeFade = _interval(0.0, 0.15);
  late final _line = _interval(0.15, 0.6, Curves.easeInOutCubic);
  late final _pulse = _interval(0.55, 0.85, Curves.easeOut);
  late final _title = _interval(0.5, 0.8);
  late final _tagline = _interval(0.68, 0.95);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _waiting = false;
    });
    final intro = _intro.isCompleted ? Future<void>.value() : _intro.forward().orCancel;
    final init = widget.init();
    try {
      await intro;
      if (mounted) setState(() => _waiting = true);
      await init;
    } on TickerCanceled {
      return;
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => widget.next(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: Brand.gradientOf(context)),
          child: Stack(
            children: [
              _AmbientBubbles(animation: _ambient),
              Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Gelombang yang memancar saat panah selesai tergambar
                            if (_pulse.value > 0 && _pulse.value < 1)
                              Container(
                                width: 120 + 60 * _pulse.value,
                                height: 120 + 60 * _pulse.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5 * (1 - _pulse.value)),
                                    width: 2,
                                  ),
                                ),
                              ),
                            Opacity(
                              opacity: _badgeFade.value,
                              child: Transform.scale(
                                scale: 0.4 + 0.6 * _badgeScale.value,
                                child: NaikInBadge(size: 120, progress: _line.value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: _title.value,
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - _title.value)),
                          child: Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Naik'),
                              TextSpan(text: 'In', style: TextStyle(color: Brand.accent)),
                            ]),
                            style: textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _tagline.value,
                        child: Text(
                          'Naik pelan-pelan, konsisten tiap hari',
                          style: textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: SafeArea(
                  top: false,
                  child: _error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Gagal memulai aplikasi:\n$_error',
                                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 12),
                            FilledButton.tonal(onPressed: _start, child: const Text('Coba lagi')),
                          ],
                        )
                      : AnimatedOpacity(
                          opacity: _waiting ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lingkaran transparan yang melayang pelan di latar belakang.
class _AmbientBubbles extends StatelessWidget {
  final Animation<double> animation;
  const _AmbientBubbles({required this.animation});

  static const _bubbles = [
    // (posisi x, posisi y, ukuran, fase)
    (0.12, 0.18, 140.0, 0.0),
    (0.85, 0.12, 90.0, 0.3),
    (0.9, 0.7, 180.0, 0.6),
    (0.08, 0.82, 110.0, 0.8),
    (0.55, 0.92, 70.0, 0.45),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Stack(
          children: [
            for (final (x, y, size, phase) in _bubbles)
              Positioned(
                left: constraints.maxWidth * x - size / 2,
                top: constraints.maxHeight * y - size / 2 + 14 * math.sin((animation.value + phase) * 2 * math.pi),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
