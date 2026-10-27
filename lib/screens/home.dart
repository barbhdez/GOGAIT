part of '../main.dart';

// ---- HOME SCREEN ----
class VistaHome extends StatefulWidget {
  const VistaHome({super.key});

  @override
  State<VistaHome> createState() => _VistaHomeState();
}

class _VistaHomeState extends State<VistaHome> with IdiomaListenerMixin {
  int get _bleConectados =>
      (bleDer.device != null ? 1 : 0) + (bleIzq.device != null ? 1 : 0);
  bool get _bleConectado => _bleConectados > 0;
  bool get _bleAmbosConectados => _bleConectados == 2;
  Timer? _bleCheckTimer;

  // N/A si ninguna sesión del periodo tiene el dato (ver periodoMetricasSeleccionado)
  List<Map<String, dynamic>> get metrics {
    final balance = balanceMedioPeriodo(periodoMetricasSeleccionado);
    final impacto = impactoMedioPeriodo(periodoMetricasSeleccionado);
    return [
      {
        // preview de Quick Metrics: colorea por umbral, el resto de la app usa color fijo
        'label': tr('metric_balance'),
        'value': balance == null ? 'N/A' : '${balance.round()}%',
        'color': balance == null ? kGray : colorDesequilibrio(balance),
        'icon': Icons.my_location,
        'info': tr('balance_info'),
      },
      {
        // siempre en %, igual que Quick Metrics; el kg es solo para una sesión suelta
        'label': tr('metric_impact'),
        'value': impacto == null ? 'N/A' : '${impacto.round()}%',
        'color': impacto == null ? kGray : colorImpacto(impacto),
        'icon': Icons.speed,
        'info': tr('impact_info'),
      },
      {
        'label': tr('metric_cadence'),
        'value': '${cadenciaMediaPeriodo(periodoMetricasSeleccionado).round()} spm',
        // mismo morado que Cadence en Activity Details
        'color': kPurple,
        'icon': Icons.trending_up,
        'info': tr('cadence_info'),
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    // bleDer/bleIzq pueden cambiar en segundo plano (p.ej. se apaga el Bluetooth), refresco periódico
    _bleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (_perfilIncompleto(usuarioActual)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _avisarPerfilIncompleto();
        }
      });
    }
  }

  void _avisarPerfilIncompleto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('complete_profile_title'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('complete_profile_message'),
            style: const TextStyle(color: kGray, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    gogaitRoute(builder: (_) => const VistaAjustes()));
              },
              child: Text(tr('complete_profile_button'),
                  style: const TextStyle(color: kOrange))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bleCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expanded + ellipsis: nombre largo no debe empujar el selector/avatar fuera de pantalla.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('home_hello').replaceAll('{name}',
                              usuarioActual?.nombre ?? tr('user_fallback')),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('home_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(children: [
                    _SelectorIdioma(),
                    const SizedBox(width: 10),
                    GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaAjustes()));
                      setState(() {});
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: kGradientFull, shape: BoxShape.circle),
                          child: usuarioActual?.fotoPath != null
                              ? ClipOval(
                                  child: Image.file(
                                      File(usuarioActual!.fotoPath!),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person,
                                  color: Colors.white, size: 24),
                        ),
                        // Insignia de ajustes: distingue este acceso de otros avatares que no llevan a ningún sitio.
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: kCard,
                                shape: BoxShape.circle,
                                border: Border.all(color: kBg, width: 2)),
                            child: const Icon(Icons.settings,
                                color: kOrange, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ]),
                ],
              ),
              const SizedBox(height: 20),

              GogaitCard(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaBluetooth()));
                  setState(() {});
                },
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _bleConectado
                                      ? kTeal.withValues(alpha: 0.15)
                                      : kGray.withValues(alpha: 0.15)),
                              child: Icon(Icons.bluetooth,
                                  color: _bleConectado ? kTeal : kGray,
                                  size: 18)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _bleAmbosConectados
                                          ? tr('insoles_connected')
                                          : _bleConectado
                                              ? tr('insoles_partial')
                                              : tr('insoles_disconnected'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      _bleConectado
                                          ? tr('insoles_count').replaceAll(
                                              '{n}', '$_bleConectados')
                                          : tr('tap_to_connect'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          color:
                                              _bleConectado ? kTeal : kGray,
                                          fontSize: 11)),
                                ]),
                          ),
                        ]),
                      ),
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _bleConectado ? kTeal : kGray)),
                        const SizedBox(width: 6),
                        Text(_bleConectado ? tr('status_active') : tr('status_offline'),
                            style: TextStyle(
                                color: _bleConectado ? kTeal : kGray,
                                fontSize: 12)),
                      ]),
                    ]),
              ),
              const SizedBox(height: 16),

              GogaitCard(
                onTap: historial.isNotEmpty
                    ? () async {
                        await Navigator.push(
                            context,
                            gogaitRoute(
                                builder: (_) => VistaDetalleHistorico(
                                    sesion: historial.last)));
                        setState(() {});
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(tr('last_activity'),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            // Sin hora: con hora incluida el texto no cabía junto al título y siempre se recortaba.
                            historial.isNotEmpty
                                ? _formatFechaSesion(historial.last,
                                    incluirHora: false)
                                : '—',
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: kGray, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: kOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: kOrange.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.directions_run,
                              color: kOrange, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                historial.isNotEmpty
                                    ? historial.last.titulo
                                    : '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                historial.isNotEmpty
                                    ? historial.last.duracion
                                    : '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: kGray, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(tr('quick_metrics'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          gogaitRoute(
                              builder: (_) => const VistaExportMetrics()));
                      setState(() {});
                    },
                    child: Text(tr('export_your_data'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(color: kTeal, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final metricsList = metrics;
                return Row(
                  children: metricsList
                      .map((m) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: m != metricsList.last ? 10.0 : 0),
                            child: GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                    context,
                                    gogaitRoute(
                                        builder: (_) =>
                                            const VistaExportMetrics()));
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: kGrayDark.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(m['icon'] as IconData,
                                        color: kGray, size: 18),
                                    const SizedBox(height: 8),
                                    Text(
                                      m['value'] as String,
                                      style: TextStyle(
                                          color: m['color'] as Color,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Flexible(
                                        child: Text(m['label'] as String,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                      ),
                                      InfoTip(
                                          titulo: m['label'] as String,
                                          texto: m['info'] as String),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ))
                      .toList(),
                );
              }),
              const SizedBox(height: 32),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaSeleccionActividad()));
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                      gradient: kGradientFull,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.show_chart, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        tr('start_analysis'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GogaitCard(
                onTap: () async {
                  await Navigator.push(
                      context,
                      gogaitRoute(
                          builder: (_) => const VistaHistorico()));
                  setState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('view_history'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
