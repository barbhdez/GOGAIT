part of '../main.dart';

// ---- METRICS GUIDE SCREEN ----
// Explica qué mide cada métrica, de dónde sale el número y cómo interpretarlo.
class VistaGuiaMetricas extends StatelessWidget {
  const VistaGuiaMetricas({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, _, __) {
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
                child: Text(tr('metrics_guide_title'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
              ),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('metrics_guide_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 20),
                      _tarjetaMetrica(
                        icon: Icons.my_location,
                        color: kTeal,
                        titulo: tr('metric_balance'),
                        definicion: tr('mg_balance_def'),
                        formula: 'Balance = 100 ×\n\n'
                            '  ΣPresRight\n'
                            '  ──────────────────\n'
                            '  ΣPresLeft + ΣPresRight',
                        variables: [
                          tr('mg_balance_var1'),
                          tr('mg_balance_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_balance_val1')),
                          (kOrange, tr('mg_balance_val2')),
                          (kRed, tr('mg_balance_val3')),
                        ],
                        nota: tr('mg_balance_nota'),
                        dondeAparece: tr('mg_balance_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.speed,
                        color: kOrange,
                        titulo: tr('metric_impact'),
                        definicion: tr('mg_impact_def'),
                        formula: 'Impact = avg(step peak)\n\n'
                            'Impact (kg) =\n\n'
                            '  Impact\n'
                            '  ─────── × Weight\n'
                            '    100',
                        variables: [
                          tr('mg_impact_var1'),
                          tr('mg_impact_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_impact_val1')),
                          (kOrange, tr('mg_impact_val2')),
                          (kRed, tr('mg_impact_val3')),
                        ],
                        nota: tr('mg_impact_nota'),
                        dondeAparece: tr('mg_impact_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.trending_down,
                        color: kRed,
                        titulo: tr('fatigue_index'),
                        definicion: tr('mg_fatigue_def'),
                        formula: 'Fatigue Index = 100 ×\n\n'
                            '  ImpactEnd −\n'
                            '  ImpactStart\n'
                            '  ─────────────\n'
                            '  ImpactStart',
                        variables: [
                          tr('mg_fatigue_var1'),
                          tr('mg_fatigue_var2'),
                        ],
                        valores: [
                          (kTeal, tr('mg_fatigue_val1')),
                          (kRed, tr('mg_fatigue_val2')),
                        ],
                        nota: tr('mg_fatigue_nota'),
                        dondeAparece: tr('mg_fatigue_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.do_not_step,
                        color: kYellow,
                        titulo: tr('mg_heel_metatarsal_title'),
                        definicion: tr('mg_heel_metatarsal_def'),
                        formula: 'w_heel = 1.0 → Heel Strike\n'
                            'w_heel = 0.5 → Midstance\n'
                            'w_heel = 0.0 → Propulsion/Swing',
                        variables: [
                          tr('mg_heel_metatarsal_var1'),
                          tr('mg_heel_metatarsal_var2'),
                        ],
                        valores: [
                          (kYellow, tr('mg_heel_metatarsal_val1')),
                          (kYellow, tr('mg_heel_metatarsal_val2')),
                          (kYellow, tr('mg_heel_metatarsal_val3')),
                        ],
                        nota: tr('mg_heel_metatarsal_nota'),
                        dondeAparece: tr('mg_heel_metatarsal_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.compare_arrows,
                        color: kYellow,
                        titulo: tr('strike_index'),
                        definicion: tr('mg_strike_def'),
                        formula: 'Strike Index =\n\n'
                            '  avg(100 × (1 − w_heel_mag))',
                        variables: [
                          tr('mg_strike_var1'),
                          tr('mg_strike_var2'),
                        ],
                        valores: [
                          (kYellow, tr('mg_strike_val1')),
                          (kYellow, tr('mg_strike_val2')),
                          (kYellow, tr('mg_strike_val3')),
                        ],
                        nota: tr('mg_strike_nota'),
                        dondeAparece: tr('mg_strike_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.emoji_events_outlined,
                        color: kPurple,
                        titulo: tr('performance_score'),
                        definicion: tr('mg_performance_def'),
                        formula: 'Score = 100 −\n\n'
                            '  avg(PenBalance,\n'
                            '      PenFatigue,\n'
                            '      PenStride)',
                        variables: [
                          tr('mg_performance_var1'),
                          tr('mg_performance_var2'),
                          tr('mg_performance_var3'),
                        ],
                        valores: [
                          (kPurple, tr('mg_performance_val1')),
                          (kPurple, tr('mg_performance_val2')),
                          (kPurple, tr('mg_performance_val3')),
                          (kPurple, tr('mg_performance_val4')),
                        ],
                        nota: tr('mg_performance_nota'),
                        dondeAparece: tr('mg_performance_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.trending_up,
                        color: kOrange,
                        titulo: tr('metric_cadence'),
                        definicion: tr('mg_cadence_def'),
                        formula: 'Cadence =\n\n'
                            '  Steps\n'
                            '  ────────\n'
                            '  Minute',
                        dondeAparece: tr('mg_cadence_where'),
                      ),
                      const SizedBox(height: 14),
                      _tarjetaMetrica(
                        icon: Icons.straighten,
                        color: kOrange,
                        titulo: tr('stride_vs_expected'),
                        definicion: tr('mg_stride_def'),
                        formula: 'StrideRatio =\n\n'
                            '  Distance / Steps\n'
                            '  ──────────────────\n'
                            '  ExpectedStride\n\n'
                            'ExpectedStride = Height × k',
                        variables: [
                          tr('mg_stride_var1'),
                        ],
                        valores: [
                          (kOrange, tr('mg_stride_val1')),
                          (kOrange, tr('mg_stride_val2')),
                          (kOrange, tr('mg_stride_val3')),
                        ],
                        nota: tr('mg_stride_nota'),
                        dondeAparece: tr('mg_stride_where'),
                      ),
                      const SizedBox(height: 20),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                kOrange.withValues(alpha: 0.08),
                                kRed.withValues(alpha: 0.08)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: kOrange.withValues(alpha: 0.2))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.my_location,
                                      color: kOrange, size: 16),
                                  const SizedBox(width: 8),
                                  Text(tr('about_insights_title'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                    tr('about_insights_intro'),
                                    style: const TextStyle(
                                        color: kGray,
                                        fontSize: 12,
                                        height: 1.4)),
                                const SizedBox(height: 8),
                                _reglaInsight(tr('about_insights_rule_1')),
                                _reglaInsight(tr('about_insights_rule_2')),
                                _reglaInsight(tr('about_insights_rule_3')),
                                _reglaInsight(tr('about_insights_rule_4')),
                                _reglaInsight(tr('about_insights_rule_5')),
                                _reglaInsight(tr('about_insights_rule_6')),
                              ])),
                      const SizedBox(height: 12),
                    ]))),
      ])),
    );
        });
  }

  Widget _reglaInsight(String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, color: kGray, size: 4)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                style:
                    const TextStyle(color: kGray, fontSize: 12, height: 1.4))),
      ]));

  // Puntos de color: variables de la fórmula o valores típicos (ver colorDesequilibrio/colorImpacto/etc.).
  Widget _listaConPuntos(List<String> lineas, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineas
          .map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, color: color, size: 4)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(l,
                            style: const TextStyle(
                                color: kGray, fontSize: 12, height: 1.35))),
                  ])))
          .toList());

  // Como _listaConPuntos pero con color propio por línea (mismos colores que colorDesequilibrio/colorImpacto/colorFatiga).
  Widget _listaValoresConPuntos(List<(Color, String)> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.circle, color: item.$1, size: 9)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                                color: kGray, fontSize: 12, height: 1.35))),
                  ])))
          .toList());

  // Etiqueta en mayúsculas para separar secciones dentro de la tarjeta.
  Widget _seccionLabel(String texto, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)));

  Widget _tarjetaMetrica({
    required IconData icon,
    required Color color,
    required String titulo,
    required String definicion,
    String? formula,
    List<String> variables = const [],
    List<(Color, String)> valores = const [],
    String? nota,
    required String dondeAparece,
  }) {
    return GogaitCard(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15))),
          ]),
          const SizedBox(height: 8),
          Text(definicion,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 13, height: 1.4)),
          if (formula != null) ...[
            const SizedBox(height: 8),
            Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25))),
                child: Text(formula,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4))),
          ],
          if (variables.isNotEmpty) ...[
            const SizedBox(height: 10),
            _seccionLabel(tr('mg_section_vars'), color),
            _listaConPuntos(variables, color),
          ],
          if (valores.isNotEmpty) ...[
            const SizedBox(height: 10),
            _seccionLabel(tr('mg_section_valores'), color),
            _listaValoresConPuntos(valores),
          ],
          if (nota != null) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline, color: kGray, size: 12)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(nota,
                      style: const TextStyle(
                          color: kGray,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          height: 1.3))),
            ]),
          ],
          const SizedBox(height: 10),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: kGrayDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.place_outlined, color: kGray, size: 12),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(dondeAparece,
                        style: const TextStyle(
                            color: kGray,
                            fontSize: 11,
                            fontStyle: FontStyle.italic))),
              ])),
        ]));
  }
}
