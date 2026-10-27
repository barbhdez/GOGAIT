part of '../main.dart';

// ---- SPLASH SCREEN ----
// logo animado; tras 3s pasa a Home si hay sesión, si no a la bienvenida
class VistaSplash extends StatefulWidget {
  const VistaSplash({super.key});
  @override
  State<VistaSplash> createState() => _VistaSplashState();
}

class _VistaSplashState extends State<VistaSplash>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl, _fadeCtrl, _pulseCtrl;
  late Animation<double> _scaleAnim, _fadeAnim, _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeCtrl);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);

    _scaleCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 300), () => _fadeCtrl.forward());
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      final firebaseUser = FirebaseAuth.instance.currentUser;
      // perfil incompleto: VistaHome avisa con un diálogo, no hay pantalla intermedia
      final destino = firebaseUser == null
          ? const VistaBienvenida()
          : const VistaHome();
      Navigator.pushReplacement(
          context, gogaitRoute(builder: (_) => destino));
    });
    appLang.addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  @override
  void dispose() {
    appLang.removeListener(_onLangChange);
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        CustomPaint(painter: _GridPainter(), size: Size.infinite),
        Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color:
                            kOrange.withValues(alpha: 0.3 * _pulseAnim.value),
                        blurRadius: 60,
                        spreadRadius: 20)
                  ]),
                  child: child,
                ),
                child: Image.asset('assets/logo.png',
                    width: 128,
                    height: 128,
                    errorBuilder: (_, __, ___) => Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: const Icon(Icons.directions_walk,
                              color: Colors.white, size: 64),
                        )),
              )),
          const SizedBox(height: 24),
          FadeTransition(
              opacity: _fadeAnim,
              child: ShaderMask(
                shaderCallback: (bounds) => kGradientFull.createShader(bounds),
                child: const Text('GOGAIT',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 4)),
              )),
          const SizedBox(height: 48),
          FadeTransition(opacity: _fadeAnim, child: _DotsLoader()),
          const SizedBox(height: 16),
          FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                      opacity: 0.5 + 0.5 * _pulseAnim.value,
                      child: Text(tr('splash_analyzing'),
                          style: const TextStyle(
                              color: kGray, fontSize: 14, letterSpacing: 1))))),
          const SizedBox(height: 8),
          FadeTransition(
              opacity: _fadeAnim,
              child: Text(tr('splash_connecting'),
                  style:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 12))),
        ])),
      ]),
    );
  }
}

// los 3 puntitos animados del splash, cada uno con su propio ritmo
class _DotsLoader extends StatefulWidget {
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 1200))
          ..repeat(
              reverse: true, period: Duration(milliseconds: 1200 + i * 200)));
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0.5, end: 1.0).animate(c))
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _ctrls[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            3,
            (i) => AnimatedBuilder(
                animation: _anims[i],
                builder: (_, __) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          kOrange.withValues(alpha: _anims[i].value),
                          kRed.withValues(alpha: _anims[i].value)
                        ]),
                      ),
                    ))));
  }
}

// Dibuja la rejilla de fondo sutil del splash.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kOrange.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
