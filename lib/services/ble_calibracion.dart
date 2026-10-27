part of '../main.dart';

// Estado global de la app (sesión y conexión BLE), sin gestores de estado externos
Usuario? usuarioActual; // usuario que ha iniciado sesión (null si no hay login)
List<SesionActividad> historial = []; // sesiones de actividad guardadas
// compartido con Quick Metrics del Home para que ambas vistas queden sincronizadas
String periodoMetricasSeleccionado = 'week';
// una instancia por pie (bleDer/bleIzq) para que las dos placas vayan sin pisarse
class FootBleState {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic; // característica de datos de presión
  StreamSubscription<BluetoothConnectionState>? connSub;
  Timer? watchdog;

  void limpiar() {
    watchdog?.cancel();
    watchdog = null;
    device = null;
    characteristic = null;
  }
}

final FootBleState bleDer = FootBleState();
final FootBleState bleIzq = FootBleState();
FootBleState bleEstado(Pie pie) => pie == Pie.derecha ? bleDer : bleIzq;

StreamSubscription<BluetoothAdapterState>? _bleAdapterSubGlobal;

// ADC crudo (12 bits) a % usando 2 puntos por persona/plantilla; null = sin calibrar, valores de fábrica
class CalibracionPie {
  double? adcReposo; // ADC sin presión (0%)
  double? adcCarga; // ADC con todo el peso apoyado (100%)
  // referencia talón/punta para el reparto talón/metatarso (ver _pesoTalon): un solo sensor no distingue ambas zonas
  double? adcTalon;
  double? adcPunta;
}

final CalibracionPie calibDer = CalibracionPie();
final CalibracionPie calibIzq = CalibracionPie();
CalibracionPie calibPie(Pie pie) => pie == Pie.derecha ? calibDer : calibIzq;
const double _kAdcReposoFabrica = 1800;
const double _kAdcCargaFabrica = 1100;

String _sufijoPie(Pie pie) => pie == Pie.derecha ? 'der' : 'izq';

// separada por cuenta (ver _claveUsuario): cada cuenta tiene su propia calibración
Future<void> cargarCalibracion(Pie pie) async {
  final prefs = await SharedPreferences.getInstance();
  final c = calibPie(pie);
  final s = _sufijoPie(pie);
  c.adcReposo = prefs.getDouble(_claveUsuario('calibAdcReposo_$s'));
  c.adcCarga = prefs.getDouble(_claveUsuario('calibAdcCarga_$s'));
  c.adcTalon = prefs.getDouble(_claveUsuario('calibAdcTalon_$s'));
  c.adcPunta = prefs.getDouble(_claveUsuario('calibAdcPunta_$s'));
}

// deja la calibración activa en memoria, separada por cuenta
Future<void> guardarCalibracion(
    Pie pie, double adcReposo, double adcCarga, double adcTalon, double adcPunta) async {
  final c = calibPie(pie);
  c.adcReposo = adcReposo;
  c.adcCarga = adcCarga;
  c.adcTalon = adcTalon;
  c.adcPunta = adcPunta;
  final prefs = await SharedPreferences.getInstance();
  final s = _sufijoPie(pie);
  await prefs.setDouble(_claveUsuario('calibAdcReposo_$s'), adcReposo);
  await prefs.setDouble(_claveUsuario('calibAdcCarga_$s'), adcCarga);
  await prefs.setDouble(_claveUsuario('calibAdcTalon_$s'), adcTalon);
  await prefs.setDouble(_claveUsuario('calibAdcPunta_$s'), adcPunta);
}

// sin tope superior a propósito: una pisada real puede superar el pico calibrado
double adcAPresion(double adc, Pie pie) {
  final c = calibPie(pie);
  final reposo = c.adcReposo ?? _kAdcReposoFabrica;
  final carga = c.adcCarga ?? _kAdcCargaFabrica;
  final rango = reposo - carga;
  if (rango <= 0) {
    return 0;
  }
  final presion = 100 * (reposo - adc) / rango;
  return presion < 0 ? 0 : presion;
}

// vigila la conexión BLE durante toda la vida de la app, no solo con la pantalla montada
void iniciarMonitorBle(BluetoothDevice device, Pie pie) {
  final estado = bleEstado(pie);
  estado.device = device;
  estado.connSub?.cancel();
  estado.connSub = device.connectionState.listen((s) {
    if (s == BluetoothConnectionState.disconnected) {
      estado.limpiar();
    }
  });
  _bleAdapterSubGlobal ??= FlutterBluePlus.adapterState.listen((s) {
    if (s != BluetoothAdapterState.on) {
      bleDer.limpiar();
      bleIzq.limpiar();
    }
  });

  // ping leyendo RSSI cada pocos segundos en vez de esperar el supervision timeout del SO (hasta 20s)
  estado.watchdog?.cancel();
  estado.watchdog =
      Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (estado.device != device) {
      timer.cancel();
      return;
    }
    try {
      await device.readRssi(timeout: 2);
    } catch (_) {
      timer.cancel();
      if (estado.device == device) {
        estado.limpiar();
      }
    }
  });
}

// escanea por nombre o UUID de servicio, conecta y se suscribe a notificaciones
Future<bool> escanearYConectarPie(Pie pie,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final id = idBlePara(pie);
  final completer = Completer<bool>();
  StreamSubscription<List<ScanResult>>? scanSub;
  Timer? timeoutTimer;

  Future<void> pararEscaneo() async {
    timeoutTimer?.cancel();
    await scanSub?.cancel();
    scanSub = null;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  timeoutTimer = Timer(timeout, () async {
    await pararEscaneo();
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  });

  scanSub = FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      final matchNombre = r.device.platformName == id.nombre;
      final matchUUID = r.advertisementData.serviceUuids.any((u) => u
          .toString()
          .toLowerCase()
          .contains(id.servicioUuid.toLowerCase()));
      if (matchNombre || matchUUID) {
        await pararEscaneo();
        if (completer.isCompleted) {
          return;
        }
        completer.complete(await _conectarYSuscribirPie(r.device, pie));
        return;
      }
    }
  });
  await FlutterBluePlus.startScan(timeout: timeout);
  return completer.future;
}

// reutiliza una conexión que ya estuviera activa (p.ej. desde otra pantalla)
Future<bool> _conectarYSuscribirPie(BluetoothDevice device, Pie pie) async {
  final id = idBlePara(pie);
  try {
    if (bleEstado(pie).device != device) {
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 8));
    }
  } catch (_) {
    return false;
  }
  iniciarMonitorBle(device, pie);
  // sin esto Android negocia un intervalo conservador, muy por debajo de los ~100Hz reales; no existe en iOS/desktop
  try {
    await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high);
  } catch (_) {}
  final services = await device.discoverServices();
  for (final s in services) {
    if (s.uuid.toString().toLowerCase() == id.servicioUuid) {
      for (final c in s.characteristics) {
        if (c.uuid.toString().toLowerCase() == id.caracteristicaUuid) {
          await c.setNotifyValue(true);
          bleEstado(pie).characteristic = c;
          return true;
        }
      }
    }
  }
  return false;
}
