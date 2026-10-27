part of '../main.dart';

// ---- CONSTANTS & THEME ----
// Pie evita duplicar variables/funciones de conexión-calibración por lado
enum Pie { derecha, izquierda }

class FootBleId {
  final String nombre, servicioUuid, caracteristicaUuid;
  const FootBleId(this.nombre, this.servicioUuid, this.caracteristicaUuid);
}

const FootBleId _kBleDerecha = FootBleId(
    "GOGAIT_XIAO_DERECHA",
    "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
    "beb5483e-36e1-4688-b7f5-ea07361b26a8");
const FootBleId _kBleIzquierda = FootBleId(
    "GOGAIT_XIAO_IZQUIERDA",
    "b9058af5-cb7a-4de0-8753-67184b634064",
    "7886f4fc-3ad6-4f8d-b0bf-62bea816a66f");

FootBleId idBlePara(Pie pie) =>
    pie == Pie.derecha ? _kBleDerecha : _kBleIzquierda;
String etiquetaPie(Pie pie) =>
    pie == Pie.derecha ? tr('side_right') : tr('side_left');
