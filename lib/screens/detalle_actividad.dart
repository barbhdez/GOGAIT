part of '../main.dart';

// ---- ACTIVITY DETAIL SCREEN ----
// Detalle de una sesión guardada: heatmap reconstruido, gráfica de fatiga, y edición de título/notas.
class VistaDetalleHistorico extends StatefulWidget {
  final SesionActividad sesion;
  const VistaDetalleHistorico({super.key, required this.sesion});
  @override
  State<VistaDetalleHistorico> createState() => _VistaDetalleHistoricoState();
}

class _VistaDetalleHistoricoState extends State<VistaDetalleHistorico> with IdiomaListenerMixin {
  late TextEditingController _t, _d;
  bool _editing = false;
  String _footFilter = 'both';

  // Precarga los campos editables con el título y las notas guardadas.
  @override
  void initState() {
    super.initState();
    _t = TextEditingController(text: widget.sesion.titulo);
    _d = TextEditingController(text: widget.sesion.descripcion);
  }

  @override
  void dispose() {
    _t.dispose();
    _d.dispose();
    super.dispose();
  }

  // Limpia un valor para usarlo en nombre de fichero: fuera caracteres no válidos en rutas, espacios a "_", nunca vacío.
  String _paraNombreArchivo(String v) {
    final limpio = v
        .trim()
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[\\:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return limpio.isEmpty ? 'sinnombre' : limpio;
  }

  // Envuelve en comillas si hace falta (coma, comillas o salto de línea dentro, p.ej. en notas libres) para seguir siendo CSV válido.
  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // Construye el CSV de resumen: todo lo que la app registra de la sesión en una sola fila.
  String _construirCsvResumen() {
    final s = widget.sesion;
    // Sin muestras crudas, impacto es desconocido (NA), no "0". Balance necesita además señal real del pie izquierdo, si no, NA en vez de un "50" fingido.
    final sinDatosCrudos = !s.tieneImpacto;
    final sinBalance = !s.tieneBalance;
    // impacto_kg necesita peso corporal registrado (ver impactoAKg): si hubo impacto pero no kg, es que faltaba el peso, no que fuese 0.
    final sinPeso = (s.impacto + s.impactoIzq) / 2 > 0 && s.impactoKg <= 0;
    // zancada_ratio necesita altura, pasos y distancia (ver ratioZancada); 0 solo significa que faltaba algún dato.
    final sinZancada = s.zancadaRatio <= 0;
    // strike_index necesita al menos un contacto con fase registrada; sin eso, 0 es "no medido", no "talón puro".
    final sinStrikeDer = !s.tieneStrikeDer;
    final sinStrikeIzq = !s.tieneStrikeIzq;
    // fatiga_index/performance_score ya están guardados de forma permanente, no dependen de datosSesion.
    final sinFatiga = !s.tieneFatiga;
    final performanceScore = calcularPerformanceScore(
      balance: s.balance,
      tieneBalance: s.tieneBalance,
      fatiga: s.tieneFatiga ? s.fatiga : 0,
      tieneFatiga: s.tieneFatiga,
      zancadaRatio: s.zancadaRatio > 0 ? s.zancadaRatio : null,
    );
    // Los 4 ADC de calibración de cada pie: null si la sesión es anterior a este campo o esa plantilla no se calibró.
    String adc(double? v) => v == null ? 'NA' : v.toStringAsFixed(0);
    final buffer = StringBuffer();
    buffer.writeln('titulo,descripcion,tipo,fecha,hora,duracion,pasos,'
        'cadencia_spm,distancia_km,presion_talon_media,'
        'presion_metatarso_media,presion_talon_izq_media,'
        'presion_metatarso_izq_media,balance,impacto,impacto_izq,'
        'impacto_kg,impacto_multiplos_peso,zancada_ratio,strike_index_der,'
        'strike_index_izq,fatiga_index,performance_score,'
        'calib_adc_reposo_der,calib_adc_carga_der,calib_adc_talon_der,'
        'calib_adc_punta_der,calib_adc_reposo_izq,calib_adc_carga_izq,'
        'calib_adc_talon_izq,calib_adc_punta_izq');
    buffer.writeln([
      _csvEscape(s.titulo),
      _csvEscape(s.descripcion),
      s.tipo,
      s.fecha,
      s.hora,
      _csvEscape(s.duracion),
      s.pasos,
      s.cadencia.toStringAsFixed(1),
      s.distanciaKm.toStringAsFixed(3),
      s.presionTalon.toStringAsFixed(1),
      s.presionMeta.toStringAsFixed(1),
      s.presionTalonIzq.toStringAsFixed(1),
      s.presionMetaIzq.toStringAsFixed(1),
      // Desequilibrio (0=simétrico), no el balance crudo interno (50=simétrico), para coincidir con lo que se ve en pantalla.
      sinBalance ? 'NA' : ((s.balance - 50).abs() * 2).toStringAsFixed(1),
      sinDatosCrudos ? 'NA' : s.impacto.toStringAsFixed(1),
      sinDatosCrudos ? 'NA' : s.impactoIzq.toStringAsFixed(1),
      sinDatosCrudos || sinPeso ? 'NA' : s.impactoKg.toStringAsFixed(1),
      // Impacto en múltiplos del peso (ej. 1,5 = 1,5x), deliberadamente sin aplicar el peso real en kg (no exige sinPeso): es el mismo coeficiente que usa impactoAKg, sirve aunque el usuario nunca registrara su peso.
      sinDatosCrudos
          ? 'NA'
          : ((s.impacto + s.impactoIzq) / 2 / 100).toStringAsFixed(2),
      sinZancada ? 'NA' : s.zancadaRatio.toStringAsFixed(2),
      sinStrikeDer ? 'NA' : s.strikeIndexDer.toStringAsFixed(1),
      sinStrikeIzq ? 'NA' : s.strikeIndexIzq.toStringAsFixed(1),
      sinFatiga ? 'NA' : s.fatiga.toStringAsFixed(1),
      performanceScore == null ? 'NA' : performanceScore.toStringAsFixed(1),
      adc(s.adcReposoDer),
      adc(s.adcCargaDer),
      adc(s.adcTalonDer),
      adc(s.adcPuntaDer),
      adc(s.adcReposoIzq),
      adc(s.adcCargaIzq),
      adc(s.adcTalonIzq),
      adc(s.adcPuntaIzq),
    ].join(','));
    return buffer.toString();
  }

  // Construye el CSV con las muestras crudas de la sesión (una fila por muestra recibida de la placa).
  String _construirCsvMuestras() {
    final buffer = StringBuffer();
    buffer.writeln('segundo,talon_izquierdo,metatarso_izquierdo,'
        'talon_derecho,metatarso_derecho,fase_izquierda,fase_derecha');
    for (final d in widget.sesion.datosSesion) {
      // faseIzq/faseDer no existen en sesiones anteriores a este campo: en blanco en vez de "null".
      final faseIzq = d['faseIzq'] ?? '';
      final faseDer = d['faseDer'] ?? '';
      buffer.writeln('${d['seg']},${d['talonIzq']},${d['metaIzq']},'
          '${d['talonDer']},${d['metaDer']},$faseIzq,$faseDer');
    }
    return buffer.toString();
  }

  // Genera los CSV (resumen + muestras crudas si las hay) y abre el diálogo nativo de compartir/guardar.
  Future<void> _exportarCsv() async {
    final dir = await getTemporaryDirectory();
    final usuario = _paraNombreArchivo(usuarioActual?.nombre ?? '');
    final actividad = _paraNombreArchivo(widget.sesion.titulo);
    final fecha = _paraNombreArchivo(widget.sesion.fecha);
    final base = '${usuario}_${actividad}_$fecha';
    final resumenFile = File('${dir.path}/GOGAITSummary_$base.csv');
    await resumenFile.writeAsString(_construirCsvResumen());
    final files = [XFile(resumenFile.path)];
    if (widget.sesion.datosSesion.isNotEmpty) {
      final muestrasFile = File('${dir.path}/GOGAIT_$base.csv');
      await muestrasFile.writeAsString(_construirCsvMuestras());
      files.add(XFile(muestrasFile.path));
    }
    if (!mounted) {
      return;
    }
    await Share.shareXFiles(files,
        text: 'GOGAIT session data: ${widget.sesion.titulo}');
  }

  // Pide confirmación y, si se acepta, borra la sesión del historial y vuelve atrás.
  Future<void> _confirmarBorrado() async {
    final borrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kGrayDark)),
        title: Text(tr('delete_activity_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(tr('action_cannot_be_undone'),
            style: const TextStyle(color: kGray, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel_button'), style: const TextStyle(color: kGray))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete_button'),
                  style: const TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (borrar == true) {
      historial.remove(widget.sesion);
      await guardarHistorial();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Reconstruye un heatmap aproximado del pie izquierdo a partir de las métricas medias (no hay datos punto a punto); 0 si esa plantilla no tuvo datos reales.
  List<double> get _leftData => List.generate(30, (i) {
        if (i < 14) {
          return widget.sesion.presionMetaIzq;
        }
        if (i < 19) {
          return 10;
        }
        return widget.sesion.presionTalonIzq;
      });

  // Igual que _leftData pero para el pie derecho.
  List<double> get _rightData => List.generate(30, (i) {
        if (i < 14) {
          return widget.sesion.presionMeta;
        }
        if (i < 19) {
          return 10;
        }
        return widget.sesion.presionTalon;
      });

  // Color de la barra de presión según el porcentaje (misma escala que _pressureColor, paleta propia).
  Color _pressureBarColor(int pct) {
    if (pct < 25) {
      return const Color(0xFFFFE082);
    }
    if (pct < 40) {
      return const Color(0xFFFFC107);
    }
    if (pct < 55) {
      return kOrange;
    }
    if (pct < 70) {
      return kRed;
    }
    return const Color(0xFFFF0000);
  }

  // Barra horizontal de progreso para una métrica de presión (con su %).
  Widget _pressureBar(String label, int pct) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(color: kGray, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Text('$pct%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
          borderRadius: BorderRadius.circular(3),
          // Barra animada de 0 al valor real, no aparece ya llena.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => LinearProgressIndicator(
                  // Tope visual 100%; el texto de arriba muestra el % real sin recortar.
                  value: animado,
                  minHeight: 6,
                  backgroundColor: kGrayDark,
                  valueColor: AlwaysStoppedAnimation(_pressureBarColor(pct))))),
      const SizedBox(height: 8),
    ]);
  }

  // Barra de progreso de una métrica que cambia según el filtro de pie elegido (ambos/izquierdo/derecho).
  Widget _metricBar(String label, int pctBoth, int pctLeft, int pctRight,
      Color color, String badge, {String? info, String? etiquetaNumero}) {
    final pct = _footFilter == 'left'
        ? pctLeft
        : _footFilter == 'right'
            ? pctRight
            : pctBoth;
    // Impact pasa "X kg" aquí cuando hay peso registrado, para no repetir el % en una insignia aparte.
    final textoNumero = etiquetaNumero ?? '$pct%';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Row(children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style:
                      const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
            ),
            if (info != null) InfoTip(titulo: label, texto: info),
          ]),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(textoNumero,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            if (badge.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(badge,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500))),
              ),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          // Igual que en _pressureBar: anima hacia el nuevo % al aparecer o al cambiar el filtro de pie.
          child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animado, __) => LinearProgressIndicator(
                  // Igual que en _pressureBar: barra tope a 100%, el número de arriba muestra el real.
                  value: animado,
                  minHeight: 8,
                  backgroundColor: kGrayDark,
                  valueColor: AlwaysStoppedAnimation(color)))),
    ]);
  }

  // Selector Both/Left Foot/Right Foot que filtra las métricas mostradas.
  Widget _footSelector() {
    return Row(
        children: ['both', 'left', 'right'].map((f) {
      final label = f == 'both'
          ? tr('both_label')
          : f == 'left'
              ? tr('left_foot')
              : tr('right_foot');
      final sel = _footFilter == f;
      return Expanded(
          child: GestureDetector(
        onTap: () => setState(() => _footFilter = f),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? kOrange.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? kOrange : kGrayDark),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: sel ? kOrange : kGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ));
    }).toList());
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
                  child: Text(tr('activity_details'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap: () {
                    if (_editing) {
                      widget.sesion.titulo = _t.text;
                      widget.sesion.descripcion = _d.text;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr('changes_saved')),
                          backgroundColor: kCard,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))));
                    }
                    setState(() => _editing = !_editing);
                  },
                  child: Icon(_editing ? Icons.check : Icons.edit_outlined,
                      color: kOrange, size: 20)),
              const SizedBox(width: 16),
              GestureDetector(
                  onTap: _confirmarBorrado,
                  child:
                      const Icon(Icons.delete_outline, color: kRed, size: 20)),
            ])),

        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editing
                          ? TextField(
                              controller: _t,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                  filled: true,
                                  fillColor: kCard,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange))))
                          : Text(_t.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: kGray, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(() {
                            final parts = widget.sesion.fecha.split('/');
                            if (parts.length >= 2) {
                              final mes = int.tryParse(parts[1]) ?? 1;
                              // Abreviatura del mes traducido, no lista fija en inglés (respeta idioma activo).
                              final mesAbrev = tr('month_$mes')
                                  .substring(
                                      0,
                                      tr('month_$mes').length < 3
                                          ? tr('month_$mes').length
                                          : 3);
                              // Sesiones antiguas sin año en 'fecha': se recupera del id (timestamp completo).
                              final anio = parts.length >= 3
                                  ? parts[2]
                                  : DateTime.tryParse(widget.sesion.id)
                                          ?.year
                                          .toString() ??
                                      '';
                              final sufijo = anio.isEmpty ? '' : ' $anio';
                              return '${parts[0]} $mesAbrev$sufijo';
                            }
                            return widget.sesion.fecha;
                          }(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style:
                                  const TextStyle(color: kGray, fontSize: 14)),
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.access_time_outlined,
                            color: kGray, size: 16),
                        const SizedBox(width: 6),
                        Text(() {
                          final h = widget.sesion.hora.split(':');
                          if (h.length == 2) {
                            final hora = int.tryParse(h[0]) ?? 0;
                            final min = h[1];
                            final ampm = hora >= 12 ? 'PM' : 'AM';
                            final hora12 = hora > 12
                                ? hora - 12
                                : hora == 0
                                    ? 12
                                    : hora;
                            return '$hora12:$min $ampm';
                          }
                          return widget.sesion.hora;
                        }(),
                            style: const TextStyle(color: kGray, fontSize: 14)),
                      ]),
                      const SizedBox(height: 16),

                      Text(tr('notes_label'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 8),
                      _editing
                          ? TextField(
                              controller: _d,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                  filled: true,
                                  fillColor: kCard,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: kOrange))))
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kGrayDark)),
                              child: Text(
                                  _d.text.isEmpty ? tr('no_notes') : _d.text,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB), fontSize: 14))),
                      const SizedBox(height: 20),
                      // Se oculta en modo edición: solo queda visible lo editable (título y notas).
                      if (!_editing) ...[
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Builder(builder: (context) {
                            final s = widget.sesion;
                            final score = calcularPerformanceScore(
                              balance: s.balance,
                              tieneBalance: s.tieneBalance,
                              fatiga: s.tieneFatiga ? s.fatiga : 0,
                              tieneFatiga: s.tieneFatiga,
                              zancadaRatio:
                                  s.zancadaRatio > 0 ? s.zancadaRatio : null,
                            );
                            // Combina balance/fatiga/zancada; N/A si faltan datos en las tres.
                            final etiqueta = score == null
                                ? 'N/A'
                                : score >= 85
                                    ? tr('score_excellent')
                                    : score >= 70
                                        ? tr('score_good')
                                        : score >= 50
                                            ? tr('score_fair')
                                            : tr('score_needs_improvement');
                            return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(tr('performance_score'),
                                            style: const TextStyle(
                                                color: kGray, fontSize: 14)),
                                        InfoTip(
                                            titulo: tr('performance_score'),
                                            texto:
                                                tr('performance_score_info')),
                                      ]),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                      width: 160,
                                      height: 160,
                                      // Anima de 0 al score real, como en _CircProgress.
                                      child: TweenAnimationBuilder<double>(
                                          tween: Tween(
                                              begin: 0,
                                              end: score ?? 0),
                                          duration:
                                              const Duration(milliseconds: 900),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, animado, __) =>
                                              Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    SizedBox(
                                                        width: 160,
                                                        height: 160,
                                                        child:
                                                            CircularProgressIndicator(
                                                                value: score ==
                                                                        null
                                                                    ? 0
                                                                    : animado /
                                                                        100,
                                                                strokeWidth: 14,
                                                                backgroundColor:
                                                                    kGrayDark,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation(
                                                                        score ==
                                                                                null
                                                                            ? kGray
                                                                            : kOrange))),
                                                    Text(
                                                        score == null
                                                            ? '0'
                                                            : '${animado.round()}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 36,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                  ]))),
                                  const SizedBox(height: 24),
                                  Text(etiqueta,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                  const SizedBox(height: 8),
                                ]);
                          })),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.access_time_outlined,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(widget.sesion.duracion,
                                    style: const TextStyle(
                                        color: kOrange,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('duration_label'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.do_not_step,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(
                                    '${widget.sesion.distanciaKm.toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                        color: kRed,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('metric_distance'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.trending_up,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text('${widget.sesion.cadencia.round()} spm',
                                    style: const TextStyle(
                                        color: kPurple,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tr('metric_cadence'),
                                          style: const TextStyle(
                                              color: kGray, fontSize: 12)),
                                      InfoTip(
                                          titulo: tr('metric_cadence'),
                                          texto: tr('cadence_info')),
                                    ]),
                              ]),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.show_chart,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text('${widget.sesion.pasos}',
                                    style: const TextStyle(
                                        color: kTeal,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(tr('steps_label'),
                                    style:
                                        const TextStyle(color: kGray, fontSize: 12)),
                              ]),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.straighten,
                                    color: kGray, size: 22),
                                const SizedBox(height: 10),
                                Text(
                                    widget.sesion.zancadaRatio <= 0
                                        ? 'N/A'
                                        : '${(widget.sesion.zancadaRatio * 100).round()}%',
                                    style: const TextStyle(
                                        color: kOrange,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Flexible(
                                    child: Text(tr('stride_vs_expected'),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: kGray, fontSize: 12)),
                                  ),
                                  InfoTip(
                                      titulo: tr('stride_vs_expected'),
                                      texto: tr('stride_info')),
                                ]),
                              ])),
                      const SizedBox(height: 16),

                      // Sesiones grabadas antes de añadir este campo, o sin GPS, no muestran esta tarjeta.
                      if (widget.sesion.recorrido.isNotEmpty) ...[
                        GogaitCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr('route_label'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 12),
                                  MapaRecorrido(
                                      recorrido: widget.sesion.recorrido),
                                ])),
                        const SizedBox(height: 16),
                      ],

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(children: [
                            Text(tr('pressure_analysis_summary'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                        tr('pressure_distribution_breakdown'),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ),
                                  InfoTip(
                                      titulo:
                                          tr('pressure_distribution_breakdown'),
                                      texto: tr('heel_metatarsal_info')),
                                ]),
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(tr('left_foot'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        _pressureBar(tr('heel_label'),
                                            widget.sesion.presionTalonIzq.round()),
                                        _pressureBar(tr('metatarsal_label'),
                                            widget.sesion.presionMetaIzq.round()),
                                      ])),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(tr('right_foot'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        _pressureBar(
                                            tr('heel_label'), widget.sesion.presionTalon.round()),
                                        _pressureBar(tr('metatarsal_label'),
                                            widget.sesion.presionMeta.round()),
                                      ])),
                                ]),
                            const SizedBox(height: 12),
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
                                      width: 20,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      decoration: BoxDecoration(
                                          color: Color(c),
                                          borderRadius:
                                              BorderRadius.circular(3)))),
                                  const Text(' >100%',
                                      style: TextStyle(
                                          color: kGray, fontSize: 11)),
                                ]),
                          ])),
                      const SizedBox(height: 16),

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('biomechanical_metrics'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(height: 12),
                                _footSelector(),
                                const SizedBox(height: 20),
                                Builder(builder: (context) {
                                  // Sin señal del pie izq., balance es NA (no un 50 fingido); pctBoth es % de desequilibrio, no reparto real (0=simétrico, 100=todo en un pie).
                                  final sinBalance = !widget.sesion.tieneBalance;
                                  final balancePct = sinBalance
                                      ? 0
                                      : widget.sesion.balance.round();
                                  final desequilibrioPct = sinBalance
                                      ? 0
                                      : ((widget.sesion.balance - 50).abs() * 2)
                                          .round();
                                  // El badge aclara qué pie domina; solo aplica en Both.
                                  final ladoBalance = _footFilter != 'both'
                                      ? ''
                                      : balancePct > 50
                                          ? tr('right_dominant')
                                          : balancePct < 50
                                              ? tr('left_dominant')
                                              : tr('symmetric_label');
                                  return _metricBar(
                                      tr('metric_balance'),
                                      desequilibrioPct,
                                      sinBalance ? 0 : 100 - balancePct,
                                      balancePct,
                                      kGray,
                                      sinBalance ? '' : ladoBalance,
                                      info: tr('balance_info'));
                                }),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  final sinDatos = !widget.sesion.tieneImpacto;
                                  // Sin peso registrado se muestra el % en vez de kg (impactoKg es media de ambos pies).
                                  final sinPeso = (widget.sesion.impacto +
                                              widget.sesion.impactoIzq) /
                                          2 >
                                      0 &&
                                      widget.sesion.impactoKg <= 0;
                                  final impactoDerPct = sinDatos
                                      ? 0
                                      : widget.sesion.impacto.round();
                                  final impactoIzqPct = sinDatos
                                      ? 0
                                      : widget.sesion.impactoIzq.round();
                                  final impactoBothPct = sinDatos
                                      ? 0
                                      : ((widget.sesion.impacto +
                                                  widget.sesion.impactoIzq) /
                                              2)
                                          .round();
                                  // El % de respaldo sigue el filtro Left/Right/Both seleccionado.
                                  final pctSegunFiltro = _footFilter == 'left'
                                      ? impactoIzqPct
                                      : _footFilter == 'right'
                                          ? impactoDerPct
                                          : impactoBothPct;
                                  // El peso no se guarda (solo impactoKg del Both); se reconstruye para mostrar kg en Left/Right: peso = impactoKg / (impactoBothPct/100).
                                  final pesoEnSesion =
                                      (!sinPeso && impactoBothPct > 0)
                                          ? widget.sesion.impactoKg /
                                              (impactoBothPct / 100)
                                          : null;
                                  final numeroPrincipal = pesoEnSesion == null
                                      ? null
                                      : '${(pctSegunFiltro / 100 * pesoEnSesion).round()} kg';
                                  return _metricBar(
                                      tr('metric_impact'),
                                      impactoBothPct,
                                      impactoIzqPct,
                                      impactoDerPct,
                                      kGray,
                                      sinDatos ? 'N/A' : '',
                                      info: tr('impact_info'),
                                      etiquetaNumero: numeroPrincipal);
                                }),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  final tiene = widget.sesion.tieneFatiga;
                                  final fatiga =
                                      tiene ? widget.sesion.fatiga : 0.0;
                                  final tramos = widget.sesion.tramosFatiga;
                                  // Color fijo (no por umbral); el dinámico se queda solo en Quick Metrics.
                                  const colorFatiga = kGray;
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Row(children: [
                                                  Flexible(
                                                    child: Text(
                                                        tr('fatigue_index'),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFFD1D5DB),
                                                            fontSize: 14)),
                                                  ),
                                                  InfoTip(
                                                      titulo:
                                                          tr('fatigue_index'),
                                                      texto:
                                                          tr('fatigue_index_info')),
                                                ]),
                                              ),
                                              const SizedBox(width: 8),
                                              Row(children: [
                                                Text(
                                                    tiene
                                                        ? '${fatiga.round()}%'
                                                        : '0%',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const SizedBox(width: 8),
                                                Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color: colorFatiga
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    child: Text(
                                                        !tiene
                                                            ? 'N/A'
                                                            : fatiga >= 20
                                                                ? tr('fatigue_rising')
                                                                : tr('fatigue_stable'),
                                                        style: const TextStyle(
                                                            color:
                                                                colorFatiga,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500))),
                                              ]),
                                            ]),
                                        const SizedBox(height: 8),
                                        TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: 1),
                                            duration: const Duration(
                                                milliseconds: 900),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, progreso, __) =>
                                                CustomPaint(
                                                    size: const Size(
                                                        double.infinity, 70),
                                                    painter: _FatiguePainter(
                                                        tramos, progreso))),
                                      ]);
                                }),
                                const SizedBox(height: 4),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(tr('start_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                      Flexible(
                                        child: Text(tr('mid_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                      Flexible(
                                        child: Text(tr('end_label'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 10)),
                                      ),
                                    ]),
                                const SizedBox(height: 16),
                                Builder(builder: (context) {
                                  // strikeIndexDer/Izq son independientes: cada pct se apaga con su propio flag.
                                  final strikeDerPct = widget.sesion.tieneStrikeDer
                                      ? widget.sesion.strikeIndexDer.round()
                                      : 0;
                                  final strikeIzqPct = widget.sesion.tieneStrikeIzq
                                      ? widget.sesion.strikeIndexIzq.round()
                                      : 0;
                                  final sinAmbos = !widget.sesion.tieneStrikeDer &&
                                      !widget.sesion.tieneStrikeIzq;
                                  final strikeBothPct = sinAmbos
                                      ? 0
                                      : !widget.sesion.tieneStrikeDer
                                          ? strikeIzqPct
                                          : !widget.sesion.tieneStrikeIzq
                                              ? strikeDerPct
                                              : ((strikeDerPct + strikeIzqPct) / 2)
                                                  .round();
                                  // Sin datos para el pie (o pies) del filtro Both/Left/Right seleccionado.
                                  final sinDatosFiltro = _footFilter == 'left'
                                      ? !widget.sesion.tieneStrikeIzq
                                      : _footFilter == 'right'
                                          ? !widget.sesion.tieneStrikeDer
                                          : sinAmbos;
                                  final pctFiltro = _footFilter == 'left'
                                      ? strikeIzqPct
                                      : _footFilter == 'right'
                                          ? strikeDerPct
                                          : strikeBothPct;
                                  final badge = sinDatosFiltro
                                      ? 'N/A'
                                      : pctFiltro < 34
                                          ? tr('strike_heel')
                                          : pctFiltro < 67
                                              ? tr('strike_midfoot')
                                              : tr('strike_forefoot');
                                  return _metricBar(
                                      tr('strike_index'),
                                      strikeBothPct,
                                      strikeIzqPct,
                                      strikeDerPct,
                                      kYellow,
                                      badge,
                                      info: tr('strike_index_info'));
                                }),
                              ])),
                      const SizedBox(height: 16),

                      Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                kOrange.withValues(alpha: 0.08),
                                kRed.withValues(alpha: 0.08)
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kOrange.withValues(alpha: 0.2))),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        gradient: kGradient,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.my_location,
                                        color: Colors.white, size: 16)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(tr('insights_title'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      const SizedBox(height: 6),
                                      Text(generarInsights(widget.sesion),
                                          style: const TextStyle(
                                              color: Color(0xFFD1D5DB),
                                              fontSize: 13,
                                              height: 1.5)),
                                    ])),
                              ])),
                      const SizedBox(height: 16),
                      ],

                      // El tick del header ya guarda y sale de edición; no hace falta un botón "Save Changes" aquí.
                      if (!_editing)
                        GestureDetector(
                            onTap: _exportarCsv,
                            child: Container(
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: kCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kGrayDark)),
                                alignment: Alignment.center,
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.file_download_outlined,
                                          color: kTeal, size: 18),
                                      const SizedBox(width: 8),
                                      Text(tr('export_as_csv'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16)),
                                    ]))),
                    ]))),
      ])),
    );
  }
}

// Gráfica de fatiga: une los 3 valores de impacto medio (inicio/mitad/fin, tramosFatiga). Línea plana = sin datos suficientes (los 3 a 0), no ausencia de fatiga.
class _FatiguePainter extends CustomPainter {
  final List<double> tramos; // [inicio, mitad, fin], cada uno 0-100
  // 0 = nada dibujado, 1 = línea completa.
  final double progreso;
  _FatiguePainter(this.tramos, [this.progreso = 1]);

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = tramos.isEmpty
        ? 0.0
        : tramos.reduce((a, b) => a > b ? a : b);
    final subiendo = tramos.length == 3 && tramos[2] > tramos[0];
    final color = maximo <= 0
        ? kGray
        : subiendo
            ? kRed
            : kTeal;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    // Margen arriba/abajo para que los puntos no toquen el borde; sin máximo (todo a 0), línea plana centrada.
    double yPara(double valor) {
      if (maximo <= 0) {
        return size.height * 0.5;
      }
      final margen = size.height * 0.15;
      return size.height - margen - (valor / maximo) * (size.height - 2 * margen);
    }

    final puntos = List.generate(3, (i) {
      final x = size.width * (i / 2);
      final v = tramos.length == 3 ? tramos[i] : 0.0;
      return Offset(x, yPara(v));
    });
    final path = Path()..moveTo(puntos[0].dx, puntos[0].dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Igual que en _LinePainter: recorta el trazo según 'progreso' para que se vea dibujándose.
    if (progreso >= 1) {
      canvas.drawPath(path, linePaint);
    } else if (progreso > 0) {
      final visible = Path();
      for (final metric in path.computeMetrics()) {
        visible.addPath(
            metric.extractPath(0, metric.length * progreso), Offset.zero);
      }
      canvas.drawPath(visible, linePaint);
    }
    final puntosVisibles = (progreso * 2).floor() + 1; // 3 puntos, 2 tramos
    for (int i = 0; i < puntos.length && i < puntosVisibles; i++) {
      canvas.drawCircle(puntos[i], 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _FatiguePainter oldDelegate) =>
      oldDelegate.tramos != tramos || oldDelegate.progreso != progreso;
}
