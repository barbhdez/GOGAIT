part of '../main.dart';

const Color kBg = Color(0xFF0D1117);
const Color kCard = Color(0xFF1A1F2E);
const Color kOrange = Color(0xFFFF8A00);
const Color kRed = Color(0xFFFF3D57);
const Color kYellow = Color(0xFFFFC107);
const Color kTeal = Color(0xFF00D9C0);
const Color kPurple = Color(0xFF8B5CF6);
const Color kGray = Color(0xFF6B7280);
const Color kGrayDark = Color(0xFF374151);

LinearGradient get kGradient => const LinearGradient(
      colors: [kOrange, kRed],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

LinearGradient get kGradientFull => const LinearGradient(
      colors: [kOrange, kRed, kYellow],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

// ---- TRANSICIÓN DE PANTALLA ----
// Reemplazo de MaterialPageRoute con fundido + desplazamiento lateral
Route<T> gogaitRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curva,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(curva),
          child: child,
        ),
      );
    },
  );
}
