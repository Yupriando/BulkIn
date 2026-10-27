import 'package:flutter/material.dart';

/// Palet BulkIn: oranye menyala → merah → magenta, dengan aksen hijau "volt".
class Brand {
  static const ember = Color(0xFFFF7A1A);
  static const flame = Color(0xFFF0322E);
  static const magenta = Color(0xFFD01C5E);
  static const emberDark = Color(0xFFD9530F);
  static const flameDark = Color(0xFFB81B33);
  static const magentaDark = Color(0xFF5E0D33);
  static const volt = Color(0xFFC6F432);

  /// Latar gelap kehitaman (sedikit ungu) untuk mode gelap.
  static const ink = Color(0xFF0F0D13);
  static const inkCard = Color(0xFF1A1720);
  static const inkLine = Color(0xFF2B2733);

  /// Latar header/splash/kartu utama. Mode gelap memakai gradasi yang lebih pekat.
  static LinearGradient gradientOf(BuildContext context) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [emberDark, flameDark, magentaDark]
            : const [ember, flame, magenta],
      );

  /// Bayangan berwarna di bawah kartu bergradasi.
  static List<BoxShadow> glowOf(BuildContext context) => [
        BoxShadow(
          color: flame.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Tulisan "BulkIn" dengan "In" berwarna volt.
class BulkInWordmark extends StatelessWidget {
  final TextStyle? style;
  const BulkInWordmark({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(children: [
        TextSpan(text: 'Bulk'),
        TextSpan(text: 'In', style: TextStyle(color: Brand.volt)),
      ]),
      style: style,
    );
  }
}

/// Garis grafik yang naik — logo BulkIn. Bentuknya sama dengan ic_launcher_foreground.xml (viewport 108).
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
class BulkInBadge extends StatelessWidget {
  final double size;
  final double progress;
  const BulkInBadge({super.key, this.size = 96, this.progress = 1});

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
