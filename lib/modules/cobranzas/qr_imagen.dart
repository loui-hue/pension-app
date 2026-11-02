import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

/// Muestra la imagen del QR de cobro de un método de pago.
/// La imagen está protegida por el token, así que se descarga con ApiService
/// y se guarda en memoria para no volver a pedirla en cada cobro.
class QrImagen extends StatefulWidget {
  final int metodoId;
  final double size;
  const QrImagen({super.key, required this.metodoId, this.size = 260});

  static final Map<int, Uint8List> _cache = {};

  /// Se llama después de subir un QR nuevo para no mostrar el anterior.
  static void invalidar(int metodoId) => _cache.remove(metodoId);

  @override
  State<QrImagen> createState() => _QrImagenState();
}

class _QrImagenState extends State<QrImagen> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(QrImagen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metodoId != widget.metodoId) _cargar();
  }

  Future<void> _cargar() async {
    final enCache = QrImagen._cache[widget.metodoId];
    if (enCache != null) {
      setState(() => _bytes = enCache);
      return;
    }
    try {
      final bytes = Uint8List.fromList(
        await ApiService().getBytes('/payment-methods/${widget.metodoId}/qr'),
      );
      QrImagen._cache[widget.metodoId] = bytes;
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true)
          : Center(
              child: _error
                  ? const Text(
                      'No se pudo cargar el QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textDark),
                    )
                  : const CircularProgressIndicator(color: AppTheme.primary),
            ),
    );
  }
}
