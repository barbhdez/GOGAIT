part of '../main.dart';

// ---- FOOT HEATMAP WIDGET ----
// Traduce presión (0-100) a color; umbral "sin color" bajo (6, no 20) porque las medias de sesión completa caen fácilmente ahí.
Color _pressureColor(double value) {
  if (value < 6) {
    return const Color(0xFF1A1F2E);
  }
  if (value < 35) {
    return const Color(0xFFFFE082);
  }
  if (value < 50) {
    return const Color(0xFFFFC107);
  }
  if (value < 65) {
    return const Color(0xFFFF8A00);
  }
  if (value < 80) {
    return const Color(0xFFFF3D57);
  }
  if (value <= 100) {
    return const Color(0xFFFF0000);
  }
  // >100%: supera la calibración (normal en propulsión); color aparte para distinguirlo del 80-100%.
  return const Color(0xFFB026FF);
}

// Silueta de un pie coloreada según la presión de cada zona.
class FootHeatmapWidget extends StatelessWidget {
  final List<double> data;
  final String label;
  final bool isLeft;
  const FootHeatmapWidget(
      {super.key,
      required this.data,
      required this.label,
      required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: kGray, fontSize: 12)),
      const SizedBox(height: 8),
      CustomPaint(
        size: const Size(105, 150),
        painter: _FootPainter(data: data, isLeft: isLeft),
      ),
    ]);
  }
}

// Dibuja la silueta del pie a base de círculos de color por zona de presión.
class _FootPainter extends CustomPainter {
  final List<double> data;
  final bool isLeft;
  _FootPainter({required this.data, required this.isLeft});

  // Dibuja un punto de presión: un círculo de color con un halo difuminado.
  void _circle(Canvas c, double cx, double cy, double r, double value) {
    final paint = Paint()
      ..color = _pressureColor(value)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    c.drawCircle(Offset(cx, cy), r, paint);
    final paint2 = Paint()..color = _pressureColor(value);
    c.drawCircle(Offset(cx, cy), r * 0.7, paint2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    // Toes
    final toes = isLeft
        ? [
            const Offset(30, 15),
            const Offset(42, 12),
            const Offset(52, 10),
            const Offset(62, 12),
            const Offset(72, 15)
          ]
        : [
            const Offset(72, 15),
            const Offset(62, 12),
            const Offset(52, 10),
            const Offset(42, 12),
            const Offset(30, 15)
          ];
    for (int i = 0; i < toes.length; i++) {
      _circle(canvas, toes[i].dx, toes[i].dy, i == 0 ? 5 : 4,
          data.length > i ? data[i] : 0);
    }

    // Ball
    final ball = isLeft
        ? [
            const Offset(28, 35),
            const Offset(40, 32),
            const Offset(52, 30),
            const Offset(64, 32),
            const Offset(74, 36),
            const Offset(32, 50),
            const Offset(48, 46),
            const Offset(64, 48),
            const Offset(70, 52)
          ]
        : [
            const Offset(74, 35),
            const Offset(64, 32),
            const Offset(52, 30),
            const Offset(40, 32),
            const Offset(28, 36),
            const Offset(70, 50),
            const Offset(54, 46),
            const Offset(38, 48),
            const Offset(32, 52)
          ];
    for (int i = 0; i < ball.length; i++) {
      _circle(canvas, ball[i].dx, ball[i].dy, i < 5 ? 7 : 6,
          data.length > 5 + i ? data[5 + i] : 0);
    }

    // Arch
    const arch = [
      Offset(40, 68),
      Offset(52, 65),
      Offset(62, 68),
      Offset(44, 82),
      Offset(58, 82)
    ];
    for (int i = 0; i < arch.length; i++) {
      _circle(canvas, arch[i].dx, arch[i].dy, 5,
          data.length > 14 + i ? data[14 + i] : 0);
    }

    // Heel
    const heel = [
      Offset(38, 100),
      Offset(51, 98),
      Offset(64, 100),
      Offset(42, 115),
      Offset(51, 118),
      Offset(60, 115),
      Offset(46, 130),
      Offset(56, 130)
    ];
    for (int i = 0; i < heel.length; i++) {
      _circle(canvas, heel[i].dx, heel[i].dy, i == 4 ? 9 : 7,
          data.length > 19 + i ? data[19 + i] : 0);
    }
  }

  @override
  bool shouldRepaint(_FootPainter old) => old.data != data;
}
