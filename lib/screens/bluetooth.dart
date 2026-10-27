part of '../main.dart';

// ---- BLUETOOTH CONNECTION SCREEN ----
// Flujo con las plantillas GOGAIT_XIAO_DERECHA/IZQUIERDA: comprobar Bluetooth, escanear, conectar. Si ya había una placa conectada, salta directo a éxito.
class VistaBluetooth extends StatefulWidget {
  const VistaBluetooth({super.key});
  @override
  State<VistaBluetooth> createState() => _VistaBluetoothState();
}

enum _EstadoConexion { pendiente, buscando, conectado, fallo }

String _textoEstadoConex(_EstadoConexion e) {
  switch (e) {
    case _EstadoConexion.conectado:
      return tr('status_connected');
    case _EstadoConexion.buscando:
      return tr('status_searching');
    case _EstadoConexion.fallo:
      return tr('status_not_found');
    case _EstadoConexion.pendiente:
      return tr('status_not_connected');
  }
}

class _VistaBluetoothState extends State<VistaBluetooth>
    with TickerProviderStateMixin, IdiomaListenerMixin {
  int _step =
      0; // 0:check, 1:authorize, 2:connect, 3:connecting, 4:connected, 5:failed
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSubDer;
  StreamSubscription<BluetoothConnectionState>? _connSubIzq;
  Timer? _timeoutTimer;

  // Estado de cada plantilla por separado: se buscan en el mismo escaneo pero conectan independientemente.
  _EstadoConexion _estadoDer = _EstadoConexion.pendiente;
  _EstadoConexion _estadoIzq = _EstadoConexion.pendiente;
  final Set<Pie> _conectandoAhora = {};

  _EstadoConexion _estadoDe(Pie pie) =>
      pie == Pie.derecha ? _estadoDer : _estadoIzq;
  void _setEstado(Pie pie, _EstadoConexion e) {
    if (pie == Pie.derecha) {
      _estadoDer = e;
    } else {
      _estadoIzq = e;
    }
  }

  bool get _algunaConectada =>
      _estadoDer == _EstadoConexion.conectado ||
      _estadoIzq == _EstadoConexion.conectado;
  bool get _ambasConectadas =>
      _estadoDer == _EstadoConexion.conectado &&
      _estadoIzq == _EstadoConexion.conectado;

  // Si ya había placas conectadas salta directo a "Conectado"; si no, vigila el Bluetooth del móvil.
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    for (final pie in Pie.values) {
      final device = bleEstado(pie).device;
      if (device != null) {
        _setEstado(pie, _EstadoConexion.conectado);
        _escucharDesconexion(device, pie);
      }
    }
    if (_algunaConectada) {
      _step = 4;
      return;
    }
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) {
        return;
      }
      if (state == BluetoothAdapterState.on) {
        setState(() => _step = 2);
      } else {
        setState(() => _step = 1);
      }
    });
  }

  void _escucharDesconexion(BluetoothDevice device, Pie pie) {
    final sub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && mounted) {
        setState(() {
          _setEstado(pie, _EstadoConexion.pendiente);
          if (_step == 4 && !_algunaConectada) {
            _step = 2;
          }
        });
      }
    });
    if (pie == Pie.derecha) {
      _connSubDer = sub;
    } else {
      _connSubIzq = sub;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _connSubDer?.cancel();
    _connSubIzq?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // Pide activar el Bluetooth del sistema (solo hace falta en Android).
  Future<void> _authorize() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {}
  }

  void _terminarEscaneo() {
    _timeoutTimer?.cancel();
    _scanSub?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.stopScan();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      for (final pie in Pie.values) {
        if (_estadoDe(pie) == _EstadoConexion.buscando) {
          _setEstado(pie, _EstadoConexion.fallo);
        }
      }
      _step = _algunaConectada ? 4 : 5;
    });
  }

  // Escanea las dos placas a la vez y conecta cada una en cuanto aparece; a los 12s sin encontrarla, marca fallida.
  Future<void> _connect() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _step = 3;
      for (final pie in Pie.values) {
        if (_estadoDe(pie) != _EstadoConexion.conectado) {
          _setEstado(pie, _EstadoConexion.buscando);
        }
      }
    });
    _timeoutTimer = Timer(const Duration(seconds: 12), _terminarEscaneo);
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        for (final pie in Pie.values) {
          if (_estadoDe(pie) != _EstadoConexion.buscando ||
              _conectandoAhora.contains(pie)) {
            continue;
          }
          final id = idBlePara(pie);
          final matchNombre = r.device.platformName == id.nombre;
          final matchUUID = r.advertisementData.serviceUuids.any((u) => u
              .toString()
              .toLowerCase()
              .contains(id.servicioUuid.toLowerCase()));
          if (matchNombre || matchUUID) {
            _conectandoAhora.add(pie);
            _conectarUno(r.device, pie);
          }
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
  }

  // Conecta con una placa ya localizada, sin bloquear a la otra plantilla.
  Future<void> _conectarUno(BluetoothDevice device, Pie pie) async {
    final ok = await _conectarYSuscribirPie(device, pie);
    _conectandoAhora.remove(pie);
    if (!mounted) {
      return;
    }
    setState(() {
      _setEstado(pie, ok ? _EstadoConexion.conectado : _EstadoConexion.fallo);
      if (ok) {
        _escucharDesconexion(device, pie);
      }
      final sigueBuscando = _estadoDer == _EstadoConexion.buscando ||
          _estadoIzq == _EstadoConexion.buscando;
      if (!sigueBuscando) {
        _timeoutTimer?.cancel();
        _scanSub?.cancel();
        if (FlutterBluePlus.isScanningNow) {
          FlutterBluePlus.stopScan();
        }
        _step = _algunaConectada ? 4 : 5;
      }
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
              Expanded(
                  child: Text(tr('device_connection'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: _step == 0
                    ? const Center(
                        child: CircularProgressIndicator(color: kOrange))
                    : _step == 1
                        ? _buildAuthorize()
                        : _step == 2
                            ? _buildConnect()
                            : _step == 3
                                ? _buildConnecting()
                                : _step == 4
                                    ? _buildSuccess()
                                    : _buildFailed())),
      ])),
    );
  }

  // Paso 1: pedir al usuario que active el Bluetooth.
  Widget _buildAuthorize() => Column(children: [
        const Spacer(),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D1F3C),
                border: Border.all(color: kTeal.withValues(alpha: 0.3))),
            child: const Icon(Icons.bluetooth, color: kTeal, size: 48)),
        const SizedBox(height: 24),
        Text(tr('enable_bluetooth'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(tr('bluetooth_required'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 32),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('about_insoles_title'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 12),
              _WhyItem(tr('why_xiao_sensors')),
              _WhyItem(tr('why_measures_plantar')),
              _WhyItem(tr('why_sends_10ms')),
              _WhyItem(tr('why_powers_analysis')),
            ])),
        const Spacer(),
        GogaitButton(text: tr('enable_bluetooth'), onTap: _authorize),
      ]);

  // Fila de estado de un pie, reutilizada en los pasos 2 a 5.
  Widget _filaEstado(Pie pie) {
    final estado = _estadoDe(pie);
    late Color color;
    late IconData icon;
    late String texto;
    switch (estado) {
      case _EstadoConexion.conectado:
        color = kTeal;
        icon = Icons.bluetooth_connected;
        texto = tr('status_connected');
        break;
      case _EstadoConexion.buscando:
        color = kOrange;
        icon = Icons.bluetooth_searching;
        texto = tr('status_searching');
        break;
      case _EstadoConexion.fallo:
        color = kRed;
        icon = Icons.bluetooth_disabled;
        texto = tr('status_not_found');
        break;
      case _EstadoConexion.pendiente:
        color = kGray;
        icon = Icons.bluetooth;
        texto = tr('status_not_connected');
        break;
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(pie == Pie.derecha ? tr('insole_right') : tr('insole_left'),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texto,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ]));
  }

  // Paso 2: Bluetooth ya activo, listo para pulsar "Connect Devices".
  Widget _buildConnect() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      kOrange.withValues(alpha: 0.15 * _pulseAnim.value),
                      kRed.withValues(alpha: 0.15 * _pulseAnim.value)
                    ]),
                    border: Border.all(
                        color: kOrange.withValues(alpha: _pulseAnim.value),
                        width: 2)),
                child: Icon(Icons.bluetooth,
                    color: kOrange.withValues(alpha: _pulseAnim.value),
                    size: 48))),
        const SizedBox(height: 24),
        Text(tr('connect_smart_insoles'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(tr('right_left_insoles'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 16),
        GogaitCard(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('about_insoles_title'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 8),
              _WhyItem(tr('why_measures_heel_metatarsal')),
              _WhyItem(tr('why_sends_ble')),
              _WhyItem(tr('why_powers_heatmap')),
            ])),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _connect,
          child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                  gradient: kGradient, borderRadius: BorderRadius.circular(16)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('connect_devices'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                  ])),
        ),
        const SizedBox(height: 20),
      ]));

  // Paso 3: escaneando/conectando; estado de cada pie por separado.
  Widget _buildConnecting() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      kOrange.withValues(alpha: 0.15 * _pulseAnim.value),
                      kRed.withValues(alpha: 0.15 * _pulseAnim.value)
                    ]),
                    border: Border.all(
                        color: kOrange.withValues(alpha: _pulseAnim.value),
                        width: 2)),
                child: Icon(Icons.bluetooth_searching,
                    color: kOrange.withValues(alpha: _pulseAnim.value),
                    size: 48))),
        const SizedBox(height: 24),
        Text(tr('searching_for_insoles'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(tr('waiting_up_to_12s'),
            style: const TextStyle(color: kGray, fontSize: 12)),
        const SizedBox(height: 20),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
      ]));

  // Paso 4: al menos una plantilla conectada.
  Widget _buildSuccess() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  const Color(0xFF00E6A8).withValues(alpha: _ambasConectadas ? 1 : 0.5),
                  kTeal.withValues(alpha: _ambasConectadas ? 1 : 0.5)
                ])),
            child: const Icon(Icons.bluetooth_connected,
                color: Colors.white, size: 48)),
        const SizedBox(height: 24),
        Text(_ambasConectadas ? tr('both_insoles_connected') : tr('partially_connected'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            _ambasConectadas
                ? tr('both_ready')
                : tr('missing_insole').replaceAll('{side}',
                    _estadoDer == _EstadoConexion.conectado
                        ? tr('side_left')
                        : tr('side_right')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
        if (!_ambasConectadas) ...[
          GestureDetector(
              onTap: _connect,
              child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGrayDark)),
                  child: Center(
                      child: Text(tr('search_again'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15))))),
          const SizedBox(height: 12),
        ],
        GogaitButton(
            text: tr('continue_label'), onTap: () => Navigator.pop(context)),
        const SizedBox(height: 20),
      ]));

  // Paso 5: no se encontró/no se pudo conectar con ninguna placa.
  Widget _buildFailed() => SingleChildScrollView(
          child: Column(children: [
        const SizedBox(height: 20),
        Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kRed.withValues(alpha: 0.1),
                border: Border.all(color: kRed.withValues(alpha: 0.4))),
            child: const Icon(Icons.bluetooth_disabled, color: kRed, size: 48)),
        const SizedBox(height: 24),
        Text(tr('connection_failed'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
            tr('could_not_find_insoles'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kGray, fontSize: 14)),
        const SizedBox(height: 24),
        GogaitCard(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _filaEstado(Pie.derecha),
              const Divider(color: Color(0xFF374151), height: 20),
              _filaEstado(Pie.izquierda),
            ])),
        const SizedBox(height: 20),
        GestureDetector(
            onTap: _connect,
            child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                    gradient: kGradient,
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child: Text(tr('retry'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15))))),
        if (_algunaConectada) ...[
          const SizedBox(height: 12),
          GogaitButton(
              text: tr('continue_with_1_insole'),
              onTap: () => Navigator.pop(context)),
        ],
        const SizedBox(height: 12),
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr('back'),
                    style: const TextStyle(color: kGray, fontSize: 14)))),
        const SizedBox(height: 20),
      ]));
}

// Línea con viñeta para las listas "About GOGAIT Smart Insoles".
class _WhyItem extends StatelessWidget {
  final String text;
  const _WhyItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(color: kOrange, fontSize: 14)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: kGray, fontSize: 13))),
        ]),
      );
}
