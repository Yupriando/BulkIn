import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Palet BulkIn: biru tua (navy) dengan aksen hijau mint yang segar.
class Brand {
  static const navyLight = Color(0xFF1F4FA3);
  static const navy = Color(0xFF123A7A);
  static const navyDark = Color(0xFF0A1F44);
  static const navyDeep = Color(0xFF050C1F);
  static const mint = Color(0xFF7BE495);

  /// Latar gelap untuk mode gelap.
  static const ink = Color(0xFF070E1F);
  static const inkCard = Color(0xFF0F1A33);
  static const inkLine = Color(0xFF1D2B4A);

  /// Latar header/splash/kartu utama. Mode gelap memakai gradasi yang lebih pekat.
  static LinearGradient gradientOf(BuildContext context) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [navy, navyDark, navyDeep]
            : const [navyLight, navy, navyDark],
      );

  /// Bayangan berwarna di bawah kartu bergradasi.
  static List<BoxShadow> glowOf(BuildContext context) => [
        BoxShadow(
          color: (Theme.of(context).brightness == Brightness.dark ? Colors.black : navy).withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Tulisan "BulkIn" dengan "In" berwarna mint.
class BulkInWordmark extends StatelessWidget {
  final TextStyle? style;
  const BulkInWordmark({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(children: [
        TextSpan(text: 'Bulk'),
        TextSpan(text: 'In', style: TextStyle(color: Brand.mint)),
      ]),
      style: style,
    );
  }
}

/// Logo BulkIn: apel di atas timbangan dapur. Bentuknya sama dengan ic_launcher_foreground.xml (viewport 108).
/// [progress] 0..1 menganimasikan: timbangan muncul, apel jatuh memantul, lalu jarum berayun.
class FoodScalePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color fruitColor;

  FoodScalePainter({this.progress = 1, this.color = Colors.white, this.fruitColor = Brand.mint});

  static const _box = Rect.fromLTRB(26, 20, 82, 86);
  static const _dial = Offset(54, 69);

  double _segment(double begin, double end) => ((progress - begin) / (end - begin)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.shortestSide / _box.longestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-_box.center.dx, -_box.center.dy);

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Timbangan: muncul membesar dari bawah.
    final grow = Curves.easeOutBack.transform(_segment(0, 0.4));
    canvas.save();
    canvas.translate(54, 82);
    canvas.scale(grow);
    canvas.translate(-54, -82);
    canvas.drawRRect(RRect.fromLTRBR(34, 50, 74, 54, const Radius.circular(2)), fill);
    canvas.drawRect(const Rect.fromLTRB(51, 53, 57, 57), fill);
    // Badan timbangan dengan lubang bulat untuk jarum (evenOdd = lubang tembus).
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(RRect.fromLTRBR(30, 56, 78, 82, const Radius.circular(7)))
        ..addOval(Rect.fromCircle(center: _dial, radius: 8)),
      fill,
    );
    // Jarum berayun dari kiri ke kanan saat apel mendarat.
    final swing = Curves.elasticOut.transform(_segment(0.7, 1));
    final angle = (-50 + 95 * swing) * math.pi / 180;
    canvas.drawLine(_dial, _dial + Offset(math.sin(angle), -math.cos(angle)) * 6.5, stroke);
    canvas.drawCircle(_dial, 1.6, fill);
    canvas.restore();

    // Apel: jatuh dari atas lalu memantul di piringan timbangan.
    final drop = _segment(0.35, 0.8);
    if (drop > 0) {
      final fade = _segment(0.35, 0.45);
      canvas.save();
      canvas.translate(0, -24 * (1 - Curves.bounceOut.transform(drop)));
      final fruit = Paint()..color = fruitColor.withValues(alpha: fruitColor.a * fade);
      final apple = Path()
        ..addOval(Rect.fromCircle(center: const Offset(50, 40.5), radius: 8.5))
        ..addOval(Rect.fromCircle(center: const Offset(58, 40.5), radius: 8.5))
        ..addOval(Rect.fromCenter(center: const Offset(54, 44.5), width: 20, height: 9));
      canvas.drawPath(apple, fruit);
      canvas.drawLine(const Offset(54, 33.5), const Offset(55.5, 28), stroke..color = color.withValues(alpha: color.a * fade));
      canvas.drawPath(
        Path()
          ..moveTo(56, 30)
          ..quadraticBezierTo(58, 23.5, 65, 24.5)
          ..quadraticBezierTo(63, 31, 56, 30)
          ..close(),
        Paint()..color = color.withValues(alpha: color.a * fade),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FoodScalePainter old) =>
      old.progress != progress || old.color != color || old.fruitColor != fruitColor;
}

/// Logo dalam lingkaran kaca, dipakai di splash & layar login.
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
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      padding: EdgeInsets.all(size * 0.2),
      child: CustomPaint(painter: FoodScalePainter(progress: progress)),
    );
  }
}
