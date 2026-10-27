part of '../main.dart';

// lee FirebaseAuth directo: hace falta antes de que exista 'usuarioActual'
String _claveUsuario(String clave) {
  final email = FirebaseAuth.instance.currentUser?.email ?? '';
  return email.isEmpty ? clave : '${clave}_$email';
}

// separado por cuenta, ver _claveUsuario
Future<void> guardarHistorial() async {
  final prefs = await SharedPreferences.getInstance();
  final lista = historial
      .map((s) => jsonEncode({
            'id': s.id,
            'titulo': s.titulo,
            'descripcion': s.descripcion,
            'tipo': s.tipo,
            'fecha': s.fecha,
            'hora': s.hora,
            'duracion': s.duracion,
            'presionMeta': s.presionMeta,
            'presionTalon': s.presionTalon,
            'presionMetaIzq': s.presionMetaIzq,
            'presionTalonIzq': s.presionTalonIzq,
            'pasos': s.pasos,
            'cadencia': s.cadencia,
            'distanciaKm': s.distanciaKm,
            'balance': s.balance,
            'impacto': s.impacto,
            'impactoIzq': s.impactoIzq,
            'impactoKg': s.impactoKg,
            'zancadaRatio': s.zancadaRatio,
            'strikeIndexDer': s.strikeIndexDer,
            'strikeIndexIzq': s.strikeIndexIzq,
            'tieneBalance': s.tieneBalance,
            'tieneFatiga': s.tieneFatiga,
            'tieneStrikeDer': s.tieneStrikeDer,
            'tieneStrikeIzq': s.tieneStrikeIzq,
            'tieneImpacto': s.tieneImpacto,
            'fatiga': s.fatiga,
            'tramosFatiga': s.tramosFatiga,
            'datosSesion': s.datosSesion,
            'recorrido': s.recorrido,
            'adcReposoDer': s.adcReposoDer,
            'adcCargaDer': s.adcCargaDer,
            'adcTalonDer': s.adcTalonDer,
            'adcPuntaDer': s.adcPuntaDer,
            'adcReposoIzq': s.adcReposoIzq,
            'adcCargaIzq': s.adcCargaIzq,
            'adcTalonIzq': s.adcTalonIzq,
            'adcPuntaIzq': s.adcPuntaIzq,
          }))
      .toList();
  await prefs.setStringList(_claveUsuario('historial'), lista);
}

// reconstruye el historial en memoria, ordenado por id (fecha de creación)
Future<void> cargarHistorial() async {
  final prefs = await SharedPreferences.getInstance();
  final lista = prefs.getStringList(_claveUsuario('historial')) ?? [];
  historial = lista.map((s) {
    final m = jsonDecode(s);
    final datosSesion = (m['datosSesion'] as List<dynamic>?)
            ?.map((d) => Map<String, dynamic>.from(d))
            .toList() ??
        [];
    final recorrido = (m['recorrido'] as List<dynamic>?)
            ?.map((d) => Map<String, dynamic>.from(d))
            .toList() ??
        [];
    return SesionActividad(
      id: m['id'],
      titulo: m['titulo'],
      descripcion: m['descripcion'],
      tipo: m['tipo'],
      fecha: m['fecha'],
      hora: m['hora'],
      duracion: m['duracion'],
      presionMeta: (m['presionMeta'] as num).toDouble(),
      presionTalon: (m['presionTalon'] as num).toDouble(),
      // sesiones antiguas (antes de la segunda placa) no tienen estas claves
      presionMetaIzq: (m['presionMetaIzq'] as num?)?.toDouble() ?? 0,
      presionTalonIzq: (m['presionTalonIzq'] as num?)?.toDouble() ?? 0,
      pasos: (m['pasos'] as num?)?.toInt() ?? 0,
      cadencia: (m['cadencia'] as num?)?.toDouble() ?? 0,
      distanciaKm: (m['distanciaKm'] as num?)?.toDouble() ?? 0,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      impacto: (m['impacto'] as num?)?.toDouble() ?? 0,
      impactoIzq: (m['impactoIzq'] as num?)?.toDouble() ?? 0,
      impactoKg: (m['impactoKg'] as num?)?.toDouble() ?? 0,
      zancadaRatio: (m['zancadaRatio'] as num?)?.toDouble() ?? 0,
      strikeIndexDer: (m['strikeIndexDer'] as num?)?.toDouble() ?? 0,
      strikeIndexIzq: (m['strikeIndexIzq'] as num?)?.toDouble() ?? 0,
      // sesiones antiguas sin estas claves se recalculan desde datosSesion
      tieneBalance: (m['tieneBalance'] as bool?) ??
          tieneDatosPieIzquierdo(datosSesion),
      tieneFatiga:
          (m['tieneFatiga'] as bool?) ?? tieneDatosFatiga(datosSesion),
      tieneStrikeDer: (m['tieneStrikeDer'] as bool?) ??
          tieneDatosStrikeIndex(datosSesion, Pie.derecha),
      tieneStrikeIzq: (m['tieneStrikeIzq'] as bool?) ??
          tieneDatosStrikeIndex(datosSesion, Pie.izquierda),
      tieneImpacto: (m['tieneImpacto'] as bool?) ?? datosSesion.isNotEmpty,
      fatiga: (m['fatiga'] as num?)?.toDouble() ?? calcularFatiga(datosSesion),
      tramosFatiga: (m['tramosFatiga'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          tramosFatiga(datosSesion),
      datosSesion: datosSesion,
      recorrido: recorrido,
      adcReposoDer: (m['adcReposoDer'] as num?)?.toDouble(),
      adcCargaDer: (m['adcCargaDer'] as num?)?.toDouble(),
      adcTalonDer: (m['adcTalonDer'] as num?)?.toDouble(),
      adcPuntaDer: (m['adcPuntaDer'] as num?)?.toDouble(),
      adcReposoIzq: (m['adcReposoIzq'] as num?)?.toDouble(),
      adcCargaIzq: (m['adcCargaIzq'] as num?)?.toDouble(),
      adcTalonIzq: (m['adcTalonIzq'] as num?)?.toDouble(),
      adcPuntaIzq: (m['adcPuntaIzq'] as num?)?.toDouble(),
    );
  }).toList();
  historial.sort((a, b) => a.id.compareTo(b.id));
  // defensa contra duplicados exactos (mismo id) colados en lo ya guardado
  final idsVistos = <String>{};
  historial.retainWhere((s) => idsVistos.add(s.id));
  await purgarDatosCrudosAntiguos();
}

// tras esto se descartan las muestras crudas, solo hacen falta para el CSV de detalle
const Duration _kVidaDatosCrudos = Duration(hours: 24);

Future<void> purgarDatosCrudosAntiguos() async {
  final ahora = DateTime.now();
  var huboCambios = false;
  for (final s in historial) {
    if (s.datosSesion.isEmpty) {
      continue;
    }
    final fecha = DateTime.tryParse(s.id);
    if (fecha != null && ahora.difference(fecha) > _kVidaDatosCrudos) {
      s.datosSesion = [];
      huboCambios = true;
    }
  }
  if (huboCambios) {
    await guardarHistorial();
  }
}

// sesiones con id no parseable (no debería pasar) se incluyen siempre, para no perder datos
List<SesionActividad> sesionesEnPeriodo(String periodo) {
  final ahora = DateTime.now();
  final limite = switch (periodo) {
    'week' => ahora.subtract(const Duration(days: 7)),
    'month' => ahora.subtract(const Duration(days: 30)),
    'year' => ahora.subtract(const Duration(days: 365)),
    _ => null, // 'all'
  };
  final sesiones = historial.where((s) {
    final fecha = DateTime.tryParse(s.id);
    return fecha == null || limite == null || fecha.isAfter(limite);
  }).toList();
  sesiones.sort((a, b) => a.id.compareTo(b.id));
  return sesiones;
}

// cadencia media (spm) del periodo; 0 si no hay sesiones
double cadenciaMediaPeriodo(String periodo) {
  final sesiones = sesionesEnPeriodo(periodo);
  if (sesiones.isEmpty) {
    return 0;
  }
  return sesiones.map((s) => s.cadencia).reduce((a, b) => a + b) /
      sesiones.length;
}

// desequilibrio medio (0-100) de sesiones con dato real (ver tieneBalance); null si ninguna lo tiene
double? balanceMedioPeriodo(String periodo) {
  final sesiones =
      sesionesEnPeriodo(periodo).where((s) => s.tieneBalance).toList();
  if (sesiones.isEmpty) {
    return null;
  }
  final balanceMedio =
      sesiones.map((s) => s.balance).reduce((a, b) => a + b) /
          sesiones.length;
  return (balanceMedio - 50).abs() * 2;
}

// impacto medio (media de ambos pies) de sesiones con muestras crudas; null si ninguna las tiene
double? impactoMedioPeriodo(String periodo) {
  final sesiones =
      sesionesEnPeriodo(periodo).where((s) => s.tieneImpacto).toList();
  if (sesiones.isEmpty) {
    return null;
  }
  return sesiones
          .map((s) => (s.impacto + s.impactoIzq) / 2)
          .reduce((a, b) => a + b) /
      sesiones.length;
}

// desequilibrio: <15 normal, >35 marcado
Color colorDesequilibrio(double pct) {
  if (pct < 15) {
    return kTeal;
  }
  if (pct < 35) {
    return kOrange;
  }
  return kRed;
}

// por encima de 100 el pico medio ya supera la referencia de calibración
Color colorImpacto(double pct) {
  if (pct < 60) {
    return kTeal;
  }
  if (pct < 100) {
    return kOrange;
  }
  return kRed;
}
