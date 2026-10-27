part of '../main.dart';

// se persiste como "DD/MM/YYYY", se muestra como "June 25, 2026"
String fechaNacAGuardar(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

String fechaNacAMostrar(DateTime? fecha) => fecha == null
    ? '—'
    : '${tr('month_${fecha.month}')} ${fecha.day}, ${fecha.year}';

// "Member since June 2026" a partir de currentUser.metadata.creationTime
String miembroDesde() {
  final creado = FirebaseAuth.instance.currentUser?.metadata.creationTime;
  if (creado == null) {
    return '';
  }
  return tr('member_since')
      .replaceAll('{month}', tr('month_${creado.month}'))
      .replaceAll('{year}', '${creado.year}');
}

// reconstruye el DateTime desde el formato de fechaNacAGuardar
DateTime? fechaNacDesdeGuardado(String guardado) {
  final parts = guardado.split('/');
  if (parts.length != 3) {
    return null;
  }
  return DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-'
      '${parts[0].padLeft(2, '0')}');
}

// solo-calendario: el modo teclado "MM/DD/YYYY" confunde con guiones
Future<DateTime?> elegirFechaNacimiento(
        BuildContext context, DateTime? actual) =>
    showDatePicker(
        context: context,
        initialDate: actual ?? DateTime(1990),
        firstDate: DateTime(1940),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme:
                    const ColorScheme.dark(primary: kOrange, surface: kCard),
                dialogTheme: const DialogThemeData(backgroundColor: kCard)),
            child: child!));

// pill con la fecha elegida + icono de calendario, para registro y perfil
Widget pillFechaNacimiento(DateTime? fecha, VoidCallback onTap) {
  return GestureDetector(
      onTap: onTap,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGrayDark)),
          child: Row(children: [
            Flexible(
                child: Text(fechaNacAMostrar(fecha),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14))),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined, color: kGray, size: 14),
          ])));
}

// Condiciones de pie disponibles, reutilizadas entre registro y perfil.
List<Map<String, String>> get _condicionesPie => [
  {'value': 'none', 'label': tr('condition_none')},
  {'value': 'plantar-fasciitis', 'label': tr('condition_plantar_fasciitis')},
  {'value': 'bunions', 'label': tr('condition_bunions')},
  {'value': 'arthritis', 'label': tr('condition_arthritis')},
  {'value': 'other', 'label': tr('condition_other')},
];

// si no coincide con ninguna opción conocida (dato antiguo), se muestra tal cual
String etiquetaCondicion(String valor) {
  for (final c in _condicionesPie) {
    if (c['value'] == valor) {
      return c['label']!;
    }
  }
  return valor.isEmpty ? tr('condition_none') : valor;
}

// pills seleccionables a ancho completo, reutilizado entre registro y perfil
Widget selectorCondicionPie(
    String seleccionado, void Function(String) onChanged) {
  return Column(
      children: _condicionesPie
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onChanged(c['value']!),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: seleccionado == c['value'] ? kGradient : null,
                      color: seleccionado == c['value'] ? null : kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: seleccionado == c['value']
                              ? Colors.transparent
                              : kGrayDark),
                    ),
                    child: Text(c['label']!,
                        style: TextStyle(
                            color: seleccionado == c['value']
                                ? Colors.white
                                : kGray,
                            fontWeight: FontWeight.w500,
                            fontSize: 15)),
                  ),
                ),
              ))
          .toList());
}

// usa el id (DateTime completo) en vez de 'fecha', que solo tiene día/mes
String _formatFechaSesion(SesionActividad s,
    {String? separador, bool incluirHora = true}) {
  final fecha = DateTime.tryParse(s.id);
  if (fecha == null) {
    return incluirHora ? '${s.fecha} ${separador ?? tr('at_word')} ${s.hora}' : s.fecha;
  }
  final fechaLarga = '${fecha.day} ${tr('month_${fecha.month}')} ${fecha.year}';
  if (!incluirHora) {
    return fechaLarga;
  }
  final hora = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  return '$fechaLarga ${separador ?? tr('at_word')} $hora';
}

// Validaciones reutilizables de formularios (email y contraseña).
class Validadores {
  static bool esEmailValido(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email);
  // mínimo 6 caracteres, una mayúscula y un número
  static bool esContraseniaValida(String pass) =>
      pass.length >= 6 &&
      pass.contains(RegExp(r'[A-Z]')) &&
      pass.contains(RegExp(r'[0-9]'));
}
