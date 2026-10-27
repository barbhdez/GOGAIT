part of '../main.dart';

// ---- WIDGETS COMUNES ----
// botón con degradado naranja/rojo, o solo borde (outlined) para acciones secundarias
class GogaitButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool outlined;
  final double? width;
  const GogaitButton(
      {super.key,
      required this.text,
      required this.onTap,
      this.outlined = false,
      this.width});

  @override
  State<GogaitButton> createState() => _GogaitButtonState();
}

class _GogaitButtonState extends State<GogaitButton> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) => setState(() => _presionado = false),
      onTapCancel: () => setState(() => _presionado = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width ?? double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.outlined ? null : kGradientFull,
            border: widget.outlined
                ? Border.all(color: kOrange.withValues(alpha: 0.4))
                : null,
            color: widget.outlined ? kCard : null,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(widget.text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// tarjeta base de casi todas las secciones de la app, opcionalmente pulsable
class GogaitCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const GogaitCard({super.key, required this.child, this.padding, this.onTap});

  @override
  State<GogaitCard> createState() => _GogaitCardState();
}

class _GogaitCardState extends State<GogaitCard> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    // solo se encoge si tiene onTap, si no no debe parecer interactiva
    final interactiva = widget.onTap != null;
    return GestureDetector(
      onTapDown: interactiva ? (_) => setState(() => _presionado = true) : null,
      onTapUp: interactiva ? (_) => setState(() => _presionado = false) : null,
      onTapCancel: interactiva ? () => setState(() => _presionado = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGrayDark.withValues(alpha: 0.5)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Campo de texto con etiqueta, usado en formularios (login, registro, perfil).
class GogaitInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  const GogaitInput(
      {super.key,
      required this.label,
      required this.controller,
      this.hint,
      this.obscure = false,
      this.suffix,
      this.keyboardType,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // label vacío: la pantalla ya pone su propio título encima
      if (label.isNotEmpty) ...[
        Text(label,
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14)),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          filled: true,
          fillColor: kCard,
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF374151))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF374151))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kOrange)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }
}

// Tarjetita pequeña para mostrar una métrica suelta (icono + valor + etiqueta).
class MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const MetricChip(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGrayDark.withValues(alpha: 0.5)),
      ),
      child: Stack(children: [
        Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
            )),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: kGray, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kGray, fontSize: 11)),
        ]),
      ]),
    );
  }
}

// explica qué significa una métrica (Balance, Impact...) en una hoja simple
void mostrarInfoMetrica(BuildContext context, String titulo, String texto) {
  // showGeneralDialog en vez de showDialog: permite que la explicación "crezca" desde el icono que la abrió
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: titulo,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kGrayDark)),
      title: Text(titulo,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      content: Text(texto,
          style: const TextStyle(color: kGray, fontSize: 14, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('got_it_button'), style: const TextStyle(color: kOrange))),
      ],
    ),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final crece = CurvedAnimation(
          parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: crece, child: child),
      );
    },
  );
}

// icono ⓘ que abre mostrarInfoMetrica al tocarlo
class InfoTip extends StatelessWidget {
  final String titulo;
  final String texto;
  const InfoTip({super.key, required this.titulo, required this.texto});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: () => mostrarInfoMetrica(context, titulo, texto),
      child: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.info_outline, color: kGray, size: 14)));
}
