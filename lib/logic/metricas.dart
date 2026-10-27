part of '../main.dart';

// Un sensor por plantilla mide talón+metatarso como una sola señal: solo da balance izq/der y Heel/Metatarsal (eje medial/lateral no medible con este hardware)

// umbral de contacto compartido por toda la app; en pruebas el ruido en Swing llegó a ~14,9, quizá subir a 18.0
const kUmbralContacto = 15.0;

// balance: 0-100 (50=simétrico). Sin muestras del pie izq. devuelve 50 en vez de fingir un reparto real
double calcularBalance(List<Map<String, dynamic>> datosSesion) {
  var sumaIzq = 0.0, sumaDer = 0.0;
  for (final d in datosSesion) {
    sumaIzq +=
        (d['talonIzq'] as num).toDouble() + (d['metaIzq'] as num).toDouble();
    sumaDer +=
        (d['talonDer'] as num).toDouble() + (d['metaDer'] as num).toDouble();
  }
  if (sumaIzq <= 0) {
    return 50;
  }
  return (100 * sumaDer / (sumaIzq + sumaDer)).clamp(0.0, 100.0);
}

// sin muestras del pie izq. el balance es el valor neutro, no un dato medido
bool tieneDatosPieIzquierdo(List<Map<String, dynamic>> datosSesion) =>
    datosSesion.any((d) =>
        (d['talonIzq'] as num).toDouble() != 0 ||
        (d['metaIzq'] as num).toDouble() != 0);

// impacto: 0-100, media del pico de presión de cada contacto por encima del umbral
double calcularImpacto(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  final picos = <double>[];
  var enContacto = false;
  var pico = 0.0;
  for (final d in datosSesion) {
    final presion = (d['talon$sufijo'] as num).toDouble() +
        (d['meta$sufijo'] as num).toDouble();
    if (presion >= kUmbralContacto) {
      if (!enContacto || presion > pico) {
        pico = presion;
      }
      enContacto = true;
    } else if (enContacto) {
      picos.add(pico);
      enContacto = false;
    }
  }
  if (enContacto) {
    picos.add(pico);
  }
  if (picos.isEmpty) {
    return 0;
  }
  return picos.reduce((a, b) => a + b) / picos.length;
}

// sesiones grabadas antes de guardar faseDer/faseIzq no tienen strikeIndex: 0 aquí significa "no medible", no talón puro
bool tieneDatosStrikeIndex(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  return datosSesion.any((d) => d['fase$sufijo'] != null);
}

// strikeIndex: 0-100 (0=talón, 50=centrado, 100=antepié), medido en la transición Swing->Heel Strike.
// Usa wMagTalon (vs. calibración talón/punta) y no _pesoTalon, que en Heel Strike siempre daría "talón puro".
double calcularStrikeIndex(List<Map<String, dynamic>> datosSesion, Pie pie) {
  final sufijo = pie == Pie.derecha ? 'Der' : 'Izq';
  final indices = <double>[];
  String? faseAnterior;
  for (final d in datosSesion) {
    final fase = d['fase$sufijo'] as String?;
    if (fase == 'Heel Strike' && faseAnterior == 'Swing') {
      final wMagTalon = (d['wMagTalon$sufijo'] as num?)?.toDouble();
      if (wMagTalon != null) {
        indices.add(100 * (1 - wMagTalon));
      }
    }
    faseAnterior = fase;
  }
  if (indices.isEmpty) {
    return 0;
  }
  return indices.reduce((a, b) => a + b) / indices.length;
}

// media de ambos pies en un tramo, igual que el badge "Both" de Impact en la UI
double _impactoMedioTramo(List<Map<String, dynamic>> tramo) {
  final der = calcularImpacto(tramo, Pie.derecha);
  final izq = calcularImpacto(tramo, Pie.izquierda);
  return (der + izq) / 2;
}

// menos de 30 muestras no dan 3 tramos con datos suficientes para fatiga fiable
const int _kMinMuestrasFatiga = 30;

bool tieneDatosFatiga(List<Map<String, dynamic>> datosSesion) =>
    datosSesion.length >= _kMinMuestrasFatiga &&
    _impactoMedioTramo(
            datosSesion.sublist(0, datosSesion.length ~/ 3)) >
        0;

// fatiga: % de subida del impacto medio del último tercio vs. el primero; puede salir negativo
double calcularFatiga(List<Map<String, dynamic>> datosSesion) {
  if (!tieneDatosFatiga(datosSesion)) {
    return 0;
  }
  final tercio = datosSesion.length ~/ 3;
  final inicio = datosSesion.sublist(0, tercio);
  final fin = datosSesion.sublist(datosSesion.length - tercio);
  final impactoInicio = _impactoMedioTramo(inicio);
  final impactoFin = _impactoMedioTramo(fin);
  return 100 * (impactoFin - impactoInicio) / impactoInicio;
}

// los 3 valores de impacto medio (inicio/mitad/fin) del gráfico de fatiga
List<double> tramosFatiga(List<Map<String, dynamic>> datosSesion) {
  if (!tieneDatosFatiga(datosSesion)) {
    return const [0, 0, 0];
  }
  final tercio = datosSesion.length ~/ 3;
  return [
    _impactoMedioTramo(datosSesion.sublist(0, tercio)),
    _impactoMedioTramo(datosSesion.sublist(tercio, tercio * 2)),
    _impactoMedioTramo(datosSesion.sublist(tercio * 2)),
  ];
}

// performanceScore: 0-100, penalización media de balance/fatiga/zancadaRatio; null si ninguna disponible
double? calcularPerformanceScore({
  required double balance,
  required bool tieneBalance,
  required double fatiga,
  required bool tieneFatiga,
  required double? zancadaRatio,
}) {
  final penalizaciones = <double>[];
  if (tieneBalance) {
    penalizaciones.add((balance - 50).abs() * 2);
  }
  if (tieneFatiga) {
    penalizaciones.add(fatiga);
  }
  if (zancadaRatio != null && zancadaRatio > 0) {
    penalizaciones.add((zancadaRatio - 1.0).abs() * 100);
  }
  if (penalizaciones.isEmpty) {
    return null;
  }
  final penalizacionMedia =
      penalizaciones.reduce((a, b) => a + b) / penalizaciones.length;
  return (100 - penalizacionMedia).clamp(0.0, 100.0);
}

// insights generados con reglas fijas sobre las métricas reales
String generarInsights(SesionActividad s) {
  final frases = <String>[];
  if (s.tieneBalance) {
    // mismo umbral que colorDesequilibrio (15%): desviación = desequilibrio/2
    final desviacion = (s.balance - 50).abs();
    if (desviacion < 7.5) {
      frases.add(tr('insight_balanced'));
    } else {
      final lado = s.balance > 50 ? tr('side_right') : tr('side_left');
      frases.add(tr('insight_favors_side')
          .replaceAll('{side}', lado.toLowerCase())
          .replaceAll('{right}', '${s.balance.round()}')
          .replaceAll('{left}', '${(100 - s.balance).round()}'));
    }
  }
  if (s.tieneFatiga) {
    final fatiga = s.fatiga;
    frases.add(fatiga >= 20
        ? tr('insight_fatigue_rising')
        : tr('insight_fatigue_stable'));
  }
  if (s.zancadaRatio > 1.15) {
    frases.add(tr('insight_stride_longer'));
  } else if (s.zancadaRatio > 0 && s.zancadaRatio < 0.85) {
    frases.add(tr('insight_stride_shorter'));
  }
  if (frases.isEmpty) {
    return tr('insight_not_enough_data');
  }
  return frases.join(' ');
}

// 100% de calibración = todo el peso apoyado, así que impacto/100 × peso ≈ kg en el pico
double impactoAKg(double impacto, double pesoKg) {
  if (pesoKg <= 0) {
    return 0;
  }
  return impacto / 100 * pesoKg;
}

// coeficientes de Hoeger et al. (2008, ACSM's Health & Fitness Journal): 0,415 caminar, 0,50 correr
double zancadaEsperadaM(double alturaCm, String tipoActividad) {
  final coef = tipoActividad == 'walking' ? 0.415 : 0.50;
  return (alturaCm / 100) * coef;
}

// ratio zancada real/esperada, 1.0 = lo esperado; null si falta altura, pasos o distancia
double? ratioZancada(
    double distanciaKm, int pasos, double alturaCm, String tipoActividad) {
  if (alturaCm <= 0 || pasos <= 0 || distanciaKm <= 0) {
    return null;
  }
  final esperadaM = zancadaEsperadaM(alturaCm, tipoActividad);
  if (esperadaM <= 0) {
    return null;
  }
  final zancadaRealM = (distanciaKm * 1000) / pasos;
  return zancadaRealM / esperadaM;
}
