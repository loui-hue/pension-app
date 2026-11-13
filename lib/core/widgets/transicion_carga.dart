import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Indicador de carga que espera 300 ms antes de aparecer (con un fundido).
/// En la red local los datos suelen llegar antes y la pantalla pasa directo al
/// contenido: la ruedita ya no "parpadea" un instante, que era el destello que se
/// veía al abrir cada pantalla.
class Cargando extends StatefulWidget {
  const Cargando({super.key});

  @override
  State<Cargando> createState() => _CargandoState();
}

class _CargandoState extends State<Cargando> {
  bool _visible = false;
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _espera = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: const CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}

/// Barra fina para "actualizando" sin vaciar la pantalla.
class BarraActualizando extends StatelessWidget {
  final bool activa;
  const BarraActualizando({super.key, required this.activa});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: activa
          ? const LinearProgressIndicator(color: AppTheme.primary, backgroundColor: Colors.transparent)
          : null,
    );
  }
}
