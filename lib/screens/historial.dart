part of '../main.dart';

// ---- HISTORY SCREEN ----
// Historial de actividades, filtrable por tipo (all/walking/running/trail).
class VistaHistorico extends StatefulWidget {
  const VistaHistorico({super.key});
  @override
  State<VistaHistorico> createState() => _VistaHistoricoState();
}

class _VistaHistoricoState extends State<VistaHistorico> with IdiomaListenerMixin {
  String _filter = 'all';

  // Icono representativo según el tipo de actividad.
  IconData _iconForType(String t) {
    switch (t) {
      case 'running':
        return Icons.directions_run;
      case 'trail':
        return Icons.terrain;
      default:
        return Icons.directions_walk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? historial
        : historial.where((s) => s.tipo == _filter).toList();
    // s.duracion es "12min 34s" (ver VistaResumen._guardar); se reconstruyen minutos+segundos completos, no solo la parte antes de 'min'.
    final totalMin = filtered.fold<double>(0, (sum, s) {
      final m = RegExp(r'(\d+)min\s*(\d+)s').firstMatch(s.duracion);
      if (m == null) {
        return sum;
      }
      return sum + int.parse(m.group(1)!) + int.parse(m.group(2)!) / 60;
    });
    final totalKm = filtered.fold<double>(0, (sum, s) => sum + s.distanciaKm);

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
                  child: Text(tr('activity_history'),
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kOrange.withValues(alpha: 0.12),
                          kRed.withValues(alpha: 0.12),
                          kYellow.withValues(alpha: 0.12)
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kGrayDark.withValues(alpha: 0.5))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                              icon: Icons.access_time,
                              color: kPurple,
                              value: '${(totalMin / 60).toStringAsFixed(1)}h',
                              label: tr('hours_label')),
                          _StatItem(
                              icon: Icons.directions_walk,
                              color: kRed,
                              value: '${filtered.length}',
                              label: tr('sessions_label')),
                          _StatItem(
                              icon: Icons.location_on_outlined,
                              color: kOrange,
                              value: '${totalKm.toStringAsFixed(1)}km',
                              label: tr('metric_distance')),
                        ]),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FilterBtn(
                            label: tr('filter_all'),
                            value: 'all',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        _FilterBtn(
                            label: tr('filter_walking'),
                            value: 'walking',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.directions_walk),
                        _FilterBtn(
                            label: tr('filter_running'),
                            value: 'running',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.directions_run),
                        _FilterBtn(
                            label: tr('filter_trail'),
                            value: 'trail',
                            current: _filter,
                            onTap: (v) => setState(() => _filter = v),
                            icon: Icons.terrain),
                      ])),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(tr('no_activities_found'),
                            style: const TextStyle(color: kGray),
                            textAlign: TextAlign.center)),
                  ...filtered.reversed.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              gogaitRoute(
                                  builder: (_) =>
                                      VistaDetalleHistorico(sesion: s)));
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kGrayDark.withValues(alpha: 0.5))),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          kOrange.withValues(alpha: 0.2),
                                          kRed.withValues(alpha: 0.2)
                                        ]),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: kOrange.withValues(
                                                alpha: 0.3))),
                                    child: Icon(_iconForType(s.tipo),
                                        color: kOrange, size: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(s.titulo,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15)),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.chevron_right,
                                                color: kGray, size: 18),
                                          ]),
                                      const SizedBox(height: 2),
                                      Text(
                                          _formatFechaSesion(s, separador: '·'),
                                          style: const TextStyle(
                                              color: kGray, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        const Icon(Icons.access_time,
                                            color: kGray, size: 14),
                                        const SizedBox(width: 4),
                                        Text(s.duracion,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.location_on_outlined,
                                            color: kGray, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                            '${s.distanciaKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                      ]),
                                    ])),
                              ]),
                        ),
                      ),
                    );
                  }),
                ]))),
      ])),
    );
  }
}

// Icono + valor + etiqueta en columna (resumen de Horas/Sesiones/Distancia).
class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatItem(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: kGray, fontSize: 11)),
      ]);
}

// Botón-pastilla de filtro (All/Walking/Running/Trail); se resalta si está seleccionado.
class _FilterBtn extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  final IconData? icon;
  const _FilterBtn(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap,
      this.icon});
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? kGradient : null,
          color: sel ? null : kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.transparent : kGrayDark),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: sel ? Colors.white : kOrange, size: 16),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : kGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
