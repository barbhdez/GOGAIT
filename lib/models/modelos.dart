part of '../main.dart';

// ---- MODELS ----
// Datos del usuario logueado: perfil, medidas corporales y preferencias.
class Usuario {
  String email, nombre, apellido, genero, cumpleanos, contrasena, arco;
  double altura, peso, shoeSize;
  String? fotoPath, patologia;
  Usuario({
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.genero,
    required this.contrasena,
    required this.altura,
    required this.peso,
    required this.cumpleanos,
    required this.shoeSize,
    required this.arco,
    this.fotoPath,
    this.patologia,
  });
}

// Sin altura/peso reales no se puede calcular Impacto en kg ni Stride Ratio
bool _perfilIncompleto(Usuario? u) =>
    u == null || u.altura < 140 || u.peso < 40;

// Sesión guardada en el historial (running, walking, trail...) con sus métricas y, opcionalmente, muestras crudas
class SesionActividad {
  String id, titulo, descripcion, tipo, fecha, hora, duracion;
  // presionMetaIzq/presionTalonIzq quedan a 0 si no hubo datos del pie izquierdo (ver tieneDatosPieIzquierdo)
  final double presionMeta, presionTalon;
  final double presionMetaIzq, presionTalonIzq;
  final int pasos;
  final double cadencia; // pasos/min medios de la sesión
  final double distanciaKm; // medida por GPS
  final double balance, impacto; // ver calcularBalance/calcularImpacto
  final double impactoIzq;
  final double impactoKg; // ver impactoAKg, 0 si no había peso registrado
  final double zancadaRatio; // ver ratioZancada, 0 si faltaba algún dato
  // strikeIndex: 0=talón, 50=centrado, 100=antepié; 0 también si no hay contactos medibles
  final double strikeIndexDer, strikeIndexIzq;
  // distinguen "0 real" de "no medible" en cada métrica
  final bool tieneBalance, tieneFatiga, tieneStrikeDer, tieneStrikeIzq;
  final bool tieneImpacto;
  final double fatiga;
  final List<double> tramosFatiga;
  // no es final: se vacía al purgar muestras crudas antiguas (ver purgarDatosCrudosAntiguos)
  List<Map<String, dynamic>> datosSesion;
  // una entrada por posición GPS, 'seg' comparte eje temporal con datosSesion
  final List<Map<String, dynamic>> recorrido;
  // calibración de cada plantilla en el momento de guardar, null si no llegó a calibrarse
  final double? adcReposoDer, adcCargaDer, adcTalonDer, adcPuntaDer;
  final double? adcReposoIzq, adcCargaIzq, adcTalonIzq, adcPuntaIzq;
  SesionActividad({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fecha,
    required this.hora,
    required this.duracion,
    required this.presionMeta,
    required this.presionTalon,
    this.presionMetaIzq = 0,
    this.presionTalonIzq = 0,
    this.pasos = 0,
    this.cadencia = 0,
    this.distanciaKm = 0,
    this.balance = 0,
    this.impacto = 0,
    this.impactoIzq = 0,
    this.impactoKg = 0,
    this.zancadaRatio = 0,
    this.strikeIndexDer = 0,
    this.strikeIndexIzq = 0,
    this.tieneBalance = false,
    this.tieneFatiga = false,
    this.tieneStrikeDer = false,
    this.tieneStrikeIzq = false,
    this.tieneImpacto = false,
    this.fatiga = 0,
    this.tramosFatiga = const [0, 0, 0],
    this.datosSesion = const [],
    this.recorrido = const [],
    this.adcReposoDer,
    this.adcCargaDer,
    this.adcTalonDer,
    this.adcPuntaDer,
    this.adcReposoIzq,
    this.adcCargaIzq,
    this.adcTalonIzq,
    this.adcPuntaIzq,
  });
}
