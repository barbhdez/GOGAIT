part of '../main.dart';

// ---- ACTIVITY TYPE SELECTION SCREEN (previa a la calibración) ----
// Elegir el tipo prellena tipo/título de sesión en VistaResumen (tipoInicial). La calibración es la misma para los tres, con un salto que también vale para correr.
class VistaSeleccionActividad extends StatelessWidget {
  const VistaSeleccionActividad({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (context, _, __) {
    final tipos = [
      {
        'tipo': 'walking',
        'icon': Icons.directions_walk,
        'titulo': tr('activity_walk'),
        'desc': tr('activity_walk_desc'),
      },
      {
        'tipo': 'running',
        'icon': Icons.directions_run_outlined,
        'titulo': tr('activity_run'),
        'desc': tr('activity_run_desc'),
      },
      {
        'tipo': 'trail',
        'icon': Icons.landscape_outlined,
        'titulo': tr('activity_trail'),
        'desc': tr('activity_trail_desc'),
      },
    ];
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
                child: Text(tr('select_activity_title'),
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
                          tr('select_activity_subtitle'),
                          style: const TextStyle(color: kGray, fontSize: 13)),
                      const SizedBox(height: 20),
                      for (final t in tipos) ...[
                        GogaitCard(
                            onTap: () => Navigator.push(
                                context,
                                gogaitRoute(
                                    builder: (_) => VistaPreparacion(
                                        tipoActividad:
                                            t['tipo'] as String))),
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: kOrange.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: Icon(t['icon'] as IconData,
                                      color: kOrange, size: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t['titulo'] as String,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(t['desc'] as String,
                                            style: const TextStyle(
                                                color: kGray, fontSize: 12)),
                                      ])),
                              const Icon(Icons.chevron_right,
                                  color: kGray, size: 20),
                            ])),
                        const SizedBox(height: 12),
                      ],
                    ]))),
      ])),
    );
        });
  }
}
