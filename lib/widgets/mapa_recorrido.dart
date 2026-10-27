part of '../main.dart';

// ---- ROUTE MAP WIDGET ----
// Dibuja el recorrido GPS sobre teselas de OpenStreetMap (sin API key), a partir de SesionActividad.recorrido.
class MapaRecorrido extends StatelessWidget {
  final List<Map<String, dynamic>> recorrido;
  const MapaRecorrido({super.key, required this.recorrido});

  @override
  Widget build(BuildContext context) {
    final puntos = recorrido
        .map((p) => LatLng(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();
    if (puntos.isEmpty) {
      return const SizedBox.shrink();
    }
    // Encuadre inicial centrado en el recorrido: punto medio entre primero y último, sin paquete adicional de cámara.
    final centro = LatLng(
        (puntos.first.latitude + puntos.last.latitude) / 2,
        (puntos.first.longitude + puntos.last.longitude) / 2);
    return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  // Servidor de teselas estándar de OSM: gratuito, sin API key. El User-Agent es obligatorio según su política de uso.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gogait.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(points: puntos, strokeWidth: 4, color: kOrange),
                ]),
                MarkerLayer(markers: [
                  Marker(
                      point: puntos.first,
                      width: 16,
                      height: 16,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: kTeal, shape: BoxShape.circle))),
                  Marker(
                      point: puntos.last,
                      width: 16,
                      height: 16,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: kRed, shape: BoxShape.circle))),
                ]),
              ],
            )));
  }
}
