part of '../main.dart';

// ---- REGISTER SCREEN ----
// registro en 4 pasos: datos, medidas, pie, salud
class VistaRegistro extends StatefulWidget {
  const VistaRegistro({super.key});
  @override
  State<VistaRegistro> createState() => _VistaRegistroState();
}

class _VistaRegistroState extends State<VistaRegistro> with IdiomaListenerMixin {
  int _step = 1;
  final _nameC = TextEditingController(), _emailC = TextEditingController();
  final _apellidoC = TextEditingController();
  final _passC = TextEditingController();
  DateTime? _fechaNac;
  double _altura = 170, _peso = 70, _shoeSize = 42;
  String _genero = 'Male', _arco = 'Normal', _patologia = 'none';
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

  void _next() async {
    if (_step == 1) {
      if (_nameC.text.trim().isEmpty) {
        _snack(tr('err_first_name'));
        return;
      }
      if (_apellidoC.text.trim().isEmpty) {
        _snack(tr('err_last_name'));
        return;
      }
      if (!Validadores.esEmailValido(_emailC.text)) {
        _snack(tr('err_valid_email'));
        return;
      }
      if (!Validadores.esContraseniaValida(_passC.text)) {
        _snack(tr('err_password_rules'));
        return;
      }
      if (_fechaNac == null) {
        _snack(tr('err_dob'));
        return;
      }
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passC.text.trim(),
      );

      // la contraseña no se guarda aquí, Firebase Auth ya es la fuente de verdad
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveUsuario('nombre'), _nameC.text);
      await prefs.setString(_claveUsuario('apellido'), _apellidoC.text);
      await prefs.setDouble(_claveUsuario('altura'), _altura);
      await prefs.setDouble(_claveUsuario('peso'), _peso);
      await prefs.setString(
          _claveUsuario('cumpleanos'), fechaNacAGuardar(_fechaNac!));
      await prefs.setDouble(_claveUsuario('shoeSize'), _shoeSize);
      await prefs.setString(_claveUsuario('genero'), _genero);
      await prefs.setString(_claveUsuario('arco'), _arco);
      await prefs.setString(_claveUsuario('patologia'), _patologia);

      usuarioActual = Usuario(
        email: _emailC.text.trim(),
        nombre: _nameC.text,
        apellido: _apellidoC.text,
        genero: _genero,
        contrasena: _passC.text,
        altura: _altura,
        peso: _peso,
        cumpleanos: fechaNacAGuardar(_fechaNac!),
        shoeSize: _shoeSize,
        arco: _arco,
        patologia: _patologia == 'none' ? null : _patologia,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(context,
          gogaitRoute(builder: (_) => const VistaHome()), (_) => false);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        _snack(tr('err_email_in_use'));
      } else if (e.code == 'weak-password') {
        _snack(tr('err_weak_password'));
      } else if (e.code == 'invalid-email') {
        _snack(tr('err_invalid_email_format'));
      } else {
        _snack('${tr('err_registration_generic')}: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error general: $e');
      _snack('${tr('error_prefix')}: $e');
    }
  }

  // Slider con etiqueta y unidad (usado para altura, peso y talla de zapato).
  Widget _buildSlider(String label, double value, double min, double max,
      String unit, void Function(double) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ${value.toInt()} $unit',
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: kGrayDark,
          inactiveTrackColor: kGrayDark,
          thumbColor: kOrange,
          overlayColor: kOrange.withValues(alpha: 0.15),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          trackHeight: 4,
        ),
        child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v))),
      ),
    ]);
  }

  // Botón de selección simple (usado para elegir género).
  Widget _selectBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? kGradient : null,
          color: selected ? null : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : kGrayDark),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : kGray,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ),
    );
  }

  // Botón de selección con símbolo encima (usado para el tipo de arco del pie).
  Widget _archBtn(
      String label, String symbol, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: selected ? kGradient : null,
          color: selected ? null : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : kGrayDark),
        ),
        alignment: Alignment.center,
        child: Column(children: [
          Text(symbol,
              style: TextStyle(
                  color: selected ? Colors.white : kGray, fontSize: 22)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : kGray,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: _step == 1
                      ? () => Navigator.pop(context)
                      : () => setState(() => _step--),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGrayDark)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 20))),
              Expanded(
                  child: Text(tr('reg_create_account'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18))),
              const SizedBox(width: 36),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(children: [
              Row(
                  children: List.generate(
                      4,
                      (i) => Expanded(
                              child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: i < _step ? kGradient : null,
                              color: i < _step ? null : kGrayDark,
                            ),
                          )))),
              const SizedBox(height: 6),
              Text(tr('reg_step_of').replaceAll('{n}', '$_step'),
                  style: const TextStyle(color: kGray, fontSize: 12)),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == 1) ...[
                        Text(tr('reg_personal_info'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        GogaitInput(
                            label: tr('first_name'),
                            hint: 'John',
                            controller: _nameC),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('last_name'),
                            hint: 'Doe',
                            controller: _apellidoC),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('email_label'),
                            hint: tr('email_hint'),
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        GogaitInput(
                            label: tr('password_label'),
                            hint: tr('password_hint_rules'),
                            controller: _passC,
                            obscure: !_showPass,
                            suffix: IconButton(
                                icon: Icon(
                                    _showPass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: kGray,
                                    size: 20),
                                onPressed: () =>
                                    setState(() => _showPass = !_showPass))),
                        const SizedBox(height: 16),
                        Text(tr('reg_date_of_birth'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 8),
                        pillFechaNacimiento(_fechaNac, () async {
                          final picked =
                              await elegirFechaNacimiento(context, _fechaNac);
                          if (picked != null) {
                            setState(() => _fechaNac = picked);
                          }
                        }),
                      ],
                      if (_step == 2) ...[
                        Text(tr('reg_physical_metrics'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 28),
                        _buildSlider(tr('height'), _altura, 140, 220, 'cm',
                            (v) => _altura = v),
                        const SizedBox(height: 24),
                        _buildSlider(
                            tr('weight'), _peso, 40, 150, 'kg', (v) => _peso = v),
                        const SizedBox(height: 24),
                        _buildSlider(tr('shoe_size_eu'), _shoeSize, 35, 50, 'EU',
                            (v) => _shoeSize = v),
                        const SizedBox(height: 24),
                        Text(tr('gender'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _selectBtn(tr('male'), _genero == 'Male',
                                  () => setState(() => _genero = 'Male'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _selectBtn(tr('female'), _genero == 'Female',
                                  () => setState(() => _genero = 'Female'))),
                        ]),
                      ],
                      if (_step == 3) ...[
                        Text(tr('reg_foot_biomechanics'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        Text(tr('foot_arch_type'),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _archBtn(tr('arch_flat'), '—', _arco == 'Flat',
                                  () => setState(() => _arco = 'Flat'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _archBtn(tr('arch_normal'), '⌢', _arco == 'Normal',
                                  () => setState(() => _arco = 'Normal'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _archBtn(tr('arch_high'), '⌒', _arco == 'High',
                                  () => setState(() => _arco = 'High'))),
                        ]),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kGrayDark)),
                            child: Text(tr('reg_arch_info'),
                                style: const TextStyle(
                                    color: kGray, fontSize: 13, height: 1.5))),
                      ],
                      if (_step == 4) ...[
                        Text(tr('reg_health_info_title'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(tr('reg_health_question'),
                            style: const TextStyle(color: kGray, fontSize: 14)),
                        const SizedBox(height: 20),
                        selectorCondicionPie(
                            _patologia, (v) => setState(() => _patologia = v)),
                        const SizedBox(height: 8),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kGrayDark)),
                            child: Text(tr('reg_health_info'),
                                style: const TextStyle(
                                    color: kGray, fontSize: 13, height: 1.5))),
                      ],
                    ]))),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Row(children: [
              if (_step > 1) ...[
                GestureDetector(
                    onTap: () => setState(() => _step--),
                    child: Container(
                        height: 56,
                        width: 90,
                        decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGrayDark)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chevron_left,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              Text(tr('back'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ]))),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: GestureDetector(
                onTap: _next,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                      gradient: kGradient,
                      borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_step < 4 ? tr('next') : tr('reg_create_account'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        if (_step < 4) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right,
                              color: Colors.white, size: 20)
                        ],
                      ]),
                ),
              )),
            ])),
      ])),
    );
  }
}
