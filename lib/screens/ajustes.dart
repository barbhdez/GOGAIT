part of '../main.dart';

// ---- SETTINGS SCREEN ----
// Ajustes del usuario: datos personales y físicos editables, foto, y cierre de sesión.
class VistaAjustes extends StatefulWidget {
  const VistaAjustes({super.key});
  @override
  State<VistaAjustes> createState() => _VistaAjustesState();
}

class _VistaAjustesState extends State<VistaAjustes> with IdiomaListenerMixin {
  late TextEditingController _nC, _apellidoC, _emailC;
  late double _altura, _peso, _shoeSize;
  late String _genero, _arco, _patologia;
  DateTime? _fechaNac;
  bool _editing = false;

  // Fecha de nacimiento formateada como "June 25, 2026".
  String get _fechaStr => fechaNacAMostrar(_fechaNac);

  // Precarga los campos con los datos del usuario, con valores por defecto si aún no hay medidas guardadas.
  @override
  void initState() {
    super.initState();
    _nC = TextEditingController(text: usuarioActual?.nombre ?? '');
    _apellidoC = TextEditingController(text: usuarioActual?.apellido ?? '');
    _emailC = TextEditingController(text: usuarioActual?.email ?? '');
    _patologia = usuarioActual?.patologia ?? 'none';
    _altura = (usuarioActual?.altura ?? 0) < 140 ? 170 : usuarioActual!.altura;
    _peso = (usuarioActual?.peso ?? 0) < 40 ? 70 : usuarioActual!.peso;
    _shoeSize =
        (usuarioActual?.shoeSize ?? 0) < 35 ? 42 : usuarioActual!.shoeSize;
    _genero = (usuarioActual?.genero.isEmpty ?? true)
        ? 'Male'
        : usuarioActual!.genero;
    _arco =
        (usuarioActual?.arco.isEmpty ?? true) ? 'Normal' : usuarioActual!.arco;
    final cump = usuarioActual?.cumpleanos ?? '';
    if (cump.isNotEmpty) {
      _fechaNac = fechaNacDesdeGuardado(cump);
    }
  }

  @override
  void dispose() {
    _nC.dispose();
    _apellidoC.dispose();
    _emailC.dispose();
    super.dispose();
  }

  // Pide confirmación y, si se acepta, elimina la cuenta y todos sus datos.
  Future<void> _confirmarEliminarCuenta() async {
    final eliminar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('delete_account_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
            tr('delete_account_msg'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete_button'),
                  style: const TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (eliminar == true) {
      await _eliminarCuenta();
    }
  }

  // Borra la cuenta de Firebase primero; las claves locales solo se borran si eso tiene éxito, para no dejar la cuenta a medias si Firebase falla.
  Future<void> _eliminarCuenta() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
      final prefs = await SharedPreferences.getInstance();
      if (email != null && email.isNotEmpty) {
        final sufijo = '_$email';
        final claves =
            prefs.getKeys().where((k) => k.endsWith(sufijo)).toList();
        for (final clave in claves) {
          await prefs.remove(clave);
        }
      }
      usuarioActual = null;
      historial = [];
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
          context,
          gogaitRoute(builder: (_) => const VistaBienvenida()),
          (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final mensaje = e.code == 'requires-recent-login'
          ? tr('err_reauth_required')
          : '${tr('err_deleting_account')}: ${e.message}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  // Guarda los cambios en SharedPreferences y en el Usuario en memoria, y sale del modo edición.
  void _save() async {
    final cumpleGuardar =
        _fechaNac != null ? fechaNacAGuardar(_fechaNac!) : '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_claveUsuario('nombre'), _nC.text);
    await p.setString(_claveUsuario('apellido'), _apellidoC.text);
    await p.setString(_claveUsuario('cumpleanos'), cumpleGuardar);
    await p.setDouble(_claveUsuario('altura'), _altura);
    await p.setDouble(_claveUsuario('peso'), _peso);
    await p.setDouble(_claveUsuario('shoeSize'), _shoeSize);
    await p.setString(_claveUsuario('genero'), _genero);
    await p.setString(_claveUsuario('arco'), _arco);
    await p.setString(_claveUsuario('patologia'), _patologia);
    usuarioActual?.nombre = _nC.text;
    usuarioActual?.apellido = _apellidoC.text;
    usuarioActual?.cumpleanos = cumpleGuardar;
    usuarioActual?.altura = _altura;
    usuarioActual?.peso = _peso;
    usuarioActual?.shoeSize = _shoeSize;
    usuarioActual?.genero = _genero;
    usuarioActual?.arco = _arco;
    usuarioActual?.patologia = _patologia == 'none' ? null : _patologia;
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('changes_saved')),
          backgroundColor: kCard,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  // Fila de solo lectura: icono + etiqueta + valor (modo no edición).
  Widget _infoRow(String label, String value, IconData icon,
      {Color iconColor = kOrange}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: kGray, fontSize: 14)),
          const SizedBox(width: 8),
          // Expanded para que el valor quede a la derecha y haga ellipsis si es largo.
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
        ]));
  }

  // Fila editable: icono + etiqueta + widget de edición (dropdown, texto, selector de fecha...).
  Widget _editRow(String label, IconData icon, Widget valueWidget,
      {Color iconColor = kOrange}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: kGray, fontSize: 14))),
          Expanded(child: valueWidget),
        ]));
  }

  // Desplegable genérico con el estilo de la app (género, tipo de arco...).
  Widget _dropdown(
      String value, List<String> options, void Function(String) onChanged,
      {String Function(String)? labelFor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        dropdownColor: kCard,
        underline: const SizedBox(),
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        items: options
            .map((o) => DropdownMenuItem(
                value: o, child: Text(labelFor != null ? labelFor(o) : o)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => onChanged(v));
          }
        },
      ),
    );
  }

  // Mismo estilo que _dropdown, pero el valor guardado (slug) y el label mostrado son distintos, así que no encaja en _dropdown.
  Widget _dropdownCondicion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: DropdownButton<String>(
        value: _patologia,
        isDense: true,
        isExpanded: true,
        dropdownColor: kCard,
        underline: const SizedBox(),
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down, color: kGray, size: 18),
        items: _condicionesPie
            .map((c) =>
                DropdownMenuItem(value: c['value'], child: Text(c['label']!)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _patologia = v);
          }
        },
      ),
    );
  }

  // Campo de texto compacto para editar un valor en línea (nombre, patología).
  Widget _inlineText(TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kGrayDark)),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
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
                  child: Text(tr('profile_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap:
                      _editing ? _save : () => setState(() => _editing = true),
                  child: Icon(_editing ? Icons.check : Icons.edit_outlined,
                      color: kOrange, size: 22)),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final x = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (x != null) {
                        final p = await SharedPreferences.getInstance();
                        await p.setString(_claveUsuario('fotoPath'), x.path);
                        if (mounted) {
                          setState(() => usuarioActual?.fotoPath = x.path);
                        }
                      }
                    },
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: usuarioActual?.fotoPath != null
                              ? ClipOval(
                                  child: Image.file(
                                      File(usuarioActual!.fotoPath!),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person,
                                  color: Colors.white, size: 48)),
                      Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: kTeal, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      (() {
                        final partes = [
                          usuarioActual?.nombre,
                          usuarioActual?.apellido
                        ].where((s) => s != null && s.isNotEmpty).join(' ');
                        return partes.isEmpty ? tr('user_fallback') : partes;
                      })(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600)),
                  Text(miembroDesde(),
                      style: const TextStyle(color: kGray, fontSize: 13)),
                  const SizedBox(height: 24),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('personal_data'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(tr('name_label'), Icons.person_outline,
                                  _inlineText(_nC),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(tr('last_name'), Icons.person_outline,
                                  _inlineText(_apellidoC),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('email_label'),
                                  Icons.email_outlined,
                                  Text(_emailC.text,
                                      style: const TextStyle(
                                          color: kGray, fontSize: 14),
                                      textAlign: TextAlign.right),
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('date_of_birth_break'),
                                  Icons.calendar_today_outlined,
                                  pillFechaNacimiento(_fechaNac, () async {
                                    final picked = await elegirFechaNacimiento(
                                        context, _fechaNac);
                                    if (picked != null) {
                                      setState(() => _fechaNac = picked);
                                    }
                                  }),
                                  iconColor: kOrange),
                            ] else ...[
                              _infoRow(tr('name_label'), _nC.text, Icons.person_outline,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('last_name'), _apellidoC.text,
                                  Icons.person_outline,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(
                                  tr('email_label'), _emailC.text, Icons.email_outlined,
                                  iconColor: kOrange),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('date_of_birth'), _fechaStr,
                                  Icons.calendar_today_outlined,
                                  iconColor: kOrange),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('physical_metrics'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(
                                  tr('height'),
                                  Icons.height,
                                  _dropdown(
                                      '${_altura.toInt()}',
                                      List.generate(81, (i) => '${140 + i}'),
                                      (v) => _altura = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('weight'),
                                  Icons.monitor_weight_outlined,
                                  _dropdown(
                                      '${_peso.toInt()}',
                                      List.generate(111, (i) => '${40 + i}'),
                                      (v) => _peso = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('shoe_size_label'),
                                  Icons.directions_walk_outlined,
                                  _dropdown(
                                      '${_shoeSize.toInt()}',
                                      List.generate(16, (i) => '${35 + i}'),
                                      (v) => _shoeSize = double.parse(v)),
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(
                                  tr('gender'),
                                  Icons.person_outline,
                                  _dropdown(_genero, ['Male', 'Female'],
                                      (v) => _genero = v,
                                      labelFor: (v) =>
                                          v == 'Male' ? tr('male') : tr('female')),
                                  iconColor: kRed),
                            ] else ...[
                              _infoRow(tr('height'), '${_altura.toInt()} cm',
                                  Icons.height,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('weight'), '${_peso.toInt()} kg',
                                  Icons.monitor_weight_outlined,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('shoe_size_label'), '${_shoeSize.toInt()} EU',
                                  Icons.directions_walk_outlined,
                                  iconColor: kRed),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(tr('gender'),
                                  _genero == 'Male' ? tr('male') : tr('female'),
                                  Icons.person_outline,
                                  iconColor: kRed),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  GogaitCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('biomechanics_title'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_editing) ...[
                              _editRow(
                                  tr('foot_arch_label'),
                                  Icons.architecture,
                                  _dropdown(_arco, ['Flat', 'Normal', 'High'],
                                      (v) => _arco = v,
                                      labelFor: (v) => v == 'Flat'
                                          ? tr('arch_flat')
                                          : v == 'High'
                                              ? tr('arch_high')
                                              : tr('arch_normal')),
                                  iconColor: kYellow),
                              const Divider(
                                  color: Color(0xFF374151), height: 20),
                              _editRow(tr('condition_label'), Icons.favorite_outline,
                                  _dropdownCondicion(),
                                  iconColor: kYellow),
                            ] else ...[
                              _infoRow(
                                  tr('foot_arch_label'),
                                  _arco == 'Flat'
                                      ? tr('arch_flat')
                                      : _arco == 'High'
                                          ? tr('arch_high')
                                          : tr('arch_normal'),
                                  Icons.architecture,
                                  iconColor: kYellow),
                              const Divider(
                                  color: Color(0xFF374151), height: 1),
                              _infoRow(
                                  tr('condition_label'),
                                  etiquetaCondicion(_patologia),
                                  Icons.favorite_outline,
                                  iconColor: kYellow),
                            ],
                          ])),
                  const SizedBox(height: 12),

                  // Solo fuera de modo edición, para no mezclarlo con los controles de edición del perfil.
                  if (!_editing) ...[
                    GogaitCard(
                        onTap: () => Navigator.push(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaGuiaMetricas())),
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: kTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.menu_book_outlined,
                                  color: kTeal, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(tr('metrics_guide_title'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15))),
                          const Icon(Icons.chevron_right,
                              color: kGray, size: 20),
                        ])),
                    const SizedBox(height: 20),
                  ],

                  // Solo cierra sesión, no toca datos locales de otras cuentas del dispositivo.
                  if (!_editing)
                    GestureDetector(
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        usuarioActual = null;
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.pushAndRemoveUntil(
                            context,
                            gogaitRoute(
                                builder: (_) => const VistaBienvenida()),
                            (_) => false);
                      },
                      child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kRed.withValues(alpha: 0.3))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout, color: kRed, size: 20),
                                const SizedBox(width: 8),
                                Text(tr('sign_out'),
                                    style: const TextStyle(
                                        color: kRed,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ])),
                    ),

                  // Borra cuenta y datos locales; requiere confirmación explícita por ser irreversible.
                  if (!_editing) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _confirmarEliminarCuenta,
                      child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                              color: kRed.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: kGrayDark)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_forever_outlined,
                                    color: kGray, size: 20),
                                const SizedBox(width: 8),
                                Text(tr('delete_account'),
                                    style: const TextStyle(
                                        color: kGray,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ])),
                    ),
                  ],
                ]))),
      ])),
    );
  }
}
