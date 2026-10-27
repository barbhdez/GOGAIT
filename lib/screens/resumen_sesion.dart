part of '../main.dart';

// ---- SESSION SUMMARY SCREEN ----
// Pantalla tras terminar la actividad: elegir tipo, título/notas y guardar la sesión en el historial.
class VistaResumen extends StatefulWidget {
  final int segundos;
  final VoidCallback onFinalizar;
  final double presionMetaIzq, presionTalonIzq, presionMetaDer, presionTalonDer;
  final int pasos;
  final double distanciaKm;
  final String tipoInicial;
  final List<Map<String, dynamic>> datosSesion;
  final List<Map<String, dynamic>> recorrido;
  const VistaResumen(
      {super.key,
      required this.segundos,
      required this.onFinalizar,
      required this.presionMetaIzq,
      required this.presionTalonIzq,
      required this.presionMetaDer,
      required this.presionTalonDer,
      required this.pasos,
      required this.distanciaKm,
      this.tipoInicial = 'running',
      required this.datosSesion,
      this.recorrido = const []});
  @override
  State<VistaResumen> createState() => _VistaResumenState();
}

class _VistaResumenState extends State<VistaResumen> with IdiomaListenerMixin {
  late String _tipo;
  final _titulo = TextEditingController();
  final _notas = TextEditingController();
  String _footFilter = 'both';
  // Último título autogenerado (hora+tipo); si el usuario lo cambia a mano, se deja de tocar aunque cambie el tipo (ver _tituloPorDefecto).
  String? _ultimoTituloAuto;

  @override
  void initState() {
    super.initState();
    // Tipo ya elegido antes de calibrar (VistaSeleccionActividad); aquí solo se prellena, se puede cambiar desde el selector.
    _tipo = widget.tipoInicial;
    _ultimoTituloAuto = _tituloPorDefecto(_tipo);
    _titulo.text = _ultimoTituloAuto!;
  }

  // "Morning Run", "Afternoon Walk"... según la hora actual y el tipo de actividad.
  String _tituloPorDefecto(String tipo) {
    final hora = DateTime.now().hour;
    final momento = hora < 5
        ? tr('time_night')
        : hora < 12
            ? tr('time_morning')
            : hora < 17
                ? tr('time_afternoon')
                : hora < 21
                    ? tr('time_evening')
                    : tr('time_night');
    final actividad = tipo == 'walking'
        ? tr('activity_walk')
        : tipo == 'trail'
            ? tr('trail_run')
            : tr('activity_run');
    return '$momento $actividad';
  }

  // Media de una columna sobre todas las muestras, no la última lectura (que podía caer sin apoyo).
  double _mediaMuestras(String clave, double valorSiVacio) {
    if (widget.datosSesion.isEmpty) {
      return valorSiVacio;
    }
    final valores =
        widget.datosSesion.map((d) => (d[clave] as num).toDouble());
    return valores.reduce((a, b) => a + b) / widget.datosSesion.length;
  }

  void _guardar() {
    widget.onFinalizar();
    final now = DateTime.now();
    final presionMetaMedia =
        _mediaMuestras('metaDer', widget.presionMetaDer);
    final presionTalonMedia =
        _mediaMuestras('talonDer', widget.presionTalonDer);
    final presionMetaIzqMedia =
        _mediaMuestras('metaIzq', widget.presionMetaIzq);
    final presionTalonIzqMedia =
        _mediaMuestras('talonIzq', widget.presionTalonIzq);
    final impacto = calcularImpacto(widget.datosSesion, Pie.derecha);
    final impactoIzq = calcularImpacto(widget.datosSesion, Pie.izquierda);
    historial.add(SesionActividad(
      id: now.toString(),
      titulo: _titulo.text,
      descripcion: _notas.text,
      tipo: _tipo,
      fecha: '${now.day}/${now.month}/${now.year}',
      hora: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      duracion: '${widget.segundos ~/ 60}min ${widget.segundos % 60}s',
      // Media de toda la sesión, no la última lectura instantánea.
      presionMeta: presionMetaMedia,
      presionTalon: presionTalonMedia,
      presionMetaIzq: presionMetaIzqMedia,
      presionTalonIzq: presionTalonIzqMedia,
      pasos: widget.pasos,
      // Cadencia media de toda la sesión (no la instantánea en vivo).
      cadencia: widget.segundos > 0 ? widget.pasos / (widget.segundos / 60) : 0,
      distanciaKm: widget.distanciaKm,
      balance: calcularBalance(widget.datosSesion),
      impacto: impacto,
      impactoIzq: impactoIzq,
      // Media de ambos pies, no solo derecho (ver impactoMedioPeriodo): impactoKg es cifra general de Impact.
      impactoKg: impactoAKg((impacto + impactoIzq) / 2, usuarioActual?.peso ?? 0),
      zancadaRatio: ratioZancada(widget.distanciaKm, widget.pasos,
              usuarioActual?.altura ?? 0, _tipo) ??
          0,
      strikeIndexDer: calcularStrikeIndex(widget.datosSesion, Pie.derecha),
      strikeIndexIzq: calcularStrikeIndex(widget.datosSesion, Pie.izquierda),
      tieneBalance: tieneDatosPieIzquierdo(widget.datosSesion),
      tieneFatiga: tieneDatosFatiga(widget.datosSesion),
      tieneStrikeDer: tieneDatosStrikeIndex(widget.datosSesion, Pie.derecha),
      tieneStrikeIzq: tieneDatosStrikeIndex(widget.datosSesion, Pie.izquierda),
      tieneImpacto: widget.datosSesion.isNotEmpty,
      fatiga: calcularFatiga(widget.datosSesion),
      tramosFatiga: tramosFatiga(widget.datosSesion),
      datosSesion: List.from(widget.datosSesion),
      recorrido: List.from(widget.recorrido),
      // Foto de la calibración activa al guardar, fija a esta sesión aunque se recalibre después (ver SesionActividad).
      adcReposoDer: calibDer.adcReposo,
      adcCargaDer: calibDer.adcCarga,
      adcTalonDer: calibDer.adcTalon,
      adcPuntaDer: calibDer.adcPunta,
      adcReposoIzq: calibIzq.adcReposo,
      adcCargaIzq: calibIzq.adcCarga,
      adcTalonIzq: calibIzq.adcTalon,
      adcPuntaIzq: calibIzq.adcPunta,
    ));
    guardarHistorial();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final durStr =
        '${(widget.segundos ~/ 60).toString().padLeft(2, '0')}:${(widget.segundos % 60).toString().padLeft(2, '0')}';
    final steps = widget.pasos;
    final km = widget.distanciaKm.toStringAsFixed(2);

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
                      child:
                          const Icon(Icons.chevron_left, color: Colors.white))),
              Expanded(
                  child: Text(tr('session_summary'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 36),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('activity_type'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                          children: [
                        {'type': 'walking', 'icon': Icons.directions_walk},
                        {
                          'type': 'running',
                          'icon': Icons.directions_run_outlined
                        },
                        {'type': 'trail', 'icon': Icons.landscape_outlined},
                      ]
                              .map((a) => Expanded(
                                      child: GestureDetector(
                                    onTap: () => setState(() {
                                      _tipo = a['type'] as String;
                                      // Solo actualiza el título si sigue siendo el autogenerado.
                                      if (_titulo.text == _ultimoTituloAuto) {
                                        _ultimoTituloAuto =
                                            _tituloPorDefecto(_tipo);
                                        _titulo.text = _ultimoTituloAuto!;
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: _tipo == a['type']
                                            ? kGradient
                                            : null,
                                        color:
                                            _tipo == a['type'] ? null : kCard,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: _tipo == a['type']
                                                ? Colors.transparent
                                                : kGrayDark),
                                      ),
                                      child: Icon(a['icon'] as IconData,
                                          color: _tipo == a['type']
                                              ? Colors.white
                                              : kOrange,
                                          size: 28),
                                    ),
                                  )))
                              .toList()),
                      const SizedBox(height: 16),

                      Text(tr('activity_title'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      GogaitInput(
                          label: '', hint: tr('activity_title_hint'), controller: _titulo),
                      const SizedBox(height: 16),

                      Text(tr('notes_optional'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      GogaitInput(
                          label: '',
                          hint: tr('notes_hint'),
                          controller: _notas,
                          maxLines: 3),
                      const SizedBox(height: 16),

                      GogaitCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('session_performance'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(height: 16),
                                Row(
                                    children: [
                                  {'v': 'both', 'l': tr('both_feet')},
                                  {'v': 'left', 'l': tr('left_foot')},
                                  {'v': 'right', 'l': tr('right_foot')},
                                ]
                                        .map((f) => Expanded(
                                                child: GestureDetector(
                                              onTap: () => setState(() =>
                                                  _footFilter =
                                                      f['v'] as String),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    right: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _footFilter == f['v']
                                                      ? kOrange.withValues(
                                                          alpha: 0.15)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color:
                                                          _footFilter == f['v']
                                                              ? kOrange
                                                              : kGrayDark),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(f['l'] as String,
                                                    style: TextStyle(
                                                        color: _footFilter ==
                                                                f['v']
                                                            ? kOrange
                                                            : kGray,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ),
                                            )))
                                        .toList()),
                                const SizedBox(height: 24),
                                Builder(builder: (context) {
                                  // Balance requiere señal real del pie izq (tieneDatosPieIzquierdo); si no, N/A en vez de un 50 fingido.
                                  // No usa _footFilter: Balance ya compara ambos pies. Se muestra como % de desequilibrio (0=simétrico), no el balance crudo (50=simétrico).
                                  final tieneIzq = tieneDatosPieIzquierdo(
                                      widget.datosSesion);
                                  final balanceVal = tieneIzq
                                      ? ((calcularBalance(widget.datosSesion) -
                                                  50)
                                              .abs() *
                                          2)
                                          .round()
                                      : null;
                                  // Impact sí varía con _footFilter: el pico de presión por contacto puede ser distinto en cada pie.
                                  final impactoPct = widget.datosSesion.isEmpty
                                      ? null
                                      : _footFilter == 'left'
                                          ? (tieneIzq
                                              ? calcularImpacto(
                                                  widget.datosSesion,
                                                  Pie.izquierda)
                                              : null)
                                          : _footFilter == 'right'
                                              ? calcularImpacto(
                                                  widget.datosSesion,
                                                  Pie.derecha)
                                              : (tieneIzq
                                                  ? ((calcularImpacto(
                                                              widget
                                                                  .datosSesion,
                                                              Pie.derecha) +
                                                          calcularImpacto(
                                                              widget
                                                                  .datosSesion,
                                                              Pie.izquierda)) /
                                                      2)
                                                  : calcularImpacto(
                                                      widget.datosSesion,
                                                      Pie.derecha));
                                  final impactoVal = impactoPct?.round();
                                  // Igual que en Detalle de actividad: con peso registrado se muestra en kg en vez de %; el anillo sigue lleno según el %.
                                  final peso = usuarioActual?.peso ?? 0;
                                  final impactoKgVal = (impactoPct != null &&
                                          peso > 0)
                                      ? '${impactoAKg(impactoPct, peso).round()} kg'
                                      : null;
                                  return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _CircProgress(
                                            value: balanceVal,
                                            color: kTeal,
                                            label: tr('metric_balance'),
                                            info: tr('balance_info')),
                                        _CircProgress(
                                            value: impactoVal,
                                            etiquetaNumero: impactoKgVal,
                                            color: kOrange,
                                            label: tr('metric_impact'),
                                            info: tr('impact_info')),
                                      ]);
                                }),
                              ])),
                      const SizedBox(height: 16),

                      Row(
                          children: [
                        {
                          'label': tr('duration_label'),
                          'value': durStr,
                          'color': kPurple,
                          'ultimo': false,
                        },
                        {'label': tr('steps_label'), 'value': '$steps', 'color': kRed, 'ultimo': false},
                        {
                          'label': tr('metric_distance'),
                          'value': '$km km',
                          'color': kTeal,
                          'ultimo': true,
                        },
                      ]
                              .map((s) => Expanded(
                                      child: Padding(
                                    padding: EdgeInsets.only(
                                        right: (s['ultimo'] as bool) ? 0 : 8.0),
                                    child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                            color: kCard,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: kGrayDark.withValues(
                                                    alpha: 0.5))),
                                        child: Column(children: [
                                          Text(s['label'] as String,
                                              style: const TextStyle(
                                                  color: kGray, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text(s['value'] as String,
                                              style: TextStyle(
                                                  color: s['color'] as Color,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700)),
                                        ])),
                                  )))
                              .toList()),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: _guardar,
                        child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                                gradient: kGradient,
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(tr('save_session'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                ])),
                      ),
                    ]))),
      ])),
    );
  }
}

// Anillo de progreso circular con el valor en el centro (Balance, Impact...).
// value a null: no se puede calcular esa métrica, muestra "N/A" y anillo gris en vez de un número inventado.
class _CircProgress extends StatelessWidget {
  final int? value;
  final Color color;
  final String label;
  final String? info;
  // Sustituye el "X%" central por este texto cuando se conoce (p.ej. "X kg"); el anillo sigue lleno según value.
  final String? etiquetaNumero;
  const _CircProgress(
      {required this.value,
      required this.color,
      required this.label,
      this.info,
      this.etiquetaNumero});
  @override
  Widget build(BuildContext context) {
    final conocido = value != null;
    return Column(children: [
      SizedBox(
          width: 95,
          height: 95,
          // Anima de 0 al valor real cada vez que aparece, sin recortar para que el número pueda superar 100.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: conocido ? value!.toDouble() : 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                        width: 95,
                        height: 95,
                        child: CircularProgressIndicator(
                            // El anillo tope a 100%; el texto de abajo sí muestra el valor real.
                            value: conocido ? (animado / 100).clamp(0.0, 1.0) : 0,
                            strokeWidth: 9,
                            backgroundColor: kGrayDark,
                            valueColor: AlwaysStoppedAnimation(
                                conocido ? color : kGray))),
                    Text(
                        conocido
                            ? (etiquetaNumero ?? '${animado.round()}%')
                            : 'N/A',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: conocido ? 22 : 16,
                            fontWeight: FontWeight.w700)),
                  ])),
      ),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        if (info != null) InfoTip(titulo: label, texto: info!),
      ]),
    ]);
  }
}
