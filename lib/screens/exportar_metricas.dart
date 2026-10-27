part of '../main.dart';

// ---- EXPORT METRICS SCREEN ----
// Gráficas de Balance/Impact/Cadence por periodo; periodoMetricasSeleccionado se comparte con Home.
class VistaExportMetrics extends StatefulWidget {
  const VistaExportMetrics({super.key});
  @override
  State<VistaExportMetrics> createState() => _VistaExportMetricsState();
}

class _VistaExportMetricsState extends State<VistaExportMetrics> with IdiomaListenerMixin {
  List<Map<String, String>> get _periods => [
    {'value': 'week', 'label': tr('period_week')},
    {'value': 'month', 'label': tr('period_month')},
    {'value': 'year', 'label': tr('period_year')},
    {'value': 'all', 'label': tr('period_all_time')},
  ];

  // Agrupa sesiones por periodo (semana->día, mes->semana, año/todo->mes) para no amontonar puntos con 1-2 sesiones/semana; Balance/Impact usan las mismas fórmulas que Home.
  List<Map<String, dynamic>> _agruparSesiones(List<SesionActividad> sesiones,
      String Function(DateTime fecha) claveDe,
      String Function(DateTime fecha) etiquetaDe) {
    // LinkedHashMap implícito: como 'sesiones' llega ordenada ascendente, la etiqueta de cada grupo queda la de su sesión más reciente y el orden de inserción es cronológico.
    final grupos = <String, List<SesionActividad>>{};
    final etiquetas = <String, String>{};
    for (final s in sesiones) {
      final fecha = DateTime.tryParse(s.id);
      final clave = fecha == null ? 'sf_${s.id}' : claveDe(fecha);
      grupos.putIfAbsent(clave, () => []).add(s);
      etiquetas[clave] = fecha == null ? s.fecha : etiquetaDe(fecha);
    }
    return grupos.entries.map((e) {
      final lista = e.value;
      // Igual que balanceMedioPeriodo/impactoMedioPeriodo: solo cuentan sesiones con dato real, para no arrastrar el promedio hacia 50/0; si ninguna lo tiene, cae al grupo completo (evita dividir por lista vacía).
      final conBalance = lista.where((s) => s.tieneBalance).toList();
      final baseBalance = conBalance.isEmpty ? lista : conBalance;
      final balance = baseBalance
              .map((s) => (s.balance - 50).abs() * 2)
              .reduce((a, b) => a + b) /
          baseBalance.length;
      final conImpacto = lista.where((s) => s.tieneImpacto).toList();
      final baseImpacto = conImpacto.isEmpty ? lista : conImpacto;
      final impact = baseImpacto
              .map((s) => (s.impacto + s.impactoIzq) / 2)
              .reduce((a, b) => a + b) /
          baseImpacto.length;
      final cadence =
          lista.map((s) => s.cadencia).reduce((a, b) => a + b) /
              lista.length;
      return {
        'date': etiquetas[e.key],
        'balance': balance.round(),
        'impact': impact.round(),
        'cadence': cadence.round(),
      };
    }).toList();
  }

  String _claveDia(DateTime f) => '${f.year}-${f.month}-${f.day}';
  // Nombre del día (Lun, Mar...) en vez de "16/9": sin ambigüedad y más corto en una ventana de 7 días.
  String _etiquetaDia(DateTime f) => tr('weekday_${f.weekday}');

  // Semana de calendario lunes-domingo (weekday 1=lunes, 7=domingo), no ventana móvil de 7 días.
  DateTime _lunesDeLaSemana(DateTime f) {
    final soloFecha = DateTime(f.year, f.month, f.day);
    return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
  }

  String _claveSemana(DateTime f) {
    final lunes = _lunesDeLaSemana(f);
    return '${lunes.year}-${lunes.month}-${lunes.day}';
  }

  String _claveMes(DateTime f) => '${f.year}-${f.month}';
  String _etiquetaMes(DateTime f) {
    final nombre = tr('month_${f.month}');
    final abrev = nombre.substring(0, nombre.length < 3 ? nombre.length : 3);
    return f.year == DateTime.now().year ? abrev : '$abrev ${f.year % 100}';
  }

  // A diferencia de _agruparSesiones, la etiqueta ("Sem 1", "Sem 2"...) sale del orden de aparición, no de la fecha: el rango "9/9–15/9" liaba más que ayudaba.
  List<Map<String, dynamic>> _agruparPorSemana(List<SesionActividad> sesiones) {
    final grupos = <String, List<SesionActividad>>{};
    for (final s in sesiones) {
      final fecha = DateTime.tryParse(s.id);
      final clave = fecha == null ? 'sf_${s.id}' : _claveSemana(fecha);
      grupos.putIfAbsent(clave, () => []).add(s);
    }
    final etiquetaSemana = tr('week_label_short');
    var indice = 0;
    return grupos.entries.map((e) {
      indice++;
      final lista = e.value;
      // Mismo criterio que _agruparSesiones: solo promediar sesiones con dato real de balance/impacto.
      final conBalance = lista.where((s) => s.tieneBalance).toList();
      final baseBalance = conBalance.isEmpty ? lista : conBalance;
      final balance = baseBalance
              .map((s) => (s.balance - 50).abs() * 2)
              .reduce((a, b) => a + b) /
          baseBalance.length;
      final conImpacto = lista.where((s) => s.tieneImpacto).toList();
      final baseImpacto = conImpacto.isEmpty ? lista : conImpacto;
      final impact = baseImpacto
              .map((s) => (s.impacto + s.impactoIzq) / 2)
              .reduce((a, b) => a + b) /
          baseImpacto.length;
      final cadence =
          lista.map((s) => s.cadencia).reduce((a, b) => a + b) /
              lista.length;
      return {
        'date': '$etiquetaSemana $indice',
        'balance': balance.round(),
        'impact': impact.round(),
        'cadence': cadence.round(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _data {
    final sesiones = sesionesEnPeriodo(periodoMetricasSeleccionado);
    switch (periodoMetricasSeleccionado) {
      case 'week':
        return _agruparSesiones(sesiones, _claveDia, _etiquetaDia);
      case 'month':
        return _agruparPorSemana(sesiones);
      default: // 'year' y 'all': una media por mes.
        return _agruparSesiones(sesiones, _claveMes, _etiquetaMes);
    }
  }

  // A diferencia de _data (agrupada), el CSV exporta el detalle real sin promediar, para analizar fuera con el dato crudo.
  List<Map<String, dynamic>> get _datosCsvCrudos =>
      sesionesEnPeriodo(periodoMetricasSeleccionado).map((s) {
        final fecha = DateTime.tryParse(s.id);
        return {
          'date': fecha == null
              ? s.fecha
              : '${fecha.day}/${fecha.month}/${fecha.year}',
          // 'NA' (no un 50/0 que parezca dato real) si la sesión nunca tuvo pie izquierdo o muestras crudas.
          'balance': s.tieneBalance
              ? ((s.balance - 50).abs() * 2).round().toString()
              : 'NA',
          'impact': s.tieneImpacto
              ? ((s.impacto + s.impactoIzq) / 2).round().toString()
              : 'NA',
          'cadence': s.cadencia.round().toString(),
        };
      }).toList();

  // Genera el CSV del periodo seleccionado y abre el diálogo nativo de compartir/guardar.
  Future<void> _exportarCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('date,balance,impact,cadence');
    for (final d in _datosCsvCrudos) {
      buffer.writeln(
          '${d['date']},${d['balance']},${d['impact']},${d['cadence']}');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/gogait_metrics_$periodoMetricasSeleccionado.csv');
    await file.writeAsString(buffer.toString());
    if (!mounted) {
      return;
    }
    await Share.shareXFiles([XFile(file.path)],
        text: 'GOGAIT metrics ($periodoMetricasSeleccionado)');
  }

  // Construye la tarjeta con la gráfica de una métrica (balance/impact/cadence).
  Widget _buildChart(String label, String key, Color color,
      {String? infoTexto}) {
    final dataValues = _data.map((d) => (d[key] as int).toDouble()).toList();
    final dataLabels = _data.map((d) => d['date'] as String).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGrayDark.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          if (infoTexto != null) InfoTip(titulo: label, texto: infoTexto),
        ]),
        const SizedBox(height: 16),
        SizedBox(
            height: 160,
            child: _InteractiveChart(
                data: dataValues,
                labels: dataLabels,
                color: color,
                metricLabel: label)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mismas funciones que Home, para no mostrar un número distinto bajo la misma etiqueta.
    final balancePeriodo = balanceMedioPeriodo(periodoMetricasSeleccionado);
    final impactoPeriodo = impactoMedioPeriodo(periodoMetricasSeleccionado);
    final avgBalance = balancePeriodo?.round();
    final avgImpact = impactoPeriodo?.round();
    // Media real de todas las sesiones del periodo (no de los puntos agrupados de _data), igual que balancePeriodo/impactoPeriodo.
    final avgCadence =
        cadenciaMediaPeriodo(periodoMetricasSeleccionado).round();

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
                  child: Text(tr('export_metrics_title'),
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
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, color: kGray, size: 16),
                    const SizedBox(width: 8),
                    Text(tr('time_period'),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                      children: _periods
                          .map((p) => Expanded(
                                  child: GestureDetector(
                                onTap: () => setState(() =>
                                    periodoMetricasSeleccionado =
                                        p['value']!),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: periodoMetricasSeleccionado ==
                                            p['value']
                                        ? kGradient
                                        : null,
                                    color: periodoMetricasSeleccionado ==
                                            p['value']
                                        ? null
                                        : kCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: periodoMetricasSeleccionado ==
                                                p['value']
                                            ? Colors.transparent
                                            : kGrayDark),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(p['label']!,
                                      style: TextStyle(
                                          color: periodoMetricasSeleccionado ==
                                                  p['value']
                                              ? Colors.white
                                              : kGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ),
                              )))
                          .toList()),
                  const SizedBox(height: 20),

                  Row(
                      children: [
                    {
                      // Quick Metrics es la única pantalla donde el número se colorea por umbral; en el resto (Home, Resumen, Detalle) queda fijo.
                      'label': tr('metric_balance'),
                      'value': avgBalance == null ? 'N/A' : '$avgBalance%',
                      'color': balancePeriodo == null
                          ? kGray
                          : colorDesequilibrio(balancePeriodo),
                      'ultimo': false,
                    },
                    {
                      'label': tr('metric_impact'),
                      'value': avgImpact == null ? 'N/A' : '$avgImpact%',
                      'color': impactoPeriodo == null
                          ? kGray
                          : colorImpacto(impactoPeriodo),
                      'ultimo': false,
                    },
                    {
                      'label': tr('metric_cadence'),
                      'value': '$avgCadence spm',
                      'color': kPurple,
                      'ultimo': true,
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
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: kGrayDark.withValues(
                                              alpha: 0.5))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m['label'] as String,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(m['value'] as String,
                                            style: TextStyle(
                                                color: m['color'] as Color,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ),
                              )))
                          .toList()),
                  const SizedBox(height: 16),

                  // Mismo color que la tarjeta resumen, según la media del periodo (colorDesequilibrio/colorImpacto).
                  _buildChart(
                      tr('metric_balance'),
                      'balance',
                      balancePeriodo == null
                          ? kGray
                          : colorDesequilibrio(balancePeriodo),
                      infoTexto: tr('balance_info')),
                  const SizedBox(height: 12),
                  _buildChart(
                      tr('metric_impact'),
                      'impact',
                      impactoPeriodo == null
                          ? kGray
                          : colorImpacto(impactoPeriodo),
                      infoTexto: tr('impact_info')),
                  const SizedBox(height: 12),
                  _buildChart(tr('metric_cadence'), 'cadence', kPurple,
                      infoTexto: tr('cadence_info')),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _exportarCsv,
                    child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00D9C0), Color(0xFF00E6A8)]),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download_outlined,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(tr('export_to_csv'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                            ])),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('export_period_note'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kGray, fontSize: 12)),
                ]))),
      ])),
    );
  }
}

// Gráfica de línea táctil: al tocar, resalta el punto más cercano y muestra su tooltip.
class _InteractiveChart extends StatefulWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final String metricLabel;
  const _InteractiveChart(
      {required this.data,
      required this.labels,
      required this.color,
      required this.metricLabel});
  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _dibujoCtrl;

  // Anima la línea "dibujándose" una vez al aparecer; no se repite en cada rebuild (p.ej. al tocar un punto).
  @override
  void initState() {
    super.initState();
    _dibujoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _dibujoCtrl.dispose();
    super.dispose();
  }

  // Averigua qué punto está más cerca del toque y lo selecciona (o deselecciona si ya lo estaba).
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        const leftPad = 36.0;
        final chartW = box.size.width - leftPad;
        final stepX =
            widget.data.length > 1 ? chartW / (widget.data.length - 1) : 0.0;
        int closest = 0;
        double minDist = double.infinity;
        for (int i = 0; i < widget.data.length; i++) {
          final dist = (local.dx - (leftPad + i * stepX)).abs();
          if (dist < minDist) {
            minDist = dist;
            closest = i;
          }
        }
        setState(
            () => _selectedIndex = _selectedIndex == closest ? null : closest);
      },
      child: AnimatedBuilder(
        animation: _dibujoCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            data: widget.data,
            labels: widget.labels,
            color: widget.color,
            selectedIndex: _selectedIndex,
            metricLabel: widget.metricLabel,
            progreso: Curves.easeOutCubic.transform(_dibujoCtrl.value),
          ),
        ),
      ),
    );
  }
}

// Dibuja la gráfica de línea: rejilla, eje de valores, la línea con sus puntos, y el tooltip del punto seleccionado.
class _LinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final int? selectedIndex;
  final String metricLabel;
  // 0 = nada dibujado todavía, 1 = línea completa. Ver _InteractiveChartState.
  final double progreso;

  _LinePainter(
      {required this.data,
      required this.labels,
      required this.color,
      this.selectedIndex,
      required this.metricLabel,
      this.progreso = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    const leftPad = 36.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;
    // Guarda: con un único punto data.length-1 sería 0 y la división daría Infinity/NaN.
    final stepX = data.length > 1 ? chartW / (data.length - 1) : 0.0;

    // Impact suele superar 100 (ver calcularImpacto): el eje se adapta al máximo real (100 como suelo), redondeado al siguiente múltiplo de 100.
    final maxDato = data.reduce((a, b) => a > b ? a : b);
    final maxEje = maxDato <= 100 ? 100.0 : (maxDato / 100).ceil() * 100.0;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A2F3E)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = (maxEje * i / 4).toInt();
      tp.text = TextSpan(
          text: '$val', style: const TextStyle(color: kGray, fontSize: 9));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path();
    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final x = leftPad + i * stepX;
      final y = chartH - (data[i] / maxEje) * chartH;
      points.add(Offset(x, y));
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    // Se dibuja solo el tramo que toca según 'progreso' (0 a 1), cortando con PathMetrics en vez de mostrar/ocultar segmentos completos, para que se vea "dibujándose" con trazo continuo.
    if (progreso >= 1) {
      canvas.drawPath(linePath, linePaint);
    } else if (progreso > 0) {
      final visible = Path();
      for (final metric in linePath.computeMetrics()) {
        visible.addPath(
            metric.extractPath(0, metric.length * progreso), Offset.zero);
      }
      canvas.drawPath(visible, linePaint);
    }

    // Con muchos puntos las etiquetas se pisan: solo se pintan las que quepan sin solapar (según el ancho real de la más larga), siempre incluyendo primera y última; el resto se ve en el tooltip.
    var anchoEtiquetaMax = 0.0;
    for (final l in labels) {
      tp.text = TextSpan(text: l, style: const TextStyle(fontSize: 9));
      tp.layout();
      if (tp.width > anchoEtiquetaMax) {
        anchoEtiquetaMax = tp.width;
      }
    }
    final anchoEtiquetaAprox = anchoEtiquetaMax + 10;
    final maxEtiquetas = points.length <= 2
        ? points.length
        : (chartW / anchoEtiquetaAprox).floor().clamp(2, points.length);
    final indicesEtiqueta = <int>{};
    if (points.length <= maxEtiquetas) {
      indicesEtiqueta.addAll(List.generate(points.length, (i) => i));
    } else {
      final paso = (points.length - 1) / (maxEtiquetas - 1);
      for (int i = 0; i < maxEtiquetas; i++) {
        indicesEtiqueta.add((i * paso).round());
      }
    }

    // Cada punto aparece solo cuando la línea ya lo ha alcanzado (mismo criterio de índice que 'progreso').
    final puntosVisibles = points.isEmpty
        ? 0
        : (progreso * (points.length - 1)).floor() + 1;
    for (int i = 0; i < points.length && i < puntosVisibles; i++) {
      final isSelected = i == selectedIndex;
      canvas.drawCircle(points[i], isSelected ? 7 : 5, Paint()..color = color);
      canvas.drawCircle(
          points[i], isSelected ? 4 : 3, Paint()..color = Colors.white);
      if (indicesEtiqueta.contains(i)) {
        tp.text = TextSpan(
            text: labels[i], style: const TextStyle(color: kGray, fontSize: 9));
        tp.layout();
        tp.paint(
            canvas, Offset(points[i].dx - tp.width / 2, size.height - 14));
      }
    }

    if (progreso >= 1 && selectedIndex != null && selectedIndex! < points.length) {
      final p = points[selectedIndex!];
      final val = data[selectedIndex!].toInt();
      final dateLabel = labels[selectedIndex!];
      tp.text = TextSpan(
        text: '$dateLabel\n$metricLabel : $val',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.6,
            fontWeight: FontWeight.w600),
      );
      tp.layout();
      const pad = 10.0;
      final tw = tp.width + pad * 2;
      final th = tp.height + pad * 2;
      double tx = p.dx - tw / 2;
      double ty = p.dy - th - 10;
      if (tx < leftPad) {
        tx = leftPad;
      }
      if (tx + tw > size.width) {
        tx = size.width - tw;
      }
      if (ty < 0) {
        ty = p.dy + 10;
      }
      final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx, ty, tw, th), const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF252B3B));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = kGrayDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      tp.paint(canvas, Offset(tx + pad, ty + pad));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.data != data ||
      old.selectedIndex != selectedIndex ||
      old.color != color ||
      old.progreso != progreso;
}
