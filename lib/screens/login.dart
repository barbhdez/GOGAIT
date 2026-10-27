part of '../main.dart';

// ---- LOGIN SCREEN ----
// Pantalla de inicio de sesión con email y contraseña (Firebase Auth).
class VistaLogin extends StatefulWidget {
  const VistaLogin({super.key});
  @override
  State<VistaLogin> createState() => _VistaLoginState();
}

class _VistaLoginState extends State<VistaLogin> with IdiomaListenerMixin {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _showPass = false;

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isError
                ? kRed.withValues(alpha: 0.4)
                : kTeal.withValues(alpha: 0.4)),
      ),
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? kRed : kTeal, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
      ]),
    ));
  }

  void _login() async {
    if (!Validadores.esEmailValido(_emailC.text)) {
      _snack(tr('err_invalid_email'));
      return;
    }
    if (_passC.text.isEmpty) {
      _snack(tr('err_enter_password'));
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );
      final prefs = await SharedPreferences.getInstance();
      usuarioActual = Usuario(
        email: _emailC.text.trim(),
        nombre: prefs.getString(_claveUsuario('nombre')) ?? '',
        apellido: prefs.getString(_claveUsuario('apellido')) ?? '',
        genero: prefs.getString(_claveUsuario('genero')) ?? 'Male',
        contrasena: _passC.text,
        altura: prefs.getDouble(_claveUsuario('altura')) ?? 0.0,
        peso: prefs.getDouble(_claveUsuario('peso')) ?? 0.0,
        cumpleanos: prefs.getString(_claveUsuario('cumpleanos')) ?? '',
        shoeSize: prefs.getDouble(_claveUsuario('shoeSize')) ?? 0.0,
        arco: prefs.getString(_claveUsuario('arco')) ?? 'Normal',
        fotoPath: prefs.getString(_claveUsuario('fotoPath')),
        patologia: prefs.getString(_claveUsuario('patologia')),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(context,
          gogaitRoute(builder: (_) => const VistaHome()), (_) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _snack(tr('err_user_not_found'));
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _snack(tr('err_wrong_password'));
      } else if (e.code == 'invalid-email') {
        _snack(tr('err_invalid_email_format'));
      } else if (e.code == 'too-many-requests') {
        _snack(tr('err_too_many_attempts'));
      } else {
        _snack('${tr('err_login_generic')}: ${e.message}');
      }
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
        SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const SizedBox(height: 40),
                  Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 64,
                        height: 64,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(
                              color: kOrange.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 10)
                        ])),
                    Image.asset('assets/logo.png',
                        width: 64,
                        height: 64,
                        errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                gradient: kGradientFull,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.directions_walk,
                                color: Colors.white, size: 32))),
                  ]),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (b) => kGradient.createShader(b),
                    child: Text(tr('login_welcome_back'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('login_subtitle'),
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14)),
                  const SizedBox(height: 36),
                  GogaitInput(
                      label: tr('email_label'),
                      hint: tr('email_hint'),
                      controller: _emailC,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 18),
                  GogaitInput(
                      label: tr('password_label'),
                      hint: tr('password_hint'),
                      controller: _passC,
                      obscure: !_showPass,
                      suffix: IconButton(
                          icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B7280),
                              size: 20),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass))),
                  const SizedBox(height: 12),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () async {
                            if (!Validadores.esEmailValido(_emailC.text)) {
                              _snack(tr('err_enter_email_first'));
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                email: _emailC.text.trim(),
                              );
                              _snack(tr('password_reset_sent'), isError: false);
                            } on FirebaseAuthException catch (e) {
                              _snack('${tr('error_prefix')}: ${e.message}');
                            }
                          },
                          child: Text(tr('forgot_password'),
                              style: const TextStyle(
                                  color: kOrange, fontSize: 14)))),

                  const SizedBox(height: 24),
                  GogaitButton(text: tr('login'), onTap: _login),
                  const SizedBox(height: 24),
                  Wrap(alignment: WrapAlignment.center, children: [
                    Text(tr('no_account'),
                        style: const TextStyle(color: kGray, fontSize: 14)),
                    GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaRegistro())),
                        child: Text(tr('register_here'),
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 14,
                                fontWeight: FontWeight.w600))),
                  ]),
                ]))),
        SafeArea(
            child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: _SelectorIdioma()))),
      ]),
    );
  }
}
