import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
// hide Path: choca con el Path de dart:ui que usan los CustomPainter
import 'package:latlong2/latlong.dart' hide Path;
import 'firebase_options.dart';

part 'core/config_ble.dart';
part 'i18n/traducciones.dart';
part 'core/tema.dart';
part 'models/modelos.dart';
part 'logic/metricas.dart';
part 'utils/utilidades.dart';
part 'services/ble_calibracion.dart';
part 'services/almacenamiento.dart';
part 'widgets/comunes.dart';
part 'screens/splash.dart';
part 'screens/bienvenida.dart';
part 'screens/login.dart';
part 'screens/registro.dart';
part 'screens/home.dart';
part 'widgets/mapa_calor_pie.dart';
part 'screens/bluetooth.dart';
part 'screens/tipo_actividad.dart';
part 'screens/preparacion.dart';
part 'screens/actividad_en_vivo.dart';
part 'screens/resumen_sesion.dart';
part 'screens/historial.dart';
part 'screens/exportar_metricas.dart';
part 'widgets/mapa_recorrido.dart';
part 'screens/detalle_actividad.dart';
part 'screens/ajustes.dart';
part 'screens/guia_metricas.dart';

// ---- MAIN ----
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // sin este await, _claveUsuario() podía leer sin email y sobrescribir el historial con uno vacío
  await FirebaseAuth.instance.authStateChanges().first;
  await cargarHistorial();
  await cargarCalibracion(Pie.derecha);
  await cargarCalibracion(Pie.izquierda);
  await cargarIdiomaGuardado();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser != null) {
    usuarioActual = Usuario(
      email: firebaseUser.email ?? '',
      nombre: prefs.getString(_claveUsuario('nombre')) ?? '',
      apellido: prefs.getString(_claveUsuario('apellido')) ?? '',
      genero: prefs.getString(_claveUsuario('genero')) ?? 'Male',
      contrasena: '',
      altura: prefs.getDouble(_claveUsuario('altura')) ?? 0.0,
      peso: prefs.getDouble(_claveUsuario('peso')) ?? 0.0,
      cumpleanos: prefs.getString(_claveUsuario('cumpleanos')) ?? '',
      shoeSize: prefs.getDouble(_claveUsuario('shoeSize')) ?? 0.0,
      arco: prefs.getString(_claveUsuario('arco')) ?? 'Normal',
      fotoPath: prefs.getString(_claveUsuario('fotoPath')),
      patologia: prefs.getString(_claveUsuario('patologia')),
    );
  }
  runApp(const GogaitApp());
}

class GogaitApp extends StatelessWidget {
  const GogaitApp({super.key});
  @override
  Widget build(BuildContext context) {
    // envuelve toda la MaterialApp: al cambiar appLang.value reconstruye cualquier pantalla que use tr()
    return ValueListenableBuilder<AppLang>(
        valueListenable: appLang,
        builder: (_, __, ___) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: kBg,
              fontFamily: 'SF Pro Display',
              colorScheme: const ColorScheme.dark(
                primary: kOrange,
                surface: kCard,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: kBg,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
            home: const VistaSplash(),
          );
        });
  }
}
