import 'package:flutter/material.dart';

class Brand {
  static const navy = Color(0xFF123A7A);
  static const navyLight = Color(0xFF1E56A0);
  static const navyDark = Color(0xFF0A1F44);
  static const navyDeep = Color(0xFF050F24);
  static const accent = Color(0xFFFFC94D);

  /// Latar header/splash. Mode gelap memakai gradasi yang lebih pekat.
  static LinearGradient gradientOf(BuildContext context) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [navy, navyDark, navyDeep]
            : const [navyLight, navy, navyDark],
      );
}

/// Garis grafik yang naik — logo NaikIn. Bentuknya sama dengan ic_launcher_foreground.xml (viewport 108).
/// [progress] 0..1 menggambar garis sedikit demi sedikit.
class RisingLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  RisingLinePainter({this.progress = 1, this.color = Colors.white, this.strokeWidth = 7});

  static const _points = [Offset(32, 72), Offset(47, 57), Offset(57, 66), Offset(76, 46)];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Skala dari viewport 108 ke ukuran widget, fokus pada area logo (x 28..80, y 40..76).
    const box = Rect.fromLTRB(26, 38, 82, 78);
    final scale = size.shortestSide / box.longestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-box.center.dx, -box.center.dy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final line = Path()..moveTo(_points.first.dx, _points.first.dy);
    for (final p in _points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final metric = line.computeMetrics().first;
    // 85% pertama untuk garis, 15% sisanya untuk kepala panah.
    final lineProgress = (progress / 0.85).clamp(0.0, 1.0);
    canvas.drawPath(metric.extractPath(0, metric.length * lineProgress), paint);

    final headProgress = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
    if (headProgress > 0) {
      const tip = Offset(76, 46);
      final arm = 12 * headProgress;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx - arm, tip.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx, tip.dy + arm),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RisingLinePainter old) => old.progress != progress || old.color != color;
}

/// Logo dalam lingkaran kaca, dipakai di layar login.
class NaikInBadge extends StatelessWidget {
  final double size;
  final double progress;
  const NaikInBadge({super.key, this.size = 96, this.progress = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: EdgeInsets.all(size * 0.24),
      child: CustomPaint(painter: RisingLinePainter(progress: progress, strokeWidth: 8)),
    );
  }
}
