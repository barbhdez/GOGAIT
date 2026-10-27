part of '../main.dart';

// ---- WELCOME SCREEN ----
// Pantalla de bienvenida con los botones de Login / Register.
class VistaBienvenida extends StatefulWidget {
  const VistaBienvenida({super.key});
  @override
  State<VistaBienvenida> createState() => _VistaBienvenidaState();
}

class _VistaBienvenidaState extends State<VistaBienvenida>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _titleCtrl, _btnCtrl, _meshCtrl;
  late Animation<double> _logoScale,
      _logoOpacity,
      _titleSlide,
      _titleOpacity,
      _btnSlide,
      _btnOpacity;

  // Anima en cascada: primero el logo, luego el título, luego los botones.
  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    // mesh de fondo "respira" en bucle; ciclo largo (7s) para que no maree
    _meshCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_logoCtrl);
    _titleSlide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_titleCtrl);
    _btnSlide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_btnCtrl);

    _logoCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 200), () => _titleCtrl.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _btnCtrl.forward());
    // sin este listener el texto queda congelado al cambiar de idioma
    appLang.addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  @override
  void dispose() {
    appLang.removeListener(_onLangChange);
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _btnCtrl.dispose();
    _meshCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Container(color: Colors.black)),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Transform.translate(
            offset: Offset(0, MediaQuery.of(context).size.height * 0.05),
            child: AnimatedBuilder(
              animation: _meshCtrl,
              builder: (context, child) {
                // t: 0 en mitad del ciclo, 1 en extremos; comparte escala/giro y brillo
                final t = _meshCtrl.value;
                return Transform.scale(
                  scale: 1.0 + t * 0.06,
                  child: Transform.rotate(
                    angle: (t - 0.5) * 0.025,
                    child: Stack(fit: StackFit.expand, children: [
                      child!,
                      // brillo cálido que pulsa por encima del mesh
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0.15 + t * 0.25,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.bottomCenter,
                                radius: 1.0,
                                colors: [
                                  kOrange.withValues(alpha: 0.6),
                                  kRed.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
              child: Image.asset('assets/mesh-bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomCenter,
                            radius: 1.2,
                            colors: [
                              kRed.withValues(alpha: 0.3),
                              kOrange.withValues(alpha: 0.15),
                              Colors.black
                            ],
                          ),
                        ),
                      )),
            ),
          ),
        ),
        Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.50))),
        SafeArea(
            child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                    child: _SelectorIdioma()))),
        SafeArea(
            child: Column(children: [
          const Spacer(),
          AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, child) => Opacity(
                    opacity: _logoOpacity.value,
                    child:
                        Transform.scale(scale: _logoScale.value, child: child),
                  ),
              child: Column(children: [
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(
                          color: kOrange.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10)
                    ]),
                  ),
                  Image.asset('assets/logo.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                                gradient: kGradientFull,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.directions_walk,
                                color: Colors.white, size: 48),
                          )),
                ]),
                const SizedBox(height: 24),
                AnimatedBuilder(
                    animation: _titleCtrl,
                    builder: (_, __) => Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleSlide.value),
                            child: Column(children: [
                              RichText(
                                  text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1),
                                children: [
                                  const TextSpan(
                                      text: 'GOG',
                                      style: TextStyle(color: Colors.white)),
                                  WidgetSpan(
                                      child: ShaderMask(
                                    shaderCallback: (b) => const LinearGradient(
                                            colors: [kRed, kOrange])
                                        .createShader(b),
                                    child: const Text('A',
                                        style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  )),
                                  const TextSpan(
                                      text: 'IT',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text(tr('welcome_tagline'),
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB), fontSize: 16)),
                            ]),
                          ),
                        )),
              ])),
          const Spacer(),
          AnimatedBuilder(
              animation: _btnCtrl,
              builder: (_, child) => Opacity(
                    opacity: _btnOpacity.value,
                    child: Transform.translate(
                        offset: Offset(0, _btnSlide.value), child: child),
                  ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(children: [
                  GogaitButton(
                      text: tr('login'),
                      onTap: () => Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaLogin()))),
                  const SizedBox(height: 12),
                  GogaitButton(
                      text: tr('register'),
                      outlined: true,
                      onTap: () => Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaRegistro()))),
                  const SizedBox(height: 16),
                  Text(tr('welcome_footer'),
                      style:
                          const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ]),
              )),
        ])),
      ]),
    );
  }
}

// pastilla con la bandera actual; al tocarla abre la hoja con los 6 idiomas
class _SelectorIdioma extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, idiomaActual, __) {
          return GestureDetector(
              onTap: () => _abrirSelectorIdioma(context),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: kCard.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(idiomaActual.flag,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 16),
                  ])));
        });
  }

  void _abrirSelectorIdioma(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: kCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('select_language'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...AppLang.values.map((lang) => ValueListenableBuilder<AppLang>(
                    valueListenable: appLang,
                    builder: (_, actual, __) => ListTile(
                        onTap: () {
                          cambiarIdioma(lang);
                          Navigator.pop(ctx);
                        },
                        leading: Text(lang.flag,
                            style: const TextStyle(fontSize: 22)),
                        title: Text(lang.nombreNativo,
                            style: const TextStyle(color: Colors.white)),
                        trailing: actual == lang
                            ? const Icon(Icons.check_circle,
                                color: kOrange, size: 20)
                            : null))),
              ]),
            )));
  }
}
