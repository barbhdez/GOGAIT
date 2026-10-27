part of '../main.dart';

// ---- INSOLE PREPARATION SCREEN (splash obligatorio) ----
// Paso obligatorio antes de Live Analysis: conectar y calibrar de cero cada vez (histéresis de la fibra y peso del usuario cambian); al completar navega sola a VistaActividad.
class VistaPreparacion extends StatefulWidget {
  final String tipoActividad;
  const VistaPreparacion({super.key, required this.tipoActividad});
  @override
  State<VistaPreparacion> createState() => _VistaPreparacionState();
}

enum _TipoEstadoBle { noConectado, buscando, conectado, noEncontrado, desconectado }

class _VistaPreparacionState extends State<VistaPreparacion> with IdiomaListenerMixin {
  // Se calibra primero el pie derecho y luego el izquierdo; ver _cambiarAPie.
  Pie _pieActual = Pie.derecha;
  bool _conectado = false, _conectando = false, _escaneando = false;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // Guardado como "tipo" + parámetro (no texto traducido) para que _estadoBleTexto refleje el idioma actual.
  _TipoEstadoBle _tipoEstadoBle = _TipoEstadoBle.noConectado;
  String? _nombreBuscando;

  String get _estadoBleTexto {
    switch (_tipoEstadoBle) {
      case _TipoEstadoBle.noConectado:
        return tr('status_not_connected');
      case _TipoEstadoBle.buscando:
        return tr('searching_device').replaceAll('{name}', _nombreBuscando ?? '');
      case _TipoEstadoBle.conectado:
        return _insoleConectadoMsg(_pieActual);
      case _TipoEstadoBle.noEncontrado:
        return tr('insole_not_found');
      case _TipoEstadoBle.desconectado:
        return tr('disconnected');
    }
  }

  String _insoleConectadoMsg(Pie pie) =>
      tr('insole_side_connected').replaceAll('{side}', etiquetaPie(pie));

  // Solo se pide saltar en Run/Trekking: andar ya ronda 1.1-1.2x el peso corporal en el pico, basta apoyo en calma.
  bool get _conSaltos => widget.tipoActividad != 'walking';

  // Pasos con saltos: 0 nada·1 reposo·2 calma·3 +salto·4 talón calma·5 +salto·6 punta calma·7 +salto.
  // Sin saltos: 0 nada·1 reposo·2 carga·3 talón·4 punta. Con salto, se guarda el pico más alto de las dos capturas.
  int _pasoCalibracion = 0;
  bool _muestreando = false;
  StreamSubscription<List<int>>? _muestreoSub;
  final List<double> _muestras = [];
  double? _adcReposo,
      _adcCargaPie,
      _adcCarga,
      _adcTalonPie,
      _adcTalon,
      _adcPuntaPie,
      _adcPunta;
  String? _errorCalibracion;

  // Suscripción BLE permanente (no la de 2s de _capturarPaso) para feedback en vivo antes de pulsar "Capture".
  StreamSubscription<List<int>>? _liveSub;
  double _lecturaEnVivo = 0;
  double _adcCrudoEnVivo = 0;
  DateTime? _ultimoRefrescoLive;

  // Presión en vivo con reposo/carga de ESTA calibración (no la guardada vía adcAPresion); null hasta tener ambas.
  double? get _presionEnVivoCalibrada {
    if (_adcReposo == null || _adcCarga == null) {
      return null;
    }
    final rango = _adcReposo! - _adcCarga!;
    if (rango <= 0) {
      return 0;
    }
    final presion = 100 * (_adcReposo! - _adcCrudoEnVivo) / rango;
    return presion < 0 ? 0 : presion;
  }

  @override
  void initState() {
    super.initState();
    final estado = bleEstado(_pieActual);
    if (estado.device != null && estado.characteristic != null) {
      _conectado = true;
      _tipoEstadoBle = _TipoEstadoBle.conectado;
      _escucharDesconexion();
      _iniciarLive();
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _muestreoSub?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  void _escucharDesconexion() {
    _connSub?.cancel();
    final device = bleEstado(_pieActual).device;
    if (device == null) {
      return;
    }
    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() {
          _conectado = false;
          _tipoEstadoBle = _TipoEstadoBle.desconectado;
        });
      }
    });
  }

  // Escucha el ADC crudo (throttled a ~60/s) para reflejar al instante en el mapa de calor qué zona se presiona.
  void _iniciarLive() {
    _liveSub?.cancel();
    _liveSub = bleEstado(_pieActual).characteristic!.lastValueStream.listen((data) {
      final v = double.tryParse(utf8.decode(data).trim());
      if (v == null || !mounted) {
        return;
      }
      final ahora = DateTime.now();
      if (_ultimoRefrescoLive == null ||
          ahora.difference(_ultimoRefrescoLive!) >=
              const Duration(milliseconds: 16)) {
        _ultimoRefrescoLive = ahora;
        setState(() {
          _lecturaEnVivo = adcAPresion(v, _pieActual);
          _adcCrudoEnVivo = v;
        });
      }
    });
  }

  // Reparte la lectura en vivo entre talón/metatarso según el sub-paso, para resaltar solo la zona que toca.
  List<double> get _heatmapEnVivo {
    // Solo se llama con referencias ya listas (ver condición en build()), así que _presionEnVivoCalibrada no es null aquí.
    final presion = _presionEnVivoCalibrada ?? _lecturaEnVivo;
    double talon = presion, meta = presion;
    final heelActivo = _conSaltos
        ? (_pasoCalibracion == 3 || _pasoCalibracion == 4)
        : _pasoCalibracion == 2;
    final forefootActivo = _conSaltos
        ? (_pasoCalibracion == 5 || _pasoCalibracion == 6)
        : _pasoCalibracion == 3;
    if (heelActivo) {
      meta = 0; // sub-paso(s) "solo talón"
    } else if (forefootActivo) {
      talon = 0; // sub-paso(s) "solo punta"
    }
    return List.generate(30, (i) {
      if (i < 5) {
        return meta;
      }
      if (i < 14) {
        return meta * 0.8;
      }
      if (i < 19) {
        return 10;
      }
      return talon;
    });
  }

  // Si la lectura en vivo coincide con lo esperado en el sub-paso (sin presión = pie en aire; resto = contacto).
  bool get _faseConfirmada {
    final contacto = _lecturaEnVivo >= kUmbralContacto;
    return _pasoCalibracion == 0 ? !contacto : contacto;
  }

  // Texto de confirmación bajo el mapa de calor, según el sub-paso activo.
  String get _etiquetaFaseCalib {
    final contacto = _lecturaEnVivo >= kUmbralContacto;
    if (!_conSaltos) {
      switch (_pasoCalibracion) {
        case 0:
          return contacto
              ? tr('phase_pressure_lift')
              : tr('phase_foot_lifted');
        case 1:
          return contacto
              ? tr('phase_full_foot_pressed')
              : tr('phase_waiting_full_foot');
        case 2:
          return contacto ? tr('phase_heel_pressed') : tr('phase_waiting_heel');
        case 3:
          return contacto
              ? tr('phase_forefoot_pressed')
              : tr('phase_waiting_forefoot');
        default:
          return tr('phase_calibration_complete');
      }
    }
    switch (_pasoCalibracion) {
      case 0:
        return contacto ? tr('phase_pressure_lift') : tr('phase_foot_lifted');
      case 1:
        return contacto ? tr('phase_full_foot_pressed') : tr('phase_waiting_full_foot');
      case 2:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_hop');
      case 3:
        return contacto ? tr('phase_heel_pressed') : tr('phase_waiting_heel');
      case 4:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_heel_hop');
      case 5:
        return contacto ? tr('phase_forefoot_pressed') : tr('phase_waiting_forefoot');
      case 6:
        return contacto ? tr('phase_hop_detected') : tr('phase_waiting_forefoot_hop');
      default:
        return tr('phase_calibration_complete');
    }
  }

  // Escanea/conecta la placa del pie actual (mismo criterio que el resto de la app). No desconecta al salir: la conexión queda viva globalmente.
  Future<void> _conectar() async {
    if (_escaneando || _conectando || _conectado) {
      return;
    }
    setState(() {
      _escaneando = true;
      _tipoEstadoBle = _TipoEstadoBle.buscando;
      _nombreBuscando = idBlePara(_pieActual).nombre;
    });
    final ok = await escanearYConectarPie(_pieActual,
        timeout: const Duration(seconds: 15));
    if (!mounted) {
      return;
    }
    if (ok) {
      _escucharDesconexion();
      setState(() {
        _escaneando = false;
        _conectando = false;
        _conectado = true;
        _tipoEstadoBle = _TipoEstadoBle.conectado;
      });
      _iniciarLive();
    } else {
      setState(() {
        _escaneando = false;
        _conectando = false;
        _tipoEstadoBle = _TipoEstadoBle.noEncontrado;
      });
    }
  }

  // Deja lista la pantalla para el siguiente pie: resetea el asistente y, si ya estaba conectada, arranca su feedback en vivo.
  void _cambiarAPie(Pie nuevo) {
    _liveSub?.cancel();
    _connSub?.cancel();
    _muestreoSub?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _pieActual = nuevo;
      _pasoCalibracion = 0;
      _muestras.clear();
      _adcReposo = null;
      _adcCargaPie = null;
      _adcCarga = null;
      _adcTalonPie = null;
      _adcTalon = null;
      _adcPuntaPie = null;
      _adcPunta = null;
      _errorCalibracion = null;
      _lecturaEnVivo = 0;
      _muestreando = false;
      final estado = bleEstado(nuevo);
      if (estado.device != null && estado.characteristic != null) {
        _conectado = true;
        _conectando = false;
        _escaneando = false;
        _tipoEstadoBle = _TipoEstadoBle.conectado;
      } else {
        _conectado = false;
        _conectando = false;
        _escaneando = false;
        _tipoEstadoBle = _TipoEstadoBle.noConectado;
      }
    });
    if (_conectado) {
      _escucharDesconexion();
      _iniciarLive();
    }
  }

  // Muestrea el ADC ~2s: paso 1 usa el promedio (reposo), el resto el mínimo (ADC más bajo = mayor presión); al final guarda y pasa al siguiente pie.
  void _capturarPaso(int paso) {
    final char = bleEstado(_pieActual).characteristic;
    if (char == null || _muestreando) {
      return;
    }
    setState(() {
      _muestreando = true;
      _errorCalibracion = null;
      _muestras.clear();
    });
    _muestreoSub = char.lastValueStream.listen((data) {
      final v = double.tryParse(utf8.decode(data).trim());
      if (v != null) {
        _muestras.add(v);
      }
    });
    Future.delayed(const Duration(seconds: 2), () async {
      await _muestreoSub?.cancel();
      if (!mounted) {
        return;
      }
      if (_muestras.isEmpty) {
        setState(() {
          _muestreando = false;
          _errorCalibracion = tr('err_no_data_insole');
        });
        return;
      }
      if (paso == 1) {
        _adcReposo = _muestras.reduce((a, b) => a + b) / _muestras.length;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 1;
        });
        return;
      }
      final minimo = _muestras.reduce((a, b) => a < b ? a : b);
      if (!_conSaltos) {
        // Secuencia corta sin salto: 1 reposo, 2 carga, 3 talón, 4 punta.
        if (paso == 2) {
          if ((_adcReposo! - minimo).abs() < 20) {
            setState(() {
              _muestreando = false;
              _errorCalibracion = tr('err_not_enough_difference');
            });
            return;
          }
          _adcCarga = minimo;
          setState(() {
            _muestreando = false;
            _pasoCalibracion = 2;
          });
          return;
        }
        if (paso == 3) {
          _adcTalon = minimo;
          setState(() {
            _muestreando = false;
            _pasoCalibracion = 3;
          });
          return;
        }
        // paso 4: solo punta, último punto de la calibración de este pie.
        _adcPunta = minimo;
        await guardarCalibracion(
            _pieActual, _adcReposo!, _adcCarga!, _adcTalon!, _adcPunta!);
        if (!mounted) {
          return;
        }
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 4;
        });
        _pasarASiguientePieOResumen();
        return;
      }
      if (paso == 2) {
        if ((_adcReposo! - minimo).abs() < 20) {
          setState(() {
            _muestreando = false;
            _errorCalibracion = tr('err_not_enough_difference');
          });
          return;
        }
        // Candidato de pie en calma; el salto del paso 3 da un pico más realista, se guarda el más alto de los dos.
        _adcCargaPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 2;
        });
        return;
      }
      if (paso == 3) {
        // Sin validar "salto insuficiente" (la calma ya validó); carga final = el pico más alto entre calma y salto.
        _adcCarga = minimo < _adcCargaPie! ? minimo : _adcCargaPie!;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 3;
        });
        return;
      }
      if (paso == 4) {
        // Candidato de talón en apoyo estático (inclinado hacia atrás, sin saltar aún).
        _adcTalonPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 4;
        });
        return;
      }
      if (paso == 5) {
        // Talón final = pico más alto entre apoyo estático y salto sobre el talón (mismo motivo que la carga).
        _adcTalon = minimo < _adcTalonPie! ? minimo : _adcTalonPie!;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 5;
        });
        return;
      }
      if (paso == 6) {
        // Candidato de punta en apoyo estático (inclinado hacia delante).
        _adcPuntaPie = minimo;
        setState(() {
          _muestreando = false;
          _pasoCalibracion = 6;
        });
        return;
      }
      // paso 7: salto sobre la punta, último punto de la calibración de
      // este pie.
      _adcPunta = minimo < _adcPuntaPie! ? minimo : _adcPuntaPie!;
      await guardarCalibracion(
          _pieActual, _adcReposo!, _adcCarga!, _adcTalon!, _adcPunta!);
      if (!mounted) {
        return;
      }
      setState(() {
        _muestreando = false;
        _pasoCalibracion = 7;
      });
      _pasarASiguientePieOResumen();
    });
  }

  // Al completar la calibración de un pie: si era el derecho, pasa a
  // calibrar el izquierdo; si ya eran los dos, entra en Live Analysis.
  void _pasarASiguientePieOResumen() {
    final piePrevio = _pieActual;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      if (piePrevio == Pie.derecha) {
        _cambiarAPie(Pie.izquierda);
      } else {
        Navigator.pushReplacement(
            context,
            gogaitRoute(
                builder: (_) =>
                    VistaActividad(tipoActividad: widget.tipoActividad)));
      }
    });
  }

  // Pone a null los valores desde el paso [pasoObjetivo] en adelante, sin
  // tocar lo anterior. La numeración depende de si hay saltos (_conSaltos).
  void _limpiarDesde(int pasoObjetivo) {
    final limpiadores = _conSaltos
        ? <int, VoidCallback>{
            1: () => _adcReposo = null,
            2: () => _adcCargaPie = null,
            3: () => _adcCarga = null,
            4: () => _adcTalonPie = null,
            5: () => _adcTalon = null,
            6: () => _adcPuntaPie = null,
            7: () => _adcPunta = null,
          }
        : <int, VoidCallback>{
            1: () => _adcReposo = null,
            2: () => _adcCarga = null,
            3: () => _adcTalon = null,
            4: () => _adcPunta = null,
          };
    for (final entry in limpiadores.entries) {
      if (entry.key >= pasoObjetivo) {
        entry.value();
      }
    }
  }

  // Repite un sub-paso sin reiniciar los anteriores (ver _limpiarDesde).
  void _rehacerPaso(int paso) {
    if (_muestreando) {
      return;
    }
    setState(() {
      _limpiarDesde(paso);
      _pasoCalibracion = paso - 1;
      _errorCalibracion = null;
    });
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
              const SizedBox(width: 12),
              Expanded(
                  child: Text(tr('prepare_insole'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600))),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('prepare_insole_desc'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 14),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: kOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: kOrange.withValues(alpha: 0.3))),
                          child: Row(children: [
                            const Icon(Icons.rule, color: kOrange, size: 16),
                            const SizedBox(width: 8),
                            Text(
                                tr('calibrating_foot')
                                    .replaceAll('{side}', etiquetaPie(_pieActual)),
                                style: const TextStyle(
                                    color: kOrange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ])),
                      const SizedBox(height: 14),
                      _pasoUI(
                          numero: 1,
                          titulo: tr('put_on_insole'),
                          hecho: true,
                          contenido: Text(
                              tr('fit_snugly'),
                              style: const TextStyle(color: kGray, fontSize: 13))),
                      const SizedBox(height: 14),
                      _pasoUI(
                          numero: 2,
                          titulo: tr('connect_via_bluetooth'),
                          hecho: _conectado,
                          contenido: _conectado
                              ? Text(_insoleConectadoMsg(_pieActual),
                                  style:
                                      const TextStyle(color: kTeal, fontSize: 13))
                              : Row(children: [
                                  Expanded(
                                      child: Text(_estadoBleTexto,
                                          style: TextStyle(
                                              color: _escaneando
                                                  ? kOrange
                                                  : kGray,
                                              fontSize: 13))),
                                  if (_escaneando || _conectando)
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: kOrange))
                                  else
                                    GestureDetector(
                                        onTap: _conectar,
                                        child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6),
                                            decoration: BoxDecoration(
                                                gradient: kGradient,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(tr('connect_button'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)))),
                                ])),
                      const SizedBox(height: 14),
                      Opacity(
                          opacity: _conectado ? 1 : 0.4,
                          child: IgnorePointer(
                              ignoring: !_conectado,
                              child: _pasoUI(
                                  numero: 3,
                                  titulo: tr('calibrate_to_weight'),
                                  hecho: _pasoCalibracion == (_conSaltos ? 7 : 4),
                                  contenido: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_conectado) ...[
                                          Builder(builder: (context) {
                                            final presionCalibrada =
                                                _presionEnVivoCalibrada;
                                            final calibrando =
                                                presionCalibrada != null;
                                            return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  if (calibrando)
                                                    Center(
                                                        child:
                                                            FootHeatmapWidget(
                                                                data:
                                                                    _heatmapEnVivo,
                                                                label:
                                                                    etiquetaPie(_pieActual),
                                                                isLeft: _pieActual ==
                                                                    Pie.izquierda))
                                                  else
                                                    // Sin reposo+carga de esta sesión no hay referencia fiable todavía.
                                                    Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(20),
                                                        alignment:
                                                            Alignment.center,
                                                        decoration: BoxDecoration(
                                                            color: kCard,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            border: Border.all(
                                                                color:
                                                                    kGrayDark)),
                                                        child: Text(
                                                            tr('heatmap_pending'),
                                                            textAlign:
                                                                TextAlign
                                                                    .center,
                                                            style: const TextStyle(
                                                                color: kGray,
                                                                fontSize:
                                                                    12))),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        if (_faseConfirmada)
                                                          const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color: kTeal,
                                                              size: 14),
                                                        if (_faseConfirmada)
                                                          const SizedBox(
                                                              width: 6),
                                                        Flexible(
                                                          child: Text(
                                                              _etiquetaFaseCalib,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              maxLines: 1,
                                                              style: TextStyle(
                                                                  color: _faseConfirmada
                                                                      ? kTeal
                                                                      : kGray,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                        ),
                                                        // % respecto a la carga completa de esta sesión.
                                                        if (calibrando) ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                              '${presionCalibrada.round()}%',
                                                              style: const TextStyle(
                                                                  color:
                                                                      kOrange,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                        ],
                                                      ]),
                                                  const SizedBox(height: 4),
                                                  // ADC crudo sin calibrar, para detectar visualmente un sensor enganchado.
                                                  Text(
                                                      tr('raw_adc').replaceAll(
                                                          '{n}', '${_adcCrudoEnVivo.round()}'),
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 11)),
                                                  const SizedBox(height: 14),
                                                ]);
                                          }),
                                        ],
                                        // Reinicia los 4/7 pasos desde cero (alternativa a repetir un sub-paso con "Redo").
                                        if (_pasoCalibracion > 0 &&
                                            _pasoCalibracion <
                                                (_conSaltos ? 7 : 4))
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: GestureDetector(
                                                  onTap: _muestreando
                                                      ? null
                                                      : () =>
                                                          _rehacerPaso(1),
                                                  child: Text(
                                                      tr('restart_calibration_foot'),
                                                      style: const TextStyle(
                                                          color: kGray,
                                                          fontSize: 12,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline)))),
                                        _subpasoCalibracion(
                                            texto: tr('substep_no_pressure'),
                                            hecho: _pasoCalibracion >= 1,
                                            activo: _pasoCalibracion == 0,
                                            onTap: () => _capturarPaso(1),
                                            onRedo: () => _rehacerPaso(1)),
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_full_pressure'),
                                            hecho: _pasoCalibracion >= 2,
                                            activo: _pasoCalibracion == 1,
                                            onTap: () => _capturarPaso(2),
                                            onRedo: () => _rehacerPaso(2)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_hop'),
                                              hecho: _pasoCalibracion >= 3,
                                              activo: _pasoCalibracion == 2,
                                              onTap: () => _capturarPaso(3),
                                              onRedo: () => _rehacerPaso(3)),
                                        ],
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_heel_only'),
                                            hecho: _pasoCalibracion >=
                                                (_conSaltos ? 4 : 3),
                                            activo: _pasoCalibracion ==
                                                (_conSaltos ? 3 : 2),
                                            onTap: () => _capturarPaso(
                                                _conSaltos ? 4 : 3),
                                            onRedo: () => _rehacerPaso(
                                                _conSaltos ? 4 : 3)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_heel_hop'),
                                              hecho: _pasoCalibracion >= 5,
                                              activo: _pasoCalibracion == 4,
                                              onTap: () => _capturarPaso(5),
                                              onRedo: () => _rehacerPaso(5)),
                                        ],
                                        const SizedBox(height: 10),
                                        _subpasoCalibracion(
                                            texto: tr('substep_forefoot_only'),
                                            hecho: _pasoCalibracion >=
                                                (_conSaltos ? 6 : 4),
                                            activo: _pasoCalibracion ==
                                                (_conSaltos ? 5 : 3),
                                            onTap: () => _capturarPaso(
                                                _conSaltos ? 6 : 4),
                                            onRedo: () => _rehacerPaso(
                                                _conSaltos ? 6 : 4)),
                                        if (_conSaltos) ...[
                                          const SizedBox(height: 10),
                                          _subpasoCalibracion(
                                              texto: tr('substep_forefoot_hop'),
                                              hecho: _pasoCalibracion >= 7,
                                              activo: _pasoCalibracion == 6,
                                              onTap: () => _capturarPaso(7),
                                              onRedo: () => _rehacerPaso(7)),
                                        ],
                                        if (_errorCalibracion != null) ...[
                                          const SizedBox(height: 10),
                                          Text(_errorCalibracion!,
                                              style: const TextStyle(
                                                  color: kRed, fontSize: 12)),
                                        ],
                                        if (_pasoCalibracion ==
                                            (_conSaltos ? 7 : 4)) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                              _pieActual == Pie.derecha
                                                  ? tr('right_foot_calibrated')
                                                  : tr('calibrated_entering_live'),
                                              style: const TextStyle(
                                                  color: kTeal, fontSize: 13)),
                                        ],
                                      ])))),
                    ]))),
      ])),
    );
  }

  // Tarjeta de paso numerado, con marca de "hecho" cuando corresponde.
  Widget _pasoUI(
      {required int numero,
      required String titulo,
      required bool hecho,
      required Widget contenido}) {
    return GogaitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: hecho ? kTeal : kGrayDark, shape: BoxShape.circle),
            child: hecho
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$numero',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(titulo,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      contenido,
    ]));
  }

  // Fila de un sub-paso: botón "Capturar" deshabilitado hasta que le toca o mientras muestrea.
  Widget _subpasoCalibracion(
      {required String texto,
      required bool hecho,
      required bool activo,
      required VoidCallback onTap,
      VoidCallback? onRedo}) {
    return Row(children: [
      Icon(hecho ? Icons.check_circle : Icons.circle_outlined,
          color: hecho ? kTeal : kGray, size: 18),
      const SizedBox(width: 8),
      Expanded(
          child: Text(texto,
              style: TextStyle(
                  color: hecho ? Colors.white : kGray, fontSize: 13))),
      if (!hecho)
        GestureDetector(
            onTap: activo && !_muestreando ? onTap : null,
            child: Opacity(
                opacity: activo ? 1 : 0.4,
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange)),
                    child: _muestreando && activo
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kOrange))
                        : Text(tr('capture_button'),
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))))),
      // Paso hecho se puede repetir sin perder los demás (ver _rehacerPaso).
      if (hecho && onRedo != null)
        GestureDetector(
            onTap: _muestreando ? null : onRedo,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGrayDark)),
                child: Text(tr('redo_button'),
                    style: const TextStyle(
                        color: kGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)))),
    ]);
  }
}

// Detector de fase de marcha por pie, curva en "M": Heel Strike (1er pico) -> Midstance (valle) -> Propulsion (2º pico) -> Swing.
class _EstadoMarcha {
  String fase = 'Swing';
  double ultimaPresion = 0;
  int direccion = 0; // -1 bajando, 0 inicial, 1 subiendo
  int muestrasEnDireccion = 0;
  int pasos = 0;
  final List<DateTime> tiemposPaso = [];
}
