part of '../main.dart';

// ---- LIVE ACTIVITY SCREEN ----
// Cronómetro de sesión, heatmap de presión en tiempo real y conexión BLE (propia o heredada).
class VistaActividad extends StatefulWidget {
  final String tipoActividad;
  const VistaActividad({super.key, this.tipoActividad = 'running'});
  @override
  State<VistaActividad> createState() => _VistaActividadState();
}

class _VistaActividadState extends State<VistaActividad> with IdiomaListenerMixin {
  int _seg = 0;
  Timer? _timerCrono;
  bool _running = false, _paused = false;
  StreamSubscription<List<int>>? _notifySubDer, _notifySubIzq;
  StreamSubscription<BluetoothConnectionState>? _connSubDer, _connSubIzq;
  _EstadoConexion _estadoConexDer = _EstadoConexion.pendiente;
  _EstadoConexion _estadoConexIzq = _EstadoConexion.pendiente;
  _EstadoConexion _estadoConexDe(Pie pie) =>
      pie == Pie.derecha ? _estadoConexDer : _estadoConexIzq;
  void _setEstadoConex(Pie pie, _EstadoConexion e) {
    if (pie == Pie.derecha) {
      _estadoConexDer = e;
    } else {
      _estadoConexIzq = e;
    }
  }

  bool get _algunaConectada =>
      _estadoConexDer == _EstadoConexion.conectado ||
      _estadoConexIzq == _EstadoConexion.conectado;
  bool get _ambasConectadas =>
      _estadoConexDer == _EstadoConexion.conectado &&
      _estadoConexIzq == _EstadoConexion.conectado;

  // Distancia recorrida medida por GPS, independiente de los sensores de presión.
  StreamSubscription<Position>? _posSub;
  Position? _ultimaPosicion;
  double _distanciaMetros = 0;
  // Trazado: una entrada por posición GPS, no por muestra (100Hz sería excesivo); comparte 'seg' con _datosSesion.
  final List<Map<String, dynamic>> _recorrido = [];
  double _presionTalonIzq = 0, _presionMetaIzq = 0;
  double _presionTalonDer = 0, _presionMetaDer = 0;
  final List<Map<String, dynamic>> _datosSesion = [];
  DateTime? _ultimoRefrescoUi;

  // Orden izq->der (no el de Pie.values), igual que el heatmap, para que la etiqueta de fase corresponda.
  static const List<Pie> _kOrdenPies = [Pie.izquierda, Pie.derecha];

  // Presión instantánea de un pie (0-100): talón+metatarso reconstruye la lectura real.
  double _presionActual(Pie pie) => pie == Pie.derecha
      ? _presionTalonDer + _presionMetaDer
      : _presionTalonIzq + _presionMetaIzq;

  // Detector de fase de marcha y pasos, uno por pie (ver _EstadoMarcha).
  final _EstadoMarcha _marchaDer = _EstadoMarcha();
  final _EstadoMarcha _marchaIzq = _EstadoMarcha();
  _EstadoMarcha _marcha(Pie pie) => pie == Pie.derecha ? _marchaDer : _marchaIzq;
  static const int _kMuestrasParaConfirmar = 3;
  static const Duration _kVentanaCadencia = Duration(seconds: 10);

  // Reparte presión en 30 puntos según wTalon (ver _pesoTalon): dedos/bola=metatarso, talón=talón, arco=resto (máx en Midstance); sin suavizado, cambia en seco con la fase.
  List<double> _heatmapDesdeReparto(double presion, double wTalon) {
    // Bajo el umbral de contacto es ruido (pie en el aire): se apaga del todo en vez de teñir el mapa.
    if (presion < kUmbralContacto) {
      return List.filled(30, 0);
    }
    final talon = presion * wTalon;
    final meta = presion * (1 - wTalon);
    final arco = presion * (1 - 2 * (wTalon - 0.5).abs());
    return List.generate(30, (i) {
      if (i < 5) {
        return meta;
      }
      if (i < 14) {
        return meta * 0.8;
      }
      if (i < 19) {
        return arco;
      }
      return talon;
    });
  }

  // Heatmap en vivo del pie izquierdo (ver _heatmapDesdeReparto).
  List<double> get _leftData => _heatmapDesdeReparto(
      _presionActual(Pie.izquierda), _pesoTalon(Pie.izquierda));
  // Igual que _leftData pero para el pie derecho.
  List<double> get _rightData => _heatmapDesdeReparto(
      _presionActual(Pie.derecha), _pesoTalon(Pie.derecha));

  // Si ya había placas conectadas (VistaBluetooth/VistaPreparacion) reutiliza esas conexiones; si no, se conecta desde aquí.
  @override
  void initState() {
    super.initState();
    var algunaYaConectada = false;
    for (final pie in Pie.values) {
      final estado = bleEstado(pie);
      if (estado.device != null && estado.characteristic != null) {
        _setEstadoConex(pie, _EstadoConexion.conectado);
        _suscribirNotify(pie);
        _escucharDesconexion(pie);
        algunaYaConectada = true;
      }
    }
    if (algunaYaConectada) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_running) {
          _iniciarTimer();
        }
      });
    }
  }

  // Se suscribe a las notificaciones de presión de la placa de un pie.
  void _suscribirNotify(Pie pie) {
    final char = bleEstado(pie).characteristic;
    if (char == null) {
      return;
    }
    final sub = char.lastValueStream.listen((data) => _procesarDatos(data, pie));
    if (pie == Pie.derecha) {
      _notifySubDer?.cancel();
      _notifySubDer = sub;
    } else {
      _notifySubIzq?.cancel();
      _notifySubIzq = sub;
    }
  }

  // Escucha la desconexión de la placa de un pie para reflejarlo en la UI.
  void _escucharDesconexion(Pie pie) {
    final device = bleEstado(pie).device;
    if (device == null) {
      return;
    }
    final sub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() => _setEstadoConex(pie, _EstadoConexion.pendiente));
      }
    });
    if (pie == Pie.derecha) {
      _connSubDer?.cancel();
      _connSubDer = sub;
    } else {
      _connSubIzq?.cancel();
      _connSubIzq = sub;
    }
  }

  // Arranca (o reanuda) el cronómetro de duración de la sesión.
  void _iniciarTimer() {
    _timerCrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _seg++);
      }
    });
    setState(() => _running = true);
    if (_posSub == null) {
      _iniciarSeguimientoUbicacion();
    }
  }

  // Pide permiso de ubicación y arranca el GPS que suma distancia entre posiciones; sin permiso/GPS, se queda a 0 sin bloquear la sesión.
  Future<void> _iniciarSeguimientoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    if (!mounted) {
      return;
    }
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // ignora ruido GPS por debajo de 3m
      ),
    ).listen((pos) {
      if (_ultimaPosicion != null && _running) {
        _distanciaMetros += Geolocator.distanceBetween(
          _ultimaPosicion!.latitude,
          _ultimaPosicion!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      _ultimaPosicion = pos;
      if (_running) {
        _recorrido.add({
          'seg': _seg,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'altitud': pos.altitude,
        });
      }
    });
  }

  // Distancia recorrida en la sesión, en kilómetros.
  double get _distanciaKm => _distanciaMetros / 1000;

  // Escanea 15s la placa de un pie para conectar desde esta pantalla, sin pasar por VistaBluetooth.
  Future<void> _conectarPie(Pie pie) async {
    if (_estadoConexDe(pie) == _EstadoConexion.buscando ||
        _estadoConexDe(pie) == _EstadoConexion.conectado) {
      return;
    }
    setState(() => _setEstadoConex(pie, _EstadoConexion.buscando));
    final ok = await escanearYConectarPie(pie, timeout: const Duration(seconds: 15));
    if (!mounted) {
      return;
    }
    if (ok) {
      _suscribirNotify(pie);
      _escucharDesconexion(pie);
      setState(() => _setEstadoConex(pie, _EstadoConexion.conectado));
      if (!_running) {
        _iniciarTimer();
      }
    } else {
      setState(() => _setEstadoConex(pie, _EstadoConexion.fallo));
    }
  }

  // Curva en "M": Heel Strike(sube)->Midstance(valle)->Propulsion(2º pico)->Swing(cae a 0); exige varias muestras seguidas para confirmar y filtrar ruido.
  void _actualizarFaseMarcha(double presion, Pie pie) {
    final m = _marcha(pie);
    final direccion = presion > m.ultimaPresion
        ? 1
        : (presion < m.ultimaPresion ? -1 : m.direccion);
    if (direccion == m.direccion) {
      m.muestrasEnDireccion++;
    } else {
      m.direccion = direccion;
      m.muestrasEnDireccion = 1;
    }
    final cambioConfirmado = m.muestrasEnDireccion >= _kMuestrasParaConfirmar;

    switch (m.fase) {
      case 'Heel Strike':
        if (cambioConfirmado && m.direccion == -1) {
          m.fase = 'Midstance'; // primer pico alcanzado, empieza a bajar
        }
        break;
      case 'Midstance':
        if (cambioConfirmado && m.direccion == 1) {
          m.fase = 'Propulsion'; // valle superado, vuelve a subir
        }
        break;
      case 'Propulsion':
        if (presion < kUmbralContacto) {
          m.fase = 'Swing'; // el pie se ha despegado del suelo
        }
        break;
      case 'Swing':
      default:
        if (presion >= kUmbralContacto) {
          m.fase = 'Heel Strike'; // el pie vuelve a tocar el suelo
          _registrarPaso(pie);
        }
        break;
    }
    m.ultimaPresion = presion;
  }

  // Registra un apoyo de talón para pasos/cadencia; descarta del historial los apoyos fuera de la ventana.
  void _registrarPaso(Pie pie) {
    final m = _marcha(pie);
    m.pasos++;
    final ahora = DateTime.now();
    m.tiemposPaso.add(ahora);
    m.tiemposPaso.removeWhere((t) => ahora.difference(t) > _kVentanaCadencia);
  }

  // Pasos totales reales, suma de los apoyos detectados en cada pie.
  int get _pasosTotales => _marchaDer.pasos + _marchaIzq.pasos;

  // Cadencia instantánea (pasos/min) de ambos pies en los últimos _kVentanaCadencia segundos; con <2 apoyos no hay dato suficiente.
  int get _cadencia {
    final tiempos = [..._marchaDer.tiemposPaso, ..._marchaIzq.tiemposPaso]
      ..sort();
    if (tiempos.length < 2) {
      return 0;
    }
    final segundos =
        tiempos.last.difference(tiempos.first).inMilliseconds / 1000;
    if (segundos <= 0) {
      return 0;
    }
    return ((tiempos.length - 1) / segundos * 60).round();
  }

  // Traduce el código interno de fase al texto de pantalla, sin tocar el código usado en comparaciones.
  String _trFase(String fase) {
    switch (fase) {
      case 'Heel Strike':
        return tr('gait_phase_heel_strike');
      case 'Midstance':
        return tr('gait_phase_midstance');
      case 'Propulsion':
        return tr('gait_phase_propulsion');
      default:
        return tr('gait_phase_swing');
    }
  }

  // Color de una fase de marcha, para los chips de estado en la UI.
  Color _colorFase(String fase) {
    switch (fase) {
      case 'Heel Strike':
        return kOrange;
      case 'Midstance':
        return kTeal;
      case 'Propulsion':
        return kRed;
      default:
        return kGray;
    }
  }

  // Fracción de talón (0-1) por fase: Heel Strike=1, Midstance=0.5, Propulsion/Swing=0.
  double _pesoTalon(Pie pie) {
    switch (_marcha(pie).fase) {
      case 'Heel Strike':
        return 1.0;
      case 'Midstance':
        return 0.5;
      default: // Propulsion, Swing
        return 0.0;
    }
  }

  // Fracción de talón por magnitud (vs calibración talón/punta), para calcularStrikeIndex: _pesoTalon en Heel Strike siempre da 100%, esta señal distingue el patrón real.
  double? _wMagTalonDer, _wMagTalonIzq;
  double? _pesoTalonMagnitud(double presion, Pie pie) {
    final calib = calibPie(pie);
    if (calib.adcTalon == null || calib.adcPunta == null) {
      return null;
    }
    final refTalon = adcAPresion(calib.adcTalon!, pie);
    final refPunta = adcAPresion(calib.adcPunta!, pie);
    final distTalon = (presion - refTalon).abs();
    final distPunta = (presion - refPunta).abs();
    final sumaDist = distTalon + distPunta;
    return sumaDist <= 0 ? 0.5 : distPunta / sumaDist;
  }

  // Parsea un paquete BLE, actualiza la presión mostrada y, si la sesión está en marcha, añade la muestra a los datos a guardar.
  void _procesarDatos(List<int> data, Pie pie) {
    if (data.isEmpty) {
      return;
    }
    final raw = utf8.decode(data).trim();
    // ADC crudo (0-4095); el % se calcula con la calibración del usuario, no un rango fijo de firmware.
    final adc = double.tryParse(raw);
    if (adc == null) {
      return;
    }
    final presion = adcAPresion(adc, pie);
    // Un único sensor por pie: se reparte la lectura entre talón/metatarso según la fase (ver _pesoTalon).
    _actualizarFaseMarcha(presion, pie);
    final fase = _marcha(pie).fase;
    final wTalon = _pesoTalon(pie);
    // En Swing _pesoTalon daría el mismo peso que Propulsion; se corta a 0 para no contar ruido como apoyo real.
    final t = fase == 'Swing' ? 0.0 : presion * wTalon;
    final m = fase == 'Swing' ? 0.0 : presion * (1 - wTalon);
    final wMag = _pesoTalonMagnitud(presion, pie);
    if (pie == Pie.derecha) {
      _presionTalonDer = t;
      _presionMetaDer = m;
      _wMagTalonDer = wMag;
    } else {
      _presionTalonIzq = t;
      _presionMetaIzq = m;
      _wMagTalonIzq = wMag;
    }
    // Repintar a 100Hz excede lo que la pantalla refresca; se limita a ~60/seg (16ms), pero cada muestra se sigue guardando.
    final ahora = DateTime.now();
    if (mounted &&
        (_ultimoRefrescoUi == null ||
            ahora.difference(_ultimoRefrescoUi!) >=
                const Duration(milliseconds: 16))) {
      _ultimoRefrescoUi = ahora;
      setState(() {});
    }
    if (_running) {
      _datosSesion.add({
        'seg': _seg,
        'talonIzq': _presionTalonIzq,
        'metaIzq': _presionMetaIzq,
        'talonDer': _presionTalonDer,
        'metaDer': _presionMetaDer,
        'faseIzq': _marchaIzq.fase,
        'faseDer': _marchaDer.fase,
        'wMagTalonIzq': _wMagTalonIzq,
        'wMagTalonDer': _wMagTalonDer,
      });
    }
  }

  // Formatea segundos como mm:ss.
  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // Libera timers/streams y desconecta las placas gestionadas desde esta pantalla al salir.
  @override
  void dispose() {
    _timerCrono?.cancel();
    _notifySubDer?.cancel();
    _notifySubIzq?.cancel();
    _connSubDer?.cancel();
    _connSubIzq?.cancel();
    _posSub?.cancel();
    if (_connSubDer != null) {
      unawaited(bleDer.device?.disconnect());
    }
    if (_connSubIzq != null) {
      unawaited(bleIzq.device?.disconnect());
    }
    super.dispose();
  }

  // Navega a la pantalla de resumen para revisar y guardar la sesión.
  void _irAResumen() {
    Navigator.push(
        context,
        gogaitRoute(
            builder: (_) => VistaResumen(
                segundos: _seg,
                onFinalizar: () => _timerCrono?.cancel(),
                presionMetaIzq: _presionMetaIzq,
                presionTalonIzq: _presionTalonIzq,
                presionMetaDer: _presionMetaDer,
                presionTalonDer: _presionTalonDer,
                pasos: _pasosTotales,
                distanciaKm: _distanciaKm,
                tipoInicial: widget.tipoActividad,
                datosSesion: List.from(_datosSesion),
                recorrido: List.from(_recorrido))));
  }

  // Al volver atrás: sin sesión en marcha sale directo, con sesión pregunta antes de ir al resumen.
  Future<void> _confirmarFinalizar() async {
    if (!_running) {
      Navigator.pop(context);
      return;
    }
    final finalizar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('finish_activity_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('finish_activity_msg'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('finish_button'),
                  style: const TextStyle(
                      color: kOrange, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (finalizar == true && mounted) {
      _irAResumen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            return;
          }
          await _confirmarFinalizar();
        },
        child: Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(children: [
                          GestureDetector(
                              onTap: _confirmarFinalizar,
                              child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: kCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kGrayDark)),
                                  child: const Icon(Icons.chevron_left,
                                      color: Colors.white, size: 20))),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(tr('live_analysis'),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            const Icon(Icons.bluetooth, color: kTeal, size: 14),
                            const SizedBox(width: 4),
                            Text(
                                _ambasConectadas
                                    ? tr('status_connected')
                                    : _algunaConectada
                                        ? tr('ble_half_connected')
                                        : tr('searching_short'),
                                style: const TextStyle(
                                    color: kTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ])),
                    ])),
            if (!_ambasConectadas)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: GogaitCard(
                      child: Column(children: [
                        for (final pie in Pie.values) ...[
                          if (pie == Pie.izquierda)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                    color: Color(0xFF374151), height: 1)),
                          Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(
                                        '${pie == Pie.derecha ? tr('insole_right') : tr('insole_left')}: ${_textoEstadoConex(_estadoConexDe(pie))}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                            color: _estadoConexDe(pie) ==
                                                    _EstadoConexion.buscando
                                                ? kOrange
                                                : _estadoConexDe(pie) ==
                                                        _EstadoConexion
                                                            .conectado
                                                    ? kTeal
                                                    : kGray,
                                            fontSize: 13))),
                                if (_estadoConexDe(pie) !=
                                    _EstadoConexion.buscando)
                                  if (_estadoConexDe(pie) ==
                                      _EstadoConexion.conectado)
                                    const Icon(Icons.check_circle,
                                        color: kTeal, size: 18)
                                  else
                                    GestureDetector(
                                        onTap: () => _conectarPie(pie),
                                        child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                                gradient: kGradient,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(tr('connect_button'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600))))
                                else
                                  const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: kOrange)),
                              ]),
                        ],
                      ]))),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Text(tr('session_duration'),
                      style: const TextStyle(color: kGray, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_fmt(_seg),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const SizedBox(height: 10),
                  // Fase + lectura cruda por pie, mismo orden izq/der que el heatmap; solo para comprobar que el sensor mide.
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final pie in _kOrdenPies)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: _colorFase(_marcha(pie).fase)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                      '${_trFase(_marcha(pie).fase)} · ${_presionActual(pie).round()}%',
                                      style: TextStyle(
                                          color: _colorFase(_marcha(pie).fase),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600))),
                          ])),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(children: [
                      GogaitCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            Text(tr('plantar_pressure'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  FootHeatmapWidget(
                                      data: _leftData,
                                      label: tr('left_foot'),
                                      isLeft: true),
                                  FootHeatmapWidget(
                                      data: _rightData,
                                      label: tr('right_foot'),
                                      isLeft: false),
                                ]),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF374151)),
                            const SizedBox(height: 8),
                            Text(tr('pressure_level'),
                                style: const TextStyle(color: kGray, fontSize: 11)),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(tr('low_label'),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: kGray, fontSize: 11)),
                                  ),
                                  ...[
                                    0xFFFFE082,
                                    0xFFFFC107,
                                    0xFFFF8A00,
                                    0xFFFF3D57,
                                    0xFFFF0000,
                                    0xFFB026FF
                                  ].map((c) => Container(
                                      width: 24,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      decoration: BoxDecoration(
                                          color: Color(c),
                                          borderRadius:
                                              BorderRadius.circular(4)))),
                                  const Text(' >100%',
                                      style: TextStyle(
                                          color: kGray, fontSize: 11)),
                                ]),
                          ])),
                      const SizedBox(height: 12),
                      Row(
                          children: [
                        {
                          'label': tr('metric_distance'),
                          'value': '${_distanciaKm.toStringAsFixed(2)} km',
                          'color': kRed,
                          'ultimo': false,
                        },
                        {
                          'label': tr('metric_cadence'),
                          'value': '$_cadencia',
                          'color': kPurple,
                          'ultimo': true,
                          'info': tr('cadence_info'),
                        },
                      ]
                              .map((m) => Expanded(
                                      child: Padding(
                                    padding: EdgeInsets.only(
                                        right: (m['ultimo'] as bool) ? 0 : 8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: kCard,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: kGrayDark.withValues(
                                                    alpha: 0.5))),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Flexible(
                                                  child: Text(
                                                      m['label'] as String,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      maxLines: 1,
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 11)),
                                                ),
                                                if (m['info'] != null)
                                                  InfoTip(
                                                      titulo:
                                                          m['label'] as String,
                                                      texto: m['info']
                                                          as String),
                                              ]),
                                              const SizedBox(height: 4),
                                              Text(m['value'] as String,
                                                  style: TextStyle(
                                                      color:
                                                          m['color'] as Color,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ])),
                                  )))
                              .toList()),
                    ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: () {
                              if (!mounted) {
                                return;
                              }
                              setState(() => _paused = !_paused);
                              if (_paused) {
                                _timerCrono?.cancel();
                              } else if (_running) {
                                _timerCrono = Timer.periodic(
                                    const Duration(seconds: 1), (_) {
                                  if (mounted) {
                                    setState(() => _seg++);
                                  }
                                });
                              }
                            },
                            child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                    color: kCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kGrayDark)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          _paused
                                              ? Icons.play_arrow
                                              : Icons.pause,
                                          color: Colors.white,
                                          size: 20),
                                      const SizedBox(width: 6),
                                      Text(_paused ? tr('resume_button') : tr('pause_button'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ])))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GestureDetector(
                            onTap: !_running
                                ? (_algunaConectada ? () => _iniciarTimer() : null)
                                : _irAResumen,
                            child: Opacity(
                                opacity:
                                    (!_running && !_algunaConectada) ? 0.4 : 1.0,
                                child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                        gradient: kGradient,
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                              _running
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 20),
                                          const SizedBox(width: 6),
                                          Text(_running ? tr('finish_button') : tr('start_button'),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600)),
                                        ]))))),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: kRed)),
                    const SizedBox(width: 6),
                    Text(tr('recording_in_progress'),
                        style: const TextStyle(color: kGray, fontSize: 13)),
                  ]),
                ])),
          ])),
        ));
  }
}
